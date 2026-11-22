---
title: "Profils utilisateur et configuration Git"
description: "Gérez les profils utilisateur et la configuration Git, et ajustez les réglages d’un seul dépôt."
---

Git enregistre un nom et une adresse e-mail avec chaque commit, et peut le signer avec une clé. Spooky vous donne trois endroits pour les configurer :

- :ui[settings.profiles], dans :ui[app.name > settings.title], garde les identités entre lesquelles vous alternez.
- :ui[settings.gitConfig], dans :ui[app.name > settings.title], règle le binaire Git ainsi que votre identité et votre signature globales.
- Les réglages d’un seul dépôt l’emportent sur les réglages globaux pour ce dépôt.

## Profils utilisateur {#profiles}

Un profil utilisateur réunit un nom, une adresse e-mail et, si vous le souhaitez, une clé de signature, enregistrés sous un titre comme « Travail ». Spooky garde les profils sur ce Mac. Vous pouvez les utiliser dans les dépôts locaux comme dans les dépôts sur un serveur.

Pour ajouter un profil :

1. Choisissez :ui[app.name > settings.title] › :ui[settings.profiles].
2. Cliquez sur le bouton d’ajout sous la liste.
3. Remplissez les champs :ui[profiles.title], :ui[profiles.userName] et :ui[profiles.email]. Si vous le souhaitez, choisissez une :ui[profiles.signingKey] parmi les clés trouvées sur ce Mac.
4. Cliquez sur :ui[profiles.create.submit].

Le titre, le nom d’utilisateur et l’adresse e-mail sont obligatoires. Deux profils ne peuvent pas avoir le même titre, ni à la fois le même nom d’utilisateur et la même adresse e-mail.

Pour modifier un profil, sélectionnez-le et cliquez sur :ui[profiles.edit]. Pour en supprimer un, sélectionnez-le et cliquez sur le bouton de suppression. Supprimer un profil ne change aucun réglage Git.

Si l’identité que vous utilisez en ce moment n’est pas encore un profil, choisissez :ui[profiles.addCurrent]{1="alex@example.com"} dans son menu. Saisissez un titre, puis cliquez sur :ui[profiles.add.submit].

### Utiliser un profil {#use-profile}

Cliquez sur l’image à côté d’une identité pour voir vos profils, avec une coche à côté de celui qui est utilisé. Ce que change le choix d’un profil dépend de l’endroit où vous le choisissez :

| Où | Ce que cela change | Demande d’abord |
|---|---|---|
| La zone de commit, ou :ui[bookmarks.detail.identity] dans les [réglages du dépôt](#repository) | Les réglages Git propres à ce dépôt. Consultez [Choisir qui valide](/guide/work/commit/#identity). | Oui |
| :ui[settings.gitConfig] dans les réglages | Vos réglages Git globaux sur ce Mac | Non |

Le nom et l’adresse e-mail du profil sont écrits dans `user.name` et `user.email`. Un profil doté d’une clé de signature définit aussi `user.signingkey` et `gpg.format`.

Les [Actions rapides](/guide/repositories/navigation/#quick-actions) listent aussi vos profils. :ui[quickActions.setCommitter] agit comme la zone de commit. :ui[quickActions.setGlobalUser] définit, après confirmation, le nom et l’adresse e-mail dans vos réglages Git globaux sur la machine où se trouve le dépôt.

:::note[Dépôts sur un serveur]
Choisir un profil pour un dépôt sur un serveur modifie les réglages du dépôt sur le serveur. Les autres outils qui y valident utilisent la même identité. Dans un dépôt sur un serveur, :ui[quickActions.setGlobalUser] écrit dans vos réglages globaux sur le serveur.
:::

## Configuration Git {#git-config}

La page :ui[settings.gitConfig] comporte quatre parties : le binaire Git, votre identité, la signature et les outils externes. Les outils sont décrits dans [Intégration](/guide/settings/integration/#diff-merge-tools).

::screenshot[La page Configuration Git de la fenêtre Réglages, avec le binaire Git, le nom et l’adresse e-mail globaux, les réglages de signature et les outils de comparaison et de fusion.]{name="settings-git-config" frame="window" markers="20,15.9 20,28 18,43.7 20,81.4"}

1. Le binaire Git
2. Votre identité
3. La signature
4. Les outils externes

### Binaire Git {#git-program}

:ui[settings.gitProgram] liste les binaires Git assez récents présents sur ce Mac, avec leur version. Spooky cherche aux endroits habituels : `/usr/bin/git` (marqué comme celui du système, et utilisé au départ), Command Line Tools, Xcode, Homebrew et MacPorts.

Pour utiliser un Git qui n’est pas dans la liste, choisissez :ui[settings.gitProgram.choose] et sélectionnez le programme. Si le fichier n’est pas Git, ou si sa version est trop ancienne, Spooky vous dit pourquoi et garde celui que vous aviez. La ligne sous le menu indique la version la plus ancienne que Spooky accepte.

:::note[Dépôts sur un serveur]
Ce réglage ne s’applique qu’aux dépôts locaux. Les dépôts sur un serveur utilisent le Git du serveur. Consultez [Configuration requise](/reference/requirements/#servers).
:::

### Identité globale {#global-identity}

:ui[gitConfig.userName] et :ui[gitConfig.email] sont les réglages globaux `user.name` et `user.email` de Git. Tous les dépôts de ce Mac les utilisent, sauf ceux qui ont les leurs.

Les changements sont enregistrés quand vous appuyez sur <kbd>Retour</kbd> ou quittez le champ. Vider un champ supprime le réglage. La ligne en dessous indique dans quel fichier ils sont enregistrés, en général `~/.gitconfig`.

Cliquez sur l’image à droite pour choisir un [profil](#use-profile) ou gérer vos profils.

### Signature {#signing}

Ces réglages décident de la façon dont Git signe les commits dans tous les dépôts de ce Mac qui n’ont pas leurs propres réglages.

| Réglage | Ce qu’il fait |
|---|---|
| :ui[gitConfig.sshProgram] | Le programme qui signe avec des clés SSH. :ui[gitConfig.sshProgram.system] est utilisé au départ. Si 1Password est installé, son programme de signature figure aussi dans la liste. |
| :ui[gitConfig.gpgProgram] | Le programme GnuPG pour les clés OpenPGP. Liste les versions assez récentes présentes sur ce Mac. Choisissez :ui[gitConfig.gpgProgram.select] pour en choisir un autre. |
| :ui[gitConfig.signingKey] | La clé qui sert à signer : une clé secrète de votre trousseau GnuPG, ou une clé chargée dans l’agent SSH. Le choix d’une clé indique aussi à Git s’il doit signer avec OpenPGP ou avec SSH. |
| :ui[gitConfig.allowedSigners] | Le fichier des clés SSH dont vous jugez les signatures fiables, utilisé quand Git vérifie les signatures. Choisissez `~/.ssh/allowed_signers`, choisissez un autre fichier, ou choisissez :ui[gitConfig.allowedSigners.none]. |
| :ui[gitConfig.signCommits] | Signe chaque commit |
| :ui[gitConfig.ensureEmailMatch] | Avertit quand l’adresse e-mail de la clé OpenPGP n’est pas votre adresse e-mail globale. Activé au départ. |

Quand quelque chose demande votre attention, comme un programme de signature qui ne peut pas s’exécuter, un bouton d’avertissement jaune apparaît à côté du réglage. Cliquez dessus pour voir ce qui ne va pas.

Les commits signés et la demande de phrase secrète sont décrits dans [Signer les commits](/guide/work/commit/#signing).

## Réglages du dépôt {#repository}

Chaque dépôt a ses propres réglages. Pour les voir, cliquez sur :ui[repositorySettings.title] sous :ui[workspace.group] dans la barre latérale. Les boutons du haut permettent de passer d’une section à l’autre, parmi quatre.

Les changements sont écrits dans les réglages Git propres au dépôt, et attendent leur tour avec les autres opérations du dépôt. Tout ce qu’un dépôt ne définit pas vient de vos réglages globaux.

::screenshot[Les réglages du dépôt dans la fenêtre principale, sur l’onglet Général, avec le nom, le chemin, la description, l’identité et les réglages de signature du dépôt.]{name="settings-repository" frame="window" markers="72.2,9.8 60,38.8"}

1. Les boutons qui changent de section
2. :ui[bookmarks.detail.identity]

### Général {#repository-general}

| Élément | Ce qu’il affiche |
|---|---|
| :ui[repositorySettings.name] et :ui[repositorySettings.path] | L’emplacement du dépôt |
| :ui[repositorySettings.localLocation] | Pour les dépôts sur un serveur, l’emplacement du dossier du dépôt sur ce Mac. Consultez [Définir l’emplacement](/guide/server/local-location/#set). |
| :ui[bookmarks.detail.description] | Une description du dépôt, affichée aussi dans [la fenêtre Dépôts](/guide/repositories/manager/). Cliquez sur :ui[bookmarks.detail.edit] pour la modifier. |
| :ui[bookmarks.detail.identity] | Le nom et l’adresse e-mail avec lesquels ce dépôt valide. Cliquez sur l’image pour utiliser un [profil](#use-profile), ou sur :ui[bookmarks.detail.edit] pour taper un nom et une adresse e-mail rien que pour ce dépôt. |

Sous :ui[repositorySettings.signing], :ui[repositorySettings.signCommits], :ui[repositorySettings.signingKey] et :ui[repositorySettings.allowedSigners] fonctionnent comme les [réglages globaux](#signing), pour ce dépôt seulement.

### Git LFS, fichiers ignorés et exclusions {#repository-files}

- :ui[repositorySettings.lfs] affiche la version de Git LFS et les :ui[repositorySettings.lfs.patterns]. Consultez [Git LFS](/guide/advanced/lfs/).
- :ui[repositorySettings.ignores] liste les règles du `.gitignore` situé à la racine du dépôt. Validez ce fichier pour partager les règles avec les autres.
- :ui[repositorySettings.excludes] liste les règles du fichier `info/exclude` de Git. Elles ne s’appliquent qu’à cette copie du dépôt.

Cliquez sur :ui[repositorySettings.openInEditor] pour modifier les règles. Le fichier s’ouvre dans l’app que votre Mac lui associe. Si le fichier n’existe pas encore, Spooky le crée d’abord.

:::note[Dépôts sur un serveur]
Les réglages sont lus et écrits sur le serveur. Vous ne pouvez les modifier que tant que le dépôt est connecté. :ui[repositorySettings.openInEditor] ouvre le fichier de la même façon que la copie de travail ouvre les fichiers sur le serveur. Consultez [Terminal et autres apps](/guide/server/local-location/#terminal).
:::

## Voir aussi

- [Valider des modifications](/guide/work/commit/)
- [Général, mises à jour et environnement](/guide/settings/general/)
- [Intégration](/guide/settings/integration/)
- [Configuration requise](/reference/requirements/)
