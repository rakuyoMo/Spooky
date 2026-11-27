---
title: "Découvrir Spooky"
description: "Faites connaissance avec la fenêtre Dépôts et la fenêtre de dépôt : la barre latérale, la barre d’outils, les trois colonnes et les Actions rapides."
---

Les fenêtres de Spooky affichent l’une de ces deux choses. La vue Dépôts liste vos dépôts. Une fenêtre de dépôt est l’endroit où vous faites le travail proprement dit. Cette page nomme les parties de l’une et de l’autre. Le reste du guide utilise ces noms.

## La fenêtre Dépôts {#repositories-window}

Quand vous ouvrez Spooky pour la première fois, il affiche la vue Dépôts. La barre latérale liste vos dépôts sous :ui[repositories.title]. Vous pouvez les ranger dans des groupes.

- Sélectionnez un dépôt pour voir ses détails à droite : son emplacement, sa dernière ouverture, son dernier commit, sa branche actuelle, ses modifications et ses dépôts distants.
- Sélectionnez un groupe, ou rien du tout, pour voir une zone qui indique :ui[bookmarks.dropZone.title], avec les boutons :ui[bookmarks.dropZone.add], :ui[action.addRemote], :ui[bookmarks.dropZone.create] et :ui[bookmarks.dropZone.clone].
- Le bouton d’ajout en bas de la barre latérale ajoute des groupes et des dépôts.

Double-cliquez sur un dépôt pour l’ouvrir. Il s’ouvre dans la même fenêtre, à la place de la vue Dépôts. Pour retrouver la liste, cliquez sur :ui[toolbar.bookmarks] en haut de la barre latérale. [La fenêtre Dépôts](/guide/repositories/manager/) décrit la liste en détail.

## La fenêtre de dépôt {#repository-window}

Une fois un dépôt ouvert, le titre de la fenêtre affiche son nom. Sous le nom figure la vue actuelle avec un bref résumé, comme la branche et le nombre de fichiers modifiés.

::screenshot[Une fenêtre de dépôt. La barre latérale, à gauche, liste les vues, les branches, les tags et les dépôts distants du dépôt. La barre d’outils occupe le haut. La colonne du milieu affiche la zone de commit au-dessus d’une liste de fichiers modifiés, et la colonne de droite affiche les modifications du fichier sélectionné.]{name="tour-window" frame="window" markers="16.5,47 50,3.25 36,72 85,31"}

1. La barre latérale
2. La barre d’outils
3. La colonne du milieu : la liste de la vue actuelle
4. La colonne de droite : les détails de ce qui est sélectionné dans la colonne du milieu

:::note[Dépôts sur un serveur]
Le titre de la fenêtre commence par l’alias d’hôte, sous la forme `alias:name`. La barre d’outils affiche aussi l’alias d’hôte dans un élément :ui[toolbar.host]. [État de la connexion et reconnexion](/guide/server/connection/) explique ce que la fenêtre affiche quand la connexion est coupée.
:::

### Barre latérale {#sidebar}

La section :ui[workspace.group], en haut, permet de passer d’une vue du dépôt à l’autre :

| Vue | Ce qu’elle affiche |
|---|---|
| :ui[workspace.title] | Vos modifications non validées. Le nombre affiché à côté compte les fichiers modifiés. |
| :ui[history.title] | Les commits |
| :ui[stash.title] | Les modifications que vous avez mises de côté |
| :ui[pr.title] | Les pull requests ou merge requests du service d’hébergement |
| :ui[review.title] | Vos branches, pour repérer celles que vous pouvez nettoyer |
| :ui[reflog.title] | Les positions successives de HEAD. Affiché une fois :ui[sidebar.showReflog] activé dans :ui[sidebar.viewSettings]. |
| :ui[repositorySettings.title] | Les réglages de ce dépôt. Consultez [Réglages du dépôt](/guide/settings/identity/#repository). |

Viennent ensuite :ui[sidebar.pinned] (dès que vous épinglez une branche), :ui[branch.group], :ui[sidebar.archived], :ui[sidebar.tags], :ui[remote.group], :ui[submodule.group] et :ui[worktree.group]. Dans :ui[branch.group], une pastille HEAD marque la branche sur laquelle vous êtes. Une flèche avec un nombre, comme ↑3, compte les commits que vous n’avez pas encore poussés.

La barre en bas de la barre latérale contient un champ :ui[sidebar.filter], un bouton :ui[reference.addMenu] pour créer des branches et d’autres références, et :ui[sidebar.viewSettings] pour choisir ce que la barre latérale affiche.

### Barre d’outils {#toolbar}

De gauche à droite, la barre d’outils contient ces boutons :

- :ui[toolbar.bookmarks] : revenir à la vue Dépôts
- :ui[toolbar.previous] et :ui[toolbar.next] : reculer et avancer parmi les vues visitées
- :ui[toolbar.finder] et :ui[toolbar.terminal] : afficher le dossier du dépôt dans le Finder, ou l’ouvrir dans un terminal
- :ui[sync.fetch], :ui[sync.pull] et :ui[sync.push] : échanger des commits avec les dépôts distants
- :ui[toolbar.forcePush] : remplacer une branche distante par la vôtre après avoir réécrit des commits
- :ui[toolbar.applyStash] et :ui[toolbar.saveStash] : reprendre des modifications mises de côté, ou mettre de côté vos modifications actuelles
- :ui[toolbar.createBranch] : créer une branche
- :ui[action.refresh] : relire le dépôt
- :ui[action.search] : filtrer la liste de la vue actuelle

Maintenez <kbd>⌥</kbd> enfoncée et :ui[sync.fetch], :ui[sync.pull] et :ui[sync.push] passent en version rapide, comme :ui[sync.quickPush]. Une version rapide agit tout de suite sur la branche amont, sans ouvrir de zone de dialogue.

:ui[toolbar.clone] apparaît tant que vous avez des clones récents. Consultez [La fenêtre Dépôts](/guide/repositories/manager/). Choisissez :ui[menu.view > menu.customizeToolbar] pour ajouter ou retirer des boutons. En plus des boutons ci-dessus, vous pouvez ajouter :ui[toolbar.quickActions], :ui[toolbar.synchronize], :ui[sync.merge] et :ui[sync.rebaseHead], ainsi que :ui[toolbar.pushTo].

### Les trois colonnes {#columns}

La colonne de gauche est la barre latérale. La colonne du milieu affiche la liste de la vue choisie. Dans :ui[workspace.title], ce sont la zone de commit et les fichiers modifiés. Dans :ui[history.title], ce sont les commits.

La colonne de droite affiche les détails de ce que vous sélectionnez au milieu. Dans :ui[workspace.title], ce sont les modifications du fichier sélectionné. Quand un fichier a à la fois des modifications indexées et non indexées, utilisez :ui[working.staged] et :ui[working.unstaged], en haut, pour passer des unes aux autres. Si rien n’est sélectionné, la colonne affiche :ui[detail.empty.title].

### Fenêtres étroites {#narrow-window}

Quand la fenêtre devient trop étroite pour trois colonnes, elle passe à une disposition pour fenêtres étroites. Élargissez la fenêtre et les trois colonnes reviennent, à la largeur que vous leur aviez donnée.

::screenshot[Une fenêtre de dépôt étroite. Une rangée sous la barre d’outils permet de changer de vue. La zone de commit et la liste des fichiers modifiés se trouvent au-dessus des modifications du fichier sélectionné.]{name="tour-narrow-window" frame="window" markers="75,9 75,40 75,84"}

1. La rangée des vues, à la place de la barre latérale
2. La liste de la vue actuelle
3. Le détail de ce qui est sélectionné dans la liste

- La rangée des vues contient les vues qui se trouvent sous :ui[workspace.group] dans la barre latérale. Faites défiler la rangée sur le côté pour atteindre celles qui ne tiennent pas. Pour les branches, les tags, les dépôts distants et les autres vues, cliquez sur :ui[sidebar.menu] au début de la rangée. La barre latérale s’ouvre par-dessus la vue. Cliquez de nouveau sur :ui[sidebar.menu], ou en dehors de la barre latérale, pour la fermer.
- La liste se trouve au-dessus du détail. Faites glisser la ligne qui les sépare pour donner plus de place à l’un des deux.
- :ui[toolbar.bookmarks], :ui[toolbar.previous] et :ui[toolbar.next] se placent avant le titre de la fenêtre et restent toujours dans la barre d’outils, avec le champ de recherche. Les autres boutons qui ne tiennent plus passent dans le menu » au bout de la barre d’outils. :ui[sync.fetch], :ui[sync.pull] et :ui[sync.push] y passent en dernier.

La vue actuelle, votre sélection et le message de commit en cours de rédaction restent tels quels quand la disposition change.

La fenêtre Dépôts change elle aussi de disposition quand elle devient étroite. La liste des dépôts se trouve alors au-dessus du détail du dépôt sélectionné.

Pour garder une seule disposition, choisissez :ui[menu.layout.narrow] ou :ui[menu.layout.wide] dans :ui[menu.view > menu.layout]. La fenêtre utilise alors cette disposition quelle que soit sa largeur. Choisissez :ui[menu.layout.automatic] pour que la disposition suive de nouveau la largeur de la fenêtre. Ce choix s’applique à toutes les fenêtres.

### Actions rapides {#quick-actions}

Choisissez :ui[menu.file > quickActions.menu] ou appuyez sur <kbd>⇧⌘A</kbd> pour ouvrir un panneau. Tapez pour trouver une vue, une branche, un fichier ou un commit, puis lancez une action dessus sans quitter le clavier. [Fenêtres et navigation](/guide/repositories/navigation/) explique ce qu’il trouve et quelles touches il utilise.

## Voir aussi

- [Votre premier dépôt](/guide/start/first-repository/)
- [La fenêtre Dépôts](/guide/repositories/manager/)
- [Fenêtres et navigation](/guide/repositories/navigation/)
