---
title: "Réécrire l’historique"
description: "Annulez des commits par revert, faites des cherry-picks, réinitialisez, rebasez de façon interactive et corrigez des commits plus anciens."
---

La plupart des commandes de cette page partent de la liste de l’[historique](/guide/history/browse/) : cliquez sur un commit avec le bouton droit, ou sélectionnez-en d’abord plusieurs. Le revert et le cherry-pick ajoutent de nouveaux commits. Les autres réécrivent des commits qui existent déjà.

:::caution
Les commits réécrits reçoivent de nouveaux hashs. Si vous les avez déjà poussés, votre branche et sa branche amont divergent, et la prochaine poussée exige de pousser de force. Toute personne qui a déjà les anciens commits doit réconcilier son historique. Consultez [Pousser de force](/guide/branches/sync/#force-push).
:::

À part le cherry-pick et la réinitialisation, ces commandes n’apparaissent dans le menu d’un commit que tant que la liste affiche uniquement la branche sur laquelle vous êtes. Pour y arriver, choisissez :ui[menu.view > history.showHead] (<kbd>⌘0</kbd>), ou cliquez sur la branche dans la barre latérale.

::screenshot[Le menu contextuel du commit 2daa6982 quand la liste affiche la branche sur laquelle vous êtes. On y trouve notamment Réinitialiser HEAD, Revert et Rebaser ailleurs, suivis de Corriger, Modifier, Modifier le message de commit et Supprimer pour ce commit.]{name="history-commit-menu" frame="closeup"}

## Annuler un commit par revert {#revert}

Le revert ajoute un commit qui annule les modifications d’un commit antérieur. Le commit antérieur reste dans l’historique : c’est donc le moyen sûr de revenir sur quelque chose que vous avez déjà poussé.

1. Cliquez sur le commit avec le bouton droit et choisissez :ui[rewrite.menu.revert]{1="e2dda2bc"} dans le menu. Avec plusieurs commits sélectionnés, l’élément est :ui[rewrite.menu.revertMany]{1="3"}.
2. :ui[rewrite.revert.commit] est activé par défaut, donc chaque commit annulé reçoit son propre commit. Désactivez-le pour laisser les modifications dans la copie de travail. Spooky retient ce choix.
3. Cliquez sur :ui[rewrite.revert.button].

Plusieurs commits sont annulés du plus récent au plus ancien. Pour annuler un commit de fusion, choisissez son :ui[rewrite.mainline] : le parent dont le côté compte comme la ligne principale. Un commit de fusion ne peut être annulé que seul.

Les détails du commit et la [sélection multiple](/guide/history/commit-details/#multiple) ont aussi un bouton :ui[rewrite.revert.button].

## Faire un cherry-pick {#cherry-pick}

Le cherry-pick copie les modifications de commits d’une autre branche sur la branche sur laquelle vous êtes, sous la forme de nouveaux commits.

1. Cliquez sur l’autre branche dans la barre latérale pour voir son historique.
2. Cliquez sur le commit avec le bouton droit et choisissez :ui[rewrite.menu.cherryPick]{1="e2dda2bc"} dans le menu. Avec plusieurs commits sélectionnés, l’élément est :ui[rewrite.menu.cherryPickMany]{1="3"}, et vous pouvez aussi cliquer sur :ui[rewrite.cherryPick.button] à droite.
3. Choisissez les options. Spooky les retient :
   - :ui[rewrite.cherryPick.commit] (activé par défaut) valide chacun d’eux. Désactivez-le pour seulement appliquer les modifications à la copie de travail.
   - :ui[rewrite.cherryPick.fastForward] déplace votre branche vers le commit au lieu de le copier, quand votre branche se trouve sur le parent du commit. Il ne s’applique que si la première option est activée.
4. Cliquez sur :ui[rewrite.cherryPick.button].

Les commits sont appliqués du plus ancien au plus récent. Un commit de fusion nécessite un :ui[rewrite.mainline], comme pour le revert.

Tant que la liste affiche la branche sur laquelle vous êtes, l’élément n’apparaît que pour les commits de la branche amont que vous n’avez pas encore tirés.

Vous pouvez aussi faire glisser des commits de la liste sur :ui[workspace.title] ou sur la branche sur laquelle vous êtes dans la barre latérale. Maintenez <kbd>⌥</kbd> enfoncée en les déposant pour les annuler par revert à la place.

## Réinitialiser à un commit antérieur {#reset}

La réinitialisation déplace la branche sur laquelle vous êtes vers un autre commit. Les commits qui le suivent quittent la branche.

1. Cliquez sur le commit avec le bouton droit et choisissez :ui[rewrite.menu.reset]{1="e2dda2bc"} dans le menu. Vous pouvez aussi cliquer sur :ui[history.rollback] dans les détails du commit, ou choisir :ui[workspace.title > rewrite.reset.menu] dans la barre des menus.
2. Vérifiez :ui[rewrite.revision]. Vous pouvez choisir une branche, une branche distante ou un tag, ou saisir un hash. La zone de dialogue liste les commits qui quitteront la branche.
3. Choisissez un :ui[rewrite.reset.mode] :
   - :ui[rewrite.reset.soft] garde l’index et la copie de travail tels quels. Les modifications des commits qui partent restent indexées.
   - :ui[rewrite.reset.mixed] réinitialise l’index et garde la copie de travail. Ces modifications deviennent non indexées.
   - :ui[rewrite.reset.hard] réinitialise les deux. Les modifications non validées, ainsi que celles des commits qui partent, sont abandonnées.
4. Cliquez sur :ui[rewrite.reset.button].

La zone de dialogue commence à chaque fois sur :ui[rewrite.reset.soft]. La réinitialisation ne propose pas de remiser vos modifications.

:::caution
:ui[rewrite.reset.hard] abandonne les modifications non validées des fichiers suivis. La zone de dialogue vous avertit quand il y en a. <kbd>⌘Z</kbd> les ramène, mais seulement jusqu’à ce que vous quittiez Spooky.
:::

## Rebaser des commits sur une autre base {#rebase-onto}

:ui[rewrite.rebaseOnto] déplace des commits pour les poser sur un autre commit.

- Pour déplacer toute une portion de votre branche, choisissez :ui[workspace.title > rewrite.rebaseOnto.menu] dans la barre des menus. Remplissez :ui[rewrite.rebaseOnto.current] et :ui[rewrite.rebaseOnto.new]. Les commits qui suivent la base actuelle sont rejoués sur la nouvelle.
- Pour ne déplacer que certains commits, sélectionnez-les et cliquez avec le bouton droit. Choisissez :ui[rewrite.menu.rebaseOntoMany]{1="3"} dans le menu, ou :ui[rewrite.menu.rebaseOnto]{1="e2dda2bc"} pour un seul commit, puis remplissez :ui[rewrite.rebaseOnto.new]. Les commits de la même portion que vous n’avez pas sélectionnés sont retirés de la branche.

Aucune des deux bases ne peut être le commit que vous avez extrait. La zone de dialogue liste les commits qui seront réécrits, et vous avertit quand certains sont déjà poussés ou présents dans d’autres branches. :ui[sync.skipHooks] ignore pour cette fois le crochet pre-rebase du dépôt. Cliquez sur :ui[rewrite.rebaseOnto.button] pour commencer.

Pour rebaser une branche sur une autre branche, consultez [Rebaser](/guide/branches/merge-rebase/#rebase).

## Fusionner, intégrer, supprimer et déplacer des commits {#interactive}

Ces commandes réécrivent une suite de commits sur la branche sur laquelle vous êtes. Sélectionnez les commits, cliquez avec le bouton droit et choisissez :

- :ui[rewrite.menu.squashMany]{1="3"} pour les fondre dans le plus ancien. Leurs messages sont combinés, et la liste sélectionne ensuite le nouveau commit.
- :ui[rewrite.menu.fixupMany]{1="3"} pour les fondre dans le plus ancien, en ne gardant que son message.
- :ui[rewrite.menu.deleteMany]{1="3"} pour les retirer de la branche. Avec un seul commit sélectionné, :ui[rewrite.menu.delete]{1="e2dda2bc"} fait la même chose.

Vous pouvez aussi faire glisser des commits dans la liste :

- Déposez-les sur un autre commit pour les fusionner avec lui. Maintenez <kbd>⌥</kbd> enfoncée en les déposant pour les intégrer (fixup) à la place. Le libellé au point de dépôt indique :ui[rewrite.squash.button] ou :ui[rewrite.fixup.button].
- Déposez-les entre deux lignes pour les y déplacer. Le libellé indique :ui[branch.moveHere].

Pour toutes ces commandes, Spooky demande confirmation avant de réécrire quoi que ce soit. La zone de dialogue liste chaque commit qui sera réécrit, avec ce qui lui arrive, comme :ui[rewrite.note.squash] ou :ui[rewrite.note.drop]. Un panneau d’avertissement jaune marque les commits déjà poussés ou présents dans d’autres branches, et un avertissement au-dessus de la liste donne l’explication. La suppression de commits déjà présents sur la branche amont pose d’abord une question supplémentaire.

::screenshot[La zone de dialogue qui demande confirmation avant de fusionner deux commits dans 10e44ab8. Deux avertissements en haut indiquent que certains des commits sont déjà sur la branche amont ou dans d’autres branches. La liste en dessous affiche les quatre commits réécrits, avec ce qui arrive à chacun. Le commit poussé a un panneau d’avertissement jaune à la fin de sa ligne. Les boutons sont Annuler et Fusionner les commits.]{name="history-rewrite-confirm" frame="dialog"}

## Modifier le message d’un commit {#reword}

1. Cliquez sur le commit avec le bouton droit et choisissez :ui[rewrite.menu.reword]{1="e2dda2bc"} dans le menu.
2. Modifiez :ui[working.subject] et :ui[working.body]. Les lignes de commentaire sont traitées comme dans la [zone de commit](/guide/work/commit/#comments).
3. Cliquez sur :ui[rewrite.reword.button].

Les commits qui le suivent sont réécrits eux aussi, et la liste sélectionne ensuite le commit sous son nouveau hash. Si le commit est déjà sur la branche amont, Spooky demande confirmation avant d’ouvrir la zone de dialogue.

## Modifier un commit {#edit}

La modification s’arrête sur un commit et remet ses modifications dans la copie de travail, pour que vous puissiez le scinder ou le refaire.

1. Cliquez sur le commit avec le bouton droit et choisissez :ui[rewrite.menu.edit]{1="e2dda2bc"}. Confirmez avec :ui[rewrite.edit.button].
2. La bannière indique :ui[conflict.title.edit]{1="e2dda2bc" 2="main"}. Les modifications du commit sont dans la copie de travail, non indexées.
3. Indexez-les et validez-les comme d’habitude, en autant de commits que vous voulez.
4. Cliquez sur :ui[working.endEditing] dans la bannière. Les commits qui le suivent sont rejoués par-dessus.

Pour renoncer, cliquez sur :ui[working.abort] dans la bannière. Le premier commit d’un dépôt ne peut pas être modifié.

## Corriger un commit plus ancien {#amend}

Corriger un commit plus ancien lui ajoute des modifications, comme le fait la [correction du dernier commit](/guide/work/commit/#amend).

1. Cliquez sur le commit avec le bouton droit et choisissez :ui[rewrite.menu.amend]{1="e2dda2bc"}. Spooky commence aussitôt, sans confirmation.
2. Le rebasage s’arrête sur ce commit. Faites vos modifications et indexez-les.
3. Cochez :ui[working.amend] dans la zone de commit, et validez.
4. Cliquez sur :ui[working.endEditing] dans la bannière. Les commits qui le suivent sont rejoués par-dessus.

Si vous avez des modifications locales au départ, Spooky propose de les remiser d’abord. Elles restent ensuite dans le remisage, donc vous pouvez les appliquer pendant que le rebasage est arrêté, ou plus tard.

## Autosquash {#autosquash}

Un commit peut se marquer lui-même comme correctif d’un commit antérieur : commencez son objet par `fixup!`, `squash!` ou `amend!`, suivi de l’objet du commit antérieur. La zone de commit [complète l’objet](/guide/work/commit/#autocomplete) pour vous.

Quand la liste affiche la branche sur laquelle vous êtes sans recherche, et que ses 1 000 derniers commits comprennent de tels commits, une bannière intitulée :ui[rewrite.autosquash] apparaît sous l’en-tête. Cliquez sur :ui[rewrite.autosquash.button] dans la bannière, et confirmez. Chaque commit marqué est fondu dans le commit qu’il désigne :

- `fixup!` garde le message du commit antérieur.
- `squash!` combine les deux messages.
- `amend!` remplace le message du commit antérieur par le sien.

Cliquez sur × pour masquer la bannière pour le moment.

## Quand la réécriture ne peut pas commencer {#errors}

Spooky vérifie les commits avant de réécrire quoi que ce soit. Si quelque chose ne va pas, il l’explique, et rien ne change :

| Message | Pourquoi |
|---|---|
| :ui[rewrite.error.notInHead] | Les commits doivent tous être dans l’historique de la branche sur laquelle vous êtes, sur une seule ligne. |
| :ui[rewrite.error.merges] | Un commit de fusion fait obstacle, et la réécriture l’aplatirait. Choisissez des commits postérieurs à la dernière fusion. |
| :ui[rewrite.error.root] | Le premier commit d’un dépôt n’a pas de parent auquel rendre ses modifications. |
| :ui[rewrite.error.selection] | La fusion de commits nécessite au moins deux commits, et la cible ne peut pas être l’un des commits à fondre. |
| :ui[rewrite.error.autosquash] | Aucun commit récent n’est marqué pour un commit antérieur. |
| :ui[rewrite.error.changed] | La branche a changé après que Spooky l’a lue. Actualisez l’historique et réessayez. |

## Modifications locales et conflits {#local-changes}

Le revert, le cherry-pick et le rebasage ont besoin d’une copie de travail qui ne fait pas obstacle. Quand vos modifications locales bloquent l’un d’eux, Spooky propose de [les remiser d’abord](/guide/work/stash/#auto-stash). La correction d’un commit plus ancien demande avant de commencer.

Si un commit entre en conflit en cours de route, Spooky s’arrête et affiche la [bannière de l’opération](/guide/work/conflicts/#banner). Résolvez les conflits, puis continuez ou abandonnez depuis celle-ci.

## Annuler une réécriture {#undo}

Choisissez :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>) pour annuler un revert, un cherry-pick, une réinitialisation ou une réécriture. Quand un rebasage est arrêté, par exemple pour modifier un commit, terminez-le ou abandonnez-le d’abord. Un rebasage ou un cherry-pick arrêté sur un conflit ne peut pas être annulé. Consultez [Annulation et récupération](/guide/work/undo/).

Les anciens commits restent aussi quelque temps dans le [reflog](/guide/work/undo/#reflog).

:::note[Dépôts sur un serveur]
Les commits sont réécrits sur le serveur. Chaque zone de dialogue qui réécrit l’historique nomme le serveur sur lequel elle s’exécute.
:::

## Voir aussi

- [Résoudre les conflits](/guide/work/conflicts/)
- [Annulation et récupération](/guide/work/undo/)
- [Fusionner et rebaser](/guide/branches/merge-rebase/)
