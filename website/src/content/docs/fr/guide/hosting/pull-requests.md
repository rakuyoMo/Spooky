---
title: "Pull requests et merge requests"
description: "Listez, créez, commentez, extrayez, fusionnez et fermez des pull requests sur GitHub et des merge requests sur GitLab."
---

Spooky affiche les pull requests ouvertes sur GitHub et les merge requests ouvertes sur GitLab pour le dépôt distant d’un dépôt. Vous pouvez les lire et en discuter, les extraire, les fusionner et en créer, sans quitter la fenêtre du dépôt.

Il faut pour cela un [compte d’hébergement](/guide/hosting/accounts/) pour le dépôt distant. Quand le dépôt distant est sur GitLab, la barre latérale, les menus et les zones de dialogue indiquent merge request au lieu de pull request.

## Ouvrir la liste {#list}

Cliquez sur :ui[pr.title] dans la barre latérale, ou choisissez :ui[menu.view > pr.show.menu] (<kbd>⌘4</kbd>).

Choisissez un dépôt distant dans le menu en haut de la liste. Chaque ligne affiche :

- Le titre, marqué :ui[pullRequests.state.draft] pour les brouillons
- Le numéro, l’auteur et la date d’ouverture
- La branche source et la branche de destination. Pour une requête venant d’un fork, la branche source est accompagnée de son projet.

Faites défiler jusqu’en bas pour en charger d’autres. Les requêtes fermées et fusionnées ne sont pas listées.

Si la liste ne peut pas se charger, elle indique pourquoi. Les requêtes déjà chargées restent en dessous. Quand le jeton du compte est rejeté ou qu’il lui manque une portée, vous pouvez cliquer sur :ui[accounts.reauthenticate] directement à cet endroit.

Quand la liste ne sait pas quel compte utiliser, consultez [Quel compte un dépôt distant utilise](/guide/hosting/accounts/#remotes).

## Lire une requête {#details}

Sélectionnez une requête pour l’afficher à droite. Passez d’une vue à l’autre en haut, parmi trois :

- :ui[pullRequests.conversation] : le titre et l’état, la description, les commentaires, et les commits groupés par jour, du plus ancien au plus récent.
- :ui[pullRequests.commits] : les commits de la requête. La barre du dessus liste les contributeurs et le nombre de commits.
- :ui[pullRequests.changeset] : ce que la requête modifie, par rapport à l’endroit où sa branche source s’est séparée.

Dans la conversation, double-cliquez sur un commit ou appuyez sur <kbd>Retour</kbd> pour l’ouvrir. Cliquez avec le bouton droit sur un commit pour copier son hash. Cliquez sur un lien dans le texte pour l’ouvrir.

:ui[pullRequests.commits] et :ui[pullRequests.changeset] ont besoin des commits de la requête dans votre dépôt. S’ils n’y sont pas encore, cliquez sur :ui[pullRequests.fetch]. Spooky les récupère depuis le dépôt distant sans modifier vos branches.

## Créer une requête {#create}

La branche source doit déjà se trouver sur un dépôt distant. Poussez-la d’abord, puis faites l’une de ces actions :

- Cliquez sur le bouton d’ajout en haut de la liste.
- Choisissez :ui[menu.repository > pr.create.menu] (<kbd>⌃⌘P</kbd>).
- Cliquez avec le bouton droit sur une branche dans la barre latérale et choisissez :ui[pr.forBranch.create]{1="feature/units-toggle"} dans le menu. Si la branche a déjà une requête ouverte, l’élément s’appelle :ui[pr.forBranch.show]{1="feature/units-toggle"}.

Dans la zone de dialogue :

1. À côté de :ui[pullRequests.source] et de :ui[pullRequests.target], choisissez un dépôt distant et l’une de ses branches. Au début, la source est la branche sur laquelle vous avez cliqué avec le bouton droit ou la branche actuelle, et la cible est la branche par défaut du dépôt distant. Seuls les dépôts distants situés sur la même instance que le compte sont listés. Une source située dans un autre projet donne une requête venant d’un fork.
2. Au début, le titre est le nom de la branche source. La description est facultative.
3. Cliquez sur :ui[pr.create.submit].

La source et la cible ne peuvent pas être la même branche.

## Discuter {#discuss}

Pour ajouter un commentaire, cliquez sur :ui[pullRequests.addComment] à la fin de la conversation, ou appuyez sur <kbd>⌘S</kbd>.

Pour vos propres commentaires, utilisez :ui[pullRequests.comment.edit] et :ui[pullRequests.comment.delete] sur le commentaire, ou cliquez dessus avec le bouton droit. Un double-clic sur votre commentaire l’ouvre aussi pour modification. La suppression d’un commentaire ne peut pas être annulée.

Sur GitLab, vous pouvez aussi répondre à n’importe quel commentaire avec :ui[pullRequests.comment.reply]. La réponse rejoint la même discussion sur GitLab.

Pour votre propre requête, vous pouvez aussi :

- Modifier la description : cliquez sur :ui[pullRequests.edit] à côté d’elle, ou cliquez dessus avec le bouton droit et choisissez :ui[pullRequests.editDescription.menu] dans le menu.
- Modifier le titre, la description et la branche cible : double-cliquez sur la requête dans la liste, ou cliquez dessus avec le bouton droit et choisissez :ui[pr.edit.menu]{1="#12"} dans le menu. La source et le projet cible restent tels quels.

## Extraire une requête {#checkout}

Pour travailler sur le code d’une requête, cliquez sur :ui[pullRequests.checkout] en bas des détails, ou cliquez avec le bouton droit sur la requête et choisissez :ui[pr.checkout.menu]{1="#12"} dans le menu.

Saisissez un nom pour la branche locale et cliquez sur :ui[pullRequests.checkout]. Au début, c’est le nom de la branche source. Pour une requête venant d’un fork, c’est `pullrequests/<author>/<branch>`.

Spooky récupère d’abord les commits de la requête, puis extrait la branche :

- Si une branche locale de ce nom pointe déjà sur ces commits, Spooky l’extrait.
- Si elle pointe ailleurs, la zone de dialogue l’indique. Choisissez un autre nom.
- Sinon, Spooky crée la branche. Pour une requête du même projet, elle suit la branche source sur le dépôt distant, à condition que celle-ci soit sur le même commit.

Si des fichiers suivis sont modifiés, Spooky demande s’il faut d’abord les remiser. Consultez [Remisage automatique](/guide/work/stash/#auto-stash).

L’extraction n’est pas disponible quand la branche locale qui suit la branche source a des commits que vous n’avez pas poussés. Elle ne l’est pas non plus quand cette branche est la branche actuelle et se trouve déjà sur le commit de la requête.

## Fusionner une requête {#merge}

Cliquez sur :ui[pullRequests.merge] en bas des détails. La fusion se fait sur le service d’hébergement. Elle ne peut pas être annulée.

- **GitHub** : choisissez un :ui[pullRequests.mergeType] parmi ceux que le dépôt autorise : :ui[pullRequests.method.merge], :ui[pullRequests.method.rebase] ou :ui[pullRequests.method.squash]. Spooky propose celui que vous avez utilisé la dernière fois.
- **GitLab** : la zone de dialogue affiche la :ui[pullRequests.mergeStrategy] du projet. Sélectionnez :ui[pullRequests.squash] pour fusionner les commits en un seul. L’option est absente quand le projet ne l’autorise pas. Elle reste activée quand le projet l’exige.

:ui[pullRequests.deleteBranch] supprime la branche source sur le service. Au début, l’option reprend le réglage du projet.

Si la requête ne peut pas être fusionnée, la zone de dialogue indique pourquoi. Par exemple, c’est un brouillon, elle a des conflits, votre compte n’a pas le droit de fusionner, ou le service vérifie encore.

Après la fusion, Spooky récupère depuis le dépôt distant pour mettre ses branches à jour.

## Fermer une requête {#close}

Cliquez sur :ui[pullRequests.close] en bas des détails, puis confirmez. Pour la rouvrir, rendez-vous sur le service d’hébergement.

:::note[Dépôts sur un serveur]
La liste et tout ce que vous faites sur le service partent de votre Mac. La récupération des commits d’une requête, son extraction et la récupération après une fusion s’exécutent sur le serveur. Il en va de même pour les comparaisons dans :ui[pullRequests.commits] et :ui[pullRequests.changeset].
:::

Chaque requête envoyée au service apparaît sur la page :ui[activity.service] de la fenêtre :ui[activity.title].

## Voir aussi

- [Comptes d’hébergement](/guide/hosting/accounts/)
- [Branches](/guide/branches/branches/)
- [Revue des branches](/guide/branches/review/)
