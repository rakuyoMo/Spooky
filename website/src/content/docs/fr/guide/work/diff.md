---
title: "Examiner et indexer les modifications"
description: "Lisez les modifications d’un fichier, réglez l’affichage des diffs, et indexez ou abandonnez des modifications par fichier, par section ou par ligne."
---

Sélectionnez un fichier dans la copie de travail, et la colonne de droite affiche son diff : ce qui a changé, ligne par ligne. De là, vous pouvez n’indexer que les parties qui ont leur place dans le prochain commit et abandonner le reste.

## Lire un diff {#read}

Un diff est découpé en sections. Une section est un groupe de lignes modifiées, entouré de quelques lignes inchangées. Sa ligne d’en-tête indique où la section se trouve dans le fichier.

- Les lignes ajoutées sont en vert, et les lignes supprimées en rouge. Les deux colonnes de numéros de ligne correspondent à l’ancienne et à la nouvelle version du fichier.
- Quand un fichier a à la fois des modifications indexées et non indexées, passez des unes aux autres avec :ui[working.unstaged] et :ui[working.staged] en haut de la colonne. Un côté sans modification est estompé.
- La barre sous le diff affiche le nombre de sections et le nombre de lignes ajoutées et supprimées.
- Pour une image, le diff affiche l’ancienne et la nouvelle image. :ui[diff.twoUp] les place côte à côte. :ui[diff.oneUp] en affiche une à la fois, et vous passez de :ui[diff.old] à :ui[diff.new].

Un diff très volumineux peut ralentir la fenêtre, donc Spooky demande d’abord : :ui[working.largeDiff] Cliquez sur :ui[working.showDiff] pour le voir. La taille limite est :ui[working.diffThreshold] dans :ui[app.name > settings.title] › :ui[settings.general]. Elle est de 20 000 ko par défaut. Consultez [Historique et diffs](/guide/settings/general/#history).

## Options de diff {#options}

La barre sous le diff contient les options que vous changez le plus souvent :

- À son extrémité gauche se trouvent deux boutons. Placez le pointeur dessus pour voir leur nom.
  - :ui[diff.ignoreWhitespace] laisse de côté les modifications qui ne touchent que des espaces et des tabulations. Si rien d’autre n’a changé dans le fichier, le diff indique :ui[diff.onlyWhitespace]
  - :ui[diff.showEntireFile] affiche le fichier entier avec les modifications à leur place. Il ne s’applique qu’au diff que vous regardez.
- À son extrémité droite, :ui[diff.context] règle le nombre de lignes inchangées affichées autour de chaque modification. La valeur par défaut est 3. Vous pouvez aussi la choisir dans :ui[menu.view > diff.contextMenu].

Les réglages d’espaces et de contexte s’appliquent partout : dans tous les dépôts, dans la copie de travail et dans l’historique.

D’autres options se trouvent dans :ui[app.name > settings.title] › :ui[settings.text] :

| Réglage | Ce qu’il fait |
|---|---|
| :ui[text.enableSyntaxColoring] | Colore le code selon son langage. Activé par défaut. |
| :ui[text.syntaxColoringInDiffs] | Utilise aussi la coloration syntaxique dans les diffs. Désactivé par défaut. |
| :ui[text.showInvisibles] | Affiche les espaces, les tabulations et les fins de ligne sous forme de symboles |
| :ui[text.tabWidth] | La largeur d’une tabulation, en espaces |

[Texte](/guide/settings/appearance/#text) en dit plus sur ces réglages. Les couleurs viennent du thème. Consultez [Thèmes](/guide/settings/appearance/#themes).

## Indexer des fichiers entiers {#stage-file}

Indexer, c’est choisir les modifications qui entrent dans le prochain commit. Pour indexer des fichiers entiers, procédez de l’une des façons suivantes :

- Cochez la case devant le fichier. Si le fichier est sélectionné, tous les fichiers sélectionnés sont indexés.
- Sélectionnez des fichiers et appuyez sur <kbd>Espace</kbd>. Si un fichier sélectionné a des modifications non indexées, la barre d’espace l’indexe. Sinon, elle le désindexe.
- Cliquez sur :ui[working.stageAll] au-dessus de la liste, ou choisissez :ui[workspace.title > working.stageAllMenu] (<kbd>⇧⌘E</kbd>).

Pour désindexer, décochez la case, appuyez à nouveau sur <kbd>Espace</kbd>, ou choisissez :ui[workspace.title > working.unstageAllMenu] (<kbd>⌥⇧⌘E</kbd>). Quand tout est indexé, le bouton :ui[working.stageAll] devient :ui[working.unstageAll]. Tant que seule une partie des modifications est indexée, maintenez <kbd>⌥</kbd> enfoncée pour le faire changer.

## Indexer des sections {#chunks}

Chaque section a des boutons à l’extrémité droite de sa ligne d’en-tête :

- Du côté :ui[working.unstaged] : :ui[working.discardChunk] et :ui[working.stageChunk]
- Du côté :ui[working.staged] : :ui[working.unstageChunk]

La section passe aussitôt de l’autre côté. Le reste du fichier ne bouge pas.

## Indexer des lignes {#lines}

Quand une section mêle des modifications destinées à des commits différents, n’indexez que certaines de ses lignes.

1. Cliquez sur le numéro d’une ligne modifiée pour la sélectionner. Cliquez à nouveau pour la désélectionner.
2. Pour sélectionner d’autres lignes, cliquez aussi sur leur numéro. Faites glisser sur les numéros pour sélectionner une suite de lignes, ou maintenez <kbd>⇧</kbd> enfoncée et cliquez pour sélectionner toutes les lignes intermédiaires.
3. Cliquez sur :ui[working.stageLines] dans l’en-tête de la section.

::screenshot[Une section dans le diff de src/readings.ts. Cinq lignes sont sélectionnées par leur numéro, et l’en-tête de la section affiche les boutons Abandonner les lignes et Indexer les lignes.]{name="staging" frame="closeup"}

Seules les lignes modifiées peuvent être sélectionnées. Chaque section a sa propre sélection, et ses boutons agissent sur les lignes qui y sont sélectionnées. Du côté :ui[working.staged], le bouton est :ui[working.unstageLines].

## Abandonner des modifications {#discard}

Abandonner, c’est jeter les modifications que vous ne voulez pas garder.

- **Un fichier** : cliquez dessus avec le bouton droit et choisissez :ui[working.discard.menu] dans le menu, ou choisissez :ui[workspace.title > working.discardMenu] (<kbd>⇧⌘⌫</kbd>).
- **Tout** : choisissez :ui[workspace.title > working.discardAllMenu] dans la barre des menus.
- **Une section ou quelques lignes** : cliquez sur :ui[working.discardChunk] ou :ui[working.discardLines] dans l’en-tête de la section.

Pour les fichiers, Spooky demande d’abord confirmation. Les fichiers suivis reviennent à leur état du dernier commit, modifications indexées comprises. Les nouveaux fichiers vont dans la Corbeille. Cliquez sur :ui[working.discard] ou :ui[working.discardAll.submit] pour continuer.

Pour les sections et les lignes, Spooky demande :ui[working.discardContent.title] Cochez :ui[dialog.doNotAskAgain] pour éviter la question la prochaine fois. Pour la retrouver, activez :ui[settings.warnDiscardingChunks] dans :ui[app.name > settings.title] › :ui[settings.general]. Consultez [Confirmations](/guide/settings/general/#confirmations).

:::caution
Les modifications abandonnées ne sont dans aucun commit. Le seul moyen de les récupérer est :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>), et seulement tant que le dépôt n’a pas changé à nouveau. Les nouveaux fichiers se récupèrent dans la Corbeille tant qu’ils y sont encore.
:::

:::note[Dépôts sur un serveur]
L’abandon écrase les fichiers sur le serveur. Les nouveaux fichiers vont dans la Corbeille du serveur. Si le serveur n’a pas de Corbeille, ils sont supprimés définitivement. La question propose :ui[dialog.doNotAskAgain]. Pour la retrouver, activez :ui[settings.warnDiscardingOnServer] dans :ui[settings.general].
:::

## Comparer dans une autre app {#external}

Pour examiner une modification dans une app de comparaison, comme FileMerge ou Kaleidoscope :

- Placez le pointeur sur le nom du fichier en haut de la colonne de droite, et cliquez sur :ui[externalTool.action.diffTool]. Il compare le côté que vous regardez.
- Ou cliquez sur le fichier avec le bouton droit et choisissez dans le sous-menu :ui[externalTool.compare] : :ui[externalTool.compare.workingTreeToBase], :ui[externalTool.compare.workingTreeToIndex] ou :ui[externalTool.compare.indexToBase].

La première fois, Spooky demande quelle app utiliser. Pour en changer plus tard, utilisez :ui[externalTool.diffTool] dans :ui[app.name > settings.title] › :ui[settings.gitConfig]. Spooky fonctionne avec Araxis Merge, BBEdit, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge, TextMate et Visual Studio Code. Consultez [Outils de comparaison et de fusion](/guide/settings/integration/#diff-merge-tools).

:::note[Dépôts sur un serveur]
L’app de comparaison reçoit des copies des fichiers dans un dossier temporaire sur votre Mac. Le dossier est supprimé quand vous fermez le dépôt.
:::

## Voir aussi

- [Copie de travail](/guide/work/working-copy/)
- [Valider des modifications](/guide/work/commit/)
- [Annulation et récupération](/guide/work/undo/)
