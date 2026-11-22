---
title: "Tags et dépôts distants"
description: "Créez, publiez et supprimez des tags, et ajoutez, modifiez, renommez et retirez des dépôts distants."
---

Les tags sont listés dans la barre latérale sous :ui[sidebar.tags], et les dépôts distants sous :ui[remote.group]. Chacun a son propre menu : cliquez dessus avec le bouton droit pour voir ce que vous pouvez en faire.

## Tags {#tags}

Un tag donne à un commit un nom qui ne bouge pas, en général pour une version comme `v0.4.0`. Contrairement à une branche, il ne se déplace pas quand vous validez.

Placez le pointeur sur un tag pour voir le commit qu’il désigne, et son message s’il en a un. Double-cliquez sur un tag pour extraire son commit. Consultez [Extraire un tag ou un commit](/guide/branches/branches/#checkout-revision).

Comme les branches, les tags dont le nom contient un `/` sont rangés dans des dossiers. Pour n’afficher que les plus récents, ou les trier dans l’autre sens, consultez [Filtrer et grouper](/guide/branches/branches/#filter).

### Créer un tag {#create-tag}

1. Choisissez :ui[menu.repository > tag.createMenu] (<kbd>⇧⌘T</kbd>). Vous pouvez aussi cliquer sur le bouton d’ajout en bas de la barre latérale et le choisir dans le menu. Pour créer un tag sur une branche ou un commit précis, cliquez plutôt dessus avec le bouton droit et choisissez :ui[tag.createFrom]{1="main"} dans le menu.
2. Saisissez le nom dans :ui[reference.name].
3. :ui[tag.revision] est le commit qui reçoit le tag. Au début, c’est la branche actuelle, ou l’élément sur lequel vous avez cliqué avec le bouton droit.
4. Rédigez un :ui[tag.messageField] si vous le souhaitez. Sans message, le tag n’est qu’un nom pour le commit. Avec un message, Git enregistre aussi qui a créé le tag et quand.
5. Pour signer le tag, sélectionnez :ui[tag.sign], et choisissez une clé dans :ui[tag.signingKey]. :ui[tag.signingKey.configured] utilise la clé configurée dans Git. Un tag signé doit avoir un message. Spooky retient si vous signez.
6. Cliquez sur :ui[tag.create.submit].

Vous pouvez aussi faire glisser un commit ou une branche locale sur :ui[sidebar.tags] ou sur un dossier de tags.

Un nouveau tag n’existe que dans ce dépôt tant que vous ne le publiez pas. Pour le retirer, choisissez :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

### Publier un tag {#publish-tag}

1. Cliquez avec le bouton droit sur le tag et choisissez :ui[tag.publishMenu]{1="v0.4.0"} dans le menu, ou choisissez :ui[menu.repository > tag.publishMainMenu] dans la barre des menus. Vous pouvez aussi faire glisser le tag sur un dépôt distant.
2. Vérifiez :ui[tag.local] et :ui[sync.remote]. Le dépôt distant est celui que suit votre branche actuelle, sauf si vous avez fait glisser le tag sur un autre.
3. Sélectionnez :ui[sync.skipHooks] pour pousser sans exécuter les crochets Git du dépôt.
4. Cliquez sur :ui[tag.publish].

La publication d’un tag peut être annulée. L’annulation le supprime de nouveau sur le dépôt distant.

Pour pousser tous les tags vers un dépôt distant en une fois, cliquez avec le bouton droit sur le dépôt distant et choisissez :ui[tag.pushAll]{1="origin"} dans le menu. La zone de dialogue de poussée peut aussi envoyer tous les tags. Consultez [Pousser](/guide/branches/sync/#push).

### Supprimer un tag {#delete-tag}

Cliquez avec le bouton droit sur le tag et choisissez :ui[reference.deleteMenu]{1="v0.1.0"} dans le menu. Vous pouvez aussi sélectionner un ou plusieurs tags et appuyer sur <kbd>⌘⌫</kbd> quand la barre latérale est active.

Spooky demande toujours confirmation. Pour supprimer aussi le tag sur un dépôt distant, sélectionnez :ui[tag.deleteRemote] et choisissez le dépôt distant dans :ui[sync.remote].

La suppression d’un tag dans ce dépôt uniquement peut être annulée. Sa suppression sur un dépôt distant ne le peut pas.

## Dépôts distants {#remotes}

Un dépôt distant est une autre copie du dépôt, depuis laquelle vous récupérez et vers laquelle vous poussez, souvent sur un service d’hébergement. Celui depuis lequel vous avez cloné s’appelle en général `origin`.

Sous :ui[remote.group], chaque dépôt distant liste ses branches. Placez le pointeur sur un dépôt distant pour voir ses URL de récupération et de poussée.

Cliquez avec le bouton droit sur un dépôt distant pour afficher son menu :

- :ui[remote.fetchMenu]{1="origin"} et :ui[sync.prune] ouvrent la zone de dialogue de récupération pour ce dépôt distant. Consultez [Récupérer](/guide/branches/sync/#fetch).
- :ui[remote.viewInBrowser]{1="origin"} ouvre la page web du dépôt distant. Cela fonctionne avec les URL HTTP(S), SSH et `git://`, mais pas avec les chemins locaux.
- Les autres éléments ajoutent, modifient, renomment et suppriment des dépôts distants, comme décrit ci-dessous.

:::note[Dépôts sur un serveur]
Les dépôts distants sont contactés depuis le serveur, avec le réseau et les clés SSH du serveur. Une URL qui fonctionne sur votre Mac peut ne pas fonctionner depuis le serveur.
:::

### Ajouter un dépôt distant {#add-remote}

1. Choisissez :ui[menu.repository > remote.addMainMenu] dans la barre des menus. Vous pouvez aussi cliquer sur le bouton d’ajout en bas de la barre latérale, ou cliquer avec le bouton droit sur :ui[remote.group], puis choisir :ui[remote.addMenu] dans le menu.
2. Saisissez un nom court dans :ui[reference.name], comme `upstream`.
3. Collez l’adresse dans :ui[remote.url].
4. Cliquez sur :ui[remote.add.submit].

Spooky vérifie la connexion avant d’ajouter le dépôt distant. S’il ne parvient pas à se connecter, la zone de dialogue reste ouverte. Vous pouvez corriger une faute de frappe et réessayer. Une fois le dépôt distant ajouté, Spooky le récupère tout de suite.

### Réglages d’un dépôt distant {#remote-settings}

Cliquez sur un dépôt distant dans la barre latérale pour ouvrir ses réglages. Le sélecteur du haut propose deux pages :

- :ui[remote.page.general] montre comment Git communique avec le dépôt distant.
- :ui[remote.page.branches] liste les branches du dépôt distant avec le commit que chacune désigne.

Placez le pointeur sur une ligne de :ui[remote.page.general] pour afficher ses boutons.

| Réglage | Ce qu’il fait |
|---|---|
| :ui[remote.field.fetchURL] | L’adresse depuis laquelle Spooky récupère. Vous pouvez aussi la modifier en cliquant avec le bouton droit sur le dépôt distant et en choisissant :ui[remote.editConnection]. |
| :ui[remote.skipFetchAll] | Exclut ce dépôt distant de la récupération automatique et de :ui[sync.fetchAll]. |
| :ui[remote.field.fetchRefspecs] | Les branches à récupérer, et où les garder. |
| :ui[remote.field.pushURL] | L’adresse vers laquelle Spooky pousse. Tant que vous n’en définissez pas, la poussée utilise l’URL de récupération, affichée en gris. :ui[remote.action.unset] y revient. |
| :ui[remote.field.pushRefspecs] | Les branches à pousser, et vers où. |

Une refspec est une règle qui fait correspondre les noms de branches d’un côté à des noms de l’autre. La plupart des dépôts distants n’ont besoin que de celle que Git configure. Pour en ajouter une, cliquez sur :ui[remote.action.addRefspec] à côté de :ui[remote.group.fetch] ou de :ui[remote.group.push].

Spooky vérifie une nouvelle URL avant de l’enregistrer. Les modifications des réglages d’un dépôt distant peuvent être annulées.

### Renommer ou retirer un dépôt distant {#rename-remote}

Cliquez avec le bouton droit sur le dépôt distant et choisissez :ui[reference.renameMenu]{1="origin"} ou :ui[reference.deleteMenu]{1="origin"} dans le menu.

Retirer un dépôt distant le retire de ce dépôt, avec ses branches distantes. Le dépôt qu’il désigne ne change pas. Le changement de nom et le retrait peuvent tous deux être annulés.

## Voir aussi

- [Branches](/guide/branches/branches/)
- [Récupérer, tirer et pousser](/guide/branches/sync/)
- [Annulation et récupération](/guide/work/undo/)
