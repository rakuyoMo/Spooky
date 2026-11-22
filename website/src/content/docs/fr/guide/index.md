---
title: "Guide de l’utilisateur"
description: "Découvrez comment ce guide est organisé et par où commencer."
---

Ce guide montre comment faire le travail Git de tous les jours dans Spooky. Il couvre les dépôts sur votre Mac et ceux qui restent sur une autre machine, accessible via SSH. Chaque page traite un domaine et commence par ce qu’elle vous aide à faire.

Si vous découvrez Spooky, lisez les pages Premiers pas dans l’ordre. Si vos dépôts se trouvent sur un serveur, lisez ensuite Dépôts sur un serveur.

Dans Spooky, :ui[menu.help > help.help] (<kbd>⌘?</kbd>) ouvre ce site web. Beaucoup de zones de dialogue ont aussi un bouton d’aide. Il ouvre la partie de ce guide consacrée à cette zone de dialogue.

## Organisation du guide {#organization}

| Groupe | Ce qu’il couvre |
|---|---|
| [Premiers pas](/guide/start/install/) | L’installation et la mise à jour de Spooky, les parties de ses fenêtres, un premier commit et une première poussée |
| [Dépôts](/guide/repositories/manager/) | La liste de vos dépôts, les fenêtres et les onglets, la navigation en arrière et en avant, les Actions rapides |
| [Dépôts sur un serveur](/guide/server/overview/) | La façon dont Spooky travaille avec les dépôts sur un serveur, la préparation de SSH, l’ajout d’un dépôt sur un serveur, la connexion et l’emplacement sur ce Mac |
| [Travail quotidien](/guide/work/working-copy/) | La copie de travail, l’examen et l’indexation des modifications, la validation, les remisages, les conflits et l’annulation |
| [Historique](/guide/history/browse/) | Le parcours de l’historique, les détails d’un commit, l’historique d’un fichier et le blame, la réécriture de l’historique |
| [Branches et synchronisation](/guide/branches/branches/) | Les branches, les tags et les dépôts distants, la récupération, le tirage et la poussée, la fusion et le rebasage, le nettoyage des branches |
| [Collaboration](/guide/hosting/accounts/) | Les comptes d’hébergement, les pull requests et les merge requests |
| [Autres fonctions de Git](/guide/advanced/submodules/) | Les sous-modules, les worktrees, Git LFS et la file d’attente des opérations |
| [Réglages et intégration](/guide/settings/general/) | Les réglages, l’apparence et les thèmes, les profils utilisateur et la configuration Git, le travail avec d’autres apps |
| [Référence](/reference/shortcuts/) | Les raccourcis clavier, la configuration requise, les données et la confidentialité, le dépannage |

## Conventions {#conventions}

### Noms à l’écran {#names}

Les noms des boutons, des menus, des options et des fenêtres sont en gras, comme :ui[working.commit]. Ils viennent directement de Spooky. Quand Spooky s’affiche dans la langue de cette page, vous voyez les mêmes noms à l’écran.

Un chemin de menu comme :ui[menu.file > action.openLocal] signifie : cliquez sur le premier nom dans la barre des menus, puis choisissez le suivant dans ce menu.

Certaines pages nomment aussi des éléments de macOS, comme **Réglages Système**. Ils sont écrits tels que macOS les affiche.

### Raccourcis clavier {#shortcuts}

Les raccourcis ressemblent à des touches, comme <kbd>⇧⌘A</kbd>. Maintenez les touches de modification enfoncées, puis appuyez sur la dernière touche. Les symboles sont ceux que macOS affiche dans ses menus.

| Symbole | Touche |
|---|---|
| <kbd>⌘</kbd> | Commande |
| <kbd>⇧</kbd> | Majuscule |
| <kbd>⌥</kbd> | Option |
| <kbd>⌃</kbd> | Contrôle |
| <kbd>↩</kbd> | Retour |
| <kbd>⌫</kbd> | Suppr |

Tous les raccourcis sont listés dans [Raccourcis clavier](/reference/shortcuts/).

### Notes sur les dépôts sur un serveur {#server-notes}

Un dépôt sur un serveur reste sur une autre machine, et Spooky l’ouvre via SSH. La plupart des tâches s’y font de la même façon. Quand quelque chose diffère, la page le signale dans une note comme celle-ci :

:::note[Dépôts sur un serveur]
Une note portant ce titre vous indique ce qui change dans un dépôt sur un serveur. Si vous n’utilisez que des dépôts sur votre Mac, vous pouvez ignorer ces notes.
:::

## Voir aussi

- [Installer Spooky](/guide/start/install/)
- [Découvrir Spooky](/guide/start/tour/)
- [Fonctionnement des dépôts sur un serveur](/guide/server/overview/)
