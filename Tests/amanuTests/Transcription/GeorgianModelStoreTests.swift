import Foundation
import os
import Testing
@testable import amanu

struct GeorgianModelStoreTests {
    private let payload = Data("georgian model bytes".utf8)
    private let sha256 = "442de2a02580f805d19af697c86dd54b591ee1c72681980c379df7fb80445979"

    @Test("The default manifest pins the Georgian NeMo GGUF")
    func defaultManifestPinsGeorgianNeMo() {
        let manifest = GeorgianModelStore.defaultManifest
        #expect(manifest.id == "georgian-nemo-q8_0")
        #expect(manifest.fileName == "georgian-nemo-Q8_0.gguf")
        #expect(manifest.revision == "deb86504b4e4374429442046fc598be035674e82")
        #expect(manifest.downloadURL.absoluteString == "https://huggingface.co/LeonardoDaviti/Georgian-NeMo-GGUF/resolve/deb86504b4e4374429442046fc598be035674e82/georgian-nemo-Q8_0.gguf?download=true")
        #expect(manifest.expectedBytes == 135_383_168)
        #expect(manifest.sha256 == "5e43433e5ac6933bafcc191a5d518cfe50c66e33d205f29fcc491bfc4fe49625")
        #expect(GeorgianModelStore.advertisedDownloadBytes == 135_383_168)
    }

    @Test("The default store lives in models/georgian")
    func defaultDirectory() {
        #expect(GeorgianModelStore().directory.path.hasSuffix("amanu/models/georgian"))
    }

    @Test("A verified Georgian model is installed atomically with byte progress")
    func verifiedDownload() async throws {
        let directory = temporaryDirectory()
        let manifest = fixtureManifest(sha256: sha256)
        let updates = OSAllocatedUnfairLock(initialState: [GeorgianModelStore.Progress]())
        let payload = payload
        let store = GeorgianModelStore(directory: directory, manifest: manifest) {
            _, partial, progress in
            try payload.write(to: partial)
            progress(.init(receivedBytes: Int64(payload.count), totalBytes: Int64(payload.count)))
        }

        let installed = try await store.download { update in
            updates.withLock { $0.append(update) }
        }

        #expect(try Data(contentsOf: installed) == payload)
        #expect(!FileManager.default.fileExists(atPath: installed.path + ".partial"))
        #expect(updates.withLock { $0.last?.fraction } == 1)
    }

    @Test("A corrupt Georgian download is removed")
    func corruptDownload() async throws {
        let directory = temporaryDirectory()
        let manifest = fixtureManifest(sha256: String(repeating: "0", count: 64))
        let payload = payload
        let store = GeorgianModelStore(directory: directory, manifest: manifest) {
            _, partial, _ in try payload.write(to: partial)
        }

        await #expect(throws: GeorgianModelStore.Error.invalidSHA256) {
            try await store.download()
        }
        #expect(!FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(manifest.fileName).path))
    }

    private func fixtureManifest(sha256: String) -> GeorgianModelStore.Manifest {
        .init(
            id: "fixture",
            fileName: "fixture.gguf",
            revision: "075dff81f843cf23d22b4ce943ffdc4dd8650cd7",
            downloadURL: URL(string: "https://example.test/fixture.gguf")!,
            expectedBytes: Int64(payload.count),
            sha256: sha256)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("amanu-georgian-store-\(UUID().uuidString)")
    }
}
