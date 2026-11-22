---
title: "Hosting-Accounts"
description: "Accounts von GitHub, GitLab.com und selbst betriebenem GitLab verbinden und erfahren, wo ihre Token gesichert sind und wofür sie verwendet werden."
---

Fügen Sie Ihren GitHub- oder GitLab-Account hinzu, um in Spooky mit Pull Requests und Merge Requests zu arbeiten. Git verwendet den Account auch, um sich bei HTTPS-Remotes dieses Dienstes anzumelden, sodass Sie nicht nach Benutzername und Passwort gefragt werden.

## Einen Account hinzufügen {#add}

Öffnen Sie :ui[app.name > settings.title] und klicken Sie auf :ui[settings.accounts]. Klicken Sie unter der Liste auf die Hinzufügen-Taste und wählen Sie, wo der Account liegt:

| Wählen Sie | Für | Anmeldung mit |
|---|---|---|
| :ui[accounts.add.github] | github.com | Ihrem Browser oder einem persönlichen Zugriffstoken |
| :ui[accounts.add.gitlab] | GitLab.com | Einem persönlichen Zugriffstoken |
| :ui[accounts.add.gitlabSelfManaged] | GitLab auf Ihrem eigenen Server | Einem persönlichen Zugriffstoken oder Benutzername und Passwort |

::screenshot[Das Dialogfenster zum Hinzufügen eines selbst betriebenen GitLab-Accounts. Der Host ist https://gitlab.example.com, und die Authentifizierungsmethode ist Benutzername und Passwort.]{name="hosting-add-account" frame="dialog" markers="79.2,64.1 83.3,56.4"}

1. Der Host
2. Die Authentifizierungsmethode

Während Spooky den Account prüft, steht unten im Dialogfenster :ui[accounts.validating]. :ui[action.cancel] beendet die Prüfung und lässt das Dialogfenster geöffnet, sodass Sie Ihre Eingaben korrigieren können. Wenn die Prüfung fehlschlägt, nennt eine Meldung den Grund, und Ihre Eingaben bleiben erhalten.

Jeder Account erscheint in der Liste mit Dienst, Instanz und Benutzername. Sie können mehrere Accounts desselben Dienstes hinzufügen.

### GitHub {#github}

Wenn neben :ui[accounts.authentication] die Option :ui[accounts.authentication.oauth] gewählt ist, klicken Sie auf :ui[accounts.add.submit]:

1. Spooky zeigt einen Einmalcode, kopiert ihn und öffnet GitHub in Ihrem Browser.
2. Setzen Sie den Code dort ein und autorisieren Sie Spooky. Wenn Sie inzwischen etwas anderes kopiert haben, klicken Sie auf :ui[accounts.copyCode], um ihn erneut zu kopieren.
3. Sobald Sie Spooky autorisiert haben, schließt sich das Dialogfenster, und der Account steht in der Liste.

Wenn der Code abläuft oder Sie den Zugriff im Browser ablehnen, beginnen Sie von vorn, um einen neuen Code zu erhalten.

Um stattdessen ein Token zu verwenden, wählen Sie neben :ui[accounts.authentication] die Option :ui[accounts.authentication.token]. Das Token braucht die Scopes `repo` und `read:org`.

### GitLab.com {#gitlab-com}

Setzen Sie ein persönliches Zugriffstoken mit dem Scope `api` ein.

### Selbst betriebenes GitLab {#self-managed}

Geben Sie neben :ui[accounts.host] die Adresse Ihres GitLab-Servers ein. Geben Sie Port und Pfad mit an, falls vorhanden, zum Beispiel `https://example.com:8443/gitlab`. Wählen Sie dann die Art der Anmeldung:

- :ui[accounts.authentication.token]: ein Token mit dem Scope `api`.
- :ui[accounts.authentication.password]: Spooky verwendet das Passwort nur, um ein Token zu erhalten, und sichert das Passwort nicht.

Die Anmeldung mit Benutzername und Passwort funktioniert nur, wenn alles Folgende zutrifft:

- Auf dem Server läuft GitLab 18.11 oder älter. GitLab 19.0 und neuer tauschen kein Passwort mehr gegen ein Token.
- Der Server verlangt keine Zugangsdaten einer OAuth-Anwendung. GitLab 13.9 verlangt sie immer, und GitLab 17.8 oder neuer lässt sich so einstellen.
- Der Server erlaubt Git über HTTPS mit Passwort.
- Ihr Account hat ein GitLab- oder LDAP-Passwort, verwendet keine Zwei-Faktor-Authentifizierung und meldet sich nicht ausschließlich über Single Sign-on an.

Das so erhaltene Token läuft ab, und Spooky erneuert es selbstständig. Wenn GitLab es nicht mehr erneuert, wird der Account so markiert, dass er erneut authentifiziert werden muss.

Spooky braucht GitLab 9.0 oder neuer. Der Server muss von Ihrem Mac aus erreichbar sein, und Ihr Mac muss seinem Zertifikat vertrauen. Wenn nicht, vertrauen Sie dem Zertifikat in der **Schlüsselbundverwaltung**.

## Accounts verwalten {#manage}

Alle Fenster teilen sich dieselben Accounts. Unter :ui[app.name > settings.title] › :ui[settings.accounts]:

- Um einen Account erneut zu authentifizieren, wählen Sie ihn aus und klicken Sie unter der Liste auf :ui[accounts.reauthenticate]. Melden Sie sich erneut an oder geben Sie ein neues Token ein. Es muss derselbe Benutzer sein. Um sich als jemand anderes anzumelden, fügen Sie einen neuen Account hinzu.
- Um einen Account zu entfernen, wählen Sie ihn aus, klicken Sie unter der Liste auf die Entfernen-Taste und bestätigen Sie. Spooky löscht sein Token aus Ihrem Schlüsselbund.

Ein Account mit dem Vermerk :ui[accounts.needsReauthentication] hat ein Token, das der Dienst nicht mehr akzeptiert, etwa weil es abgelaufen ist oder widerrufen wurde. Authentifizieren Sie ihn erneut, um ihn wieder zu verwenden.

Spooky übernimmt die Änderung sofort. Eine geöffnete Liste der Pull Requests oder Merge Requests wird neu geladen, ohne dass Sie das Fenster erneut öffnen müssen.

## Wofür Accounts verwendet werden {#uses}

Ein Account arbeitet mit den Remotes seines Dienstes:

- Die Liste der [Pull Requests und Merge Requests](/guide/hosting/pull-requests/)
- Issue-Nummern nach `#` in Commit-Nachrichten. Siehe [Automatische Vervollständigung](/guide/work/commit/#autocomplete).
- Der Status von Pull Requests und Merge Requests in der [Branch-Übersicht](/guide/branches/review/)
- [Ein Repository veröffentlichen](#publish) beim Dienst
- [Bei HTTPS-Remotes anmelden](#git)

## Welchen Account ein Remote verwendet {#remotes}

Spooky vergleicht die Adresse jedes Remotes mit der Instanz jedes Accounts: github.com, GitLab.com oder Ihr eigener GitLab-Server.

- **Ein Account auf dieser Instanz**: Spooky verwendet ihn.
- **Mehrere Accounts auf dieser Instanz**: Die Liste der Pull Requests bittet Sie, einen zu wählen. Spooky merkt sich Ihre Auswahl für dieses Remote.
- **Noch kein Account**: Bei github.com und GitLab.com weist die Liste darauf hin und bietet :ui[pullRequests.openAccounts] an.
- **Die Adresse passt nicht**: zum Beispiel, wenn das Remote einen Host-Alias aus `~/.ssh/config` verwendet. Die Liste zeigt einen Hinweis mit einer Taste :ui[pullRequests.associate]. Wenn das Remote zu einem Ihrer Accounts gehört, klicken Sie darauf und wählen Sie den Account und das Projekt.

HTTPS- und SSH-Adressen desselben Projekts passen zum selben Account.

## Bei HTTPS-Remotes anmelden {#git}

Wenn ein HTTPS-Remote zu einem Ihrer Accounts gehört, meldet sich Git mit dem Token des Accounts an. Das gilt für Klonen, Abrufen, Pullen, Pushen und das automatische Abrufen.

- SSH-Remotes verwenden weiterhin Ihre SSH-Schlüssel. Accounts ändern daran nichts.
- Bei diesen Adressen antwortet Spooky anstelle eines Credential Helpers, den Sie für Git eingerichtet haben, etwa des Schlüsselbund-Helpers von macOS. Diese Helper sehen und sichern das Token nicht.
- Wenn Sie mehrere Accounts auf derselben Instanz haben und für das Remote keinen gewählt haben, fragt Git Sie wie gewohnt nach Benutzername und Passwort.

Wenn Git das Token ablehnt, schlägt dieser Befehl fehl. Danach fragt Git Sie bei den Remotes dieses Accounts nach Benutzername und Passwort, und das Dialogfenster sagt, dass das Token des Accounts nicht akzeptiert wurde. Authentifizieren Sie den Account erneut, um sich wieder damit anzumelden.

:::note[Server-Repositorys]
Auch Git auf dem Server meldet sich mit dem Token an. Es erhält das Token jedes Mal, wenn es gebraucht wird, von Spooky auf Ihrem Mac. Das Token wird nicht auf dem Server gesichert.
:::

## Wo Token gesichert werden {#storage}

- Die Liste der Accounts liegt in den Einstellungen von Spooky, ohne die Token.
- Die Token liegen in Ihrem Schlüsselbund, in Einträgen mit dem Namen `com.rakuyo.spooky.hosting.<address>`.
- Wenn Sie sich bei einem selbst betriebenen GitLab mit Benutzername und Passwort anmelden, behält Spooky die Token, die es dafür erhält. Das Passwort behält es nicht.

Token gelangen weder in die Einträge unter :ui[activity.title] noch in die Protokolle von Spooky.

## Wohin Anfragen gehen {#network}

Spooky kommuniziert von Ihrem Mac aus mit dem Dienst, auch bei Server-Repositorys:

- GitHub: `github.com`, während Sie im Browser autorisieren, und `api.github.com` für alles andere.
- GitLab: `gitlab.com` oder die Adresse Ihres eigenen GitLab.

Das geschieht, wenn Sie einen Account hinzufügen oder erneut authentifizieren und wenn Sie nutzen, wofür der Account da ist: die Liste der Pull Requests und Merge Requests und was Sie dort tun, Issue-Nummern nach `#`, den Status in der Branch-Übersicht und das Veröffentlichen eines Repositorys. Accounts, die mit Benutzername und Passwort angemeldet wurden, erneuern dort auch ihre Token.

Jede dieser Anfragen erscheint auf der Seite :ui[activity.service] des Fensters :ui[activity.title].

Bilder von GitHub- und GitLab-Benutzern kommen von den Adressen, die diese Dienste angeben. Geladene Bilder bleiben nur im Arbeitsspeicher und sind weg, wenn Sie Spooky beenden.

Git selbst verbindet sich von dort mit dem Remote, wo das Repository liegt. Bei einem Server-Repository ist das der Server. Siehe [Daten und Datenschutz](/reference/data-privacy/#network).

## Ein Repository veröffentlichen {#publish}

Um aus dem geöffneten Repository ein Repository auf GitHub oder GitLab zu erstellen, wählen Sie :ui[menu.repository > publish.menu] in der Menüleiste. Sie können auch in der Seitenleiste mit der rechten Maustaste auf :ui[workspace.title] klicken und :ui[workspace.publishMenu] aus dem Menü wählen. Wenn das Repository noch kein Remote hat, öffnet auch :ui[sync.push] dieses Dialogfenster. Sie brauchen mindestens einen Account.

| Feld | Was es bewirkt |
|---|---|
| :ui[publish.remote] | Der Name des neuen Remotes. Anfangs `origin`, oder `origin-2`, wenn das Repository bereits ein `origin` hat. |
| :ui[pullRequests.account] | Wo das Repository erstellt wird: unter Ihrem eigenen Benutzer oder in einer Organisation oder Gruppe, der Sie angehören |
| :ui[publish.name] | Der Name beim Dienst. Anfangs der Name des Repository-Ordners. |
| :ui[pullRequests.description] | Optional |
| :ui[publish.visibility] | :ui[publish.visibility.private] oder :ui[publish.visibility.public]. GitLab hat außerdem :ui[publish.visibility.internal]. |
| :ui[publish.target] | Die HTTPS-Adresse, die das Remote verwenden wird |

Wenn Sie auf :ui[publish.submit] klicken, macht Spooky Folgendes:

1. Es erstellt ein leeres Repository beim Dienst.
2. Es fügt es als Remote hinzu, mit der HTTPS-Adresse.
3. Es pusht alle lokalen Branches und Tags dorthin. Branches ohne Upstream verfolgen ab jetzt ihren neuen Remote-Branch. Branches, die bereits einen haben, behalten ihn.

Wenn bereits ein Repository mit diesem Namen existiert, weist Spooky darauf hin und überschreibt es nicht. Wählen Sie einen anderen Namen. Wenn der Push fehlschlägt, bleiben das neue Remote und das Repository beim Dienst beide bestehen, sodass Sie erneut pushen können.

Das Veröffentlichen lässt sich nicht mit <kbd>⌘Z</kbd> widerrufen, und auch frühere Vorgänge lassen sich danach nicht mehr widerrufen.

## Siehe auch

- [Pull Requests und Merge Requests](/guide/hosting/pull-requests/)
- [Abfragen von Passwort und Passphrase](/guide/server/connection/#prompts)
- [Daten und Datenschutz](/reference/data-privacy/)
