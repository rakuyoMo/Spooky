---
title: "Git LFS"
description: "Git LFS aktivieren, Dateien und Muster verfolgen und LFS-Inhalte abrufen, pullen und pushen."
---

Git LFS hält große Dateien aus dem Verlauf des Repositorys heraus. Das Repository speichert für jede eine kleine Zeigerdatei. Der Inhalt kommt in einen LFS-Speicher auf dem Remote.

Spooky führt Git LFS auf dem Rechner aus, auf dem das Repository liegt.

## Was Sie brauchen {#requirements}

Git LFS 2.9.0 oder neuer, im `PATH`, den Git auf dem Rechner mit dem Repository verwendet.

Zum Prüfen klicken Sie in der Seitenleiste unter :ui[workspace.group] auf :ui[repositorySettings.title]. Der Abschnitt :ui[repositorySettings.lfs] zeigt die :ui[lfs.version] von Git LFS. Siehe [Git LFS, Ignorieren und Ausschließen](/guide/settings/identity/#repository-files).

Wird Git LFS nicht gefunden oder ist es zu alt, sagt dort ein Hinweis, wie Sie das beheben:

- **Auf Ihrem Mac**: Installieren oder aktualisieren Sie Git LFS. Ist es installiert, wird aber nicht gefunden, öffnen Sie :ui[app.name > settings.title] › :ui[settings.environment]. Aktivieren Sie :ui[settings.environment.loginShell] oder fügen Sie `PATH` als eigene Variable hinzu. Siehe [Variablen auf diesem Mac](/guide/settings/general/#local-variables).
- **Auf einem Server**: Installieren oder aktualisieren Sie Git LFS dort. Fügen Sie seinen Ordner zum `PATH` nicht interaktiver SSH-Sitzungen hinzu, zum Beispiel in `~/.zshenv`.

Solange Git LFS fehlt, sind die Tasten in diesem Abschnitt, die es brauchen, nicht verfügbar.

In einem Repository mit Git LFS können auch andere Vorgänge wie das Wechseln von Branches oder das Stagen aus demselben Grund fehlschlagen. Spooky zeigt dann :ui[hostError.lfsUnavailable] mit demselben Hinweis.

## Git LFS aktivieren {#enable}

Klicken Sie im Abschnitt :ui[repositorySettings.lfs] der Repository-Einstellungen auf :ui[lfs.enable]. Das richtet Git LFS nur für dieses Repository ein. Ihre globale Git-Konfiguration ändert sich nicht. Siehe [Git LFS, Ignorieren und Ausschließen](/guide/settings/identity/#repository-files).

Für Spooky verwendet ein Repository Git LFS, wenn in Git die Git-LFS-Filter eingerichtet sind und das Repository die Git-LFS-Hooks hat. Bis dahin bietet der Abschnitt nur :ui[lfs.enable] an. Auch die LFS-Menüeinträge sind nicht verfügbar.

Wenn Sie ein Repository klonen, das Git LFS verwendet, aktivieren Sie :ui[clone.lfs]. Siehe [Ein Repository klonen](/guide/repositories/manager/#clone).

Nachdem Sie Git LFS aktualisiert haben, wählen Sie :ui[menu.repository > lfs.menu > lfs.menu.update] in der Menüleiste, um die Git-LFS-Hooks des Repositorys zu aktualisieren.

## Dateien verfolgen {#track}

Dateien, die zu einem Verfolgungsmuster passen, werden mit Git LFS gespeichert. Die Muster stehen in `.gitattributes` im Wurzelverzeichnis des Repositorys. Alle, die das Repository verwenden, erhalten sie. Die Änderung an `.gitattributes` erscheint in der Arbeitskopie. Committen Sie sie wie andere Änderungen.

Um ein Muster hinzuzufügen, klicken Sie in den Repository-Einstellungen auf :ui[lfs.createPattern] oder wählen Sie :ui[menu.repository > lfs.menu > lfs.menu.track] in der Menüleiste. Geben Sie ein Muster wie `*.psd` ein und klicken Sie dann auf :ui[files.pattern.save].

::screenshot[Der Abschnitt Git LFS in den Einstellungen eines Repositorys. Er zeigt die installierte Version von Git LFS und zwei Verfolgungsmuster, *.psd und *.mp4. Die Zeile *.psd zeigt die Entfernen-Taste, die erscheint, wenn der Zeiger über einem Muster liegt.]{name="advanced-lfs-settings" frame="window" markers="34.5,24 88.5,35.6 48.8,34.4"}

1. Die installierte Version von Git LFS
2. Die Taste, die ein Muster entfernt
3. :ui[lfs.createPattern]

Sie können auch in der Arbeitskopie mit der rechten Maustaste auf Dateien klicken und aus :ui[lfs.menu] wählen:

- :ui[lfs.trackFile]: nur die ausgewählten Dateien verfolgen, mit ihren genauen Pfaden. Bei mehreren Dateien nennt der Eintrag die Anzahl.
- :ui[lfs.trackType.single]{1="psd"}: alle Dateien mit derselben Erweiterung verfolgen. Bei mehreren Dateien heißt der Eintrag :ui[lfs.trackType]. Er umfasst jede ihrer Erweiterungen.
- :ui[lfs.createPattern.menu]: selbst ein Muster eingeben, ausgehend vom Pfad der ersten ausgewählten Datei.

Für einen Ordner ist nur :ui[lfs.createPattern.menu] verfügbar.

### Ein Muster nicht mehr verfolgen {#untrack}

Klicken Sie in den Repository-Einstellungen neben einem Muster auf :ui[lfs.remove] und bestätigen Sie. Das Muster wird aus `.gitattributes` entfernt. Dateien, die bereits mit Git LFS gespeichert sind, bleiben, wie sie sind.

Kann Git LFS ein Muster nicht entfernen, sagt Spooky, welche übrig sind. Entfernen Sie sie von Hand mit :ui[repositorySettings.openInEditor] neben :ui[repositorySettings.lfs.patterns]. Siehe [Git LFS, Ignorieren und Ausschließen](/guide/settings/identity/#repository-files).

## LFS-Inhalte abrufen, pullen und pushen {#transfer}

Ist Git LFS eingerichtet, lädt Git LFS-Inhalte normalerweise beim Auschecken von Dateien. Beim Pushen lädt es die Inhalte hoch. Um das selbst zu tun, wählen Sie aus :ui[menu.repository > lfs.menu] in der Menüleiste:

| Eintrag | Wirkung |
|---|---|
| :ui[lfs.menu.fetch] | Lädt die LFS-Inhalte, die der aktuelle Checkout braucht. Die Arbeitskopie ändert sich nicht. |
| :ui[lfs.menu.pull] | Lädt sie und ersetzt dann die Zeigerdateien in der Arbeitskopie durch die Inhalte. |
| :ui[lfs.menu.push] | Lädt die LFS-Inhalte aller lokalen Branches und Tags hoch, die das Remote noch nicht hat. |

Wählen Sie im Dialogfenster ein Remote. Vorausgewählt ist das Remote des Upstreams des aktuellen Branches, oder das erste Remote, wenn es keinen Upstream gibt. Der Fortschritt erscheint im [Aktivitätsbereich](/guide/advanced/queue-activity/#activity-area) unten in der Seitenleiste.

## Widerrufen {#undo}

Sie können das Aktivieren von Git LFS, das Hinzufügen eines Verfolgungsmusters und das Entfernen eines Musters widerrufen. Siehe [Widerrufen und Wiederherstellen](/guide/work/undo/).

Das Aktualisieren der Hooks lässt sich nicht widerrufen. Auch Vorgänge davor lassen sich dann nicht mehr widerrufen.

Das Abrufen, Pullen und Pushen von LFS-Inhalten wird nicht aufgezeichnet, genau wie das Abrufen, Pullen und Pushen im Repository. Vorgänge davor lassen sich weiterhin widerrufen.

:::note[Server-Repositorys]
Git LFS läuft auf dem Server. LFS-Inhalte gehen zwischen dem Server und dem Remote hin und her. Ihr Mac braucht für ein Server-Repository kein Git LFS.
:::

## Siehe auch

- [Systemanforderungen](/reference/requirements/#optional)
- [Submodule](/guide/advanced/submodules/)
- [Das Fenster „Repositorys“](/guide/repositories/manager/)
