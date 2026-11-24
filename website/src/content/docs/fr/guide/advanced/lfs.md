---
title: "Git LFS"
description: "Activez Git LFS, suivez des fichiers et des motifs, et récupérez, tirez et poussez du contenu LFS."
---

Git LFS garde les fichiers volumineux hors de l’historique du dépôt. Le dépôt stocke un petit fichier pointeur pour chacun d’eux. Le contenu va dans un espace de stockage LFS sur le dépôt distant.

Spooky exécute Git LFS sur la machine où se trouve le dépôt.

## Ce qu’il vous faut {#requirements}

Git LFS 2.9.0 ou ultérieur, dans le `PATH` que Git utilise sur la machine où se trouve le dépôt.

Pour vérifier, cliquez sur :ui[repositorySettings.title] sous :ui[workspace.group] dans la barre latérale. La section :ui[repositorySettings.lfs] affiche la :ui[lfs.version] de Git LFS. Consultez [Git LFS, fichiers ignorés et exclusions](/guide/settings/identity/#repository-files).

Si Git LFS est introuvable ou trop ancien, une note y indique comment y remédier :

- **Sur votre Mac** : installez ou mettez à jour Git LFS. S’il est installé mais introuvable, ouvrez :ui[app.name > settings.title] › :ui[settings.environment]. Cochez :ui[settings.environment.loginShell], ou ajoutez `PATH` comme variable personnalisée. Consultez [Variables sur ce Mac](/guide/settings/general/#local-variables).
- **Sur un serveur** : installez ou mettez à jour Git LFS sur le serveur. Ajoutez son dossier au `PATH` des sessions SSH non interactives, par exemple dans `~/.zshenv`.

Tant que Git LFS est absent, les boutons de cette section qui en ont besoin ne sont pas disponibles.

Dans un dépôt qui utilise Git LFS, d’autres opérations, comme changer de branche ou indexer, peuvent échouer pour la même raison. Spooky affiche alors :ui[hostError.lfsUnavailable] avec les mêmes conseils.

## Activer Git LFS {#enable}

Dans la section :ui[repositorySettings.lfs] des réglages du dépôt, cliquez sur :ui[lfs.enable]. Cela configure Git LFS pour ce dépôt uniquement. Votre configuration Git globale ne change pas. Consultez [Git LFS, fichiers ignorés et exclusions](/guide/settings/identity/#repository-files).

Spooky considère qu’un dépôt utilise Git LFS quand Git a les filtres Git LFS configurés et que le dépôt a les crochets Git LFS. Jusque-là, la section ne propose que :ui[lfs.enable]. Les éléments de menu LFS ne sont pas disponibles non plus.

Quand vous clonez un dépôt qui utilise Git LFS, cochez :ui[clone.lfs]. Consultez [Cloner un dépôt](/guide/repositories/manager/#clone).

Après une mise à jour de Git LFS, choisissez :ui[menu.repository > lfs.menu > lfs.menu.update] dans la barre des menus pour mettre à jour les crochets Git LFS du dépôt.

## Suivre des fichiers {#track}

Les fichiers qui correspondent à un motif de suivi sont stockés avec Git LFS. Les motifs vont dans `.gitattributes` à la racine du dépôt. Tous ceux qui utilisent le dépôt les reçoivent. La modification de `.gitattributes` apparaît dans la copie de travail. Validez-la comme les autres modifications.

Pour ajouter un motif, cliquez sur :ui[lfs.createPattern] dans les réglages du dépôt, ou choisissez :ui[menu.repository > lfs.menu > lfs.menu.track] dans la barre des menus. Saisissez un motif comme `*.psd`, puis cliquez sur :ui[files.pattern.save].

::screenshot[La section Git LFS des réglages d’un dépôt. Elle affiche la version de Git LFS installée et deux motifs de suivi, *.psd et *.mp4. La ligne *.psd affiche le bouton de suppression qui apparaît quand le pointeur est sur un motif.]{name="advanced-lfs-settings" frame="window" markers="34.5,24 90,35.6 47.7,34.4"}

1. La version de Git LFS installée
2. Le bouton qui supprime un motif
3. :ui[lfs.createPattern]

Vous pouvez aussi cliquer avec le bouton droit sur des fichiers dans la copie de travail et choisir dans :ui[lfs.menu] :

- :ui[lfs.trackFile] : ne suivre que les fichiers sélectionnés, avec leur chemin exact. Avec plusieurs fichiers, l’élément indique combien.
- :ui[lfs.trackType.single]{1="psd"} : suivre tous les fichiers de même extension. Avec plusieurs fichiers, l’élément est :ui[lfs.trackType]. Il couvre chacune de leurs extensions.
- :ui[lfs.createPattern.menu] : saisir vous-même un motif, à partir du chemin du premier fichier sélectionné.

Pour un dossier, seul :ui[lfs.createPattern.menu] est disponible.

### Ne plus suivre un motif {#untrack}

Dans les réglages du dépôt, cliquez sur :ui[lfs.remove] à côté d’un motif, et confirmez. Le motif est retiré de `.gitattributes`. Les fichiers déjà stockés avec Git LFS restent tels quels.

Si Git LFS ne parvient pas à retirer un motif, Spooky indique lesquels restent. Retirez-les à la main avec :ui[repositorySettings.openInEditor] à côté de :ui[repositorySettings.lfs.patterns]. Consultez [Git LFS, fichiers ignorés et exclusions](/guide/settings/identity/#repository-files).

## Récupérer, tirer et pousser du contenu LFS {#transfer}

Une fois Git LFS configuré, Git télécharge normalement le contenu LFS quand il extrait les fichiers. Il envoie le contenu quand vous poussez. Pour le faire vous-même, choisissez dans :ui[menu.repository > lfs.menu] dans la barre des menus :

| Élément | Ce qu’il fait |
|---|---|
| :ui[lfs.menu.fetch] | Télécharge le contenu LFS nécessaire à l’extraction actuelle. La copie de travail ne change pas. |
| :ui[lfs.menu.pull] | Le télécharge, puis remplace les fichiers pointeurs de la copie de travail par le contenu. |
| :ui[lfs.menu.push] | Envoie le contenu LFS utilisé par toutes les branches et tous les tags locaux que le dépôt distant n’a pas encore. |

Choisissez un dépôt distant dans la zone de dialogue. Au départ, c’est le dépôt distant de la branche amont de la branche actuelle, ou le premier dépôt distant s’il n’y a pas de branche amont. La progression apparaît dans la [zone d’activité](/guide/advanced/queue-activity/#activity-area) en bas de la barre latérale.

## Annuler {#undo}

Vous pouvez annuler l’activation de Git LFS, l’ajout d’un motif de suivi et son retrait. Consultez [Annulation et récupération](/guide/work/undo/).

La mise à jour des crochets ne peut pas être annulée. Les opérations qui la précèdent ne peuvent plus l’être non plus.

La récupération, le tirage et la poussée de contenu LFS ne sont pas enregistrés, tout comme récupérer, tirer et pousser dans le dépôt. Les opérations qui les précèdent peuvent encore être annulées.

:::note[Dépôts sur un serveur]
Git LFS s’exécute sur le serveur. Le contenu LFS circule entre le serveur et le dépôt distant. Votre Mac n’a pas besoin de Git LFS pour un dépôt sur un serveur.
:::

## Voir aussi

- [Configuration requise](/reference/requirements/#optional)
- [Sous-modules](/guide/advanced/submodules/)
- [La fenêtre Dépôts](/guide/repositories/manager/)
