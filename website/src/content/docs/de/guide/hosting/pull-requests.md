---
title: "Pull Requests und Merge Requests"
description: "Pull Requests auf GitHub und Merge Requests auf GitLab auflisten, erstellen, diskutieren, auschecken, zusammenführen und schließen."
---

Spooky zeigt für das Remote eines Repositorys die offenen Pull Requests auf GitHub und Merge Requests auf GitLab. Sie können sie lesen und diskutieren, auschecken, zusammenführen und neue erstellen, ohne das Repository-Fenster zu verlassen.

Dafür brauchen Sie einen [Hosting-Account](/guide/hosting/accounts/) für das Remote. Wenn das Remote bei GitLab liegt, steht in Seitenleiste, Menüs und Dialogfenstern Merge Request statt Pull Request.

## Die Liste öffnen {#list}

Klicken Sie in der Seitenleiste auf :ui[pr.title] oder wählen Sie :ui[menu.view > pr.show.menu] (<kbd>⌘4</kbd>).

Wählen Sie im Menü oben in der Liste ein Remote. Jede Zeile zeigt:

- Den Titel, bei Entwürfen mit dem Vermerk :ui[pullRequests.state.draft]
- Die Nummer, den Autor und wann der Request geöffnet wurde
- Den Quell-Branch und den Branch, in den er geht. Bei einem Request aus einem Fork steht beim Quell-Branch sein Projekt.

Scrollen Sie nach unten, um mehr zu laden. Geschlossene und zusammengeführte Requests werden nicht aufgeführt.

Wenn die Liste nicht geladen werden kann, nennt sie den Grund. Die bereits geladenen Requests bleiben darunter stehen. Wenn das Token des Accounts abgelehnt wird oder ihm ein Scope fehlt, können Sie gleich dort auf :ui[accounts.reauthenticate] klicken.

Wenn die Liste nicht erkennt, welcher Account zu verwenden ist, lesen Sie [Welchen Account ein Remote verwendet](/guide/hosting/accounts/#remotes).

## Einen Request lesen {#details}

Wählen Sie einen Request aus, um ihn rechts zu sehen. Oben wechseln Sie zwischen drei Ansichten:

- :ui[pullRequests.conversation]: Titel und Status, die Beschreibung, die Kommentare und die Commits nach Tagen gruppiert, die ältesten zuerst.
- :ui[pullRequests.commits]: die Commits des Requests. Die Leiste darüber führt die Mitwirkenden und die Anzahl der Commits auf.
- :ui[pullRequests.changeset]: was der Request ändert, verglichen mit der Stelle, an der sein Quell-Branch abgezweigt ist.

Doppelklicken Sie in der Konversation auf einen Commit oder drücken Sie den <kbd>Zeilenschalter</kbd>, um ihn zu öffnen. Klicken Sie mit der rechten Maustaste auf einen Commit, um seinen Hash zu kopieren. Klicken Sie auf einen Link im Text, um ihn zu öffnen.

:ui[pullRequests.commits] und :ui[pullRequests.changeset] brauchen die Commits des Requests in Ihrem Repository. Wenn sie noch nicht da sind, klicken Sie auf :ui[pullRequests.fetch]. Spooky holt sie vom Remote, ohne Ihre Branches zu ändern.

## Einen Request erstellen {#create}

Der Quell-Branch muss bereits auf einem Remote liegen. Pushen Sie ihn zuerst und führen Sie dann einen der folgenden Schritte aus:

- Klicken Sie oben in der Liste auf die Hinzufügen-Taste.
- Wählen Sie :ui[menu.repository > pr.create.menu] (<kbd>⌃⌘P</kbd>).
- Klicken Sie in der Seitenleiste mit der rechten Maustaste auf einen Branch und wählen Sie :ui[pr.forBranch.create]{1="feature/units-toggle"} aus dem Menü. Wenn der Branch bereits einen offenen Request hat, heißt der Eintrag stattdessen :ui[pr.forBranch.show]{1="feature/units-toggle"}.

Im Dialogfenster:

1. Wählen Sie neben :ui[pullRequests.source] und :ui[pullRequests.target] jeweils ein Remote und einen Branch darauf. Die Quelle ist anfangs der Branch, auf den Sie mit der rechten Maustaste geklickt haben, oder der aktuelle Branch, das Ziel der Standard-Branch des Remotes. Es werden nur Remotes auf derselben Instanz wie der Account aufgeführt. Eine Quelle in einem anderen Projekt ergibt einen Request aus einem Fork.
2. Der Titel ist anfangs der Name des Quell-Branches. Die Beschreibung ist optional.
3. Klicken Sie auf :ui[pr.create.submit].

Quelle und Ziel dürfen nicht derselbe Branch sein.

## Diskutieren {#discuss}

Um einen Kommentar hinzuzufügen, klicken Sie am Ende der Konversation auf :ui[pullRequests.addComment] oder drücken Sie <kbd>⌘S</kbd>.

Bei Ihren eigenen Kommentaren verwenden Sie :ui[pullRequests.comment.edit] und :ui[pullRequests.comment.delete] am Kommentar, oder klicken Sie mit der rechten Maustaste darauf. Auch ein Doppelklick auf Ihren Kommentar öffnet ihn zum Bearbeiten. Das Löschen eines Kommentars lässt sich nicht widerrufen.

Auf GitLab können Sie außerdem mit :ui[pullRequests.comment.reply] auf jeden Kommentar antworten. Die Antwort kommt auf GitLab in dieselbe Diskussion.

Bei Ihrem eigenen Request können Sie außerdem:

- Die Beschreibung ändern: Klicken Sie daneben auf :ui[pullRequests.edit], oder klicken Sie mit der rechten Maustaste darauf und wählen Sie :ui[pullRequests.editDescription.menu] aus dem Menü.
- Titel, Beschreibung und Ziel-Branch ändern: Doppelklicken Sie in der Liste auf den Request, oder klicken Sie mit der rechten Maustaste darauf und wählen Sie :ui[pr.edit.menu]{1="#12"} aus dem Menü. Die Quelle und das Zielprojekt bleiben, wie sie sind.

## Einen Request auschecken {#checkout}

Um am Code eines Requests zu arbeiten, klicken Sie unten in den Details auf :ui[pullRequests.checkout], oder klicken Sie mit der rechten Maustaste auf den Request und wählen Sie :ui[pr.checkout.menu]{1="#12"} aus dem Menü.

Geben Sie einen Namen für den lokalen Branch ein und klicken Sie auf :ui[pullRequests.checkout]. Der Name ist anfangs der Name des Quell-Branches. Bei einem Request aus einem Fork lautet er `pullrequests/<author>/<branch>`.

Spooky holt zuerst die Commits des Requests und checkt dann den Branch aus:

- Wenn ein lokaler Branch mit diesem Namen bereits auf sie zeigt, checkt Spooky ihn aus.
- Wenn er woandershin zeigt, weist das Dialogfenster darauf hin. Wählen Sie einen anderen Namen.
- Andernfalls erstellt Spooky den Branch. Bei einem Request aus demselben Projekt verfolgt er den Quell-Branch auf dem Remote, sofern dieser auf demselben Commit steht.

Wenn Sie Änderungen an versionierten Dateien haben, fragt Spooky, ob sie zuerst gestasht werden sollen. Siehe [Automatisches Stashen](/guide/work/stash/#auto-stash).

Das Auschecken ist nicht verfügbar, wenn der lokale Branch, der den Quell-Branch verfolgt, Commits hat, die Sie noch nicht gepusht haben. Es ist auch nicht verfügbar, wenn dieser Branch der aktuelle Branch ist und bereits auf dem Commit des Requests steht.

## Einen Request zusammenführen {#merge}

Klicken Sie unten in den Details auf :ui[pullRequests.merge]. Der Merge findet beim Hosting-Dienst statt. Er lässt sich nicht widerrufen.

- **GitHub**: Wählen Sie unter :ui[pullRequests.mergeType] eine der Arten, die das Repository erlaubt: :ui[pullRequests.method.merge], :ui[pullRequests.method.rebase] oder :ui[pullRequests.method.squash]. Spooky wählt die Art vor, die Sie beim letzten Mal verwendet haben.
- **GitLab**: Das Dialogfenster zeigt :ui[pullRequests.mergeStrategy] des Projekts. Aktivieren Sie :ui[pullRequests.squash], um die Commits zusammenzufassen. Die Option fehlt, wenn das Projekt das Zusammenfassen nicht erlaubt. Sie bleibt aktiviert, wenn das Projekt es verlangt.

:ui[pullRequests.deleteBranch] entfernt den Quell-Branch beim Dienst. Anfangs entspricht die Option der Einstellung des Projekts.

Wenn sich der Request nicht zusammenführen lässt, nennt das Dialogfenster den Grund. Zum Beispiel ist er ein Entwurf, hat Konflikte, Ihr Account darf nicht zusammenführen, oder der Dienst prüft noch.

Nach dem Merge ruft Spooky vom Remote ab, um dessen Branches auf den neuesten Stand zu bringen.

## Einen Request schließen {#close}

Klicken Sie unten in den Details auf :ui[pullRequests.close] und bestätigen Sie. Um ihn wieder zu öffnen, gehen Sie zum Hosting-Dienst.

:::note[Server-Repositorys]
Die Liste und alles, was Sie beim Dienst tun, gehen von Ihrem Mac aus. Das Abrufen der Commits eines Requests, das Auschecken und das Abrufen nach einem Merge laufen auf dem Server. Ebenso die Vergleiche in :ui[pullRequests.commits] und :ui[pullRequests.changeset].
:::

Jede Anfrage an den Dienst erscheint auf der Seite :ui[activity.service] des Fensters :ui[activity.title].

## Siehe auch

- [Hosting-Accounts](/guide/hosting/accounts/)
- [Branches](/guide/branches/branches/)
- [Branch-Übersicht](/guide/branches/review/)
