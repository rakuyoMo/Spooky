---
title: "Worktrees"
description: "Extrayez des branches dans des worktrees supplémentaires, et ouvrez, déplacez, réparez et supprimez ces worktrees."
---

Un worktree est un autre dossier extrait du même dépôt. Chaque worktree a sa propre branche extraite et sa propre copie de travail. Ils partagent tous les commits et les branches du dépôt. Vous pouvez ainsi travailler sur une deuxième branche sans remiser ni changer de branche dans le premier dossier.

Une branche ne peut être extraite que dans un seul worktree à la fois.

## Dans la barre latérale {#sidebar}

Les worktrees sont listés sous :ui[worktree.group] dans la barre latérale, triés par nom. Le nom est la dernière partie du chemin du worktree. Le worktree ouvert dans la fenêtre n’est pas listé. Placez le pointeur sur l’un d’eux pour voir où il est extrait.

Cliquez sur un worktree pour voir son nom, son chemin, sa révision actuelle et sa branche. Double-cliquez dessus pour l’ouvrir dans la même fenêtre.

Une branche extraite dans un autre worktree a une petite pastille sur son icône. Quand vous cliquez dessus avec le bouton droit, le menu indique dans quel worktree elle se trouve. Il propose aussi d’ouvrir ou de supprimer ce worktree. Consultez [Basculer sur une branche](/guide/branches/branches/#checkout).

Pour lister aussi les worktrees dans la fenêtre Dépôts, consultez [Organiser la liste](/guide/repositories/manager/#organize).

## Ajouter un worktree {#add}

Commencez de l’une de ces façons :

- Choisissez :ui[menu.repository > menu.addWorktree] dans la barre des menus.
- Cliquez sur le bouton d’ajout en bas de la barre latérale, ou cliquez avec le bouton droit sur :ui[worktree.group], et choisissez :ui[worktree.add.menu] dans le menu.
- Cliquez avec le bouton droit sur une branche locale et choisissez :ui[worktree.checkoutBranch]{1="feature/units-toggle"} dans le menu.
- Faites glisser une branche locale sur :ui[worktree.group].

Dans la zone de dialogue :

1. À côté de :ui[worktree.revision], choisissez ou saisissez la branche ou la révision à extraire. Si vous êtes parti d’une branche, elle est déjà renseignée.
2. À côté de :ui[worktree.destination], saisissez le chemin complet du nouveau dossier. Le bouton :ui[submodule.path.select] commence à côté du dossier du dépôt. Il suggère un nom composé du nom du dépôt et de la révision. Le dossier ne doit pas encore exister, ou doit être vide.
3. Cochez :ui[worktree.detach] pour extraire une HEAD détachée à cette révision. Le worktree n’occupe alors aucune branche.
4. Cliquez sur :ui[worktree.add.submit].

Si la branche est déjà extraite dans un worktree, la zone de dialogue le signale. Cochez :ui[worktree.detach], ou :ui[worktree.force] sous :ui[dialog.options], pour créer le worktree quand même.

Le dépôt doit avoir au moins un commit. Une fois le worktree créé, la fenêtre reste sur le dépôt que vous aviez ouvert. Le nouveau worktree apparaît dans la barre latérale.

## Ouvrir un worktree {#open}

Un worktree s’ouvre comme n’importe quel autre dépôt. Cliquez dessus avec le bouton droit dans la barre latérale et choisissez dans le menu :

- :ui[worktree.open.current], :ui[worktree.open.newTab] ou :ui[worktree.open.newWindow]
- :ui[worktree.reveal], :ui[action.copyPath] ou :ui[action.openTerminal]

## Déplacer un worktree {#move}

Cliquez sur un worktree avec le bouton droit et choisissez :ui[worktree.move.menu] dans le menu. Saisissez le nouveau chemin, ou cliquez sur le bouton :ui[submodule.path.select]. Les modifications du worktree le suivent.

## Supprimer un worktree {#remove}

Cliquez sur un worktree avec le bouton droit et choisissez :ui[worktree.remove.menu] dans le menu. Cela supprime le dossier du worktree. La branche qui y était extraite reste dans le dépôt.

Si le worktree contient des modifications ou des fichiers non suivis, Git refuse de le supprimer. Cochez :ui[worktree.remove.force] pour le supprimer avec eux.

Le worktree principal du dépôt, le dossier qui contient son répertoire `.git`, ne peut être ni déplacé ni supprimé. Il figure dans la liste quand vous avez un autre worktree ouvert.

## Réparer un worktree {#repair}

Si le dossier d’un worktree est déplacé ou supprimé en dehors de Spooky, le worktree cesse de fonctionner. Il reçoit une icône d’avertissement dans la barre latérale. Vous ne pouvez pas l’ouvrir. Ses détails indiquent :ui[worktree.invalid], avec la raison donnée par Git, et deux boutons :

- :ui[worktree.invalid.repair] : si vous avez déplacé le dossier, choisissez :ui[submodule.path.select] dans le menu :ui[worktree.location], et retrouvez l’endroit où le dossier se trouve maintenant. Spooky vérifie que le dossier est bien ce worktree de ce dépôt. Cliquez ensuite sur :ui[worktree.relocate.submit].
- :ui[worktree.invalid.remove] : si le dossier a disparu, ce bouton retire du dépôt ce qui reste du worktree.

Vous trouverez aussi les deux dans le menu contextuel du worktree.

## Annuler {#undo}

L’ajout, le déplacement, la suppression et la réparation de worktrees ne peuvent pas être annulés avec <kbd>⌘Z</kbd>. Après l’une de ces opérations, celles qui la précèdent ne peuvent plus l’être non plus. Consultez [Annulation et récupération](/guide/work/undo/).

:::note[Dépôts sur un serveur]
Les worktrees sont créés sur le serveur. Leurs chemins sont des chemins sur le serveur. :ui[submodule.path.select] parcourt les dossiers du serveur.

:ui[worktree.reveal] est disponible quand Spooky peut trouver le dossier du worktree sur votre Mac. Si le worktree est dans le dossier du dépôt, Spooky le trouve grâce à l’emplacement du dépôt. Sinon, il cherche parmi les volumes montés sur votre Mac. Consultez [Emplacement sur ce Mac](/guide/server/local-location/).
:::

## Voir aussi

- [Branches](/guide/branches/branches/)
- [Sous-modules](/guide/advanced/submodules/)
- [La fenêtre Dépôts](/guide/repositories/manager/)
