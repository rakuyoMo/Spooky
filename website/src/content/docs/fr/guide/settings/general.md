---
title: "Général, mises à jour et environnement"
description: "Repérez-vous dans la fenêtre Réglages et définissez les options des pages Général, Mises à jour et Environnement."
---

Les réglages s’appliquent à Spooky dans son ensemble. La plupart prennent effet dès que vous les modifiez. Il n’y a pas de bouton Enregistrer.

## La fenêtre Réglages {#window}

Choisissez :ui[app.name > settings.title] (<kbd>⌘,</kbd>). Les pages sont alignées en haut de la fenêtre, et le titre indique la page où vous êtes.

| Page | Ce qu’elle règle | Décrite dans |
|---|---|---|
| :ui[settings.general] | Le clonage, les opérations en arrière-plan, les confirmations, l’historique, la liste de fichiers et les fenêtres | [Général](#general) |
| :ui[settings.appearance] | Clair ou sombre, et l’icône de l’app | [Apparence et thèmes](/guide/settings/appearance/#appearance) |
| :ui[settings.gitConfig] | Le binaire Git, votre identité Git globale, la signature, et les outils externes de comparaison et de fusion | [Profils utilisateur et configuration Git](/guide/settings/identity/#git-config) |
| :ui[settings.text] | La coloration syntaxique, les caractères invisibles et la largeur des tabulations dans les diffs et les fichiers | [Apparence et thèmes](/guide/settings/appearance/#text) |
| :ui[settings.editor] | La vérification et le retour à la ligne du message de commit | [Apparence et thèmes](/guide/settings/appearance/#editor) |
| :ui[settings.themes] | Les couleurs et la police des diffs et des fichiers | [Apparence et thèmes](/guide/settings/appearance/#themes) |
| :ui[settings.profiles] | Les identités entre lesquelles vous pouvez alterner quand vous validez | [Profils utilisateur et configuration Git](/guide/settings/identity/#profiles) |
| :ui[settings.accounts] | Les comptes GitHub et GitLab | [Comptes d’hébergement](/guide/hosting/accounts/) |
| :ui[settings.sshHosts] | Les alias d’hôte de vos serveurs, enregistrés dans `~/.ssh/config` | [Préparer SSH](/guide/server/prepare-ssh/#alias) |
| :ui[settings.integration] | Les liens depuis github.com, l’agent SSH et les rapports de plantage | [Intégration](/guide/settings/integration/#integration-page) |
| :ui[settings.environment] | Les variables d’environnement du Git de ce Mac, et une vérification de l’environnement d’un serveur | [Environnement](#environment) |
| :ui[settings.updates] | La façon dont Spooky se met à jour | [Mises à jour](#updates) |

Les réglages propres à un seul dépôt, comme son identité et sa signature, se trouvent plutôt dans la fenêtre du dépôt. Consultez [Réglages du dépôt](/guide/settings/identity/#repository).

## Général {#general}

La page :ui[settings.general] est une longue liste. Les sections ci-dessous la suivent de haut en bas.

::screenshot[La page Général de la fenêtre Réglages, avec l’emplacement des clones, l’app de terminal, les options d’opérations et de confirmation, les options d’historique et de diff, et les options de la liste de fichiers.]{name="settings-general" frame="window"}

### Clonage et terminal {#cloning}

| Réglage | Ce qu’il fait |
|---|---|
| :ui[settings.cloneDirectory] | L’endroit où la zone de dialogue de clonage propose de placer les nouveaux dépôts. Au départ, c’est votre dossier de départ. Le menu propose aussi `~/Development` si vous en avez un. Choisissez :ui[settings.cloneDirectory.select] pour choisir un autre dossier. |
| :ui[settings.terminal] | L’app qu’utilise :ui[action.openTerminal]. Consultez [Terminal](/guide/settings/integration/#terminal). |

### Opérations {#operations}

| Réglage | Par défaut | Ce qu’il fait |
|---|---|---|
| :ui[settings.autoFetch] | Toutes les 30 minutes | La fréquence à laquelle Spooky récupère en arrière-plan. Consultez [Récupérer automatiquement](/guide/branches/sync/#auto-fetch). |
| :ui[stash.offerAutoStash] | Activé | Quand des modifications locales bloquent une opération, demande s’il faut d’abord les remiser. Consultez [Remisage automatique](/guide/work/stash/#auto-stash). |
| :ui[settings.autoUpdateSubmodules] | Désactivé | Met à jour les sous-modules extraits après les opérations qui déplacent leurs pointeurs, sans rien demander. Consultez [Mettre à jour après d’autres opérations](/guide/advanced/submodules/#auto-update). |
| :ui[branch.cleanNames] | Activé | Corrige pour Git les noms des branches, des tags et des dépôts distants pendant la saisie. Consultez [Créer une branche](/guide/branches/branches/#create). |
| :ui[settings.autoArchive] | Désactivé | Archive les branches qui semblent terminées. Consultez [Archiver automatiquement](/guide/branches/review/#auto-archive). |

### Confirmations {#confirmations}

Chacune de ces questions comporte :ui[dialog.doNotAskAgain]. Le sélectionner à cet endroit désactive le réglage correspondant ici. Réactivez le réglage pour que la question soit posée à nouveau. Les quatre sont activés au départ.

| Réglage | Demande avant |
|---|---|
| :ui[settings.warnDiscardingChunks] | D’abandonner des sections ou des lignes, dans n’importe quel dépôt. Consultez [Abandonner des modifications](/guide/work/diff/#discard). |
| :ui[settings.warnDiscardingOnServer] | D’abandonner des fichiers entiers dans un dépôt sur un serveur |
| :ui[settings.warnDeletingOnServer] | De supprimer définitivement des fichiers sur un serveur sans Corbeille |
| :ui[settings.warnRestoringOnServer] | De restaurer des fichiers depuis une révision dans un dépôt sur un serveur. Consultez [Restaurer un fichier depuis une révision](/guide/history/file-views/#restore). |

Dans un dépôt local, l’abandon de fichiers entiers demande toujours confirmation.

### Historique et diffs {#history}

| Réglage | Par défaut | Ce qu’il fait |
|---|---|---|
| :ui[history.pageSize] | 100 | Le nombre de commits que l’historique charge à la fois : 100, 200, 500 ou 1 000 |
| :ui[settings.dateFormat] | Absolu | Les dates absolues sont courtes, comme 26/10/2026. Les dates relatives disent « Aujourd’hui » ou « Hier » pour ces deux jours et écrivent les autres dates en entier. Le menu montre un exemple de chacune. |
| :ui[history.mergeDiff] | :ui[history.mergeDiff.firstParent] | Ce qu’affichent les modifications d’un commit de fusion. Consultez [Les modifications](/guide/history/commit-details/#changeset). |
| :ui[working.diffThreshold] | 20 000 | Les diffs qui dépassent ce nombre de kilooctets demandent confirmation avant de s’afficher. Choisissez une valeur ou tapez-en une. Consultez [Lire un diff](/guide/work/diff/#read). |

Le format de date s’applique à l’historique, aux remisages, à l’historique d’un fichier et au reflog.

### Liste de fichiers {#file-list}

| Réglage | Par défaut | Ce qu’il fait |
|---|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] | Ou ouvrir le fichier dans votre outil de comparaison |
| :ui[files.openSubmodules] | Activé | Un double-clic sur un sous-module l’ouvre dans Spooky plutôt que dans une autre app |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] | Ou afficher le fichier dans Coup d’œil |
| :ui[files.fontSize] | :ui[files.fontSize.medium] | Ou :ui[files.fontSize.regular] |
| :ui[files.truncation] | :ui[files.truncation.beginning] | Ou raccourcir le milieu des noms longs |

Consultez [Réglages de la liste de fichiers](/guide/work/working-copy/#settings) pour leur effet dans la copie de travail.

### Fenêtres et liste Dépôts {#windows}

| Réglage | Par défaut | Ce qu’il fait |
|---|---|---|
| :ui[settings.windowRestoration] | :ui[settings.windowRestoration.system] | Ce que Spooky rouvre au démarrage. Consultez [Reprendre là où vous vous étiez arrêté](/guide/repositories/navigation/#restore). |
| :ui[settings.showLaunchWindow] | Désactivé | Affiche une fenêtre avec vos dépôts récents au démarrage de Spooky |
| :ui[settings.showWorktreesInRepositoryList] | Désactivé | Liste les worktrees de chaque dépôt dans la liste Dépôts |
| :ui[settings.showHostAliasesInRepositoryList] | Activé | Affiche l’alias d’hôte de chaque dépôt sur un serveur dans la liste Dépôts |
| :ui[settings.showDeveloperMenu] | Désactivé | Ajoute le menu :ui[menu.developer], avec des outils pour tester Spooky lui-même |

## Mises à jour {#updates}

La page :ui[settings.updates] règle le canal de mise à jour, la recherche et le téléchargement automatiques des mises à jour, et la fréquence des recherches. [Garder Spooky à jour](/guide/start/install/#updates) explique chaque option.

## Environnement {#environment}

Les apps ouvertes depuis le Finder ou le Dock ne reçoivent pas l’environnement que vous avez dans Terminal. Par exemple, il peut manquer à `PATH` des dossiers comme `/opt/homebrew/bin`. Les crochets Git, les assistants d’identification et Git LFS risquent alors d’être introuvables. La page :ui[settings.environment] règle ce problème pour le Git de ce Mac.

### Variables sur ce Mac {#local-variables}

| Réglage | Ce qu’il fait |
|---|---|
| :ui[settings.environment.loginShell] | Lance une fois votre shell de connexion, lit les variables définies par ses fichiers de démarrage et les transmet à Git. Le tableau en dessous liste ce qui a été lu. Activé au départ. |
| :ui[settings.environment.custom] | Les variables que vous ajoutez vous-même. Cliquez sur le bouton d’ajout pour en ajouter une, et sur le bouton de suppression pour retirer celle qui est sélectionnée. Elles l’emportent sur celles du shell de connexion. |

Quelques points à connaître :

- Les changements s’appliquent à la commande Git suivante. Vous n’avez pas besoin de redémarrer Spooky.
- Le shell de connexion est relu à chaque démarrage de Spooky. Si la lecture échoue, la page vous le signale.
- Si deux variables personnalisées portent le même nom, celle du bas l’emporte. Une variable dont le nom n’est pas valide reste dans le tableau mais n’est pas transmise à Git.
- Pour utiliser un agent SSH autre que celui du système, définissez `SSH_AUTH_SOCK` ici ou dans votre shell de connexion. Consultez [Agent SSH](/guide/settings/integration/#ssh-agent).

:::note[Dépôts sur un serveur]
Ces variables ne s’appliquent qu’au Git de ce Mac. Le Git d’un serveur utilise l’environnement du serveur.
:::

### Vérifier un serveur {#server-check}

En bas de la page, vous pouvez voir l’environnement que Git reçoit sur un serveur, sans ajouter de dépôt :

1. Tapez un alias d’hôte dans le champ :ui[remote.host]. Vous pouvez aussi en choisir un dans le menu :ui[settings.environment.server.hosts]. Il liste les serveurs de vos dépôts sur un serveur.
2. Cliquez sur :ui[settings.environment.server.check].

::screenshot[La vérification d’un serveur, en bas de la page Environnement des réglages. Un alias d’hôte a été vérifié, et le résultat affiche le Git trouvé sur le serveur avec sa version.]{name="settings-environment" frame="closeup"}

Le résultat affiche le Git que trouvent les sessions SSH et sa version, ou :ui[settings.environment.server.noGit]. En dessous, il liste chaque dossier de `PATH` et le nom des variables qui commencent par `GIT_`. Si Git est introuvable, consultez [Git est introuvable sur le serveur](/reference/troubleshooting/#server-path).

## Voir aussi

- [Apparence et thèmes](/guide/settings/appearance/)
- [Profils utilisateur et configuration Git](/guide/settings/identity/)
- [Intégration](/guide/settings/integration/)
- [Installer Spooky](/guide/start/install/)
