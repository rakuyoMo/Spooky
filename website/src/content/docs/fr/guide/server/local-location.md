---
title: "Emplacement sur ce Mac"
description: "Donnez à un dépôt sur un serveur un emplacement sur ce Mac, par recherche automatique, par montage SMB ou sshfs, ou avec un dossier de votre choix, pour que l’affichage dans le Finder, le terminal et les éditeurs externes puissent l’ouvrir."
---

Le Finder ne peut afficher que des dossiers de votre Mac. Les fichiers d’un dépôt sur un serveur sont sur le serveur. Pour les afficher dans le Finder, Spooky a besoin d’un dossier sur ce Mac où apparaissent les fichiers du serveur, en général un volume réseau monté. Ce dossier est l’emplacement du dépôt sur ce Mac.

Cette page explique comment Spooky trouve ou monte ce dossier, et comment Terminal et les autres apps ouvrent un dépôt sur un serveur.

## Afficher dans le Finder {#show-in-finder}

:ui[action.revealFinder] est toujours disponible dans un dépôt sur un serveur. Vous le trouverez à ces endroits :

- Le menu :ui[menu.file]
- :ui[toolbar.finder] dans la barre d’outils. Pour l’ajouter, choisissez :ui[menu.view > menu.customizeToolbar] et faites-le glisser dans la barre d’outils.
- La ligne :ui[workspace.title] de la barre latérale, quand vous cliquez dessus avec le bouton droit
- Les [Actions rapides](/guide/repositories/navigation/#quick-actions)
- La fenêtre Dépôts, quand vous cliquez avec le bouton droit sur un dépôt sur un serveur
- Les fichiers de la copie de travail, quand vous cliquez dessus avec le bouton droit. Le Finder sélectionne ces fichiers.

Si l’emplacement est connu et que le dossier est là, le Finder s’ouvre tout de suite. Sinon, Spooky affiche une feuille et suit ces étapes :

1. Si le dépôt n’est pas connecté, Spooky se connecte d’abord.
2. Il cherche le dossier, et le monte si la méthode est SMB ou sshfs.
3. S’il ne trouve toujours pas le dossier, la feuille devient le formulaire de définition de l’emplacement, avec la raison en haut. Consultez [Définir l’emplacement](#set).

Cliquez sur :ui[action.cancel] pour fermer la feuille. Vos réglages ne changent pas.

## Définir l’emplacement {#set}

1. Dans la barre latérale, sous :ui[workspace.group], cliquez sur :ui[repositorySettings.title].
2. Sur la page :ui[repositorySettings.general], repérez :ui[repositorySettings.localLocation]. La ligne affiche la méthode et le dossier, ou la raison pour laquelle il n’y a pas de dossier, comme :ui[localLocation.notMounted].
3. Placez le pointeur sur la ligne, puis cliquez sur :ui[localLocation.change] quand il apparaît. Le dépôt doit être connecté.
4. Dans :ui[localLocation.title], choisissez une méthode à côté de :ui[localLocation.method].
5. Cliquez sur :ui[localLocation.mount] pour un montage, ou sur :ui[localLocation.save] pour les autres méthodes.

Pendant que Spooky monte ou vérifie le dossier, le formulaire est verrouillé. Cliquez sur :ui[action.cancel] pour arrêter. Votre réglage précédent est conservé.

L’emplacement est enregistré sur ce Mac pour chaque dépôt sur un serveur. Spooky ne l’écrit ni dans le dépôt ni sur le serveur.

Si un montage SMB ou sshfs a été éjecté, la ligne affiche :ui[localLocation.mountAgain]. Cliquez dessus pour monter à nouveau le dossier.

## Méthodes {#methods}

Le menu :ui[localLocation.method] ne liste que les méthodes qui fonctionnent à ce moment-là. La méthode actuelle y figure toujours.

### Automatique {#automatic}

:ui[localLocation.method.automatic] est la méthode par défaut. Spooky passe en revue les volumes réseau déjà montés sur ce Mac, comme les volumes SMB, NFS, AFP, WebDAV et sshfs. Peu importe l’app qui les a montés. Un volume compte si son serveur a la même adresse que votre alias d’hôte.

Spooky cherche ensuite le dossier du dépôt dans le volume. Pour s’assurer qu’il s’agit du même dépôt, Spooky place brièvement un fichier vide dans le dossier Git du dépôt sur le serveur, vérifie qu’il apparaît sur le volume, puis le supprime.

### Montage SMB {#smb}

:ui[localLocation.method.smbMount] monte un dossier partagé du serveur avec SMB, le protocole de partage de fichiers qu’utilise macOS. Elle est proposée quand le serveur répond sur le port SMB en moins de 2 secondes.

1. Choisissez :ui[localLocation.method.smbMount], puis cliquez sur :ui[localLocation.mount].
2. macOS affiche les dossiers partagés du serveur, ou vous demande d’abord de vous connecter. Choisissez le partage qui contient le dépôt.

Spooky retient le partage et le monte à nouveau la fois suivante sans rien demander. Si le dépôt n’est pas dans le partage choisi, le formulaire affiche :ui[localLocation.notInShare] Choisissez un autre partage et réessayez.

Si le serveur est un Mac, activez **Partage de fichiers** dans **menu Pomme › Réglages Système › Général › Partage** sur ce Mac.

### Montage sshfs {#sshfs}

:ui[localLocation.method.sshfsMount] monte le dossier du dépôt via SSH, avec le même alias d’hôte que Spooky. Elle nécessite sshfs et macFUSE ou FUSE-T sur ce Mac. Spooky cherche `sshfs` dans `/opt/homebrew/bin`, `/usr/local/bin` et votre `PATH`. S’il n’est pas installé, cette méthode n’est pas proposée.

1. Choisissez :ui[localLocation.method.sshfsMount].
2. À côté de :ui[localLocation.mountAt], cliquez sur :ui[localLocation.choose] et choisissez un dossier vide sur ce Mac. Les fichiers du serveur y apparaissent.
3. Cliquez sur :ui[localLocation.mount].

### Dossier choisi {#chosen-folder}

:ui[localLocation.method.chosenFolder] vous laisse choisir le dossier vous-même, par exemple un dossier que vous avez monté d’une autre façon.

1. Choisissez :ui[localLocation.method.chosenFolder].
2. À côté de :ui[localLocation.folder], cliquez sur :ui[localLocation.choose] et choisissez le dossier du dépôt.
3. Cliquez sur :ui[localLocation.save]. Spooky vérifie le dossier avant d’enregistrer.

Spooky n’éjecte jamais un volume qu’il a monté. Quand vous rouvrez le dépôt plus tard, Spooky le monte à nouveau en arrière-plan, sans rien demander.

## Monter lors de l’ajout {#when-adding}

Quand vous [ajoutez un dépôt sur un serveur](/guide/server/add/), :ui[remote.mount] configure l’emplacement dans la même étape. Il est d’abord réglé sur :ui[remote.mount.none]. Une fois l’alias d’hôte renseigné, le menu propose :ui[remote.mount.smb] et :ui[remote.mount.sshfs] s’ils sont disponibles. Si aucun ne l’est, il affiche :ui[remote.mount.unavailable].

- **SMB :** Une fois le dépôt ouvert, macOS affiche les dossiers partagés du serveur ou une fenêtre de connexion. Si vous annulez, le dépôt s’ouvre quand même, et :ui[repositorySettings.localLocation], dans ses réglages, indique pourquoi il n’est pas monté.
- **sshfs :** Une ligne :ui[localLocation.mountAt] supplémentaire apparaît. Choisissez un dossier vide. Spooky y monte le dépôt après son ouverture.

Si vous changez l’alias d’hôte, le menu revient à :ui[remote.mount.none].

## Terminal et autres apps {#terminal}

Ces commandes fonctionnent dans un dépôt sur un serveur sans emplacement sur ce Mac :

- **:ui[action.openTerminal]** ouvre l’app de terminal choisie dans :ui[app.name > settings.title] › :ui[settings.general], ouvre une session avec `ssh -t` et l’alias d’hôte, puis se place dans le dossier du dépôt. Si le serveur n’autorise pas de terminal, Spooky se reconnecte sans terminal. Les commandes fonctionnent toujours, mais pas l’édition de ligne ni les programmes en plein écran. Vous la trouverez dans le menu :ui[menu.file], sous le nom :ui[toolbar.terminal] dans la barre d’outils, et en cliquant avec le bouton droit sur la copie de travail ou sur un dépôt dans la fenêtre Dépôts. Pour choisir l’app de terminal, consultez [Terminal](/guide/settings/integration/#terminal).
- **:ui[action.copyPath]** copie le chemin précédé de l’alias d’hôte, comme `driftwood-server:/srv/git/driftwood`.
- **:ui[files.open] et :ui[files.openWith]**, dans la copie de travail, ouvrent un fichier dans une autre app. Visual Studio Code, Visual Studio Code Insiders et Cursor ouvrent le fichier directement sur le serveur, si une extension Remote SSH est installée. Les autres apps reçoivent une copie sur ce Mac. Quand vous enregistrez, Spooky réécrit la copie sur le serveur.

Si le fichier a changé sur le serveur entre-temps, Spooky demande avant d’écrire : :ui[externalTool.fileChanged]. Cliquez sur :ui[externalTool.overwrite] pour le remplacer par votre copie. Spooky supprime les copies quand vous fermez le dépôt.

Coup d’œil et les outils externes de comparaison et de fusion travaillent eux aussi sur des copies. Quand un outil de fusion a terminé, Spooky réécrit le résultat sur le serveur et l’indexe.

## Voir aussi

- [Fonctionnement des dépôts sur un serveur](/guide/server/overview/)
- [Ajouter un dépôt sur un serveur](/guide/server/add/)
- [Intégration](/guide/settings/integration/)
