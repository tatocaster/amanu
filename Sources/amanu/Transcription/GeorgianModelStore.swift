import Foundation

/// The revision-pinned Georgian NeMo model consumed by transcribe.cpp: the
/// FastConformer RNN-T from EchoesML/Georgian-NeMo, as LeonardoDaviti's GGUF.
/// Downloading, verifying and sharing it is `VerifiedModelStore`'s job.
struct GeorgianModelStore: Sendable {
    typealias Manifest = VerifiedModelStore.Manifest
    typealias Progress = VerifiedModelStore.Progress
    typealias Error = VerifiedModelStore.Error
    typealias ProgressHandler = VerifiedModelStore.ProgressHandler
    typealias Downloader = VerifiedModelStore.Downloader

    // Q8_0 is the quantisation this engine was tested with; it is about
    // 129 MiB, half the size of the GigaAM model it replaced.
    static let defaultManifest = Manifest(
        id: "georgian-nemo-q8_0",
        fileName: "georgian-nemo-Q8_0.gguf",
        revision: "deb86504b4e4374429442046fc598be035674e82",
        downloadURL: URL(string:
            "https://huggingface.co/LeonardoDaviti/Georgian-NeMo-GGUF/resolve/deb86504b4e4374429442046fc598be035674e82/georgian-nemo-Q8_0.gguf?download=true"
        )!,
        expectedBytes: 135_383_168,
        sha256: "5e43433e5ac6933bafcc191a5d518cfe50c66e33d205f29fcc491bfc4fe49625")

    static let advertisedDownloadBytes: Int64 = defaultManifest.expectedBytes

    private let store: VerifiedModelStore

    init(
        directory: URL = Home.current.url
            .appendingPathComponent("Library/Application Support/amanu/models/georgian", isDirectory: true),
        manifest: Manifest = GeorgianModelStore.defaultManifest,
        downloader: @escaping Downloader = { try await ModelDownloader.download(source: $0, partial: $1, progress: $2) }
    ) {
        store = VerifiedModelStore(directory: directory, manifest: manifest, downloader: downloader)
    }

    var directory: URL { store.directory }
    var manifest: Manifest { store.manifest }
    var modelURL: URL { store.modelURL }
    var partialURL: URL { store.partialURL }
    var bytesOnDisk: Int { store.bytesOnDisk }

    func download(progress: @escaping ProgressHandler = { _ in }) async throws -> URL {
        try await store.download(progress: progress)
    }

    func delete() throws { try store.delete() }
}
