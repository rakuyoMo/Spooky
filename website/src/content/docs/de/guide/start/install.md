---
title: "Spooky installieren"
description: "Prüfen Sie die Systemanforderungen, laden Sie Spooky, öffnen Sie es zum ersten Mal, halten Sie es aktuell, wählen Sie seine Sprache und deinstallieren Sie es."
---

Diese Seite führt Sie vom Laden von Spooky bis zum ersten Öffnen. Sie behandelt außerdem Updates, die Sprache der Oberfläche und das Entfernen von Spooky.

## Systemanforderungen {#requirements}

- macOS 26 oder neuer
- Git 2.41 oder neuer

Spooky verwendet das Git unter `/usr/bin/git`, solange Sie kein anderes wählen. Um eines zu wählen, öffnen Sie :ui[app.name > settings.title] (<kbd>⌘,</kbd>), klicken Sie auf :ui[settings.gitConfig] und wählen Sie ein Programm aus dem Menü :ui[settings.gitProgram]. Das Menü führt die Git-Programme auf, die Spooky gefunden hat und die neu genug sind. Wählen Sie :ui[settings.gitProgram.choose], um eines von einem anderen Ort zu verwenden. Die Mindestversion steht unter dem Menü. Siehe [Git-Programm](/guide/settings/identity/#git-program).

:::note[Server-Repositorys]
Auch der Server braucht Git 2.41 oder neuer. Spooky erreicht ihn per SSH über einen Host-Alias aus `~/.ssh/config`. Das Git, das Sie in den Einstellungen wählen, gilt nur für Repositorys auf Ihrem Mac. Server-Repositorys verwenden das Git auf dem Server. Siehe [Systemanforderungen](/reference/requirements/) und [SSH vorbereiten](/guide/server/prepare-ssh/).
:::

## Laden {#download}

1. Öffnen Sie die [Release-Seite von Spooky](https://github.com/rakuyoMo/Spooky/releases) auf GitHub.
2. Suchen Sie die neueste stabile Version. Ihr Name ist `v`, gefolgt von der Versionsnummer. Mit **Pre-release** markierte Versionen sind Beta- und Alphaversionen. Ihre Versionsnummern enden auf `-beta.` oder `-alpha.` und eine Zahl.
3. Laden Sie die ZIP-Datei mit dem Namen `Spooky-`, gefolgt von der Versionsnummer.
4. Doppelklicken Sie auf die geladene ZIP-Datei, um sie zu entpacken.
5. Ziehen Sie Spooky in Ihren Ordner **Programme**.

## Spooky zum ersten Mal öffnen {#first-launch}

Spooky ist nicht von Apple beglaubigt. Beim ersten Öffnen hält macOS es an und zeigt eine Warnung. So öffnen Sie es trotzdem:

1. Doppelklicken Sie im Ordner **Programme** auf Spooky. Wenn die Warnung erscheint, schließen Sie sie.
2. Wählen Sie **Apple-Menü › Systemeinstellungen** und klicken Sie in der Seitenleiste auf **Datenschutz & Sicherheit**. Möglicherweise müssen Sie nach unten scrollen.
3. Gehen Sie zu **Sicherheit** und klicken Sie auf **Dennoch öffnen**. Die Taste ist etwa eine Stunde lang verfügbar, nachdem Sie versucht haben, Spooky zu öffnen.
4. Geben Sie Ihr Anmeldepasswort ein und klicken Sie auf **OK**.

macOS merkt sich Ihre Entscheidung. Von da an öffnet sich Spooky normal. Es startet mit dem Fenster „Repositorys“. [Spooky im Überblick](/guide/start/tour/) erklärt, was Sie dort sehen.

## Spooky aktuell halten {#updates}

Spooky sucht standardmäßig von selbst nach Updates. :ui[app.name > updates.check] sucht sofort.

Jedes Update ist signiert. Spooky prüft die Signatur, bevor es ein Update installiert. Wenn ein Update die Prüfung nicht besteht, ersetzt es Ihre vorhandene Kopie nicht.

Um zu ändern, wie Spooky sich aktualisiert, öffnen Sie :ui[app.name > settings.title] und klicken Sie auf :ui[settings.updates]:

| Einstellung | Wirkung |
|---|---|
| :ui[updates.channel] | Welche Versionen Sie erhalten. Siehe [Update-Kanäle](#channels). |
| :ui[updates.automaticChecks] | Sucht im Hintergrund nach Updates. Standardmäßig eingeschaltet. |
| :ui[updates.automaticDownloads] | Lädt Updates im Hintergrund und installiert sie, wenn Sie Spooky beenden. Standardmäßig ausgeschaltet. Nur verfügbar, wenn die automatische Suche eingeschaltet ist und Spooky in einem Ordner liegt, in den Sie schreiben können. |
| :ui[updates.interval] | Wie oft gesucht wird: :ui[updates.interval.hourly], :ui[updates.interval.daily] oder :ui[updates.interval.weekly]. Der Standard ist täglich. Nur verfügbar, wenn die automatische Suche eingeschaltet ist. |

Die letzte Zeile, :ui[updates.lastCheck], zeigt, wann Spooky zuletzt gesucht hat. Wenn es noch nicht gesucht hat, steht dort :ui[updates.never].

### Update-Kanäle {#channels}

| Kanal | Sie erhalten |
|---|---|
| :ui[updates.channel.stable] | Stabile Versionen. Das ist der Standard. |
| :ui[updates.channel.beta] | Stabile Versionen und Betaversionen |
| :ui[updates.channel.development] | Alle Versionen, auch Alphaversionen |

### Was sich geändert hat {#whats-new}

Wenn Sie eine neue Version von Spooky zum ersten Mal starten, zeigen Repository-Fenster unten in der Seitenleiste :ui[whatsNew.card.title]. Klicken Sie auf :ui[whatsNew.card.learnMore], um zu lesen, was sich geändert hat. Sie können die Karte auch einfach schließen.

Um die Hinweise später zu lesen, wählen Sie :ui[menu.help > help.whatsNew]. :ui[menu.help > help.releaseNotes] öffnet die Releases auf GitHub.

## Die Sprache der Oberfläche wählen {#language}

Spooky gibt es auf Englisch, Chinesisch (vereinfacht), Chinesisch (traditionell), Japanisch, Koreanisch, Deutsch, Französisch und Spanisch. Es folgt der Sprachreihenfolge, die Sie in macOS festgelegt haben. Wenn keine Ihrer Sprachen verfügbar ist, verwendet es Englisch.

So verwenden Sie nur für Spooky eine andere Sprache:

1. Wählen Sie **Apple-Menü › Systemeinstellungen** und klicken Sie in der Seitenleiste auf **Allgemein**.
2. Klicken Sie auf **Sprache & Region** und gehen Sie zu **Apps**.
3. Klicken Sie auf die Taste **Hinzufügen**, wählen Sie Spooky und eine Sprache und klicken Sie auf **Hinzufügen**.
4. Wenn Spooky geöffnet ist, beenden Sie es und öffnen Sie es erneut.

Um zur Systemsprache zurückzukehren, wählen Sie Spooky in derselben Liste aus und klicken Sie auf die Taste **Entfernen**.

## Deinstallieren {#uninstall}

1. Beenden Sie Spooky mit :ui[app.name > menu.quit] (<kbd>⌘Q</kbd>).
2. Legen Sie Spooky aus dem Ordner **Programme** in den **Papierkorb**.

Ihre Einstellungen und Daten bleiben auf Ihrem Mac. So entfernen Sie auch diese:

- Einstellungen: Führen Sie `defaults delete com.rakuyo.spooky` im **Terminal** aus.
- Andere Daten, etwa Ihre Themen und die Einträge der Aktivität: Löschen Sie den Ordner `~/Library/Application Support/Spooky/`.
- Caches: Löschen Sie den Ordner `~/Library/Caches/com.rakuyo.spooky/` und die Objekte in `~/Library/HTTPStorages/`, deren Namen mit `com.rakuyo.spooky` beginnen.
- Passwörter und Tokens, die Spooky gesichert hat: Löschen Sie die Objekte in Ihrem Schlüsselbund, deren Namen mit `com.rakuyo.spooky.` beginnen.
- Auf jedem Server, den Sie verwendet haben: Löschen Sie dort den Ordner `~/.spooky/` in Ihrem Benutzerordner.

Repositorys behalten die Einträge `branch.<name>.spooky-*`, die Spooky zu ihrer Git-Konfiguration hinzugefügt hat. [Daten und Datenschutz](/reference/data-privacy/) führt auf, was Spooky speichert und wo.

## Siehe auch

- [Spooky im Überblick](/guide/start/tour/)
- [Systemanforderungen](/reference/requirements/)
- [Daten und Datenschutz](/reference/data-privacy/)
