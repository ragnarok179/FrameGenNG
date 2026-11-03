# FrameGenNG

Frame Generation integrated into the BeamNG.drive graphics settings.

FrameGenNG uses BeamNG's native DLSS input in DirectX 12 and adds adjustable Frame Generation directly below the game's DLSS options. The project targets NVIDIA RTX GPUs using the Turing, Ampere, Ada, and Blackwell architectures:

- RTX 20 and RTX 30: compatibility path powered by `dlssg_for_sm86`;
- RTX 40 and RTX 50: native DLSS-G path through the FrameGenNG integration layer;
- professional Quadro RTX, RTX A, RTX Ada, and RTX PRO Blackwell models: the matching architecture path;
- future RTX generations: a compatibility goal after validation, not a current guarantee.

> **Current validation:** FrameGenNG has been validated on BeamNG.drive 0.40.3.0 with an RTX 3060 Laptop GPU. RTX 20, 40, and 50 GPUs still require testing before compatibility can be guaranteed.

## Requirements

- Windows 10 version 2004 (build 19041) or newer, or Windows 11, 64-bit
- BeamNG.drive running in DirectX 12
- DLSS enabled in BeamNG
- Hardware-accelerated GPU scheduling enabled in Windows
- An up-to-date NVIDIA driver; R580 or newer is recommended for the RTX 20/30 compatibility path
- Enough free VRAM for Frame Generation

## Using Frame Generation

Frame Generation creates additional images between the frames rendered by the game. For example, 60 base FPS at 2× can produce up to 120 displayed FPS, while 30 base FPS at 3× can produce up to 90 displayed FPS.

The multiplier does not replace a good base frame rate. A game running at 5 base FPS will not feel smooth simply because 4× reports up to 20 displayed FPS. Low base FPS can still cause high latency and visible interpolation artifacts, so 2× remains the recommended setting.

BeamNG's FPS counter only reports the base frames rendered by the game. Press **Alt+R** to open the NVIDIA App performance overlay and see the displayed frame rate including generated frames.

For more stable results, limit the base frame rate instead of leaving it unlimited. Adjust the limit or graphics settings so normal GPU usage stays around 80–90% in the NVIDIA overlay (alt+r). This leaves some performance headroom for demanding scenes and helps keep the frame rate consistent.

## Quick installation

1. Close BeamNG.drive.
2. Extract the `FrameGenNG` folder directly into the BeamNG root folder. (You can find it through Steam: Library → Right-click BeamNG.drive → Manage → Browse local files.)
3. Open `FrameGenNG Manager.vbs`.
4. Select **Install**.
5. Start BeamNG in DirectX 12, enable DLSS, then configure Frame Generation below the DLSS settings.
6. To configure it, open **Options → Graphics** in BeamNG, enable **DLSS**, then use the Frame Generation controls displayed directly below the DLSS settings.

BeamNG will warn about `dxgi.dll` and, on RTX 20/30, `d3d12.dll`. This is expected: these proxy libraries load the FrameGenNG graphics layer. Select **Cancel** in that warning if you do not want BeamNG to show it again.

Other graphics injectors or wrappers that install their own `dxgi.dll` or `d3d12.dll` next to the BeamNG executable may conflict with FrameGenNG. Remove or disable the other injector before installing FrameGenNG.

The Steam Overlay remains available for Steam Input and Steam Controller support. Other known third-party overlays stay blocked by the Frame Generation renderer for stability.

## Safe removal and recovery

The manager keeps BeamNG's installed files untouched. The HDR and interface integrations are installed as user-folder overrides. **Uninstall** removes FrameGenNG and restores pre-existing user overrides without touching unrelated changes. **Reinstall after game update** removes the old integration and rebuilds it from the current BeamNG files while preserving the selected Frame Generation state and multiplier.

To remove FrameGenNG completely, close BeamNG, open the manager, and select **Uninstall**. After the manager confirms that removal completed successfully, manually delete the `FrameGenNG` package folder from the BeamNG root folder. Leaving this package folder in place does not affect BeamNG; it only keeps the manager and installation files available.

Automatic restore points are created before important operations. Open **Restore Points** to create a manual point or return to an earlier compatible FrameGenNG state. Backups are stored under `FrameGenNG\backups` in the BeamNG user folder; do not delete them manually before uninstalling.

## Diagnostics

Open **Diagnostics** to check the installation. Advanced logging is optional and disabled by default. **Export diagnostic bundle** creates a support ZIP under `FrameGenNG\diagnostics\exports` in the BeamNG user folder; review it before sharing because logs can contain local paths.

## After a BeamNG update

After every BeamNG update, close the game, open FrameGenNG Manager, and select **Reinstall after game update** before starting BeamNG again. FrameGenNG does not try to detect game updates automatically. It removes its previous integration, validates the current game files, creates a new baseline, and stops with FrameGenNG uninstalled if the updated files are not supported.

## Automatic updates

The manager checks official stable GitHub Releases when it opens. Select **Update to v…** to download, verify, and install an available update. Settings and the previous working package are preserved so the updater can roll back automatically if installation fails. Drafts and prereleases are ignored.

If an automatic update does not complete correctly, open the manager and select **Uninstall**. Then download the latest release from the [FrameGenNG releases page](https://github.com/ragnarok179/FrameGenNG/releases/latest), replace the old `FrameGenNG` package folder, and install the new version manually.

Expand **Details** inside the manager to inspect operation and update messages.

## License and credits

FrameGenNG source code and scripts are Copyright (C) 2026 `ragnarok179` and are released under the [GNU General Public License v3.0 or later](LICENSE). Redistributions and derivative works that include FrameGenNG-authored material must preserve the author attribution and original repository link stated in [NOTICE](NOTICE).

FrameGenNG includes a modified GPLv3 build of [OptiScaler](https://github.com/optiscaler/OptiScaler) and an RTX 20/30 compatibility path based on [dlssg_for_sm86](https://github.com/sdli1995/dlssg_for_sm86) by `sdli1995`, including the RTX 20/SM75 adaptation credited upstream to `Coldwood1026`. NVIDIA, Streamline, NGX, and other bundled third-party components remain under their own terms. See [NOTICE](NOTICE) and [Third-party notices](THIRD_PARTY_NOTICES.md).
