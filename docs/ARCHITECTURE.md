# Architecture de FrameGenNG

```text
BeamNG DX12 + DLSS SR
        │
        ▼
FrameGenNG / OptiScaler (dxgi.dll)
  ├─ récupère couleur, profondeur et vecteurs de mouvement
  ├─ lit les réglages FrameGenNG du dossier utilisateur
  ├─ adapte scRGB vers HDR10 pour la chaîne FG
  └─ signale proprement la fermeture à NGX
        │
        ├─ RTX 20/30 ─► dlssg_for_sm86 (d3d12.dll + kernels SM75/SM86)
        │
        └─ RTX 40/50 ─► runtime DLSS-G natif
        │
        ▼
Swapchain avec images générées
```

## Intégration BeamNG

L'installation ajoute deux options sous les paramètres DLSS :

- activation de la génération d'images ;
- multiplicateur 2×, 3× ou 4×.

Ces contrôles sont masqués lorsque DLSS n'est pas sélectionné. La DLL relit les réglages au maximum deux fois par seconde, ce qui évite d'exposer l'interface technique d'OptiScaler.

Une extension GELua écrit un signal pendant `onPreExit`. La DLL l'observe avant le démontage D3D12 et évite les appels de fermeture NGX devenus dangereux. Ce pont corrige le plantage observé à la fermeture du prototype.

## Installation réversible

Le gestionnaire applique une transaction : validation, sauvegarde, copie, modification de l'interface, puis écriture de l'état. En cas d'échec, les cibles déjà touchées sont restaurées. L'état contient les empreintes SHA-256 des fichiers posés afin que la désinstallation puisse détecter une modification ultérieure et la préserver dans une copie de récupération.

