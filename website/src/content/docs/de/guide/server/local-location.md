---
title: "Ort auf diesem Mac"
description: "Geben Sie einem Server-Repository einen Ort auf diesem Mac – durch automatische Suche, eine SMB- oder sshfs-Einbindung oder einen gewählten Ordner –, damit „Im Finder zeigen“, das Terminal und externe Editoren es öffnen können."
---

Der Finder kann nur Ordner auf Ihrem Mac zeigen. Die Dateien eines Server-Repositorys liegen auf dem Server. Um sie im Finder zu zeigen, braucht Spooky einen Ordner auf diesem Mac, in dem die Dateien des Servers erscheinen, meist ein eingebundenes Netzwerkvolume. Dieser Ordner ist der Ort des Repositorys auf diesem Mac.

Diese Seite behandelt, wie Spooky diesen Ordner findet oder einbindet und wie das Terminal und andere Apps ein Server-Repository öffnen.

## Im Finder zeigen {#show-in-finder}

:ui[action.revealFinder] ist in einem Server-Repository immer verfügbar. Sie finden es an diesen Stellen:

- Im Menü :ui[menu.file]
- Als :ui[toolbar.finder] in der Symbolleiste
- In der Zeile :ui[workspace.title] in der Seitenleiste, wenn Sie mit der rechten Maustaste darauf klicken
- In den [Schnellaktionen](/guide/repositories/navigation/#quick-actions)
- Im Fenster „Repositorys“, wenn Sie mit der rechten Maustaste auf ein Server-Repository klicken
- Bei Dateien in der Arbeitskopie, wenn Sie mit der rechten Maustaste darauf klicken. Der Finder wählt diese Dateien aus.

Wenn der Ort bekannt und der Ordner vorhanden ist, öffnet sich der Finder sofort. Andernfalls zeigt Spooky ein Dialogfenster und geht diese Schritte durch:

1. Wenn das Repository nicht verbunden ist, verbindet sich Spooky zuerst.
2. Es sucht den Ordner und bindet ihn ein, wenn die Methode SMB oder sshfs ist.
3. Wenn es den Ordner dann immer noch nicht findet, wird das Dialogfenster zum Formular für das Festlegen des Orts, mit dem Grund ganz oben. Siehe [Den Ort festlegen](#set).

Klicken Sie auf :ui[action.cancel], um das Dialogfenster zu schließen. Ihre Einstellungen bleiben unverändert.

## Den Ort festlegen {#set}

1. Klicken Sie in der Seitenleiste unter :ui[workspace.group] auf :ui[repositorySettings.title].
2. Suchen Sie auf der Seite :ui[repositorySettings.general] den Eintrag :ui[repositorySettings.localLocation]. Er zeigt die Methode und den Ordner oder den Grund, warum es keinen Ordner gibt, etwa :ui[localLocation.notMounted].
3. Bewegen Sie den Zeiger über die Zeile und klicken Sie auf :ui[localLocation.change], wenn es erscheint. Das Repository muss verbunden sein.
4. Wählen Sie unter :ui[localLocation.title] neben :ui[localLocation.method] eine Methode.
5. Klicken Sie bei einer Einbindung auf :ui[localLocation.mount] und bei den anderen Methoden auf :ui[localLocation.save].

Während Spooky den Ordner einbindet oder prüft, ist das Formular gesperrt. Klicken Sie auf :ui[action.cancel], um abzubrechen. Ihre frühere Einstellung bleibt.

Der Ort wird auf diesem Mac für jedes Server-Repository gesichert. Spooky schreibt ihn weder ins Repository noch auf den Server.

Wenn eine SMB- oder sshfs-Einbindung ausgeworfen wurde, zeigt die Zeile :ui[localLocation.mountAgain]. Klicken Sie darauf, um den Ordner erneut einzubinden.

## Methoden {#methods}

Das Menü :ui[localLocation.method] führt nur die Methoden auf, die gerade funktionieren. Die aktuelle Methode ist immer aufgeführt.

### Automatisch {#automatic}

:ui[localLocation.method.automatic] ist der Standard. Spooky durchsucht die Netzwerkvolumes, die bereits auf diesem Mac eingebunden sind, etwa SMB-, NFS-, AFP-, WebDAV- und sshfs-Volumes. Welche App sie eingebunden hat, spielt keine Rolle. Ein Volume zählt, wenn sein Server dieselbe Adresse hat wie Ihr Host-Alias.

Spooky sucht dann im Volume nach dem Repository-Ordner. Um sicherzugehen, dass es dasselbe Repository ist, legt Spooky kurz eine leere Datei im Git-Ordner des Repositorys auf dem Server ab, prüft, ob sie auf dem Volume erscheint, und löscht sie wieder.

### SMB-Einbindung {#smb}

:ui[localLocation.method.smbMount] bindet einen freigegebenen Ordner des Servers per SMB ein, dem Dateifreigabeprotokoll, das macOS verwendet. Die Methode ist aufgeführt, wenn der Server innerhalb von 2 Sekunden auf dem SMB-Port antwortet.

1. Wählen Sie :ui[localLocation.method.smbMount] und klicken Sie auf :ui[localLocation.mount].
2. macOS zeigt die freigegebenen Ordner des Servers oder bittet Sie zuerst, sich anzumelden. Wählen Sie die Freigabe, die das Repository enthält.

Spooky merkt sich die Freigabe und bindet sie beim nächsten Mal ohne Rückfrage wieder ein. Wenn das Repository nicht in der gewählten Freigabe liegt, zeigt das Formular :ui[localLocation.notInShare] Wählen Sie eine andere Freigabe und versuchen Sie es erneut.

Wenn der Server ein Mac ist, schalten Sie auf diesem Mac unter **Apple-Menü › Systemeinstellungen › Allgemein › Teilen** die **Dateifreigabe** ein.

### sshfs-Einbindung {#sshfs}

:ui[localLocation.method.sshfsMount] bindet den Repository-Ordner per SSH ein, mit demselben Host-Alias, den Spooky verwendet. Die Methode braucht sshfs und macFUSE oder FUSE-T auf diesem Mac. Spooky sucht `sshfs` in `/opt/homebrew/bin`, `/usr/local/bin` und Ihrem `PATH`. Wenn es nicht installiert ist, wird diese Methode nicht aufgeführt.

1. Wählen Sie :ui[localLocation.method.sshfsMount].
2. Klicken Sie neben :ui[localLocation.mountAt] auf :ui[localLocation.choose] und wählen Sie einen leeren Ordner auf diesem Mac. Die Dateien des Servers erscheinen dort.
3. Klicken Sie auf :ui[localLocation.mount].

### Gewählter Ordner {#chosen-folder}

Mit :ui[localLocation.method.chosenFolder] wählen Sie den Ordner selbst, zum Beispiel einen, den Sie auf anderem Weg eingebunden haben.

1. Wählen Sie :ui[localLocation.method.chosenFolder].
2. Klicken Sie neben :ui[localLocation.folder] auf :ui[localLocation.choose] und wählen Sie den Repository-Ordner.
3. Klicken Sie auf :ui[localLocation.save]. Spooky prüft den Ordner, bevor es sichert.

Spooky wirft niemals ein Volume aus, das es eingebunden hat. Wenn Sie das Repository später wieder öffnen, bindet Spooky es im Hintergrund erneut ein, ohne etwas zu fragen.

## Beim Hinzufügen einbinden {#when-adding}

Wenn Sie [ein Server-Repository hinzufügen](/guide/server/add/), richtet :ui[remote.mount] den Ort im selben Schritt ein. Vorgegeben ist :ui[remote.mount.none]. Sobald Sie den Host-Alias eintragen, führt das Menü :ui[remote.mount.smb] und :ui[remote.mount.sshfs] auf, wenn sie verfügbar sind. Ist keines von beiden verfügbar, zeigt es :ui[remote.mount.unavailable].

- **SMB:** Nachdem sich das Repository geöffnet hat, zeigt macOS die freigegebenen Ordner des Servers oder ein Anmeldefenster. Wenn Sie abbrechen, öffnet sich das Repository trotzdem, und :ui[repositorySettings.localLocation] in seinen Einstellungen zeigt, warum es nicht eingebunden ist.
- **sshfs:** Eine zusätzliche Zeile :ui[localLocation.mountAt] erscheint. Wählen Sie einen leeren Ordner. Spooky bindet das Repository dort ein, nachdem es sich geöffnet hat.

Wenn Sie den Host-Alias ändern, springt das Menü zurück auf :ui[remote.mount.none].

## Terminal und andere Apps {#terminal}

Diese Befehle funktionieren in einem Server-Repository auch ohne Ort auf diesem Mac:

- **:ui[action.openTerminal]** öffnet die Terminal-App, die unter :ui[app.name > settings.title] › :ui[settings.general] gewählt ist, meldet sich mit `ssh -t` und dem Host-Alias an und wechselt in den Repository-Ordner. Wenn der Server kein Terminal erlaubt, verbindet sich Spooky erneut ohne eines. Befehle funktionieren weiterhin, Zeilenbearbeitung und bildschirmfüllende Programme aber nicht. Sie finden den Befehl im Menü :ui[menu.file], als :ui[toolbar.terminal] in der Symbolleiste und wenn Sie mit der rechten Maustaste auf die Arbeitskopie oder im Fenster „Repositorys“ auf ein Repository klicken. Wie Sie die Terminal-App wählen, lesen Sie unter [Terminal](/guide/settings/integration/#terminal).
- **:ui[action.copyPath]** kopiert den Pfad mit vorangestelltem Host-Alias, etwa `driftwood-server:/srv/git/driftwood`.
- **:ui[files.open] und :ui[files.openWith]** in der Arbeitskopie öffnen eine Datei in einer anderen App. Visual Studio Code, Visual Studio Code Insiders und Cursor öffnen die Datei direkt auf dem Server, wenn eine Remote-SSH-Erweiterung installiert ist. Andere Apps erhalten eine Kopie auf diesem Mac. Wenn Sie sichern, schreibt Spooky die Kopie auf den Server zurück.

Wenn sich die Datei auf dem Server inzwischen geändert hat, fragt Spooky vor dem Schreiben: :ui[externalTool.fileChanged]. Klicken Sie auf :ui[externalTool.overwrite], um sie durch Ihre Kopie zu ersetzen. Spooky löscht die Kopien, wenn Sie das Repository schließen.

Auch die Übersicht sowie externe Vergleichs- und Zusammenführungswerkzeuge arbeiten mit Kopien. Nachdem ein Zusammenführungswerkzeug fertig ist, schreibt Spooky das Ergebnis auf den Server zurück und stagt es.

## Siehe auch

- [So funktionieren Server-Repositorys](/guide/server/overview/)
- [Server-Repository hinzufügen](/guide/server/add/)
- [Integration](/guide/settings/integration/)
