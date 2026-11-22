---
title: "Configuration requise"
description: "Vérifiez ce que Spooky exige de macOS, de Git et de vos serveurs."
---

Cette page liste ce dont Spooky a besoin sur votre Mac et sur les serveurs auxquels vous vous connectez.

## Mac {#mac}

| Quoi | Exigence |
|---|---|
| macOS | macOS 26 ou ultérieur |
| Git | Git 2.41.0 ou ultérieur. Spooky utilise `/usr/bin/git`, sauf si vous en choisissez un autre à côté de :ui[settings.gitProgram] dans :ui[app.name > settings.title] › :ui[settings.gitConfig]. Consultez [Binaire Git](/guide/settings/identity/#git-program). |
| SSH | Le SSH fourni avec macOS. Les dépôts sur un serveur l’utilisent pour se connecter. |

Spooky s’appuie sur des fonctions de Git ajoutées dans la version 2.41.0 : les versions plus anciennes ne fonctionnent donc pas.

## Serveurs {#servers}

Un serveur peut être une machine Linux ou un Mac. Spooky n’y a pas besoin d’un accès administrateur, et n’y installe aucun service.

| Quoi | Exigence |
|---|---|
| Connexion | Une connexion SSH avec une clé, par un alias d’hôte de `~/.ssh/config` sur votre Mac. Un compte qui ne peut se connecter qu’avec un mot de passe ne fonctionne pas. Consultez [Préparer SSH](/guide/server/prepare-ssh/). |
| Git | Git 2.41.0 ou ultérieur, dans le `PATH` qu’utilisent les connexions SSH non interactives |
| Serveur SSH | OpenSSH avec SFTP activé et le transfert de sockets Unix autorisé. Les deux le sont par défaut. `MaxSessions` doit valoir 10 ou plus, ce qui est aussi la valeur par défaut. |
| Demandes de phrase secrète | OpenSSH 8.4 ou ultérieur, si Git sur le serveur a besoin d’une phrase secrète pour une clé SSH |
| Perl | `/usr/bin/perl` avec ses modules standard `IO::Socket::UNIX`, `JSON::PP`, `POSIX` et `Fcntl` |
| Fichiers | Un accès en écriture à `~/.spooky/bin` dans votre dossier de départ sur le serveur, et à `/tmp` |
| Corbeille | Facultatif. Sur un Mac, Spooky utilise `/usr/bin/trash`, fourni avec macOS 15 et ultérieur. Sous Linux, il utilise `gio` ou `trash-put`. Sans l’un d’eux, Spooky demande d’abord confirmation, puis supprime les fichiers définitivement. |

Pour voir ce qu’un serveur fournit avant d’ajouter un dépôt, lancez le test décrit dans [Préparer SSH](/guide/server/prepare-ssh/#test). Vous pouvez aussi vérifier un serveur dans :ui[app.name > settings.title] › :ui[settings.environment]. Consultez [Vérifier un serveur](/guide/settings/general/#server-check).

## Facultatif {#optional}

| Pour utiliser | Il vous faut |
|---|---|
| Git LFS | Git LFS 2.9.0 ou ultérieur, sur la machine où se trouve le dépôt, dans le `PATH` que Git y utilise |
| Les montages sshfs | sshfs et macFUSE ou FUSE-T sur votre Mac |
| Les montages SMB | Le partage de fichiers SMB sur le serveur |
| Les pull requests et merge requests | Un compte sur github.com ou GitLab.com, ou sur un GitLab autogéré 9.0 ou ultérieur |

## Voir aussi

- [Installer Spooky](/guide/start/install/)
- [Fonctionnement des dépôts sur un serveur](/guide/server/overview/)
- [Données et confidentialité](/reference/data-privacy/)
