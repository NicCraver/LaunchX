import AppKit

// MARK: - NSTableViewDataSource

extension SearchPanelViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }
}

// MARK: - NSTableViewDelegate

extension SearchPanelViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let identifier = NSUserInterfaceItemIdentifier("ResultCell")

        var cellView =
            tableView.makeView(withIdentifier: identifier, owner: self) as? ResultCellView
        if cellView == nil {
            cellView = ResultCellView()
            cellView?.identifier = identifier
        }

        let item = results[row]
        let isSelected = row == selectedIndex
        // 在文件夹打开模式或 IDE 项目模式下隐藏箭头（不能再 Tab）
        cellView?.configure(
            with: item, isSelected: isSelected, hideArrow: isInFolderOpenMode || isInIDEProjectMode)

        // 绑定图标点击事件（用于提醒事项快速勾选）
        cellView?.onIconClick = { [weak self] in
            if item.isReminder, let identifier = item.reminderIdentifier {
                RemindersService.shared.toggleCompletion(identifier: identifier) { success in
                    if success {
                        self?.loadReminders()
                    }
                }
            }
        }

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row >= 0 && row < results.count {
            let oldIndex = selectedIndex
            selectedIndex = row
            // 只刷新变化的行
            let columnIndexes = IndexSet(integer: 0)
            tableView.reloadData(
                forRowIndexes: IndexSet([oldIndex, row]), columnIndexes: columnIndexes)
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // 分组标题不可选中
        guard row < results.count else { return true }
        return !results[row].isSectionHeader
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // 分组标题使用较小的行高
        guard row < results.count else { return rowHeight }
        if results[row].isSectionHeader {
            return 28  // 分组标题行高
        }
        return rowHeight
    }
}
