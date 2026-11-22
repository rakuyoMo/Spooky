---
title: "File d’attente et activité"
description: "Voyez comment Spooky met les opérations d’écriture en file d’attente, suivez-les et annulez-les dans la zone d’activité de la barre latérale et dans la fenêtre Activité, et recevez des notifications du système."
---

Spooky modifie un dépôt une opération à la fois. Si vous lancez quelque chose pendant qu’une autre opération est en cours, la vôtre attend son tour au lieu d’être refusée. Le chargement de l’état, de l’historique et des diffs n’attend pas.

## Comment les opérations sont mises en file d’attente {#queue}

Quand rien ne s’exécute dans le dépôt, une opération démarre aussitôt. Sinon, elle rejoint la file d’attente du dépôt, et les opérations s’exécutent dans l’ordre où vous les avez lancées. Toutes les fenêtres qui affichent le dépôt partagent la même file.

Cela concerne tout ce qui modifie le dépôt, où que vous le lanciez : les menus, la barre d’outils, les menus contextuels, les Actions rapides, le glisser-déposer, les doubles-clics, les zones de dialogue, la liste de fichiers et la zone de commit.

- Les éléments de menu et les boutons restent disponibles pendant que le dépôt est occupé. Une zone de dialogue se ferme quand vous cliquez sur son bouton, comme d’habitude.
- Si une opération demande une confirmation, comme la suppression d’une branche ou une poussée forcée, elle la demande au moment où vous cliquez. Elle ne la redemande pas quand son tour arrive.
- Les questions qui dépendent de l’état du dépôt à ce moment-là, comme celle de remiser ou non les modifications qui gênent, se posent quand son tour arrive.

Pendant qu’une opération qui modifie la copie de travail ou l’index s’exécute, la liste de fichiers est estompée, même si vous avez lancé l’opération dans une autre fenêtre. Les autres opérations, comme récupérer et pousser, laissent la liste de fichiers telle quelle, et ce que vous y faites rejoint la file.

Un commit en attente garde son message et ses options verrouillés jusqu’à son exécution.

## Quand son tour arrive {#turn}

Une fois l’opération précédente terminée et la fenêtre actualisée, Spooky confronte la suivante au dépôt tel qu’il est maintenant. Il utilise les mêmes règles que celles qui décident si l’élément de menu est disponible. Si l’opération n’a plus de sens, par exemple parce que la branche sur laquelle elle porte a disparu, elle ne s’exécute pas. Son enregistrement indique :ui[activity.skipped], avec la raison.

Si une opération échoue, tout ce qui est en file d’attente après elle est annulé, pour que rien ne s’exécute par-dessus l’échec. Leurs enregistrements indiquent quelle opération a échoué. Si vous arrêtez vous-même une opération en cours, seule celle-ci s’arrête, et les autres continuent.

Les opérations en file d’attente sont aussi annulées quand :

- La connexion à un dépôt sur un serveur est perdue. Elles ne s’exécutent pas après la reconnexion.
- Vous fermez la fenêtre, ou vous y ouvrez un autre dépôt. Seules les opérations lancées depuis cette fenêtre sont annulées.
- Vous quittez Spooky.

## Annuler et rétablir {#undo}

Annuler et rétablir ne passent pas par la file d’attente. Tant qu’une opération que vous avez lancée s’exécute ou attend, ils ne sont pas disponibles, et le menu indique :ui[undo.reason.busy]. Consultez [Quand l’annulation est bloquée](/guide/work/undo/#blocked).

## Récupération automatique {#auto-fetch}

La [récupération automatique](/guide/branches/sync/#auto-fetch) ne démarre que si rien ne s’exécute ni n’attend dans le dépôt. Si vous lancez quoi que ce soit pendant qu’elle récupère, y compris annuler et rétablir, elle s’arrête aussitôt et votre opération s’exécute. Son enregistrement indique :ui[activity.cancelled], et à quelle opération elle a cédé la place.

## La zone d’activité {#activity-area}

Le bas de la barre latérale liste, pour le dépôt de la fenêtre :

- Les récupérations, les tirages, les poussées et les autres opérations qui se connectent à un dépôt distant, pendant leur exécution et quelques secondes après leur fin. La plus récente est en haut.
- En dessous, les opérations qui attendent dans la file, la prochaine en haut. À la place de la sortie de Git, elles affichent :ui[activity.waitingDetail] jusqu’à ce que leur tour arrive.

Chaque ligne a une barre de progression, un bouton d’arrêt et la dernière ligne de la sortie de Git. Jusqu’à trois lignes s’affichent à la fois. Faites défiler pour en voir plus.

- Cliquez sur le bouton d’arrêt d’une ligne en attente pour la sortir de la file. Rien ne s’exécute, et la ligne indique que l’opération a été annulée.
- Cliquez sur le bouton d’arrêt d’une ligne en cours pour arrêter l’opération.
- Cliquez n’importe où ailleurs dans une ligne pour ouvrir la fenêtre :ui[activity.title].

Les opérations qui ne se connectent pas à un dépôt distant quittent la zone quand elles démarrent. Leur progression s’affiche dans la fenêtre elle-même, par exemple dans la copie de travail ou la zone de commit.

## La fenêtre Activité {#activity-window}

Choisissez :ui[menu.window > activity.title] (<kbd>⌃⌘0</kbd>). La fenêtre contient les enregistrements de tous les dépôts, répartis en trois pages que vous choisissez dans la barre d’outils :

| Page | Ce qu’elle liste | Durée de conservation des enregistrements |
|---|---|---|
| :ui[activity.remote] | Les récupérations, les tirages, les poussées et les autres opérations qui se connectent à un dépôt distant | 7 jours, enregistrés sur votre Mac |
| :ui[activity.repository] | Les autres opérations Git, et les chargements que vous lancez, comme le chargement de commits | Les 100 derniers, jusqu’à ce que vous quittiez l’app |
| :ui[activity.service] | Les requêtes envoyées à GitHub et GitLab | Jusqu’à ce que vous quittiez l’app |

::screenshot[La fenêtre Activité sur la page Distant. La liste contient les enregistrements de récupération, de tirage et de poussée d’un dépôt. La poussée est sélectionnée, et son journal complet est à droite.]{name="advanced-activity" frame="window" markers="56.1,10 32.8,4.6 93.8,4.6"}

1. Les pages : :ui[activity.remote], :ui[activity.repository] et :ui[activity.service]
2. :ui[activity.clear]
3. Le champ de recherche

Les chargements que Spooky effectue de lui-même pour garder une fenêtre à jour ne sont pas listés.

Sélectionnez un enregistrement pour voir son journal complet à droite. Vous pouvez sélectionner et copier le texte.

- Les opérations en attente sont listées ici aussi, avec la mention :ui[activity.waiting] et un bouton d’arrêt.
- :ui[activity.clear] supprime les enregistrements terminés de la page actuelle. Ceux qui sont en cours restent.
- Le champ de recherche filtre la page actuelle par nom de dépôt et par texte du journal.

Les mots de passe et les jetons sont exclus des journaux.

## Notifications du système {#notifications}

Spooky envoie une notification quand :

- Un clonage se termine. Elle affiche l’adresse distante, sans nom d’utilisateur ni mot de passe, et l’endroit où le dépôt a été cloné. Consultez [Cloner un dépôt](/guide/repositories/manager/#clone).
- Des branches sont archivées automatiquement. Elle indique combien. Consultez [Archiver automatiquement](/guide/branches/review/#auto-archive).

Spooky ne demande pas d’autorisation, donc macOS les distribue d’abord discrètement dans le **Centre de notifications**. Pour choisir comment elles apparaissent, choisissez **menu Pomme › Réglages Système**, cliquez sur **Notifications** dans la barre latérale, puis sur **Spooky**. Un clic sur une notification fait passer Spooky au premier plan.

:::note[Dépôts sur un serveur]
Chaque dépôt sur un serveur a sa propre file d’attente, comme un dépôt local. L’arrêt d’une opération, ou une récupération automatique qui cède la place, met aussi fin au processus Git sur le serveur.
:::

## Voir aussi

- [Récupérer, tirer et pousser](/guide/branches/sync/)
- [Annulation et récupération](/guide/work/undo/)
- [État de la connexion et reconnexion](/guide/server/connection/)
