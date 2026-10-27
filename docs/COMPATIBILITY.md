# Compatibilité

## Objectif matériel

| GPU | Chemin prévu | État |
| --- | --- | --- |
| RTX 20 (Turing) | OptiScaler + `dlssg_for_sm86` SM75 | À tester |
| RTX 30 (Ampere) | OptiScaler + `dlssg_for_sm86` SM86 | Validé sur RTX 3060 Laptop |
| RTX 40 (Ada) | OptiScaler + DLSS-G natif | À tester |
| RTX 50 (Blackwell) | OptiScaler + DLSS-G/MFG natif | À tester |
| RTX futures | Profil natif après validation | Non garanti |

Le gestionnaire choisit automatiquement le profil d'installation à partir du nom du GPU :

- RTX 20/30 : profil `LegacyRTX`, incluant le proxy `d3d12.dll` de `dlssg_for_sm86` ;
- RTX 40/50 : profil `NativeRTX`, sans proxy SM75/SM86 ;
- GPU RTX non reconnu : l'installation s'arrête au lieu de deviner silencieusement.

## Logiciel

- Windows 10/11 x64
- BeamNG.drive 0.40.3.0 validé
- DirectX 12 obligatoire
- DLSS activé dans BeamNG
- Pilote NVIDIA compatible avec le runtime DLSS-G utilisé

Les mises à jour de BeamNG peuvent modifier la structure de l'interface. Désinstallez FrameGenNG avant une mise à jour majeure du jeu, puis installez la version FrameGenNG compatible.

## HDR

Le prototype convertit en interne le chemin de présentation scRGB vers HDR10 lorsque nécessaire pour le Frame Generation. Le réglage HDR visible dans BeamNG reste la source de vérité pour l'utilisateur. Cette adaptation est incluse dans la DLL OptiScaler modifiée.

## Multiplicateurs

L'interface expose 2×, 3× et 4×. La disponibilité réelle dépend du GPU, du runtime DLSS-G et du pilote. 2× reste la valeur recommandée.

