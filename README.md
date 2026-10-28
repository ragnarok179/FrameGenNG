# FrameGenNG

Frame Generation integrated into the BeamNG.drive graphics settings.

FrameGenNG uses BeamNG's native DLSS input in DirectX 12 and adds adjustable Frame Generation directly below the game's DLSS options. The project targets the full NVIDIA RTX family:

- RTX 20 and RTX 30: compatibility path powered by `dlssg_for_sm86`;
- RTX 40 and RTX 50: native DLSS-G path through the FrameGenNG integration layer;
- future RTX generations: a compatibility goal after validation.

> **Current validation:** FrameGenNG has been validated on BeamNG.drive 0.40.3.0 with an RTX 3060 Laptop GPU. RTX 20, 40, and 50 GPUs still require testing before compatibility can be guaranteed.

## Requirements

- Windows 10 or 11, 64-bit
- BeamNG.drive running in DirectX 12
- DLSS enabled in BeamNG
- An up-to-date NVIDIA driver
- Enough free VRAM for Frame Generation

No CUDA Toolkit, Python installation, or separate OptiScaler setup is required.

## Quick installation

1. Close BeamNG.drive.
2. Extract the `FrameGenNG` folder directly into the BeamNG.drive root folder, next to `Bin64`.
3. Open `FrameGenNG Manager.cmd`.
4. Select **Install**.
5. Start BeamNG in DirectX 12, enable DLSS, then configure Frame Generation below the DLSS settings.

BeamNG will warn about `dxgi.dll` and, on RTX 20/30, `d3d12.dll`. This is expected: these proxy libraries load the FrameGenNG graphics layer. Select **Cancel** in that warning if you do not want BeamNG to show it again.

## Important notes

- Proxy DLLs can trigger heuristic antivirus or SmartScreen warnings. Download FrameGenNG only from this repository's GitHub Releases page and verify the published SHA-256 checksum.
- Frame Generation uses additional VRAM. If frame times become unstable, reduce texture quality or output resolution and close other GPU-heavy applications.
- Do not combine FrameGenNG with another `dxgi.dll` or `d3d12.dll` proxy unless that combination has been explicitly tested.
- Avoid using FrameGenNG in BeamMP or any anti-cheat-protected session until that environment has explicitly confirmed compatibility.

## Safe removal and recovery

- The complete payload is verified against its SHA-256 manifest before installation.
- Existing BeamNG user-interface overrides and the HDR output shader are backed up before installation.
- Installation stops instead of overwriting another `dxgi.dll` or `d3d12.dll` graphics proxy.
- Uninstall restores the original files instead of only deleting the added DLLs.
- Install, Repair, and Uninstall invalidate BeamNG's rendering shader cache after changing the HDR encoder, preventing stale color-space code from being reused.
- BeamNG settings added by FrameGenNG are removed without overwriting unrelated changes made later.
- If an installed file was modified after installation, a recovery copy is preserved before restoration.
- Backups are stored under `FrameGenNG\backups` in the BeamNG user folder.
- The manager also creates durable restore points before installation, repair, update, uninstall, and restore operations. Open **Restore Points** to create a manual point or return to an earlier compatible FrameGenNG state.
- The five newest automatic restore points are retained. Manual points are never removed automatically; up to ten can be kept and deleted from the manager.
- The installation state is stored twice, so emergency uninstall still works if the primary state file is missing or damaged.
- **Repair** preserves the selected FG state and multiplier, performs a clean restoration, then rebuilds the integration from the current BeamNG files.

Do not manually delete the backup folder before uninstalling FrameGenNG.

Repair and restore serve different purposes: **Repair** rebuilds the current version against the current BeamNG files, while **Restore Points** returns the package, install state, profile, and Frame Generation settings to an earlier snapshot. A restore point is rejected when it was created for a different BeamNG executable, preventing an old integration from being forced onto an updated game.

## Diagnostics

The **Diagnostics** window always provides the standard installation integrity scan. **Advanced diagnostic logging** is optional and disabled by default. When enabled, it records detailed manager actions and errors without adding per-frame logging or affecting driving performance.

Use **Export diagnostic bundle** to create a support ZIP containing a structured report, recent BeamNG and FrameGenNG log excerpts when available, installation state, transaction logs, GPU/driver information, and the payload manifest. The bundle is saved under `FrameGenNG\diagnostics\exports` in the BeamNG user folder; only the five newest exports are retained. It can contain local folder paths and user names from logs, so review it before sharing.

## After a BeamNG update

Open the FrameGenNG Manager before starting the game. The manager fingerprints the BeamNG executable and the integration sources it modifies. If they changed, it reports **BeamNG update detected** and asks for **Repair**.

Repair removes the old integration safely and rebuilds it from the updated game files. If the update placed a new file where FrameGenNG previously installed one, that new game file is preserved and copied to recovery storage instead of being overwritten with an obsolete backup. If the updated BeamNG layout is no longer compatible, installation stops and leaves the game restored rather than forcing an unsafe patch.

## Automatic updates

The manager checks the official GitHub Releases feed when it opens. If a compatible update is available, select **Update to v…** and confirm the operation.

The updater downloads the release ZIP and its SHA-256 file, verifies the archive, every payload file, the embedded version, and the manifest, preserves the current Frame Generation state and multiplier, restores the original game files, backs up the complete installed mod package, replaces it, then installs the new version. If installation fails, it automatically restores the previous package and game integration whenever that version is still compatible with the current BeamNG installation.

FrameGenNG only follows normal published releases and ignores drafts and prereleases. No update is installed without confirmation, and no GitHub account or access token is required.

See [Compatibility](docs/COMPATIBILITY.md), [Troubleshooting](docs/TROUBLESHOOTING.md), and [Architecture](docs/ARCHITECTURE.md) for details.

## Languages

The repository, documentation, logs, and command-line output use English. The in-game FrameGenNG settings automatically follow BeamNG's selected language for English, French, German, and Spanish, with English as the fallback.

## License and credits

FrameGenNG source code and scripts are Copyright (C) 2026 `ragnarok179` and are released under the [GNU General Public License v3.0 or later](LICENSE).

FrameGenNG includes a modified GPLv3 build of [OptiScaler](https://github.com/optiscaler/OptiScaler) and an RTX 20/30 compatibility path based on [dlssg_for_sm86](https://github.com/sdli1995/dlssg_for_sm86) by `sdli1995`, including the RTX 20/SM75 adaptation credited upstream to `Coldwood1026`. NVIDIA, Streamline, NGX, and other bundled third-party components remain under their own terms. See [NOTICE](NOTICE) and [Third-party notices](THIRD_PARTY_NOTICES.md).

FrameGenNG is an independent community project and is not affiliated with or endorsed by BeamNG, NVIDIA, OptiScaler, or the authors of `dlssg_for_sm86`.

