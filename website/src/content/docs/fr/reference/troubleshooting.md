---
title: "Dépannage"
description: "Corrigez les problèmes courants, comme les connexions qui échouent, un Git trop ancien, les autorisations et le PATH sur le serveur, et découvrez comment signaler un problème."
---

Chaque problème ci-dessous commence par ce que vous voyez, puis explique pourquoi cela se produit et quoi faire. Beaucoup d’erreurs de Spooky affichent aussi la sortie d’origine de Git ou de SSH, qui nomme souvent la cause exacte.

## Impossible de se connecter à un serveur {#connect}

Un problème de connexion se manifeste à l’un de ces endroits :

- La zone de dialogue :ui[remote.form.title] reste ouverte et indique ce qu’il faut corriger. Consultez [Quand la vérification échoue](/guide/server/add/#results) pour chaque cas.
- L’ouverture d’un dépôt sur un serveur affiche :ui[missing.unreachable.title]{1="driftwood-server"}. Consultez [Pendant une déconnexion](/guide/server/connection/#offline).
- Dans un dépôt sur un serveur ouvert, le bandeau en haut de la liste devient jaune et nomme la raison. Consultez [État de la connexion](/guide/server/connection/#status).

Essayez d’abord la même connexion en dehors de Spooky. Exécutez ceci dans Terminal, avec votre propre alias d’hôte :

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

Si la commande échoue, le problème se situe entre votre Mac et le serveur. Consultez [Tester la façon dont Spooky se connecte](/guide/server/prepare-ssh/#test) pour savoir ce que signifie chaque type de sortie. Si elle fonctionne dans Terminal mais que Spooky ne parvient toujours pas à se connecter, Spooky utilise peut-être un autre agent SSH. Consultez [Agent SSH](/guide/settings/integration/#ssh-agent).

La raison affichée par Spooky vous indique où chercher :

| Raison | Quoi faire |
|---|---|
| :ui[remoteError.authentication] | Le serveur n’accepte pas votre clé, ou votre Mac ne peut pas la déverrouiller. Après un redémarrage, chargez de nouveau la clé, comme dans [Après le redémarrage de votre Mac](/guide/server/prepare-ssh/#after-restart). Un compte qui ne peut se connecter qu’avec un mot de passe ne fonctionne pas. |
| :ui[remoteError.unknownHostKey] | Votre Mac ne connaît pas encore le serveur. Connectez-vous une fois dans Terminal et vérifiez l’empreinte, comme dans [Se connecter une première fois](/guide/server/prepare-ssh/#fingerprint). Spooky n’accepte jamais une empreinte à votre place. |
| :ui[remoteError.changedHostKey] | Ne vous connectez pas tout de suite. Confirmez d’abord le changement auprès du propriétaire du serveur. |
| :ui[remoteError.unavailable] | Vérifiez l’alias d’hôte et votre réseau. Spooky réessaie 5 secondes après chaque tentative échouée. Pour réessayer tout de suite, cliquez sur :ui[action.reconnect] dans le bandeau. Consultez [Déconnexions et reconnexion](/guide/server/connection/#reconnect). |
| :ui[remoteError.deployment] | Il manque au serveur un élément dont Spooky a besoin : le transfert de sockets Unix, `/usr/bin/perl`, ou l’accès en écriture à `~/.spooky/bin` et à `/tmp`. Consultez [Serveurs](/reference/requirements/#servers). |

Si Git est absent ou trop ancien sur le serveur, lisez la suite.

## Git est trop ancien {#git-version}

Spooky nécessite Git 2.41.0 ou ultérieur, sur votre Mac comme sur les serveurs.

### Sur votre Mac {#mac-git}

Quand vous ouvrez un dépôt local, Spooky peut afficher l’un de ces messages :

- :ui[error.version], avec la sortie de Git en dessous. Le binaire Git que Spooky utilise est antérieur à la version 2.41.0. Choisissez-en un plus récent à côté de :ui[settings.gitProgram] dans :ui[app.name > settings.title] › :ui[settings.gitConfig], ou mettez à jour Xcode ou les Command Line Tools.
- :ui[error.gitProgram], avec le chemin en dessous. Le binaire Git que vous avez choisi n’est plus là, par exemple parce que vous l’avez désinstallé. Choisissez-en un autre au même endroit.

Le menu ne liste que les binaires Git assez récents. Consultez [Binaire Git](/guide/settings/identity/#git-program).

### Sur un serveur {#server-git}

La connexion échoue avec :ui[remoteError.gitVersion]. Mettez à jour Git sur le serveur vers la version 2.41.0 ou ultérieure.

Si un Git plus récent y est déjà installé, les connexions SSH en trouvent d’abord un plus ancien. Placez le dossier du Git plus récent avant les autres dans `PATH`, comme dans [Git est introuvable sur le serveur](#server-path).

## Git est introuvable sur le serveur {#server-path}

La connexion échoue avec :ui[remoteError.gitUnavailable]. Ou bien, quand vous vérifiez le serveur dans :ui[app.name > settings.title] › :ui[settings.environment], il affiche :ui[settings.environment.server.noGit].

Si Git n’est pas installé sur le serveur, installez Git 2.41.0 ou ultérieur. S’il l’est, la cause est en général le `PATH`. Spooky exécute les commandes sur le serveur via SSH, sans shell interactif. Ce shell lit moins de fichiers de démarrage. Un `PATH` défini dans `~/.zshrc` ou `~/.bash_profile` peut ne pas s’appliquer.

Pour corriger cela :

1. Connectez-vous au serveur dans Terminal et exécutez `command -v git`. La commande affiche l’emplacement de Git, par exemple `/opt/homebrew/bin/git`.
2. Comparez-le au `PATH` que Spooky obtient. La sortie de l’erreur l’indique, tout comme la vérification décrite dans [Vérifier un serveur](/guide/settings/general/#server-check).
3. Ajoutez le dossier de Git à `PATH` dans un fichier de démarrage que les shells non interactifs lisent. Exécutez `echo $SHELL` sur le serveur pour voir quel shell vous utilisez.
   - zsh : `~/.zshenv`
   - bash : `~/.bashrc`, au-dessus de toute ligne qui s’arrête tôt quand le shell n’est pas interactif

   Par exemple :

   ```sh
   export PATH="/opt/homebrew/bin:$PATH"
   ```

4. Cliquez de nouveau sur :ui[settings.environment.server.check], ou lancez le test de la section [Impossible de se connecter à un serveur](#connect). Puis reconnectez-vous.

Git LFS et les programmes que vos crochets exécutent sont trouvés par le même `PATH`. S’ils fonctionnent dans Terminal mais pas depuis Spooky, ajoutez leurs dossiers de la même façon.

## Problèmes d’autorisation {#permissions}

| Ce que vous voyez | Pourquoi, et quoi faire |
|---|---|
| :ui[remoteError.pathPermission] | Votre utilisateur sur le serveur ne peut pas ouvrir ou lire le dossier du dépôt. Demandez l’accès au propriétaire du serveur, ou choisissez un dossier qui vous appartient. |
| :ui[remoteError.diskAccess] | Le serveur est un Mac, et le dépôt se trouve dans un dossier que macOS protège, comme Documents. Activez l’accès complet au disque pour les utilisateurs distants, comme dans [Utiliser un Mac comme serveur](/guide/server/prepare-ssh/#mac-server), ou déplacez le dépôt. |
| :ui[error.ownership] | Le dossier du dépôt sur ce Mac appartient à un autre utilisateur. Git refuse d’y travailler. Devenez propriétaire du dossier. Si vous faites confiance à son propriétaire, vous pouvez à la place exécuter la commande `git config --global --add safe.directory` que suggère la sortie de Git. |
| :ui[error.terminal] | Les détails sous le titre indiquent ce qui n’a pas fonctionné. Souvent, l’app de terminal choisie à côté de :ui[settings.terminal] n’est plus installée, ou vous n’avez pas autorisé Spooky à contrôler Terminal ou iTerm. Consultez [Terminal](/guide/settings/integration/#terminal). |
| :ui[appIcon.writeFailed] | Spooky enregistre l’icône dans `Spooky.app`. Votre utilisateur doit pouvoir y écrire. Dans le Finder, sélectionnez Spooky, choisissez **Fichier › Lire les informations**, et vérifiez que vous avez le droit **Lecture et écriture** sous **Partage et permissions**. |

:::note[Dépôts sur un serveur]
Sur un serveur, un dossier qui appartient à un autre utilisateur échoue avec :ui[remoteError.notWorkingTree], et la sortie de Git mentionne le propriétaire. Adressez-vous au propriétaire du serveur, ou exécutez la commande `safe.directory` sur le serveur.
:::

## Signaler un problème {#report}

Choisissez :ui[menu.help > help.support] pour ouvrir les tickets de Spooky sur GitHub. Cherchez-y votre problème, ou ouvrez un nouveau ticket. Indiquez ce que vous avez fait, ce que vous attendiez et ce qui s’est passé. Si Spooky a affiché une erreur, joignez son titre et la sortie d’origine.

Un rapport de diagnostic aide à montrer ce qui s’est passé. Choisissez :ui[menu.help > help.diagnosticReport] et choisissez où l’enregistrer. Spooky enregistre un fichier texte et l’affiche dans le Finder. Il n’envoie le rapport nulle part. Ouvrez le fichier et lisez-le avant de le partager. Consultez [Rapports de diagnostic](/reference/data-privacy/#diagnostic-reports) pour savoir ce qu’il contient.

Si Spooky a quitté de manière inattendue la dernière fois, il demande au lancement suivant : :ui[crash.title]. Quand vous cliquez sur :ui[crash.report], une page de nouveau ticket sur GitHub s’ouvre dans votre navigateur, préremplie avec un résumé du plantage. Le ticket n’est créé que lorsque vous l’envoyez dans le navigateur. Consultez [Rapports de plantage](/reference/data-privacy/#crash-reports).

## Voir aussi

- [Préparer SSH](/guide/server/prepare-ssh/)
- [État de la connexion et reconnexion](/guide/server/connection/)
- [Configuration requise](/reference/requirements/)
- [Données et confidentialité](/reference/data-privacy/)
