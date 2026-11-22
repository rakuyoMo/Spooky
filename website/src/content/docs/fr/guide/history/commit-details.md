---
title: "Détails d’un commit"
description: "Examinez les détails d’un commit, ses modifications, son arborescence de fichiers et l’état de sa signature, comparez des révisions et exportez des fichiers."
---

Sélectionnez un commit dans l’[historique](/guide/history/browse/), et la colonne de droite affiche ses détails : qui l’a créé et quand, le message complet et les fichiers qu’il a modifiés.

## L’en-tête {#header}

La barre du haut affiche le hash court du commit et les boutons :ui[history.changeset] et :ui[history.tree]. Vous pouvez sélectionner et copier le hash. Sous la barre, l’en-tête liste :

- :ui[history.author] et :ui[history.committer], avec leurs dates. L’avatar de droite est celui de l’auteur. Si quelqu’un d’autre a validé le commit, l’avatar du validateur figure à sa gauche.
- :ui[history.refs], les branches et les tags qui pointent sur le commit
- :ui[history.hash], le hash complet
- :ui[history.parentHash], une ligne par parent
- :ui[history.treeHash]
- La signature, si le commit est signé. Consultez [Signatures](#signatures).

Cliquez sur la flèche en haut à droite pour réduire l’en-tête à l’auteur, à la date et aux références. Spooky retient votre choix. Le message complet suit l’en-tête.

### Boutons d’action {#actions}

Placez le pointeur sur les détails, et une rangée de boutons apparaît sur la ligne qui sépare l’en-tête du message :

- :ui[history.rollback] ouvre la zone de dialogue qui réinitialise la branche actuelle à ce commit. Consultez [Réinitialiser à un commit antérieur](/guide/history/rewrite/#reset).
- :ui[rewrite.revert.button] ouvre la zone de dialogue qui ajoute un commit annulant celui-ci. Consultez [Annuler un commit par revert](/guide/history/rewrite/#revert).
- :ui[history.diffTool] ouvre toutes les modifications du commit dans votre outil de comparaison. Consultez [Comparer dans une autre app](/guide/work/diff/#external).

:ui[history.rollback] et :ui[rewrite.revert.button] n’apparaissent que tant que la liste affiche la branche sur laquelle vous êtes.

## Les modifications {#changeset}

:ui[history.changeset] liste les fichiers que le commit a modifiés, triés par chemin. La ligne au-dessus de la liste compte les fichiers, les ajouts et les suppressions.

- Cliquez sur la flèche à côté d’un fichier pour afficher ses modifications. Pour afficher ou masquer les modifications de tous les fichiers, cliquez sur :ui[history.expandAll] ou :ui[history.collapseAll] au début de la ligne au-dessus de la liste, ou appuyez sur <kbd>⌃⌘→</kbd> ou <kbd>⌃⌘←</kbd>.
- Cliquez sur un fichier pour le sélectionner. Cliquez en maintenant <kbd>⇧</kbd> ou <kbd>⌘</kbd> enfoncée pour en sélectionner plusieurs. <kbd>↑</kbd> <kbd>↓</kbd> déplacent la sélection.

Les fichiers sont d’abord réduits. Pour qu’ils s’ouvrent tout seuls, choisissez un nombre sous :ui[history.autoExpand.title] dans :ui[menu.view > history.diffs]. Un commit qui ne modifie pas plus de fichiers que ce nombre ouvre tous les diffs. :ui[history.autoExpand.always] les ouvre toujours.

Pour un commit de fusion, :ui[history.mergeDiff] dans :ui[app.name > settings.title] › :ui[settings.general] décide de ce que les modifications affichent :

- :ui[history.mergeDiff.firstParent] (par défaut) affiche les modifications que la fusion a apportées à la branche.
- :ui[history.mergeDiff.mergedFilePaths] n’affiche que les fichiers qui diffèrent de tous les parents.
- :ui[history.mergeDiff.off] n’affiche aucune modification.

Consultez [Historique et diffs](/guide/settings/general/#history).

Cliquez sur un fichier avec le bouton droit pour :

- Copier son chemin, ou son chemin dans le dépôt
- Afficher le fichier tel qu’il était dans ce commit, son blame ou son historique. Consultez [Historique du fichier et blame](/guide/history/file-views/).
- L’ouvrir dans votre outil de comparaison, comparé au premier parent du commit
- Le restaurer dans la copie de travail à la version de ce commit. Consultez [Restaurer un fichier depuis une révision](/guide/history/file-views/#restore).
- Enregistrer sur votre Mac la version qu’il a dans ce commit

Avec plusieurs fichiers sélectionnés, vous pouvez les ouvrir dans votre outil de comparaison, les restaurer ou les exporter ensemble.

## L’arborescence de fichiers {#tree}

:ui[history.tree] affiche tous les fichiers du dépôt tels qu’ils étaient dans ce commit, pas seulement ceux qui ont été modifiés. Cliquez sur la flèche à côté d’un dossier pour l’ouvrir.

Cliquez sur un fichier ou un dossier avec le bouton droit pour :

- Ouvrir le fichier dans son app par défaut, ou dans une app de votre choix
- Afficher le fichier, son blame ou son historique
- Le restaurer dans la copie de travail à la version de ce commit
- L’exporter, ou l’enregistrer dans une archive zip

L’ouverture et l’affichage ne concernent que les fichiers. Avec plusieurs éléments sélectionnés, vous pouvez les ouvrir, les restaurer, les exporter ou les archiver ensemble. Les éléments exportés vont dans un dossier que vous choisissez. Si des éléments du même nom s’y trouvent déjà, Spooky demande confirmation avant de les écraser.

## Détails en pleine page {#full-page}

Double-cliquez sur un commit dans la liste pour donner toute la fenêtre à ses détails. La colonne de gauche affiche le commit, avec la liste des fichiers modifiés en dessous. La colonne de droite affiche les modifications du fichier sélectionné.

- Cliquez sur le hash court en haut à gauche pour choisir un autre commit. Double-cliquez sur un commit dans la liste pour y passer.
- Double-cliquez sur un fichier, ou appuyez sur <kbd>Retour</kbd>, pour ouvrir dans son app par défaut la version qu’il a dans ce commit.

Pour revenir à l’historique, choisissez :ui[menu.view > navigation.back] (<kbd>⌘[</kbd>), ou cliquez sur :ui[toolbar.previous] dans la barre d’outils.

## Plusieurs commits {#multiple}

Sélectionnez plus d’un commit, et la colonne de droite indique combien. En dessous figurent ces boutons :

- :ui[rewrite.cherryPick.button] applique les commits à la branche sur laquelle vous êtes. Tant que la liste affiche cette branche, le bouton est :ui[rewrite.revert.button]. Consultez [Réécrire l’historique](/guide/history/rewrite/).
- :ui[compare.submit] apparaît quand exactement deux commits sont sélectionnés. Il montre ce qui a changé du commit le plus ancien au plus récent. Maintenez <kbd>⌥</kbd> enfoncée pour comparer dans l’autre sens.

## Signatures {#signatures}

Les détails vérifient la signature du commit que vous sélectionnez. L’en-tête développé affiche la clé et l’état, comme :ui[signature.good].

Pour voir aussi les signatures dans la liste, activez :ui[signature.verify] dans les [options de présentation](/guide/history/browse/#view-options). Les commits signés reçoivent alors un point à la fin de leur ligne :

- Vert : la signature est valide.
- Rouge : la signature est incorrecte.
- Jaune : tout autre état, comme une clé expirée ou une signature que Spooky ne peut pas vérifier.

Cliquez sur le point pour voir la clé et l’état.

## Comparer deux révisions {#compare}

Pour voir ce qui a changé entre deux commits, branches ou tags quelconques :

1. Choisissez :ui[menu.repository > compare.menu] dans la barre des menus. Ou cliquez sur un commit avec le bouton droit et choisissez :ui[compare.menuFrom]{1="e2dda2bc"} pour partir de lui.
2. Remplissez :ui[compare.base] et :ui[compare.target]. Les menus listent vos branches, vos branches distantes et vos tags. Vous pouvez aussi saisir un hash.
3. Cliquez sur :ui[compare.submit].

La colonne de droite affiche la comparaison. :ui[compare.commits] liste les commits que la seconde révision a et que la première n’a pas. :ui[history.changeset] affiche les modifications de la première à la seconde. Pour la fermer, cliquez sur × en haut à droite, ou sélectionnez un autre commit.

Avec deux commits sélectionnés, le menu propose directement :ui[compare.menuPair]{1="e2dda2bc" 2="f6b437e0"}.

## Exporter des fichiers {#export}

Pour enregistrer tous les fichiers d’un commit tels qu’ils étaient à ce moment-là :

1. Cliquez sur un commit avec le bouton droit et choisissez :ui[export.menuFrom]{1="e2dda2bc"} dans le menu. :ui[menu.repository > export.menu], dans la barre des menus, part du commit sélectionné.
2. Vérifiez la révision. Pour obtenir un seul fichier zip, cochez :ui[export.createArchive].
3. Cliquez sur :ui[export.submit] et choisissez où enregistrer.

Sans archive, vous obtenez un dossier nommé d’après le dépôt et le hash court.

L’export apparaît dans la [fenêtre Activité](/guide/advanced/queue-activity/), où vous pouvez l’annuler.

## Enregistrer un patch {#patch}

Un patch est un fichier texte qui contient les modifications d’un commit. Vous pouvez l’appliquer dans un autre dépôt avec `git am`.

1. Cliquez sur un commit avec le bouton droit et choisissez :ui[patch.menu]{1="e2dda2bc"} dans le menu. Avec plusieurs commits sélectionnés, l’élément enregistre un patch pour chacun.
2. Cochez :ui[patch.omitPrefixes] pour omettre les `a/` et `b/` devant chaque chemin.
3. Cliquez sur :ui[patch.save] et choisissez un dossier.

Chaque commit a son propre fichier, numéroté du plus ancien au plus récent, comme `0001-Add-a-theme-toggle-to-the-header.patch`. Une fois l’opération terminée, le Finder s’ouvre avec les fichiers sélectionnés. L’enregistrement apparaît aussi dans la fenêtre Activité.

Maintenez <kbd>⌥</kbd> enfoncée dans le menu pour obtenir :ui[patch.quickMenu]{1="e2dda2bc"}. Il enregistre aussitôt dans le dossier du dépôt, avec votre dernier choix pour :ui[patch.omitPrefixes].

:::note[Dépôts sur un serveur]
Les exports et les patchs que vous enregistrez avec :ui[patch.save] vont sur votre Mac. Un patch enregistré aussitôt va dans le dossier du dépôt sur le serveur.
:::

## Copier les informations d’un commit {#copy}

Cliquez sur un commit avec le bouton droit pour copier :

- :ui[history.copyHash], le hash complet
- :ui[history.copyInfo], le hash court et la première ligne du message

Avec plusieurs commits sélectionnés, vous obtenez une ligne pour chacun.

## Voir aussi

- [Parcourir l’historique](/guide/history/browse/)
- [Historique du fichier et blame](/guide/history/file-views/)
- [Réécrire l’historique](/guide/history/rewrite/)
