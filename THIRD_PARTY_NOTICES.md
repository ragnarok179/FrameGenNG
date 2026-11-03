# Third-party notices

FrameGenNG combines several independent projects. Their presence does not imply affiliation with or endorsement of FrameGenNG.

## OptiScaler

- Project: <https://github.com/optiscaler/OptiScaler>
- Upstream base commit: `b19cfd29134ab9bc75d654b90f55fb05faca91b2`
- License: GNU GPL version 3
- FrameGenNG changes: `source/renderer/framegenng-renderer.patch`

The complete GPLv3 text is provided in `LICENSE`. Copyright remains with the OptiScaler authors and contributors.

## dlssg_for_sm86

- Project and author: <https://github.com/sdli1995/dlssg_for_sm86> by `sdli1995`
- Version integrated into FrameGenNG: 0.4.0
- Project source: GNU GPL version 3, according to the upstream license and notice
- NVIDIA runtime and kernel images: separate third-party material not relicensed under the upstream GPLv3 license
- RTX 20/SM75 adaptation: credited upstream to `Coldwood1026`
- Upstream notice: <https://github.com/sdli1995/dlssg_for_sm86/blob/main/THIRD_PARTY_NOTICES.txt>

FrameGenNG uses the proxy, runtime, SM75/SM86 backend, and kernel pack required by the RTX 20/30 profile. The optional custom XeSS-FG engine from this project is not included; FrameGenNG uses Intel's XeSS-FG runtime through the OptiScaler integration instead.

Main files and hashes from the validated 0.4.0 package:

| File | SHA-256 |
| --- | --- |
| `d3d12.dll` | `c4b6f6320a8ad465334514161911941f769d541f8e8d5186171fbe0027ea1ddc` |
| `runtime/nvngx_dlssg.dll` | `cadee1aa6db3907babdc3285da2aebc4553d92b89c38ba3eae8abd8bba1bea72` |
| `backend/sm86_backend.dll` | `30ffc6e09a347ccde87ecc6fa54fd7818f5ed8a9353f5c31c2a90835c7f0ca9b` |
| `kernels/fg_kernels.dll` | `1394c2d5d9cc8938ba3e52b043048d20d6d4c13a019c161b11a3dfd16343ec24` |

## NVIDIA Streamline and NGX

Streamline and NGX DLLs remain subject to NVIDIA's terms. They are loaded as separate components and are not relicensed by FrameGenNG.

- Streamline : <https://github.com/NVIDIAGameWorks/Streamline>
- NVIDIA DLSS : <https://developer.nvidia.com/rtx/dlss>

## AMD FidelityFX

FrameGenNG includes the DirectX 12 FidelityFX loader and Frame Generation provider, plus the monolithic FidelityFX SDK 1.1.4 Vulkan provider distributed with the pinned OptiScaler dependency set. They are loaded from FrameGenNG's private runtime folder and do not replace BeamNG's FidelityFX files.

- Project: <https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK>
- Vulkan provider license copy: `licenses/FidelityFX_v1_LICENSE.md`
- License copy: `licenses/FidelityFX_v2_LICENSE.md`

| File | Version | SHA-256 |
| --- | --- | --- |
| `amd_fidelityfx_loader_dx12.dll` | `2.3.0.2740` | `e2d85aa05a9bd9ed8b38935fdf5199372cca6f74c12015143bb6f945ee1608aa` |
| `amd_fidelityfx_framegeneration_dx12.dll` | `4.0.1.2740` | `02297beedd285e822d3a64f314cf00faf378dcec0edc47ff0c4dd71b3a8c2f18` |
| `amd_fidelityfx_vk.dll` | `1.0.1.41314` | `a1624cc4238fef046f30c4d80ce3f47be63fc5f5373f49e3ee9edb9960f54c78` |

## Intel XeSS Frame Generation and XeLL

FrameGenNG includes Intel's XeSS Frame Generation and Xe Low Latency runtimes distributed with the pinned OptiScaler dependency set. BeamNG's own `libxess.dll` upscaler remains untouched.

- Project and documentation: <https://github.com/intel/xess>
- License copy: `licenses/XeSS_LICENSE.txt`

| File | Version | SHA-256 |
| --- | --- | --- |
| `libxess_fg.dll` | `1.3.1.78` | `ec5e0c65e075570c6ede72618bb666d0be0c2e10b2ea9762c0fe8cb8e375ab27` |
| `libxell.dll` | `1.3.2.10` | `d2030dcd694fda8f2ec7e044b13e6db8f0b56d4ba9113a5efad334e3f3ded8c7` |

## Other licenses

The DirectX, FidelityFX, and XeSS notices distributed with the upstream OptiScaler package are preserved in `licenses/`.

