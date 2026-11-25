### Nouveautés

- Quand la fenêtre du dépôt devient trop étroite pour trois colonnes, elle passe à une disposition pour fenêtres étroites : une rangée sous la barre d’outils remplace la barre latérale et permet de passer de **Copie de travail** à **Historique** ou à **Remisages**, et la liste se trouve au-dessus du détail. Cliquez sur **Barre latérale** au début de la rangée pour ouvrir toute la barre latérale par-dessus la vue. Élargissez la fenêtre et les trois colonnes reviennent à la largeur que vous leur aviez donnée ; la vue actuelle, votre sélection et le message de commit en cours de rédaction restent tels quels
- Dans une fenêtre étroite, les boutons qui ne tiennent plus dans la barre d’outils passent dans le menu », tandis que **Récupérer**, **Tirer** et **Pousser** restent dans la barre d’outils
- Dans la vue **CI/CD** des détails d’une requête, une vérification ou un job qui a un journal peut être développé pour afficher le journal sous sa ligne. Les jobs de GitHub Actions ont un journal une fois terminés ; chaque job d’un pipeline GitLab peut être développé, et tant qu’un job est en cours, son journal se met à jour avec le statut
- Vous pouvez ajouter et retirer les étiquettes d’une requête dans **Conversation** : cliquez sur le × après le nom d’une étiquette pour la retirer, sur **Ajouter** pour choisir l’une des étiquettes du projet, ou utilisez **Nouvelle étiquette…** pour en créer une et l’ajouter à la requête

### Améliorations

- La liste des pull requests et des merge requests indique désormais l’état de chaque requête par une icône avant le titre, à la place du texte qui le suivait : verte pour une requête ouverte, grise pour un brouillon, rouge pour une requête fermée et violette pour une requête fusionnée
- Dans la page **Mises à jour** des réglages, les canaux de publication s’appellent désormais **Stable**, **Bêta** et **Alpha**. Les versions bêta et alpha portent leur marque dans le numéro de version, par exemple 1.2.0-beta.1, et se reconnaissent ainsi dans **À propos de Spooky** et dans la fenêtre de mise à jour

### Corrections

- macOS ne redemande plus le mot de passe de votre trousseau après chaque mise à jour de Spooky lorsque Spooky lit le jeton d’un compte ou les informations d’identification enregistrées dans le trousseau. Après l’installation de cette version, macOS le demande encore une fois pour chaque élément enregistré
- Après la modification d’un alias dans la page **Hôtes SSH** des réglages, les dépôts de cet hôte enregistrés dans les signets n’échouent plus à se connecter avec l’ancien alias ; leurs réglages et les informations d’identification enregistrées dans le trousseau passent aussi au nouvel alias
