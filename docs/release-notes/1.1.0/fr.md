### Nouveautés

- Nouvelle page **Hôtes SSH** dans les réglages : affichez, ajoutez, modifiez et supprimez les alias d’hôte de ~/.ssh/config. Double-cliquez sur un alias ou appuyez sur Retour pour le modifier ; Spooky ne change que les lignes que vous modifiez, et les autres options et les commentaires restent tels quels
- La liste des pull requests et des merge requests peut passer de **Ouvertes** à **Toutes** pour afficher aussi les requêtes fermées et fusionnées
- Les étiquettes des requêtes apparaissent dans la liste et dans **Conversation**
- Nouvelle vue **CI/CD** dans les détails d’une requête : l’état global et le résultat de chaque vérification ou tâche, tenus à jour tant que quelque chose est en attente ou en cours ; chaque ligne de la liste affiche aussi le statut CI/CD

### Améliorations

- Les dépôts de serveur se connectent plus vite, et les commandes Git, la lecture et l’écriture de fichiers ainsi que les annulations sont plus rapides, surtout sur les réseaux à forte latence ; une connexion perdue est aussi détectée plus tôt
- Coller plusieurs lignes dans **Objet du commit** garde la première ligne dans l’objet et place le reste dans **Description détaillée**
- Dans la fenêtre **Dépôts**, la touche Retour renomme désormais le signet ou le groupe sélectionné au lieu d’ouvrir le dépôt, et Échap annule ; double-cliquez pour ouvrir un dépôt. Cliquer sur le nom d’une ligne sélectionnée ne lance plus le renommage
- La barre d’outils par défaut de la fenêtre du dépôt comprend désormais **Finder**, **Terminal**, **Pousser de force** et **Créer une branche** ; **Actions rapides**, **Synchroniser** et **Fusionner** / **Rebaser** s’ajoutent au besoin depuis **Personnaliser la barre d’outils…**, où vous pouvez aussi faire glisser l’ensemble par défaut dans la barre d’outils pour adopter toute la nouvelle disposition
- Lors de la suppression de signets, la case de la Corbeille est estompée pour un dépôt de serveur dont le dossier n’est plus sur le serveur, et seul le signet est retiré
- À la réouverture d’un dépôt GitLab, Spooky parle tout de suite de merge requests, sans attendre le chargement des dépôts distants
- GitLab supprime la référence de la branche source d’une merge request 14 jours après sa fermeture ou sa fusion ; récupérer ensuite ses commits affiche **Les commits ne sont plus disponibles**
- Quand une commande Git, comme changer de branche ou indexer, échoue parce que git-lfs est introuvable, l’erreur s’intitule désormais **Git LFS n’est pas disponible** et explique comment régler PATH pour un dépôt local ou de serveur
- Les anciennes versions du script auxiliaire dans ~/.spooky/bin sur un serveur sont supprimées après 30 jours sans utilisation
- Termes et ponctuation plus cohérents dans l’interface, dans toutes les langues

### Corrections

- Écrire un fichier dans un dépôt de serveur n’abîme plus l’original si la connexion tombe ou si l’écriture est annulée
- Une brève coupure du réseau n’interrompt plus la connexion à un dépôt de serveur ni les commandes en cours
- Après l’annulation de l’écriture d’un fichier dans un dépôt de serveur, Spooky n’affiche plus la connexion comme active tout en refusant les écritures suivantes
- Les fichiers que Git crée dans un dépôt de serveur reçoivent leurs permissions de l’umask de la session de connexion, comme lorsque vous lancez Git vous-même par SSH
- Les mots de passe contenus dans les URL des dépôts distants n’apparaissent plus dans les journaux d’activité ni dans les messages d’erreur
- Deux dépôts de serveur dont les chemins semblent identiques mais dont les octets diffèrent ne partagent plus la même connexion
- Changer plusieurs fois de suite l’icône de l’app conserve bien le dernier groupe choisi
- L’élément **Cloner** de la barre d’outils peut être déplacé et retiré, et il figure toujours dans **Personnaliser la barre d’outils…**
- Lorsque vous tirez, les résumés d’activité n’affichent plus le résultat brut de la récupération par Git
