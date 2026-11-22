---
title: "Systemanforderungen"
description: "Prüfen Sie, was Spooky von macOS, Git und Ihren Servern verlangt."
---

Diese Seite führt auf, was Spooky auf Ihrem Mac und auf den Servern braucht, mit denen Sie sich verbinden.

## Mac {#mac}

| Was | Anforderung |
|---|---|
| macOS | macOS 26 oder neuer |
| Git | Git 2.41.0 oder neuer. Spooky verwendet `/usr/bin/git`, sofern Sie nicht unter :ui[app.name > settings.title] › :ui[settings.gitConfig] neben :ui[settings.gitProgram] ein anderes wählen. Siehe [Git-Programm](/guide/settings/identity/#git-program). |
| SSH | Das SSH, das mit macOS geliefert wird. Server-Repositorys stellen damit die Verbindung her. |

Spooky stützt sich auf Git-Funktionen, die mit Version 2.41.0 hinzugekommen sind. Ältere Versionen funktionieren daher nicht.

## Server {#servers}

Ein Server kann ein Linux-Rechner oder ein Mac sein. Spooky braucht dort keinen Administratorzugriff und installiert keinen Dienst.

| Was | Anforderung |
|---|---|
| Anmeldung | SSH-Anmeldung mit einem Schlüssel, über einen Host-Alias in `~/.ssh/config` auf Ihrem Mac. Ein Account, der sich nur mit einem Passwort anmelden kann, funktioniert nicht. Siehe [SSH vorbereiten](/guide/server/prepare-ssh/). |
| Git | Git 2.41.0 oder neuer, im `PATH`, den nicht interaktive SSH-Anmeldungen verwenden |
| SSH-Server | OpenSSH mit aktiviertem SFTP und erlaubter Weiterleitung von Unix-Sockets. Beides ist standardmäßig aktiviert. `MaxSessions` muss mindestens 10 betragen, was ebenfalls der Standard ist. |
| Passphrase-Abfragen | OpenSSH 8.4 oder neuer, falls Git auf dem Server eine Passphrase für einen SSH-Schlüssel braucht |
| Perl | `/usr/bin/perl` mit seinen Standardmodulen `IO::Socket::UNIX`, `JSON::PP`, `POSIX` und `Fcntl` |
| Dateien | Schreibzugriff auf `~/.spooky/bin` in Ihrem Benutzerordner auf dem Server und auf `/tmp` |
| Papierkorb | Optional. Auf einem Mac verwendet Spooky `/usr/bin/trash`, das mit macOS 15 und neuer geliefert wird. Unter Linux verwendet es `gio` oder `trash-put`. Ohne eines davon fragt Spooky zuerst nach und löscht Dateien dann endgültig. |

Um zu sehen, was ein Server bietet, bevor Sie ein Repository hinzufügen, führen Sie den Test unter [SSH vorbereiten](/guide/server/prepare-ssh/#test) aus. Sie können einen Server auch unter :ui[app.name > settings.title] › :ui[settings.environment] prüfen. Siehe [Einen Server prüfen](/guide/settings/general/#server-check).

## Optional {#optional}

| Für | Brauchen Sie |
|---|---|
| Git LFS | Git LFS 2.9.0 oder neuer, auf dem Rechner, auf dem das Repository liegt, im `PATH`, den Git dort verwendet |
| sshfs-Einbindungen | sshfs und macFUSE oder FUSE-T auf Ihrem Mac |
| SMB-Einbindungen | SMB-Dateifreigabe auf dem Server |
| Pull Requests und Merge Requests | Einen Account bei github.com oder GitLab.com oder bei einem selbst betriebenen GitLab 9.0 oder neuer |

## Siehe auch

- [Spooky installieren](/guide/start/install/)
- [So funktionieren Server-Repositorys](/guide/server/overview/)
- [Daten und Datenschutz](/reference/data-privacy/)
