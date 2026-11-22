---
title: "Apparence et thèmes"
description: "Choisissez l’apparence, utilisez un thème intégré ou créez, importez et exportez les vôtres, réglez les options de texte et d’éditeur, et choisissez une icône d’app."
---

Quatre pages de :ui[app.name > settings.title] décident de l’aspect de Spooky : :ui[settings.appearance] pour l’app dans son ensemble, :ui[settings.themes] pour les couleurs des diffs et des fichiers, :ui[settings.text] pour l’affichage du texte, et :ui[settings.editor] pour le message de commit.

## Apparence {#appearance}

Cliquez sur une image de la ligne :ui[settings.appearance.label] pour changer toute l’app :

- :ui[appearance.system] suit macOS. C’est le réglage par défaut.
- :ui[appearance.light] et :ui[appearance.dark] restent les mêmes quel que soit le réglage de macOS.

Dans une fenêtre de dépôt, vous pouvez aussi en changer depuis les [Actions rapides](/guide/repositories/navigation/#quick-actions) : cherchez l’apparence et lancez :ui[quickActions.setAppearance].

## Icône de l’app {#app-icon}

Sous l’apparence, :ui[settings.appIcon.label] liste les icônes disponibles, en deux séries :

| Série | Icônes |
|---|---|
| :ui[appIcon.series.hideAndSeek] | :ui[appIcon.rise] (par défaut), :ui[appIcon.front], :ui[appIcon.hide], :ui[appIcon.reveal] |
| :ui[appIcon.series.cherryPick] | :ui[appIcon.midnight], :ui[appIcon.perch], :ui[appIcon.cherryPick], :ui[appIcon.armful] |

Pointez une icône pour la voir en grand à gauche. En dessous figurent ses quatre aspects possibles dans le Dock : telle quelle, connectée à un serveur, sombre, et sombre pendant une connexion. Cliquez sur l’icône pour l’utiliser. Quand les icônes ont le focus clavier, les touches fléchées passent de l’une à l’autre et <kbd>Espace</kbd> utilise celle où vous êtes.

La nouvelle icône apparaît dans le Dock, le sélecteur d’apps (<kbd>⌘Tab</kbd>) et le Finder, même quand Spooky n’est pas lancé. Quelques points à connaître :

- Tant qu’un dépôt sur un serveur est connecté, l’icône s’illumine. Dans les icônes :ui[appIcon.series.hideAndSeek], les voyants du serveur s’allument. Dans les icônes :ui[appIcon.series.cherryPick], les yeux du fantôme deviennent des étoiles brillantes.
- La version sombre s’affiche quand le style des icônes et des widgets, dans **Réglages Système › Apparence**, est sombre, ou automatique alors que Spooky est en mode sombre. Avec un style transparent ou teinté, l’icône ne s’illumine pas.
- Quand vous passez à :ui[appIcon.rise] ou que vous la quittez, le Dock redémarre une fois. Sinon, un Spooky gardé dans le Dock afficherait encore l’ancienne icône.
- Spooky enregistre toute autre icône dans `Spooky.app`. S’il ne peut pas y écrire, la page indique pourquoi, et l’icône ne change pas.

## Thèmes {#themes}

Un thème définit la police et les couleurs qu’utilisent les diffs et le contenu des fichiers. Spooky en fournit deux : Default pour l’apparence claire, et Default (Dark) pour l’apparence sombre.

Le thème sélectionné dans la liste est celui qu’utilise l’apparence actuelle. Le clair et le sombre retiennent chacun le leur. Pour définir le thème de l’autre apparence, passez d’abord à celle-ci. Les Actions rapides peuvent aussi changer de thème, avec :ui[quickActions.applyTheme].

::screenshot[La page Thèmes de la fenêtre Réglages. La liste de gauche contient Default et Default (Dark), avec Default sélectionné, et les boutons d’ajout et de suppression en bas. À droite figurent un champ de police indiquant Menlo-Regular 11.0, une liste de types de texte comme Texte brut, Mot-clé, Chaîne et Commentaire, chacun dans sa couleur, et des sélecteurs de couleur pour la couleur de la police, l’arrière-plan, la sélection, les ajouts et les suppressions. En dessous se trouve un court aperçu de diff, avec des lignes inchangées, supprimées et ajoutées.]{name="themes" frame="window" markers="13.3,30 9.4,95.3 58.3,17.8 61.1,37.3 70,56.9 61.1,82.7"}

1. La liste des thèmes
2. :ui[themes.add] et :ui[themes.remove]
3. La police
4. Les types de texte que distingue la coloration syntaxique
5. Les sélecteurs de couleur
6. Un aperçu d’un diff dans ce thème

### Créer et modifier un thème {#edit-theme}

1. Cliquez sur le bouton d’ajout sous la liste. Spooky ajoute :ui[themes.newName], avec les couleurs du thème intégré de l’apparence actuelle, et sélectionne son nom.
2. Tapez un nom et appuyez sur <kbd>Retour</kbd>.
3. Cliquez sur le champ de police pour choisir une police et une taille dans le panneau des polices.
4. Sélectionnez un type de texte dans la liste, puis cliquez sur :ui[themes.text] pour changer sa couleur. :ui[themes.background], :ui[themes.selection], :ui[themes.added] et :ui[themes.deleted] définissent les couleurs autour du texte.

Les changements sont enregistrés tout de suite. L’aperçu les montre au fur et à mesure. Pour renommer un thème plus tard, sélectionnez-le et appuyez sur <kbd>Retour</kbd>.

Vous pouvez modifier les thèmes intégrés, mais pas les renommer ni les supprimer. Pour supprimer un autre thème, sélectionnez-le et cliquez sur le bouton de suppression. Spooky demande d’abord confirmation, car l’opération est irréversible. Une apparence qui utilisait ce thème revient à son thème intégré.

### Partager des thèmes {#share-themes}

Chaque thème est un fichier `.spookytheme`.

- **Exporter** : faites glisser un thème de la liste vers un dossier du Finder.
- **Importer** : faites glisser des fichiers `.spookytheme` sur la liste. Vous pouvez aussi les ouvrir depuis le Finder ou les déposer sur l’icône de Spooky dans le Dock.

Si un thème du même nom existe, Spooky demande s’il faut le remplacer. Un fichier qui n’est pas un thème valide est ignoré, avec un message.

Spooky garde les thèmes dans `~/Library/Application Support/Spooky/Themes/`. Consultez [Données et confidentialité](/reference/data-privacy/#mac).

## Texte {#text}

La page :ui[settings.text] règle l’aspect du texte dans les diffs et le contenu des fichiers. Les couleurs viennent du thème.

| Réglage | Par défaut | Ce qu’il fait |
|---|---|---|
| :ui[text.enableSyntaxColoring] | Activé | Colore le code selon son langage |
| :ui[text.syntaxColoringInDiffs] | Désactivé | Utilise aussi les couleurs syntaxiques dans les diffs. Nécessite que la coloration syntaxique soit activée. |
| :ui[text.showInvisibles] | Désactivé | Affiche les espaces, les tabulations et les fins de ligne sous forme de symboles |
| :ui[text.tabWidth] | 4 | La largeur d’une tabulation, de 1 à 100 espaces |

## Éditeur {#editor}

La page :ui[settings.editor] configure les champs du message de commit. Consultez [Rédiger le message](/guide/work/commit/#write) pour leur comportement.

| Réglage | Par défaut | Ce qu’il fait |
|---|---|---|
| :ui[editor.showsCounter] | Activé | Décompte les caractères restants dans l’objet |
| :ui[editor.subjectLimit] | 50 | La longueur maximale conseillée pour l’objet, en caractères. Choisissez une valeur ou tapez-en une de 1 à 1 000. |
| :ui[editor.wrapping] | :ui[editor.softWrap] | Ou :ui[editor.hardWrap], avec une police à chasse fixe et sans retour à la ligne automatique |
| :ui[editor.bodyLimit] | 72 | La limite de ligne pour :ui[editor.hardWrap] |
| :ui[editor.showsGuide] | Activé | Trace une ligne à cette limite, pour :ui[editor.hardWrap] |
| :ui[editor.warnsComments] | Activé | Avertit des lignes que Git traiterait comme des commentaires. Consultez [Commentaires dans le message](/guide/work/commit/#comments). |
| :ui[editor.stripsComments] | Désactivé | Supprime ces lignes quand vous validez. Disponible quand l’avertissement est désactivé. |
| :ui[editor.completesIssues] | Activé | Complète les numéros de tickets après `#`. Consultez [Saisie semi-automatique](/guide/work/commit/#autocomplete). |

## Voir aussi

- [Général, mises à jour et environnement](/guide/settings/general/)
- [Examiner et indexer les modifications](/guide/work/diff/)
- [Valider des modifications](/guide/work/commit/)
- [Fenêtres et navigation](/guide/repositories/navigation/)
