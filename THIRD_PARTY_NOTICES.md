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

FrameGenNG uses only the proxy, runtime, SM75/SM86 backend, and kernel pack required by the RTX 20/30 profile. Optional Super Resolution and XeSS-FG components are not included.

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

## Other licenses

The DirectX, FidelityFX, and XeSS notices distributed with the upstream OptiScaler package are preserved in `licenses/`. Some cover components not active in the FrameGenNG configuration, but remain present to preserve the notice set supplied with the upstream binary.

