---
title: "Warteschlange und Aktivität"
description: "Sehen Sie, wie Spooky Schreibvorgänge einreiht, verfolgen und stoppen Sie sie im Aktivitätsbereich der Seitenleiste und im Fenster „Aktivität“, und erhalten Sie Systemmitteilungen."
---

Spooky ändert ein Repository mit einem Vorgang nach dem anderen. Starten Sie etwas, während ein anderer Vorgang läuft, wartet Ihrer, bis er an der Reihe ist, statt abgewiesen zu werden. Das Laden von Status, Verlauf und Diffs wartet nicht.

## Wie Vorgänge eingereiht werden {#queue}

Läuft im Repository nichts, startet ein Vorgang sofort. Andernfalls kommt er in die Warteschlange des Repositorys, und die Vorgänge laufen in der Reihenfolge, in der Sie sie gestartet haben. Alle Fenster, die das Repository zeigen, teilen dieselbe Warteschlange.

Das gilt für alles, was das Repository ändert, egal wo Sie es starten: Menüs, die Symbolleiste, Kontextmenüs, Schnellaktionen, Drag & Drop, Doppelklicks, Dialogfenster, die Dateiliste und der Commit-Bereich.

- Menüeinträge und Tasten bleiben verfügbar, während das Repository beschäftigt ist. Ein Dialogfenster schließt sich wie gewohnt, wenn Sie auf seine Taste klicken.
- Verlangt ein Vorgang eine Bestätigung, etwa das Löschen eines Branches oder ein Force-Push, fragt er beim Klicken. Er fragt nicht noch einmal, wenn er an der Reihe ist.
- Fragen, die vom Repository in diesem Moment abhängen, etwa ob Änderungen gestasht werden sollen, die im Weg sind, kommen, wenn der Vorgang an der Reihe ist.

Während ein Vorgang läuft, der die Arbeitskopie oder den Index ändert, ist die Dateiliste abgeblendet, auch wenn Sie den Vorgang in einem anderen Fenster gestartet haben. Andere Vorgänge wie Abrufen und Pushen lassen die Dateiliste, wie sie ist, und was Sie dort tun, kommt in die Warteschlange.

Ein wartender Commit hält seine Nachricht und Optionen gesperrt, bis er ausgeführt wird.

## Wenn der Vorgang an der Reihe ist {#turn}

Nachdem der Vorgang davor fertig ist und das Fenster aktualisiert wurde, prüft Spooky den nächsten gegen das Repository, wie es jetzt ist. Es verwendet dieselben Regeln, die entscheiden, ob der Menüeintrag verfügbar ist. Ergibt der Vorgang keinen Sinn mehr, zum Beispiel weil der Branch, auf dem er arbeitet, weg ist, wird er nicht ausgeführt. In seinem Eintrag steht :ui[activity.skipped], mit dem Grund.

Schlägt ein Vorgang fehl, wird alles abgebrochen, was nach ihm eingereiht ist, damit nichts auf dem Fehler aufbaut. In den Einträgen steht, welcher Vorgang fehlgeschlagen ist. Stoppen Sie einen laufenden Vorgang selbst, stoppt nur dieser, und die übrigen laufen weiter.

Eingereihte Vorgänge werden außerdem abgebrochen, wenn:

- Die Verbindung zu einem Server-Repository verloren geht. Nach dem erneuten Verbinden werden sie nicht ausgeführt.
- Sie das Fenster schließen oder darin ein anderes Repository öffnen. Nur Vorgänge, die von diesem Fenster aus gestartet wurden, werden abgebrochen.
- Sie Spooky beenden.

## Widerrufen und wiederholen {#undo}

Widerrufen und Wiederholen werden nicht eingereiht. Solange ein von Ihnen gestarteter Vorgang läuft oder wartet, sind sie nicht verfügbar, und im Menü steht :ui[undo.reason.busy]. Siehe [Wenn Widerrufen blockiert ist](/guide/work/undo/#blocked).

## Automatisches Abrufen {#auto-fetch}

Das [automatische Abrufen](/guide/branches/sync/#auto-fetch) startet nur, wenn im Repository nichts läuft oder wartet. Starten Sie während des Abrufens irgendetwas, auch Widerrufen und Wiederholen, stoppt es sofort, und Ihr Vorgang läuft. In seinem Eintrag steht :ui[activity.cancelled] und für welchen Vorgang es Platz gemacht hat.

## Der Aktivitätsbereich {#activity-area}

Der untere Teil der Seitenleiste listet für das Repository im Fenster auf:

- Abrufen, Pullen, Pushen und andere Vorgänge, die sich mit einem Remote verbinden, während sie laufen und noch einige Sekunden danach. Der neueste steht oben.
- Darunter die Vorgänge, die in der Warteschlange warten, der nächste oben. Anstelle der Git-Ausgabe zeigen sie :ui[activity.waitingDetail], bis sie an der Reihe sind.

Jede Zeile hat einen Fortschrittsbalken, eine Stopptaste und die letzte Zeile der Git-Ausgabe. Bis zu drei Zeilen sind gleichzeitig zu sehen. Scrollen Sie für weitere.

- Klicken Sie in einer wartenden Zeile auf die Stopptaste, um den Vorgang aus der Warteschlange zu nehmen. Nichts wird ausgeführt, und in der Zeile steht, dass der Vorgang abgebrochen wurde.
- Klicken Sie in einer laufenden Zeile auf die Stopptaste, um den Vorgang zu stoppen.
- Klicken Sie irgendwo sonst in eine Zeile, um das Fenster :ui[activity.title] zu öffnen.

Vorgänge, die sich nicht mit einem Remote verbinden, verlassen den Bereich, wenn sie starten. Ihr Fortschritt erscheint im Fenster selbst, zum Beispiel in der Arbeitskopie oder im Commit-Bereich.

## Das Fenster „Aktivität“ {#activity-window}

Wählen Sie :ui[menu.window > activity.title] (<kbd>⌃⌘0</kbd>). Das Fenster enthält Einträge aus allen Repositorys, auf drei Seiten, die Sie in der Symbolleiste wählen:

| Seite | Was sie auflistet | Wie lange Einträge bleiben |
|---|---|---|
| :ui[activity.remote] | Abrufen, Pullen, Pushen und andere Vorgänge, die sich mit einem Remote verbinden | 7 Tage, auf Ihrem Mac gesichert |
| :ui[activity.repository] | Andere Git-Vorgänge und Ladevorgänge, die Sie starten, etwa das Laden von Commits | Die letzten 100, bis Sie die App beenden |
| :ui[activity.service] | Anfragen an GitHub und GitLab | Bis Sie die App beenden |

::screenshot[Das Fenster „Aktivität“ auf der Seite für Remote-Aktivitäten. Die Liste enthält Einträge für Abrufen, Pullen und Pushen eines Repositorys. Der Push ist ausgewählt, rechts steht sein vollständiges Protokoll.]{name="advanced-activity" frame="window" markers="58.5,10 32.8,4.6 93.8,4.6"}

1. Die Seiten: :ui[activity.remote], :ui[activity.repository] und :ui[activity.service]
2. :ui[activity.clear]
3. Das Suchfeld

Ladevorgänge, die Spooky von selbst ausführt, um ein Fenster aktuell zu halten, werden nicht aufgelistet.

Wählen Sie einen Eintrag aus, um rechts sein vollständiges Protokoll zu sehen. Sie können den Text auswählen und kopieren.

- Wartende Vorgänge stehen auch hier, als :ui[activity.waiting], mit einer Stopptaste.
- :ui[activity.clear] entfernt die abgeschlossenen Einträge auf der aktuellen Seite. Laufende bleiben.
- Das Suchfeld filtert die aktuelle Seite nach Repository-Name und Protokolltext.

Passwörter und Token werden aus den Protokollen ausgelassen.

## Systemmitteilungen {#notifications}

Spooky sendet eine Mitteilung, wenn:

- Ein Klonvorgang fertig ist. Sie zeigt die Remote-Adresse, ohne Benutzernamen oder Passwort darin, und wohin das Repository geklont wurde. Siehe [Ein Repository klonen](/guide/repositories/manager/#clone).
- Branches automatisch archiviert werden. Sie zeigt, wie viele. Siehe [Automatisch archivieren](/guide/branches/review/#auto-archive).

Spooky fragt nicht nach einer Erlaubnis, deshalb stellt macOS die Mitteilungen zunächst still in der **Mitteilungszentrale** zu. Um festzulegen, wie sie erscheinen, wählen Sie **Apple-Menü › Systemeinstellungen**, klicken Sie in der Seitenleiste auf **Mitteilungen** und dann auf **Spooky**. Ein Klick auf eine Mitteilung holt Spooky nach vorn.

:::note[Server-Repositorys]
Jedes Server-Repository hat seine eigene Warteschlange, wie ein lokales. Das Stoppen eines Vorgangs oder ein automatisches Abrufen, das Platz macht, beendet auch den Git-Prozess auf dem Server.
:::

## Siehe auch

- [Abrufen, Pullen und Pushen](/guide/branches/sync/)
- [Widerrufen und Wiederherstellen](/guide/work/undo/)
- [Verbindungsstatus und erneutes Verbinden](/guide/server/connection/)
