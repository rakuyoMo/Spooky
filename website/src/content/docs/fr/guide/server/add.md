---
title: "Ajouter un dépôt sur un serveur"
description: "Remplissez la zone de dialogue d’ajout d’un dépôt sur un serveur, lisez les résultats de la vérification de la connexion, et clonez ou recherchez des dépôts sur le serveur."
---

Ajouter un dépôt sur un serveur le place dans votre liste Dépôts et l’ouvre. Spooky vérifie d’abord la connexion. S’il manque quelque chose, la zone de dialogue vous dit quoi corriger.

Avant de commencer, assurez-vous que Terminal peut se connecter au serveur sans rien demander. Consultez [Préparer SSH](/guide/server/prepare-ssh/).

Pour ouvrir la zone de dialogue, choisissez :ui[action.addRemote] dans le menu :ui[menu.file], ou dans le menu du bouton d’ajout de la fenêtre Dépôts.

## Remplir la zone de dialogue {#dialog}

::screenshot[La zone de dialogue d’ajout d’un dépôt sur un serveur. L’alias d’hôte est spooky-test. Le chemin du dépôt est /srv/git/driftwood, avec un bouton Parcourir à côté. Le montage sur ce Mac est réglé sur Ne pas monter. Les boutons sont Annuler et Ouvrir.]{name="add-server" frame="dialog"}

| Champ | Ce qu’il faut saisir |
|---|---|
| :ui[remote.host] | Le nom `Host` de `~/.ssh/config`, comme `driftwood-server`. Saisissez seulement l’alias, sans nom d’utilisateur ni port. |
| :ui[remote.path] | Le chemin complet du dépôt sur le serveur, qui commence par `/`, comme `/srv/git/driftwood` |
| :ui[remote.mount] | Facultatif. Rend le dossier du dépôt disponible sur ce Mac, pour que le Finder puisse l’afficher. Consultez [Monter lors de l’ajout](/guide/server/local-location/#when-adding). |

Si vous ne connaissez pas le chemin, cliquez sur :ui[clone.browse] une fois l’alias d’hôte renseigné. Spooky liste les dossiers du serveur, à partir du chemin saisi ou de votre dossier de départ sur le serveur. Les dépôts Git sont marqués :ui[browse.repository]. Les dossiers que vous ne pouvez pas lire sont estompés. Double-cliquez sur un dossier pour y entrer, puis cliquez sur :ui[bookmarks.create.choosePrompt].

Vous pouvez aussi choisir un dossier à l’intérieur d’un dépôt. Spooky ouvre le dépôt auquel il appartient.

:ui[action.open] est disponible une fois l’alias d’hôte renseigné et le chemin commençant par `/`.

## La vérification de la connexion {#check}

Quand vous cliquez sur :ui[action.open], Spooky affiche :ui[remote.checking] en bas de la zone de dialogue et vérifie ces points, dans l’ordre :

1. SSH ouvre une session avec l’alias d’hôte.
2. Git est présent sur le serveur, en version 2.41.0 ou ultérieure.
3. Le dossier existe, et vous pouvez l’ouvrir et le lire.
4. Le dossier fait partie d’un dépôt Git, et Git peut lire son état.

Les champs sont verrouillés pendant la vérification. Cliquez sur :ui[action.cancel] pour l’arrêter et fermer la zone de dialogue.

Quand tout est bon, Spooky installe son script auxiliaire sur le serveur, ajoute le dépôt à la liste Dépôts et l’ouvre.

## Quand la vérification échoue {#results}

La zone de dialogue reste ouverte et garde ce que vous avez saisi. En bas, elle indique quoi corriger, suivi de la sortie d’origine de SSH ou de Git. Corrigez le problème et cliquez à nouveau sur :ui[action.open].

| Ce qui ne va pas | Ce qu’il faut faire |
|---|---|
| L’alias d’hôte n’est pas valide | Saisissez seulement l’alias de la ligne `Host`, sans espace, `@`, `:` ni `/`. |
| L’empreinte du serveur est inconnue | Connectez-vous une fois dans Terminal et vérifiez l’empreinte. Consultez [Se connecter une première fois](/guide/server/prepare-ssh/#fingerprint). Spooky n’accepte jamais une empreinte à votre place. |
| L’empreinte du serveur a changé | Ne vous connectez pas encore. Confirmez d’abord le changement avec le propriétaire du serveur. |
| SSH ne peut pas ouvrir de session | Le serveur n’accepte pas votre clé, ou votre Mac ne peut pas la déverrouiller. Consultez [Tester la façon dont Spooky se connecte](/guide/server/prepare-ssh/#test). |
| Le serveur est injoignable | Vérifiez l’alias d’hôte et votre réseau, puis réessayez. |
| Git est introuvable | Installez Git 2.41.0 ou ultérieur sur le serveur. S’il est installé, les sessions SSH ne le trouvent pas. La sortie indique le `PATH` utilisé par le serveur. Ajoutez-y le dossier de Git dans le fichier de démarrage du shell sur le serveur. |
| Git est trop ancien | Mettez Git à jour sur le serveur, en version 2.41.0 ou ultérieure. |
| Le dossier n’existe pas | Vérifiez le chemin. Pour y démarrer un nouveau dépôt, cliquez sur :ui[bookmarks.noRepository.create]. |
| Pas d’autorisation sur le dossier | Votre utilisateur sur le serveur doit avoir l’autorisation d’ouvrir et de lire le dossier. |
| macOS bloque le dossier sur le serveur | Le serveur est un Mac, et le dépôt se trouve dans un dossier protégé comme Documents. Activez l’accès complet au disque pour les utilisateurs distants, comme dans [Utiliser un Mac comme serveur](/guide/server/prepare-ssh/#mac-server), ou déplacez le dépôt. |
| Le dossier n’est pas un dépôt Git | Choisissez le dossier du dépôt, ou cliquez sur :ui[bookmarks.noRepository.create] pour faire de ce dossier un dépôt. Si la sortie de Git mentionne la propriété (« ownership »), le dossier appartient à un autre utilisateur du serveur. |
| Git ne peut pas lire l’état | La sortie de Git, en dessous, explique pourquoi. |
| La session sur le serveur ne peut pas être établie | Le SSH du serveur doit autoriser le transfert de sockets Unix. Le serveur a aussi besoin de `/usr/bin/perl`, et vous devez pouvoir écrire dans `~/.spooky/bin` et `/tmp` sur le serveur. Consultez [Configuration requise](/reference/requirements/#servers). |

::screenshot[La zone de dialogue d’ajout d’un dépôt sur un serveur, avec l’alias d’hôte spooky-test et le chemin /srv/git/driftwood. Sous les champs, un avertissement demande de vérifier que le chemin absolu existe sur le serveur sélectionné, suivi de la sortie d’origine, « Directory does not exist ». Les boutons sont Annuler, Créer un dépôt et Ouvrir.]{name="server-add-error" frame="dialog"}

:ui[bookmarks.noRepository.create] exécute `git init` dans ce dossier, après l’avoir créé s’il manque. Spooky vérifie ensuite à nouveau la connexion et ouvre le nouveau dépôt.

Pour voir le `PATH` et le Git qu’un serveur utilise sans ajouter de dépôt, ouvrez :ui[app.name > settings.title] › :ui[settings.environment]. Saisissez l’alias d’hôte en bas, puis cliquez sur :ui[settings.environment.server.check]. Consultez [Vérifier un serveur](/guide/settings/general/#server-check).

## Variables d’environnement Git sur le serveur {#environment}

Après la vérification, Spooky peut afficher :ui[remote.environment.title]. Le shell non interactif du serveur définit des variables dont le nom commence par `GIT_`. Elles changent la façon dont Git trouve les dépôts et lit ses réglages, pour chaque commande que Spooky y exécute.

Cliquez sur :ui[action.close], et le dépôt s’ouvre. Si Git s’y comporte de façon inattendue, retirez ces variables des fichiers de démarrage du shell sur le serveur.

## Cloner et rechercher sur un serveur {#clone-scan}

Il existe deux autres façons de faire entrer un dépôt sur un serveur dans la liste :

- **Cloner :** Dans la zone de dialogue de clonage, choisissez un serveur dans :ui[clone.to]. Git clone le dépôt sur le serveur, et Spooky l’ajoute comme dépôt sur un serveur. Consultez [Cloner un dépôt](/guide/repositories/manager/#clone).
- **Rechercher :** Choisissez :ui[scan.menu] dans le menu du bouton d’ajout, puis choisissez un serveur dans :ui[scan.in]. Spooky explore le dossier sur le serveur et liste les dépôts qu’il trouve. Consultez [Rechercher des dépôts](/guide/repositories/manager/#scan).

## Voir aussi

- [Préparer SSH](/guide/server/prepare-ssh/)
- [État de la connexion et reconnexion](/guide/server/connection/)
- [Emplacement sur ce Mac](/guide/server/local-location/)
