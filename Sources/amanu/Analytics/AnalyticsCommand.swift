import ArgumentParser
import Foundation

/// `amanu analytics` — kept registered so scripts and muscle memory still get
/// an answer, but analytics is removed in this fork.
struct AnalyticsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analytics",
        abstract: "Analytics is removed from this build."
    )

    // Accepted and ignored, so `amanu analytics off` still works.
    @Argument(help: .hidden)
    var state: String?

    func run() throws {
        print("analytics: removed from this build — nothing is collected or sent.")
    }
}
