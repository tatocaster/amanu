import Foundation
import Testing
@testable import amanu

struct GeorgianRealModelTests {
    /// Opt-in ABI/model smoke test. It catches a framework that compiles but
    /// cannot load the exact GGUF we publish in setup.
    @Test(
        "The published Georgian GGUF transcribes real Georgian audio",
        .enabled(if:
            ProcessInfo.processInfo.environment["AMANU_GEORGIAN_GGUF"] != nil
                && ProcessInfo.processInfo.environment["AMANU_GEORGIAN_AUDIO"] != nil))
    func publishedModelSmokeTest() async throws {
        let modelPath = ProcessInfo.processInfo.environment["AMANU_GEORGIAN_GGUF"]!
        let audioPath = ProcessInfo.processInfo.environment["AMANU_GEORGIAN_AUDIO"]!
        let manifest = GeorgianModelStore.defaultManifest
        let model = URL(fileURLWithPath: modelPath)
        let store = GeorgianModelStore(
            directory: model.deletingLastPathComponent(),
            manifest: .init(
                id: manifest.id,
                fileName: model.lastPathComponent,
                revision: manifest.revision,
                downloadURL: manifest.downloadURL,
                expectedBytes: manifest.expectedBytes,
                sha256: manifest.sha256)) { _, _, _ in
                    Issue.record("the supplied real model must not download")
                }
        let engine = GeorgianEngine(modelStore: store)
        try await engine.prepare()

        let segments = try await engine.transcribe(URL(fileURLWithPath: audioPath))

        #expect(!segments.isEmpty)
        #expect(segments.contains { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
        // Mkhedruli is the Georgian script; Latin or Cyrillic output would mean
        // the wrong model or language path was loaded.
        #expect(segments.contains { $0.text.unicodeScalars.contains { (0x10D0...0x10FF).contains($0.value) } })
        await engine.release()
    }
}
