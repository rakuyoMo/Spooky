---
title: "Remisages"
description: "Créez, appliquez et examinez des remisages, et utilisez le remisage automatique."
---

Un remisage met vos modifications locales de côté sans les valider. Utilisez-le quand il vous faut une copie de travail propre pour un moment, par exemple pour changer de branche ou tirer, et que vous voulez retrouver vos modifications ensuite.

Les remisages appartiennent au dépôt. Ils ne sont pas poussés vers le dépôt distant.

## Créer un remisage {#save}

1. Choisissez :ui[workspace.title > stash.saveMenu] (<kbd>⇧⌘S</kbd>), ou cliquez sur :ui[toolbar.saveStash] dans la barre d’outils.
2. Si vous le souhaitez, décrivez les modifications dans :ui[stash.message] pour retrouver le remisage plus tard.
3. Pour mettre aussi de côté les nouveaux fichiers, cochez :ui[stash.includeUntracked]. Spooky retient ce choix.
4. Cliquez sur :ui[stash.save].

Toutes vos modifications vont dans le remisage, et la copie de travail est à nouveau propre. S’il n’y a rien à remiser, Spooky indique :ui[stash.error.noChanges]. Les nouveaux fichiers ne comptent que si :ui[stash.includeUntracked] est coché.

Pour enregistrer une copie de vos modifications tout en continuant à y travailler, choisissez plutôt :ui[workspace.title > stash.snapshotMenu] (<kbd>⌃⇧⌘S</kbd>). La zone de dialogue est la même, et la copie de travail reste telle quelle.

## Remiser certains fichiers {#partial}

Pour ne mettre de côté que certains fichiers, sélectionnez-les dans la copie de travail, cliquez avec le bouton droit et choisissez :ui[stash.stashFile]{1="README.md"} ou :ui[stash.stashItems]{1="3"} dans le menu. Les éléments d’instantané situés en dessous laissent les fichiers tels quels.

Vous pouvez aussi faire glisser les fichiers sur :ui[stash.title] dans la barre latérale.

Les nouveaux fichiers que vous avez sélectionnés vont toujours dans le remisage, que :ui[stash.includeUntracked] soit coché ou non.

:::tip
Maintenez <kbd>⌥</kbd> enfoncée pendant que le menu est ouvert, et les éléments deviennent des versions rapides comme :ui[stash.quickStashFile]{1="README.md"}. Elles remisent aussitôt, sans la zone de dialogue, avec un message écrit par Git.
:::

## Afficher les remisages {#view}

Cliquez sur :ui[stash.title] dans la barre latérale, ou choisissez :ui[menu.view > stash.show] (<kbd>⌘3</kbd>).

La liste de gauche affiche le remisage le plus récent en premier. Chaque ligne affiche :ui[stash.basedOn] avec la branche depuis laquelle le remisage a été créé, la date et le message. Pour filtrer la liste, saisissez du texte dans le champ de recherche de la barre d’outils.

::screenshot[La vue des remisages. La liste de gauche affiche trois remisages, et Halfway through the units toggle est sélectionné. Ses détails sont à droite, avec les boutons Appliquer, Supprimer et Comparer affichés sous les informations du commit.]{name="work-stashes" frame="window" markers="33,36 86.5,35.5"}

1. La liste des remisages
2. :ui[stash.applyButton], :ui[stash.deleteButton] et :ui[history.diffTool]

Sélectionnez un remisage pour voir ses modifications à droite, présentées comme les détails d’un commit. Placez le pointeur sur les détails pour afficher les boutons :ui[stash.applyButton], :ui[stash.deleteButton] et :ui[history.diffTool]. :ui[history.diffTool] ouvre le remisage dans une app de comparaison.

## Appliquer un remisage {#apply}

L’application ramène les modifications d’un remisage dans la copie de travail.

1. Choisissez :ui[workspace.title > stash.applyMenu] (<kbd>⌥⇧⌘S</kbd>), ou cliquez sur :ui[toolbar.applyStash] dans la barre d’outils. Vous pouvez aussi faire glisser un remisage sur :ui[workspace.title] ou sur la branche actuelle dans la barre latérale.
2. Choisissez le remisage dans :ui[stash.picker]. Dans la vue des remisages, le remisage sélectionné est déjà choisi.
3. Réglez les options :
   - :ui[stash.deleteAfterApply] supprime le remisage une fois ses modifications revenues.
   - :ui[stash.restoreIndex] indexe à nouveau ce qui était indexé quand vous avez créé le remisage.
4. Cliquez sur :ui[stash.apply].

Spooky retient les deux options pour la prochaine fois.

Si les modifications entrent en collision avec ce qui se trouve maintenant dans la copie de travail, Spooky signale :ui[stash.error.conflicts]. Le remisage est conservé, même si :ui[stash.deleteAfterApply] est coché. Résolvez les conflits comme décrit dans [Résoudre les conflits](/guide/work/conflicts/).

Pour ne ramener qu’un seul fichier, ouvrez le remisage et faites glisser le fichier depuis ses détails sur :ui[workspace.title] dans la barre latérale.

## Supprimer des remisages {#delete}

Dans la vue des remisages, cliquez sur un remisage avec le bouton droit et choisissez :ui[stash.deleteNamed]{1="Halfway through the units toggle"} dans le menu. Si plusieurs remisages sont sélectionnés, l’élément est :ui[stash.deleteMultiple]{1="2"}. Vous pouvez aussi appuyer sur <kbd>⌘⌫</kbd>.

Spooky demande toujours confirmation. Pour récupérer un remisage après l’avoir supprimé, choisissez :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

## Remisage automatique {#auto-stash}

Certaines opérations ne peuvent pas s’exécuter tant que vous avez des modifications locales, comme changer de branche, tirer ou fusionner. Quand l’une d’elles est bloquée, Spooky demande s’il faut d’abord remiser vos modifications.

::screenshot[Une zone de dialogue qui demande s’il faut remiser les modifications locales qui bloquent l’opération. Elle comporte un champ pour un message facultatif, une case Réappliquer les modifications une fois l’opération terminée, et les boutons Interrompre, Ne pas remiser et Remiser les modifications.]{name="work-auto-stash" frame="dialog"}

- :ui[stash.autoStash.confirm] remise les modifications et exécute l’opération.
- :ui[stash.autoStash.skip] exécute l’opération sans remiser. Si vos modifications la bloquent toujours, elle échoue comme elle l’aurait fait.
- :ui[stash.autoStash.abort] annule l’opération.

Cochez :ui[stash.autoStash.reapply] pour retrouver les modifications dès que l’opération est terminée. Sinon, le remisage reste dans la liste, et vous pouvez l’appliquer vous-même plus tard. Spooky retient ce choix.

Quand vous changez de branche avec des modifications dans des fichiers suivis, Spooky demande avant de commencer, même si les modifications ne gêneraient pas.

Si quelque chose se passe mal en cours de route, vos modifications restent dans le remisage, et Spooky vous dit ce qui s’est passé.

Pour ne plus recevoir la question, désactivez :ui[stash.offerAutoStash] dans :ui[app.name > settings.title] › :ui[settings.general]. Consultez [Opérations](/guide/settings/general/#operations).

## Voir aussi

- [Copie de travail](/guide/work/working-copy/)
- [Résoudre les conflits](/guide/work/conflicts/)
- [Branches](/guide/branches/branches/)
