# Modified OptiScaler source

The `payload/Bin64/dxgi.dll` binary is built from the following upstream OptiScaler commit:

```text
b19cfd29134ab9bc75d654b90f55fb05faca91b2
https://github.com/optiscaler/OptiScaler
```

The renderer changes are split into focused patches applied after the upstream project has been locally rebranded as `FrameGenNGEngine`:

- `framegenng-renderer.patch` contains the BeamNG and DirectX integration;
- `xess-responsive-mask.patch` contains the XeSS input-mask compatibility change;
- `vulkan-frame-generation.patch` contains the experimental Vulkan FidelityFX Frame Generation path;
- `vulkan-output-guard.patch` prevents unsupported DLSS-G and XeSS-FG initialization under Vulkan;
- `vulkan-unsupported-passthrough.patch` clears the unsupported Frame Generation backend and leaves Vulkan presentation untouched when the selected upscaler has no supported Vulkan Frame Generation path.
- `vulkan-shutdown-boundary.patch` releases FidelityFX and Vulkan upscaler contexts at the first safe shutdown boundary, even when BeamNG stops presenting before destroying its swapchain.

Together, these patches provide:

- reading FrameGenNG settings from the configured BeamNG user folder or its Local AppData default;
- automatic DLSS-G, FidelityFX Frame Generation, or XeSS-FG selection from BeamNG's saved upscaler;
- dynamic enable and backend-aware multiplier selection;
- presentation-path adaptation for the Frame Generation swapchain;
- Steam Overlay and Steam Input passthrough while other known overlays remain blocked;
- automatic SDR/HDR presentation switching on DirectX based on Windows HDR and BeamNG's requested output;
- BeamNG shutdown signaling and targeted avoidance of unsafe late NGX calls;
- swapchain lifetime fixes identified during prototype testing.

The Vulkan patch deliberately uses the monolithic FidelityFX SDK 1.1.4 provider. Its swapchain lifecycle has been validated with BeamNG, while the newer split Vulkan loader uses a different lifecycle and caused a driver crash during BeamNG's startup resize. Vulkan support is therefore limited to the tested FidelityFX Frame Generation path. When DLSS, XeSS, or another unsupported mode is selected, FrameGenNG clears its Frame Generation backend, does not install Vulkan presentation hooks, and leaves BeamNG's native SDR/HDR path untouched.

The DirectX FidelityFX loader/frame-generation runtime, the monolithic Vulkan FidelityFX runtime, and the Intel XeSS-FG/XeLL runtime distributed in `payload/Bin64/FrameGenNG` come from the dependency set produced by this same pinned OptiScaler source. BeamNG's own upscaler DLLs remain untouched.

## Rebuilding

### Automated local test build

From a development checkout of the repository, open `Build FrameGenNG Test Package.cmd`. The build downloads and caches the pinned upstream source, applies the FrameGenNG naming normalization and renderer patch, compiles the Release x64 DLL, updates the payload manifest, and creates the final ZIP and SHA-256 file under `dist`. The development launcher and build script are intentionally not included in the distributed user ZIP.

The first build requires Git for Windows, internet access, and Visual Studio 2022 or Build Tools 2022 with the C++ workload. Downloaded sources and intermediate files remain under `.build-cache`, which is ignored by Git. Later builds reuse this cache. Use `scripts\build-native-release.ps1 -RefreshSource` to recreate it.

The build updates `payload/Bin64/dxgi.dll` and `payload/manifest.json` with the exact native binary placed in the test package. Commit those files only after the packaged build has been validated.

### Manual rebuild

```powershell
git clone --recursive https://github.com/optiscaler/OptiScaler.git FrameGenNGEngine-source
git -C FrameGenNGEngine-source checkout b19cfd29134ab9bc75d654b90f55fb05faca91b2
# Apply the FrameGenNGEngine naming normalization, then:
git -C FrameGenNGEngine-source apply ..\framegenng-renderer.patch
git -C FrameGenNGEngine-source apply ..\xess-responsive-mask.patch
git -C FrameGenNGEngine-source apply ..\vulkan-frame-generation.patch
git -C FrameGenNGEngine-source apply ..\vulkan-output-guard.patch
git -C FrameGenNGEngine-source apply ..\vulkan-unsupported-passthrough.patch
```

Then build the x64 Release solution with Visual Studio and the dependencies documented by OptiScaler. The patch is distributed under the same GPLv3 terms as the modified work.

The published DLL must match the hash recorded in `payload/manifest.json`. A mismatch means the binary is not the one validated with the prototype.

