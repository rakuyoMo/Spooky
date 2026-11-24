---
title: "Raccourcis clavier"
description: "Retrouvez tous les raccourcis clavier de Spooky."
---

Les éléments de menu affichent leur raccourci à côté d’eux. Cette page les rassemble tous, ainsi que les touches qui fonctionnent à des endroits précis, comme la zone de commit, les listes et les zones de dialogue. Les symboles sont expliqués dans [Raccourcis clavier](/guide/#shortcuts).

Un raccourci ne fonctionne que si son élément de menu est disponible. Quand un élément est estompé, son raccourci ne fait rien.

## Menus {#menus}

### App et fenêtres {#app-windows}

| Raccourci | Élément de menu |
|---|---|
| <kbd>⌘,</kbd> | :ui[app.name > settings.title] |
| <kbd>⌘H</kbd> | :ui[app.name > menu.hide] |
| <kbd>⌥⌘H</kbd> | :ui[app.name > menu.hideOthers] |
| <kbd>⌘Q</kbd> | :ui[app.name > menu.quit] |
| <kbd>⌘N</kbd> | :ui[menu.file > menu.newWindow] |
| <kbd>⌘T</kbd> | :ui[menu.file > menu.newTab] |
| <kbd>⌘W</kbd> | :ui[menu.file > menu.closeWindow] |
| <kbd>⌃⌘F</kbd> | :ui[menu.view > menu.fullscreen] |
| <kbd>⌘M</kbd> | :ui[menu.window > menu.minimize] |
| <kbd>⌃⌘0</kbd> | :ui[menu.window > activity.title] |
| <kbd>⌘?</kbd> | :ui[menu.help > help.help] |

### Dépôts {#repositories}

| Raccourci | Élément de menu |
|---|---|
| <kbd>⌘O</kbd> | :ui[menu.file > action.openLocal] |
| <kbd>⌃⌘C</kbd> | :ui[menu.file > clone.menu] |
| <kbd>⇧⌘A</kbd> | :ui[menu.file > quickActions.menu] |
| <kbd>⌃⌘R</kbd> | :ui[menu.view > menu.showRepositories] |

### Vues {#views}

| Raccourci | Élément de menu |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.view > menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.view > menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[menu.view > stash.show] |
| <kbd>⌘4</kbd> | :ui[menu.view > pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[menu.view > review.show] |
| <kbd>⌘6</kbd> | :ui[menu.view > reflog.show] |
| <kbd>⌘0</kbd> | :ui[menu.view > history.showHead] |
| <kbd>⌘[</kbd> | :ui[menu.view > navigation.back] |
| <kbd>⌘]</kbd> | :ui[menu.view > navigation.forward] |
| <kbd>⌘R</kbd> | :ui[menu.view > action.refresh] |
| <kbd>⌃⌘T</kbd> | :ui[menu.view > files.statusMenu > working.tree] |
| <kbd>⌃⌘L</kbd> | :ui[menu.view > files.statusMenu > working.list] |
| <kbd>⌃⌘M</kbd> | :ui[menu.view > files.statusMenu > files.showNonModified] |
| <kbd>⌃⌘I</kbd> | :ui[menu.view > files.statusMenu > files.showIgnored] |
| <kbd>⌃⌘G</kbd> | :ui[menu.view > history.title > history.showGraph] |
| <kbd>⌃⌥⌘C</kbd> | :ui[menu.view > history.title > history.compareBranches] |
| <kbd>⌃⌘→</kbd> | :ui[menu.view > history.diffs > history.expandAll] |
| <kbd>⌃⌘←</kbd> | :ui[menu.view > history.diffs > history.collapseAll] |

### Édition et recherche {#edit}

| Raccourci | Élément de menu |
|---|---|
| <kbd>⌘Z</kbd> | :ui[menu.edit > menu.undo] |
| <kbd>⇧⌘Z</kbd> | :ui[menu.edit > menu.redo] |
| <kbd>⌘X</kbd> | :ui[menu.edit > menu.cut] |
| <kbd>⌘C</kbd> | :ui[menu.edit > menu.copy] |
| <kbd>⌘V</kbd> | :ui[menu.edit > menu.paste] |
| <kbd>⌥⇧⌘V</kbd> | :ui[menu.edit > menu.pasteAndMatchStyle] |
| <kbd>⌘⌫</kbd> | :ui[menu.edit > menu.delete] |
| <kbd>⌘A</kbd> | :ui[menu.edit > menu.selectAll] |
| <kbd>⇧⌘W</kbd> | :ui[menu.edit > commit.reformatParagraph] |
| <kbd>⌘F</kbd> | :ui[menu.edit > menu.find > action.find] |
| <kbd>⌥⌘F</kbd> | :ui[menu.edit > menu.find > action.search] |
| <kbd>⌘G</kbd> | :ui[menu.edit > menu.find > menu.findNext] |
| <kbd>⇧⌘G</kbd> | :ui[menu.edit > menu.find > menu.findPrevious] |
| <kbd>⌘E</kbd> | :ui[menu.edit > menu.find > menu.useSelectionForFind] |
| <kbd>⌘J</kbd> | :ui[menu.edit > menu.find > menu.jumpToSelection] |
| <kbd>⌘:</kbd> | :ui[menu.edit > menu.spelling > menu.showSpelling] |
| <kbd>⌘;</kbd> | :ui[menu.edit > menu.spelling > menu.checkDocument] |

- Consultez [Annuler et rétablir](/guide/work/undo/#undo) pour savoir ce que :ui[menu.undo] peut annuler.
- :ui[menu.delete] supprime aussi ce qui est sélectionné dans certaines listes. Consultez [Listes](#lists).
- :ui[action.find] et :ui[action.search] placent tous deux le curseur dans le champ de recherche de la barre d’outils. Consultez [Rechercher et filtrer](/guide/history/browse/#search) et [Rechercher un fichier](/guide/work/working-copy/#search).
- :ui[commit.reformatParagraph] fonctionne dans le message de commit. Consultez [Rédiger le message](/guide/work/commit/#write).

### Branches et synchronisation {#sync}

| Raccourci | Élément de menu |
|---|---|
| <kbd>⌘B</kbd> | :ui[menu.repository > branch.createMenu] |
| <kbd>⇧⌘T</kbd> | :ui[menu.repository > tag.createMenu] |
| <kbd>⌃⌘P</kbd> | :ui[menu.repository > pr.create.menu] |
| <kbd>⇧⌘F</kbd> | :ui[menu.repository > sync.fetchMenu] |
| <kbd>⌥⇧⌘F</kbd> | :ui[menu.repository > sync.quickFetch] |
| <kbd>⇧⌘P</kbd> | :ui[menu.repository > sync.pullMenu] |
| <kbd>⌥⇧⌘P</kbd> | :ui[menu.repository > sync.quickPull] |
| <kbd>⇧⌘Y</kbd> | :ui[menu.repository > sync.syncMenu] |
| <kbd>⌥⇧⌘Y</kbd> | :ui[menu.repository > sync.quickSync] |
| <kbd>⇧⌘U</kbd> | :ui[menu.repository > sync.pushMenu] |
| <kbd>⌥⇧⌘U</kbd> | :ui[menu.repository > sync.quickPushMenu] |
| <kbd>⌃⌘U</kbd> | :ui[menu.repository > sync.forcePushMenu] |
| <kbd>⇧⌘B</kbd> | :ui[workspace.title > rewrite.checkout.menu] |
| <kbd>⇧⌘M</kbd> | :ui[workspace.title > sync.mergeMenu] |
| <kbd>⌥⇧⌘M</kbd> | :ui[workspace.title > sync.quickMerge] |
| <kbd>⇧⌘R</kbd> | :ui[workspace.title > sync.rebaseMenu] |
| <kbd>⌥⇧⌘R</kbd> | :ui[workspace.title > sync.quickRebase] |
| <kbd>⌃⇧⌘R</kbd> | :ui[workspace.title > rewrite.rebaseOnto.menu] |

Les éléments avec <kbd>⌥⇧⌘</kbd> sont des versions rapides. Ils remplacent l’élément situé au-dessus d’eux tant que vous maintenez <kbd>⌥</kbd> avec le menu ouvert. Ils s’exécutent tout de suite, sans zone de dialogue. Leurs raccourcis fonctionnent sans ouvrir le menu. Consultez les versions rapides dans [Récupérer, tirer et pousser](/guide/branches/sync/#quick) et [Fusionner et rebaser](/guide/branches/merge-rebase/#quick).

### Modifications et commits {#changes}

| Raccourci | Élément de menu |
|---|---|
| <kbd>⇧⌘C</kbd> | :ui[workspace.title > working.commitMenu] |
| <kbd>⇧⌘E</kbd> | :ui[workspace.title > working.stageAllMenu] |
| <kbd>⌥⇧⌘E</kbd> | :ui[workspace.title > working.unstageAllMenu] |
| <kbd>⇧⌘⌫</kbd> | :ui[workspace.title > working.discardMenu] |
| <kbd>⇧⌘S</kbd> | :ui[workspace.title > stash.saveMenu] |
| <kbd>⌥⇧⌘S</kbd> | :ui[workspace.title > stash.applyMenu] |
| <kbd>⌃⇧⌘S</kbd> | :ui[workspace.title > stash.snapshotMenu] |
| <kbd>⌃⇧⌘D</kbd> | :ui[workspace.title > externalTool.compare > externalTool.compare.workingTreeToBase] |
| <kbd>⇧⌘D</kbd> | :ui[menu.repository > externalTool.openDiffTool] |

## Maintenir Option {#option}

Maintenir <kbd>⌥</kbd> change certains boutons et menus. Relâchez la touche, et ils reprennent leur forme.

| Où | Ce qui change |
|---|---|
| Les boutons de récupération, de tirage, de poussée, de synchronisation, de fusion et de rebasage de la barre d’outils | Ils deviennent des versions rapides. Consultez [Récupérer, tirer et pousser](/guide/branches/sync/#quick). |
| La zone de commit, quand aucun des champs du message n’est en cours de modification | Elle passe à la correction du dernier commit. Consultez [Corriger le dernier commit](/guide/work/commit/#amend). |
| :ui[working.stageAll] au-dessus de la liste de fichiers, quand seule une partie des modifications est indexée | Il devient :ui[working.unstageAll]. Consultez [Indexer des fichiers entiers](/guide/work/diff/#stage-file). |
| Le menu des fichiers dans la copie de travail | Les éléments de remisage deviennent des versions rapides. Consultez [Remiser certains fichiers](/guide/work/stash/#partial). |
| Le menu d’un sous-module | La récupération et la mise à jour deviennent des versions rapides. Consultez [Récupérer et mettre à jour](/guide/advanced/submodules/#update). |
| Le menu d’une branche qui a une branche parente | La mise à jour depuis la branche parente devient une version rapide. Consultez [Mettre à jour une branche depuis sa branche parente](/guide/branches/merge-rebase/#update). |
| Le menu d’un commit | L’enregistrement d’un patch devient une version rapide. Avec deux commits sélectionnés, leur comparaison se fait dans l’autre sens. Consultez [Enregistrer un patch](/guide/history/commit-details/#patch). |
| :ui[compare.submit] avec deux commits sélectionnés | La comparaison se fait dans l’autre sens. Consultez [Plusieurs commits](/guide/history/commit-details/#multiple). |
| Le glissement | Consultez [Glisser avec Option](#drag). |

## Zone de commit {#commit-area}

| Touches | Ce qu’elles font |
|---|---|
| <kbd>↩</kbd> ou <kbd>Tab</kbd> dans l’objet | Passe à la description |
| <kbd>Tab</kbd> dans la description | Passe à la liste de fichiers |
| <kbd>⇧Tab</kbd> dans la description | Revient à l’objet |
| <kbd>⌘↩</kbd> pendant la saisie du message | Clique sur le bouton principal de la zone de commit, comme :ui[working.commit]. <kbd>Entrée</kbd> sur un pavé numérique fait de même. |
| <kbd>⌥⌘↩</kbd> quand aucun des champs du message n’est en cours de modification | Corrige le dernier commit. Consultez [Corriger le dernier commit](/guide/work/commit/#amend). |
| <kbd>↑</kbd> <kbd>↓</kbd>, <kbd>↩</kbd>, <kbd>Esc</kbd> dans la liste de saisie semi-automatique | Choisissent une correspondance, l’insèrent et ferment la liste |

Consultez [Valider des modifications](/guide/work/commit/).

## Liste de fichiers {#file-list}

Ces touches fonctionnent dans la liste de fichiers de la copie de travail :

| Touches | Ce qu’elles font |
|---|---|
| <kbd>Espace</kbd> | Indexe ou désindexe les fichiers sélectionnés. Avec :ui[files.spacebar] réglé sur :ui[files.spacebar.quickLook], la touche les affiche dans Coup d’œil à la place. Consultez [Liste de fichiers](/guide/settings/general/#file-list). |
| <kbd>⌘⌫</kbd> | Place les fichiers sélectionnés dans la Corbeille |
| <kbd>⇧Tab</kbd> | Revient à la description du message de commit |

## Lignes d’un diff {#diff-lines}

Dans la copie de travail, appuyez sur <kbd>Tab</kbd> jusqu’à ce que les numéros de ligne d’une section aient le focus clavier. Ensuite :

| Touches | Ce qu’elles font |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Passent d’une ligne sélectionnable à l’autre |
| <kbd>Espace</kbd> | Sélectionne ou désélectionne la ligne |
| <kbd>Tab</kbd> ou <kbd>⇧Tab</kbd> | Quitte les numéros de ligne |

Avec la souris, maintenez <kbd>⇧</kbd> et cliquez sur un numéro de ligne pour sélectionner toutes les lignes intermédiaires. Consultez [Indexer des lignes](/guide/work/diff/#lines).

## Listes {#lists}

| Où | Touches | Ce qu’elles font |
|---|---|---|
| La liste des commits dans l’historique | <kbd>⌘C</kbd> | Copie les hashs complets des commits sélectionnés |
| Les modifications d’un commit | <kbd>↑</kbd> <kbd>↓</kbd> | Déplacent la sélection |
| Les fichiers modifiés dans les détails en pleine page | <kbd>↩</kbd> | Ouvre les fichiers sélectionnés dans leur app par défaut |
| L’arborescence de fichiers d’un commit | <kbd>↩</kbd> | Ouvre ou ferme le dossier sélectionné |
| L’historique du fichier | <kbd>↩</kbd> | Ouvre le commit sélectionné dans les détails en pleine page |
| La barre latérale | <kbd>⌘⌫</kbd> | Supprime les branches, les tags, le dépôt distant ou le sous-module sélectionnés, après confirmation |
| Le champ de filtre de la barre latérale | <kbd>Esc</kbd> | Vide le champ |
| Les remisages | <kbd>⌘⌫</kbd> | Supprime les remisages sélectionnés, après confirmation |
| La revue des branches | <kbd>⌘⌫</kbd> | Supprime les branches sélectionnées, après confirmation |
| La fenêtre Dépôts | <kbd>↩</kbd> | Renomme l’entrée sélectionnée |
| La fenêtre Dépôts | <kbd>⌫</kbd> ou <kbd>⌦</kbd> | Retire les entrées sélectionnées. Consultez [Retirer des dépôts](/guide/repositories/manager/#delete). |
| La fenêtre affichée au lancement | <kbd>↩</kbd> | Ouvre le dépôt sélectionné. Consultez [Reprendre là où vous vous étiez arrêté](/guide/repositories/navigation/#restore). |
| La conversation d’une pull request | <kbd>↩</kbd> | Ouvre le commit sélectionné |
| La conversation d’une pull request | <kbd>⌘S</kbd> | Clique sur :ui[pullRequests.addComment] |
| :ui[settings.themes] dans Réglages | <kbd>↩</kbd> | Renomme le thème sélectionné |
| :ui[settings.appIcon.label] dans Réglages | Touches fléchées, <kbd>Espace</kbd> | Passent d’une icône à l’autre, et utilisent celle où vous êtes |
| :ui[settings.sshHosts] dans Réglages | <kbd>↩</kbd> | Ouvre l’alias sélectionné pour le modifier |

Dans les listes où vous pouvez sélectionner plusieurs éléments, un clic avec <kbd>⇧</kbd> sélectionne une plage. Un clic avec <kbd>⌘</kbd> ajoute ou retire un seul élément. Dans la barre latérale, cliquez avec <kbd>⌘</kbd> sur des branches et des tags pour voir leur historique ensemble. Consultez [Ouvrir l’historique](/guide/history/browse/#open).

Maintenez <kbd>⌘</kbd> et double-cliquez sur une branche extraite dans un autre worktree. Ce worktree s’ouvre dans un nouvel onglet. Consultez [Extraire une branche](/guide/branches/branches/#checkout).

## Actions rapides {#quick-actions}

Ces touches fonctionnent dans le panneau [Actions rapides](/guide/repositories/navigation/#quick-actions) :

| Touches | Ce qu’elles font |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Déplacent la sélection |
| <kbd>↩</kbd> | Exécute l’action par défaut de l’élément sélectionné |
| <kbd>Tab</kbd>, ou <kbd>→</kbd> à la fin du texte | Liste toutes les actions de l’élément sélectionné |
| <kbd>←</kbd> sans texte, ou <kbd>⇧Tab</kbd> | Revient en arrière depuis la liste des actions |
| <kbd>Esc</kbd> | Efface le texte. Sans texte, revient en arrière depuis la liste des actions ou ferme le panneau. |

## Zones de dialogue {#dialogs}

Dans une zone de dialogue, <kbd>↩</kbd> clique sur le bouton mis en évidence. <kbd>Esc</kbd> clique sur le bouton d’annulation. Si la zone de dialogue n’a pas de tel bouton, <kbd>Esc</kbd> clique aussi sur le bouton mis en évidence.

## Glisser avec Option {#drag}

Maintenez <kbd>⌥</kbd> au moment de déposer pour faire autre chose :

| Faites glisser | Sur | Sans <kbd>⌥</kbd> | Avec <kbd>⌥</kbd> |
|---|---|---|---|
| Une branche locale | :ui[workspace.title] ou la branche actuelle | La zone de dialogue de fusion | La zone de dialogue de rebasage |
| Une branche distante | La branche actuelle | La zone de dialogue de tirage | Elle devient la branche amont de votre branche. |
| Des commits de l’historique | :ui[workspace.title] ou la branche actuelle | Un cherry-pick de ces commits | Leur annulation par revert |
| Des commits dans l’historique | Un autre commit de la liste | Ils sont fusionnés dans celui-ci | Un fixup à la place |

Consultez [Glisser-déposer](/guide/branches/merge-rebase/#drag-and-drop) et [Fusionner, intégrer, supprimer et déplacer des commits](/guide/history/rewrite/#interactive).

## Voir aussi

- [Fenêtres et navigation](/guide/repositories/navigation/)
- [Valider des modifications](/guide/work/commit/)
- [Examiner et indexer les modifications](/guide/work/diff/)
- [Fusionner et rebaser](/guide/branches/merge-rebase/)
