import Foundation
import SwiftData

nonisolated enum FinFlowStore {
    static let groupID = "group.in.akshaux.finflow"

    static func container() throws -> ModelContainer {
        migrateLegacyIfNeeded()
        let configuration = ModelConfiguration(url: storeURL())
        return try ModelContainer(for: Expense.self, configurations: configuration)
    }

    static func storeURL() -> URL {
        let folder = storeFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "Expenses.store")
    }

    private static func storeFolder() -> URL {
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return group.appending(path: "FinFlow", directoryHint: .isDirectory)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appending(path: "FinFlow", directoryHint: .isDirectory)
    }

    private static func migrateLegacyIfNeeded() {
        let destination = storeURL()
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination.path) else { return }
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let roots = [support, support.appending(path: "in.akshaux.finflow")]
        for root in roots {
            let primary = root.appending(path: "default.store")
            guard fileManager.fileExists(atPath: primary.path) else { continue }
            try? fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] {
                let source = URL(fileURLWithPath: primary.path + suffix)
                let copy = URL(fileURLWithPath: destination.path + suffix)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                try? fileManager.copyItem(at: source, to: copy)
            }
            return
        }
    }
}
