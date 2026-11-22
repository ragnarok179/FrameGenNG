# Compatibility

## Target hardware

| Selected BeamNG upscaler | Frame Generation path | Availability |
| --- | --- | --- |
| DLSS | NVIDIA DLSS Frame Generation | DirectX 12 on recognized RTX Turing, Ampere, Ada, and Blackwell GPUs |
| FSR 3 or FSR 4 | FidelityFX Frame Generation | DirectX 12 and Vulkan when BeamNG exposes the selected FSR mode |
| XeSS | Intel Xe Frame Generation | DirectX 12 when BeamNG and the XeFG runtime support the GPU |

The manager installs one of three file profiles:

- SM75 and SM86: `LegacyRTX`, including the FrameGenNG compatibility `d3d12.dll` proxy;
- SM89 and SM120: `NativeRTX`, with native DLSS-G and the Ada/Blackwell helper;
- other or unrecognized GPUs: `Universal`, containing the common FSR/XeSS renderer without NVIDIA compatibility shims.

BeamNG decides whether an upscaler is available on the active GPU. FrameGenNG only shows controls for the selected supported path. An unrecognized future RTX GPU receives the safe universal profile until its architecture is validated.

## Software

- Windows 10 version 2004 (build 19041) or newer, or Windows 11 x64
- BeamNG.drive 0.40.4
- DirectX 12 for the primary integration, or Vulkan for the experimental FidelityFX path
- DLSS, FSR 3, FSR 4, or XeSS selected in BeamNG
- current GPU drivers
- Hardware-accelerated GPU scheduling for NVIDIA DLSS Frame Generation

After every BeamNG update, close the game and select **Reinstall after game update** in FrameGenNG Manager before starting BeamNG again. Game updates are not detected automatically. The operation removes the previous integration, validates the current BeamNG files, and leaves FrameGenNG uninstalled if the updated files are not compatible.

## Multipliers

DLSS exposes 2×, 3×, and 4×. On RTX 40, the NativeRTX profile includes an Ada-specific MFG helper for stable 3×/4× capability and pacing. If the runtime rejects a requested multiplier, FrameGenNG keeps the setting but safely uses the highest supported value and records both values in the native log. FSR 3, FSR 4, and XeSS expose 2× because their bundled generation paths produce one intermediate frame. 2× remains the recommended setting.

Higher multipliers need a stable base frame rate. At a low base frame rate they can increase input latency and make interpolation artifacts more visible. Frame Generation also consumes additional VRAM according to the output resolution.

## Known compatibility boundaries

- Other injectors that place their own `dxgi.dll` or `d3d12.dll` beside the BeamNG executable may conflict with FrameGenNG.
- BeamNG's FSR 3 (Custom) mode is not supported for Frame Generation because it is an internal upscaler rather than the FidelityFX API path used by the FSR 3 and FSR 4 modes.
- The FidelityFX and XeSS generation paths are experimental integrations whose stability and image quality can vary by driver and BeamNG version.
- Vulkan supports the FSR 3 and FSR 4 upscalers with FidelityFX Frame Generation at 2×. With DLSS, XeSS, or another unsupported mode, FrameGenNG hides its Frame Generation controls and does not install Vulkan presentation hooks; DLSS-G and XeSS-FG remain DirectX 12 only.
- SDR and HDR are supported across the listed DirectX 12 and Vulkan paths. Vulkan preserves BeamNG's native scRGB presentation instead of using the DirectX 12 HDR10 bridge.
- Changing BeamNG's upscaler requires a game restart before FrameGenNG initializes the matching generation engine.
- NVIDIA DLSS-G does not natively support an FP16/scRGB presentation path. FrameGenNG automatically activates its HDR10 bridge only when both Windows HDR and BeamNG HDR are active; SDR keeps its normal presentation path.
- Laptop hybrid-graphics configurations must run BeamNG on the NVIDIA RTX GPU rather than the integrated GPU.

