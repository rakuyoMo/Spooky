---
title: "Änderungen committen"
description: "Betreff und Beschreibung eines Commits schreiben, die automatische Vervollständigung nutzen, den letzten Commit ändern sowie Identität und Signatur für einen Commit wählen."
---

Ein Commit sichert die gestagten Änderungen zusammen mit einer Nachricht im Verlauf des Repositorys. Stagen Sie zuerst die Änderungen, wie in [Änderungen prüfen und stagen](/guide/work/diff/) beschrieben. Schreiben Sie dann die Nachricht im Commit-Bereich oben in der Arbeitskopie.

## Die Nachricht schreiben {#write}

Die Nachricht hat zwei Teile:

- :ui[working.subject] ist eine kurze Zeile, die die Änderung zusammenfasst. Drücken Sie den <kbd>Zeilenschalter</kbd> oder <kbd>Tab</kbd>, um zur Beschreibung zu wechseln.
- :ui[working.body] ist optional. Erklären Sie dort, was sich geändert hat und warum.

::screenshot[Der Commit-Bereich, erweitert. Der Betreff lautet Add a units toggle, darunter steht eine zweizeilige Beschreibung. Unten in der Beschreibung liegen die Tasten zum Anheften und für den Umbruch. Darunter stehen die Markierungsfelder zum Ändern des letzten Commits und zum Abzeichnen, rechts davon Name, E-Mail-Adresse und Bild des Autors. Ganz unten liegen die Tasten zum Stagen aller Änderungen und zum Committen.]{name="work-commit-area" frame="closeup" markers="62,12 24,56 94.6,69.1"}

1. :ui[working.subject]
2. Die Taste zum Anheften und die Taste für den Umbruch
3. Das Bild des Autors

Der Commit-Bereich erweitert sich, während Sie in eines der Felder tippen, und bleibt offen, solange die Beschreibung Text enthält. Um ihn immer offen zu halten, klicken Sie unten in der Beschreibung auf die Taste zum Anheften. Ziehen Sie die Unterkante der Beschreibung, um sie höher oder niedriger zu machen.

Sobald Sie tippen, zählt die Zahl am Ende des Betreffs die Zeichen, die Ihnen noch bleiben. Zeichen jenseits der Grenze werden hervorgehoben.

Die andere Taste unten in der Beschreibung wechselt zwischen zwei Arten des Umbruchs:

- :ui[editor.softWrap] bricht Zeilen am Rand des Felds um.
- :ui[editor.hardWrap] verwendet eine Schrift mit fester Breite und bricht nicht um. Eine Hilfslinie markiert die Zeichengrenze, und längere Zeilen werden hervorgehoben. Um den aktuellen Absatz an der Grenze umzubrechen, wählen Sie :ui[menu.edit > commit.reformatParagraph] (<kbd>⇧⌘W</kbd>).

Diese Optionen finden Sie unter :ui[app.name > settings.title] › :ui[settings.editor]:

| Einstellung | Standard |
|---|---|
| :ui[editor.showsCounter] | Aktiviert |
| :ui[editor.subjectLimit] | 50 |
| :ui[editor.wrapping] | :ui[editor.softWrap] |
| :ui[editor.bodyLimit] | 72. Änderbar, wenn :ui[editor.hardWrap] gewählt ist. |
| :ui[editor.showsGuide] | Aktiviert. Wird mit :ui[editor.hardWrap] verwendet. |
| :ui[editor.warnsComments] | Aktiviert. Siehe [Kommentare in der Nachricht](#comments). |
| :ui[editor.stripsComments] | Deaktiviert. Verfügbar, wenn die Warnung deaktiviert ist. |
| :ui[editor.completesIssues] | Aktiviert. Siehe [Automatische Vervollständigung](#autocomplete). |

Siehe [Editor](/guide/settings/appearance/#editor).

## Committen {#commit}

Ist die Nachricht fertig, klicken Sie auf :ui[working.commit] oder drücken Sie <kbd>⌘↩</kbd>, während Sie in der Nachricht tippen. Die Taste bleibt abgeblendet, bis der Betreff Text enthält und Änderungen gestagt sind.

Um von überall im Fenster zum Betreff zu springen, wählen Sie :ui[workspace.title > working.commitMenu] (<kbd>⇧⌘C</kbd>).

Zwei Markierungsfelder unter der Beschreibung verändern den Commit:

- :ui[commit.signOff] hängt eine Zeile `Signed-off-by` mit Ihrem Namen und Ihrer E-Mail-Adresse an das Ende der Nachricht an. Das Markierungsfeld bleibt, wie Sie es verlassen haben, in allen Repositorys.
- :ui[commit.skipHooks] committet, ohne die Hooks `pre-commit` und `commit-msg` des Repositorys auszuführen. Es erscheint nur, wenn das Repository solche Hooks hat, und wird nach jedem Commit wieder deaktiviert.

Schlägt der Commit fehl, bleibt Ihre Nachricht im Commit-Bereich. Um einen gerade erstellten Commit zurückzunehmen, wählen Sie :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>). Siehe [Widerrufen und Wiederherstellen](/guide/work/undo/).

### Kommentare in der Nachricht {#comments}

Zeilen, die mit `#` beginnen, gelten in Git als Kommentare, sofern Sie kein anderes Kommentarzeichen festgelegt haben. Spooky committet die Nachricht so, wie Sie sie geschrieben haben, und fragt deshalb vorher nach, wenn die Nachricht solche Zeilen enthält: :ui[commit.comments]

- :ui[commit.removeComments] committet ohne diese Zeilen.
- :ui[commit.keepComments] committet sie unverändert.

Aktivieren Sie :ui[commit.doNotAskAgain], um Ihre Wahl für das nächste Mal zu behalten. Um die Frage zurückzuholen, aktivieren Sie :ui[editor.warnsComments] unter :ui[app.name > settings.title] › :ui[settings.editor]. Siehe [Editor](/guide/settings/appearance/#editor).

Enthält die Nachricht nur Kommentare, fragt Spooky :ui[commit.commentsOnly] Klicken Sie auf :ui[commit.keepCommentsAndCommit], um sie trotzdem zu committen.

## Automatische Vervollständigung {#autocomplete}

Geben Sie im Betreff oder in der Beschreibung eines der folgenden Zeichen ein, und Spooky listet beim Weitertippen die Treffer auf:

| Eingabe | Fügt ein |
|---|---|
| `c:` | Den Kurz-Hash eines der letzten 100 Commits. Geben Sie einen Teil des Hashs, des Betreffs oder des Autors ein. |
| `\` | Den Pfad einer gestagten Datei |
| `#` | Die Nummer eines offenen Issues auf GitHub oder GitLab |
| `fixup!` oder `squash!` am Anfang des Betreffs | Den Betreff eines früheren Commits, um diesen Commit als Korrektur dafür zu markieren |

::screenshot[Der Commit-Betreff nach der Eingabe von c:. Eine Liste darunter zeigt die letzten Commits, jeweils mit Autor, Datum, Kurz-Hash und Betreff. Der erste ist ausgewählt.]{name="work-commit-completion" frame="closeup"}

Drücken Sie <kbd>↑</kbd> oder <kbd>↓</kbd>, um einen Treffer zu wählen, den <kbd>Zeilenschalter</kbd>, um ihn einzufügen, und <kbd>Esc</kbd>, um die Liste zu schließen.

Issue-Nummern setzen einen [Hosting-Account](/guide/hosting/accounts/) für das Remote des Repositorys voraus, und :ui[editor.completesIssues] muss unter :ui[app.name > settings.title] › :ui[settings.editor] aktiviert sein. Siehe [Editor](/guide/settings/appearance/#editor). Ein mit `fixup!` oder `squash!` markierter Commit lässt sich später in sein Ziel einfügen, wie in [Verlauf umschreiben](/guide/history/rewrite/) beschrieben.

## Den letzten Commit ändern {#amend}

Beim Ändern wird der letzte Commit durch einen neuen ersetzt. Damit korrigieren Sie die Nachricht oder fügen vergessene Änderungen hinzu.

1. Aktivieren Sie :ui[working.amend] unter der Beschreibung. Spooky trägt die Nachricht des letzten Commits ein, und das Markierungsfeld zeigt den Kurz-Hash dieses Commits.
2. Bearbeiten Sie die Nachricht und stagen Sie die Änderungen, die hinein sollen.
3. Klicken Sie auf :ui[working.amend].

Deaktivieren Sie das Markierungsfeld, um zu der Nachricht zurückzukehren, die Sie vorher geschrieben haben.

Um den letzten Commit schnell zu ändern, halten Sie <kbd>⌥</kbd> gedrückt, während keines der Nachrichtenfelder bearbeitet wird. Der Commit-Bereich wechselt zum Ändern des letzten Commits, bis Sie die Taste loslassen. Klicken Sie bei gedrückter Taste auf :ui[working.amend] oder drücken Sie <kbd>⌥⌘↩</kbd>. Der Commit behält seine Nachricht und nimmt die gestagten Änderungen auf.

:::caution
Haben Sie den letzten Commit bereits gepusht, unterscheidet er sich nach dem Ändern von dem auf dem Remote. Zum Pushen ist dann ein Force-Push nötig. Siehe [Force-Push](/guide/branches/sync/#force-push).
:::

Wie Sie einen älteren Commit ändern, steht in [Verlauf umschreiben](/guide/history/rewrite/).

## Wählen, wer committet {#identity}

Name und E-Mail-Adresse rechts neben den Markierungsfeldern werden im Commit als Autor festgehalten. Sie stammen aus den Git-Einstellungen `user.name` und `user.email`. Das Bild daneben wird anhand der E-Mail-Adresse gesucht. Siehe [Daten und Datenschutz](/reference/data-privacy/).

Um als jemand anderes zu committen, zum Beispiel mit Ihrer geschäftlichen E-Mail-Adresse, verwenden Sie ein Benutzerprofil:

1. Klicken Sie auf das Bild. Ein Menü listet Ihre Profile auf, mit einem Häkchen neben dem verwendeten.
2. Wählen Sie ein Profil.
3. Prüfen Sie, welche Einstellungen Spooky schreiben wird, und klicken Sie auf :ui[profiles.apply.submit].

Name, E-Mail-Adresse und Signaturschlüssel des Profils kommen in die eigenen Git-Einstellungen dieses Repositorys, andere Repositorys sind also nicht betroffen.

Ist die aktuelle Identität noch kein Profil, bietet das Menü :ui[profiles.addCurrent]{1="alex@example.com"} an, um sie als Profil zu sichern. Um Profile einzurichten, wählen Sie :ui[profiles.manage] aus demselben Menü. Siehe [Benutzerprofile](/guide/settings/identity/#profiles).

:::note[Server-Repositorys]
Das Profil kommt in die Einstellungen des Repositorys auf dem Server. Andere Werkzeuge, die im selben Repository auf dem Server committen, verwenden es ebenfalls.
:::

## Commits signieren {#signing}

Ein signierter Commit trägt den Nachweis, dass er vom Besitzer eines Schlüssels stammt. Spooky arbeitet mit SSH- und OpenPGP-Schlüsseln.

Bewegen Sie den Zeiger über das Bild im Commit-Bereich, um zu sehen, ob der nächste Commit signiert wird und mit welchem Schlüssel.

- **Für alle Repositorys**: Aktivieren Sie :ui[gitConfig.signCommits] und wählen Sie :ui[gitConfig.signingKey] unter :ui[app.name > settings.title] › :ui[settings.gitConfig]. Siehe [Signieren](/guide/settings/identity/#signing).
- **Für ein Repository**: Klicken Sie in der Seitenleiste auf :ui[repositorySettings.title]. Legen Sie unter :ui[repositorySettings.signing] die Optionen :ui[repositorySettings.signCommits] und :ui[repositorySettings.signingKey] fest. Siehe [Repository-Einstellungen](/guide/settings/identity/#repository).

Braucht der Schlüssel eine Passphrase, fragt Spooky in einem Dialogfenster :ui[signing.unlock] danach.

## Siehe auch

- [Änderungen prüfen und stagen](/guide/work/diff/)
- [Widerrufen und Wiederherstellen](/guide/work/undo/)
- [Benutzerprofile und Git-Konfiguration](/guide/settings/identity/)
