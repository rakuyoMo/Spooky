---
title: "Widerrufen und Wiederherstellen"
description: "Erfahren Sie, was ⌘Z widerrufen kann und warum sich manche Vorgänge nicht widerrufen lassen, und holen Sie verlorene Commits mit dem Reflog zurück."
---

Das meiste, was Sie in Spooky mit einem Repository tun, lässt sich mit <kbd>⌘Z</kbd> zurücknehmen. Für den Rest merkt sich das Reflog von Git, wo Ihre Branches gewesen sind, sodass ein Commit selten endgültig verloren ist.

## Widerrufen und wiederholen {#undo}

Wählen Sie :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>), um den letzten Vorgang zurückzunehmen. Der Menüeintrag enthält den Namen des Vorgangs. Wählen Sie :ui[menu.edit > menu.redo] (<kbd>⇧⌘Z</kbd>), um ihn erneut auszuführen. Sie können mehrere Vorgänge zurückgehen, den neuesten zuerst.

Widerrufen lässt sich zum Beispiel:

- Stagen, Committen und Ändern des letzten Commits
- Verwerfen von Änderungen und Legen von Dateien in den Papierkorb
- Sichern, Anwenden und Löschen von Stashes
- Auschecken, Erstellen, Umbenennen und Löschen von Branches sowie Erstellen von Tags
- Anheften und Archivieren von Branches, Festlegen des Upstreams und Fast-Forward
- Merge, Rebase, Cherry-Pick, Revert und Zurücksetzen
- Hinzufügen, Umbenennen und Entfernen von Remotes sowie Ändern ihrer Einstellungen
- Veröffentlichen von Branches und Tags sowie Umbenennen von Remote-Branches
- Markieren von Dateien als assume-unchanged, Aktivieren von Git LFS und Ändern von Submodulen

Dateien, die in den Papierkorb gekommen sind, werden aus dem Papierkorb zurückgelegt. Wenn Sie ein Zurücksetzen widerrufen, während versionierte Dateien Änderungen haben, fragt Spooky zuerst, ob sie gestasht werden sollen. Der neue Stash bleibt in der Liste.

Während Sie in ein Textfeld tippen, etwa in die Commit-Nachricht, widerruft <kbd>⌘Z</kbd> stattdessen Ihre Eingabe.

Jedes Repository hat einen einzigen Widerrufen-Verlauf, den alle seine Fenster teilen. Spooky behält ihn, bis Sie die App beenden. Die dafür nötigen Snapshots liegen in der eigenen Git-Datenbank des Repositorys und werden nirgendwohin gepusht.

:::note[Server-Repositorys]
Die Snapshots liegen im Repository auf dem Server. Dateien, die in den Papierkorb des Servers gekommen sind, werden von dort zurückgelegt.
:::

## Was sich nicht widerrufen lässt {#cant-undo}

Widerrufen versetzt das Repository in den vorherigen Zustand. Manche Änderungen liegen außerhalb dessen, was Spooky wiederherstellen kann:

- Löschen von Branches und Tags auf einem Remote. Eine Ausnahme ist das Löschen eines lokalen Branches zusammen mit seinem Remote-Branch: Widerrufen erstellt beide neu.
- Ändern der Committer-Identität, der Ignorierregeln oder anderer Git-Einstellungen.
- Alles, was Sie tun, während ein Merge, Rebase oder anderer Vorgang läuft, einschließlich Fortfahren oder Abbrechen.
- Ein Rebase oder Cherry-Pick, der an einem Konflikt anhält. Ein Merge oder Revert, der an Konflikten anhält, lässt sich widerrufen, was ihn abbricht.
- Neue Dateien, die endgültig gelöscht wurden, zum Beispiel auf einem Server ohne Papierkorb.
- Initialisieren, Synchronisieren und Reparieren von Submodulen; alles, was Sie mit Worktrees tun; Aktualisieren der Git-LFS-Hooks; und Veröffentlichen eines Repositorys bei einem Hosting-Dienst. Siehe [Submodule](/guide/advanced/submodules/#undo), [Worktrees](/guide/advanced/worktrees/#undo), [Git LFS](/guide/advanced/lfs/#undo) und [Ein Repository veröffentlichen](/guide/hosting/accounts/#publish).

Nach einem dieser Vorgänge sagt der Menüeintrag, dass sich der Vorgang nicht widerrufen lässt. Auch Vorgänge davor lassen sich dann nicht mehr widerrufen.

Abrufen, Pullen, Pushen und Synchronisieren werden nicht aufgezeichnet. Sie lassen sich nicht widerrufen. Dasselbe gilt für das Abrufen und Aktualisieren von Submodulen und für das Abrufen, Pullen und Pushen von LFS-Inhalten.

## Wenn Widerrufen blockiert ist {#blocked}

Widerrufen funktioniert nur, solange das Repository noch so ist, wie der Vorgang es hinterlassen hat. Ist das nicht der Fall, ist der Menüeintrag abgeblendet und nennt in Klammern einen Grund:

| Grund | Was zu tun ist |
|---|---|
| :ui[undo.reason.busy] | Warten Sie, bis der laufende Vorgang fertig ist, oder schließen Sie den laufenden Merge, Rebase oder anderen Vorgang ab. |
| :ui[undo.reason.disconnected] | Verbinden Sie sich erneut mit dem Server. |
| :ui[undo.reason.changed] | Das Repository hat sich seit dem Vorgang geändert: Ein Pull oder eine Synchronisation hat Commits gebracht, oder das Terminal oder eine andere App hat es geändert. Stellen Sie den Zustand wieder her, und Widerrufen funktioniert wieder. |

Unmittelbar vor dem Widerrufen prüft Spooky das Repository noch einmal. Ist etwas im Weg, hält es an und sagt Ihnen, warum. Nichts wird geändert.

| Meldung | Grund |
|---|---|
| :ui[undo.error.changed] | Das Repository entspricht nicht mehr dem, was Spooky aufgezeichnet hat. |
| :ui[undo.error.untracked] | Das Wiederherstellen würde nicht verfolgte Dateien überschreiben oder löschen. |
| :ui[undo.error.hidden] | Als assume-unchanged markierte Dateien haben lokale Änderungen, oder das Repository verwendet skip-worktree. |
| :ui[undo.error.inProgress] | Schließen Sie zuerst den Merge, Rebase, Cherry-Pick oder Revert ab oder brechen Sie ihn ab. |
| :ui[undo.error.conflicts] | Lösen Sie zuerst die Konflikte. Siehe [Konflikte lösen](/guide/work/conflicts/). |
| :ui[undo.error.trash] | Einige Dateien liegen nicht mehr im Papierkorb, oder an ihrem alten Ort liegen jetzt andere Dateien. |

## Commits mit dem Reflog zurückholen {#reflog}

Git führt ein Protokoll darüber, wohin HEAD und jeder lokale Branch gezeigt haben. Ein Commit, den Sie durch Zurücksetzen, Rebase oder das Löschen eines Branches verloren haben, steht meist noch darin. Änderungen, die Sie nie committet haben, stehen dort nicht.

1. Wählen Sie :ui[menu.view > reflog.show] (<kbd>⌘6</kbd>).
2. Wählen Sie oben in :ui[reflog.ref] HEAD oder einen lokalen Branch.
3. Suchen Sie den Eintrag. Jeder zeigt den Kurz-Hash, was passiert ist und wann, darunter die Beschreibung von Git. Um die Liste zu filtern, tippen Sie in das Suchfeld in der Symbolleiste.
4. Wählen Sie den Eintrag aus, um die Details des Commits zu sehen.

::screenshot[Die Reflog-Ansicht für HEAD. Jeder Eintrag zeigt einen Kurz-Hash, eine Aktion wie commit, checkout oder reset und ein Datum, darunter die Nachricht. Rechts stehen die Commit-Details des ausgewählten Eintrags.]{name="work-reflog" frame="window" markers="33.5,9 44.1,37.1 84.4,21.3"}

1. Das Menü :ui[reflog.ref]
2. Der ausgewählte Eintrag
3. Die Details des Commits

Klicken Sie mit der rechten Maustaste auf den Eintrag, um den Commit zurückzuholen:

- :ui[reflog.createBranch]{1="9e0d36a7"} beginnt dort einen neuen Branch. Ihre vorhandenen Branches bleiben, wie sie sind.
- :ui[reflog.restore]{1="feature/units-toggle" 2="9e0d36a7"} verschiebt den angezeigten Branch zurück auf diesen Commit. Arbeitskopie und Index ändern sich nicht. Spooky fragt vorher nach, und Sie können es widerrufen.
- :ui[reflog.cherryPick]{1="9e0d36a7"} kopiert den Commit auf den aktuellen Branch. Sie können den Eintrag auch auf :ui[workspace.title] oder den aktuellen Branch in der Seitenleiste ziehen.
- :ui[reflog.reset]{1="9e0d36a7"} öffnet das Dialogfenster zum Zurücksetzen, um den aktuellen Branch auf diesen Commit zu verschieben.
- :ui[patch.menu]{1="9e0d36a7"} sichert den Commit als Patch-Datei.

Um :ui[reflog.title] in der Seitenleiste zu haben, aktivieren Sie :ui[sidebar.showReflog] in :ui[sidebar.viewSettings].

:::caution
Git entfernt alte Reflog-Einträge mit der Zeit. Standardmäßig bleiben Einträge 90 Tage erhalten, und 30 Tage, wenn ihr Commit nicht mehr im Branch liegt. Holen Sie verlorene Commits bald zurück.
:::

:::note[Server-Repositorys]
Das Reflog liegt im Repository auf dem Server. Spooky liest es dort.
:::

## Siehe auch

- [Änderungen committen](/guide/work/commit/)
- [Konflikte lösen](/guide/work/conflicts/)
- [Verlauf umschreiben](/guide/history/rewrite/)
