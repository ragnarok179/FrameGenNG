# Troubleshooting

## Black screen at startup

Close the game with Alt+F4, open the manager, and select **Reinstall after game update**. Confirm that BeamNG starts in DirectX 12. Do not place a second `dxgi.dll` or `d3d12.dll` proxy next to FrameGenNG.

## Incorrect, washed-out, or oversaturated colors

FrameGenNG selects the presentation path automatically. SDR is preserved unless Windows HDR is active and BeamNG requests HDR at the same time. Do not manually change `ForceHDR`, `UseHDR10`, or `SkipColorSpace` in `Bin64\FrameGenNG.ini`.

Fully close and restart BeamNG after changing Windows HDR. If the image remains incorrect, select **Reinstall after game update** in the manager to restore the production configuration and rebuild BeamNG's disposable rendering shader cache. Export a diagnostic bundle if the problem continues.

## Frame Generation does not activate

1. Confirm that BeamNG is using DirectX 12.
2. Enable DLSS in the graphics settings.
3. Enable **Frame Generation** below DLSS.
4. Confirm that Hardware-accelerated GPU scheduling is enabled in Windows and restart Windows after changing it.
5. Update the NVIDIA driver.
6. Temporarily disable other graphics injectors to rule out a proxy conflict.
7. Run **Diagnostics** in the manager.

If FrameGenNG reports that DLSS Frame Generation is unavailable, it leaves the selected replacement unchanged and lets BeamNG continue without Frame Generation. It does not install or select an unbundled fallback.

## Exit error

Collect `temp\frame_generation_shutdown.log` and `beamng.log` from the BeamNG user folder. Attach them to a bug report with the GPU model, NVIDIA driver, BeamNG version, and selected multiplier.

## Emergency restoration

Close BeamNG, then run `Uninstall FrameGenNG.cmd`. Restoration uses the state and backups stored in the BeamNG user folder. A redundant state copy is used automatically if the primary state is missing or damaged. Files changed after installation are copied to a `recovery-before-uninstall-*` folder before restoration.

## BeamNG was updated

Before starting the game after an update, open the manager and select **Reinstall after game update**. FrameGenNG will preserve its settings, remove the old integration, and rebuild its user-folder overrides from the updated game files.

If reinstallation reports that the updated files are incompatible, leave FrameGenNG uninstalled and wait for a compatible release. The manager deliberately leaves BeamNG without FrameGenNG instead of forcing the old integration.

## Return to an earlier FrameGenNG state

Open **FrameGenNG Manager → Restore Points**, select a compatible point, and choose **Restore selected**. The manager saves the current state before it changes anything. Use this when a mod update completed successfully but causes a problem specific to your setup. Use **Reinstall after game update** when BeamNG itself was updated.

Automatic restore points are limited to the five newest entries. Manual points remain until deleted and are limited to ten. A restore point created for a different BeamNG executable is intentionally blocked.

## Antivirus or SmartScreen warning

Proxy DLLs are sometimes flagged by heuristic scanners. Download only from this repository's GitHub Releases page, compare the release SHA-256 checksum, and do not bypass a warning for a package obtained elsewhere.

## Update check is unavailable

The manager needs access to `api.github.com` and `github.com` to check and download releases. The installed version remains usable when the service is offline or blocked. Select **Check for updates** later or update manually from the official Releases page.

## An automatic update failed

The updater restores the previous package and game integration when possible. Its result and log are stored under `FrameGenNG\updates` in the BeamNG user folder, and the pre-update state remains available through **Restore Points**. Temporary package rollback copies are removed after success and retained only when automatic rollback cannot complete. If BeamNG itself changed and the old mod version is no longer compatible, rollback leaves the game restored and reports the retained package backup.

## Collect detailed diagnostics

Open **Diagnostics** in the manager and run the standard scan first. If the issue is intermittent, enable **Advanced diagnostic logging**, reproduce the problem, reopen the manager, and select **Export diagnostic bundle**. Disable advanced logging afterward if you no longer need it.

The exported ZIP can contain local folder paths, GPU/driver information, installation state, and excerpts from recent logs. Review the archive before posting it publicly. Advanced mode does not add per-frame logging and should not affect in-game performance.

## Unstable frame times

Frame Generation needs additional VRAM. Reduce texture quality or output resolution, close other GPU-heavy applications, and test again with the 2× multiplier.

