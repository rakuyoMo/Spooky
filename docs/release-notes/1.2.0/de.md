### Neu

- Wird das Repository-Fenster zu schmal für drei Spalten, wechselt es in ein Layout für schmale Fenster: Eine Zeile unter der Symbolleiste ersetzt die Seitenleiste und wechselt zwischen **Arbeitskopie**, **Verlauf** und **Stashes**, und die Liste steht über den Details. Klicken Sie am Anfang der Zeile auf **Seitenleiste**, um die ganze Seitenleiste über der Ansicht zu öffnen. Machen Sie das Fenster breiter, kommen die drei Spalten so breit wie zuvor zurück; die aktuelle Ansicht, Ihre Auswahl und die Commit-Nachricht, an der Sie schreiben, bleiben erhalten
- In einem schmalen Fenster wandern Tasten, die nicht mehr in die Symbolleiste passen, in das Menü », während **Abrufen**, **Pullen** und **Pushen** in der Symbolleiste bleiben
- Auch das Fenster **Repositorys** wechselt das Layout, wenn es schmal wird: Die Liste der Repositorys steht über den Details des ausgewählten Repositorys, und Sie können die Linie dazwischen ziehen
- Um bei einem Layout zu bleiben, wählen Sie unter **Darstellung › Fensterlayout** die Option **Schmal** oder **Breit**; das Fenster verwendet dieses Layout dann bei jeder Breite. Mit **Automatisch**, der Standardeinstellung, richtet sich das Layout nach der Breite des Fensters. Die Auswahl gilt für alle Fenster
- Im Fenster **Repositorys** lässt sich der Ort eines Repositorys ändern, ohne es zu entfernen und neu hinzuzufügen: Bewegen Sie in den Details den Zeiger auf die Zeile **Ort** und klicken Sie auf **Bearbeiten**. Bei einem Server-Repository können Sie auch nur den Host-Alias oder nur den Pfad ändern. Das Repository bleibt in seiner Gruppe und behält einen Namen, den Sie ihm gegeben haben
- In der Ansicht **CI/CD** in den Details eines Requests lässt sich ein Check oder Job mit Protokoll aufklappen, und das Protokoll erscheint unter seiner Zeile. Jobs von GitHub Actions haben ein Protokoll, sobald sie beendet sind; jeder Job einer GitLab-Pipeline lässt sich aufklappen, und solange ein Job läuft, wird sein Protokoll zusammen mit dem Status aktualisiert
- Die Labels eines Requests lassen sich in **Unterhaltung** hinzufügen und entfernen: Klicken Sie auf das × hinter dem Namen eines Labels, um es zu entfernen, auf **Hinzufügen**, um eines der Labels des Projekts zu wählen, oder erstellen Sie mit **Neues Label …** ein Label und fügen es dem Request hinzu
- Um jemanden in einem Kommentar zu einem Request zu erwähnen, auch in einer Antwort oder beim Bearbeiten, geben Sie @ ein. Spooky listet die Beteiligten des Requests und die Mitglieder des Projekts auf und grenzt die Liste ein, während Sie einen Benutzernamen oder Namen weitertippen; drücken Sie den Zeilenschalter, um den Benutzernamen einzufügen

### Verbessert

- Die Liste der Pull Requests und Merge Requests zeigt den Status jetzt als Symbol vor dem Titel statt als Text dahinter: grün bei einem offenen Request, grau bei einem Entwurf, rot bei einem geschlossenen und violett bei einem zusammengeführten
- Auf der Seite **Updates** in den Einstellungen heißen die Release-Kanäle jetzt **Stabil**, **Beta** und **Alpha**. Beta- und Alphaversionen tragen die Kennzeichnung in der Versionsnummer, etwa 1.2.0-beta.1, und sind so unter **Über Spooky** und im Update-Fenster gleich zu erkennen

### Behoben

- macOS fragt nicht mehr nach jedem Update von Spooky nach Ihrem Schlüsselbundpasswort, wenn Spooky das Token eines Accounts oder die im Schlüsselbund gesicherten Zugangsdaten liest. Nachdem Sie diese Version installiert haben, fragt macOS noch einmal für jeden gesicherten Eintrag
- Nachdem Sie auf der Seite **SSH-Hosts** in den Einstellungen einen Alias geändert haben, scheitert die Verbindung zu den Repositorys mit Lesezeichen auf diesem Host nicht mehr am alten Alias; ihre Einstellungen und die im Schlüsselbund gesicherten Zugangsdaten wechseln ebenfalls zum neuen Alias
- In der Ansicht der Pull Requests oder Merge Requests lesen **Aktualisieren** und ⌘R jetzt die Liste und den ausgewählten Request neu ein, und wenn Sie im selben Fenster zu dem Repository zurückkehren, wird die Liste erneut geladen
- Wird die Liste der Pull Requests oder Merge Requests neu eingelesen, gehen Auswahl und Details eines Requests weiter unten in der Liste nicht mehr verloren
- Ist **Worktrees in der Repository-Liste anzeigen** auf der Seite **Allgemein** in den Einstellungen ausgeschaltet, legt das Öffnen eines Worktrees kein Lesezeichen mehr dafür an
