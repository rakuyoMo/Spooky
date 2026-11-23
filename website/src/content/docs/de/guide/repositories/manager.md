---
title: "Das Fenster „Repositorys“"
description: "Repositorys als Lesezeichen sichern, gruppieren, öffnen, klonen, erstellen, suchen und entfernen – und die finden, die verloren gegangen sind."
---

Das Fenster „Repositorys“ führt eine Liste der Repositorys, mit denen Sie arbeiten, auf Ihrem Mac und auf Servern. Jeder Eintrag ist ein Lesezeichen, das auf ein Repository zeigt. Wenn Sie ein Lesezeichen entfernen, bleibt der Ordner des Repositorys, wo er ist. Den Ordner in den Papierkorb zu legen, ist eine eigene Entscheidung. Diese Seite behandelt das Hinzufügen, Ordnen, Öffnen und Entfernen von Repositorys.

Um aus einem Repository zur Liste zu gelangen, klicken Sie in der Symbolleiste auf :ui[toolbar.bookmarks] oder wählen Sie :ui[menu.view > menu.showRepositories] (<kbd>⌃⌘R</kbd>).

::screenshot[Das Fenster „Repositorys“. Die Seitenleiste führt zwei Gruppen auf, Driftwood Labs und Notes, mit Repositorys darin; eines davon ist ein Server-Repository, dessen Name mit seinem Host-Alias beginnt. Rechts stehen die Details des ausgewählten Repositorys driftwood: sein Ort, wann es zuletzt geöffnet wurde, sein letzter Commit, eine Beschreibung, die Committer-Identität, der aktuelle Branch, die Anzahl geänderter Dateien und das Remote.]{name="repositories" frame="window"}

## Repositorys hinzufügen {#add}

Die Hinzufügen-Taste unten in der Seitenleiste hat ein Menü, mit dem Sie die Liste erweitern:

| Menüeintrag | Wirkung |
|---|---|
| :ui[bookmarks.newGroup] | Fügt unter der Auswahl eine Gruppe hinzu, deren Namen Sie gleich eingeben können |
| :ui[bookmarks.add] | Fügt Repositorys hinzu, die schon auf Ihrem Mac liegen. Sie können mehrere Ordner auf einmal auswählen. |
| :ui[action.addRemote] | Fügt ein Repository auf einem Server hinzu. Siehe [Server-Repository hinzufügen](/guide/server/add/). |
| :ui[bookmarks.create] | Erstellt ein leeres Repository. Siehe [Ein Repository erstellen](#create). |
| :ui[clone.menu] | Kopiert ein Repository von einem Remote. Siehe [Ein Repository klonen](#clone). |
| :ui[scan.menu] | Findet die Repositorys in einem Ordner. Siehe [Nach Repositorys suchen](#scan). |

Neue Einträge kommen in die ausgewählte Gruppe. Sie können Repository-Ordner auch aus dem Finder in die Liste ziehen. Wenn Sie ein Repository mit :ui[menu.file > action.openLocal] öffnen und es noch nicht in der Liste steht, wird es am Ende hinzugefügt.

### Ein Repository erstellen {#create}

1. Wählen Sie :ui[bookmarks.create] aus dem Menü der Hinzufügen-Taste.
2. Geben Sie unter :ui[bookmarks.create.name] den Namen des neuen Repositorys ein. Er ist zugleich der Name seines Ordners.
3. Klicken Sie neben :ui[bookmarks.create.location] auf :ui[bookmarks.create.choose], um den Ordner zu wählen, in dem es erstellt wird. Vorgegeben ist Ihr Benutzerordner.
4. Klicken Sie auf :ui[bookmarks.create.submit].

Spooky erstellt den Ordner, macht daraus ein leeres Git-Repository, fügt es der ausgewählten Gruppe hinzu und öffnet es.

### Ein Repository klonen {#clone}

Beim Klonen wird ein Repository samt Verlauf von einem Remote in einen neuen Ordner kopiert.

1. Wählen Sie aus dem Menü der Hinzufügen-Taste :ui[clone.menu] oder drücken Sie <kbd>⌃⌘C</kbd>.
2. Geben Sie unter :ui[clone.url] die Adresse des Repositorys ein, zum Beispiel eine, die mit `https://` oder `git@` beginnt.
3. Wählen Sie unter :ui[clone.to] entweder :ui[clone.machine.local] oder einen Server. Server, die Sie bereits verwenden, stehen in der Liste. Für einen anderen wählen Sie :ui[clone.machine.other] und geben dessen :ui[remote.host] ein.
4. Wählen Sie unter :ui[clone.directory] den Ordner, in den geklont wird. Spooky erstellt darin einen Ordner mit dem Namen des Repositorys.
5. Lassen Sie :ui[clone.submodules] aktiviert, um auch die Submodule des Repositorys auszuchecken. Aktivieren Sie :ui[clone.lfs], wenn das Repository große Dateien in Git LFS hält.
6. Klicken Sie auf :ui[clone.submit].

Spooky prüft zuerst, ob es das Remote erreichen kann. Wenn nicht, bleibt das Dialogfenster geöffnet und zeigt den Grund. Korrigieren Sie die Adresse und versuchen Sie es erneut. Wenn ja, schließt sich das Dialogfenster, und der Klon läuft im Hintergrund. Der Fortschritt steht in der Zeile des Repositorys in der Liste. Wenn der Klon fertig ist, sendet Spooky die Mitteilung :ui[clone.notification.title].

Auf Ihrem Mac ist Ihr Benutzerordner vorgegeben oder der Ordner, der unter :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.cloneDirectory] festgelegt ist. Siehe [Klonen und Terminal](/guide/settings/general/#cloning).

Solange es kürzlich geklonte Repositorys gibt, erscheint :ui[toolbar.clone] in der Symbolleiste. Klicken Sie darauf, um :ui[clone.recent.title] zu sehen. Dort können Sie einen laufenden Klon stoppen, einen fehlgeschlagenen oder abgebrochenen mit :ui[clone.retry] neu starten oder mit :ui[clone.remove] aus der Liste nehmen. Doppelklicken Sie auf einen fertigen Klon, um ihn zu öffnen. :ui[clone.recent.clear] leert die Liste.

:::note[Server-Repositorys]
Wenn Sie auf einen Server klonen, prüft Spooky die Verbindung und führt den Klon dort aus. Das neue Repository wird als Server-Repository hinzugefügt. Geben Sie für den Ordner einen absoluten Pfad auf dem Server ein oder klicken Sie auf :ui[clone.browse], um einen auszusuchen. Spooky merkt sich für jeden Server den zuletzt verwendeten Ordner.
:::

Sie können auch die Adresse eines Repositorys in die Liste ziehen, um einen Klon zu starten. Auch ein Link kann einen starten. Siehe [Fenster und Navigation](/guide/repositories/navigation/).

### Nach Repositorys suchen {#scan}

1. Wählen Sie :ui[scan.menu] aus dem Menü der Hinzufügen-Taste.
2. Wählen Sie unter :ui[scan.in] entweder :ui[clone.machine.local] oder einen Server und dann den Ordner, der durchsucht wird.
3. Klicken Sie auf :ui[scan.start]. Repositorys erscheinen, sobald Spooky sie findet. Zum Anhalten klicken Sie auf :ui[scan.stop].
4. Jedes gefundene Repository ist ausgewählt. Deaktivieren Sie die, die Sie nicht möchten, und klicken Sie auf :ui[scan.add].

Repositorys, die schon in der Liste stehen, werden nicht noch einmal gezeigt. Sie können mehrere Ordner oder Server nacheinander durchsuchen. Die Ergebnisse summieren sich.

## Die Liste ordnen {#organize}

- Um eine Gruppe hinzuzufügen, wählen Sie :ui[bookmarks.newGroup] aus dem Menü der Hinzufügen-Taste und geben Sie einen Namen ein.
- Um Einträge umzusortieren oder in eine andere Gruppe zu verschieben, ziehen Sie sie.
- Um einen Eintrag umzubenennen, wählen Sie ihn aus und drücken Sie <kbd>↩</kbd>, oder klicken Sie mit der rechten Maustaste darauf und wählen Sie :ui[bookmarks.rename]. Wenn Sie ein Repository in der Liste umbenennen, wird sein Ordner nicht umbenannt.
- Um nach Namen zu sortieren, klicken Sie mit der rechten Maustaste und wählen Sie :ui[bookmarks.sortChildren], um die Einträge einer Gruppe zu sortieren, oder :ui[bookmarks.sortParent], um die Gruppe zu sortieren, in der ein Eintrag liegt.

Zwei Optionen unter :ui[app.name > settings.title] › :ui[settings.general] ändern, was die Liste zeigt:

- :ui[settings.showWorktreesInRepositoryList]: Ein Repository mit weiteren Worktrees lässt sich aufklappen, um sie aufzuführen. Einen Worktree öffnen Sie genauso wie ein Repository. Standardmäßig ausgeschaltet.
- :ui[settings.showHostAliasesInRepositoryList]: Die Namen von Server-Repositorys beginnen mit ihrem Host-Alias. Standardmäßig eingeschaltet.

Siehe [Fenster und die Repository-Liste](/guide/settings/general/#windows).

## Ein Repository öffnen {#open}

Doppelklicken Sie auf ein Repository. Es öffnet sich im selben Fenster anstelle der Liste. Wenn das Repository bereits in einem anderen Fenster geöffnet ist, holt Spooky stattdessen dieses Fenster nach vorne.

Klicken Sie mit der rechten Maustaste auf ein Repository, um mehr Möglichkeiten zu erhalten:

- :ui[bookmarks.open]{1="driftwood"} und :ui[bookmarks.openNewWindow]{1="driftwood"}
- :ui[action.revealFinder], :ui[action.copyPath] und :ui[action.openTerminal]

Die Details rechts enthalten außerdem die Tasten :ui[action.open] und :ui[bookmarks.multiple.delete]. Klicken Sie dort auf :ui[bookmarks.detail.edit], um :ui[bookmarks.detail.description] und :ui[bookmarks.detail.identity] zu ändern. :ui[bookmarks.detail.unset] entfernt die Identität, die nur für dieses Repository festgelegt ist. Neben jedem Remote öffnet :ui[bookmarks.detail.viewInBrowser] dessen Webseite. Beschreibung und Identität sind dieselben, die Sie in den [Repository-Einstellungen](/guide/settings/identity/#repository) sehen.

:::note[Server-Repositorys]
:ui[action.copyPath] kopiert den Pfad mit vorangestelltem Host-Alias, wie in `alias:/path/to/repository`. Spooky liest die Details eines Server-Repositorys erst, wenn Sie es auswählen. Beim Auswählen wird möglicherweise eine Verbindung zum Server hergestellt.
:::

## Fehlende Repositorys {#missing}

Wenn der Ordner eines Repositorys verschoben, umbenannt oder gelöscht wird, erscheint sein Name in der Liste grau mit einem Warnzeichen. In seinen Details steht :ui[bookmarks.detail.missing] Spooky prüft die Repositorys auf Ihrem Mac jedes Mal, wenn die Liste erscheint.

Wenn Sie ein fehlendes Repository öffnen, zeigt das Fenster :ui[missing.title]. Klicken Sie auf :ui[action.refresh], um erneut zu prüfen, etwa nachdem Sie ein Laufwerk wieder angeschlossen haben. Klicken Sie auf :ui[action.close], um zur Liste zurückzukehren.

Um den Eintrag zu reparieren, entfernen Sie ihn und fügen Sie das Repository von seinem jetzigen Ort neu hinzu.

:::note[Server-Repositorys]
Spooky prüft ein Server-Repository nur, wenn Sie es auswählen oder öffnen. Wenn Spooky den Server nicht erreichen kann, zeigt das Fenster :ui[missing.unreachable.title]{1="alias"} und was SSH gemeldet hat. Siehe [Verbindungsstatus und erneutes Verbinden](/guide/server/connection/).
:::

## Repositorys entfernen {#delete}

Wählen Sie einen oder mehrere Einträge aus und führen Sie einen der folgenden Schritte aus:

- Drücken Sie <kbd>⌫</kbd>.
- Klicken Sie mit der rechten Maustaste und wählen Sie :ui[bookmarks.delete]{1="driftwood"}, bei einer Gruppe :ui[bookmarks.deleteFolder] oder bei mehreren Einträgen :ui[bookmarks.deleteMultiple]{1="2"}.
- Klicken Sie in den Details auf :ui[bookmarks.multiple.delete].

Wenn der Ordner des Repositorys noch existiert, fragt Spooky zuerst :ui[bookmarks.delete.title]{1="driftwood"}. Nur die Lesezeichen werden entfernt. Die Ordner bleiben, wo sie sind. Um sie auch in den Papierkorb zu legen, aktivieren Sie :ui[bookmarks.delete.trash]. Klicken Sie zum Bestätigen auf :ui[bookmarks.delete.submit].

Leere Gruppen und Einträge, deren Ordner nicht mehr vorhanden sind, werden sofort und ohne Nachfrage entfernt.

:::caution
Beim Legen in den Papierkorb wird der ganze Repository-Ordner mitgenommen, einschließlich der Änderungen, die Sie nicht committet haben. Sie können ihn zurückholen, bis Sie den Papierkorb entleeren. Das Markierungsfeld für den Papierkorb ist bei jedem Öffnen des Dialogfensters deaktiviert.
:::

Wenn ein Ordner nicht in den Papierkorb gelegt werden kann, zeigt Spooky :ui[bookmarks.trashFailed.title] und führt die Ordner auf, die geblieben sind. Spooky legt niemals Ihren Benutzerordner, einen Ordner, der ihn enthält, oder die oberste Ebene eines Laufwerks in den Papierkorb.

:::note[Server-Repositorys]
Spooky fragt immer nach, bevor es ein Server-Repository entfernt. Sein Ordner kommt in den Papierkorb auf diesem Server, nicht auf Ihrem Mac. Wenn der Ordner auf dem Server nicht mehr vorhanden ist, ist das Markierungsfeld für den Papierkorb grau dargestellt und nur das Lesezeichen wird entfernt.
:::

## Siehe auch

- [Fenster und Navigation](/guide/repositories/navigation/)
- [Server-Repository hinzufügen](/guide/server/add/)
- [Worktrees](/guide/advanced/worktrees/)
