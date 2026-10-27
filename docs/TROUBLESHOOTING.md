# Dépannage

## Écran noir au lancement

Fermez le jeu avec Alt+F4, ouvrez le gestionnaire et choisissez **Réparer**. Vérifiez ensuite que BeamNG démarre en DirectX 12. N'ajoutez pas un second proxy `dxgi.dll` ou `d3d12.dll` à côté de FrameGenNG.

## Image délavée en HDR

Utilisez une version de FrameGenNG qui inclut le pont HDR validé. Ne forcez pas manuellement scRGB/HDR10 dans les fichiers INI. Le jeu reste responsable du choix visible, tandis que FrameGenNG adapte uniquement la chaîne de génération d'images.

## Pas de Frame Generation

1. Vérifiez que BeamNG utilise DirectX 12.
2. Activez DLSS dans les paramètres graphiques.
3. Activez **Génération d'images** sous DLSS.
4. Désactivez temporairement les autres injecteurs graphiques afin d'écarter un conflit.
5. Lancez **Diagnostic** dans le gestionnaire.

## Erreur à la fermeture

Récupérez `temp\frame_generation_shutdown.log` et `beamng.log` dans le dossier utilisateur BeamNG. Joignez-les à un rapport avec le modèle de GPU, le pilote NVIDIA, la version de BeamNG, le mode HDR et le multiplicateur utilisé.

## Restauration d'urgence

Fermez BeamNG puis lancez `Uninstall FrameGenNG.cmd`. La restauration utilise l'état et les sauvegardes conservés dans le dossier utilisateur. Les fichiers modifiés après installation sont copiés dans un dossier `recovery-before-uninstall-*` avant d'être remplacés.

