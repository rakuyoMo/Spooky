---
title: "Annulation et récupération"
description: "Découvrez ce que ⌘Z peut annuler et pourquoi certaines opérations ne peuvent pas l’être, et récupérez des commits perdus avec le reflog."
---

La plupart des choses que vous faites à un dépôt dans Spooky peuvent être annulées avec <kbd>⌘Z</kbd>. Pour le reste, le reflog de Git se souvient des endroits où vos branches sont passées, donc un commit est rarement perdu pour de bon.

## Annuler et rétablir {#undo}

Choisissez :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>) pour annuler la dernière opération. L’élément de menu comprend le nom de l’opération. Choisissez :ui[menu.edit > menu.redo] (<kbd>⇧⌘Z</kbd>) pour la refaire. Vous pouvez remonter plusieurs opérations, de la plus récente à la plus ancienne.

Vous pouvez annuler, par exemple :

- L’indexation, la validation et la correction d’un commit
- L’abandon de modifications et la mise de fichiers à la Corbeille
- La création, l’application et la suppression de remisages
- L’extraction d’une branche, la création, le renommage et la suppression de branches, et la création de tags
- L’épinglage et l’archivage de branches, la définition de la branche amont et l’avance rapide
- La fusion, le rebasage, le cherry-pick, le revert et la réinitialisation
- L’ajout, le renommage et la suppression de dépôts distants, et la modification de leurs réglages
- La publication de branches et de tags, et le renommage de branches distantes
- Le marquage de fichiers comme assume-unchanged, l’activation de Git LFS et la modification de sous-modules

Les fichiers partis à la Corbeille en sont ressortis. Si vous annulez une réinitialisation alors que des fichiers suivis ont des modifications, Spooky demande d’abord s’il faut les remiser. Le nouveau remisage reste dans la liste.

Pendant que vous saisissez dans un champ de texte, comme le message de commit, <kbd>⌘Z</kbd> annule plutôt votre saisie.

Chaque dépôt a un seul historique d’annulation, partagé par toutes ses fenêtres. Spooky le conserve jusqu’à ce que vous quittiez l’app. Les instantanés dont il a besoin sont stockés dans la base de données Git du dépôt, et ne sont poussés nulle part.

:::note[Dépôts sur un serveur]
Les instantanés sont stockés dans le dépôt sur le serveur. Les fichiers partis dans la Corbeille du serveur en sont ressortis.
:::

## Ce qui ne peut pas être annulé {#cant-undo}

L’annulation remet le dépôt dans l’état où il était. Certains changements sortent de ce que Spooky peut restaurer :

- La suppression de branches et de tags sur un dépôt distant. La suppression d’une branche locale avec sa branche distante fait exception : l’annulation recrée les deux.
- La modification de l’identité du validateur, des règles d’exclusion ou d’autres réglages Git.
- Tout ce que vous faites pendant une fusion, un rebasage ou une autre opération en cours, y compris la continuer ou l’abandonner.
- Un rebasage ou un cherry-pick qui s’arrête sur un conflit. Une fusion ou un revert qui s’arrête sur des conflits peut être annulé, ce qui l’abandonne.
- Les nouveaux fichiers supprimés définitivement, par exemple sur un serveur sans Corbeille.
- L’initialisation, la synchronisation et la réparation de sous-modules ; tout ce que vous faites avec les worktrees ; la mise à jour des crochets Git LFS ; et la publication d’un dépôt sur un service d’hébergement. Consultez [Sous-modules](/guide/advanced/submodules/#undo), [Worktrees](/guide/advanced/worktrees/#undo), [Git LFS](/guide/advanced/lfs/#undo) et [Publier un dépôt](/guide/hosting/accounts/#publish).

Après l’une de ces opérations, l’élément de menu indique qu’elle ne peut pas être annulée. Les opérations qui la précèdent ne peuvent plus l’être non plus.

Récupérer, tirer, pousser et synchroniser ne sont pas enregistrés. Ils ne peuvent pas être annulés. Il en va de même pour la récupération et la mise à jour des sous-modules, et pour la récupération, le tirage et la poussée de contenu LFS.

## Quand l’annulation est bloquée {#blocked}

L’annulation ne fonctionne que tant que le dépôt est encore dans l’état où l’opération l’a laissé. Quand ce n’est pas le cas, l’élément de menu est estompé et donne une raison entre parenthèses :

| Raison | Que faire |
|---|---|
| :ui[undo.reason.busy] | Attendez la fin de l’opération en cours d’exécution, ou terminez la fusion, le rebasage ou l’autre opération en cours. |
| :ui[undo.reason.disconnected] | Reconnectez-vous au serveur. |
| :ui[undo.reason.changed] | Le dépôt a changé depuis l’opération : un tirage ou une synchronisation a apporté des commits, ou Terminal ou une autre app l’a modifié. Remettez-le en état, et l’annulation fonctionne à nouveau. |

Spooky vérifie le dépôt une dernière fois juste avant d’annuler quoi que ce soit. Si quelque chose fait obstacle, il s’arrête et vous dit pourquoi. Rien n’est modifié.

| Message | Pourquoi |
|---|---|
| :ui[undo.error.changed] | Le dépôt ne correspond plus à ce que Spooky a enregistré. |
| :ui[undo.error.untracked] | La restauration écraserait ou supprimerait des fichiers non suivis. |
| :ui[undo.error.hidden] | Des fichiers marqués assume-unchanged ont des modifications locales, ou le dépôt utilise skip-worktree. |
| :ui[undo.error.inProgress] | Terminez ou abandonnez d’abord la fusion, le rebasage, le cherry-pick ou le revert. |
| :ui[undo.error.conflicts] | Résolvez d’abord les conflits. Consultez [Résoudre les conflits](/guide/work/conflicts/). |
| :ui[undo.error.trash] | Certains fichiers ne sont plus dans la Corbeille, ou d’autres fichiers occupent maintenant leur emplacement. |

## Récupérer des commits avec le reflog {#reflog}

Git tient un journal des endroits vers lesquels HEAD et chaque branche locale ont pointé. Un commit perdu à la suite d’une réinitialisation, d’un rebasage ou de la suppression d’une branche y figure généralement encore. Les modifications que vous n’avez jamais validées n’y sont pas.

1. Choisissez :ui[menu.view > reflog.show] (<kbd>⌘6</kbd>).
2. Dans :ui[reflog.ref], en haut, choisissez HEAD ou une branche locale.
3. Trouvez l’entrée. Chacune affiche le hash court, ce qui s’est passé et quand, avec la description de Git en dessous. Pour filtrer la liste, saisissez du texte dans le champ de recherche de la barre d’outils.
4. Sélectionnez l’entrée pour voir les détails du commit.

::screenshot[La vue Reflog pour HEAD. Chaque entrée affiche un hash court, une action comme commit, checkout ou reset, et une date, avec le message en dessous. Les détails du commit de l’entrée sélectionnée sont à droite.]{name="work-reflog" frame="window" markers="33.5,9 44.1,37.1 84.4,21.3"}

1. Le menu :ui[reflog.ref]
2. L’entrée sélectionnée
3. Les détails du commit

Cliquez sur l’entrée avec le bouton droit pour récupérer le commit :

- :ui[reflog.createBranch]{1="9e0d36a7"} démarre une nouvelle branche à cet endroit. Vos branches actuelles restent telles quelles.
- :ui[reflog.restore]{1="feature/units-toggle" 2="9e0d36a7"} ramène la branche affichée à ce commit. La copie de travail et l’index ne changent pas. Spooky demande d’abord confirmation, et vous pouvez annuler.
- :ui[reflog.cherryPick]{1="9e0d36a7"} copie le commit sur la branche actuelle. Vous pouvez aussi faire glisser l’entrée sur :ui[workspace.title] ou sur la branche actuelle dans la barre latérale.
- :ui[reflog.reset]{1="9e0d36a7"} ouvre la zone de dialogue de réinitialisation, pour déplacer la branche actuelle vers ce commit.
- :ui[patch.menu]{1="9e0d36a7"} enregistre le commit dans un fichier patch.

Pour avoir :ui[reflog.title] dans la barre latérale, activez :ui[sidebar.showReflog] dans :ui[sidebar.viewSettings].

:::caution
Git supprime les anciennes entrées du reflog avec le temps. Par défaut, les entrées sont conservées 90 jours, et 30 jours quand leur commit n’est plus sur la branche. Récupérez vite les commits perdus.
:::

:::note[Dépôts sur un serveur]
Le reflog se trouve dans le dépôt sur le serveur. C’est là que Spooky le lit.
:::

## Voir aussi

- [Valider des modifications](/guide/work/commit/)
- [Résoudre les conflits](/guide/work/conflicts/)
- [Réécrire l’historique](/guide/history/rewrite/)
