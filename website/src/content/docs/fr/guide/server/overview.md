---
title: "Fonctionnement des dépôts sur un serveur"
description: "Découvrez ce qui se passe sur le serveur et ce qui se passe sur votre Mac, ce que Spooky garde sur le serveur, et en quoi les dépôts sur un serveur diffèrent des dépôts locaux."
---

Un dépôt sur un serveur est un dépôt Git situé sur une autre machine, que Spooky ouvre via SSH. Ses fichiers restent sur le serveur, et Git s’y exécute. Vous ne le clonez pas d’abord sur votre Mac. Cette page explique ce que fait chaque côté, ce que Spooky laisse sur le serveur et ce qui fonctionne autrement que dans un dépôt sur votre Mac.

Pour en configurer un, commencez par [Préparer SSH](/guide/server/prepare-ssh/), puis passez à [Ajouter un dépôt sur un serveur](/guide/server/add/).

## Ce qui se passe et où {#where}

Spooky se connecte avec le SSH fourni avec macOS. Il utilise un alias d’hôte de votre fichier `~/.ssh/config`. Il ouvre donc une session sur le serveur de la même façon que la commande `ssh` dans Terminal.

Sur le serveur :

- Git exécute chaque commande, avec le Git et l’environnement du serveur.
- Spooky lit et écrit les fichiers via la connexion SSH. Les fichiers volumineux passent par SFTP, la partie de SSH consacrée au transfert de fichiers.
- Les fichiers que vous supprimez, et les nouveaux fichiers que vous abandonnez, vont dans la Corbeille du serveur s’il en a une.
- La récupération, le tirage et la poussée atteignent les dépôts distants comme GitHub depuis le serveur. Ils utilisent le réseau du serveur et ses clés SSH.

Sur votre Mac :

- Les fenêtres, les listes et les diffs avec lesquels vous travaillez.
- La connexion SSH au serveur. Spooky garde une connexion par dépôt ouvert et y fait passer chaque commande.
- Les questions posées par Git sur le serveur, comme un mot de passe ou la phrase secrète d’une clé. Consultez [Demandes de mot de passe et de phrase secrète](/guide/server/connection/#prompts).
- Les requêtes vers GitHub et GitLab, comme la connexion à votre compte ou le chargement des pull requests.
- Les copies des fichiers que vous ouvrez dans Coup d’œil ou dans une autre app.

:::note
Pour un dépôt distant joint via SSH, le serveur doit déjà connaître la clé d’hôte de ce dépôt distant. Si ce n’est pas le cas, ouvrez une session sur le serveur et connectez-vous une fois au dépôt distant à partir de là.
:::

## Ce que Spooky garde sur le serveur {#on-server}

Spooky n’a pas besoin d’un accès administrateur et n’installe aucun service. Il laisse deux choses sur le serveur :

- **Un script auxiliaire dans `~/.spooky/bin/`**, dans votre dossier de départ sur le serveur. Il transmet les questions de Git à votre Mac. Spooky l’y place lors de la connexion et le garde pour les connexions suivantes. Les autres noms de ce dossier, qui se terminent par `-askpass`, `-gpg`, etc., sont des liens vers le même fichier.
- **Des fichiers temporaires dans `/tmp/spooky-*`** tant qu’un dépôt est ouvert. Spooky les supprime quand vous fermez le dépôt.

Le script s’exécute avec `/usr/bin/perl`, déjà présent sur la plupart des serveurs macOS et Linux. Pour la liste complète, consultez [Configuration requise](/reference/requirements/#servers).

Vous pouvez supprimer `~/.spooky` à tout moment. Spooky réinstalle le script à la connexion suivante.

## En quoi les dépôts sur un serveur diffèrent {#differences}

Un dépôt sur un serveur s’ouvre dans le même type de fenêtre qu’un dépôt sur votre Mac. La plupart des vues et des commandes fonctionnent de la même façon. Voici les signes visibles qu’un dépôt se trouve sur un serveur :

::screenshot[Une fenêtre de dépôt sur un serveur. Le titre indique spooky-test:driftwood, avec la vue et la branche actuelles en dessous. La barre d’outils affiche l’alias d’hôte spooky-test. Un bandeau en haut de la colonne du milieu indique que spooky-test est connecté. En dessous se trouvent la zone de commit et la liste des fichiers modifiés. La colonne de droite affiche les modifications du fichier sélectionné.]{name="hero" frame="window" markers="47.5,3.3 64.4,7.2 40,8.9"}

1. Le titre de la fenêtre commence par l’alias d’hôte, sous la forme `driftwood-server:driftwood`. La fenêtre Dépôts affiche les noms de la même façon.
2. L’élément :ui[toolbar.host] de la barre d’outils affiche l’alias d’hôte.
3. L’état de la connexion s’affiche en haut de la copie de travail, de l’historique et des autres listes. Consultez [État de la connexion et reconnexion](/guide/server/connection/).

Certaines choses fonctionnent autrement :

| Quoi | Dans un dépôt sur un serveur |
|---|---|
| Modifications faites sur le serveur | Spooky vérifie les changements sur le serveur toutes les 2 secondes tant que la fenêtre du dépôt est au premier plan, et toutes les 10 secondes sinon. Quand le serveur tarde à répondre, il vérifie moins souvent. |
| Perte de la connexion | Vous pouvez encore consulter ce que Spooky a lu en dernier, mais vous ne pouvez rien modifier avant la reconnexion. |
| :ui[action.revealFinder] | Le Finder a besoin d’un dossier sur votre Mac qui affiche les fichiers du serveur. Consultez [Emplacement sur ce Mac](/guide/server/local-location/). |
| :ui[action.openTerminal] | Terminal ouvre une session sur le serveur avec `ssh` et se place dans le dossier du dépôt. |
| :ui[action.copyPath] | Le chemin copié commence par l’alias d’hôte, sous la forme `driftwood-server:/srv/git/driftwood`. |
| Ouverture d’un fichier dans une autre app | La plupart des apps reçoivent une copie du fichier. Spooky réécrit vos modifications sur le serveur quand vous enregistrez. Consultez [Terminal et autres apps](/guide/server/local-location/#terminal). |
| Abandon ou suppression de fichiers | Spooky demande confirmation avant d’abandonner des modifications, car cela écrase des fichiers sur le serveur. Les fichiers supprimés et les nouveaux fichiers abandonnés vont dans la Corbeille du serveur. Si le serveur n’a pas de Corbeille, Spooky demande d’abord, puis les supprime définitivement. |
| Réglages :ui[settings.environment] | Ils ne s’appliquent qu’au Git de votre Mac. Le Git d’un serveur utilise l’environnement du serveur. Consultez [Environnement](/guide/settings/general/#environment). |

Vous pouvez désactiver les confirmations pour l’abandon de modifications, la suppression définitive de fichiers et la restauration de fichiers dans :ui[app.name > settings.title] › :ui[settings.general]. Consultez [Confirmations](/guide/settings/general/#confirmations).

## Voir aussi

- [Préparer SSH](/guide/server/prepare-ssh/)
- [Ajouter un dépôt sur un serveur](/guide/server/add/)
- [Configuration requise](/reference/requirements/)
