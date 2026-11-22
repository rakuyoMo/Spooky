---
title: "Sous-modules"
description: "Ouvrez, mettez à jour, récupérez, initialisez, synchronisez, déplacez, renommez et supprimez des sous-modules."
---

Un sous-module est un autre dépôt Git placé dans un dossier de votre dépôt. Votre dépôt enregistre quel commit de celui-ci utiliser. Spooky appelle cet enregistrement le pointeur du sous-module.

## Dans la barre latérale {#sidebar}

Les sous-modules sont listés sous :ui[submodule.group] dans la barre latérale, triés par chemin. Placez le pointeur sur l’un d’eux pour voir son nom et son URL.

- Une ligne estompée est un sous-module qui n’est pas encore extrait.
- Une icône d’avertissement signifie que sa configuration est incomplète, ou que son URL doit être synchronisée.
- Un nombre indique combien de fichiers ont changé à l’intérieur.
- ↑ et ↓ indiquent de combien le commit extrait est en avance ou en retard sur le pointeur.

Cliquez sur un sous-module pour voir ses détails. Double-cliquez sur un sous-module extrait pour l’ouvrir comme un dépôt dans la même fenêtre. Tant qu’il est ouvert, :ui[toolbar.parentRepository] dans la barre d’outils vous ramène en arrière.

Un double-clic sur un sous-module extrait dans la liste de fichiers de la copie de travail l’ouvre de la même façon. Pour que ce double-clic l’ouvre plutôt comme les autres fichiers, désactivez :ui[files.openSubmodules] dans :ui[app.name > settings.title] › :ui[settings.general]. Consultez [Liste de fichiers](/guide/settings/general/#file-list).

## Détails {#details}

Les détails comportent trois pages, que vous choisissez en haut :

- :ui[submodule.page.general] : le nom, le chemin, l’état, les modifications locales, le commit extrait, le pointeur et les réglages en vigueur. Si le sous-module n’est pas initialisé, ou si son URL dans `.gitmodules` a changé, une note en haut propose un bouton pour y remédier.
- :ui[submodule.page.shared] : les réglages de `.gitmodules`. Tous ceux qui clonent le dépôt les reçoivent. Les modifications faites ici apparaissent dans la copie de travail. Vous les validez comme les autres modifications.
- :ui[submodule.page.local] : les réglages de la configuration propre à ce dépôt. Ils ne s’appliquent qu’ici. Ils l’emportent sur `.gitmodules`.

Sur les deux pages de configuration, vous pouvez renommer et déplacer le sous-module, changer son URL et régler trois options. :ui[submodule.useDefault] retire une option. La valeur par défaut de Git s’applique alors.

- :ui[submodule.field.fetchMode] : si la récupération du dépôt parent récupère aussi ce sous-module. Choisissez :ui[submodule.fetchMode.always], :ui[submodule.fetchMode.onDemand] (seulement quand les commits récupérés changent son pointeur, valeur par défaut) ou :ui[submodule.fetchMode.never].
- :ui[submodule.field.ignoreMode] : quelles modifications du sous-module la copie de travail du parent ignore. Choisissez :ui[submodule.ignoreMode.none] (valeur par défaut), :ui[submodule.ignoreMode.untracked], :ui[submodule.ignoreMode.dirty] (seul un autre commit extrait compte) ou :ui[submodule.ignoreMode.all].
- :ui[submodule.field.updateStrategy] : comment la mise à jour amène le sous-module à son pointeur. Choisissez :ui[submodule.updateStrategy.checkout] (valeur par défaut), :ui[submodule.updateStrategy.rebase] ou :ui[submodule.updateStrategy.merge] sur sa branche actuelle, ou :ui[submodule.updateStrategy.none].

## Ajouter un sous-module {#add}

1. Choisissez :ui[menu.repository > menu.addSubmodule] dans la barre des menus. Vous pouvez aussi cliquer sur le bouton d’ajout en bas de la barre latérale, ou cliquer avec le bouton droit sur :ui[submodule.group], et choisir :ui[submodule.add.menu] dans le menu.
2. Saisissez l’URL du dépôt du sous-module.
3. Pour :ui[submodule.path], choisissez :ui[submodule.path.select] et sélectionnez un dossier vide dans votre dépôt.
4. Cliquez sur :ui[submodule.add.submit].

Si votre dépôt a déjà un répertoire Git pour un sous-module de ce nom, par exemple celui d’un sous-module que vous avez supprimé, Spooky demande quoi faire. :ui[submodule.forceAdd.reuse] le réutilise. :ui[submodule.forceAdd.overwrite] le supprime et clone à nouveau.

## Récupérer et mettre à jour {#update}

- **Récupérer** télécharge les nouveaux commits depuis le dépôt distant du sous-module. Ce qui est extrait ne change pas.
- **Mettre à jour** extrait le commit que le pointeur enregistre. Un sous-module qui n’est pas initialisé est d’abord initialisé.

Cliquez sur un sous-module avec le bouton droit et choisissez :ui[submodule.fetch.menu]{1="vendor/charts"} ou :ui[submodule.update.menu]{1="vendor/charts"} dans le menu. Le menu :ui[menu.repository] propose les mêmes éléments, plus des éléments pour tous les sous-modules à la fois.

Les zones de dialogue ont ces options :

- :ui[sync.prune] lors de la récupération
- :ui[submodule.update.recursive] lors de la mise à jour. Elle met aussi à jour les sous-modules contenus dans le sous-module. Leurs dépôts distants doivent fonctionner avec des identifiants déjà configurés. Spooky ne peut pas vous les demander en cours de route.

Maintenez <kbd>⌥</kbd> enfoncée dans le menu contextuel pour obtenir :ui[submodule.quickFetch]{1="vendor/charts"} et :ui[submodule.quickUpdate]{1="vendor/charts"}. Ils sautent la zone de dialogue et reprennent les options de la dernière fois. Il en va de même pour :ui[menu.fetchAllSubmodules] et :ui[menu.updateAllSubmodules] dans la barre des menus.

La mise à jour n’est disponible que s’il y a quelque chose à faire : le sous-module n’est pas extrait, ou un autre commit est extrait.

### Mettre à jour après d’autres opérations {#auto-update}

Le basculement sur une branche, le tirage, la fusion et d’autres opérations peuvent changer le pointeur d’un sous-module extrait. Spooky demande ensuite s’il faut mettre ces sous-modules à jour. Cochez :ui[submodule.autoUpdate.always] pour les mettre à jour aussitôt à partir de là. Vous pouvez revenir en arrière avec :ui[settings.autoUpdateSubmodules] dans :ui[app.name > settings.title] › :ui[settings.general]. Consultez [Opérations](/guide/settings/general/#operations).

### Initialiser et synchroniser {#initialize}

- **Initialiser** copie les réglages du sous-module de `.gitmodules` dans la configuration de votre dépôt. Mettez-le ensuite à jour pour l’extraire.
- **Synchroniser** sert quand l’URL dans `.gitmodules` a changé. L’URL de la configuration de votre dépôt, et celle du dépôt du sous-module lui-même, sont alignées sur la nouvelle.

Les deux se trouvent dans le menu contextuel, et dans une note sur la page :ui[submodule.page.general] quand ils sont nécessaires.

## Extraire une autre révision {#checkout}

Cliquez avec le bouton droit sur un sous-module extrait et choisissez une branche ou un tag du sous-module dans :ui[submodule.checkoutRevision]. La révision actuelle a une coche.

Si des modifications à l’intérieur du sous-module gênent, l’extraction échoue. Spooky ne propose pas de les remiser. Les remisages de votre dépôt ne couvrent pas le sous-module.

Le pointeur de votre dépôt ne bouge pas tant que vous n’avez pas validé le nouveau commit du sous-module.

## Déplacer, renommer et supprimer {#manage}

Les trois se trouvent dans le menu contextuel :

- **Déplacer** change le chemin du sous-module. Cochez :ui[submodule.move.rename] pour le renommer aussi d’après le nouveau chemin.
- **Renommer** change son nom. `.gitmodules` et votre configuration désignent le sous-module par ce nom. Le dossier reste où il est.
- **Supprimer** retire le sous-module de votre dépôt. Cochez :ui[submodule.delete.keepWorkingTree] pour ne retirer que sa configuration et garder ses fichiers. S’il contient des modifications, Spooky demande confirmation avant de le supprimer quand même avec :ui[submodule.forceDelete.submit].

Ces opérations modifient `.gitmodules` et l’index de votre dépôt. Validez-les pour que les autres les reçoivent aussi.

Après une suppression, le répertoire Git du sous-module reste dans le dossier `.git` de votre dépôt. Un nouvel ajout peut le réutiliser.

### Réparer un sous-module {#repair}

Quand la configuration d’un sous-module est incomplète, ses détails indiquent :ui[submodule.invalid], avec deux boutons. :ui[submodule.repair.submit] restaure ce qui manque : l’entrée dans `.gitmodules`, le pointeur ou le dépôt extrait. Si Spooky ne trouve l’URL du sous-module nulle part, supprimez-le et ajoutez-le à nouveau.

## Annuler {#undo}

Vous pouvez annuler l’ajout, le déplacement, le renommage et la suppression d’un sous-module, l’extraction d’une autre révision dans celui-ci, et la modification de son URL ou de ses options. Consultez [Annulation et récupération](/guide/work/undo/).

L’initialisation, la synchronisation et la réparation ne peuvent pas être annulées. Après l’une d’elles, les opérations qui la précèdent ne peuvent plus l’être non plus.

La récupération et la mise à jour ne sont pas enregistrées, tout comme récupérer et tirer dans le dépôt. Les opérations qui les précèdent peuvent encore être annulées.

:::note[Dépôts sur un serveur]
Tout cela s’exécute sur le serveur. Quand vous ajoutez un sous-module, vous choisissez son dossier sur le serveur.
:::

## Voir aussi

- [Récupérer, tirer et pousser](/guide/branches/sync/)
- [Worktrees](/guide/advanced/worktrees/)
- [Annulation et récupération](/guide/work/undo/)
