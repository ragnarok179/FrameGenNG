# Source OptiScaler modifiée

La DLL `payload/Bin64/dxgi.dll` est construite à partir d'OptiScaler, commit amont :

```text
b19cfd29134ab9bc75d654b90f55fb05faca91b2
https://github.com/optiscaler/OptiScaler
```

Le fichier `framegenng-optiscaler.patch` contient les modifications FrameGenNG appliquées à ce commit. Elles couvrent :

- lecture des réglages FrameGenNG dans le dossier utilisateur BeamNG ;
- sélection dynamique activation/multiplicateur ;
- adaptation HDR scRGB vers HDR10 sur la swapchain de Frame Generation ;
- signal de fermeture BeamNG et contournement ciblé des appels NGX dangereux ;
- correctifs de durée de vie de la swapchain observés lors du prototype.

## Reconstruction

```powershell
git clone --recursive https://github.com/optiscaler/OptiScaler.git
git -C OptiScaler checkout b19cfd29134ab9bc75d654b90f55fb05faca91b2
git -C OptiScaler apply ..\framegenng-optiscaler.patch
```

Compilez ensuite la solution x64 Release avec Visual Studio et les dépendances décrites par OptiScaler. Le patch est distribué sous les mêmes conditions GPLv3 que l'œuvre modifiée.

La DLL publiée doit produire l'empreinte renseignée dans `payload/manifest.json`. Une différence signifie que le binaire n'est pas celui qui a été validé avec le prototype.

