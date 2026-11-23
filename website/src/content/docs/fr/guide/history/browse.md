---
title: "Parcourir l’historique"
description: "Parcourez la liste et le graphe des commits, lisez les pastilles de référence, recherchez et filtrez les commits, et changez les options de présentation."
---

La vue :ui[history.title] liste les commits d’un dépôt, du plus récent au plus ancien, à côté d’un graphe qui montre comment ils se relient. Sélectionnez un commit pour voir ses détails à droite.

::screenshot[La vue Historique d’un dépôt. L’en-tête au-dessus de la liste indique Toutes les branches, dépôts distants et tags, avec le bouton des options de présentation à son extrémité droite. Les commits sont regroupés sous novembre 2026. Des lignes colorées, à gauche, relient les commits, et des pastilles comme HEAD, main et v0.4.0 figurent à côté des noms d’auteur. À droite se trouvent les détails du commit sélectionné, avec les boutons Modifications et Arborescence en haut.]{name="history" frame="window" markers="50,13.75 42,23 22.5,62 79,9"}

1. L’en-tête : ce que la liste affiche, et les options de présentation
2. Les pastilles des branches et des tags qui pointent sur un commit
3. Le graphe des commits
4. Les détails du commit sélectionné. Consultez [Détails d’un commit](/guide/history/commit-details/).

## Ouvrir l’historique {#open}

- :ui[menu.view > menu.showHistory] (<kbd>⌘2</kbd>), ou :ui[history.title] dans la barre latérale, affiche ensemble toutes les branches, les branches distantes et les tags. L’en-tête indique :ui[history.all].
- Cliquez sur une branche, un tag ou une branche distante dans la barre latérale pour ne voir que son historique. Cliquez sur d’autres en maintenant <kbd>⌘</kbd> enfoncée pour les voir ensemble.
- :ui[menu.view > history.showHead] (<kbd>⌘0</kbd>) affiche l’historique de la branche sur laquelle vous êtes.

Quand vous regardez une branche locale qui a une branche amont, l’en-tête affiche les deux, comme dans `main › origin/main`. La liste comprend alors les commits de la branche amont que vous n’avez pas encore tirés.

## La liste des commits {#list}

Chaque ligne affiche l’avatar et le nom de l’auteur, la date, le hash court et la première ligne du message. Par défaut, les commits sont regroupés par mois.

Quand la liste affiche une branche locale qui a une branche amont :

- ↑ marque un commit que vous n’avez pas poussé.
- ↓ marque un commit que vous n’avez pas tiré. Ces lignes sont estompées.

Spooky charge les 100 premiers commits. Il charge les 100 suivants quand vous faites défiler jusqu’à la fin. Pour en charger davantage à la fois, modifiez :ui[history.pageSize] dans :ui[app.name > settings.title] › :ui[settings.general]. Sur la même page, :ui[settings.dateFormat] règle la présentation des dates dans la liste. Consultez [Historique et diffs](/guide/settings/general/#history).

Cliquez sur un commit pour le sélectionner. Cliquez en maintenant <kbd>⇧</kbd> ou <kbd>⌘</kbd> enfoncée pour en sélectionner plusieurs. <kbd>⌘C</kbd> copie les hashs complets des commits sélectionnés. Double-cliquez sur un commit pour ouvrir ses détails en pleine page.

Cliquez sur un commit avec le bouton droit pour voir tout ce que vous pouvez en faire. Si le commit n’est pas sélectionné, le menu n’agit que sur ce commit. Votre sélection reste telle quelle.

## Le graphe des commits {#graph}

Le graphe, à gauche, représente chaque commit par un point, avec des lignes qui descendent vers ses parents. Un commit de fusion a plusieurs lignes qui descendent.

Pour le masquer, désactivez :ui[history.showGraph] dans les [options de présentation](#view-options) (<kbd>⌃⌘G</kbd>). :ui[history.firstParentOnly] ne suit que le premier parent de chaque fusion. Les commits arrivés par une fusion sont laissés de côté.

## Pastilles de référence {#badges}

Les pastilles à côté du nom de l’auteur montrent ce qui pointe sur un commit :

| Pastille | Ce qui pointe sur le commit |
|---|---|
| HEAD en bleu | Le commit que vous avez extrait |
| Bleue | Une branche locale |
| Grise | Une branche distante |
| Jaune | Un tag |
| Rouge | Un remisage |

La branche sur laquelle vous êtes vient en premier. Les pastilles qui ne tiennent pas se replient en « … ».

Cliquez sur la pastille d’un tag pour voir la signature du tag : la clé et sa validité, ou :ui[signature.unsigned].

## Rechercher et filtrer {#search}

1. Appuyez sur <kbd>⌘F</kbd>, ou cliquez dans le champ de recherche de la barre d’outils.
2. Cliquez sur la loupe dans le champ pour choisir sur quoi porte la recherche : :ui[history.search.message], :ui[history.search.author], :ui[history.search.committer], :ui[history.search.file], :ui[history.search.hash], :ui[history.search.sinceDate] ou :ui[history.search.untilDate].
3. Saisissez du texte. La liste n’affiche que les commits correspondants.

Pendant la saisie, Spooky suggère des auteurs, des validateurs et des chemins de fichier. Quand vous recherchez dans les messages, les suggestions permettent aussi de passer à un autre type de recherche. Si vous saisissez une date, la première suggestion recherche les commits depuis cette date.

Comment chaque type établit la correspondance :

- Les messages, les auteurs et les validateurs sont comparés comme des expressions régulières, sans tenir compte de la casse.
- Un fichier correspond aux commits qui l’ont modifié. Un dossier correspond aux commits qui ont modifié quoi que ce soit à l’intérieur.
- Un hash de commit nécessite au moins les 4 premiers caractères.

La recherche apparaît sous la forme d’une ligne sous l’en-tête. Pour ajouter une autre condition, cliquez sur le bouton d’ajout et choisissez son type dans le menu au début de la nouvelle ligne. Pour une date, choisissez :ui[history.search.after], :ui[history.search.before] ou :ui[history.search.range]. Pour retirer une condition, cliquez sur son bouton de suppression.

Avec plusieurs conditions :

- Les conditions de types différents doivent toutes être remplies.
- Parmi plusieurs conditions du même type, un commit n’a besoin d’en remplir qu’une. Les dates font exception : un commit doit remplir toutes les conditions de date.

La recherche prend fin quand vous passez à une autre vue.

## Options de présentation {#view-options}

Cliquez sur le bouton des options de présentation à l’extrémité droite de l’en-tête, ou choisissez :ui[menu.view > history.title] :

| Option | Ce qu’elle fait |
|---|---|
| :ui[history.showGraph] | Affiche le graphe des commits. Activée par défaut. |
| :ui[history.firstParentOnly] | Ne suit que le premier parent de chaque fusion |
| :ui[history.sortBy] | :ui[history.sort.topo] garde ensemble les commits de chaque ligne de travail. :ui[history.sort.date] les classe par date. Tant que le graphe est affiché, :ui[history.sort.topo] reste activé. Quand les deux sont activés, c’est l’ordre des dates qui est utilisé. |
| :ui[history.groupBy] | Regroupe les commits par jour, par semaine ou par mois sous des intertitres, ou pas du tout. Ne s’applique que lors d’un tri par date. |
| :ui[history.medium] / :ui[history.small] | Deux lignes par commit, ou une seule. Les petites lignes ne s’appliquent que tant que le graphe est affiché. |
| :ui[signature.verify] | Marque les commits signés. Consultez [Signatures](/guide/history/commit-details/#signatures). |
| :ui[history.compareBranches] | Consultez [Comparer avec une autre branche](#compare-branches) |

Ces options s’appliquent à toutes les fenêtres et à tous les dépôts. Spooky les retient.

## Comparer avec une autre branche {#compare-branches}

Pour voir comment une branche locale se situe par rapport à une autre :

1. Cliquez sur la branche dans la barre latérale.
2. Cliquez sur le bouton de comparaison dans l’en-tête. Vous pouvez aussi activer :ui[history.compareBranches] dans les options de présentation, ou appuyer sur <kbd>⌃⌥⌘C</kbd>.
3. À côté de :ui[history.compareTo], choisissez l’autre branche dans le menu. Spooky commence par la branche parente de la branche si elle en a une.

Une ligne de la liste marque l’endroit où les deux branches se séparent. Les commits situés en dessous appartiennent aussi à l’autre branche. Ils sont estompés. Si la branche n’a pas encore de commits à elle, la liste indique :ui[history.noNewCommits].

L’en-tête peut aussi afficher deux pastilles. L’une compte les commits de l’autre branche que cette branche n’a pas encore. L’autre apparaît quand la fusion de l’autre branche provoquerait des conflits. Cliquez dessus pour lister les fichiers.

## Retrouver un commit dans l’historique {#reveal}

Quand la liste n’affiche que certaines branches, cliquez sur un commit avec le bouton droit et choisissez :ui[quickActions.revealInHistory]. La liste passe à toutes les branches et sélectionne le commit.

Si le commit est loin en arrière, au-delà des 10 000 premiers commits, Spooky demande confirmation avant de charger l’historique jusque-là. Si le commit n’est pas dans l’historique, une ligne au-dessus de la liste le signale.

## Voir aussi

- [Détails d’un commit](/guide/history/commit-details/)
- [Réécrire l’historique](/guide/history/rewrite/)
- [Branches](/guide/branches/branches/)
