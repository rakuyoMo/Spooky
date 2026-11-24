---
title: "Server-Repository hinzufügen"
description: "Füllen Sie das Dialogfenster zum Hinzufügen eines Server-Repositorys aus, lesen Sie die Ergebnisse der Verbindungsprüfung und klonen oder suchen Sie Repositorys auf dem Server."
---

Wenn Sie ein Server-Repository hinzufügen, kommt es in Ihre Repository-Liste und wird geöffnet. Spooky prüft zuerst die Verbindung. Wenn etwas fehlt, sagt Ihnen das Dialogfenster, was zu beheben ist.

Stellen Sie vorher sicher, dass sich das Terminal ohne Rückfragen mit dem Server verbinden kann. Siehe [SSH vorbereiten](/guide/server/prepare-ssh/).

Um das Dialogfenster zu öffnen, wählen Sie :ui[action.addRemote] aus dem Menü :ui[menu.file] oder aus dem Menü der Hinzufügen-Taste im Fenster „Repositorys“.

## Das Dialogfenster ausfüllen {#dialog}

::screenshot[Das Dialogfenster zum Hinzufügen eines Server-Repositorys. Der Host-Alias ist spooky-test. Der Repository-Pfad ist /srv/git/driftwood, daneben steht eine Taste zum Durchsuchen. Für das Einbinden auf diesem Mac ist „nicht einbinden“ gewählt. Die Tasten dienen zum Abbrechen und zum Öffnen.]{name="add-server" frame="dialog"}

| Feld | Was Sie eingeben |
|---|---|
| :ui[remote.host] | Der `Host`-Name aus `~/.ssh/config`, etwa `driftwood-server`. Geben Sie nur den Alias ein, ohne Benutzernamen oder Port. Wie Sie einen anlegen, lesen Sie unter [Einen Host-Alias hinzufügen](/guide/server/prepare-ssh/#alias). |
| :ui[remote.path] | Der vollständige Pfad des Repositorys auf dem Server, beginnend mit `/`, etwa `/srv/git/driftwood` |
| :ui[remote.mount] | Optional. Macht den Ordner des Repositorys auf diesem Mac verfügbar, damit der Finder ihn zeigen kann. Siehe [Beim Hinzufügen einbinden](/guide/server/local-location/#when-adding). |

Wenn Sie den Pfad nicht kennen, klicken Sie auf :ui[clone.browse], sobald der Host-Alias eingetragen ist. Spooky führt die Ordner auf dem Server auf, beginnend beim eingegebenen Pfad oder bei Ihrem Benutzerordner dort. Git-Repositorys sind mit :ui[browse.repository] gekennzeichnet. Ordner, die Sie nicht lesen können, sind abgeblendet. Doppelklicken Sie auf einen Ordner, um hineinzugehen, und klicken Sie dann auf :ui[bookmarks.create.choosePrompt].

Sie können auch einen Ordner innerhalb eines Repositorys wählen. Spooky öffnet das Repository, zu dem er gehört.

:ui[action.open] ist verfügbar, sobald der Host-Alias eingetragen ist und der Pfad mit `/` beginnt.

## Die Verbindungsprüfung {#check}

Wenn Sie auf :ui[action.open] klicken, zeigt Spooky unten im Dialogfenster :ui[remote.checking] und prüft der Reihe nach:

1. SSH meldet sich mit dem Host-Alias an.
2. Git ist auf dem Server vorhanden, in Version 2.41.0 oder neuer.
3. Der Ordner existiert, und Sie können ihn öffnen und lesen.
4. Der Ordner liegt in einem Git-Repository, und Git kann dessen Status lesen.

Während der Prüfung sind die Felder gesperrt. Klicken Sie auf :ui[action.cancel], um sie zu stoppen und das Dialogfenster zu schließen.

Wenn alles besteht, richtet Spooky sein Hilfsskript auf dem Server ein, fügt das Repository der Repository-Liste hinzu und öffnet es.

## Wenn die Prüfung fehlschlägt {#results}

Das Dialogfenster bleibt geöffnet und behält Ihre Eingaben. Unten zeigt es, was zu beheben ist, gefolgt von der Originalausgabe von SSH oder Git. Beheben Sie das Problem und klicken Sie erneut auf :ui[action.open].

| Was schiefging | Was zu tun ist |
|---|---|
| Der Host-Alias ist ungültig | Geben Sie nur den Alias aus der `Host`-Zeile ein, ohne Leerzeichen, `@`, `:` oder `/`. |
| Der Fingerabdruck des Servers ist unbekannt | Verbinden Sie sich einmal im Terminal und prüfen Sie den Fingerabdruck. Siehe [Einmal verbinden](/guide/server/prepare-ssh/#fingerprint). Spooky akzeptiert nie einen Fingerabdruck für Sie. |
| Der Fingerabdruck des Servers hat sich geändert | Verbinden Sie sich noch nicht. Klären Sie die Änderung zuerst mit dem Betreiber des Servers. |
| SSH kann sich nicht anmelden | Der Server akzeptiert Ihren Schlüssel nicht, oder Ihr Mac kann ihn nicht entsperren. Siehe [Testen, wie Spooky sich verbindet](/guide/server/prepare-ssh/#test). |
| Der Server ist nicht erreichbar | Prüfen Sie den Host-Alias und Ihr Netzwerk und versuchen Sie es erneut. |
| Git wird nicht gefunden | Installieren Sie Git 2.41.0 oder neuer auf dem Server. Wenn es installiert ist, finden SSH-Anmeldungen es nicht. Die Ausgabe führt den `PATH` auf, den der Server verwendet. Tragen Sie den Ordner von Git in der Startdatei der Shell auf dem Server dort ein. |
| Git ist zu alt | Aktualisieren Sie Git auf dem Server auf 2.41.0 oder neuer. |
| Der Ordner existiert nicht | Prüfen Sie den Pfad. Um dort ein neues Repository anzulegen, klicken Sie auf :ui[bookmarks.noRepository.create]. |
| Keine Berechtigung für den Ordner | Ihr Benutzer auf dem Server braucht die Berechtigung, den Ordner zu öffnen und zu lesen. |
| macOS auf dem Server blockiert den Ordner | Der Server ist ein Mac, und das Repository liegt in einem geschützten Ordner wie „Dokumente“. Schalten Sie den Festplattenvollzugriff für entfernte Benutzer ein, wie unter [Einen Mac als Server verwenden](/guide/server/prepare-ssh/#mac-server) beschrieben, oder verschieben Sie das Repository. |
| Der Ordner ist kein Git-Repository | Wählen Sie den Ordner des Repositorys oder klicken Sie auf :ui[bookmarks.noRepository.create], um aus diesem Ordner eines zu machen. Wenn Gits Ausgabe den Eigentümer erwähnt, gehört der Ordner einem anderen Benutzer auf dem Server. |
| Git kann den Status nicht lesen | Gits Ausgabe darunter erklärt, warum. |
| Die Serversitzung lässt sich nicht einrichten | Das SSH des Servers muss die Weiterleitung von Unix-Sockets erlauben. Der Server braucht außerdem `/usr/bin/perl`, und Sie brauchen dort Schreibzugriff auf `~/.spooky/bin` und `/tmp`. Siehe [Systemanforderungen](/reference/requirements/#servers). |

::screenshot[Das Dialogfenster zum Hinzufügen eines Server-Repositorys mit dem Host-Alias spooky-test und dem Pfad /srv/git/driftwood. Unter den Feldern bittet eine Warnung darum zu prüfen, ob der absolute Pfad auf dem gewählten Server existiert, gefolgt von der Originalausgabe „Directory does not exist“. Die Tasten dienen zum Abbrechen, zum Erstellen eines Repositorys und zum Öffnen.]{name="server-add-error" frame="dialog"}

:ui[bookmarks.noRepository.create] führt `git init` in diesem Ordner aus und erstellt den Ordner vorher, falls er fehlt. Spooky prüft die Verbindung dann erneut und öffnet das neue Repository.

Um den `PATH` und das Git eines Servers zu sehen, ohne ein Repository hinzuzufügen, öffnen Sie :ui[app.name > settings.title] › :ui[settings.environment]. Geben Sie unten den Host-Alias ein und klicken Sie auf :ui[settings.environment.server.check]. Siehe [Einen Server prüfen](/guide/settings/general/#server-check).

## Git-Umgebungsvariablen auf dem Server {#environment}

Nach der Prüfung zeigt Spooky möglicherweise :ui[remote.environment.title]. Die nicht interaktive Shell des Servers setzt Variablen, deren Namen mit `GIT_` beginnen. Sie ändern bei jedem Befehl, den Spooky dort ausführt, wie Git Repositorys findet und seine Einstellungen liest.

Klicken Sie auf :ui[action.close], und das Repository wird geöffnet. Wenn sich Git darin unerwartet verhält, entfernen Sie diese Variablen aus den Startdateien der Shell auf dem Server.

## Auf einem Server klonen und suchen {#clone-scan}

Es gibt zwei weitere Wege, ein Server-Repository in die Liste zu bekommen:

- **Klonen:** Wählen Sie im Dialogfenster zum Klonen unter :ui[clone.to] einen Server. Git klont das Repository auf dem Server, und Spooky fügt es als Server-Repository hinzu. Siehe [Ein Repository klonen](/guide/repositories/manager/#clone).
- **Suchen:** Wählen Sie :ui[scan.menu] aus dem Menü der Hinzufügen-Taste und dann unter :ui[scan.in] einen Server. Spooky durchsucht den Ordner auf dem Server und führt die gefundenen Repositorys auf. Siehe [Nach Repositorys suchen](/guide/repositories/manager/#scan).

## Siehe auch

- [SSH vorbereiten](/guide/server/prepare-ssh/)
- [Verbindungsstatus und erneutes Verbinden](/guide/server/connection/)
- [Ort auf diesem Mac](/guide/server/local-location/)
