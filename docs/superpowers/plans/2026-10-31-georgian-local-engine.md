# Georgian Local Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the GigaAM local engine with a Georgian engine. It runs
the community GGUF of EchoesML/Georgian-NeMo through the transcribe.cpp
runtime amanu already links. It can be chosen as the default local engine,
and it appears in the Recordings window's "Re-transcribe with…" menu.

**Architecture:** GigaAM's code is already a generic transcribe.cpp GGUF
engine: a verified download, 20 s chunking, `transcribe_run`. So this is a
rename plus a new manifest, not new machinery. Task 1 renames the types and
swaps the model. Task 2 renames the engine id `gigaam` → `georgian` on every
user-facing surface. Task 3 updates the docs and runs the real-model check.

**Tech Stack:** Swift 6 / SwiftPM, swift-testing (`@Test`, `#expect`), AppKit,
CTranscribe (transcribe.cpp v0.2.0 xcframework, unchanged).

**Spec:** `docs/specs/2026-10-31-georgian-local-engine-design.md`

## Global Constraints

- Model manifest, copied verbatim from the spec:
  - id `georgian-nemo-q8_0`
  - fileName `georgian-nemo-Q8_0.gguf`
  - revision `deb86504b4e4374429442046fc598be035674e82`
  - downloadURL `https://huggingface.co/LeonardoDaviti/Georgian-NeMo-GGUF/resolve/deb86504b4e4374429442046fc598be035674e82/georgian-nemo-Q8_0.gguf?download=true`
  - expectedBytes `135_383_168`
  - sha256 `5e43433e5ac6933bafcc191a5d518cfe50c66e33d205f29fcc491bfc4fe49625`
- Model directory: `~/Library/Application Support/amanu/models/georgian`.
- Engine id (config, session state, provenance, menus): `georgian`.
  - Display name: `Georgian`.
  - Setup card title: `Georgian (NeMo)`.
  - Card detail: `Georgian only · about 135 MB` / `Только грузинский · около 135 МБ`.
- `Package.swift` and the transcribe.cpp version are not touched.
  `params.language` stays `nil`, which is what was tested.
- Chunk duration stays at 20 s.
- `TranscriptVersions` keeps its `"gigaam" → "GigaAM"` label for old
  versions. Past `docs/release-notes-*.md` are not edited.
- Live transcription (Nemotron) is not touched.
- Commit messages follow `CLAUDE.md`: one prose sentence, no `feat:`
  prefix. Code comments explain why, in full sentences.
- Work on a branch, `georgian-engine`, never on `master`.

## Review Focus

1. **A config still saying `local_engine = "gigaam"`** should warn and
   fall back to parakeet, not fail or crash. Tested in Task 2.
2. **A config still saying `engine = "gigaam"`** should be treated as
   `auto`, like any unknown name. Tested in Task 2.
3. **Re-transcribing a session whose state names `gigaam`**: the
   `configuredEngine(for:)` filter must drop the unknown name and use the
   configured engine. Tested in Task 2.
4. **Old transcript versions made with GigaAM** should still show "GigaAM"
   in the versions list. Tested in Task 2.
5. **A leftover `models/gigaam` folder on disk** should not appear in model
   storage or be counted. Tested in Task 1.

---

### Task 1: Rename the engine types and swap in the Georgian model

**Files:**
- Rename (`git mv`) and edit:
  - `Sources/amanu/Transcription/GigaAMModelStore.swift` → `GeorgianModelStore.swift`
  - `Sources/amanu/Transcription/GigaAMEngine.swift` → `GeorgianEngine.swift`
- Modify:
  - `Sources/amanu/Transcription/ModelStorage.swift`
  - `Sources/amanu/Transcription/EngineResolver.swift:177`
  - `Sources/amanu/UI/SettingsWindow.swift:415,495`
  - `Sources/amanu/UI/SetupForm.swift` (type and variable names only:
    `gigaAMModelStore`, `gigaAMDownloadTask`, `downloadGigaAMIfNeeded`,
    `modelStorage.gigaAMModel()`)
  - `Sources/amanu/Analytics/AnalyticsCatalogue.swift:149` (type reference only)
  - Comment mentions in `DedicatedThread.swift:6` and `ParakeetEngine.swift:31`
- Rename and edit tests:
  - `Tests/amanuTests/Transcription/GigaAMEngineTests.swift` → `GeorgianEngineTests.swift`
  - `GigaAMModelStoreTests.swift` → `GeorgianModelStoreTests.swift`
  - `GigaAMRealModelTests.swift` → `GeorgianRealModelTests.swift`
- Modify tests:
  - `EmptyTrackTests.swift:93`
  - `EngineVocabularyTests.swift:22`
  - `ModelStorageTests.swift:39,65,76,90`
  - `InterfaceLanguageTests.swift:595`

**Interfaces:**
- Produces:
  - `struct GeorgianModelStore` with the same API as `GigaAMModelStore`,
    `static let defaultManifest` set to the Global Constraints values, and
    `advertisedDownloadBytes`.
  - `actor GeorgianEngine: TranscriptionEngine` with the same init
    signature as `GigaAMEngine` (`modelStore:runtime:chunkDuration:progress:`).
  - `protocol GeorgianRuntime`, `GeorgianCPPRuntime`, `GeorgianRunState`.
  - `ModelStorage.Model.Kind.georgian` and `ModelStorage.georgianModel() -> Model`.
- In this task `GeorgianEngine.name` is still `"gigaam"`. Task 2 flips
  it, together with every other occurrence of the id string, so config
  and engine never disagree.

- [ ] **Step 1: Branch.** `git switch -c georgian-engine`

- [ ] **Step 2: Write the failing tests.**
  - In `GeorgianModelStoreTests` add
    `@Test("The default manifest pins the Georgian NeMo GGUF")`. It asserts
    every Global Constraints manifest field on
    `GeorgianModelStore.defaultManifest`, plus
    `GeorgianModelStore.advertisedDownloadBytes == 135_383_168`.
  - Add `@Test("The default store lives in models/georgian")`. It asserts
    `GeorgianModelStore().directory.path.hasSuffix("amanu/models/georgian")`.
  - In `GeorgianEngineTests`, change the model assertion to
    `#expect(engine.model == "georgian-nemo-q8_0")` and the fixture
    manifest id to the same value.
  - In `ModelStorageTests`, the expected names list replaces
    `"GigaAM v3"` with `"Georgian (NeMo)"`.
  - Add `@Test("A leftover GigaAM folder is not listed")`. It creates
    `root/gigaam/x.gguf` with bytes, builds `ModelStorage` with
    `georgian: GeorgianModelStore(directory: root.appendingPathComponent("georgian"))`,
    and asserts no model's directory ends in `gigaam` and the Georgian
    model's `bytes == 0`.
  - In `InterfaceLanguageTests:595`, replace `"GigaAM v3"` with
    `"Georgian (NeMo)"`.

- [ ] **Step 3: Run them and confirm they fail.**
  Run `swift test --filter 'Georgian|ModelStorage'`. Expect a compile
  failure, `cannot find 'GeorgianModelStore'`.

- [ ] **Step 4: Do the rename and the manifest swap.**
  - `git mv` the two source files and three test files, then rename every
    `GigaAM*` type and `gigaAM*` identifier listed above.
  - Set the manifest and directory `models/georgian`.
  - In `ModelStorage`:
    - Rename the init parameter `gigaAM:` to `georgian:`.
    - `georgianModel()` returns kind `.georgian`, name `"Georgian (NeMo)"`.
    - In the delete switch, `deleted = "georgian"`.
  - In `SettingsWindow.purpose(of: .georgian)`:
    `"Local Georgian transcription with transcribe.cpp."` /
    `"Локальная грузинская расшифровка через transcribe.cpp."`.
  - Rewrite the engine and store doc comments to say this is Georgian
    FastConformer RNN-T, from EchoesML/Georgian-NeMo via LeonardoDaviti's
    GGUF. Explain that 20 s chunking was kept because it is tested, not
    because the model needs it.
  - In `GeorgianRealModelTests`, rename the env vars to
    `AMANU_GEORGIAN_GGUF` / `AMANU_GEORGIAN_AUDIO`. Add
    `#expect(segments.contains { $0.text.unicodeScalars.contains { (0x10D0...0x10FF).contains($0.value) } })`,
    which checks for Georgian Mkhedruli script.

- [ ] **Step 5: Run the tests and confirm they pass.**
  Run `swift test --filter 'Georgian|ModelStorage|EmptyTrack|EngineVocabulary|InterfaceLanguage'`.
  Expect them to pass; the real-model test is skipped because the env vars
  are unset.

- [ ] **Step 6: Run the full suite.** `swift test`. Expect it to pass.

- [ ] **Step 7: Commit.**
  `git commit -m "Swap GigaAM's model for the Georgian NeMo GGUF, keeping the transcribe.cpp engine it ran on."`

---

### Task 2: Rename the engine id `gigaam` → `georgian` everywhere a person or config sees it

**Files:**
- Modify:
  - `Sources/amanu/Transcription/GeorgianEngine.swift` (`name = "georgian"`)
  - `Sources/amanu/Config.swift:102`
  - `Sources/amanu/Settings/SettingsSchema.swift:137,161,172`
  - `Sources/amanu/Transcription/EngineResolver.swift:177`
  - `Sources/amanu/UI/RecordingsWindow.swift:21`
  - `Sources/amanu/UI/SetupForm.swift`:
    - the card tuple at `:401`
    - the `"gigaam"` cases at `:1235, :1244, :1262, :1269, :1281, :1650, :1889, :1901, :1909`
  - `Sources/amanu/Setup/SetupProgress.swift:182`
  - `Sources/amanu/Analytics/AnalyticsCatalogue.swift:148-149`
- Leave `Sources/amanu/Sessions/TranscriptVersions.swift:149` as it is.
- Tests:
  - `SetupTests.swift:698-746`
  - `SettingsSchemaTests.swift:480-489`
  - `SetupProgressTests.swift:57`
  - `EngineSelectionTests.swift:55-59`
  - `RetranscriptionTests.swift:509`
  - `GeorgianEngineTests.swift:20`
  - `ConfigFileTests.swift`
  - the existing `TranscriptVersions` tests

**Interfaces:**
- Consumes: `GeorgianEngine`, `GeorgianModelStore` and `ModelStorage.georgianModel()` from Task 1.
- Produces: engine id `"georgian"` in:
  - `Config.localEngines`
  - all three `SettingsSchema` choice lists
  - `RecordingsWindow.retranscriptionEngines`, as `.init(id: "georgian", title: "Georgian")`
  - analytics asset `"georgian-nemo"`

- [ ] **Step 1: Write and retarget the failing tests.**
  - **Existing tests to retarget:**
    - `GeorgianEngineTests`: `#expect(engine.name == "georgian")`.
    - `EngineSelectionTests`: the `gigaAMIsLocal` test becomes
      `georgianIsLocal`, with the same three expectations on `"georgian"`.
    - `SettingsSchemaTests`: `georgianIsInLocalEngineChoices` expects
      `options.contains("georgian")` and `!options.contains("gigaam")`.
    - `SetupTests`: the card id is `"georgian"`, and the copy contains
      `"Georgian only"` and `"135 MB"`. The download-button loop uses
      `["parakeet", "whisper", "georgian"]`. The click test expects
      `store.localEngine == "georgian"`.
    - `SetupProgressTests`: the tuple is `("georgian", "Georgian")`.
    - `RetranscriptionTests:509`: the list is
      `["parakeet", "whisper", "georgian", "assemblyai", "openai", "elevenlabs"]`.
  - **New tests:**
    - Review Focus 2, in `EngineSelectionTests`:
      `@Test("A config still naming gigaam is treated as auto")` asserts
      `Self.choice("gigaam", key: true, localModels: true) == .cloudOrLocal`.
    - Review Focus 1, in `ConfigFileTests`, following that file's existing
      config-fixture pattern:
      `@Test("A legacy gigaam local engine falls back to parakeet")` writes
      `local_engine = "gigaam"` and asserts
      `Config.transcriptionLocalEngine() == "parakeet"`.
    - Review Focus 3, in `RetranscriptionTests`:
      `@Test("A session marked for gigaam re-transcribes with the configured engine")`
      writes `SessionState.Key.transcriptionEngine = "gigaam"` into a
      fixture session and asserts
      `EngineResolver.configuredEngine(for:) == Config.transcriptionEngine()`.
    - Review Focus 4, alongside the existing `TranscriptVersions` tests:
      `@Test("Versions made with GigaAM keep their name")` asserts
      `RecordingsEngineName.name("gigaam") == "GigaAM"` and
      `RecordingsEngineName.name("georgian") == "Georgian"`.
      - Drop `private` from `enum RecordingsEngineName`
        (`TranscriptVersions.swift:144`) so the test can reach it.
      - Add `case "georgian": return "Georgian"` next to the gigaam case.

- [ ] **Step 2: Run them and confirm they fail.**
  Run `swift test --filter 'EngineSelection|SettingsSchema|Setup|Retranscription|Georgian|ConfigFile|TranscriptVersions'`.
  Expect the retargeted assertions to fail on `"gigaam"` versus `"georgian"`.

- [ ] **Step 3: Rename the id across the listed sources.**
  - Card tuple: `("georgian", "Georgian (NeMo)", localised("Georgian only · about 135 MB", "Только грузинский · около 135 МБ"))`.
  - `localModelMegabytes`: `case "georgian": 135`.
  - Download asset string: `"georgian-nemo-q8_0"`.
  - `AnalyticsCatalogue`:
    `case "georgian": return provenance == GeorgianModelStore.defaultManifest.id ? "georgian-nemo" : "custom"`.
  - `SetupProgress`: `case "georgian": return "Georgian"`.
  - After the edit, `grep -rn '"gigaam"' Sources` must show only
    `TranscriptVersions.swift`.

- [ ] **Step 4: Run the tests and confirm they pass.**
  Run the same filter, then the full `swift test`. Expect both to pass.

- [ ] **Step 5: Render the setup window.**
  Follow `docs/testing/window-shots.md` to render the setup window in both
  appearances. Look at the Georgian card: the text must not be truncated
  or overlap anything.

- [ ] **Step 6: Commit.**
  `git commit -m "Offer the Georgian engine under its own name in setup, settings and the re-transcribe menu, letting configs that still say gigaam fall back as unknown engines do."`

---

### Task 3: Update the docs and check against the real model

**Files:**
- Modify:
  - `README.md:21,68,439-440,544`: GigaAM becomes Georgian, about 135 MB,
    Georgian-only. Add a line crediting EchoesML/Georgian-NeMo, noting
    its research-and-education license.
  - `PRIVACY.md:12`
  - `docs/analytics.md:106,109` (`georgian` / `georgian-nemo`)
  - `docs/pitfalls.md:467` (rename only)
  - `docs/testing/setup-window-manual-checklist.md:179`
- `THIRD-PARTY-NOTICES.md` lists no downloaded models today, GigaAM's
  included, so it stays as it is.

- [ ] **Step 1: Make the doc edits above.**
  Then `grep -rn -i gigaam README.md PRIVACY.md docs/analytics.md docs/pitfalls.md docs/testing`
  must return nothing.

- [ ] **Step 2: Run the real-model test.** It uses the GGUF and the FLEURS
  clips that were downloaded and verified during design. Convert a clip
  first if the reader cannot take WAV.

```bash
AMANU_GEORGIAN_GGUF=/private/tmp/claude-501/-Users-tatocaster-Projects-amanu/9e133780-6110-43bb-9eed-99ce7509679e/scratchpad/model/georgian-nemo-Q8_0.gguf \
AMANU_GEORGIAN_AUDIO=/private/tmp/claude-501/-Users-tatocaster-Projects-amanu/9e133780-6110-43bb-9eed-99ce7509679e/scratchpad/audio/10206813105541211669.wav \
swift test --filter GeorgianRealModel
```

  Expect it to pass, with segments in Georgian script.

- [ ] **Step 3: Build the app.** `make app`. Expect `.build/Amanu.app` to
  build and be signed.

- [ ] **Step 4: Commit.**
  `git commit -m "Describe the Georgian engine where the docs described GigaAM."`

- [ ] **Step 5: Hand off for the manual check.**
  These steps need a person:
  1. Quit Amanu.
  2. `cp -R .build/Amanu.app /Applications/`
  3. Pick Georgian in setup and watch the ~135 MB download finish.
  4. Record or import Georgian audio.
  5. Right-click the recording → "Re-transcribe with Georgian".
