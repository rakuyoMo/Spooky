---
title: "Votre premier dépôt"
description: "Ouvrez un dépôt sur votre Mac, puis modifiez, indexez, validez et poussez votre travail du début à la fin."
---

Cette page vous fait parcourir un cycle de travail complet. Vous ouvrez un dépôt sur votre Mac, modifiez un fichier, indexez la modification, la validez, puis poussez le commit vers un dépôt distant.

Il vous faut un dépôt Git sur votre Mac, avec un dépôt distant vers lequel vous pouvez pousser. Si vous n’en avez pas encore, [La fenêtre Dépôts](/guide/repositories/manager/) montre comment en cloner ou en créer un.

## Ouvrir le dépôt {#open}

1. Choisissez :ui[menu.file > action.openLocal] (<kbd>⌘O</kbd>).
2. Sélectionnez le dossier du dépôt, puis cliquez sur :ui[repositories.panel.prompt].

Spooky ouvre le dépôt et affiche sa vue :ui[workspace.title]. Il ajoute aussi le dépôt à la liste Dépôts. La prochaine fois, vous pourrez l’ouvrir à partir de là.

Vous pouvez choisir n’importe quel dossier à l’intérieur du dépôt. Spooky ouvre le dépôt entier. Si le dossier ne fait pas partie d’un dépôt Git, Spooky affiche :ui[bookmarks.noRepository.title]. Cliquez sur :ui[bookmarks.noRepository.create] pour faire du dossier un nouveau dépôt, ou sur :ui[action.cancel] pour en choisir un autre.

:::note[Dépôts sur un serveur]
Pour travailler dans un dépôt sur un serveur, ajoutez-le plutôt avec :ui[action.addRemote]. [Ajouter un dépôt sur un serveur](/guide/server/add/) montre comment faire. Une fois le dépôt ouvert, le reste de cette page s’applique de la même façon.
:::

## Faire une modification {#change}

Modifiez un fichier du dépôt avec n’importe quel éditeur et enregistrez-le. Spooky remarque la modification et liste le fichier dans :ui[workspace.title]. Si une modification n’apparaît pas, cliquez sur :ui[action.refresh] ou appuyez sur <kbd>⌘R</kbd>.

Sélectionnez le fichier pour voir ce qui a changé dans la colonne de droite. Les lignes ajoutées sont en vert, les lignes supprimées en rouge.

## Indexer la modification {#stage}

Git ne valide pas tout ce que vous avez modifié. Il ne valide que ce que vous indexez. L’indexation vous permet de choisir les modifications qui entrent dans le prochain commit. Tout le reste demeure dans la copie de travail pour plus tard.

Pour indexer un fichier, effectuez l’une des opérations suivantes :

- Cochez la case devant le fichier.
- Sélectionnez un ou plusieurs fichiers et appuyez sur <kbd>Espace</kbd>.
- Cliquez sur :ui[working.stageAll] pour indexer tous les fichiers modifiés.

La case des fichiers indexés reste cochée. Pour n’indexer que certaines lignes d’un fichier, consultez [Examiner et indexer les modifications](/guide/work/diff/).

## Valider {#commit}

Un commit enregistre les modifications indexées dans l’historique du dépôt. Il s’accompagne d’un message qui dit ce que vous avez modifié et pourquoi.

1. Cliquez sur :ui[working.subject] et tapez un bref résumé de la modification. La zone de commit s’agrandit pendant la saisie.
2. Si vous voulez en dire plus, écrivez-le dans :ui[working.body].
3. Cliquez sur :ui[working.commit], ou appuyez sur <kbd>⌘↩</kbd>.

::screenshot[La zone de commit, avec l’objet « Add gust alerts and a humidity chart » saisi. En dessous se trouvent une description détaillée vide, les cases Corriger et Signer, le nom et l’adresse e-mail de l’auteur, et les boutons Tout indexer et Valider. La liste de fichiers, plus bas, montre trois fichiers dont la case est cochée.]{name="start-commit" frame="closeup"}

Quelques points sur la zone de commit agrandie :

- Le nombre au bout du champ d’objet compte les caractères qu’il vous reste. Au-delà, l’objet dépasse la longueur recommandée.
- :ui[working.commit] reste estompé tant que l’objet est vide.
- Le nom et l’adresse e-mail à droite sont enregistrés dans le commit comme ceux de son auteur. Pour les changer, consultez [Profils utilisateur et configuration Git](/guide/settings/identity/).
- :ui[working.amend] et :ui[commit.signOff] sont expliqués dans [Valider des modifications](/guide/work/commit/).

Après le commit, les fichiers validés quittent la liste. Dans la barre latérale, la branche actuelle affiche maintenant ↑1. C’est un commit présent sur votre Mac qui n’est pas encore sur le dépôt distant.

## Pousser {#push}

Pousser envoie vos commits vers le dépôt distant. Les autres peuvent les y récupérer, et le dépôt distant en garde une copie de sauvegarde.

1. Cliquez sur :ui[sync.push] dans la barre d’outils, ou choisissez :ui[menu.repository > sync.pushMenu] (<kbd>⇧⌘U</kbd>).
2. Vérifiez que :ui[sync.destination] est bien la branche distante vers laquelle vous voulez pousser. Si la branche suit déjà une branche distante, celle-ci est sélectionnée.
3. Cliquez sur :ui[sync.pushHead].

::screenshot[La zone de dialogue Pousser HEAD. Elle pousse les nouveaux commits de la branche locale « main » vers la destination origin/main. En dessous se trouvent une section Options repliée et les boutons Annuler et Pousser HEAD.]{name="sync" frame="dialog"}

Une fois la poussée terminée, le ↑1 à côté de la branche disparaît. [Pousser](/guide/branches/sync/#push) décrit les :ui[dialog.options]. Pour pousser une branche pour la première fois, consultez [Publier une branche](/guide/branches/sync/#publish).

:::tip
Maintenez <kbd>⌥</kbd> enfoncée et cliquez sur le bouton :ui[sync.push]. Il devient :ui[sync.quickPush] et pousse tout de suite la branche actuelle vers sa branche amont, sans la zone de dialogue.
:::

## Voir aussi

- [Copie de travail](/guide/work/working-copy/)
- [Valider des modifications](/guide/work/commit/)
- [Récupérer, tirer et pousser](/guide/branches/sync/)
