---
title: "Tags und Remotes"
description: "Tags erstellen, veröffentlichen und löschen sowie Remotes hinzufügen, bearbeiten, umbenennen und entfernen."
---

Tags stehen in der Seitenleiste unter :ui[sidebar.tags], Remotes unter :ui[remote.group]. Beide haben eigene Menüs: Klicken Sie mit der rechten Maustaste auf einen Eintrag, um zu sehen, was Sie damit tun können.

## Tags {#tags}

Ein Tag gibt einem Commit einen festen Namen, meist für ein Release wie `v0.4.0`. Anders als ein Branch bewegt es sich nicht, wenn Sie committen.

Bewegen Sie den Zeiger auf ein Tag, um den Commit zu sehen, auf den es zeigt, und seine Nachricht, falls es eine hat. Doppelklicken Sie auf ein Tag, um seinen Commit auszuchecken. Siehe [Ein Tag oder einen Commit auschecken](/guide/branches/branches/#checkout-revision).

Wie Branches kommen Tags, deren Namen ein `/` enthalten, in Ordner. Wie Sie nur die neuesten zeigen oder die Sortierung umkehren, lesen Sie unter [Filtern und gruppieren](/guide/branches/branches/#filter).

### Ein Tag erstellen {#create-tag}

1. Wählen Sie :ui[menu.repository > tag.createMenu] (<kbd>⇧⌘T</kbd>). Sie können auch unten in der Seitenleiste auf die Hinzufügen-Taste klicken und den Befehl im Menü wählen. Um einen bestimmten Branch oder Commit zu taggen, klicken Sie stattdessen mit der rechten Maustaste darauf und wählen Sie :ui[tag.createFrom]{1="main"} aus dem Menü.
2. Geben Sie den Namen in :ui[reference.name] ein.
3. :ui[tag.revision] ist der Commit, der getaggt wird. Anfangs ist das der Branch, auf dem Sie sich befinden, oder das, worauf Sie mit der rechten Maustaste geklickt haben.
4. Füllen Sie bei Bedarf :ui[tag.messageField] aus. Ohne Nachricht ist das Tag nur ein Name für den Commit. Mit Nachricht sichert Git auch, wer das Tag wann erstellt hat.
5. Um das Tag zu signieren, aktivieren Sie :ui[tag.sign] und wählen Sie in :ui[tag.signingKey] einen Schlüssel. :ui[tag.signingKey.configured] verwendet den in Git eingerichteten Schlüssel. Ein signiertes Tag braucht eine Nachricht. Spooky merkt sich, ob Sie signieren.
6. Klicken Sie auf :ui[tag.create.submit].

Sie können auch einen Commit oder einen lokalen Branch auf :ui[sidebar.tags] oder einen Tag-Ordner ziehen.

Ein neues Tag existiert nur in diesem Repository, bis Sie es veröffentlichen. Um es wieder zu entfernen, wählen Sie :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

### Ein Tag veröffentlichen {#publish-tag}

1. Klicken Sie mit der rechten Maustaste auf das Tag und wählen Sie :ui[tag.publishMenu]{1="v0.4.0"} aus dem Menü, oder wählen Sie :ui[menu.repository > tag.publishMainMenu] in der Menüleiste. Sie können das Tag auch auf ein Remote ziehen.
2. Prüfen Sie :ui[tag.local] und :ui[sync.remote]. Das Remote ist dasjenige, das Ihr aktueller Branch verfolgt, sofern Sie das Tag nicht auf ein anderes gezogen haben.
3. Aktivieren Sie :ui[sync.skipHooks], um zu pushen, ohne die Git-Hooks des Repositorys auszuführen.
4. Klicken Sie auf :ui[tag.publish].

Das Veröffentlichen eines Tags lässt sich widerrufen. Beim Widerrufen wird es auf dem Remote wieder gelöscht.

Um alle Tags auf einmal zu einem Remote zu pushen, klicken Sie mit der rechten Maustaste auf das Remote und wählen Sie :ui[tag.pushAll]{1="origin"} aus dem Menü. Auch das Dialogfenster zum Pushen kann alle Tags mitsenden. Siehe [Pushen](/guide/branches/sync/#push).

### Ein Tag löschen {#delete-tag}

Klicken Sie mit der rechten Maustaste auf das Tag und wählen Sie :ui[reference.deleteMenu]{1="v0.1.0"} aus dem Menü. Sie können auch ein oder mehrere Tags auswählen und <kbd>⌘⌫</kbd> drücken, während die Seitenleiste den Fokus hat.

Spooky fragt immer zuerst nach. Um das Tag auch auf einem Remote zu löschen, aktivieren Sie :ui[tag.deleteRemote] und wählen Sie das Remote in :ui[sync.remote].

Wenn Sie ein Tag nur in diesem Repository löschen, lässt sich das widerrufen. Auf einem Remote nicht.

## Remotes {#remotes}

Ein Remote ist eine weitere Kopie des Repositorys, von der Sie abrufen und zu der Sie pushen, oft bei einem Hosting-Dienst. Das Remote, von dem Sie geklont haben, heißt meist `origin`.

Unter :ui[remote.group] führt jedes Remote seine Branches auf. Bewegen Sie den Zeiger auf ein Remote, um seine URLs zum Abrufen und Pushen zu sehen.

Ein Rechtsklick auf ein Remote öffnet sein Menü:

- :ui[remote.fetchMenu]{1="origin"} und :ui[sync.prune] öffnen das Dialogfenster zum Abrufen für dieses Remote. Siehe [Abrufen](/guide/branches/sync/#fetch).
- :ui[remote.viewInBrowser]{1="origin"} öffnet die Webseite des Remotes. Das funktioniert bei HTTP(S)-, SSH- und `git://`-URLs, aber nicht bei lokalen Pfaden.
- Mit den übrigen Einträgen fügen Sie Remotes hinzu, bearbeiten, benennen sie um und löschen sie, wie unten beschrieben.

:::note[Server-Repositorys]
Remotes werden vom Server aus erreicht, mit dem Netzwerk und den SSH-Schlüsseln des Servers. Eine URL, die auf Ihrem Mac funktioniert, funktioniert vom Server aus möglicherweise nicht.
:::

### Ein Remote hinzufügen {#add-remote}

1. Wählen Sie :ui[menu.repository > remote.addMainMenu] in der Menüleiste. Sie können auch unten in der Seitenleiste auf die Hinzufügen-Taste klicken oder mit der rechten Maustaste auf :ui[remote.group] klicken und :ui[remote.addMenu] aus dem Menü wählen.
2. Geben Sie in :ui[reference.name] einen kurzen Namen ein, etwa `upstream`.
3. Setzen Sie die Adresse in :ui[remote.url] ein.
4. Klicken Sie auf :ui[remote.add.submit].

Spooky prüft die Verbindung, bevor es das Remote hinzufügt. Wenn keine Verbindung zustande kommt, bleibt das Dialogfenster geöffnet. Sie können einen Tippfehler korrigieren und es erneut versuchen. Sobald das Remote hinzugefügt ist, ruft Spooky es sofort ab.

### Remote-Einstellungen {#remote-settings}

Klicken Sie in der Seitenleiste auf ein Remote, um seine Einstellungen zu öffnen. Der Umschalter oben hat zwei Seiten:

- :ui[remote.page.general] zeigt, wie Git mit dem Remote kommuniziert.
- :ui[remote.page.branches] listet die Branches des Remotes auf, jeweils mit dem Commit, auf den sie zeigen.

Bewegen Sie den Zeiger auf eine Zeile in :ui[remote.page.general], um ihre Tasten einzublenden.

| Einstellung | Was sie bewirkt |
|---|---|
| :ui[remote.field.fetchURL] | Von wo Spooky abruft. Auch ein Rechtsklick auf das Remote und :ui[remote.editConnection] bearbeitet sie. |
| :ui[remote.skipFetchAll] | Nimmt dieses Remote vom automatischen Abrufen und von :ui[sync.fetchAll] aus. |
| :ui[remote.field.fetchRefspecs] | Welche Branches abgerufen und wo sie abgelegt werden. |
| :ui[remote.field.pushURL] | Wohin Spooky pusht. Solange Sie keine festlegen, verwendet das Pushen die Abruf-URL, die grau angezeigt wird. :ui[remote.action.unset] kehrt dazu zurück. |
| :ui[remote.field.pushRefspecs] | Welche Branches gepusht werden und wohin. |

Eine Refspec ist eine Regel, die Branch-Namen auf der einen Seite Namen auf der anderen zuordnet. Die meisten Remotes brauchen nur die, die Git einrichtet. Um eine hinzuzufügen, klicken Sie neben :ui[remote.group.fetch] oder :ui[remote.group.push] auf :ui[remote.action.addRefspec].

Spooky prüft eine neue URL, bevor es sie sichert. Änderungen an den Remote-Einstellungen lassen sich widerrufen.

### Ein Remote umbenennen oder entfernen {#rename-remote}

Klicken Sie mit der rechten Maustaste auf das Remote und wählen Sie :ui[reference.renameMenu]{1="origin"} oder :ui[reference.deleteMenu]{1="origin"} aus dem Menü.

Beim Entfernen verschwinden das Remote und seine Remote-Branches aus diesem Repository. Das Repository, auf das es zeigt, ändert sich nicht. Umbenennen und Entfernen lassen sich beide widerrufen.

## Siehe auch

- [Branches](/guide/branches/branches/)
- [Abrufen, Pullen und Pushen](/guide/branches/sync/)
- [Widerrufen und Wiederherstellen](/guide/work/undo/)
