# FrameGenNG

Frame Generation integrated into the BeamNG.drive graphics settings.

FrameGenNG adds Frame Generation below BeamNG's native upscaling options. It supports NVIDIA DLSS-G on RTX 20, 30, 40, and 50 GPUs and matching professional RTX models, AMD FidelityFX Frame Generation with FSR 3/4, and Intel XeSS Frame Generation with XeSS.

- **DLSS-G:** up to 4×; RTX 20/30 use the compatibility path and RTX 40/50 use the native path.
- **FidelityFX and XeSS-FG:** 2× on supported FrameGenNG configurations.
- **Current installer:** requires a recognized NVIDIA RTX GPU. Non-RTX GPUs are not yet supported.

## Requirements

- Windows 10 version 2004 (build 19041) or newer, or Windows 11, 64-bit
- A recognized NVIDIA RTX GPU with an up-to-date driver; R580 or newer is recommended for the RTX 20/30 compatibility path
- BeamNG.drive running in DirectX 12, or Vulkan with the experimental FidelityFX path
- DLSS, FSR 3, FSR 4, or XeSS selected in BeamNG
- Hardware-accelerated GPU scheduling enabled in Windows
- Enough free VRAM for Frame Generation

## Using Frame Generation

Frame Generation inserts images between rendered frames. For example, 60 base FPS at 2× can display up to 120 FPS, while 30 FPS at 3× can reach 90 FPS. It cannot make a very low base frame rate feel smooth, so 2× is recommended.

| Renderer | BeamNG upscaler | Frame Generation | Multiplier |
| --- | --- | --- | --- |
| DirectX 12 | DLSS | NVIDIA DLSS-G | 2×, 3×, or 4× |
| DirectX 12 | FSR 3 or FSR 4 | AMD FidelityFX | 2× |
| DirectX 12 | XeSS | Intel XeSS-FG | 2× |
| Vulkan | FSR 3 or FSR 4 | AMD FidelityFX | 2× |

DirectX 12 is recommended. FidelityFX, XeSS-FG, and Vulkan support are experimental. Restart BeamNG after changing the upscaler or Frame Generation engine. FSR 4 upscaling remains limited to hardware supported by AMD.

BeamNG reports only the base frame rate. Press **Alt+R** for the NVIDIA App overlay and the displayed FPS including generated frames. For stable results, limit the base FPS and leave roughly 10–20% GPU headroom.

## Quick installation

1. Close BeamNG.drive.
2. Extract the `FrameGenNG` folder directly into the BeamNG root folder. (Steam: Library → Right-click BeamNG.drive → Manage → Browse local files.)
3. Open `FrameGenNG Manager.vbs`.
4. Select **Install**.
5. Start BeamNG and select a compatible renderer and upscaler from the table above.
6. Restart the game, then enable Frame Generation below the upscaling settings in **Options → Graphics**.

Frame Generation starts disabled after installation. Your selected state and multiplier are preserved across normal restarts, automatic updates, and **Reinstall after game update**.

BeamNG will warn about `dxgi.dll` and, on RTX 20/30, `d3d12.dll`; this is expected. Select **Cancel** in that warning if you do not want it to appear again.

Other graphics injectors using these filenames may conflict with FrameGenNG. The Steam Overlay remains available for Steam Input and Steam Controller support; other known third-party overlays stay blocked for stability.

## Safe removal and recovery

The manager does not overwrite BeamNG's original files. It adds its runtime files to `Bin64` and installs the HDR and interface changes as user-folder overrides. **Uninstall** removes FrameGenNG and restores pre-existing overrides without touching unrelated changes. **Reinstall after game update** rebuilds the integration from the current BeamNG files while preserving the selected Frame Generation state and multiplier.

To remove FrameGenNG completely, close BeamNG, open the manager, and select **Uninstall**. After the manager confirms that removal completed successfully, manually delete the `FrameGenNG` package folder from the BeamNG root folder. Leaving this package folder in place does not affect BeamNG; it only keeps the manager and installation files available.

Automatic restore points are created before important operations. Open **Restore Points** to create a manual point or return to an earlier compatible FrameGenNG state. Backups are stored under `FrameGenNG\backups` in the BeamNG user folder; do not delete them manually before uninstalling.

## Diagnostics

Open **Diagnostics** to check the installation. Advanced logging is optional and disabled by default. **Export diagnostic bundle** creates a support ZIP under `FrameGenNG\diagnostics\exports` in the BeamNG user folder; review it before sharing because logs can contain local paths.

## After a BeamNG update

After every BeamNG update, close the game, open FrameGenNG Manager, and select **Reinstall after game update** before starting BeamNG again. FrameGenNG does not try to detect game updates automatically. It removes its previous integration, validates the current game files, creates a new baseline, and stops with FrameGenNG uninstalled if the updated files are not supported.

## Automatic updates

The manager checks official stable GitHub Releases when it opens. Select **Update to v…** to download, verify, and install an available update. Settings and the previous working package are preserved so the updater can roll back automatically if installation fails. Drafts and prereleases are ignored.

If an automatic update does not complete correctly, select **Uninstall**, download the [latest release](https://github.com/ragnarok179/FrameGenNG/releases/latest), replace the package folder, and install it manually. Expand **Details** to inspect operation and update messages.

## License and credits

FrameGenNG source code and scripts are Copyright (C) 2026 `ragnarok179` and are released under the [GNU General Public License v3.0 or later](LICENSE). Redistributions and derivative works that include FrameGenNG-authored material must preserve the author attribution and original repository link stated in [NOTICE](NOTICE).

FrameGenNG includes a modified GPLv3 build of [OptiScaler](https://github.com/optiscaler/OptiScaler) and an RTX 20/30 compatibility path based on [dlssg_for_sm86](https://github.com/sdli1995/dlssg_for_sm86) by `sdli1995`, including the RTX 20/SM75 adaptation credited upstream to `Coldwood1026`. NVIDIA, Streamline, NGX, and other bundled third-party components remain under their own terms. See [NOTICE](NOTICE) and [Third-party notices](THIRD_PARTY_NOTICES.md).
