---
title: "Historique du fichier et blame"
description: "Suivez un fichier à travers son historique, voyez qui a modifié chaque ligne avec le blame, affichez un fichier tel qu’il était à une révision et restaurez-le depuis cette révision."
---

Ces vues portent sur un seul fichier à la fois : les commits qui l’ont modifié, qui a écrit chaque ligne, et ce qu’il contenait à n’importe quel moment du passé.

## Historique du fichier {#file-history}

Pour voir tous les commits qui ont modifié un fichier :

- Dans la copie de travail, cliquez sur le fichier avec le bouton droit et choisissez :ui[fileHistory.showHistoryOf]{1="units.ts"}.
- Ou placez le pointeur sur le nom du fichier en haut de la colonne de droite, et cliquez sur :ui[fileHistory.title].
- Dans les [détails d’un commit](/guide/history/commit-details/#changeset), cliquez avec le bouton droit sur un fichier dans les modifications ou dans l’arborescence de fichiers, et choisissez le même élément.

Dans la copie de travail, vous pouvez aussi sélectionner un dossier et cliquer sur :ui[fileHistory.title] en haut de la colonne de droite. L’historique couvre alors tous les fichiers qu’il contient.

La colonne de gauche liste les commits, du plus récent au plus ancien, regroupés par mois. En haut figurent le nom du fichier et le nombre de commits. Cliquez sur le nom du fichier pour passer à un autre fichier.

Sélectionnez un commit pour voir à droite ce qu’il a modifié dans le fichier. Passez à :ui[showFile.raw] pour voir le fichier entier tel qu’il était dans ce commit, ou revenez à :ui[fileHistory.diff]. Placez le pointeur sur le hash court, en haut, pour en avoir plus :

- :ui[blame.title] montre qui a écrit chaque ligne à ce commit. Consultez [Blame](#blame).
- :ui[fileHistory.showCommit] ouvre le commit dans les [détails en pleine page](/guide/history/commit-details/#full-page).
- :ui[externalTool.action.diffTool] ouvre la modification dans votre outil de comparaison.

::screenshot[L’historique du fichier src/units.ts. La colonne de gauche affiche le nom du fichier et le nombre de commits, avec les commits qui l’ont modifié regroupés par mois. À droite figure ce que le commit sélectionné a modifié dans le fichier. Le pointeur est posé sur le hash court. Les boutons du blame, d’affichage du commit et de l’outil de comparaison apparaissent en haut à droite, à côté du sélecteur entre le diff et le fichier brut.]{name="history-file-history" frame="window" markers="28.5,9 94.6,13.25 86,13.25"}

1. Le nom du fichier et le nombre de commits
2. Le sélecteur entre :ui[fileHistory.diff] et :ui[showFile.raw]
3. Les boutons qui apparaissent tant que le pointeur est sur le hash court

Double-cliquez sur un commit, ou appuyez sur <kbd>Retour</kbd>, pour l’ouvrir lui aussi dans les détails en pleine page. Cliquez sur un commit avec le bouton droit pour retrouver les mêmes actions, plus la restauration et l’export du fichier à ce commit.

### Rechercher dans l’historique du fichier {#file-history-search}

Saisissez du texte dans le champ de recherche de la barre d’outils pour réduire la liste. Cliquez sur la loupe dans le champ pour choisir sur quoi porte la recherche : :ui[fileHistory.scope.message], :ui[fileHistory.scope.hash], :ui[fileHistory.scope.author] ou :ui[fileHistory.scope.committer].

- Les messages, les auteurs et les validateurs sont comparés au texte que vous saisissez, sans tenir compte de la casse. Les auteurs et les validateurs sont recherchés par nom ou par adresse e-mail.
- Un hash de commit, une branche ou un tag affiche le commit le plus récent, jusqu’à ce point, qui a modifié le fichier.

## Blame {#blame}

Le blame affiche le fichier entier, avec à droite une colonne qui indique quel commit a modifié en dernier chaque bloc de lignes. Chaque bloc affiche l’avatar de l’auteur, la première ligne du message de commit, l’auteur et l’ancienneté du commit.

- Dans la copie de travail, cliquez sur un fichier avec le bouton droit et choisissez :ui[blame.show]{1="units.ts"}. Ou placez le pointeur sur le nom du fichier en haut de la colonne de droite, et cliquez sur :ui[blame.title].
- Dans les modifications ou l’arborescence de fichiers d’un commit, choisissez :ui[fileHistory.blameAt]{1="units.ts" 2="e2dda2bc"} pour voir le fichier tel qu’il était alors.

::screenshot[Le blame de src/units.ts. Le fichier est à gauche. La colonne de droite affiche l’avatar, le message, l’auteur et l’ancienneté du commit qui a modifié chaque bloc en dernier. Les blocs issus de Drop trailing zeros from temperatures sont mis en évidence.]{name="history-blame" frame="window" markers="84,22 84,82.5"}

1. La colonne qui indique quel commit a modifié chaque bloc en dernier
2. Les blocs mis en évidence du commit sur lequel vous avez cliqué

Cliquez sur un bloc pour voir un résumé de son commit. Tous les blocs de ce commit s’illuminent. Double-cliquez sur un bloc pour ouvrir son commit dans les détails en pleine page. Pour élargir ou rétrécir la colonne, faites glisser son bord gauche. Spooky retient la largeur.

Le blame a besoin d’un fichier déjà validé. Il ne peut pas afficher les fichiers nouveaux ou non suivis, les fichiers binaires ni les sous-modules.

## Afficher un fichier à une révision {#show-file}

Pour lire un fichier tel qu’il était dans n’importe quel commit, sans modifier votre copie de travail :

- Dans la copie de travail, cliquez sur un fichier avec le bouton droit et choisissez :ui[showFile.show]{1="units.ts"}. Cela affiche la version de HEAD.
- Dans les modifications ou l’arborescence de fichiers d’un commit, choisissez :ui[fileHistory.showAt]{1="units.ts" 2="e2dda2bc"}.

L’en-tête se lit comme un chemin : révision › fichier.

- Cliquez sur la révision pour choisir un autre commit. Double-cliquez sur un commit dans la liste pour y passer.
- Cliquez sur le nom du fichier pour choisir un autre fichier du même commit.
- :ui[showFile.raw] et :ui[blame.title] alternent entre le fichier seul et le [blame](#blame).
- Placez le pointeur sur l’en-tête pour obtenir :ui[fileHistory.title] et :ui[fileHistory.showCommit].

Sous l’en-tête, Spooky compte les personnes qui ont modifié le fichier, avec leurs avatars. Le texte utilise votre thème et les réglages de :ui[app.name > settings.title] › :ui[settings.text]. Consultez [Texte](/guide/settings/appearance/#text).

Comme le blame, cette vue ne peut pas afficher les fichiers nouveaux ou non suivis, les fichiers binaires ni les sous-modules.

## Restaurer un fichier depuis une révision {#restore}

Pour remettre un fichier dans l’état où il était dans un commit antérieur :

1. Cliquez sur le commit avec le bouton droit dans l’historique du fichier et choisissez :ui[fileHistory.restoreAt]{1="units.ts" 2="e2dda2bc"} dans le menu. Dans les [détails d’un commit](/guide/history/commit-details/#changeset), l’élément est :ui[fileHistory.restoreInWorkingCopy]{1="units.ts" 2="e2dda2bc"}.
2. Spooky demande d’abord confirmation. Cliquez sur :ui[fileHistory.restore.submit].

Les modifications indexées et non indexées du fichier sont toutes remplacées. Si le fichier n’existait pas dans ce commit, il est supprimé. Rien n’est validé : le fichier restauré apparaît dans la copie de travail comme une modification indexée.

Pour revenir en arrière, choisissez :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

Vous pouvez restaurer plusieurs fichiers ou dossiers à la fois depuis les modifications ou l’arborescence de fichiers.

:::note[Dépôts sur un serveur]
Le fichier est écrasé sur le serveur. Cochez :ui[dialog.doNotAskAgain] pour éviter la question la prochaine fois. Pour la retrouver, activez :ui[settings.warnRestoringOnServer] dans :ui[app.name > settings.title] › :ui[settings.general]. Consultez [Confirmations](/guide/settings/general/#confirmations).
:::

## Voir aussi

- [Détails d’un commit](/guide/history/commit-details/)
- [Copie de travail](/guide/work/working-copy/)
- [Annulation et récupération](/guide/work/undo/)
