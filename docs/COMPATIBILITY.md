# Compatibility

## Target hardware

| GPU | Intended path | Status |
| --- | --- | --- |
| GeForce RTX 20 (Turing) | FrameGenNG compatibility engine, SM75 path | Supported by the engine; not yet tested in BeamNG |
| GeForce RTX 30 (Ampere) | FrameGenNG compatibility engine, SM86 path | Validated on RTX 3060 Laptop |
| GeForce RTX 40 (Ada) | FrameGenNG native DLSS-G path | Not yet tested in BeamNG |
| GeForce RTX 50 (Blackwell) | FrameGenNG native DLSS-G/MFG path | Not yet tested in BeamNG |
| Quadro RTX and TITAN RTX (Turing) | FrameGenNG compatibility engine, SM75 path | Supported by architecture; not yet tested in BeamNG |
| RTX A-series (Ampere) | FrameGenNG compatibility engine, SM86 path | Supported by architecture; not yet tested in BeamNG |
| RTX Ada professional models | FrameGenNG native DLSS-G path | Supported by architecture; not yet tested in BeamNG |
| RTX PRO Blackwell models | FrameGenNG native DLSS-G/MFG path | Supported by architecture; not yet tested in BeamNG |
| Future RTX generations | Native profile after validation | Not guaranteed |

The manager first reads the GPU compute capability from the NVIDIA driver:

- SM75 and SM86: `LegacyRTX`, including the FrameGenNG compatibility `d3d12.dll` proxy;
- SM89 and SM120: `NativeRTX`, without the SM75/SM86 proxy;
- if the driver query is unavailable, explicit Turing, Ampere, Ada, Blackwell, GeForce, Quadro RTX, TITAN RTX, and RTX A naming patterns provide a conservative fallback;
- unknown RTX generation: installation stops instead of guessing.

## Software

- Windows 10 version 2004 (build 19041) or newer, or Windows 11 x64
- BeamNG.drive 0.40.3.0 validated
- DirectX 12 required
- DLSS enabled in BeamNG
- Hardware-accelerated GPU scheduling required
- an up-to-date NVIDIA driver; R580 or newer is recommended for the RTX 20/30 compatibility path

After every BeamNG update, close the game and select **Reinstall after game update** in FrameGenNG Manager before starting BeamNG again. Game updates are not detected automatically. The operation removes the previous integration, validates the current BeamNG files, and leaves FrameGenNG uninstalled if the updated files are not compatible.

## Multipliers

The interface exposes 2×, 3×, and 4×. Actual availability depends on the GPU, DLSS-G runtime, and driver. 2× remains the recommended setting.

Higher multipliers need a stable base frame rate. At a low base frame rate they can increase input latency and make interpolation artifacts more visible. Frame Generation also consumes additional VRAM according to the output resolution.

## Known compatibility boundaries

- Other injectors that place their own `dxgi.dll` or `d3d12.dll` beside the BeamNG executable may conflict with FrameGenNG.
- NVIDIA DLSS-G does not natively support an FP16/scRGB presentation path. FrameGenNG includes an optional HDR10 bridge, but the distributed configuration keeps it disabled to remain safe on SDR displays. HDR behavior has only been validated on the current test system.
- Laptop hybrid-graphics configurations must run BeamNG on the NVIDIA RTX GPU rather than the integrated GPU.

