### Neu

- Neue Seite **SSH-Hosts** in den Einstellungen: Host-Aliasse aus ~/.ssh/config ansehen, hinzufügen, bearbeiten und löschen. Zum Bearbeiten doppelklicken Sie auf einen Alias oder drücken den Zeilenschalter; Spooky ändert nur die Zeilen, die Sie bearbeiten, andere Optionen und Kommentare bleiben, wie sie sind
- Die Liste der Pull Requests und Merge Requests lässt sich von **Offen** auf **Alle** umschalten und zeigt dann auch geschlossene und zusammengeführte Requests
- Die Labels eines Requests erscheinen in der Liste und in **Unterhaltung**
- Neue Ansicht **CI/CD** in den Details eines Requests: Gesamtstatus und Ergebnis jeder Prüfung oder jedes Jobs, laufend aktualisiert, solange etwas wartet oder läuft; auch jede Zeile der Liste zeigt den CI/CD-Status

### Verbessert

- Server-Repositorys verbinden sich schneller, und Git-Befehle, das Lesen und Schreiben von Dateien sowie das Abbrechen gehen schneller, besonders bei hoher Netzwerklatenz; ein Verbindungsabbruch wird früher erkannt
- Wenn Sie mehrere Zeilen in **Commit-Betreff** einfügen, bleibt die erste Zeile im Betreff und der Rest kommt in **Ausführliche Beschreibung**
- Im Fenster **Repositorys** benennt der Zeilenschalter jetzt das ausgewählte Lesezeichen oder die ausgewählte Gruppe um, statt das Repository zu öffnen, und Esc bricht ab; Repositorys öffnen Sie per Doppelklick. Ein Klick auf den Namen einer ausgewählten Zeile startet kein Umbenennen mehr
- Die Standardsymbolleiste des Repository-Fensters enthält jetzt **Finder**, **Terminal**, **Force-Push** und **Branch erstellen**; **Schnellaktionen**, **Synchronisieren** und **Zusammenführen** / **Rebase** fügen Sie bei Bedarf über **Symbolleiste anpassen …** hinzu. Um ganz zur neuen Anordnung zu wechseln, ziehen Sie dort den Standardsatz in die Symbolleiste
- Beim Löschen von Lesezeichen ist das Markierungsfeld für den Papierkorb grau dargestellt, wenn der Ordner eines Server-Repositorys auf dem Server nicht mehr vorhanden ist, und nur das Lesezeichen wird entfernt
- Wenn Sie ein GitLab-Repository erneut öffnen, spricht Spooky sofort von Merge Requests, ohne auf das Laden der Remotes zu warten
- GitLab löscht die Referenz auf den Quell-Branch eines Merge Requests 14 Tage nach dem Schließen oder Zusammenführen; wenn Sie danach seine Commits abrufen, erscheint **Die Commits sind nicht mehr verfügbar**
- Scheitert ein Git-Befehl wie ein Branch-Wechsel oder das Stagen, weil git-lfs nicht gefunden wird, lautet der Fehler jetzt **Git LFS ist nicht verfügbar** und erklärt, wie Sie PATH für ein lokales oder ein Server-Repository einrichten
- Alte Versionen des Hilfsskripts in ~/.spooky/bin auf einem Server werden nach 30 Tagen ohne Nutzung gelöscht
- Einheitlichere Begriffe und Satzzeichen in der Oberfläche aller Sprachen

### Behoben

- Bricht beim Schreiben einer Datei in einem Server-Repository die Verbindung ab oder wird der Vorgang abgebrochen, bleibt die ursprüngliche Datei unbeschädigt
- Eine kurze Netzwerkpause unterbricht weder die Verbindung zu einem Server-Repository noch die dort laufenden Befehle
- Nachdem Sie das Schreiben einer Datei in einem Server-Repository abgebrochen haben, zeigt Spooky die Verbindung nicht mehr als aktiv an, während weitere Schreibvorgänge abgelehnt werden
- Dateien, die Git in einem Server-Repository anlegt, erhalten ihre Rechte nach der umask der Anmeldung, genau wie wenn Sie Git selbst per SSH ausführen
- Passwörter in Remote-URLs erscheinen nicht mehr in Aktivitätsprotokollen und Fehlermeldungen
- Zwei Server-Repositorys, deren Pfade gleich aussehen, sich aber in den Bytes unterscheiden, teilen sich keine Verbindung mehr
- Wenn Sie das App-Symbol mehrmals hintereinander wechseln, gilt die zuletzt gewählte Gruppe
- Das Symbolleistenobjekt **Klonen** lässt sich verschieben und entfernen und steht immer in **Symbolleiste anpassen …**
- Beim Pullen zeigen Aktivitätszusammenfassungen nicht mehr das rohe Abrufergebnis von Git
