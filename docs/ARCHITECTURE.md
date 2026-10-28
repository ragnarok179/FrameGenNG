# FrameGenNG architecture

```text
BeamNG DX12 + DLSS SR
        │
        ▼
FrameGenNG rendering bridge (dxgi.dll)
  ├─ receives color, depth, and motion vectors
  ├─ reads FrameGenNG settings from the BeamNG user folder
  ├─ adapts the presentation path used by Frame Generation
  └─ signals shutdown safely to NGX
        │
        ├─ RTX 20/30 ─► FrameGenNG compatibility engine (d3d12.dll + SM75/SM86 kernels)
        │
        └─ RTX 40/50 ─► native DLSS-G runtime
        │
        ▼
Swapchain with generated frames
```

## BeamNG integration

The installer adds two controls below the DLSS settings:

- Frame Generation enable/disable;
- a 2×, 3×, or 4× multiplier.

The controls are hidden when DLSS is not selected. The DLL reads the settings at most twice per second. Its separate overlay, shortcuts, splash screen, debugging UI, alternative upscalers, plugin loading, sharpening, output scaling, and magnifier are disabled in the production configuration.

A small, version-checked shader patch can route BeamNG's scRGB output mode through the game's existing HDR10 encoder when the optional FrameGenNG HDR10 bridge is enabled. This keeps the encoded pixels and the advertised DXGI color space aligned. The distributed configuration leaves the bridge disabled for SDR safety. Installation stops on an unknown shader layout instead of applying an unverified text replacement.

A GELua extension writes a signal during `onPreExit`. The DLL observes it before D3D12 teardown and avoids unsafe late NGX shutdown calls.

## Reversible installation

The manager applies changes as a transaction: validate every payload hash, reject proxy collisions, back up existing user overrides and the HDR encoder, copy, patch the shader and interface, invalidate BeamNG's rendering shader cache, then record installation state. Uninstall invalidates the same disposable cache after restoring the vanilla encoder. If a step fails, already changed targets are restored. The state records SHA-256 hashes and is duplicated inside its backup folder so uninstall can recover from a missing primary state file.

The state also records the BeamNG executable identity and the hashes of the UI sources. A changed identity marks the installation as requiring repair. During removal after a game update, a game file whose content no longer matches the installed mod is preserved instead of being replaced by a backup from the previous BeamNG version.

## Update transaction

The manager queries the public GitHub Releases API and selects the newest compatible semantic version. Drafts and prereleases are ignored. The release ZIP and sidecar SHA-256 asset must both be present.

After download, FrameGenNG validates the checksum, optional GitHub asset digest, ZIP root, required files, embedded `VERSION`, payload manifest, sizes, and payload hashes. A helper process then waits for the manager to close, records the current FG settings, uninstalls the active integration, backs up and replaces the complete package, installs the new version, and restores the settings. A failed new installation triggers the inverse transaction using the preserved package backup.

## Restore points and retention

Durable restore points live under `FrameGenNG\restore-points` in the BeamNG user folder. Each point contains English metadata and a SHA-256-protected package snapshot, together with the recorded install/profile state, BeamNG executable identity, and Frame Generation settings. Automatic points are created before installation, repair, update, uninstall, and restore. A restore operation first creates another safety point, then uses the same transactional package-swap and rollback path as an update.

The manager retains the five newest automatic points. Manual points are kept until the user deletes them, with a limit of ten to prevent accidental unbounded growth. Short-lived package rollback copies are removed after a successful transaction, while obsolete technical install/recovery backups are capped separately. Restore is refused when the current BeamNG executable differs from the snapshot identity; Repair is the correct path after a game update.

## Diagnostics

Standard diagnostics read the existing installation state and managed-file hashes without enabling persistent logging. Advanced mode is an explicit, persisted opt-in under the BeamNG user folder. It records manager actions and errors only; it does not introduce per-frame game instrumentation. Manager logs rotate at 2 MB and only the seven newest files are retained.

Diagnostic export is user-initiated. It stages a structured report plus bounded log excerpts, installation/update state, payload metadata, and GPU/driver information, then writes a ZIP under `FrameGenNG\diagnostics\exports`. Temporary staging data is removed in a `finally` block and only the five newest exported bundles are retained. The UI warns that logs and recorded paths may contain personal information before export.

## Manager boundaries

The manager script coordinates user actions and status refreshes. Core installation, update, and diagnostic behavior remains in dedicated modules. Restore-point and backup-retention behavior is isolated in `manager/Core/FrameGenNG.Recovery.ps1` and loaded into the core module scope. Shared WinForms dialog and button construction lives in `manager/FrameGenNG.Ui.psm1`, keeping presentation details out of the transaction modules.

