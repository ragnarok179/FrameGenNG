# Modified OptiScaler source

The `payload/Bin64/dxgi.dll` binary is built from the following upstream OptiScaler commit:

```text
b19cfd29134ab9bc75d654b90f55fb05faca91b2
https://github.com/optiscaler/OptiScaler
```

The `framegenng-renderer.patch` file contains the FrameGenNG changes applied to that commit after the upstream project has been locally rebranded as `FrameGenNGEngine`:

- reading FrameGenNG settings from the configured BeamNG user folder or its Local AppData default;
- dynamic enable and multiplier selection;
- presentation-path adaptation for the Frame Generation swapchain;
- Steam Overlay and Steam Input passthrough while other known overlays remain blocked;
- automatic SDR/HDR presentation switching based on Windows HDR and BeamNG's requested output;
- BeamNG shutdown signaling and targeted avoidance of unsafe late NGX calls;
- swapchain lifetime fixes identified during prototype testing.

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
```

Then build the x64 Release solution with Visual Studio and the dependencies documented by OptiScaler. The patch is distributed under the same GPLv3 terms as the modified work.

The published DLL must match the hash recorded in `payload/manifest.json`. A mismatch means the binary is not the one validated with the prototype.

