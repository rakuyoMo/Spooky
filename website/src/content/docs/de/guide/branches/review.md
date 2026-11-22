---
title: "Branch-Übersicht"
description: "Lokale Branches mit einem Basis-Branch vergleichen, Kandidaten zum Aufräumen finden, Archivierungsvorschlägen folgen und Branches automatisch archivieren."
---

Die Branch-Übersicht listet Ihre lokalen Branches auf und vergleicht jeden mit einem Basis-Branch. Sie zeigt, welche Branches sich zusammenführen lassen, welche Konflikte ergäben, welche veraltet sind und welche ihren Remote-Branch verloren haben. So entscheiden Sie leichter, was Sie zusammenführen, archivieren oder löschen.

Um sie zu öffnen, klicken Sie oben in der Seitenleiste auf :ui[review.title] oder wählen Sie :ui[menu.view > review.show] (<kbd>⌘5</kbd>).

::screenshot[Das Fenster „Branch-Übersicht“. Der Basis-Branch ist main. Die Liste zeigt sechs Branches, von feature/csv-export bis spike/radar-overlay, jeweils mit Merge-Status, Commits voraus und zurück und verfolgtem Branch. feature/units-toggle ist ausgewählt, und die Details rechts zeigen seine Commits und eine Konflikttaste.]{name="branches-review" frame="window" markers="44,9 47.3,9 22,52 76,9"}

1. Der Basis-Branch
2. Die Filtertaste
3. Ob sich der Branch ohne Konflikte zusammenführen lässt
4. Die Konflikttaste

## Die Liste {#list}

Wählen Sie den Basis-Branch oben in der Liste unter :ui[review.compareTo]. Anfangs ist das der erste von `next`, `develop`, `dev`, `main` und `master`, den das Repository hat, sonst der Branch, auf dem Sie sich befinden.

Jeder Branch bekommt eine Zeile:

- Ein Symbol links sagt, ob sich der Branch ohne Konflikte in die Basis zusammenführen lässt oder zu Konflikten führen würde. Bewegen Sie den Zeiger darauf, um Details zu sehen.
- Rechts steht, wie viele Commits der Branch der Basis voraus ist und wie viele er zurückliegt. Während Spooky vergleicht, steht dort :ui[review.comparing].
- Die zweite Zeile zeigt den Remote-Branch, den er verfolgt, oder :ui[review.noTracking]. Wenn der Remote-Branch nicht mehr existiert, wird der Name rot.
- Wann der Branch zuletzt aktualisiert wurde, und der neueste Pull Request oder Merge Request für den Branch, mit seiner Nummer und einer Farbe für seinen Status.

## Filtern und sortieren {#filter}

Die Filtertaste oben rechts zeigt nur einen Teil der Branches:

- :ui[review.filter.stale] und :ui[review.filter.active] teilen die Branches danach, ob sie veraltet sind. Veraltet heißt: keine neuen Commits seit dem Zeitraum, der in den [Darstellungsoptionen](/guide/branches/branches/#filter) der Seitenleiste festgelegt ist, anfangs 6 Monate.
- :ui[review.filter.trackingError] zeigt Branches, deren Remote-Branch nicht mehr existiert.
- :ui[review.filter.mergeable] und :ui[review.filter.conflicts] richten sich danach, was ein Merge in die Basis ergäbe.
- :ui[pr.filter.with] und :ui[pr.filter.without] richten sich nach offenen Pull Requests oder Merge Requests. Sie brauchen einen [Hosting-Account](/guide/hosting/accounts/) für das Remote. Ohne Account weist die Liste darauf hin.
- :ui[review.filter.none] zeigt wieder jeden Branch.

Die Taste für die Darstellungsoptionen daneben sortiert die Liste nach :ui[review.sort.name] oder :ui[review.sort.date], in der Reihenfolge :ui[review.sort.ascending] oder :ui[review.sort.descending]. Spooky merkt sich Filter und Reihenfolge.

Um einen Branch nach Namen zu finden, tippen Sie in das Suchfeld in der Symbolleiste.

## Details {#details}

Wählen Sie einen Branch aus, um rechts den Vergleich mit der Basis zu sehen. Oben stehen der Branch und die Basis. Wenn ein Merge Konflikte ergäbe, listet eine Taste dort die Dateien auf.

:ui[compare.commits] listet die Commits auf, die der Branch seit der Abzweigung von der Basis erstellt hat. :ui[history.changeset] zeigt, was diese Commits geändert haben. Über beiden zeigt eine Zusammenfassung :ui[review.summary.contributors], :ui[review.summary.updated], :ui[review.summary.tracking] und :ui[review.summary.mergeStatus].

Sie können mehrere Branches gleichzeitig auswählen, etwa um sie gemeinsam zu archivieren oder zu löschen.

## Mit Branches arbeiten {#actions}

Ein Rechtsklick auf einen Branch öffnet dasselbe Menü wie in der Seitenleiste. Sind mehrere Branches ausgewählt, gilt das Menü für alle.

Wenn ein Branch mit der Basis in Konflikt stünde, enthält sein Menü außerdem :ui[review.resolveConflicts]. Spooky checkt den Branch aus und führt die Basis in ihn zusammen. Dann lösen Sie die Konflikte auf dem Branch. Siehe [Konflikte lösen](/guide/work/conflicts/).

Um Branches zu löschen, wählen Sie sie aus und drücken Sie <kbd>⌘⌫</kbd>, oder streichen Sie auf einer Zeile nach links und klicken Sie auf :ui[review.delete]. Spooky fragt zuerst nach, wie in der Seitenleiste.

## Archivierungsvorschläge {#archive-suggestions}

Spooky schlägt vor, einen lokalen Branch zu [archivieren](/guide/branches/branches/#archive), wenn:

- er veraltet ist oder
- sein Pull Request oder Merge Request zusammengeführt wurde und der Branch seitdem keine neuen Commits hat.

Angeheftete und archivierte Branches werden nie vorgeschlagen. Ebenso wenig `main`, `master`, `trunk`, `dev`, `develop`, `next` und Branches, die Eltern-Branch eines anderen sind.

Wenn es Vorschläge gibt und das automatische Archivieren deaktiviert ist, erscheint unten in der Seitenleiste eine Taste mit der Anzahl der Branches. Klicken Sie darauf, um :ui[review.archive.title] zu öffnen:

1. Wählen Sie die Branches aus, die archiviert werden sollen, oder wählen Sie :ui[menu.selectAll]. Anfangs ist nichts ausgewählt. Bei jedem Branch steht, warum er vorgeschlagen wird: :ui[pr.archive.merged] oder :ui[review.filter.stale].
2. Klicken Sie auf :ui[review.archive.submit].

::screenshot[Das Dialogfenster zum Archivieren von Branches listet drei Branches auf, jeder als veraltet markiert, einer ist ausgewählt. Unten befindet sich der Schalter zum automatischen Archivieren von Branches.]{name="branches-archive" frame="dialog"}

Danach sagt ein Hinweis unten in der Seitenleiste, wie viele Branches archiviert wurden, mit einer Taste :ui[review.archived.undo]. <kbd>⌘Z</kbd> funktioniert ebenfalls. :ui[activity.title] hält fest, warum jeder Branch archiviert wurde.

## Automatisch archivieren {#auto-archive}

Spooky kann einmal am Tag nach Branches zum Archivieren suchen. Jede dieser Optionen aktiviert das. Es ist immer dieselbe Einstellung:

- :ui[review.archive.auto] im Dialogfenster :ui[review.archive.title]
- :ui[sidebar.autoArchive] in den Darstellungsoptionen der Seitenleiste
- :ui[settings.autoArchive] unter :ui[app.name > settings.title] › :ui[settings.general] (siehe [Vorgänge](/guide/settings/general/#operations))

Anfangs ist es deaktiviert.

Einmal am Tag sucht Spooky für jedes Repository nach Vorschlägen, während Sie in dessen Fenster arbeiten. Wenn es welche gibt, öffnet es dasselbe Dialogfenster. Dort wählen Sie die Branches aus, die archiviert werden sollen. Ob Sie welche archivieren oder nicht, es prüft einen Tag später erneut.

Um einen Branch davon auszunehmen, klicken Sie mit der rechten Maustaste darauf und aktivieren Sie :ui[review.skipAutoArchive] unter dem Archivieren-Eintrag im Menü.

Wenn Branches auf diese Weise archiviert werden:

- Eine Mitteilung meldet :ui[review.archived.notification]. Der Eintrag in :ui[activity.title] heißt :ui[review.autoArchive].
- Ein Punkt neben :ui[sidebar.archived] in der Seitenleiste kennzeichnet Branches, die Sie noch nicht angesehen haben. Klicken Sie auf einen davon, und seine Markierung verschwindet nach einem Moment. Um alle zu entfernen, klicken Sie mit der rechten Maustaste auf :ui[sidebar.archived] und wählen Sie :ui[sidebar.markAllReviewed].

## Siehe auch

- [Branches](/guide/branches/branches/)
- [Zusammenführen und Rebase](/guide/branches/merge-rebase/)
- [Pull Requests und Merge Requests](/guide/hosting/pull-requests/)
- [Hosting-Accounts](/guide/hosting/accounts/)
