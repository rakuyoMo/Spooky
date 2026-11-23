---
title: "La fenêtre Dépôts"
description: "Ajoutez des signets, regroupez, ouvrez, clonez, créez, recherchez et retirez des dépôts, et retrouvez ceux qui sont devenus introuvables."
---

La fenêtre Dépôts tient la liste des dépôts avec lesquels vous travaillez, sur votre Mac et sur des serveurs. Chaque entrée est un signet qui pointe vers un dépôt. Quand vous retirez un signet, le dossier du dépôt reste où il est. Placer le dossier dans la Corbeille est un choix distinct. Cette page couvre l’ajout, l’organisation, l’ouverture et le retrait des dépôts.

Pour accéder à la liste depuis un dépôt, cliquez sur :ui[toolbar.bookmarks] dans la barre d’outils ou choisissez :ui[menu.view > menu.showRepositories] (<kbd>⌃⌘R</kbd>).

::screenshot[La fenêtre Dépôts. La barre latérale liste deux groupes, Driftwood Labs et Notes, avec des dépôts à l’intérieur ; l’un d’eux est un dépôt sur un serveur, dont le nom commence par son alias d’hôte. À droite figurent les détails du dépôt sélectionné, driftwood : son emplacement, sa dernière ouverture, son dernier commit, une description, l’identité du validateur, la branche actuelle, le nombre de fichiers modifiés et le dépôt distant.]{name="repositories" frame="window"}

## Ajouter des dépôts {#add}

Le bouton d’ajout, en bas de la barre latérale, ouvre un menu pour compléter la liste :

| Élément de menu | Ce qu’il fait |
|---|---|
| :ui[bookmarks.newGroup] | Ajoute un groupe sous la sélection, prêt à recevoir son nom |
| :ui[bookmarks.add] | Ajoute des dépôts déjà présents sur votre Mac. Vous pouvez sélectionner plusieurs dossiers à la fois. |
| :ui[action.addRemote] | Ajoute un dépôt sur un serveur. Consultez [Ajouter un dépôt sur un serveur](/guide/server/add/). |
| :ui[bookmarks.create] | Crée un dépôt vide. Consultez [Créer un dépôt](#create). |
| :ui[clone.menu] | Copie un dépôt depuis un dépôt distant. Consultez [Cloner un dépôt](#clone). |
| :ui[scan.menu] | Trouve les dépôts contenus dans un dossier. Consultez [Rechercher des dépôts](#scan). |

Les nouvelles entrées vont dans le groupe sélectionné. Vous pouvez aussi faire glisser des dossiers de dépôt du Finder vers la liste. Si vous ouvrez un dépôt avec :ui[menu.file > action.openLocal] et qu’il n’est pas encore dans la liste, il est ajouté à la fin.

### Créer un dépôt {#create}

1. Choisissez :ui[bookmarks.create] dans le menu du bouton d’ajout.
2. Dans :ui[bookmarks.create.name], tapez le nom du nouveau dépôt. C’est aussi le nom de son dossier.
3. À côté de :ui[bookmarks.create.location], cliquez sur :ui[bookmarks.create.choose] pour choisir le dossier où le créer. Le choix part de votre dossier de départ.
4. Cliquez sur :ui[bookmarks.create.submit].

Spooky crée le dossier, en fait un dépôt Git vide, l’ajoute au groupe sélectionné et l’ouvre.

### Cloner un dépôt {#clone}

Le clonage copie un dépôt et son historique depuis un dépôt distant dans un nouveau dossier.

1. Dans le menu du bouton d’ajout, choisissez :ui[clone.menu], ou appuyez sur <kbd>⌃⌘C</kbd>.
2. Dans :ui[clone.url], saisissez l’adresse du dépôt, par exemple une adresse qui commence par `https://` ou `git@`.
3. Dans :ui[clone.to], choisissez :ui[clone.machine.local] ou un serveur. Les serveurs que vous utilisez déjà figurent dans la liste. Pour en utiliser un autre, choisissez :ui[clone.machine.other] et saisissez son :ui[remote.host].
4. Dans :ui[clone.directory], choisissez le dossier de destination. Spooky y crée un dossier qui porte le nom du dépôt.
5. Laissez :ui[clone.submodules] sélectionné pour extraire aussi les sous-modules du dépôt. Sélectionnez :ui[clone.lfs] si le dépôt garde des fichiers volumineux dans Git LFS.
6. Cliquez sur :ui[clone.submit].

Spooky vérifie d’abord qu’il peut joindre le dépôt distant. S’il n’y arrive pas, la zone de dialogue reste ouverte et indique pourquoi. Corrigez l’adresse et réessayez. S’il y arrive, la zone de dialogue se ferme et le clonage se poursuit en arrière-plan. Sa progression s’affiche sur la ligne du dépôt dans la liste. Quand le clonage est terminé, Spooky envoie une notification :ui[clone.notification.title].

Sur votre Mac, le choix du dossier part de votre dossier de départ, ou du dossier défini dans :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.cloneDirectory]. Consultez [Clonage et terminal](/guide/settings/general/#cloning).

Tant que vous avez des clones récents, :ui[toolbar.clone] apparaît dans la barre d’outils. Cliquez dessus pour voir :ui[clone.recent.title]. Vous pouvez y arrêter un clonage en cours, relancer un clonage échoué ou annulé avec :ui[clone.retry], ou le retirer de la liste avec :ui[clone.remove]. Double-cliquez sur un clone terminé pour l’ouvrir. :ui[clone.recent.clear] vide la liste.

:::note[Dépôts sur un serveur]
Quand vous clonez sur un serveur, Spooky vérifie la connexion et y exécute le clonage. Le nouveau dépôt est ajouté comme dépôt sur un serveur. Pour le dossier, tapez un chemin absolu sur le serveur, ou cliquez sur :ui[clone.browse] pour en choisir un. Spooky retient le dernier dossier utilisé sur chaque serveur.
:::

Vous pouvez aussi faire glisser l’adresse d’un dépôt dans la liste pour lancer un clonage. Un lien peut en lancer un également. Consultez [Fenêtres et navigation](/guide/repositories/navigation/).

### Rechercher des dépôts {#scan}

1. Choisissez :ui[scan.menu] dans le menu du bouton d’ajout.
2. Dans :ui[scan.in], choisissez :ui[clone.machine.local] ou un serveur, puis le dossier à explorer.
3. Cliquez sur :ui[scan.start]. Les dépôts apparaissent à mesure que Spooky les trouve. Pour arrêter, cliquez sur :ui[scan.stop].
4. Tous les dépôts trouvés sont sélectionnés. Désélectionnez ceux dont vous ne voulez pas, puis cliquez sur :ui[scan.add].

Les dépôts déjà présents dans la liste ne sont pas proposés à nouveau. Vous pouvez explorer plusieurs dossiers ou serveurs l’un après l’autre. Les résultats s’additionnent.

## Organiser la liste {#organize}

- Pour ajouter un groupe, choisissez :ui[bookmarks.newGroup] dans le menu du bouton d’ajout, puis tapez un nom.
- Pour réordonner des entrées ou les déplacer dans un autre groupe, faites-les glisser.
- Pour renommer une entrée, sélectionnez-la et appuyez sur <kbd>↩</kbd>, ou cliquez dessus avec le bouton droit et choisissez :ui[bookmarks.rename]. Renommer un dépôt dans la liste ne renomme pas son dossier.
- Pour trier par nom, cliquez avec le bouton droit et choisissez :ui[bookmarks.sortChildren] pour trier les entrées d’un groupe, ou :ui[bookmarks.sortParent] pour trier le groupe où se trouve une entrée.

Deux options de :ui[app.name > settings.title] › :ui[settings.general] changent ce que la liste affiche :

- :ui[settings.showWorktreesInRepositoryList] : un dépôt qui a d’autres worktrees peut être développé pour les lister. Un worktree s’ouvre comme un dépôt. Désactivé par défaut.
- :ui[settings.showHostAliasesInRepositoryList] : le nom des dépôts sur un serveur commence par leur alias d’hôte. Activé par défaut.

Consultez [Fenêtres et liste Dépôts](/guide/settings/general/#windows).

## Ouvrir un dépôt {#open}

Double-cliquez sur un dépôt. Il s’ouvre dans la même fenêtre, à la place de la liste. Si le dépôt est déjà ouvert dans une autre fenêtre, Spooky place plutôt cette fenêtre au premier plan.

Cliquez sur un dépôt avec le bouton droit pour d’autres choix :

- :ui[bookmarks.open]{1="driftwood"} et :ui[bookmarks.openNewWindow]{1="driftwood"}
- :ui[action.revealFinder], :ui[action.copyPath] et :ui[action.openTerminal]

Les détails, à droite, ont aussi les boutons :ui[action.open] et :ui[bookmarks.multiple.delete]. Cliquez-y sur :ui[bookmarks.detail.edit] pour modifier :ui[bookmarks.detail.description] et :ui[bookmarks.detail.identity]. :ui[bookmarks.detail.unset] retire l’identité définie rien que pour ce dépôt. À côté de chaque dépôt distant, :ui[bookmarks.detail.viewInBrowser] ouvre sa page web. La description et l’identité sont celles que vous voyez dans [Réglages du dépôt](/guide/settings/identity/#repository).

:::note[Dépôts sur un serveur]
:ui[action.copyPath] copie le chemin précédé de l’alias d’hôte, sous la forme `alias:/path/to/repository`. Spooky ne lit les détails d’un dépôt sur un serveur que lorsque vous le sélectionnez. En sélectionner un peut établir une connexion au serveur.
:::

## Dépôts introuvables {#missing}

Si le dossier d’un dépôt est déplacé, renommé ou supprimé, son nom devient gris dans la liste, avec un signe d’avertissement. Ses détails indiquent :ui[bookmarks.detail.missing] Spooky vérifie les dépôts de votre Mac chaque fois que la liste apparaît.

Si vous ouvrez un dépôt introuvable, la fenêtre affiche :ui[missing.title]. Cliquez sur :ui[action.refresh] pour vérifier à nouveau, par exemple après avoir reconnecté un disque. Cliquez sur :ui[action.close] pour revenir à la liste.

Pour réparer l’entrée, retirez-la et ajoutez à nouveau le dépôt depuis son emplacement actuel.

:::note[Dépôts sur un serveur]
Spooky ne vérifie un dépôt sur un serveur que lorsque vous le sélectionnez ou l’ouvrez. Si Spooky ne peut pas joindre le serveur, la fenêtre affiche :ui[missing.unreachable.title]{1="alias"} et montre ce que SSH a signalé. Consultez [État de la connexion et reconnexion](/guide/server/connection/).
:::

## Retirer des dépôts {#delete}

Sélectionnez une ou plusieurs entrées, puis effectuez l’une des opérations suivantes :

- Appuyez sur <kbd>⌫</kbd>.
- Cliquez avec le bouton droit et choisissez :ui[bookmarks.delete]{1="driftwood"}, :ui[bookmarks.deleteFolder] pour un groupe, ou :ui[bookmarks.deleteMultiple]{1="2"} pour plusieurs entrées.
- Cliquez sur :ui[bookmarks.multiple.delete] dans les détails.

Si le dossier du dépôt existe encore, Spooky demande d’abord :ui[bookmarks.delete.title]{1="driftwood"}. Seuls les signets sont retirés. Les dossiers restent où ils sont. Pour les placer aussi dans la Corbeille, sélectionnez :ui[bookmarks.delete.trash]. Cliquez sur :ui[bookmarks.delete.submit] pour confirmer.

Les groupes vides et les entrées dont le dossier a disparu sont retirés tout de suite, sans confirmation.

:::caution
Le placement dans la Corbeille emporte tout le dossier du dépôt, y compris les modifications que vous n’avez pas validées. Vous pouvez le récupérer tant que vous n’avez pas vidé la Corbeille. La case de la Corbeille est décochée à chaque ouverture de la zone de dialogue.
:::

Si un dossier ne peut pas être déplacé, Spooky affiche :ui[bookmarks.trashFailed.title] et liste les dossiers restés en place. Spooky ne place jamais dans la Corbeille votre dossier de départ, un dossier qui le contient, ni le niveau supérieur d’un disque.

:::note[Dépôts sur un serveur]
Spooky demande toujours confirmation avant de retirer un dépôt sur un serveur. Son dossier va dans la Corbeille de ce serveur, pas dans celle de votre Mac. Si le dossier n’est plus sur le serveur, la case de la Corbeille est estompée et seul le signet est retiré.
:::

## Voir aussi

- [Fenêtres et navigation](/guide/repositories/navigation/)
- [Ajouter un dépôt sur un serveur](/guide/server/add/)
- [Worktrees](/guide/advanced/worktrees/)
