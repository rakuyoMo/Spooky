---
title: "Revue des branches"
description: "Comparez vos branches locales à une branche de base, repérez celles que vous pouvez nettoyer, suivez les suggestions d’archivage et archivez les branches automatiquement."
---

La revue des branches liste vos branches locales et compare chacune à une branche de base. Elle montre quelles branches peuvent être fusionnées, lesquelles provoqueraient des conflits, lesquelles sont anciennes et lesquelles n’ont plus leur branche distante. Vous décidez ainsi plus facilement quoi fusionner, archiver ou supprimer.

Pour l’ouvrir, cliquez sur :ui[review.title] en haut de la barre latérale, ou choisissez :ui[menu.view > review.show] (<kbd>⌘5</kbd>).

::screenshot[La fenêtre Revue des branches. La branche de base est main. La liste affiche six branches, de feature/csv-export à spike/radar-overlay, chacune avec son état de fusion, ses commits d’avance et de retard, et sa branche suivie. feature/units-toggle est sélectionnée, et les détails à droite affichent ses commits et un bouton de conflits.]{name="branches-review" frame="window" markers="43,9 47.3,9 22,52 76,9"}

1. La branche de base
2. Le bouton de filtre
3. Si la branche peut être fusionnée sans conflit
4. Le bouton de conflits

## La liste {#list}

Choisissez la branche de base dans :ui[review.compareTo] en haut de la liste. Au début, c’est la première que le dépôt possède parmi `next`, `develop`, `dev`, `main` et `master`, sinon la branche actuelle.

Chaque branche a sa ligne :

- Une icône à gauche indique si la branche peut être fusionnée dans la base sans conflit ou si elle en provoquerait. Placez le pointeur dessus pour voir les détails.
- À droite, le nombre de commits d’avance et de retard de la branche par rapport à la base. La ligne indique :ui[review.comparing] pendant que Spooky compare.
- La deuxième ligne affiche la branche distante suivie, ou :ui[review.noTracking]. Quand la branche distante a disparu, le nom devient rouge.
- La date de la dernière mise à jour de la branche, et la dernière pull request ou merge request de la branche, avec son numéro et une couleur selon son état.

## Filtrer et trier {#filter}

Le bouton de filtre en haut à droite n’affiche qu’une partie des branches :

- :ui[review.filter.stale] et :ui[review.filter.active] séparent les branches selon qu’elles sont anciennes ou non. Une branche est ancienne quand elle n’a reçu aucun commit pendant la durée réglée dans les [réglages d’affichage](/guide/branches/branches/#filter) de la barre latérale, 6 mois au début.
- :ui[review.filter.trackingError] affiche les branches dont la branche distante a disparu.
- :ui[review.filter.mergeable] et :ui[review.filter.conflicts] se basent sur le résultat qu’aurait une fusion dans la base.
- :ui[pr.filter.with] et :ui[pr.filter.without] se basent sur les pull requests ou merge requests ouvertes. Ils nécessitent un [compte d’hébergement](/guide/hosting/accounts/) pour le dépôt distant. Sans compte, la liste l’indique.
- :ui[review.filter.none] affiche de nouveau toutes les branches.

Le bouton des réglages d’affichage, juste à côté, trie la liste par :ui[review.sort.name] ou :ui[review.sort.date], dans l’ordre :ui[review.sort.ascending] ou :ui[review.sort.descending]. Spooky retient le filtre et l’ordre.

Pour trouver une branche par son nom, saisissez-le dans le champ de recherche de la barre d’outils.

## Détails {#details}

Sélectionnez une branche pour voir à droite sa comparaison avec la base. Le haut affiche la branche et la base. Quand une fusion provoquerait des conflits, un bouton y liste les fichiers.

:ui[compare.commits] liste les commits faits sur la branche depuis qu’elle s’est séparée de la base. :ui[history.changeset] montre ce que ces commits ont modifié. Au-dessus des deux, un résumé affiche :ui[review.summary.contributors], :ui[review.summary.updated], :ui[review.summary.tracking] et :ui[review.summary.mergeStatus].

Vous pouvez sélectionner plusieurs branches à la fois, par exemple pour les archiver ou les supprimer ensemble.

## Agir sur les branches {#actions}

Cliquez avec le bouton droit sur une branche pour afficher le même menu que dans la barre latérale. Avec plusieurs branches sélectionnées, le menu s’applique à toutes.

Quand une branche serait en conflit avec la base, son menu contient aussi :ui[review.resolveConflicts]. Spooky bascule sur la branche et y fusionne la base. Vous résolvez ensuite les conflits sur la branche. Consultez [Résoudre les conflits](/guide/work/conflicts/).

Pour supprimer des branches, sélectionnez-les et appuyez sur <kbd>⌘⌫</kbd>, ou balayez une ligne vers la gauche et cliquez sur :ui[review.delete]. Spooky demande d’abord confirmation, comme dans la barre latérale.

## Suggestions d’archivage {#archive-suggestions}

Spooky suggère d’[archiver](/guide/branches/branches/#archive) une branche locale quand :

- elle est ancienne, ou
- sa pull request ou merge request a été fusionnée, et la branche n’a reçu aucun commit depuis.

Les branches épinglées et archivées ne sont jamais suggérées. `main`, `master`, `trunk`, `dev`, `develop`, `next` et les branches parentes d’une autre branche non plus.

Quand il y a des suggestions et que l’archivage automatique est désactivé, un bouton indiquant le nombre de branches apparaît en bas de la barre latérale. Cliquez dessus pour ouvrir :ui[review.archive.title] :

1. Sélectionnez les branches à archiver, ou sélectionnez :ui[menu.selectAll]. Rien n’est sélectionné au début. Chaque branche indique pourquoi elle est suggérée : :ui[pr.archive.merged] ou :ui[review.filter.stale].
2. Cliquez sur :ui[review.archive.submit].

::screenshot[La zone de dialogue d’archivage des branches liste trois branches, chacune marquée comme ancienne, dont une est sélectionnée. En bas se trouve le commutateur pour archiver les branches automatiquement.]{name="branches-archive" frame="dialog"}

Ensuite, une note en bas de la barre latérale indique combien de branches ont été archivées, avec un bouton :ui[review.archived.undo]. <kbd>⌘Z</kbd> fonctionne aussi. :ui[activity.title] consigne pourquoi chaque branche a été archivée.

## Archiver automatiquement {#auto-archive}

Spooky peut chercher une fois par jour des branches à archiver. Chacun de ces éléments l’active. Il s’agit d’un seul et même réglage :

- :ui[review.archive.auto] dans la zone de dialogue :ui[review.archive.title]
- :ui[sidebar.autoArchive] dans les réglages d’affichage de la barre latérale
- :ui[settings.autoArchive] dans :ui[app.name > settings.title] › :ui[settings.general] (consultez [Opérations](/guide/settings/general/#operations))

Il est désactivé au début.

Une fois par jour pour chaque dépôt, pendant que vous travaillez dans sa fenêtre, Spooky cherche des suggestions. S’il y en a, il ouvre la même zone de dialogue. Vous y choisissez les branches à archiver. Que vous en archiviez ou non, il revérifie un jour plus tard.

Pour en exclure une branche, cliquez dessus avec le bouton droit et sélectionnez :ui[review.skipAutoArchive] sous l’élément d’archivage du menu.

Quand des branches sont archivées de cette façon :

- Une notification indique :ui[review.archived.notification]. L’entrée dans :ui[activity.title] s’appelle :ui[review.autoArchive].
- Un point à côté de :ui[sidebar.archived] dans la barre latérale signale les branches que vous n’avez pas encore regardées. Cliquez sur l’une d’elles et sa marque disparaît après un instant. Pour les effacer toutes, cliquez avec le bouton droit sur :ui[sidebar.archived] et choisissez :ui[sidebar.markAllReviewed].

## Voir aussi

- [Branches](/guide/branches/branches/)
- [Fusionner et rebaser](/guide/branches/merge-rebase/)
- [Pull requests et merge requests](/guide/hosting/pull-requests/)
- [Comptes d’hébergement](/guide/hosting/accounts/)
