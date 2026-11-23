---
title: "Fusionner et rebaser"
description: "Fusionnez et rebasez des branches, prévisualisez les conflits avant de commencer, mettez à jour une branche depuis sa branche parente et glissez-déposez des branches dans la barre latérale."
---

La fusion et le rebasage intègrent tous deux les commits d’une autre branche dans la branche actuelle :

- Une fusion réunit les deux historiques, en général avec un commit de fusion.
- Un rebasage déplace vos commits pour qu’ils viennent après ceux de l’autre branche. L’historique reste une ligne droite, mais vos commits sont réécrits.

La barre d’outils affiche :ui[sync.merge] et :ui[sync.rebaseHead] côte à côte. Les deux se lancent aussi depuis le menu :ui[workspace.title].

## Fusionner {#merge}

1. Cliquez sur :ui[sync.merge] dans la barre d’outils, ou choisissez :ui[workspace.title > sync.mergeMenu] (<kbd>⇧⌘M</kbd>). Dans la barre latérale, vous pouvez aussi cliquer avec le bouton droit sur la branche actuelle et choisir :ui[workspace.mergeMenu] dans le menu, ou faire glisser une autre branche sur elle.
2. Choisissez ce qu’il faut fusionner dans :ui[branch.target] : une branche locale, une branche distante ou un tag. Au début, c’est la branche amont de la branche actuelle.
3. Choisissez comment valider :
   - :ui[merge.squash] indexe toutes les modifications pour un seul commit que vous faites vous-même, sans commit de fusion.
   - :ui[merge.alwaysCommit] crée un commit de fusion même quand Git pourrait simplement faire avancer votre branche.
   - :ui[merge.autoCommit] valide la fusion tout de suite. Vous ne pouvez le désélectionner que si :ui[merge.alwaysCommit] est sélectionné. Les modifications fusionnées attendent alors dans la copie de travail que vous les validiez.
4. Si la fusion doit provoquer des conflits, une ligne l’indique en dessous. Consultez [Prévisualiser les conflits](#preview).
5. Réglez les options :
   - :ui[merge.verify] arrête la fusion si le commit fusionné n’a pas de signature de confiance.
   - :ui[sync.skipHooks] ignore les crochets Git du dépôt pour cette fois.
6. Cliquez sur :ui[sync.merge].

Spooky retient :ui[merge.alwaysCommit], :ui[merge.autoCommit] et :ui[merge.verify].

Si la fusion s’arrête sur des conflits, Spooky passe à la copie de travail et affiche une bannière. Consultez [Résoudre les conflits](/guide/work/conflicts/#banner).

<kbd>⌘Z</kbd> annule une fusion. Si la fusion s’est arrêtée sur des conflits, l’annuler l’abandonne.

## Rebaser {#rebase}

1. Cliquez sur :ui[sync.rebaseHead] dans la barre d’outils, ou choisissez :ui[workspace.title > sync.rebaseMenu] (<kbd>⇧⌘R</kbd>). Vous pouvez aussi cliquer avec le bouton droit sur la branche actuelle et choisir :ui[workspace.rebaseMenu] dans le menu.
2. Choisissez la branche sur laquelle rebaser dans :ui[branch.target]. Au début, c’est la branche amont de la branche actuelle.
3. Vérifiez l’aperçu, et sélectionnez :ui[sync.skipHooks] si nécessaire.
4. Cliquez sur :ui[sync.rebaseHead].

<kbd>⌘Z</kbd> annule un rebasage terminé. Un rebasage arrêté sur un conflit ne peut pas être annulé : résolvez le conflit et continuez, ou abandonnez-le depuis la bannière.

Pour ne déplacer qu’une partie de vos commits sur une autre base, consultez [Rebaser des commits sur une autre base](/guide/history/rewrite/#rebase-onto).

:::caution
Le rebasage réécrit vos commits. Si vous les avez déjà poussés, il faudra [pousser de force](/guide/branches/sync/#force-push) la prochaine fois.
:::

## Modifications locales {#local-changes}

Une fusion exige que vos fichiers suivis soient sans modification. Les nouveaux fichiers ne gênent que si la fusion devait les écraser.

Le rebasage et la mise à jour d’une branche depuis sa branche parente exigent une copie de travail sans aucune modification, nouveaux fichiers compris.

Quand des modifications locales bloquent l’une de ces opérations, Spooky propose de les remiser d’abord. Consultez [Remisage automatique](/guide/work/stash/#auto-stash).

## Prévisualiser les conflits {#preview}

Avant de commencer, les zones de dialogue de fusion, de rebasage, de tirage et de synchronisation vérifient si les branches sont en conflit, et affichent le résultat dans la zone de dialogue :

- :ui[merge.checking] pendant que Spooky les compare.
- Le nombre de fichiers en conflit. Placez le pointeur sur la ligne pour voir lesquels.
- :ui[merge.clean] ou :ui[merge.unchanged].
- :ui[merge.unavailable] quand la vérification n’a pas abouti. Placez le pointeur sur la ligne pour voir pourquoi.

La zone de dialogue de fusion n’affiche pas :ui[merge.clean] ni :ui[merge.unchanged]. Les autres affichent tous les résultats.

## Versions rapides {#quick}

Maintenez <kbd>⌥</kbd>, et :ui[sync.merge] et :ui[sync.rebaseHead] dans la barre d’outils deviennent :ui[sync.quickMerge] et :ui[sync.quickRebase]. Ils s’exécutent tout de suite, sans zone de dialogue :

- :ui[sync.quickMerge] fusionne la branche amont de la branche actuelle.
- :ui[sync.quickRebase] rebase la branche actuelle sur sa branche amont.

La fusion rapide reprend les options de commit et de signature choisies la dernière fois dans la zone de dialogue de fusion. Les deux proposent de remiser les modifications locales, comme les zones de dialogue.

Les éléments du menu de la barre latérale changent de la même façon. Par exemple, :ui[workspace.mergeMenu] devient :ui[sync.quickMergeInto]{1="origin/main" 2="main"}.

## Mettre à jour une branche depuis sa branche parente {#update}

Quand une branche a une [branche parente](/guide/branches/branches/#parent), la mise à jour intègre les nouveaux commits de la branche parente.

1. Cliquez avec le bouton droit sur la branche et choisissez :ui[branch.updateNamed]{1="feature/units-toggle"} dans le menu. Quand vous consultez l’historique de la branche et que la branche parente a de nouveaux commits, la bannière :ui[history.parentBanner.title] contient aussi un bouton :ui[review.updateBranch.menu].
2. Vérifiez :ui[review.update.branch]. La ligne en dessous indique combien de commits viendront de la branche parente.
3. Dans :ui[review.update.strategy], choisissez :ui[review.update.merge] ou :ui[review.update.rebase]. Avec :ui[review.update.merge], vous pouvez aussi sélectionner :ui[merge.alwaysCommit].
4. Vérifiez l’aperçu : :ui[review.update.conflicts], :ui[review.update.clean] ou :ui[review.update.noChanges].
5. Réglez les options : :ui[merge.verify] (pour la fusion uniquement) et :ui[sync.skipHooks].
6. Cliquez sur :ui[review.update.button].

Spooky extrait d’abord la branche, puis fusionne ou rebase. La mise à jour n’est disponible que si la branche parente a des commits que la branche n’a pas, et qu’aucune autre opération n’est en cours.

Pour la branche actuelle, :ui[branch.mergeWith]{1="main"} et :ui[branch.rebaseOn]{1="main"} dans le menu de la barre latérale ouvrent les zones de dialogue de fusion et de rebasage avec la branche parente déjà choisie.

:::tip
Maintenez <kbd>⌥</kbd> pendant que le menu est ouvert, et :ui[branch.updateNamed]{1="feature/units-toggle"} devient :ui[branch.quickUpdateNamed]{1="feature/units-toggle"}. Il fusionne la branche parente tout de suite, sans zone de dialogue.
:::

## Glisser-déposer {#drag-and-drop}

Beaucoup d’opérations sur les branches commencent par un glissement dans la barre latérale. Pendant le glissement, l’étiquette à côté du pointeur indique ce qui va se passer. Survolez un instant un dossier ou un dépôt distant replié, et il s’ouvre.

| Faites glisser | Sur | Ce qui se passe |
|---|---|---|
| Une branche locale | :ui[workspace.title] ou la branche actuelle | La zone de dialogue de fusion. Maintenez <kbd>⌥</kbd> pour celle de rebasage. |
| Une branche distante | :ui[workspace.title] ou la branche actuelle | La zone de dialogue de tirage |
| Une branche distante, en maintenant <kbd>⌥</kbd> | La branche actuelle | Elle devient la branche amont de votre branche. |
| Une branche locale, un tag ou un commit | :ui[branch.group] | La zone de dialogue pour créer une branche à partir de l’élément |
| Une branche distante | :ui[branch.group] | La zone de dialogue pour la suivre |
| Une branche locale | Un dépôt distant | La zone de dialogue de publication |
| Une branche locale | Une branche distante | La zone de dialogue :ui[sync.pushBranch] |
| Une branche locale ou un commit | :ui[sidebar.tags] ou un dossier de tags | La zone de dialogue pour créer un tag |
| Un tag | Un dépôt distant | La zone de dialogue pour publier le tag |
| Une branche locale | :ui[sidebar.pinned] ou :ui[sidebar.archived] | La branche est épinglée ou archivée. |
| Une branche locale | :ui[worktree.group] | La zone de dialogue pour lui créer un worktree |

Pour déplacer une branche dans un dossier, faites-la glisser sur le dossier. La branche est renommée avec le nom du dossier suivi de la dernière partie de son nom, sans zone de dialogue. Une branche distante ne peut aller que dans les dossiers de son propre dépôt distant. Pour sortir une branche de son dossier, faites-la glisser vers le bord supérieur ou inférieur de la liste. Vous pouvez annuler le changement de nom avec <kbd>⌘Z</kbd>.

Vous pouvez aussi faire glisser des commits de l’historique sur :ui[workspace.title] ou sur la branche actuelle pour en faire un cherry-pick. Maintenez <kbd>⌥</kbd> pour les annuler par revert à la place. Consultez [Faire un cherry-pick](/guide/history/rewrite/#cherry-pick). Faites-y glisser un seul fichier depuis les modifications d’un commit, et seules les modifications de ce fichier sont appliquées à la copie de travail, sans être indexées.

## Voir aussi

- [Résoudre les conflits](/guide/work/conflicts/)
- [Réécrire l’historique](/guide/history/rewrite/)
- [Récupérer, tirer et pousser](/guide/branches/sync/)
- [Branches](/guide/branches/branches/)
