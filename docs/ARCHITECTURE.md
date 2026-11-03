# FrameGenNG architecture

```text
BeamNG DX12 + supported temporal upscaler
or BeamNG Vulkan + FSR 3/FSR 4 (experimental)
        │
        ▼
FrameGenNG rendering bridge (dxgi.dll)
  ├─ receives color, depth, and motion vectors
  ├─ reads FrameGenNG settings from the BeamNG user folder
  ├─ adapts the presentation path used by Frame Generation
  └─ signals shutdown safely to NGX
        │
        ├─ DLSS ─► NVIDIA DLSS Frame Generation
        ├─ FSR 3/FSR 4 ─► AMD FidelityFX Frame Generation
        └─ XeSS ─► Intel XeSS Frame Generation
        │
        ▼
Swapchain with generated frames
```

The Vulkan branch supports the FSR 3 and FSR 4 upscalers with the monolithic FidelityFX SDK 1.1.4 Vulkan provider. Keeping this provider isolated avoids mixing its lifecycle with the incompatible split-loader swapchain lifecycle. Vulkan presentation hooks are installed only for the FidelityFX path. DLSS-G, XeSS-FG, and other unsupported Vulkan modes clear the native FrameGenNG backend state and remain on BeamNG's untouched presentation path.

## BeamNG integration

The installer adds two controls below the supported upscaling settings:

- Frame Generation enable/disable;
- a 2×–4× multiplier for DLSS; FSR and XeSS use their fixed 2× path.

The controls are visible for DLSS, FSR 3, FSR 4, and XeSS. They remain hidden for BeamNG's internal FSR 3 (Custom) mode because that path does not expose compatible vendor API inputs. At startup, the DLL reads the selected upscaler and chooses the corresponding Frame Generation engine. A runtime upscaler change pauses Frame Generation until the next game launch, avoiding unsafe backend replacement while a swapchain is active. The DLL continues to poll enable and multiplier settings at most twice per second. Its separate overlay, shortcuts, splash screen, debugging UI, plugin loading, sharpening, output scaling, and magnifier remain disabled in the production configuration.

A small, version-checked shader override keeps BeamNG's native SDR and scRGB mode values under Vulkan, while the DirectX 12 branch can route BeamNG's HDR output through the existing HDR10 encoder. The original shader in the Steam installation is never modified: the generated override is stored at the same relative path in BeamNG's user folder. The DirectX 12 bridge activates only when Windows HDR is active and BeamNG requests HDR; Vulkan never uses that bridge. Installation stops on an unknown vanilla shader layout instead of applying an unverified text replacement.

A GELua extension writes a signal during `onPreExit`. The DLL observes it before D3D12 teardown and avoids unsafe late NGX shutdown calls.

## Reversible installation

The manager applies changes as a transaction: validate every payload hash, reject proxy and HDR-override collisions, back up existing user overrides, generate the shader and interface overrides from the current vanilla files, invalidate BeamNG's rendering shader cache, then record installation state. Uninstall removes targets that are still recognized as FrameGenNG files and invalidates the same disposable cache. A game-folder target replaced by BeamNG or another tool is copied to recovery storage and preserved instead of being deleted or overwritten with an older backup. If an installation step fails, already changed targets are restored. The state records SHA-256 hashes and is duplicated inside its uniquely named backup folder so uninstall can recover from a missing primary state file.

FrameGenNG does not infer whether BeamNG was updated. The user starts **Reinstall after game update**, which removes the previous integration and creates a fresh baseline from the current BeamNG files. Legacy installation states that modified a game file are still removed conservatively: a game file changed outside FrameGenNG is preserved instead of being replaced by an older backup. If such a preserved file conflicts with the new integration, reinstallation stops and leaves the unknown file untouched rather than risking the updated game installation.

The rendering layer starts with Frame Generation disabled. Valid BeamNG settings enable it after startup; missing or invalid settings therefore leave BeamNG without Frame Generation instead of enabling an uncontrolled default.

## Update transaction

The manager queries the public GitHub Releases API and selects the newest compatible semantic version. Drafts and prereleases are ignored. The release ZIP and sidecar SHA-256 asset must both be present.

After download, FrameGenNG validates the checksum, optional GitHub asset digest, ZIP root, required files, embedded `VERSION`, payload manifest, sizes, and payload hashes. A helper process then waits for the manager to close, records the current FG settings, uninstalls the active integration, backs up and replaces the complete package, installs the new version, and restores the settings. A failed new installation triggers the inverse transaction using the preserved package backup.

## Restore points and retention

Durable restore points live under `FrameGenNG\restore-points` in the BeamNG user folder. Each point contains English metadata and a SHA-256-protected package snapshot, together with the recorded install/profile state, BeamNG executable identity, and Frame Generation settings. Automatic points are created before installation, reinstall, update, uninstall, and restore. A restore operation first creates another safety point, then uses the same transactional package-swap and rollback path as an update.

The manager retains the five newest automatic points. Manual points are kept until the user deletes them, with a limit of ten to prevent accidental unbounded growth. Short-lived package rollback copies are removed after a successful transaction, while obsolete technical install/recovery backups are capped separately. Restore is refused when the current BeamNG executable differs from the snapshot identity; **Reinstall after game update** is the correct path after a game update.

## Diagnostics

Standard diagnostics read the existing installation state and managed-file hashes without enabling persistent logging. Advanced mode is an explicit, persisted opt-in under the BeamNG user folder. It records manager actions and errors only; it does not introduce per-frame game instrumentation. Manager logs rotate at 2 MB and only the seven newest files are retained.

Diagnostic export is user-initiated. It stages a structured report plus bounded log excerpts, installation/update state, payload metadata, and GPU/driver information, then writes a ZIP under `FrameGenNG\diagnostics\exports`. Temporary staging data is removed in a `finally` block and only the five newest exported bundles are retained. The UI warns that logs and recorded paths may contain personal information before export.

## Manager boundaries

The manager script coordinates user actions and status refreshes. Core installation, update, and diagnostic behavior remains in dedicated modules. Restore-point and backup-retention behavior is isolated in `manager/Core/FrameGenNG.Recovery.ps1` and loaded into the core module scope. Shared WinForms dialog and button construction lives in `manager/FrameGenNG.Ui.psm1`, keeping presentation details out of the transaction modules.

