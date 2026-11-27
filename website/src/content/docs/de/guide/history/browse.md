---
title: "Verlauf durchsuchen"
description: "Commit-Liste und Graph durchsehen, Referenzplaketten lesen, Commits suchen und filtern und die Darstellungsoptionen ändern."
---

Die Ansicht :ui[history.title] listet die Commits eines Repositorys auf, den neuesten zuerst, neben einem Graphen ihrer Verbindungen. Wählen Sie einen Commit aus, um rechts seine Details zu sehen.

::screenshot[Die Verlaufsansicht eines Repositorys. Im Kopf über der Liste steht, dass alle Branches, Remotes und Tags gezeigt werden, an seinem rechten Ende liegt die Taste für die Darstellungsoptionen. Die Commits sind unter November 2026 gruppiert. Farbige Linien links verbinden die Commits, und Plaketten wie HEAD, main und v0.4.0 stehen neben den Autorennamen. Rechts stehen die Details des ausgewählten Commits, oben mit den Tasten für Änderungen und Dateibaum.]{name="history" frame="window" markers="50,13.75 42,23 22.5,62 81,9"}

1. Der Kopf: was die Liste zeigt, und die Darstellungsoptionen
2. Plaketten für die Branches und Tags, die auf einen Commit zeigen
3. Der Commit-Graph
4. Details des ausgewählten Commits. Siehe [Commit-Details](/guide/history/commit-details/).

## Den Verlauf öffnen {#open}

- :ui[menu.view > menu.showHistory] (<kbd>⌘2</kbd>) oder :ui[history.title] in der Seitenleiste zeigt alle Branches, Remote-Branches und Tags zusammen. Im Kopf steht :ui[history.all].
- Klicken Sie in der Seitenleiste auf einen Branch, ein Tag oder einen Remote-Branch, um nur dessen Verlauf zu sehen. Klicken Sie bei gedrückter <kbd>⌘</kbd>-Taste auf weitere, um sie zusammen zu sehen.
- :ui[menu.view > history.showHead] (<kbd>⌘0</kbd>) zeigt den Verlauf des Branches, auf dem Sie sich befinden.

Wenn Sie einen lokalen Branch mit Upstream ansehen, zeigt der Kopf beide, wie in `main › origin/main`. Die Liste enthält dann auch Commits im Upstream, die Sie noch nicht gepullt haben.

## Die Commit-Liste {#list}

Jede Zeile zeigt Avatar und Namen des Autors, das Datum, den Kurz-Hash und die erste Zeile der Nachricht. Standardmäßig sind die Commits nach Monat gruppiert.

Zeigt die Liste einen lokalen Branch mit Upstream:

- ↑ markiert einen Commit, den Sie noch nicht gepusht haben.
- ↓ markiert einen Commit, den Sie noch nicht gepullt haben. Diese Zeilen sind abgeblendet.

Spooky lädt die ersten 100 Commits. Die nächsten 100 lädt es, wenn Sie zum Ende scrollen. Um mehr auf einmal zu laden, ändern Sie :ui[history.pageSize] unter :ui[app.name > settings.title] › :ui[settings.general]. Auf derselben Seite legt :ui[settings.dateFormat] fest, wie Datumsangaben in der Liste aussehen. Siehe [Verlauf und Diffs](/guide/settings/general/#history).

Klicken Sie auf einen Commit, um ihn auszuwählen. Mit <kbd>⇧</kbd>-Klick oder <kbd>⌘</kbd>-Klick wählen Sie mehrere aus. <kbd>⌘C</kbd> kopiert die vollständigen Hashes der ausgewählten Commits. Doppelklicken Sie auf einen Commit, um seine Details als ganze Seite zu öffnen.

Klicken Sie mit der rechten Maustaste auf einen Commit, um alles zu sehen, was Sie damit tun können. Ist der Commit nicht ausgewählt, wirkt das Menü nur auf diesen einen Commit. Ihre Auswahl bleibt, wie sie ist.

## Der Commit-Graph {#graph}

Der Graph links zeichnet jeden Commit als Punkt, mit Linien nach unten zu seinen Eltern. Bei einem Merge-Commit führt mehr als eine Linie nach unten.

Um ihn auszublenden, deaktivieren Sie :ui[history.showGraph] in den [Darstellungsoptionen](#view-options) (<kbd>⌃⌘G</kbd>). :ui[history.firstParentOnly] folgt nur dem ersten Eltern-Commit jedes Merges. Commits, die über einen Merge hereingekommen sind, werden ausgelassen.

## Referenzplaketten {#badges}

Plaketten neben dem Autorennamen zeigen, was auf einen Commit zeigt:

| Plakette | Auf den Commit zeigt |
|---|---|
| Blau, HEAD | Der Commit, den Sie ausgecheckt haben |
| Blau | Ein lokaler Branch |
| Grau | Ein Remote-Branch |
| Gelb | Ein Tag |
| Rot | Ein Stash |

Der Branch, auf dem Sie sich befinden, steht zuerst. Plaketten, die keinen Platz haben, werden zu „…“ zusammengefasst.

Klicken Sie auf die Plakette eines Tags, um dessen Signatur zu sehen: den Schlüssel und ob sie gültig ist, oder :ui[signature.unsigned].

## Suchen und filtern {#search}

1. Drücken Sie <kbd>⌘F</kbd> oder klicken Sie in das Suchfeld in der Symbolleiste.
2. Klicken Sie auf die Lupe im Feld, um zu wählen, wonach gesucht wird: :ui[history.search.message], :ui[history.search.author], :ui[history.search.committer], :ui[history.search.file], :ui[history.search.hash], :ui[history.search.sinceDate] oder :ui[history.search.untilDate].
3. Tippen Sie. Die Liste zeigt nur die passenden Commits.

Während Sie tippen, schlägt Spooky Autoren, Committer und Dateipfade vor. Bei der Suche in Nachrichten können Sie über die Vorschläge auch zu einer anderen Art der Suche wechseln. Geben Sie ein Datum ein, sucht der erste Vorschlag nach Commits seit diesem Datum.

So passt jede Art:

- Nachrichten, Autoren und Committer werden als reguläre Ausdrücke verglichen, ohne Rücksicht auf Groß- und Kleinschreibung.
- Eine Datei passt zu den Commits, die sie geändert haben. Ein Ordner passt zu den Commits, die irgendetwas darin geändert haben.
- Ein Commit-Hash braucht mindestens die ersten 4 Zeichen.

Die Suche erscheint als Zeile unter dem Kopf. Um eine weitere Bedingung hinzuzufügen, klicken Sie auf die Hinzufügen-Taste und wählen Sie ihre Art aus dem Menü am Anfang der neuen Zeile. Für ein Datum wählen Sie :ui[history.search.after], :ui[history.search.before] oder :ui[history.search.range]. Um eine Bedingung zu entfernen, klicken Sie auf ihre Taste zum Entfernen.

Bei mehreren Bedingungen:

- Bedingungen verschiedener Art müssen alle zutreffen.
- Von mehreren Bedingungen derselben Art muss ein Commit nur eine erfüllen. Datumsangaben sind die Ausnahme: Ein Commit muss jede Datumsbedingung erfüllen.

Drücken Sie <kbd>Esc</kbd>, um das Suchfeld zu verlassen. Die Liste bleibt gefiltert. Die Suche endet, wenn Sie zu einer anderen Ansicht wechseln.

## Darstellungsoptionen {#view-options}

Klicken Sie auf die Taste für die Darstellungsoptionen am rechten Ende des Kopfs oder wählen Sie :ui[menu.view > history.title]:

| Option | Wirkung |
|---|---|
| :ui[history.showGraph] | Zeigt den Commit-Graphen. Standardmäßig aktiviert. |
| :ui[history.firstParentOnly] | Folgt nur dem ersten Eltern-Commit jedes Merges |
| :ui[history.sortBy] | :ui[history.sort.topo] hält die Commits jedes Arbeitsstrangs zusammen. :ui[history.sort.date] ordnet sie nach Datum. Solange der Graph gezeigt wird, bleibt :ui[history.sort.topo] aktiviert. Sind beide aktiviert, gilt die Reihenfolge nach Datum. |
| :ui[history.groupBy] | Gruppiert Commits nach Tag, Woche oder Monat unter Überschriften, oder gar nicht. Gilt nur bei Sortierung nach Datum. |
| :ui[history.medium] / :ui[history.small] | Zwei Zeilen pro Commit oder eine. Kleine Zeilen gelten nur, solange der Graph gezeigt wird. |
| :ui[signature.verify] | Markiert signierte Commits. Siehe [Signaturen](/guide/history/commit-details/#signatures). |
| :ui[history.compareBranches] | Siehe [Mit einem anderen Branch vergleichen](#compare-branches) |

Diese Optionen gelten für jedes Fenster und jedes Repository. Spooky merkt sie sich.

## Mit einem anderen Branch vergleichen {#compare-branches}

So sehen Sie, wie ein lokaler Branch zu einem anderen steht:

1. Klicken Sie in der Seitenleiste auf den Branch.
2. Klicken Sie im Kopf auf die Taste zum Vergleichen. Sie können auch :ui[history.compareBranches] in den Darstellungsoptionen aktivieren oder <kbd>⌃⌥⌘C</kbd> drücken.
3. Wählen Sie neben :ui[history.compareTo] den anderen Branch aus dem Menü. Spooky beginnt mit dem Eltern-Branch, falls der Branch einen hat.

Eine Zeile in der Liste markiert, wo sich die beiden Branches getrennt haben. Die Commits darunter gehören auch zum anderen Branch. Sie sind abgeblendet. Hat der Branch noch keine eigenen Commits, steht in der Liste :ui[history.noNewCommits].

Der Kopf kann außerdem zwei Plaketten zeigen. Die eine zählt die Commits im anderen Branch, die dieser Branch noch nicht hat. Die andere erscheint, wenn das Zusammenführen des anderen Branches Konflikte verursachen würde. Klicken Sie darauf, um die Dateien aufzulisten.

## Einen Commit im Verlauf finden {#reveal}

Zeigt die Liste nur einige Branches, klicken Sie mit der rechten Maustaste auf einen Commit und wählen Sie :ui[quickActions.revealInHistory]. Die Liste wechselt zu allen Branches und wählt den Commit aus.

Liegt der Commit weit zurück, jenseits der ersten 10.000 Commits, fragt Spooky nach, bevor es den Verlauf so weit lädt. Ist der Commit nicht im Verlauf, sagt das eine Zeile über der Liste.

## Siehe auch

- [Commit-Details](/guide/history/commit-details/)
- [Verlauf umschreiben](/guide/history/rewrite/)
- [Branches](/guide/branches/branches/)
