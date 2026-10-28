# FrameGenNG

Frame Generation integrated into the BeamNG.drive graphics settings.

FrameGenNG uses BeamNG's native DLSS input in DirectX 12 and adds adjustable Frame Generation directly below the game's DLSS options. The project targets GeForce RTX 20, 30, 40, and 50 series GPUs:

- RTX 20 and RTX 30: compatibility path powered by `dlssg_for_sm86`;
- RTX 40 and RTX 50: native DLSS-G path through the FrameGenNG integration layer;
- future RTX generations: a compatibility goal after validation, not a current guarantee.

> **Current validation:** FrameGenNG has been validated on BeamNG.drive 0.40.3.0 with an RTX 3060 Laptop GPU. RTX 20, 40, and 50 GPUs still require testing before compatibility can be guaranteed.

## Requirements

- Windows 10 version 2004 (build 19041) or newer, or Windows 11, 64-bit
- BeamNG.drive running in DirectX 12
- DLSS enabled in BeamNG
- Hardware-accelerated GPU scheduling enabled in Windows
- An up-to-date NVIDIA driver; R580 or newer is recommended for the RTX 20/30 compatibility path
- Enough free VRAM for Frame Generation

No CUDA Toolkit, Python installation, or separate OptiScaler setup is required.

FrameGenNG automatically supports the consumer GeForce RTX 20/30/40/50 naming scheme. Professional RTX A/PRO models and future RTX generations are not currently guaranteed and may be rejected instead of receiving an unvalidated profile.

Frame Generation works best from a stable base frame rate. 2× is the recommended multiplier; 3× and 4× availability depends on the GPU, driver, and bundled runtime. Higher multipliers can increase latency and make interpolation artifacts more visible when the base frame rate is low.

## Quick installation

1. Close BeamNG.drive.
2. Extract the `FrameGenNG` folder directly into the BeamNG.drive root folder, next to `Bin64`.
3. Open `FrameGenNG Manager.vbs`.
4. Select **Install**.
5. Start BeamNG in DirectX 12, enable DLSS, then configure Frame Generation below the DLSS settings.

BeamNG will warn about `dxgi.dll` and, on RTX 20/30, `d3d12.dll`. This is expected: these proxy libraries load the FrameGenNG graphics layer. Select **Cancel** in that warning if you do not want BeamNG to show it again.

Other graphics injectors or wrappers that install their own `dxgi.dll` or `d3d12.dll` next to the BeamNG executable may conflict with FrameGenNG. Remove or disable the other injector before installing FrameGenNG.

## Safe removal and recovery

The manager backs up every BeamNG file it changes. **Uninstall** restores the original files and removes the FrameGenNG settings without touching unrelated changes. **Repair** rebuilds the current integration while preserving the selected Frame Generation state and multiplier.

Automatic restore points are created before important operations. Open **Restore Points** to create a manual point or return to an earlier compatible FrameGenNG state. Backups are stored under `FrameGenNG\backups` in the BeamNG user folder; do not delete them manually before uninstalling.

## Diagnostics

Open **Diagnostics** to check the installation. Advanced logging is optional and disabled by default. **Export diagnostic bundle** creates a support ZIP under `FrameGenNG\diagnostics\exports` in the BeamNG user folder; review it before sharing because logs can contain local paths.

## After a BeamNG update

Open the FrameGenNG Manager after updating BeamNG. If it reports **BeamNG update detected**, select **Repair**. FrameGenNG rebuilds the integration from the updated game files and stops safely if that BeamNG version is not yet compatible.

## Automatic updates

The manager checks official stable GitHub Releases when it opens. Select **Update to v…** to download, verify, and install an available update. Settings and the previous working package are preserved so the updater can roll back automatically if installation fails. Drafts and prereleases are ignored.

Expand **Details** inside the manager to inspect operation and update messages.

## Languages

The manager and documentation use English. The in-game FrameGenNG settings automatically follow BeamNG's selected language for English, French, German, Spanish, Italian, Portuguese, Polish, Russian, Simplified Chinese, Japanese, and Korean. English is used as the fallback.

## License and credits

FrameGenNG source code and scripts are Copyright (C) 2026 `ragnarok179` and are released under the [GNU General Public License v3.0 or later](LICENSE). Redistributions and derivative works that include FrameGenNG-authored material must preserve the author attribution and original repository link stated in [NOTICE](NOTICE).

FrameGenNG includes a modified GPLv3 build of [OptiScaler](https://github.com/optiscaler/OptiScaler) and an RTX 20/30 compatibility path based on [dlssg_for_sm86](https://github.com/sdli1995/dlssg_for_sm86) by `sdli1995`, including the RTX 20/SM75 adaptation credited upstream to `Coldwood1026`. NVIDIA, Streamline, NGX, and other bundled third-party components remain under their own terms. See [NOTICE](NOTICE) and [Third-party notices](THIRD_PARTY_NOTICES.md).

FrameGenNG is an independent community project and is not affiliated with or endorsed by BeamNG, NVIDIA, OptiScaler, or the authors of `dlssg_for_sm86`.

