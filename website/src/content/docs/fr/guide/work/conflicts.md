---
title: "Résoudre les conflits"
description: "Résolvez les conflits d’une fusion, d’un rebasage ou d’une autre opération en cours avec l’assistant de conflits ou un outil de fusion externe, puis continuez ou abandonnez."
---

Un conflit se produit quand les deux côtés ont modifié la même partie d’un fichier et que Git ne peut pas dire quelle modification garder. Une fusion, un rebasage, un cherry-pick ou un revert s’arrête à ce moment-là, tout comme l’application d’un remisage. Vous décidez de ce qui va dans chaque fichier, puis vous terminez l’opération.

::screenshot[La copie de travail pendant une fusion de « feature/units-toggle » dans « main ». Une bannière jaune en haut de la colonne du milieu indique 1 conflit non résolu, 0 résolu, et comporte un bouton Abandonner. Dans la liste de fichiers, src/units.ts est marqué comme étant en conflit. À droite, deux cartes affichent la version de units.ts de chaque branche, avec des flèches pointant vers une zone de résultat vide et un bouton Choisir l’outil de fusion.]{name="conflict" frame="window" markers="24,18 47,61.6 76,37 76,73 84,86"}

1. La bannière indique ce qui est en cours et combien de conflits il reste.
2. Un fichier en conflit. Sélectionnez-le pour ouvrir l’assistant de conflits.
3. Les deux versions du fichier, une de chaque côté.
4. Le résultat : ce à quoi le fichier ressemblera.
5. Le bouton qui résout le fichier, ou qui ouvre un outil de fusion.

## Opérations en cours {#banner}

Pendant une fusion, un rebasage, un cherry-pick ou un revert, une bannière occupe le haut de la copie de travail :

- Le titre dit ce qui se passe, par exemple :ui[conflict.title.merge]{1="feature/units-toggle" 2="main"}.
- En dessous figure le nombre de conflits non résolus. Une fois l’opération arrêtée sur un conflit, le nombre de fichiers résolus suit entre parenthèses.
- Une courte indication dit quoi faire ensuite. Pendant un rebasage ou une série de commits, une barre de progression montre à quelle étape vous êtes.
- :ui[working.onlyConflicts] réduit la liste de fichiers aux fichiers de ce conflit. Les fichiers que vous avez résolus restent dans la liste. Spooky retient ce choix pour tous les dépôts.
- :ui[working.abort] annule l’opération. Consultez [Continuer ou abandonner](#continue).

La zone de commit reste masquée tant que tous les conflits ne sont pas résolus.

## Utiliser l’assistant de conflits {#wizard}

Sélectionnez un fichier en conflit dans la copie de travail. L’assistant de conflits s’ouvre à droite, avec une carte pour chaque côté, comme :ui[conflict.version]{1="main"}. Chaque carte affiche le fichier, ce que ce côté en a fait (par exemple :ui[conflict.change.modified]) et le commit d’où il vient.

Pour garder un seul côté :

1. Cliquez sur sa carte. La zone de résultat affiche cette version.
2. Cliquez sur :ui[conflict.resolveUsing]{1="main"}.

Spooky écrit cette version dans le fichier et l’indexe. Le fichier compte comme résolu. Si ce côté a supprimé le fichier, le fichier est supprimé.

Pour combiner les deux côtés, cliquez sur les deux cartes, puis sur le bouton sous la zone de résultat. Il ouvre un outil de fusion, comme décrit dans [Fusionner dans une autre app](#merge-tool).

Si vous avez déjà modifié le fichier vous-même, par exemple dans un éditeur de texte, la zone de résultat affiche :ui[conflict.result]. Cliquez sur :ui[conflict.resolveCurrent] pour indexer le fichier tel quel. L’assistant relit le fichier quand vous revenez dans Spooky.

Le bouton « … » d’une carte ouvre un menu pour cette version :

- :ui[conflict.open]{1="main"}, ou l’ouvrir avec une autre app
- :ui[conflict.export]{1="main"}
- :ui[conflict.compareOther]{1="feature/units-toggle"}
- :ui[conflict.compareBase]

## Fusionner dans une autre app {#merge-tool}

Un outil de fusion affiche les deux versions côte à côte et vous laisse choisir les modifications ligne par ligne. Il traite un fichier à la fois, quand les deux côtés ont le fichier.

1. Dans l’assistant de conflits, cliquez sur :ui[externalTool.chooseMergeTool] et choisissez une app. Après la première fois, le bouton indique :ui[externalTool.mergeIn]{1="FileMerge"}.
2. Fusionnez le fichier dans cette app, enregistrez le résultat et quittez-la.

Spooky écrit le résultat dans le fichier et le marque comme résolu. Si l’app n’a enregistré aucun résultat, Spooky indique :ui[externalTool.noResult], et le conflit demeure.

FileMerge fonctionne un peu différemment. Spooky affiche :ui[externalTool.finishMerge]{1="FileMerge"} tant qu’il est ouvert. Enregistrez le résultat dans FileMerge, puis cliquez sur :ui[externalTool.done].

Spooky prend en charge Araxis Merge, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge et Visual Studio Code. Pour changer d’app, modifiez :ui[externalTool.mergeTool] dans :ui[app.name > settings.title] › :ui[settings.gitConfig]. Activez-y :ui[externalTool.keepBackups] pour conserver le fichier tel qu’il était avant la fusion, par exemple sous le nom `src/units.ts.orig`. Consultez [Outils de comparaison et de fusion](/guide/settings/integration/#diff-merge-tools).

Si le fichier a été modifié ailleurs pendant que vous fusionniez, Spooky demande confirmation avant de l’écraser.

:::note[Dépôts sur un serveur]
L’outil de fusion reçoit des copies des versions dans un dossier temporaire sur ce Mac. Spooky réécrit le résultat sur le serveur, puis marque le fichier comme résolu. Le dossier est supprimé quand vous fermez le dépôt.
:::

## Autres façons de résoudre {#other-ways}

Cliquez avec le bouton droit sur un ou plusieurs fichiers en conflit :

- :ui[conflict.menu.resolve]
  - :ui[conflict.markResolved.one]{1="src/units.ts"} indexe le fichier dans son état actuel. Cocher sa case fait la même chose.
  - :ui[conflict.resolveUsingVersion]{1="main"} garde un seul côté, comme l’assistant.
- :ui[conflict.menu.restore]
  - :ui[conflict.restoreUnmerged.one]{1="src/units.ts"} fait revenir le conflit, même pour un fichier déjà résolu.
  - :ui[conflict.restoreVersion]{1="main"} et :ui[conflict.restoreAncestor] placent une version dans le fichier. Le fichier reste non résolu.

:::caution
La restauration écrase le fichier dans la copie de travail sans demander confirmation. Les modifications que vous y avez faites sont perdues.
:::

Quand l’application d’un remisage ou d’un patch s’arrête sur des conflits, il n’y a ni opération à continuer ou à abandonner, ni bannière. L’assistant appelle le côté entrant :ui[conflict.version.applied]. Une fois les fichiers résolus, les modifications sont dans la copie de travail comme toutes les autres.

## Continuer ou abandonner {#continue}

Quand tous les conflits sont résolus, la zone de commit revient, avec le message que Git a préparé pour l’opération.

- **Fusion, ou cherry-pick ou revert d’un seul commit** : vérifiez le message, puis cliquez sur :ui[working.commit].
- **Rebasage, ou cherry-pick ou revert de plusieurs commits** : vérifiez le message, puis cliquez sur :ui[working.continue]. Spooky valide cette étape et passe à la suivante, qui peut à nouveau s’arrêter sur un conflit.
- **Une étape de rebasage qui s’arrête pour modifier un commit** : créez vos commits, puis cliquez sur :ui[working.endEditing] dans la bannière.

Il arrive qu’il ne reste rien à valider, par exemple quand vous avez gardé la version qui était déjà là. Quand vous cliquez alors sur :ui[working.commit] ou :ui[working.continue], Spooky demande :ui[commit.empty.title] Cliquez sur :ui[commit.empty.use] pour créer un commit vide. L’autre bouton abandonne la fusion, ou ignore l’étape dans un rebasage ou une série. Dans un rebasage ou une série, vous pouvez aussi cliquer sur :ui[working.skip] dans la bannière.

Pour renoncer, cliquez sur :ui[working.abort] dans la bannière. Le dépôt revient à l’état où il était avant le début de l’opération.

:::caution
L’abandon s’exécute aussitôt, sans confirmation, et ne peut pas être annulé. Les conflits que vous avez résolus sont perdus.
:::

## Voir aussi

- [Examiner et indexer les modifications](/guide/work/diff/)
- [Remisages](/guide/work/stash/)
- [Annulation et récupération](/guide/work/undo/)
