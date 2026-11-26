### Nouveautés

- Quand la fenêtre du dépôt devient trop étroite pour trois colonnes, elle passe à une disposition pour fenêtres étroites : une rangée sous la barre d’outils remplace la barre latérale et permet de passer de **Copie de travail** à **Historique** ou à **Remisages**, et la liste se trouve au-dessus du détail. Cliquez sur **Barre latérale** au début de la rangée pour ouvrir toute la barre latérale par-dessus la vue. Élargissez la fenêtre et les trois colonnes reviennent à la largeur que vous leur aviez donnée ; la vue actuelle, votre sélection et le message de commit en cours de rédaction restent tels quels
- Dans une fenêtre étroite, les boutons qui ne tiennent plus dans la barre d’outils passent dans le menu », tandis que **Récupérer**, **Tirer** et **Pousser** restent dans la barre d’outils
- La fenêtre **Dépôts** change elle aussi de disposition quand elle devient étroite : la liste des dépôts se trouve au-dessus du détail du dépôt sélectionné, et vous pouvez faire glisser la ligne qui les sépare
- Pour garder une seule disposition quelle que soit la largeur, choisissez **Étroite** ou **Large** dans **Présentation › Disposition de la fenêtre** ; avec **Automatique**, le réglage par défaut, la disposition suit la largeur de la fenêtre. Ce choix s’applique à toutes les fenêtres
- Dans la fenêtre **Dépôts**, vous pouvez modifier l’emplacement d’un dépôt sans le retirer puis l’ajouter à nouveau : dans les détails, placez le pointeur sur la ligne **Emplacement** et cliquez sur **Modifier**. Pour un dépôt sur un serveur, vous pouvez modifier seulement l’alias d’hôte ou seulement le chemin. Le dépôt reste dans son groupe et garde le nom que vous lui avez donné
- Dans la vue **CI/CD** des détails d’une requête, une vérification ou un job qui a un journal peut être développé pour afficher le journal sous sa ligne. Les jobs de GitHub Actions ont un journal une fois terminés ; chaque job d’un pipeline GitLab peut être développé, et tant qu’un job est en cours, son journal se met à jour avec le statut
- Vous pouvez ajouter et retirer les étiquettes d’une requête dans **Conversation** : cliquez sur le × après le nom d’une étiquette pour la retirer, sur **Ajouter** pour choisir l’une des étiquettes du projet, ou utilisez **Nouvelle étiquette…** pour en créer une et l’ajouter à la requête
- Pour mentionner quelqu’un dans un commentaire sur une requête, y compris dans une réponse ou une modification, saisissez @. Spooky liste les participants de la requête et les membres du projet, et réduit la liste à mesure que vous saisissez un nom d’utilisateur ou un nom ; appuyez sur Retour pour insérer le nom d’utilisateur

### Améliorations

- La liste des pull requests et des merge requests indique désormais l’état de chaque requête par une icône avant le titre, à la place du texte qui le suivait : verte pour une requête ouverte, grise pour un brouillon, rouge pour une requête fermée et violette pour une requête fusionnée
- Dans la page **Mises à jour** des réglages, les canaux de publication s’appellent désormais **Stable**, **Bêta** et **Alpha**. Les versions bêta et alpha portent leur marque dans le numéro de version, par exemple 1.2.0-beta.1, et se reconnaissent ainsi dans **À propos de Spooky** et dans la fenêtre de mise à jour

### Corrections

- macOS ne redemande plus le mot de passe de votre trousseau après chaque mise à jour de Spooky lorsque Spooky lit le jeton d’un compte ou les informations d’identification enregistrées dans le trousseau. Après l’installation de cette version, macOS le demande encore une fois pour chaque élément enregistré
- Après la modification d’un alias dans la page **Hôtes SSH** des réglages, les dépôts de cet hôte enregistrés dans les signets n’échouent plus à se connecter avec l’ancien alias ; leurs réglages et les informations d’identification enregistrées dans le trousseau passent aussi au nouvel alias
- Quand vous consultez les pull requests ou les merge requests, **Actualiser** et ⌘R relisent désormais la liste et la requête sélectionnée, et la liste est relue quand vous revenez au dépôt dans la même fenêtre
- Relire la liste des pull requests ou des merge requests ne retire plus la sélection ni le détail d’une requête située plus bas dans la liste
- Quand **Afficher les worktrees dans la liste des dépôts** est désactivé dans la page **Général** des réglages, ouvrir un worktree ne l’ajoute plus automatiquement aux signets
