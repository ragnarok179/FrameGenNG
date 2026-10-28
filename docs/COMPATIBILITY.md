# Compatibility

## Target hardware

| GPU | Intended path | Status |
| --- | --- | --- |
| RTX 20 (Turing) | FrameGenNG compatibility engine, SM75 path | Not yet tested |
| RTX 30 (Ampere) | FrameGenNG compatibility engine, SM86 path | Validated on RTX 3060 Laptop |
| RTX 40 (Ada) | FrameGenNG native DLSS-G path | Not yet tested |
| RTX 50 (Blackwell) | FrameGenNG native DLSS-G/MFG path | Not yet tested |
| Future RTX generations | Native profile after validation | Not guaranteed |

The manager automatically selects an installation profile from the detected GPU name:

- RTX 20/30: `LegacyRTX`, including the FrameGenNG compatibility `d3d12.dll` proxy;
- RTX 40/50: `NativeRTX`, without the SM75/SM86 proxy;
- unknown RTX generation: installation stops instead of guessing.

## Software

- Windows 10/11 x64
- BeamNG.drive 0.40.3.0 validated
- DirectX 12 required
- DLSS enabled in BeamNG
- an NVIDIA driver compatible with the bundled DLSS-G runtime

BeamNG updates may change the UI structure. Uninstall FrameGenNG before a major game update, then install a FrameGenNG version confirmed compatible with that release.

## Multipliers

The interface exposes 2×, 3×, and 4×. Actual availability depends on the GPU, DLSS-G runtime, and driver. 2× remains the recommended setting.

