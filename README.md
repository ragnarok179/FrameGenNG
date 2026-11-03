# FrameGenNG

Frame Generation integrated into the BeamNG.drive graphics settings.

FrameGenNG adds Frame Generation below BeamNG's native upscaling settings. DirectX 12 is the primary renderer; Vulkan support is experimental. The current release supports recognized NVIDIA RTX GPUs from the Turing, Ampere, Ada, and Blackwell generations, including matching professional RTX models.

- **NVIDIA DLSS-G:** RTX 20 and RTX 30 use the compatibility path powered by `dlssg_for_sm86`; RTX 40 and RTX 50 use the native path. Multipliers up to 4× are available when supported by the selected path.
- **AMD FidelityFX Frame Generation:** available at 2× with BeamNG's FSR 3 and FSR 4 modes on every RTX generation supported by FrameGenNG. FSR 3 Frame Generation is vendor-independent upstream, but this FrameGenNG release does not yet install on non-RTX GPUs. Selecting FSR 4 does not unlock FSR 4 upscaling on unsupported hardware; the AMD runtime may use its FSR 3 fallback.
- **Intel XeSS Frame Generation:** available at 2× with BeamNG's XeSS mode on every RTX generation supported by FrameGenNG through Intel's cross-vendor DP4a path. Intel-only Multi Frame Generation is not used.

Non-RTX GPUs and future unrecognized RTX architectures are not supported by the current installer.

## Requirements

- Windows 10 version 2004 (build 19041) or newer, or Windows 11, 64-bit
- A recognized NVIDIA RTX GPU from the supported generations above
- BeamNG.drive running in DirectX 12, or Vulkan when using the experimental FidelityFX path
- DLSS, FSR 3, FSR 4, or XeSS selected in BeamNG
- Hardware-accelerated GPU scheduling enabled in Windows
- An up-to-date NVIDIA driver; R580 or newer is recommended for the RTX 20/30 compatibility path
- Enough free VRAM for Frame Generation

## Using Frame Generation

Frame Generation creates additional images between the frames rendered by the game. For example, 60 base FPS at 2× can produce up to 120 displayed FPS, while 30 base FPS at 3× can produce up to 90 displayed FPS.

The multiplier does not replace a good base frame rate. A game running at 5 base FPS will not feel smooth simply because 4× reports up to 20 displayed FPS. Low base FPS can still cause high latency and visible interpolation artifacts, so 2× remains the recommended setting.

FrameGenNG selects the matching engine when BeamNG starts. Both SDR and HDR are supported on DirectX 12 and Vulkan; Vulkan keeps BeamNG's native scRGB presentation path.

| Renderer | BeamNG upscaler | Frame Generation | Multiplier |
| --- | --- | --- | --- |
| DirectX 12 | DLSS | NVIDIA DLSS-G | 2×, 3×, or 4× |
| DirectX 12 | FSR 3 or FSR 4 | AMD FidelityFX | 2× |
| DirectX 12 | XeSS | Intel XeSS-FG | 2× |
| Vulkan | FSR 3 or FSR 4 | AMD FidelityFX | 2× |

FidelityFX, XeSS-FG, and Vulkan support are experimental. BeamNG's selected FSR mode remains responsible for upscaling; FrameGenNG uses FidelityFX only to generate the intermediate frame.

Restart BeamNG after selecting a different upscaler or Frame Generation engine. Switching between DLSS-G, FidelityFX, and XeSS-FG is only applied after a game restart.

BeamNG's FPS counter only reports the base frames rendered by the game. Press **Alt+R** to open the NVIDIA App performance overlay and see the displayed frame rate including generated frames.

For more stable results, limit the base frame rate and keep normal GPU usage around 80–90% in the NVIDIA overlay. This leaves headroom for demanding scenes.

## Quick installation

1. Close BeamNG.drive.
2. Extract the `FrameGenNG` folder directly into the BeamNG root folder. (You can find it through Steam: Library → Right-click BeamNG.drive → Manage → Browse local files.)
3. Open `FrameGenNG Manager.vbs`.
4. Select **Install**.
5. Start BeamNG and select a compatible renderer and upscaler from the table above.
6. Restart the game after changing the upscaler, then manually enable and configure Frame Generation directly below the upscaling settings in **Options → Graphics**.

Frame Generation is disabled after the first installation so an incompatible configuration cannot prevent BeamNG from starting. After you enable it, FrameGenNG keeps your selected state and multiplier across normal game restarts. Automatic updates and **Reinstall after game update** also preserve these settings.

BeamNG will warn about `dxgi.dll` and, on RTX 20/30, `d3d12.dll`. This is expected: these proxy libraries load the FrameGenNG graphics layer. Select **Cancel** in that warning if you do not want BeamNG to show it again.

Other graphics injectors or wrappers that install their own `dxgi.dll` or `d3d12.dll` next to the BeamNG executable may conflict with FrameGenNG. Remove or disable the other injector before installing FrameGenNG.

The Steam Overlay remains available for Steam Input and Steam Controller support. Other known third-party overlays stay blocked by the Frame Generation renderer for stability.

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

If an automatic update does not complete correctly, open the manager and select **Uninstall**. Then download the latest release from the [FrameGenNG releases page](https://github.com/ragnarok179/FrameGenNG/releases/latest), replace the old `FrameGenNG` package folder, and install the new version manually.

Expand **Details** inside the manager to inspect operation and update messages.

## License and credits

FrameGenNG source code and scripts are Copyright (C) 2026 `ragnarok179` and are released under the [GNU General Public License v3.0 or later](LICENSE). Redistributions and derivative works that include FrameGenNG-authored material must preserve the author attribution and original repository link stated in [NOTICE](NOTICE).

FrameGenNG includes a modified GPLv3 build of [OptiScaler](https://github.com/optiscaler/OptiScaler) and an RTX 20/30 compatibility path based on [dlssg_for_sm86](https://github.com/sdli1995/dlssg_for_sm86) by `sdli1995`, including the RTX 20/SM75 adaptation credited upstream to `Coldwood1026`. NVIDIA, Streamline, NGX, and other bundled third-party components remain under their own terms. See [NOTICE](NOTICE) and [Third-party notices](THIRD_PARTY_NOTICES.md).
