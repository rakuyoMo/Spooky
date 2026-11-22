---
title: "Intégration"
description: "Choisissez les outils externes de comparaison et de fusion, les éditeurs et les terminaux, et configurez l’intégration au Finder."
---

Spooky travaille avec d’autres apps de votre Mac : votre navigateur, les apps de comparaison et de fusion, les éditeurs, un terminal et le Finder. Cette page montre où chacune se configure.

## La page Intégration {#integration-page}

:ui[app.name > settings.title] › :ui[settings.integration] comporte trois réglages.

### Liens depuis github.com {#github-links}

Sur github.com, le bouton qui ouvre un dépôt dans une app de bureau envoie un lien à votre Mac. :ui[settings.github] décide quelle app le reçoit. Le menu liste les apps de votre Mac qui peuvent ouvrir ces liens.

Choisissez Spooky, et ces liens ouvrent la zone de dialogue de clonage. Consultez [Cloner un dépôt](/guide/repositories/navigation/#link-clone).

### Agent SSH {#ssh-agent}

Un agent SSH garde des clés déverrouillées à disposition. Spooky s’en sert pour se connecter aux serveurs et aux dépôts distants via SSH, et pour signer les commits avec des clés SSH.

:ui[settings.sshAgent] propose un seul choix, :ui[settings.sshAgent.system]. Spooky le trouve dans cet ordre :

1. `SSH_AUTH_SOCK` parmi vos propres variables sur la page :ui[settings.environment] (consultez [Variables sur ce Mac](/guide/settings/general/#local-variables))
2. `SSH_AUTH_SOCK` de votre shell de connexion, si sa lecture y est activée
3. L’agent que macOS lance pour vous

Pour utiliser un autre agent, comme celui d’un gestionnaire de mots de passe, définissez `SSH_AUTH_SOCK` sur la page :ui[settings.environment] ou dans votre shell de connexion.

Si l’agent ne tourne pas, un bouton d’avertissement jaune apparaît à côté du menu. Cliquez dessus pour voir quoi faire.

:::note[Dépôts sur un serveur]
Spooky ne transfère jamais votre agent à un serveur. Le Git du serveur utilise l’agent et les clés de cette machine.
:::

### Rapports de plantage {#crash-reports}

Si Spooky a quitté de façon inattendue la dernière fois, il demande au lancement suivant s’il faut signaler le plantage. Sélectionnez :ui[settings.crashReports.always] pour passer la question et ouvrir tout de suite la page de signalement. Désactivé au départ.

Consultez [Rapports de plantage](/reference/data-privacy/#crash-reports) pour le contenu du rapport.

## Outils de comparaison et de fusion {#diff-merge-tools}

Les outils se règlent sur la page :ui[settings.gitConfig].

| Réglage | Ce qu’il fait |
|---|---|
| :ui[externalTool.diffTool] | L’app qui compare les fichiers. :ui[externalTool.noneSelected] au départ. |
| :ui[externalTool.directoryDiff] | Quand vous comparez plusieurs fichiers, les ouvre sous forme de deux dossiers dans une seule fenêtre. Seul Kaleidoscope le permet. Les autres apps ouvrent un fichier à la fois. Activé au départ. |
| :ui[externalTool.mergeTool] | L’app qui résout les conflits. :ui[externalTool.noneSelected] au départ. |
| :ui[externalTool.keepBackups] | Garde le fichier tel qu’il était avant la fusion, à côté de lui, avec `.orig` à la fin. Désactivé au départ. |

Spooky fonctionne avec ces apps :

| App | Comparaison | Fusion |
|---|---|---|
| Araxis Merge | Oui | Oui |
| BBEdit | Oui | Non |
| Beyond Compare | Oui | Oui |
| DeltaWalker | Oui | Oui |
| FileMerge | Oui | Oui |
| Kaleidoscope | Oui | Oui |
| P4Merge | Oui | Oui |
| TextMate | Oui | Non |
| Visual Studio Code | Oui | Oui |

Les menus listent aussi les apps qui ne sont pas installées, mais vous ne pouvez pas les choisir. Si vous utilisez un outil avant d’en avoir choisi un, Spooky demande quelle app utiliser.

Pour les utiliser, consultez [Comparer dans une autre app](/guide/work/diff/#external) et [Fusionner dans une autre app](/guide/work/conflicts/#merge-tool).

## Éditeurs {#editors}

Spooky n’a pas de réglage d’éditeur à lui. Pour ouvrir un fichier dans une autre app, cliquez dessus avec le bouton droit dans la copie de travail et choisissez :ui[files.open] ou :ui[files.openWith]. Le sous-menu :ui[files.openWith] liste les apps qui peuvent ouvrir le fichier, l’app par défaut en premier. Le même sous-menu se trouve dans l’arborescence des fichiers d’un commit et dans l’assistant de conflits.

Dans un dépôt sur un serveur, Visual Studio Code, Visual Studio Code Insiders et Cursor ouvrent le fichier directement sur le serveur, si leur extension Remote SSH est installée. Les autres apps reçoivent une copie. Quand vous enregistrez, Spooky réécrit vos modifications sur le serveur. Consultez [Terminal et autres apps](/guide/server/local-location/#terminal).

## Terminal {#terminal}

:ui[settings.terminal], sur la page :ui[settings.general], choisit l’app utilisée par :ui[action.openTerminal]. Spooky fonctionne avec Terminal, iTerm, Warp, Ghostty, WezTerm et Otty. Le menu liste celles qui sont installées. Terminal est utilisé au départ.

Vous trouverez :ui[action.openTerminal] à ces endroits :

- Le menu :ui[menu.file]
- :ui[toolbar.terminal] dans la barre d’outils
- Le menu de la copie de travail dans la barre latérale
- Le menu d’un fichier ou d’un dossier dans la liste de fichiers de la copie de travail. Le terminal s’ouvre dans ce dossier, ou dans le dossier où se trouve le fichier.
- Les menus des dépôts dans la fenêtre Dépôts et ceux des clones récents
- Le menu d’un worktree dans la barre latérale
- Les [Actions rapides](/guide/repositories/navigation/#quick-actions)

Pour un dépôt local, le terminal s’ouvre dans le dossier sur ce Mac. Pour un dépôt sur un serveur, il ouvre une session avec SSH et se place dans le dossier sur le serveur. Consultez [Terminal et autres apps](/guide/server/local-location/#terminal).

La première fois que Spooky ouvre Terminal ou iTerm, macOS demande si Spooky peut le contrôler. Si vous refusez, Spooky affiche :ui[error.terminal]. Pour l’autoriser plus tard, accédez à **menu Pomme › Réglages Système › Confidentialité et sécurité › Automatisation**, et activez l’app sous Spooky.

## Finder {#finder}

- **Afficher un dossier** : :ui[action.revealFinder] affiche le dossier du dépôt ou un fichier dans le Finder. Pour un dépôt sur un serveur, il faut un emplacement sur ce Mac. Consultez [Afficher dans le Finder](/guide/server/local-location/#show-in-finder).
- **Ajouter des dépôts** : faites glisser des dossiers de dépôt du Finder vers la fenêtre Dépôts. Consultez [Ajouter des dépôts](/guide/repositories/manager/#add).
- **Le Dock** : déposez un dossier sur l’icône de Spooky pour ouvrir le dépôt dont il fait partie. Cliquez sur l’icône avec le bouton droit pour choisir un dépôt récent, dépôts sur un serveur compris. Consultez [Dépôts récents et Dock](/guide/repositories/navigation/#recent).
- **Thèmes** : ouvrez un fichier `.spookytheme` dans le Finder pour ajouter le thème. Consultez [Partager des thèmes](/guide/settings/appearance/#share-themes).

## Voir aussi

- [Général, mises à jour et environnement](/guide/settings/general/)
- [Profils utilisateur et configuration Git](/guide/settings/identity/)
- [Emplacement sur ce Mac](/guide/server/local-location/)
- [Préparer SSH](/guide/server/prepare-ssh/)
