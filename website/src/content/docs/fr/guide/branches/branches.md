---
title: "Branches"
description: "Créez, extrayez, suivez, renommez, supprimez, épinglez et archivez des branches, définissez des branches parentes, puis filtrez et groupez les branches dans la barre latérale."
---

Vos branches locales sont listées dans la barre latérale sous :ui[branch.group]. Presque tout ce que vous faites avec une branche part de là : cliquez dessus avec le bouton droit pour afficher son menu, ou faites-la glisser quelque part.

::screenshot[Le bas de la barre latérale. Sous Branches, main porte un badge HEAD avec ↑3, et un dossier feature contient dark-mode, station-map et units-toggle. Branches archivées est vide. Tags liste v0.1.0 à v0.4.0. Sous Dépôts distants, origin contient main avec une icône de maison et un dossier feature replié. La barre du bas contient le champ de filtre à gauche, et les boutons d’ajout et de réglages d’affichage à droite.]{name="branches" frame="closeup" markers="57,7 57,12.1 75,33.6 17,96.8 73,96.8"}

1. La branche actuelle, avec son badge HEAD et les commits pas encore poussés
2. Un dossier pour les branches dont le nom commence par `feature/`
3. :ui[sidebar.archived]
4. :ui[sidebar.filter]
5. Le bouton d’ajout et le bouton des réglages d’affichage

## Dans la barre latérale {#sidebar}

Cliquez sur une branche pour voir ses commits dans l’historique. Double-cliquez dessus pour l’extraire.

Une branche qui suit une branche distante indique l’écart entre les deux. ↑ compte vos commits qui ne sont pas encore sur le dépôt distant. ↓ compte les commits du dépôt distant que vous n’avez pas. Placez le pointeur sur une branche pour voir ce qu’elle suit.

Une branche qui n’a pas reçu de commit depuis un moment est ancienne. Son nom est estompé, suivi d’une horloge et de la durée écoulée. `main`, `master`, `trunk`, `dev`, `develop`, `next` et toute branche qui est la branche parente d’une autre ne sont jamais anciennes.

Sous :ui[remote.group], une icône de maison marque la branche par défaut de chaque dépôt distant.

## Créer une branche {#create}

1. Choisissez :ui[menu.repository > branch.createMenu] (<kbd>⌘B</kbd>). Vous pouvez aussi cliquer sur le bouton d’ajout en bas de la barre latérale, ou cliquer avec le bouton droit sur :ui[branch.group], puis le choisir dans le menu.
2. Saisissez le nom dans :ui[reference.name].
3. Choisissez le point de départ de la branche dans :ui[branch.start]. Au début, c’est la branche actuelle, ou l’élément sur lequel vous avez cliqué avec le bouton droit pour arriver ici.
4. Réglez les options :
   - :ui[branch.trackStart] fait suivre son point de départ à la nouvelle branche. L’option n’est disponible que si le point de départ est une branche.
   - :ui[branch.pin] place la nouvelle branche sous :ui[sidebar.pinned].
   - :ui[branch.checkoutCreated] extrait tout de suite la nouvelle branche. Spooky retient ce choix.
   - :ui[branch.parentOption] fait du point de départ la [branche parente](#parent) de la nouvelle branche.
5. Cliquez sur :ui[branch.create].

Pour créer une branche à partir d’une branche, d’un tag ou d’un commit précis, cliquez dessus avec le bouton droit et choisissez :ui[branch.createFromMenu]{1="main"} dans le menu. Vous pouvez aussi le faire glisser sur :ui[branch.group].

Pendant la saisie, Spooky corrige le nom pour Git : les espaces et les caractères que Git n’accepte pas deviennent `-` ou sont supprimés. Pour saisir les noms tels quels, désactivez :ui[branch.cleanNames] dans :ui[app.name > settings.title] › :ui[settings.general]. Consultez [Opérations](/guide/settings/general/#operations).

Un `/` dans un nom range la branche dans un dossier, comme `feature/units-toggle` dans `feature`. Cliquez avec le bouton droit sur un dossier et choisissez :ui[branch.createMenu] dans le menu : le nom commence déjà par le dossier.

## Extraire une branche {#checkout}

Double-cliquez sur une branche, ou cliquez dessus avec le bouton droit et choisissez :ui[branch.checkoutNamed]{1="feature/dark-mode"} dans le menu.

Le double-clic fonctionne aussi sur une branche distante :

- Si une branche locale la suit déjà, Spooky extrait cette branche.
- S’il existe une branche locale du même nom qui ne la suit pas, Spooky demande d’abord confirmation dans :ui[branch.trackExisting.title]. Il extrait ensuite cette branche et lui fait suivre la branche distante.
- Sinon, Spooky crée une branche locale du même nom qui suit la branche distante. Puis il extrait cette branche.

Si des fichiers suivis sont modifiés, Spooky demande s’il faut d’abord les remiser. Consultez [Remisage automatique](/guide/work/stash/#auto-stash).

Une branche extraite dans un autre worktree ne peut pas être extraite ici. Double-cliquez dessus et Spooky ouvre ce worktree à la place. Maintenez <kbd>⌘</kbd> pendant le double-clic pour l’ouvrir dans un nouvel onglet.

### Extraire un tag ou un commit {#checkout-revision}

Double-cliquez sur un tag pour extraire son commit. Pour extraire autre chose, choisissez :ui[workspace.title > rewrite.checkout.menu] (<kbd>⇧⌘B</kbd>), choisissez une branche, un tag ou un commit, puis cliquez sur :ui[rewrite.checkout.button].

Si votre choix n’est pas une branche locale, la zone de dialogue prévient que HEAD sera détaché. Un HEAD détaché signifie que vous êtes sur un commit, pas sur une branche. Pour garder les commits que vous y faites, créez une branche à partir d’eux.

## Suivre une branche distante {#track}

Une branche locale peut suivre une branche d’un dépôt distant, sa branche amont. Tirer et pousser utilisent la branche amont, sauf si vous choisissez autre chose. Les compteurs ↑ et ↓ se comparent à elle.

Pour obtenir une branche locale à partir d’une branche distante :

1. Cliquez avec le bouton droit sur la branche distante et choisissez :ui[branch.trackMenu]{1="origin/feature/station-map"} dans le menu, ou faites-la glisser sur :ui[branch.group].
2. :ui[branch.remoteField] affiche la branche distante. Modifiez le nom dans :ui[reference.name] si vous le souhaitez.
3. :ui[branch.track.checkout] est sélectionné à chaque fois. Désélectionnez-le pour rester sur la branche actuelle.
4. Cliquez sur :ui[branch.track.submit].

Pour changer ce que suit une branche existante, cliquez dessus avec le bouton droit et choisissez une branche sous :ui[branch.tracking]. :ui[branch.tracking.remove] arrête le suivi. Pour la branche actuelle, vous pouvez aussi maintenir <kbd>⌥</kbd> et faire glisser une branche distante sur elle.

Quand une branche autre que la branche actuelle est en retard sur sa branche amont et n’a aucun commit propre, son menu contient :ui[branch.fastForward]{1="main"}. La branche avance jusqu’à sa branche amont sans que vous l’extrayiez.

## Renommer une branche {#rename}

Cliquez avec le bouton droit sur la branche et choisissez :ui[reference.renameMenu]{1="feature/dark-mode"} dans le menu. Saisissez le nouveau nom et cliquez sur :ui[reference.rename].

L’épinglage, l’archivage et la branche parente suivent la branche. Renommer une branche distante la renomme sur le dépôt distant.

Pour déplacer une branche dans un dossier, faites-la glisser sur le dossier. Consultez [Glisser-déposer](/guide/branches/merge-rebase/#drag-and-drop).

## Supprimer une branche {#delete}

Cliquez avec le bouton droit sur la branche et choisissez :ui[reference.deleteMenu]{1="feature/dark-mode"} dans le menu. Vous pouvez aussi sélectionner une ou plusieurs branches et appuyer sur <kbd>⌘⌫</kbd> quand la barre latérale est active.

Spooky demande toujours confirmation. La zone de dialogue propose deux options :

- :ui[branch.forceDelete] supprime la branche même si elle n’est pas entièrement fusionnée. Sans cette option, Spooky liste les branches qui ne sont pas entièrement fusionnées et redemande confirmation.
- :ui[branch.deleteUpstream] supprime aussi la branche distante qu’elle suit. L’option apparaît quand vous supprimez une seule branche dont la branche distante existe encore.

Vous ne pouvez pas supprimer la branche actuelle. Extrayez d’abord une autre branche.

Supprimer une branche distante la supprime sur le dépôt distant.

Pour retrouver une branche locale supprimée, choisissez :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>). Cela fonctionne même avec :ui[branch.deleteUpstream] sélectionné. La suppression d’une branche distante seule ne peut pas être annulée. Consultez [Annulation et récupération](/guide/work/undo/).

## Épingler une branche {#pin}

Les branches épinglées passent de :ui[branch.group] à :ui[sidebar.pinned], en haut de la liste. Épinglez les branches sur lesquelles vous revenez souvent.

Cliquez avec le bouton droit sur une branche et choisissez :ui[branch.pinNamed]{1="feature/station-map"} dans le menu, ou faites-la glisser sur :ui[sidebar.pinned]. Avec plusieurs branches sélectionnées, l’élément s’appelle :ui[branch.pinMultiple]{1="2"}. Pour remettre une branche à sa place, choisissez :ui[branch.unpinNamed]{1="feature/station-map"}.

## Archiver une branche {#archive}

Archiver une branche la met à l’écart sans la supprimer. Elle passe de :ui[branch.group] à :ui[sidebar.archived]. Vous pouvez toujours l’utiliser comme avant.

Cliquez avec le bouton droit sur une branche et choisissez :ui[branch.archiveNamed]{1="feature/dark-mode"} dans le menu, ou faites-la glisser sur :ui[sidebar.archived]. Pour la faire revenir, choisissez :ui[branch.unarchiveNamed]{1="feature/dark-mode"}.

Spooky peut aussi trouver les branches qui méritent d’être archivées, et les archiver pour vous. Consultez [Revue des branches](/guide/branches/review/#archive-suggestions).

:::note[Dépôts sur un serveur]
L’épinglage, l’archivage et les branches parentes sont enregistrés dans la configuration Git du dépôt. Pour un dépôt sur un serveur, ils sont enregistrés sur le serveur.
:::

## Branche parente {#parent}

La branche parente est celle sur laquelle la vôtre est basée et avec laquelle elle doit rester à jour, comme `main` pour `feature/units-toggle`.

Pour la définir, cliquez avec le bouton droit sur la branche et choisissez une branche suggérée sous :ui[branch.parent]. Pour toute autre branche, choisissez :ui[branch.parent.setMenu], sélectionnez-la dans :ui[branch.parent.field], puis cliquez sur :ui[branch.parent.set]. Vous pouvez aussi la définir à la création de la branche. :ui[branch.parent.remove] la retire.

Une fois qu’une branche a une branche parente :

- La comparaison de branches dans l’historique propose d’abord la branche parente. Consultez [Comparer avec une autre branche](/guide/history/browse/#compare-branches).
- Quand la branche parente a des commits que votre branche n’a pas, l’historique de votre branche affiche :ui[history.parentBanner.title]. Le menu de la branche contient :ui[branch.updateNamed]{1="feature/units-toggle"} pour les intégrer. Consultez [Mettre à jour une branche depuis sa branche parente](/guide/branches/merge-rebase/#update).
- Pour la branche actuelle, :ui[branch.mergeWith]{1="main"} et :ui[branch.rebaseOn]{1="main"} dans le menu ouvrent les zones de dialogue de fusion et de rebasage avec la branche parente déjà choisie.
- La branche parente elle-même n’est jamais ancienne.

## Filtrer et grouper {#filter}

Saisissez du texte dans :ui[sidebar.filter] en bas de la barre latérale pour n’afficher que les branches, tags, branches distantes, sous-modules et worktrees correspondants. Les lettres n’ont pas besoin de se suivre : `stm` trouve `station-map`. La casse et les accents ne comptent pas. Les dossiers s’ouvrent pendant le filtrage, et <kbd>Esc</kbd> vide le champ.

Cliquez sur le bouton des réglages d’affichage en bas à droite, ou choisissez :ui[menu.view > sidebar.menu], pour régler ce que la barre latérale affiche. Les réglages s’appliquent à toutes les fenêtres.

- :ui[sidebar.groupRefs] range dans des dossiers les noms qui contiennent un `/`. L’option est activée au début. :ui[sidebar.groupedRefsOnTop] liste les dossiers avant les autres branches.
- :ui[sidebar.showStaleInfo] indique quelles branches sont anciennes. :ui[sidebar.staleInterval] règle la durée qu’une branche peut passer sans commit, 6 mois au début.
- :ui[sidebar.remoteFilter] et :ui[sidebar.tagsFilter] limitent la liste aux quelques éléments les plus récents sous :ui[sidebar.showNewest]. La limite s’applique à chaque dépôt distant séparément. Les tags peuvent aussi être triés sous :ui[sidebar.sortBy]. Pendant le filtrage, toutes les correspondances s’affichent.
- :ui[sidebar.autoArchive] est décrit dans [Revue des branches](/guide/branches/review/#auto-archive).

## Voir aussi

- [Récupérer, tirer et pousser](/guide/branches/sync/)
- [Fusionner et rebaser](/guide/branches/merge-rebase/)
- [Revue des branches](/guide/branches/review/)
- [Worktrees](/guide/advanced/worktrees/)
