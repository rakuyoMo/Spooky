---
title: "Erscheinungsbild und Themen"
description: "Wählen Sie das Erscheinungsbild, verwenden Sie ein integriertes Thema oder erstellen, importieren und exportieren Sie eigene, legen Sie die Optionen für Text und Editor fest und suchen Sie ein App-Symbol aus."
---

Vier Seiten unter :ui[app.name > settings.title] bestimmen, wie Spooky aussieht: :ui[settings.appearance] für die App als Ganzes, :ui[settings.themes] für die Farben von Diffs und Dateien, :ui[settings.text] für die Darstellung von Text und :ui[settings.editor] für die Commit-Nachricht.

## Erscheinungsbild {#appearance}

Klicken Sie in der Zeile :ui[settings.appearance.label] auf ein Bild, um die ganze App umzuschalten:

- :ui[appearance.system] folgt macOS. Das ist der Standard.
- :ui[appearance.light] und :ui[appearance.dark] bleiben gleich, egal was macOS verwendet.

In einem Repository-Fenster können Sie auch über die [Schnellaktionen](/guide/repositories/navigation/#quick-actions) umschalten: Suchen Sie das Erscheinungsbild und führen Sie :ui[quickActions.setAppearance] aus.

## App-Symbol {#app-icon}

Unter dem Erscheinungsbild führt :ui[settings.appIcon.label] die Symbole auf, die Sie wählen können, in zwei Serien:

| Serie | Symbole |
|---|---|
| :ui[appIcon.series.hideAndSeek] | :ui[appIcon.rise] (der Standard), :ui[appIcon.front], :ui[appIcon.hide], :ui[appIcon.reveal] |
| :ui[appIcon.series.cherryPick] | :ui[appIcon.midnight], :ui[appIcon.perch], :ui[appIcon.cherryPick], :ui[appIcon.armful] |

Zeigen Sie auf ein Symbol, um es links groß zu sehen. Darunter stehen die vier Arten, wie es im Dock erscheint: normal, mit einem Server verbunden, dunkel und dunkel mit Verbindung. Klicken Sie auf das Symbol, um es zu verwenden. Wenn die Symbole den Tastaturfokus haben, bewegen Sie sich mit den Pfeiltasten zwischen ihnen, und die <kbd>Leertaste</kbd> verwendet das aktuelle.

Das neue Symbol erscheint im Dock, im App-Umschalter (<kbd>⌘Tab</kbd>) und im Finder, auch wenn Spooky nicht läuft. Einige Dinge, die Sie wissen sollten:

- Solange ein Server-Repository verbunden ist, leuchtet das Symbol. Bei den Symbolen der Serie :ui[appIcon.series.hideAndSeek] gehen die Lichter des Servers an. Bei den Symbolen der Serie :ui[appIcon.series.cherryPick] werden die Augen des Geists zu leuchtenden Sternen.
- Die dunkle Version erscheint, wenn der Symbol- und Widgetstil unter **Systemeinstellungen › Erscheinungsbild** dunkel ist oder automatisch ist, während Spooky dunkel ist. Bei einem transparenten oder getönten Stil leuchtet das Symbol nicht.
- Wenn Sie zu :ui[appIcon.rise] oder davon weg wechseln, startet das Dock einmal neu. Sonst würde ein im Dock behaltenes Spooky weiter das alte Symbol zeigen.
- Jedes andere Symbol sichert Spooky in `Spooky.app`. Wenn es dort nicht schreiben kann, nennt die Seite den Grund, und das Symbol ändert sich nicht.

## Themen {#themes}

Ein Thema legt die Schrift und die Farben fest, die Diffs und Dateiinhalte verwenden. Spooky bringt zwei mit: Default für das helle Erscheinungsbild und Default (Dark) für das dunkle.

Das in der Liste ausgewählte Thema ist das, welches das aktuelle Erscheinungsbild verwendet. Hell und dunkel merken sich jeweils ihr eigenes. Um das Thema für das andere Erscheinungsbild festzulegen, wechseln Sie zuerst dorthin. Auch die Schnellaktionen können Themen wechseln, mit :ui[quickActions.applyTheme].

::screenshot[Die Seite „Themen“ des Einstellungsfensters. Die Liste links enthält Default und Default (Dark), Default ist ausgewählt, unten stehen die Tasten zum Hinzufügen und Entfernen. Rechts stehen ein Schriftfeld mit Menlo-Regular 11.0, eine Liste von Textarten wie normaler Text, Schlüsselwort, Zeichenkette und Kommentar, jede in ihrer Farbe, und Farbfelder für Schriftfarbe, Hintergrund, Auswahl, Hinzugefügt und Gelöscht. Darunter steht eine kurze Diff-Vorschau mit unveränderten, gelöschten und hinzugefügten Zeilen.]{name="themes" frame="window" markers="13.3,30 9.4,95.3 58.3,17.8 61.1,37.3 66.7,56.9 61.1,82.7"}

1. Die Liste der Themen
2. :ui[themes.add] und :ui[themes.remove]
3. Die Schrift
4. Die Textarten, die die Syntaxhervorhebung unterscheidet
5. Die Farbfelder
6. Eine Vorschau eines Diffs in diesem Thema

### Ein Thema erstellen und bearbeiten {#edit-theme}

1. Klicken Sie auf die Hinzufügen-Taste unter der Liste. Spooky fügt :ui[themes.newName] hinzu, mit den Farben des integrierten Themas für das aktuelle Erscheinungsbild, und wählt dessen Namen aus.
2. Geben Sie einen Namen ein und drücken Sie den <kbd>Zeilenschalter</kbd>.
3. Klicken Sie auf das Schriftfeld, um im Schriftfenster eine Schrift und Größe zu wählen.
4. Wählen Sie in der Liste eine Textart aus und klicken Sie auf :ui[themes.text], um ihre Farbe zu ändern. :ui[themes.background], :ui[themes.selection], :ui[themes.added] und :ui[themes.deleted] legen die Farben um den Text herum fest.

Änderungen werden sofort gesichert. Die Vorschau zeigt sie laufend. Um ein Thema später umzubenennen, wählen Sie es aus und drücken Sie den <kbd>Zeilenschalter</kbd>.

Die integrierten Themen können Sie bearbeiten, aber nicht umbenennen oder löschen. Um ein anderes Thema zu löschen, wählen Sie es aus und klicken Sie auf die Entfernen-Taste. Spooky fragt vorher nach, weil sich das nicht widerrufen lässt. Ein Erscheinungsbild, das das Thema verwendet hat, kehrt zu seinem integrierten zurück.

### Themen weitergeben {#share-themes}

Jedes Thema ist eine `.spookytheme`-Datei.

- **Exportieren**: Ziehen Sie ein Thema aus der Liste in einen Ordner im Finder.
- **Importieren**: Ziehen Sie `.spookytheme`-Dateien auf die Liste. Sie können sie auch im Finder öffnen oder auf das Symbol von Spooky im Dock ziehen.

Wenn ein Thema mit demselben Namen existiert, fragt Spooky, ob es ersetzt werden soll. Eine Datei, die kein gültiges Thema ist, wird mit einer Meldung übersprungen.

Spooky bewahrt Themen in `~/Library/Application Support/Spooky/Themes/` auf. Siehe [Daten und Datenschutz](/reference/data-privacy/#mac).

## Text {#text}

Die Seite :ui[settings.text] legt fest, wie Text in Diffs und Dateiinhalten aussieht. Die Farben kommen aus dem Thema.

| Einstellung | Standard | Wirkung |
|---|---|---|
| :ui[text.enableSyntaxColoring] | Ein | Färbt Code nach seiner Sprache |
| :ui[text.syntaxColoringInDiffs] | Aus | Verwendet Syntaxfarben auch in Diffs. Erfordert eingeschaltete Syntaxhervorhebung. |
| :ui[text.showInvisibles] | Aus | Zeigt Leerzeichen, Tabulatoren und Zeilenenden als Symbole |
| :ui[text.tabWidth] | 4 | Wie breit ein Tabulator ist, von 1 bis 100 Leerzeichen |

## Editor {#editor}

Die Seite :ui[settings.editor] richtet die Felder der Commit-Nachricht ein. Wie sie sich verhalten, lesen Sie unter [Die Nachricht schreiben](/guide/work/commit/#write).

| Einstellung | Standard | Wirkung |
|---|---|---|
| :ui[editor.showsCounter] | Ein | Zählt die im Betreff verbleibenden Zeichen herunter |
| :ui[editor.subjectLimit] | 50 | Wie lang der Betreff höchstens sein sollte, in Zeichen. Wählen Sie einen Wert oder geben Sie einen von 1 bis 1.000 ein. |
| :ui[editor.wrapping] | :ui[editor.softWrap] | Oder :ui[editor.hardWrap], mit einer Schrift fester Breite und ohne automatischen Umbruch |
| :ui[editor.bodyLimit] | 72 | Die Zeilengrenze für :ui[editor.hardWrap] |
| :ui[editor.showsGuide] | Ein | Zeichnet bei :ui[editor.hardWrap] eine Linie an dieser Grenze |
| :ui[editor.warnsComments] | Ein | Warnt vor Zeilen, die Git als Kommentare behandeln würde. Siehe [Kommentare in der Nachricht](/guide/work/commit/#comments). |
| :ui[editor.stripsComments] | Aus | Entfernt diese Zeilen beim Committen. Verfügbar, solange die Warnung ausgeschaltet ist. |
| :ui[editor.completesIssues] | Ein | Vervollständigt Issue-Nummern nach `#`. Siehe [Automatische Vervollständigung](/guide/work/commit/#autocomplete). |

## Siehe auch

- [Allgemein, Updates und Umgebung](/guide/settings/general/)
- [Änderungen prüfen und stagen](/guide/work/diff/)
- [Änderungen committen](/guide/work/commit/)
- [Fenster und Navigation](/guide/repositories/navigation/)
