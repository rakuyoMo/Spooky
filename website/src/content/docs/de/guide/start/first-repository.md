---
title: "Ihr erstes Repository"
description: "Öffnen Sie ein Repository auf Ihrem Mac und ändern, stagen, committen und pushen Sie Ihre Arbeit von Anfang bis Ende."
---

Diese Seite führt Sie durch einen vollständigen Arbeitsdurchgang. Sie öffnen ein Repository auf Ihrem Mac, ändern eine Datei, stagen die Änderung, committen sie und pushen den Commit zu einem Remote.

Sie brauchen ein Git-Repository auf Ihrem Mac mit einem Remote, zu dem Sie pushen können. Wenn Sie noch keines haben, zeigt [Das Fenster „Repositorys“](/guide/repositories/manager/), wie Sie eines klonen oder erstellen.

## Das Repository öffnen {#open}

1. Wählen Sie :ui[menu.file > action.openLocal] (<kbd>⌘O</kbd>).
2. Wählen Sie den Ordner des Repositorys aus und klicken Sie auf :ui[repositories.panel.prompt].

Spooky öffnet das Repository und zeigt dessen :ui[workspace.title]. Außerdem nimmt es das Repository in die Liste der Repositorys auf. Beim nächsten Mal können Sie es von dort öffnen.

Sie können einen beliebigen Ordner innerhalb des Repositorys wählen. Spooky öffnet das ganze Repository. Wenn der Ordner in keinem Git-Repository liegt, meldet Spooky :ui[bookmarks.noRepository.title]. Klicken Sie auf :ui[bookmarks.noRepository.create], um aus dem Ordner ein neues Repository zu machen, oder auf :ui[action.cancel], um einen anderen zu wählen.

:::note[Server-Repositorys]
Um in einem Repository auf einem Server zu arbeiten, fügen Sie es stattdessen mit :ui[action.addRemote] hinzu. [Server-Repository hinzufügen](/guide/server/add/) zeigt, wie das geht. Sobald es geöffnet ist, funktioniert der Rest dieser Seite genauso.
:::

## Etwas ändern {#change}

Bearbeiten Sie eine Datei im Repository mit einem beliebigen Editor und sichern Sie sie. Spooky bemerkt die Änderung und führt die Datei unter :ui[workspace.title] auf. Wenn eine Änderung nicht erscheint, klicken Sie auf :ui[action.refresh] oder drücken Sie <kbd>⌘R</kbd>.

Wählen Sie die Datei aus, um in der rechten Spalte zu sehen, was sich geändert hat. Hinzugefügte Zeilen sind grün, entfernte Zeilen rot.

## Die Änderung stagen {#stage}

Git committet nicht alles, was Sie geändert haben. Es committet nur, was Sie stagen. Beim Stagen legen Sie fest, welche Änderungen in den nächsten Commit kommen. Alles andere bleibt für später in der Arbeitskopie.

Um eine Datei zu stagen, führen Sie einen der folgenden Schritte aus:

- Aktivieren Sie das Markierungsfeld vor der Datei.
- Wählen Sie eine oder mehrere Dateien aus und drücken Sie die <kbd>Leertaste</kbd>.
- Klicken Sie auf :ui[working.stageAll], um alle geänderten Dateien zu stagen.

Bei gestagten Dateien bleibt das Markierungsfeld aktiviert. Wie Sie nur einige Zeilen einer Datei stagen, lesen Sie unter [Änderungen prüfen und stagen](/guide/work/diff/).

## Committen {#commit}

Ein Commit sichert die gestagten Änderungen im Verlauf des Repositorys. Dazu gehört eine Nachricht, die sagt, was Sie geändert haben und warum.

1. Klicken Sie auf :ui[working.subject] und geben Sie eine kurze Zusammenfassung der Änderung ein. Der Commit-Bereich klappt beim Tippen auf.
2. Wenn Sie mehr erklären möchten, schreiben Sie es in :ui[working.body].
3. Klicken Sie auf :ui[working.commit] oder drücken Sie <kbd>⌘↩</kbd>.

::screenshot[Der Commit-Bereich mit dem eingegebenen Betreff „Add gust alerts and a humidity chart“. Darunter stehen eine leere ausführliche Beschreibung, die Markierungsfelder zum Ändern des letzten Commits und zum Abzeichnen, Name und E-Mail des Autors sowie die Tasten zum Stagen aller Dateien und zum Committen. Die Dateiliste darunter zeigt drei Dateien mit aktivierten Markierungsfeldern.]{name="start-commit" frame="closeup"}

Einige Dinge im aufgeklappten Commit-Bereich:

- Die Zahl am Ende des Betrefffelds zählt die Zeichen, die Ihnen bleiben. Darüber hinaus ist der Betreff länger als empfohlen.
- :ui[working.commit] bleibt abgeblendet, bis der Betreff Text enthält.
- Name und E-Mail rechts werden im Commit als Autor festgehalten. Wie Sie sie ändern, lesen Sie unter [Benutzerprofile und Git-Konfiguration](/guide/settings/identity/).
- :ui[working.amend] und :ui[commit.signOff] sind unter [Änderungen committen](/guide/work/commit/) erklärt.

Nach dem Commit verschwinden die committeten Dateien aus der Liste. In der Seitenleiste zeigt der aktuelle Branch jetzt ↑1. Das ist ein Commit auf Ihrem Mac, der noch nicht auf dem Remote ist.

## Pushen {#push}

Beim Pushen werden Ihre Commits an das Remote gesendet. Andere können sie von dort holen, und das Remote bewahrt eine Kopie als Backup auf.

1. Klicken Sie in der Symbolleiste auf :ui[sync.push] oder wählen Sie :ui[menu.repository > sync.pushMenu] (<kbd>⇧⌘U</kbd>).
2. Prüfen Sie, ob :ui[sync.destination] der Remote-Branch ist, zu dem Sie pushen möchten. Wenn der Branch bereits einem Remote-Branch folgt, ist dieser ausgewählt.
3. Klicken Sie auf :ui[sync.pushHead].

::screenshot[Das Dialogfenster zum Pushen von HEAD. Es pusht die neuen Commits des lokalen Branches „main“ zum Ziel origin/main. Darunter stehen ein eingeklappter Abschnitt mit Optionen und die Tasten zum Abbrechen und zum Pushen von HEAD.]{name="sync" frame="dialog"}

Wenn der Push fertig ist, verschwindet das ↑1 neben dem Branch. [Pushen](/guide/branches/sync/#push) behandelt :ui[dialog.options]. Wie Sie einen Branch zum ersten Mal pushen, lesen Sie unter [Einen Branch veröffentlichen](/guide/branches/sync/#publish).

:::tip
Halten Sie <kbd>⌥</kbd> gedrückt und klicken Sie auf die Taste :ui[sync.push]. Sie wird zu :ui[sync.quickPush] und pusht den aktuellen Branch sofort zu seinem Tracking-Branch, ohne das Dialogfenster.
:::

## Siehe auch

- [Arbeitskopie](/guide/work/working-copy/)
- [Änderungen committen](/guide/work/commit/)
- [Abrufen, Pullen und Pushen](/guide/branches/sync/)
