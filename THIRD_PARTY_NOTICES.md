# Notices des composants tiers

FrameGenNG assemble plusieurs projets indépendants. Leur présence n'implique aucune affiliation ni approbation de FrameGenNG.

## OptiScaler

- Projet : <https://github.com/optiscaler/OptiScaler>
- Commit de base : `b19cfd29134ab9bc75d654b90f55fb05faca91b2`
- Licence : GNU GPL version 3
- Modifications FrameGenNG : `source/optiscaler/framegenng-optiscaler.patch`

Le texte complet de la GPLv3 est fourni dans `LICENSE`.

## dlssg_for_sm86

- Projet : <https://github.com/sdli1995/dlssg_for_sm86>
- Version intégrée au prototype : 0.4.0
- Code propre au projet : MIT selon sa notice amont
- Runtime NVIDIA et images de kernels : binaires tiers, explicitement exclus de la licence MIT par le projet amont
- Notice amont : <https://github.com/sdli1995/dlssg_for_sm86/blob/main/THIRD_PARTY_NOTICES.txt>

FrameGenNG utilise uniquement le proxy, le runtime, le backend SM75/SM86 et le pack de kernels nécessaires au profil RTX 20/30. Les composants optionnels de Super Resolution et XeSS-FG ne sont pas inclus.

Fichiers principaux et empreintes de la version 0.4.0 validée :

| Fichier | SHA-256 |
| --- | --- |
| `d3d12.dll` | `c4b6f6320a8ad465334514161911941f769d541f8e8d5186171fbe0027ea1ddc` |
| `runtime/nvngx_dlssg.dll` | `cadee1aa6db3907babdc3285da2aebc4553d92b89c38ba3eae8abd8bba1bea72` |
| `backend/sm86_backend.dll` | `30ffc6e09a347ccde87ecc6fa54fd7818f5ed8a9353f5c31c2a90835c7f0ca9b` |
| `kernels/fg_kernels.dll` | `1394c2d5d9cc8938ba3e52b043048d20d6d4c13a019c161b11a3dfd16343ec24` |

## NVIDIA Streamline et NGX

Les DLL Streamline et NGX restent soumises aux conditions de NVIDIA. Elles sont chargées comme composants séparés et ne sont pas relicenciées par FrameGenNG.

- Streamline : <https://github.com/NVIDIAGameWorks/Streamline>
- NVIDIA DLSS : <https://developer.nvidia.com/rtx/dlss>

## Autres licences

Les notices DirectX, FidelityFX et XeSS distribuées avec le package OptiScaler d'origine sont conservées dans `licenses/`. Certaines couvrent des composants non actifs dans la configuration FrameGenNG, mais restent présentes pour préserver le jeu de notices fourni avec le binaire amont.

