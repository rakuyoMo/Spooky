---
title: "Benutzerprofile und Git-Konfiguration"
description: "Verwalten Sie Benutzerprofile und die Git-Konfiguration und passen Sie die Einstellungen eines einzelnen Repositorys an."
---

Git hält bei jedem Commit einen Namen und eine E-Mail fest und kann ihn mit einem Schlüssel signieren. Spooky bietet Ihnen drei Orte, um das einzurichten:

- :ui[settings.profiles] unter :ui[app.name > settings.title] bewahrt Identitäten auf, zwischen denen Sie wechseln.
- :ui[settings.gitConfig] unter :ui[app.name > settings.title] legt das Git-Programm sowie Ihre globale Identität und das Signieren fest.
- Die Einstellungen eines einzelnen Repositorys haben für dieses Repository Vorrang vor den globalen.

## Benutzerprofile {#profiles}

Ein Benutzerprofil besteht aus einem Namen, einer E-Mail und einem optionalen Signaturschlüssel, gesichert unter einem Titel wie „Arbeit“. Spooky bewahrt Profile auf diesem Mac auf. Sie können sie in lokalen und in Server-Repositorys verwenden.

So fügen Sie ein Profil hinzu:

1. Wählen Sie :ui[app.name > settings.title] › :ui[settings.profiles].
2. Klicken Sie auf die Hinzufügen-Taste unter der Liste.
3. Füllen Sie die Felder :ui[profiles.title], :ui[profiles.userName] und :ui[profiles.email] aus. Wählen Sie optional unter :ui[profiles.signingKey] einen der Schlüssel, die auf diesem Mac gefunden wurden.
4. Klicken Sie auf :ui[profiles.create.submit].

Titel, Benutzername und E-Mail sind erforderlich. Zwei Profile können nicht denselben Titel haben und auch nicht zugleich denselben Benutzernamen und dieselbe E-Mail.

Um ein Profil zu ändern, wählen Sie es aus und klicken Sie auf :ui[profiles.edit]. Um eines zu löschen, wählen Sie es aus und klicken Sie auf die Entfernen-Taste. Das Löschen eines Profils ändert keine Git-Einstellungen.

Wenn die Identität, die Sie gerade verwenden, noch kein Profil ist, wählen Sie :ui[profiles.addCurrent]{1="alex@example.com"} aus ihrem Menü. Geben Sie einen Titel ein und klicken Sie auf :ui[profiles.add.submit].

### Ein Profil verwenden {#use-profile}

Klicken Sie auf das Bild neben einer Identität, um Ihre Profile zu sehen; ein Häkchen markiert das verwendete. Was die Wahl eines Profils ändert, hängt davon ab, wo Sie es wählen:

| Wo | Was es ändert | Fragt vorher |
|---|---|---|
| Im Commit-Bereich oder unter :ui[bookmarks.detail.identity] in den [Repository-Einstellungen](#repository) | Die eigenen Git-Einstellungen dieses Repositorys. Siehe [Wählen, wer committet](/guide/work/commit/#identity). | Ja |
| Unter :ui[settings.gitConfig] in den Einstellungen | Ihre globalen Git-Einstellungen auf diesem Mac | Nein |

Name und E-Mail des Profils werden in `user.name` und `user.email` geschrieben. Ein Profil mit Signaturschlüssel setzt außerdem `user.signingkey` und `gpg.format`.

Auch die [Schnellaktionen](/guide/repositories/navigation/#quick-actions) führen Ihre Profile auf. :ui[quickActions.setCommitter] wirkt wie der Commit-Bereich. :ui[quickActions.setGlobalUser] setzt nach einer Rückfrage Name und E-Mail in Ihren globalen Git-Einstellungen auf dem Rechner, auf dem das Repository liegt.

:::note[Server-Repositorys]
Wenn Sie für ein Server-Repository ein Profil wählen, ändern sich die Einstellungen des Repositorys auf dem Server. Andere Werkzeuge, die dort committen, verwenden dieselbe Identität. :ui[quickActions.setGlobalUser] schreibt in einem Server-Repository in Ihre globalen Einstellungen auf dem Server.
:::

## Git-Konfiguration {#git-config}

Die Seite :ui[settings.gitConfig] hat vier Teile: das Git-Programm, Ihre Identität, das Signieren und externe Werkzeuge. Die Werkzeuge sind unter [Integration](/guide/settings/integration/#diff-merge-tools) beschrieben.

::screenshot[Die Seite „Git-Konfiguration“ des Einstellungsfensters mit dem Git-Programm, dem globalen Namen und der globalen E-Mail, den Einstellungen zum Signieren und den Vergleichs- und Zusammenführungswerkzeugen.]{name="settings-git-config" frame="window" markers="18,15.6 18,27.4 18,42.9 18,81.8"}

1. Das Git-Programm
2. Ihre Identität
3. Das Signieren
4. Externe Werkzeuge

### Git-Programm {#git-program}

:ui[settings.gitProgram] führt die Git-Programme auf diesem Mac auf, die neu genug sind, mit ihren Versionen. Spooky sucht an den üblichen Orten: `/usr/bin/git` (als das des Systems markiert und anfangs verwendet), Command Line Tools, Xcode, Homebrew und MacPorts.

Um ein Git zu verwenden, das nicht aufgeführt ist, wählen Sie :ui[settings.gitProgram.choose] und wählen Sie das Programm aus. Wenn die Datei kein Git ist oder ihre Version zu alt ist, sagt Spooky Ihnen den Grund und behält das bisherige. Die Zeile unter dem Menü zeigt die niedrigste Version, die Spooky akzeptiert.

:::note[Server-Repositorys]
Diese Einstellung gilt nur für lokale Repositorys. Server-Repositorys verwenden das Git auf dem Server. Siehe [Systemanforderungen](/reference/requirements/#servers).
:::

### Globale Identität {#global-identity}

:ui[gitConfig.userName] und :ui[gitConfig.email] sind Gits globale Einstellungen `user.name` und `user.email`. Jedes Repository auf diesem Mac verwendet sie, sofern es keine eigenen hat.

Änderungen werden gesichert, wenn Sie den <kbd>Zeilenschalter</kbd> drücken oder das Feld verlassen. Wenn Sie ein Feld leeren, wird die Einstellung entfernt. Die Zeile darunter zeigt, in welcher Datei sie gesichert sind, meist `~/.gitconfig`.

Klicken Sie auf das Bild rechts, um ein [Profil](#use-profile) zu wählen oder die Profile zu verwalten.

### Signieren {#signing}

Diese Einstellungen legen fest, wie Git Commits in jedem Repository auf diesem Mac signiert, das keine eigenen festlegt.

| Einstellung | Wirkung |
|---|---|
| :ui[gitConfig.sshProgram] | Das Programm, das mit SSH-Schlüsseln signiert. Anfangs wird :ui[gitConfig.sshProgram.system] verwendet. Wenn 1Password installiert ist, wird auch dessen Signierprogramm aufgeführt. |
| :ui[gitConfig.gpgProgram] | Das GnuPG-Programm für OpenPGP-Schlüssel. Führt die Versionen auf diesem Mac auf, die neu genug sind. Wählen Sie :ui[gitConfig.gpgProgram.select], um ein anderes zu wählen. |
| :ui[gitConfig.signingKey] | Der Schlüssel, mit dem signiert wird: ein geheimer Schlüssel in Ihrem GnuPG-Schlüsselbund oder ein Schlüssel, der im SSH-Agent geladen ist. Die Wahl eines Schlüssels sagt Git auch, ob mit OpenPGP oder SSH signiert wird. |
| :ui[gitConfig.allowedSigners] | Die Datei mit SSH-Schlüsseln, deren Signaturen Sie vertrauen; sie wird verwendet, wenn Git Signaturen prüft. Wählen Sie `~/.ssh/allowed_signers`, eine andere Datei oder :ui[gitConfig.allowedSigners.none]. |
| :ui[gitConfig.signCommits] | Signiert jeden Commit |
| :ui[gitConfig.ensureEmailMatch] | Warnt, wenn die E-Mail des OpenPGP-Schlüssels nicht Ihre globale E-Mail ist. Anfangs eingeschaltet. |

Wenn etwas Ihre Aufmerksamkeit braucht, etwa ein Signierprogramm, das nicht ausgeführt werden kann, erscheint neben der Einstellung eine gelbe Warntaste. Klicken Sie darauf, um zu sehen, was nicht stimmt.

Signierte Commits und die Abfrage der Passphrase sind unter [Commits signieren](/guide/work/commit/#signing) beschrieben.

## Repository-Einstellungen {#repository}

Jedes Repository hat eigene Einstellungen. Um sie zu sehen, klicken Sie in der Seitenleiste unter :ui[workspace.group] auf :ui[repositorySettings.title]. Die Tasten oben wechseln zwischen vier Abschnitten.

Änderungen werden in die eigenen Git-Einstellungen des Repositorys geschrieben und reihen sich in die Warteschlange der anderen Vorgänge des Repositorys ein. Alles, was ein Repository nicht festlegt, kommt aus Ihren globalen Einstellungen.

::screenshot[Die Repository-Einstellungen im Hauptfenster, im Abschnitt „Allgemein“, mit Name, Pfad, Beschreibung, Identität und den Einstellungen zum Signieren des Repositorys.]{name="settings-repository" frame="window" markers="68.6,9.8 60,38.8"}

1. Die Tasten, die zwischen den Abschnitten wechseln
2. :ui[bookmarks.detail.identity]

### Allgemein {#repository-general}

| Eintrag | Was er zeigt |
|---|---|
| :ui[repositorySettings.name] und :ui[repositorySettings.path] | Wo das Repository liegt |
| :ui[repositorySettings.localLocation] | Bei Server-Repositorys, wo der Ordner des Repositorys auf diesem Mac liegt. Siehe [Den Ort festlegen](/guide/server/local-location/#set). |
| :ui[bookmarks.detail.description] | Eine Beschreibung des Repositorys. Auch [das Fenster „Repositorys“](/guide/repositories/manager/) zeigt sie. Klicken Sie auf :ui[bookmarks.detail.edit], um sie zu ändern. |
| :ui[bookmarks.detail.identity] | Name und E-Mail, mit denen dieses Repository committet. Klicken Sie auf das Bild, um ein [Profil](#use-profile) zu verwenden, oder auf :ui[bookmarks.detail.edit], um Name und E-Mail nur für dieses Repository einzugeben. |

Unter :ui[repositorySettings.signing] wirken :ui[repositorySettings.signCommits], :ui[repositorySettings.signingKey] und :ui[repositorySettings.allowedSigners] wie die [globalen Einstellungen](#signing), nur für dieses Repository.

### Git LFS, Ignorieren und Ausschließen {#repository-files}

- :ui[repositorySettings.lfs] zeigt die Version von Git LFS und die :ui[repositorySettings.lfs.patterns]. Siehe [Git LFS](/guide/advanced/lfs/).
- :ui[repositorySettings.ignores] führt die Regeln in der `.gitignore` auf der obersten Ebene des Repositorys auf. Committen Sie diese Datei, um die Regeln mit anderen zu teilen.
- :ui[repositorySettings.excludes] führt die Regeln in Gits `info/exclude` auf. Sie gelten nur für diese Kopie des Repositorys.

Klicken Sie auf :ui[repositorySettings.openInEditor], um die Regeln zu ändern. Die Datei öffnet sich in der App, die Ihr Mac dafür verwendet. Wenn die Datei noch nicht existiert, erstellt Spooky sie zuerst.

:::note[Server-Repositorys]
Die Einstellungen werden auf dem Server gelesen und geschrieben. Sie können sie nur ändern, solange das Repository verbunden ist. :ui[repositorySettings.openInEditor] öffnet die Datei genauso, wie die Arbeitskopie Dateien auf dem Server öffnet. Siehe [Terminal und andere Apps](/guide/server/local-location/#terminal).
:::

## Siehe auch

- [Änderungen committen](/guide/work/commit/)
- [Allgemein, Updates und Umgebung](/guide/settings/general/)
- [Integration](/guide/settings/integration/)
- [Systemanforderungen](/reference/requirements/)
