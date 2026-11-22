---
title: "Stashes"
description: "Stashes sichern, anwenden und ansehen sowie das automatische Stashen nutzen."
---

Ein Stash legt Ihre lokalen Änderungen beiseite, ohne sie zu committen. Verwenden Sie ihn, wenn Sie kurz eine saubere Arbeitskopie brauchen, zum Beispiel um den Branch zu wechseln oder zu pullen, und Ihre Änderungen danach zurückhaben möchten.

Stashes gehören zum Repository. Sie werden nicht zum Remote gepusht.

## Einen Stash sichern {#save}

1. Wählen Sie :ui[workspace.title > stash.saveMenu] (<kbd>⇧⌘S</kbd>) oder klicken Sie in der Symbolleiste auf :ui[toolbar.saveStash].
2. Beschreiben Sie die Änderungen bei Bedarf in :ui[stash.message], damit Sie den Stash später wiederfinden.
3. Um auch neue Dateien beiseitezulegen, aktivieren Sie :ui[stash.includeUntracked]. Spooky merkt sich diese Wahl.
4. Klicken Sie auf :ui[stash.save].

Alle Ihre Änderungen kommen in den Stash, und die Arbeitskopie ist wieder sauber. Gibt es nichts zu sichern, meldet Spooky :ui[stash.error.noChanges]. Neue Dateien zählen nur, wenn :ui[stash.includeUntracked] aktiviert ist.

Um eine Kopie Ihrer Änderungen zu sichern und trotzdem daran weiterzuarbeiten, wählen Sie stattdessen :ui[workspace.title > stash.snapshotMenu] (<kbd>⌃⇧⌘S</kbd>). Das Dialogfenster ist dasselbe, und die Arbeitskopie bleibt, wie sie ist.

## Einzelne Dateien stashen {#partial}

Um nur einige Dateien beiseitezulegen, wählen Sie sie in der Arbeitskopie aus, klicken Sie mit der rechten Maustaste und wählen Sie :ui[stash.stashFile]{1="README.md"} oder :ui[stash.stashItems]{1="3"} aus dem Menü. Die Snapshot-Einträge darunter lassen die Dateien, wie sie sind.

Sie können die Dateien auch auf :ui[stash.title] in der Seitenleiste ziehen.

Ausgewählte neue Dateien kommen immer in den Stash, unabhängig davon, ob :ui[stash.includeUntracked] aktiviert ist.

:::tip
Halten Sie <kbd>⌥</kbd> gedrückt, während das Menü geöffnet ist, und die Einträge werden zu Schnellversionen wie :ui[stash.quickStashFile]{1="README.md"}. Sie sichern sofort, ohne Dialogfenster, mit einer Nachricht, die Git schreibt.
:::

## Stashes ansehen {#view}

Klicken Sie in der Seitenleiste auf :ui[stash.title] oder wählen Sie :ui[menu.view > stash.show] (<kbd>⌘3</kbd>).

Die Liste links zeigt den neuesten Stash zuerst. Jede Zeile zeigt :ui[stash.basedOn] mit dem Branch, von dem aus der Stash gesichert wurde, das Datum und die Nachricht. Um die Liste zu filtern, tippen Sie in das Suchfeld in der Symbolleiste.

::screenshot[Die Stash-Ansicht. Die Liste links zeigt drei Stashes, ausgewählt ist Halfway through the units toggle. Rechts stehen seine Details, unter den Commit-Informationen erscheinen die Tasten zum Anwenden, Löschen und für das Vergleichswerkzeug.]{name="work-stashes" frame="window" markers="33,36 86.5,35.5"}

1. Die Liste der Stashes
2. :ui[stash.applyButton], :ui[stash.deleteButton] und :ui[history.diffTool]

Wählen Sie einen Stash aus, um rechts seine Änderungen zu sehen, aufgebaut wie die Details eines Commits. Bewegen Sie den Zeiger über die Details, um die Tasten :ui[stash.applyButton], :ui[stash.deleteButton] und :ui[history.diffTool] einzublenden. :ui[history.diffTool] öffnet den Stash in Ihrem Vergleichswerkzeug.

## Einen Stash anwenden {#apply}

Das Anwenden bringt die Änderungen eines Stashes zurück in die Arbeitskopie.

1. Wählen Sie :ui[workspace.title > stash.applyMenu] (<kbd>⌥⇧⌘S</kbd>) oder klicken Sie in der Symbolleiste auf :ui[toolbar.applyStash]. Sie können einen Stash auch auf :ui[workspace.title] oder den aktuellen Branch in der Seitenleiste ziehen.
2. Wählen Sie den Stash in :ui[stash.picker]. In der Stash-Ansicht ist der ausgewählte Stash bereits gewählt.
3. Legen Sie die Optionen fest:
   - :ui[stash.deleteAfterApply] entfernt den Stash, sobald seine Änderungen zurück sind.
   - :ui[stash.restoreIndex] stagt wieder, was beim Sichern des Stashes gestagt war.
4. Klicken Sie auf :ui[stash.apply].

Spooky merkt sich beide Optionen für das nächste Mal.

Kollidieren die Änderungen mit dem, was jetzt in der Arbeitskopie liegt, meldet Spooky :ui[stash.error.conflicts]. Der Stash bleibt erhalten, auch wenn :ui[stash.deleteAfterApply] aktiviert ist. Lösen Sie die Konflikte, wie in [Konflikte lösen](/guide/work/conflicts/) beschrieben.

Um eine einzelne Datei zurückzuholen, öffnen Sie den Stash und ziehen Sie die Datei aus seinen Details auf :ui[workspace.title] in der Seitenleiste.

## Stashes löschen {#delete}

Klicken Sie in der Stash-Ansicht mit der rechten Maustaste auf einen Stash und wählen Sie :ui[stash.deleteNamed]{1="Halfway through the units toggle"} aus dem Menü. Sind mehrere Stashes ausgewählt, heißt der Eintrag stattdessen :ui[stash.deleteMultiple]{1="2"}. Sie können auch <kbd>⌘⌫</kbd> drücken.

Spooky fragt immer vorher nach. Um einen gelöschten Stash zurückzuholen, wählen Sie :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

## Automatisches Stashen {#auto-stash}

Manche Vorgänge lassen sich nicht ausführen, solange Sie lokale Änderungen haben, etwa das Wechseln des Branches, Pullen oder Zusammenführen. Ist einer davon blockiert, fragt Spooky, ob Ihre Änderungen zuerst gestasht werden sollen.

::screenshot[Ein Dialogfenster mit der Frage, ob die lokalen Änderungen, die den Vorgang blockieren, gestasht werden sollen. Es hat ein Feld für eine optionale Nachricht, ein Markierungsfeld zum erneuten Anwenden der Änderungen nach Abschluss des Vorgangs und die Tasten zum Abbrechen, zum Fortfahren ohne Stash und zum Stashen der Änderungen.]{name="work-auto-stash" frame="dialog"}

- :ui[stash.autoStash.confirm] stasht die Änderungen und führt den Vorgang aus.
- :ui[stash.autoStash.skip] führt den Vorgang ohne Stashen aus. Blockieren Ihre Änderungen ihn weiterhin, schlägt er fehl wie zuvor.
- :ui[stash.autoStash.abort] bricht den Vorgang ab.

Aktivieren Sie :ui[stash.autoStash.reapply], um die Änderungen zurückzubekommen, sobald der Vorgang abgeschlossen ist. Andernfalls bleibt der Stash in der Liste, und Sie können ihn später selbst anwenden. Spooky merkt sich diese Wahl.

Wechseln Sie den Branch mit Änderungen an versionierten Dateien, fragt Spooky vor dem Start nach, auch wenn die Änderungen nicht im Weg wären.

Geht unterwegs etwas schief, bleiben Ihre Änderungen im Stash, und Spooky sagt Ihnen, was passiert ist.

Um nicht mehr gefragt zu werden, deaktivieren Sie :ui[stash.offerAutoStash] unter :ui[app.name > settings.title] › :ui[settings.general]. Siehe [Vorgänge](/guide/settings/general/#operations).

## Siehe auch

- [Arbeitskopie](/guide/work/working-copy/)
- [Konflikte lösen](/guide/work/conflicts/)
- [Branches](/guide/branches/branches/)
