---
title: "Valider des modifications"
description: "Rédigez l’objet et la description d’un commit, utilisez la saisie semi-automatique, corrigez le dernier commit, et choisissez l’identité et la signature d’un commit."
---

Un commit enregistre les modifications indexées dans l’historique du dépôt, avec un message. Indexez d’abord les modifications, comme décrit dans [Examiner et indexer les modifications](/guide/work/diff/). Rédigez ensuite le message dans la zone de commit, en haut de la copie de travail.

## Rédiger le message {#write}

Le message comporte deux parties :

- :ui[working.subject] est une ligne courte qui résume la modification. Appuyez sur <kbd>Retour</kbd> ou <kbd>Tab</kbd> pour passer à la description. Si vous collez plusieurs lignes ici, la première reste dans l’objet. Le reste va à la fin de la description.
- :ui[working.body] est facultatif. Servez-vous-en pour expliquer ce qui a changé et pourquoi.

::screenshot[La zone de commit, développée. L’objet indique Add a units toggle, avec une description de deux lignes en dessous. En bas de la description se trouvent les boutons d’épinglage et de retour à la ligne. En dessous figurent les cases Corriger et Signer, avec le nom, l’adresse e-mail et l’image de l’auteur à droite. Les boutons Tout indexer et Valider sont en bas.]{name="work-commit-area" frame="closeup" markers="62,12 24,56 94.6,69.1"}

1. :ui[working.subject]
2. Le bouton d’épinglage et le bouton de retour à la ligne
3. L’image de l’auteur

La zone de commit se développe pendant que vous saisissez dans l’un des deux champs, et reste ouverte tant que la description contient du texte. Pour la garder ouverte en permanence, cliquez sur le bouton d’épinglage en bas de la description. Faites glisser le bord inférieur de la description pour l’agrandir ou la réduire.

Dès que vous commencez à saisir, le nombre à la fin de l’objet compte les caractères qu’il vous reste. Les caractères au-delà de la limite sont mis en évidence.

L’autre bouton en bas de la description alterne entre deux modes de retour à la ligne :

- :ui[editor.softWrap] renvoie les lignes au bord du champ.
- :ui[editor.hardWrap] utilise une police à chasse fixe et ne renvoie pas les lignes. Un repère marque la limite de caractères, et les lignes plus longues sont mises en évidence. Pour couper le paragraphe actuel à la limite, choisissez :ui[menu.edit > commit.reformatParagraph] (<kbd>⇧⌘W</kbd>).

Ces options se trouvent dans :ui[app.name > settings.title] › :ui[settings.editor] :

| Réglage | Par défaut |
|---|---|
| :ui[editor.showsCounter] | Activé |
| :ui[editor.subjectLimit] | 50 |
| :ui[editor.wrapping] | :ui[editor.softWrap] |
| :ui[editor.bodyLimit] | 72. Vous pouvez le changer quand :ui[editor.hardWrap] est choisi. |
| :ui[editor.showsGuide] | Activé. Utilisé avec :ui[editor.hardWrap]. |
| :ui[editor.warnsComments] | Activé. Consultez [Commentaires dans le message](#comments). |
| :ui[editor.stripsComments] | Désactivé. Disponible quand l’avertissement est désactivé. |
| :ui[editor.completesIssues] | Activé. Consultez [Saisie semi-automatique](#autocomplete). |

Consultez [Éditeur](/guide/settings/appearance/#editor).

## Valider {#commit}

Quand le message est prêt, cliquez sur :ui[working.commit], ou appuyez sur <kbd>⌘↩</kbd> pendant que vous saisissez le message. Le bouton reste estompé tant que l’objet est vide ou qu’aucune modification n’est indexée.

Pour passer à l’objet depuis n’importe quel endroit de la fenêtre, choisissez :ui[workspace.title > working.commitMenu] (<kbd>⇧⌘C</kbd>).

Deux cases à cocher sous la description modifient le commit :

- :ui[commit.signOff] ajoute à la fin du message une ligne `Signed-off-by` avec votre nom et votre adresse e-mail. La case reste telle que vous l’avez laissée, dans tous les dépôts.
- :ui[commit.skipHooks] valide sans exécuter les crochets `pre-commit` et `commit-msg` du dépôt. Elle n’apparaît que si le dépôt a de tels crochets, et elle se décoche après chaque commit.

Si le commit échoue, votre message reste dans la zone de commit. Pour revenir sur un commit que vous venez de créer, choisissez :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>). Consultez [Annulation et récupération](/guide/work/undo/).

### Commentaires dans le message {#comments}

Les lignes qui commencent par `#` comptent comme des commentaires dans Git, sauf si vous avez défini un autre caractère de commentaire. Spooky valide le message tel que vous l’avez écrit, donc il demande d’abord quand le message contient de telles lignes : :ui[commit.comments]

- :ui[commit.removeComments] valide sans ces lignes.
- :ui[commit.keepComments] les valide telles quelles.

Cochez :ui[commit.doNotAskAgain] pour garder votre choix pour la prochaine fois. Pour retrouver la question, activez :ui[editor.warnsComments] dans :ui[app.name > settings.title] › :ui[settings.editor]. Consultez [Éditeur](/guide/settings/appearance/#editor).

Si le message ne contient que des commentaires, Spooky demande :ui[commit.commentsOnly] Cliquez sur :ui[commit.keepCommentsAndCommit] pour les valider quand même.

## Saisie semi-automatique {#autocomplete}

Saisissez l’un de ces éléments dans l’objet ou la description, et Spooky liste les correspondances au fil de la saisie :

| Saisissez | Pour insérer |
|---|---|
| `c:` | Le hash court de l’un des 100 derniers commits. Saisissez une partie du hash, de l’objet ou de l’auteur. |
| `\` | Le chemin d’un fichier indexé |
| `#` | Le numéro d’un ticket ouvert sur GitHub ou GitLab |
| `fixup!` ou `squash!` au début de l’objet | L’objet d’un commit antérieur, pour marquer ce commit comme un correctif de celui-ci |

::screenshot[L’objet du commit après la saisie de c:. Une liste en dessous affiche des commits récents, chacun avec l’auteur, la date, le hash court et l’objet. Le premier est sélectionné.]{name="work-commit-completion" frame="closeup"}

Appuyez sur <kbd>↑</kbd> ou <kbd>↓</kbd> pour choisir une correspondance, sur <kbd>Retour</kbd> pour l’insérer et sur <kbd>Esc</kbd> pour fermer la liste.

Les numéros de ticket nécessitent un [compte d’hébergement](/guide/hosting/accounts/) pour le dépôt distant du dépôt, et :ui[editor.completesIssues] activé dans :ui[app.name > settings.title] › :ui[settings.editor]. Consultez [Éditeur](/guide/settings/appearance/#editor). Un commit marqué `fixup!` ou `squash!` peut ensuite être fondu dans sa cible, comme décrit dans [Réécrire l’historique](/guide/history/rewrite/).

## Corriger le dernier commit {#amend}

La correction remplace le dernier commit par un nouveau. Utilisez-la pour corriger le message, ou pour ajouter des modifications que vous aviez oubliées.

1. Cochez :ui[working.amend] sous la description. Spooky reprend le message du dernier commit, et la case affiche le hash court de ce commit.
2. Modifiez le message, et indexez les modifications à y faire entrer.
3. Cliquez sur :ui[working.amend].

Décochez la case pour revenir au message que vous étiez en train d’écrire.

Pour une correction rapide, maintenez <kbd>⌥</kbd> enfoncée quand aucun des deux champs du message n’est en cours de modification. La zone de commit passe à la correction du dernier commit jusqu’à ce que vous relâchiez la touche. Cliquez sur :ui[working.amend] en maintenant la touche, ou appuyez sur <kbd>⌥⌘↩</kbd>. Le commit garde son message et intègre les modifications indexées.

:::caution
Si vous avez déjà poussé le dernier commit, la correction le rend différent de celui du dépôt distant. Il faut alors pousser de force. Consultez [Pousser de force](/guide/branches/sync/#force-push).
:::

Pour modifier un commit plus ancien, consultez [Réécrire l’historique](/guide/history/rewrite/).

## Choisir qui valide {#identity}

Le nom et l’adresse e-mail à droite des cases à cocher sont enregistrés dans le commit comme son auteur. Ils viennent des réglages `user.name` et `user.email` de Git. L’image à côté est recherchée d’après l’adresse e-mail. Consultez [Données et confidentialité](/reference/data-privacy/).

Pour valider sous une autre identité, par exemple avec votre adresse professionnelle, utilisez un profil utilisateur :

1. Cliquez sur l’image. Un menu liste vos profils, avec une coche à côté de celui qui est utilisé.
2. Choisissez un profil.
3. Vérifiez les réglages que Spooky s’apprête à écrire, et cliquez sur :ui[profiles.apply.submit].

Le nom, l’adresse e-mail et la clé de signature du profil vont dans les réglages Git propres à ce dépôt, donc les autres dépôts ne sont pas touchés.

Si l’identité actuelle n’est pas encore un profil, le menu propose :ui[profiles.addCurrent]{1="alex@example.com"} pour l’enregistrer comme tel. Pour configurer les profils, choisissez :ui[profiles.manage] dans le même menu. Consultez [Profils utilisateur](/guide/settings/identity/#profiles).

:::note[Dépôts sur un serveur]
Le profil va dans les réglages du dépôt sur le serveur. Les autres outils qui valident dans le même dépôt sur le serveur l’utilisent aussi.
:::

## Signer les commits {#signing}

Un commit signé porte la preuve qu’il vient du détenteur d’une clé. Spooky fonctionne avec les clés SSH et OpenPGP.

Placez le pointeur sur l’image dans la zone de commit pour voir si le prochain commit sera signé, et avec quelle clé.

- **Pour tous les dépôts** : activez :ui[gitConfig.signCommits] et choisissez :ui[gitConfig.signingKey] dans :ui[app.name > settings.title] › :ui[settings.gitConfig]. Consultez [Signature](/guide/settings/identity/#signing).
- **Pour un seul dépôt** : cliquez sur :ui[repositorySettings.title] dans la barre latérale. Sous :ui[repositorySettings.signing], réglez :ui[repositorySettings.signCommits] et :ui[repositorySettings.signingKey]. Consultez [Réglages du dépôt](/guide/settings/identity/#repository).

Si la clé demande une phrase secrète, Spooky la demande dans une zone de dialogue :ui[signing.unlock].

## Voir aussi

- [Examiner et indexer les modifications](/guide/work/diff/)
- [Annulation et récupération](/guide/work/undo/)
- [Profils utilisateur et configuration Git](/guide/settings/identity/)
