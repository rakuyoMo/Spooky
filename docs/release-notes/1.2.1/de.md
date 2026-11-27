### Verbessert

- Im Layout für schmale Fenster enthält die Zeile unter der Symbolleiste jetzt alle Ansichten, die in der Seitenleiste unter **Arbeitsbereich** stehen: neben **Arbeitskopie**, **Verlauf** und **Stashes** auch **Pull Requests** (**Merge Requests**, wenn das Remote auf GitLab liegt), **Branch-Übersicht** und **Einstellungen**, dazu **Reflog**, wenn **Darstellung › Seitenleiste › Reflog anzeigen** eingeschaltet ist. Was nicht hineinpasst, erreichen Sie, indem Sie die Zeile seitwärts scrollen; mit einem Mausrad halten Sie dabei die Umschalttaste gedrückt. Die Zeile scrollt immer so weit, dass die aktuelle Ansicht zu sehen ist
- Im Layout für schmale Fenster stehen **Lesezeichen** und **Klonen** zusammen mit **Vorherige** und **Nächste** vor dem Fenstertitel, und **Lesezeichen**, **Vorherige**, **Nächste** und das Suchfeld bleiben bei jeder Breite in der Symbolleiste. Andere Tasten, die nicht hineinpassen, wandern in das Menü »; **Abrufen**, **Pullen** und **Pushen** wandern als letzte dorthin
- Während die **Arbeitskopie** geladen wird, erscheint der Fortschritt an der Stelle ihres Ordnersymbols, in der Seitenleiste wie im Layout für schmale Fenster. Die Zahl der geänderten Dateien und das Symbol eines laufenden Vorgangs bleiben sichtbar, und daneben verschiebt sich nichts mehr. Kurze Ladevorgänge zeigen keinen Fortschritt mehr, und ist er einmal zu sehen, bleibt er einen Moment stehen, sodass er nicht flackert

### Behoben

- Mit Esc verlassen Sie jetzt das Suchfeld in der Symbolleiste. Ihr Suchbegriff bleibt erhalten, und die Liste bleibt gefiltert
