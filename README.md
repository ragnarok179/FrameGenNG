# FrameGenNG

Frame generation intégré aux paramètres graphiques de BeamNG.drive.

FrameGenNG utilise l'entrée DLSS native de BeamNG en DirectX 12 pour fournir une génération d'images réglable directement sous les options DLSS du jeu. Le projet vise toutes les cartes NVIDIA RTX :

- RTX 20 et RTX 30 : chemin de compatibilité basé sur `dlssg_for_sm86` ;
- RTX 40 et RTX 50 : chemin DLSS-G natif via la couche d'intégration FrameGenNG ;
- générations RTX futures : objectif de compatibilité, après validation.

> **État actuel : alpha.** Le prototype a été validé sur BeamNG.drive 0.40.3.0 avec une RTX 3060 Laptop. Les RTX 20, 40 et 50 restent à tester avant qu'une compatibilité puisse être garantie.

## Installation simple

1. Fermez BeamNG.drive.
2. Décompressez le dossier `FrameGenNG` directement dans le dossier racine de BeamNG.drive, à côté de `Bin64`.
3. Ouvrez `FrameGenNG Manager.cmd`.
4. Cliquez sur **Installer**.
5. Lancez BeamNG en DirectX 12, activez DLSS, puis configurez la génération d'images sous les réglages DLSS.

Le gestionnaire ne cherche pas une installation Steam. Il accepte uniquement le dossier BeamNG qui contient directement le package. Le dossier utilisateur est lu depuis `%LOCALAPPDATA%\BeamNG\BeamNG.drive.ini`, ce qui prend en charge un emplacement personnalisé.

BeamNG affichera un avertissement concernant `dxgi.dll` et, sur RTX 20/30, `d3d12.dll`. C'est attendu : ces bibliothèques chargent la couche graphique de FrameGenNG. Elles sont sauvegardées avant toute modification.

## Sécurité et restauration

- Chaque fichier existant est sauvegardé avant installation.
- La désinstallation restaure les fichiers d'origine au lieu de simplement supprimer les DLL.
- Les réglages BeamNG ajoutés par FrameGenNG sont retirés sans écraser les autres changements effectués entre-temps.
- Si un fichier installé a été modifié après l'installation, une copie de récupération est conservée avant restauration.
- Les sauvegardes sont stockées dans le dossier utilisateur BeamNG, sous `FrameGenNG\backups`.
- **Réparer** effectue une restauration propre, puis réinstalle le package courant.

Ne supprimez pas manuellement le dossier de sauvegarde avant d'avoir désinstallé FrameGenNG.

## Compatibilité

Consultez [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) pour la matrice de test et les limites connues. L'architecture technique est décrite dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Développement et licences

FrameGenNG contient une version modifiée d'OptiScaler, distribuée sous GPLv3. Le patch correspondant et le commit amont épinglé sont fournis dans `source/optiscaler`. Les composants NVIDIA, Streamline et `dlssg_for_sm86` conservent leurs licences et notices respectives ; voir [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

FrameGenNG est un projet communautaire non officiel, sans affiliation avec BeamNG GmbH, NVIDIA, OptiScaler ou les auteurs de `dlssg_for_sm86`.

