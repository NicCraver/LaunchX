import Foundation
import SQLite3

/// SQLite database for persisting file index
/// Provides fast batch operations and efficient storage
final class IndexDatabase {
    static let shared = IndexDatabase()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.launchx.indexdb", qos: .userInitiated)

    // Prepared statements for performance
    private var insertStmt: OpaquePointer?
    private var deleteStmt: OpaquePointer?
    private var updateStmt: OpaquePointer?
    private var selectAllStmt: OpaquePointer?
    private var selectByPathStmt: OpaquePointer?

    private init() {
        openDatabase()
        createTables()
        prepareStatements()
    }

    deinit {
        finalizeStatements()
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let appFolder = appSupport.appendingPathComponent("LaunchX", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)

        let dbPath = appFolder.appendingPathComponent("file_index.db").path

        if sqlite3_open_v2(
            dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
            != SQLITE_OK
        {
            print("IndexDatabase: Failed to open database at \(dbPath)")
            return
        }

        // Performance optimizations
        executeSQL("PRAGMA journal_mode = WAL")  // Write-Ahead Logging for concurrency
        executeSQL("PRAGMA synchronous = NORMAL")  // Balance safety and speed
        executeSQL("PRAGMA cache_size = -64000")  // 64MB cache
        executeSQL("PRAGMA temp_store = MEMORY")  // Temp tables in memory
        executeSQL("PRAGMA mmap_size = 268435456")  // 256MB memory-mapped I/O

        print("IndexDatabase: Opened database at \(dbPath)")
    }

    private func createTables() {
        let createTableSQL = """
                CREATE TABLE IF NOT EXISTS files (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    path TEXT NOT NULL UNIQUE,
                    extension TEXT,
                    is_app INTEGER DEFAULT 0,
                    is_directory INTEGER DEFAULT 0,
                    pinyin_full TEXT,
                    pinyin_acronym TEXT,
                    modified_date REAL,
                    indexed_date REAL DEFAULT (strftime('%s', 'now')),
                    file_size INTEGER DEFAULT 0
                );

                CREATE INDEX IF NOT EXISTS idx_name ON files(name);
                CREATE INDEX IF NOT EXISTS idx_path ON files(path);
                CREATE INDEX IF NOT EXISTS idx_extension ON files(extension);
                CREATE INDEX IF NOT EXISTS idx_is_app ON files(is_app);
                CREATE INDEX IF NOT EXISTS idx_pinyin_full ON files(pinyin_full);
                CREATE INDEX IF NOT EXISTS idx_pinyin_acronym ON files(pinyin_acronym);
                CREATE INDEX IF NOT EXISTS idx_modified_date ON files(modified_date);
            """

        executeSQL(createTableSQL)
    }

    private func prepareStatements() {
        let insertSQL = """
                INSERT OR REPLACE INTO files
                (name, path, extension, is_app, is_directory, pinyin_full, pinyin_acronym, modified_date, file_size)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil)

        let deleteSQL = "DELETE FROM files WHERE path = ?"
        sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil)

        let updateSQL = """
                UPDATE files SET name = ?, extension = ?, modified_date = ?, file_size = ?
                WHERE path = ?
            """
        sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil)

        let selectAllSQL = "SELECT * FROM files"
        sqlite3_prepare_v2(db, selectAllSQL, -1, &selectAllStmt, nil)

        let selectByPathSQL = "SELECT * FROM files WHERE path = ?"
        sqlite3_prepare_v2(db, selectByPathSQL, -1, &selectByPathStmt, nil)
    }

    private func finalizeStatements() {
        sqlite3_finalize(insertStmt)
        sqlite3_finalize(deleteStmt)
        sqlite3_finalize(updateStmt)
        sqlite3_finalize(selectAllStmt)
        sqlite3_finalize(selectByPathStmt)
    }

    @discardableResult
    private func executeSQL(_ sql: String) -> Bool {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("IndexDatabase: SQL Error - \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
            return false
        }
        return true
    }

    // MARK: - Public API

    /// Insert multiple file records in a single transaction (very fast)
    func insertBatch(_ records: [FileRecord], completion: ((Bool) -> Void)? = nil) {
        dbQueue.async { [weak self] in
            guard let self = self, let stmt = self.insertStmt else {
                completion?(false)
                return
            }

            self.executeSQL("BEGIN TRANSACTION")

            for record in records {
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)

                sqlite3_bind_text(stmt, 1, record.name, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, record.path, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, record.extension, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 4, record.isApp ? 1 : 0)
                sqlite3_bind_int(stmt, 5, record.isDirectory ? 1 : 0)
                sqlite3_bind_text(stmt, 6, record.pinyinFull, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 7, record.pinyinAcronym, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(stmt, 8, record.modifiedDate?.timeIntervalSince1970 ?? 0)
                sqlite3_bind_int64(stmt, 9, Int64(record.fileSize))

                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("IndexDatabase: Failed to insert record: \(record.path)")
                }
            }

            self.executeSQL("COMMIT")

            DispatchQueue.main.async {
                completion?(true)
            }
        }
    }

    /// Insert a single file record
    func insert(_ record: FileRecord) {
        insertBatch([record])
    }

    /// Delete records by paths
    func deleteBatch(_ paths: [String], completion: ((Bool) -> Void)? = nil) {
        dbQueue.async { [weak self] in
            guard let self = self, let stmt = self.deleteStmt else {
                completion?(false)
                return
            }

            self.executeSQL("BEGIN TRANSACTION")

            for path in paths {
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
                sqlite3_bind_text(stmt, 1, path, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }

            self.executeSQL("COMMIT")

            DispatchQueue.main.async {
                completion?(true)
            }
        }
    }

    /// Delete a single record by path
    func delete(path: String) {
        deleteBatch([path])
    }

    /// Delete all records and reset database
    func deleteAll(completion: ((Bool) -> Void)? = nil) {
        dbQueue.async { [weak self] in
            let success = self?.executeSQL("DELETE FROM files") ?? false
            self?.executeSQL("VACUUM")  // Reclaim space

            DispatchQueue.main.async {
                completion?(success)
            }
        }
    }

    /// Delete records by path prefix (for incremental updates)
    /// - Parameters:
    ///   - pathPrefix: The path prefix to match
    ///   - completion: Callback with deleted count
    func deleteByPathPrefix(_ pathPrefix: String, completion: ((Int) -> Void)? = nil) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?(0) }
                return
            }

            // 使用 LIKE 查询删除匹配前缀的记录
            let escapedPrefix = pathPrefix.replacingOccurrences(of: "'", with: "''")
            let sql = "DELETE FROM files WHERE path LIKE '\(escapedPrefix)%'"

            self.executeSQL(sql)
            let deletedCount = Int(sqlite3_changes(self.db))

            DispatchQueue.main.async {
                completion?(deletedCount)
            }
        }
    }

    /// Get all paths with a specific prefix
    /// - Parameter pathPrefix: The path prefix to match
    /// - Returns: List of paths
    func getPathsWithPrefix(_ pathPrefix: String) -> [String] {
        var paths: [String] = []

        dbQueue.sync { [weak self] in
            guard let self = self else { return }

            var stmt: OpaquePointer?
            let escapedPrefix = pathPrefix.replacingOccurrences(of: "'", with: "''")
            let sql = "SELECT path FROM files WHERE path LIKE '\(escapedPrefix)%'"

            if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let pathPtr = sqlite3_column_text(stmt, 0) {
                        paths.append(String(cString: pathPtr))
                    }
                }
                sqlite3_finalize(stmt)
            }
        }

        return paths
    }

    /// Load all records from database
    func loadAll(completion: @escaping ([FileRecord]) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self, let stmt = self.selectAllStmt else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var records: [FileRecord] = []
            records.reserveCapacity(100000)  // Pre-allocate for performance

            sqlite3_reset(stmt)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let record = self.recordFromStatement(stmt)
                records.append(record)
            }

            DispatchQueue.main.async {
                completion(records)
            }
        }
    }

    /// Load all records synchronously (for startup)
    func loadAllSync() -> [FileRecord] {
        var records: [FileRecord] = []

        dbQueue.sync { [weak self] in
            guard let self = self, let stmt = self.selectAllStmt else { return }

            records.reserveCapacity(100000)
            sqlite3_reset(stmt)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let record = self.recordFromStatement(stmt)
                records.append(record)
            }
        }

        return records
    }

    /// Check if a path exists in database
    func exists(path: String) -> Bool {
        var result = false

        dbQueue.sync { [weak self] in
            guard let self = self, let stmt = self.selectByPathStmt else { return }

            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, path, -1, SQLITE_TRANSIENT)

            result = sqlite3_step(stmt) == SQLITE_ROW
        }

        return result
    }

    /// Get database statistics
    func getStatistics() -> (totalCount: Int, appsCount: Int, filesCount: Int) {
        var total = 0
        var apps = 0
        var files = 0

        dbQueue.sync { [weak self] in
            guard let self = self else { return }

            var stmt: OpaquePointer?

            // Total count
            if sqlite3_prepare_v2(self.db, "SELECT COUNT(*) FROM files", -1, &stmt, nil)
                == SQLITE_OK
            {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    total = Int(sqlite3_column_int(stmt, 0))
                }
                sqlite3_finalize(stmt)
            }

            // Apps count
            if sqlite3_prepare_v2(
                self.db, "SELECT COUNT(*) FROM files WHERE is_app = 1", -1, &stmt, nil) == SQLITE_OK
            {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    apps = Int(sqlite3_column_int(stmt, 0))
                }
                sqlite3_finalize(stmt)
            }

            files = total - apps
        }

        return (total, apps, files)
    }

    // MARK: - Helpers

    private func recordFromStatement(_ stmt: OpaquePointer) -> FileRecord {
        let name = String(cString: sqlite3_column_text(stmt, 1))
        let path = String(cString: sqlite3_column_text(stmt, 2))

        var ext: String? = nil
        if let extPtr = sqlite3_column_text(stmt, 3) {
            ext = String(cString: extPtr)
        }

        let isApp = sqlite3_column_int(stmt, 4) == 1
        let isDirectory = sqlite3_column_int(stmt, 5) == 1

        var pinyinFull: String? = nil
        if let ptr = sqlite3_column_text(stmt, 6) {
            pinyinFull = String(cString: ptr)
        }

        var pinyinAcronym: String? = nil
        if let ptr = sqlite3_column_text(stmt, 7) {
            pinyinAcronym = String(cString: ptr)
        }

        let modifiedTimestamp = sqlite3_column_double(stmt, 8)
        let modifiedDate =
            modifiedTimestamp > 0 ? Date(timeIntervalSince1970: modifiedTimestamp) : nil

        let fileSize = Int(sqlite3_column_int64(stmt, 9))

        return FileRecord(
            name: name,
            path: path,
            extension: ext,
            isApp: isApp,
            isDirectory: isDirectory,
            pinyinFull: pinyinFull,
            pinyinAcronym: pinyinAcronym,
            modifiedDate: modifiedDate,
            fileSize: fileSize
        )
    }
}

// MARK: - File Record Model

/// Represents a file record in the index database
struct FileRecord {
    let name: String
    let path: String
    let `extension`: String?
    let isApp: Bool
    let isDirectory: Bool
    let pinyinFull: String?
    let pinyinAcronym: String?
    let modifiedDate: Date?
    let fileSize: Int

    init(
        name: String,
        path: String,
        extension: String? = nil,
        isApp: Bool = false,
        isDirectory: Bool = false,
        pinyinFull: String? = nil,
        pinyinAcronym: String? = nil,
        modifiedDate: Date? = nil,
        fileSize: Int = 0
    ) {
        self.name = name
        self.path = path
        self.extension = `extension`
        self.isApp = isApp
        self.isDirectory = isDirectory
        self.pinyinFull = pinyinFull
        self.pinyinAcronym = pinyinAcronym
        self.modifiedDate = modifiedDate
        self.fileSize = fileSize
    }
}

// MARK: - SQLite Transient

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
