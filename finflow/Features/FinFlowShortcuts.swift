import AppIntents

nonisolated struct FinFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Add an expense with \(.applicationName)"
            ],
            shortTitle: "Log an expense",
            systemImageName: "mic.fill"
        )
    }
}
