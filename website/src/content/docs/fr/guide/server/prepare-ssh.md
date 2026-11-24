---
title: "Préparer SSH"
description: "Configurez une clé SSH et un alias d’hôte dans ~/.ssh/config, et assurez-vous de pouvoir vous connecter depuis Terminal avant d’ajouter un dépôt sur un serveur."
---

Spooky ouvre une session sur un serveur avec SSH, de la même façon que Terminal. Il ne peut pas taper de mot de passe à votre place. Il lui faut donc une clé SSH. Cette page configure une clé et un nom court pour le serveur, puis vérifie que Terminal se connecte sans rien demander. Une fois que cela fonctionne, Spooky peut se connecter lui aussi.

Si `ssh` vous connecte déjà au serveur sans mot de passe, passez à [Tester la façon dont Spooky se connecte](#test).

## Ce qu’il vous faut {#before}

- Un compte sur le serveur, auquel vous pouvez vous connecter avec SSH. Demandez au propriétaire du serveur en cas de doute.
- Git 2.41.0 ou ultérieur sur le serveur.
- L’app **Terminal** sur votre Mac.

Les commandes de cette page se saisissent dans Terminal. Tapez ou collez chacune d’elles, puis appuyez sur Retour.

## Vérifier si vous avez une clé {#key-check}

Une clé SSH est une paire de fichiers. La clé privée reste sur votre Mac. La clé publique se termine par `.pub` et va sur le serveur.

```sh
ls ~/.ssh
```

Si la liste contient `id_ed25519` et `id_ed25519.pub`, vous avez déjà une clé. Passez à [Ajouter un alias d’hôte](#alias). Une autre paire, comme `id_rsa` et `id_rsa.pub`, convient aussi. Utilisez son nom à la place de `id_ed25519` dans les étapes ci-dessous.

Si vous voyez « No such file or directory », ou si la liste ne contient aucune paire de clés, créez-en une.

## Créer une clé {#create-key}

```sh
ssh-keygen -t ed25519 -C "alex@example.com"
```

Mettez votre propre adresse e-mail entre les guillemets. Ce n’est qu’une étiquette qui vous aide à reconnaître la clé.

1. Quand on vous demande où enregistrer la clé, appuyez sur Retour pour garder l’emplacement proposé.
2. Saisissez une phrase secrète, puis saisissez-la à nouveau. Rien ne s’affiche pendant la saisie. La phrase secrète protège la clé si quelqu’un copie le fichier.

À la fin, `~/.ssh` contient `id_ed25519` et `id_ed25519.pub`.

## Ajouter un alias d’hôte {#alias}

Un alias d’hôte est un nom court pour un serveur. Vous le tapez dans Terminal et dans Spooky, à la place de l’adresse du serveur et de votre nom d’utilisateur. Les alias sont enregistrés dans le fichier `~/.ssh/config`. Vous les ajoutez dans les réglages de Spooky.

1. Choisissez :ui[app.name > settings.title] › :ui[settings.sshHosts].
2. Cliquez sur le bouton d’ajout sous la liste.
3. Remplissez les champs avec vos propres informations.
4. Cliquez sur :ui[sshHosts.create.submit].

::screenshot[La zone de dialogue d’ajout d’un alias d’hôte. L’alias est driftwood-server, l’adresse du serveur 203.0.113.10, le nom d’utilisateur alex, le port est vide et la clé privée est ~/.ssh/id_ed25519. Les boutons sont Annuler et Ajouter.]{name="settings-ssh-hosts-add" frame="dialog"}

| Champ | Ce qu’il faut y mettre |
|---|---|
| :ui[sshHosts.alias] | L’alias. Utilisez un seul mot, sans espace, `@`, `:`, `/`, `*` ni `?`, et ne le commencez pas par `-` ni par `!`. |
| :ui[sshHosts.hostName] | L’adresse ou le nom du serveur, comme `203.0.113.10` ou `server.example.com` |
| :ui[sshHosts.user] | Votre nom d’utilisateur sur le serveur |
| :ui[sshHosts.port] | Le port, si SSH en utilise un autre que 22 sur le serveur |
| :ui[sshHosts.identityFile] | La clé privée que vous avez créée ou trouvée plus haut, comme `~/.ssh/id_ed25519` |

Seul :ui[sshHosts.alias] est obligatoire. Spooky écrit l’alias et les champs remplis dans `~/.ssh/config` :

```
Host driftwood-server
    HostName 203.0.113.10
    User alex
    IdentityFile ~/.ssh/id_ed25519
```

Si le fichier contient une entrée avec un motif, comme `Host *`, ou une entrée `Match`, les nouvelles lignes se placent au-dessus de la première d’entre elles. Cette entrée ne peut donc pas les remplacer. Sinon, elles se placent à la fin du fichier.

### Modifier ou supprimer un alias {#manage-aliases}

La page :ui[settings.sshHosts] liste les alias de `~/.ssh/config`, y compris ceux que vous avez ajoutés dans un éditeur de texte.

::screenshot[La page Hôtes SSH de la fenêtre Réglages. La liste a les colonnes Alias, Adresse du serveur, Nom d’utilisateur, Port et Clé privée. Elle contient trois alias : staging, backup-nas et driftwood-server, qui est sélectionné. Sous la liste figurent les boutons d’ajout et de suppression, et à droite un bouton Modifier.]{name="settings-ssh-hosts" frame="window"}

- Pour modifier un alias, double-cliquez dessus, ou sélectionnez-le et cliquez sur :ui[sshHosts.edit] ou appuyez sur <kbd>Retour</kbd>. Spooky ne change que les lignes des champs que vous modifiez. Les autres options SSH du serveur, les autres serveurs et les commentaires restent tels quels.
- Pour supprimer un alias, sélectionnez-le, cliquez sur le bouton de suppression sous la liste, puis confirmez. Spooky supprime sa ligne `Host` et les options qui la suivent.

Une entrée comportant plusieurs noms ou un motif, comme `Host *`, ne figure pas dans la liste, et Spooky ne la modifie pas. Modifiez ces entrées dans un éditeur de texte.

Spooky relit le fichier chaque fois que vous revenez à l’app. Si une autre app modifie le fichier pendant qu’une zone de dialogue est ouverte, Spooky n’enregistre pas votre modification. La liste affiche le contenu actuel du fichier, et vous refaites la modification.

## Laisser votre Mac déverrouiller la clé {#keychain}

Spooky ne demande jamais la phrase secrète de votre clé lors de la connexion. Votre Mac doit donc déverrouiller la clé à sa place. Deux lignes dans `~/.ssh/config` suffisent pour tous les serveurs. Ignorez cette étape si votre clé n’a pas de phrase secrète.

1. Ouvrez le fichier dans TextEdit :

   ```sh
   open -e ~/.ssh/config
   ```

2. Ajoutez ces lignes à la fin :

   ```
   Host *
       AddKeysToAgent yes
       UseKeychain yes
   ```

3. Enregistrez le fichier et fermez TextEdit.

La première fois que vous tapez la phrase secrète, votre Mac l’enregistre dans le trousseau. Ensuite, SSH déverrouille la clé sans rien demander.

## Se connecter une première fois {#fingerprint}

La première fois que vous vous connectez à un serveur, SSH vous demande de confirmer l’empreinte du serveur. Spooky n’accepte jamais une empreinte à votre place. Faites-le donc d’abord dans Terminal.

```sh
ssh driftwood-server
```

1. SSH affiche l’empreinte du serveur, une ligne qui commence par `SHA256:`, et demande s’il faut continuer.
2. Comparez-la avec l’empreinte que vous donne le propriétaire du serveur. Sur le serveur, cette commande l’affiche :

   ```sh
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. Si elles correspondent, tapez `yes` et appuyez sur Retour. Votre Mac retient le serveur et ne posera plus la question.

La suite dépend du serveur :

- Si SSH demande la phrase secrète de votre clé, saisissez-la. Votre Mac l’enregistre dans le trousseau.
- Si la session s’ouvre, votre clé est déjà sur le serveur. Tapez `exit`, puis passez à [Tester la façon dont Spooky se connecte](#test).
- Si SSH demande votre mot de passe sur le serveur, appuyez sur <kbd>⌃C</kbd> pour l’instant. L’étape suivante place votre clé sur le serveur.

:::caution
Si SSH avertit que l’identification de l’hôte distant a changé, ne continuez pas. Demandez au propriétaire du serveur si celui-ci a été réinstallé ou remplacé.
:::

## Placer la clé publique sur le serveur {#copy-key}

Si vous pouvez vous connecter au serveur avec un mot de passe, cette commande y copie votre clé publique. Saisissez votre mot de passe sur le serveur quand il est demandé.

```sh
ssh-copy-id -i ~/.ssh/id_ed25519.pub driftwood-server
```

Si le serveur n’accepte pas les mots de passe, envoyez plutôt votre clé publique au propriétaire du serveur. Cette commande la copie dans le presse-papiers :

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

Demandez-lui de l’ajouter à `~/.ssh/authorized_keys` dans votre dossier de départ sur le serveur. La clé publique peut être partagée sans risque. N’envoyez jamais le fichier sans `.pub`.

## Tester la façon dont Spooky se connecte {#test}

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

Cette commande se connecte comme le fait Spooky, sans rien demander. Elle a réussi si elle affiche tout de suite une version 2.41.0 ou ultérieure, comme `git version 2.47.1`. Vous êtes prêt à [ajouter le dépôt sur le serveur](/guide/server/add/).

Si elle affiche autre chose :

| Ce que vous voyez | Ce qu’il faut faire |
|---|---|
| `Permission denied` | Le serveur n’accepte pas encore votre clé, ou votre Mac ne peut pas la déverrouiller. Vérifiez [Laisser votre Mac déverrouiller la clé](#keychain), [Placer la clé publique sur le serveur](#copy-key) et [Après le redémarrage de votre Mac](#after-restart). |
| `Host key verification failed` | Votre Mac ne connaît pas encore le serveur. Consultez [Se connecter une première fois](#fingerprint). |
| `Could not resolve hostname`, `Connection refused` ou `Operation timed out` | Vérifiez :ui[sshHosts.hostName] et :ui[sshHosts.port] de l’alias dans :ui[app.name > settings.title] › :ui[settings.sshHosts], et assurez-vous que le serveur est allumé et joignable. |
| Un message contenant `command not found` | Git n’est pas installé sur le serveur, ou les sessions SSH ne le trouvent pas. Demandez au propriétaire du serveur. |
| Une version antérieure à 2.41.0 | Demandez au propriétaire du serveur de mettre Git à jour. |

## Après le redémarrage de votre Mac {#after-restart}

Si le test fonctionnait mais échoue avec `Permission denied` après un redémarrage, chargez à nouveau votre clé. Les clés dont la phrase secrète est enregistrée dans le trousseau se chargent avec :

```sh
ssh-add --apple-load-keychain
```

## Utiliser un autre agent SSH {#agent}

Un agent SSH garde des clés déverrouillées à la disposition de SSH. Spooky utilise l’agent du système, celui que macOS lance pour vous. Si vos clés sont dans un autre agent, par exemple celui d’un gestionnaire de mots de passe, réglez `SSH_AUTH_SOCK` sur le socket de cet agent. Ajoutez-la comme variable personnalisée dans :ui[app.name > settings.title] › :ui[settings.environment], ou définissez-la dans votre shell de connexion. Spooky utilise alors cet agent pour se connecter aux serveurs. Consultez [Agent SSH](/guide/settings/integration/#ssh-agent).

## Utiliser un Mac comme serveur {#mac-server}

Un autre Mac peut servir de serveur. Sur ce Mac :

1. Choisissez **menu Pomme › Réglages Système**, cliquez sur **Général**, puis sur **Partage**.
2. Activez **Session à distance**.
3. Si le dépôt se trouve dans un dossier protégé, comme Documents ou Bureau, cliquez sur le bouton d’informations à côté de **Session à distance** et activez **Autoriser l’accès complet au disque pour les utilisateurs distants**.

Suivez ensuite cette page depuis votre propre Mac, avec l’adresse de ce Mac dans :ui[sshHosts.hostName].

## Voir aussi

- [Fonctionnement des dépôts sur un serveur](/guide/server/overview/)
- [Ajouter un dépôt sur un serveur](/guide/server/add/)
- [Configuration requise](/reference/requirements/#servers)
