# Modified OptiScaler source

The `payload/Bin64/dxgi.dll` binary is built from the following upstream OptiScaler commit:

```text
b19cfd29134ab9bc75d654b90f55fb05faca91b2
https://github.com/optiscaler/OptiScaler
```

The `framegenng-renderer.patch` file contains the FrameGenNG changes applied to that commit after the upstream project has been locally rebranded as `FrameGenNGEngine`:

- reading FrameGenNG settings from the BeamNG user folder;
- dynamic enable and multiplier selection;
- presentation-path adaptation for the Frame Generation swapchain;
- BeamNG shutdown signaling and targeted avoidance of unsafe late NGX calls;
- swapchain lifetime fixes identified during prototype testing.

## Rebuilding

```powershell
git clone --recursive https://github.com/optiscaler/OptiScaler.git FrameGenNGEngine-source
git -C FrameGenNGEngine-source checkout b19cfd29134ab9bc75d654b90f55fb05faca91b2
# Apply the FrameGenNGEngine naming normalization, then:
git -C FrameGenNGEngine-source apply ..\framegenng-renderer.patch
```

Then build the x64 Release solution with Visual Studio and the dependencies documented by OptiScaler. The patch is distributed under the same GPLv3 terms as the modified work.

The published DLL must match the hash recorded in `payload/manifest.json`. A mismatch means the binary is not the one validated with the prototype.

