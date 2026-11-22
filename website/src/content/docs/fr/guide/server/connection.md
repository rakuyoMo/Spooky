---
title: "État de la connexion et reconnexion"
description: "Comprenez l’état de la connexion, les demandes de mot de passe et de phrase secrète, les déconnexions et la reconnexion, et ce que vous pouvez encore voir une fois déconnecté."
---

Un dépôt sur un serveur dépend de sa connexion SSH. Cette page explique comment savoir s’il est connecté, ce que signifient les questions venues du serveur et ce qui se passe quand la connexion est coupée.

## État de la connexion {#status}

Dans un dépôt sur un serveur, un bandeau en haut de chaque liste affiche l’alias d’hôte et l’état de la connexion. Vous le trouverez dans la copie de travail, l’historique, les remisages, le reflog, l’historique d’un fichier et la liste des fichiers d’un commit.

| État | Ce qu’il signifie |
|---|---|
| :ui[connection.connecting] | Spooky ouvre la connexion. |
| :ui[connection.connected] | La connexion fonctionne. |
| :ui[connection.reconnecting] | La connexion a été coupée, et Spooky réessaie. |
| :ui[connection.unavailable] | La dernière tentative a échoué. Spooky réessaie 5 secondes plus tard. |

Tant que le dépôt n’est pas connecté, le bandeau devient jaune et en dit plus :

- Une note indiquant que Spooky affiche le dernier instantané obtenu avec succès, et que les écritures sont désactivées jusqu’au rétablissement de la connexion.
- La raison, comme :ui[remoteError.unavailable]. Cliquez dessus pour voir la sortie d’origine de SSH.
- Un bouton :ui[action.reconnect], tant que l’état est :ui[connection.unavailable].

::screenshot[Le haut de la copie de travail d’un dépôt sur un serveur qui a perdu sa connexion. Un bandeau indique que spooky-test est indisponible, avec un bouton Reconnecter. En dessous, une note indique que Spooky affiche le dernier instantané obtenu avec succès et que les écritures sont désactivées jusqu’au rétablissement de la connexion. Une ligne repliée indique que la connexion au serveur est indisponible.]{name="server-unavailable" frame="closeup"}

## Demandes de mot de passe et de phrase secrète {#prompts}

Spooky ouvre une session sur le serveur sans rien demander. Le Git du serveur a pourtant parfois besoin d’une réponse, par exemple un mot de passe quand vous poussez vers un dépôt distant via HTTPS. Spooky transmet la question à votre Mac et l’affiche dans une zone de dialogue :

| Zone de dialogue | Quand elle apparaît |
|---|---|
| :ui[callback.username.title], :ui[callback.password.title] | Un dépôt distant demande qui vous êtes. Cela arrive en général avec les dépôts distants joints via HTTPS. |
| :ui[callback.privateKey.title] | La clé SSH que le serveur utilise pour un dépôt distant est protégée par une phrase secrète. |
| :ui[signing.unlock] | Git a besoin de la phrase secrète de la clé de signature sur le serveur pour signer un commit ou un tag. |
| :ui[callback.editor] | Git veut que vous modifiiez un texte, comme un message. |

La première ligne de la zone de dialogue nomme le serveur. Une zone de dialogue de clé privée affiche aussi le chemin de la clé sur le serveur.

Pour un nom d’utilisateur ou un mot de passe, sélectionnez :ui[callback.saveKeychain] pour conserver la réponse. La prochaine fois que le Git de ce serveur pose la question, Spooky répond à partir du trousseau. Si vous avez ajouté un compte GitHub ou GitLab, Spooky répond d’abord avec ce compte. Consultez [Comptes d’hébergement](/guide/hosting/accounts/).

Quelques points à connaître :

- Chaque zone de dialogue attend 2 minutes. Si vous ne répondez pas à temps, Git ne reçoit aucune réponse, et la commande échoue.
- La récupération automatique ne demande jamais rien. Elle n’utilise que les comptes et les réponses enregistrées dans le trousseau. Si cela ne suffit pas, elle est annulée.
- Les zones de dialogue de phrase secrète pour le Git du serveur nécessitent OpenSSH 8.4 ou ultérieur sur le serveur.

## Déconnexions et reconnexion {#reconnect}

Quand la connexion est coupée, Spooky se reconnecte de lui-même. Après chaque tentative échouée, l’état affiche :ui[connection.unavailable]. Spooky réessaie 5 secondes plus tard. Pour réessayer tout de suite, cliquez sur :ui[action.reconnect]. Une fois la connexion rétablie, Spooky recharge le dépôt.

Les modifications que vous avez lancées ne sont pas répétées après une déconnexion :

- Les opérations en attente dans la file du dépôt sont annulées. Elles ne s’exécutent pas après la reconnexion. Relancez-les si vous en avez encore besoin.
- Une opération en cours au moment de la coupure n’est pas retentée. Après la reconnexion, Spooky vérifie la branche, le nombre de modifications, le verrou de l’index et si une fusion ou un rebasage est en cours.

Cette vérification apparaît dans la zone de dialogue :ui[recovery.title]. Elle vous dit si l’opération a seulement commencé et si le commit actuel a bougé. Regardez le résultat avant de retenter l’opération.

## Pendant une déconnexion {#offline}

Vous pouvez continuer à consulter ce que Spooky a lu en dernier : les listes, le fichier sélectionné et ses modifications. Tout ce qui modifie le dépôt est indisponible jusqu’au retour de la connexion.

Si le serveur est injoignable quand vous ouvrez un dépôt, la fenêtre affiche :ui[missing.unreachable.title]{1="driftwood-server"} avec la sortie de SSH. Cliquez sur :ui[action.refresh] pour réessayer, ou sur :ui[action.close] pour revenir à la fenêtre Dépôts.

:::tip
Exécutez `ssh -o BatchMode=yes driftwood-server git --version` dans Terminal, avec votre propre alias d’hôte. Si la commande échoue, le problème se situe entre votre Mac et le serveur, pas dans Spooky. Consultez [Tester la façon dont Spooky se connecte](/guide/server/prepare-ssh/#test).
:::

## Voir aussi

- [Préparer SSH](/guide/server/prepare-ssh/)
- [Ajouter un dépôt sur un serveur](/guide/server/add/)
- [Fonctionnement des dépôts sur un serveur](/guide/server/overview/)
