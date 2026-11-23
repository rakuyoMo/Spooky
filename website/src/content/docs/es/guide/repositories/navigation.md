---
title: "Ventanas y navegación"
description: "Trabaja con ventanas y pestañas, ve atrás y adelante, usa las acciones rápidas, restaura ventanas, usa el menú del Dock y abre enlaces spooky://."
---

Esta página trata de cómo moverte por Spooky. Verás cómo tener varios repositorios abiertos, pasar de una vista a otra, saltar a cualquier sitio con las acciones rápidas y volver a donde lo dejaste.

## Ventanas y pestañas {#windows}

Cada ventana o pestaña muestra la vista Repositorios o un repositorio.

- :ui[menu.file > menu.newTab] (<kbd>⌘T</kbd>) abre una pestaña nueva con la vista Repositorios. El botón de añadir, al final de la barra de pestañas, hace lo mismo.
- :ui[menu.file > menu.newWindow] (<kbd>⌘N</kbd>) abre una ventana nueva con la vista Repositorios.
- :ui[menu.view > menu.showRepositories] (<kbd>⌃⌘R</kbd>) muestra la vista Repositorios en la ventana actual.

Si un repositorio ya está abierto, al abrirlo de nuevo se pasa a la ventana que lo muestra. Para abrirlo de todos modos en una segunda ventana, haz clic derecho en él en la lista Repositorios y selecciona :ui[bookmarks.openNewWindow]{1="driftwood"}.

### Cambiar de vista {#views}

El menú :ui[menu.view] cambia entre las vistas del repositorio:

| Atajo | Ítem del menú |
|---|---|
| <kbd>⌘1</kbd> | :ui[menu.showWorkingCopy] |
| <kbd>⌘2</kbd> | :ui[menu.showHistory] |
| <kbd>⌘3</kbd> | :ui[stash.show] |
| <kbd>⌘4</kbd> | :ui[pr.show.menu] |
| <kbd>⌘5</kbd> | :ui[review.show] |
| <kbd>⌘6</kbd> | :ui[reflog.show] |
| <kbd>⌘0</kbd> | :ui[history.showHead] |

:ui[menu.window > activity.title] (<kbd>⌃⌘0</kbd>) abre la ventana Actividad. Muestra lo que Spooky ha ejecutado y está ejecutando. Consulta [Cola de operaciones y actividad](/guide/advanced/queue-activity/).

## Ir atrás y adelante {#back-forward}

Cada ventana recuerda las vistas y los repositorios que has visitado, incluida la vista Repositorios. Para volver sobre tus pasos:

- :ui[menu.view > navigation.back] (<kbd>⌘[</kbd>) o :ui[toolbar.previous] en la barra de herramientas
- :ui[menu.view > navigation.forward] (<kbd>⌘]</kbd>) o :ui[toolbar.next] en la barra de herramientas

Si vas atrás y después abres algo nuevo, los lugares a los que podías ir hacia delante se descartan.

## Acciones rápidas {#quick-actions}

Las acciones rápidas te permiten encontrar algo escribiendo y actuar sobre ello sin soltar el teclado. Están disponibles mientras se muestra un repositorio. Selecciona :ui[menu.file > quickActions.menu] (<kbd>⇧⌘A</kbd>).

::screenshot[Las acciones rápidas abiertas sobre una ventana de repositorio, con “dark” escrito. El primer resultado, la rama feature/dark-mode, está seleccionado y muestra su acción predeterminada y la indicación para ver más acciones. Debajo están la rama remota origin/feature/dark-mode, la apariencia oscura, el tema predeterminado (oscuro) y dos commits cuyos mensajes mencionan dark.]{name="quick-actions" frame="window"}

Sin nada escrito, el panel muestra las vistas del repositorio y, después, las ramas (la actual primero), los worktrees, los remotos, los submódulos, las ramas remotas, las etiquetas, los stashes, los perfiles de usuario, y las apariencias y los temas. A medida que escribes, la lista se reduce. Spooky busca además:

- archivos de la rama actual cuyo nombre coincide
- un commit, cuando escribes de 5 a 64 caracteres hexadecimales de su hash
- commits de la rama actual cuyo mensaje contiene el texto, hasta 100

Los archivos y los commits aparecen al final de la lista un momento después de que dejes de escribir.

Usa estas teclas en el panel:

| Tecla | Qué hace |
|---|---|
| <kbd>↑</kbd> <kbd>↓</kbd> | Mueve la selección |
| <kbd>↩</kbd> | Ejecuta la acción predeterminada del ítem seleccionado |
| <kbd>Tab</kbd>, o <kbd>→</kbd> al final del texto | Muestra todas las acciones del ítem seleccionado |
| <kbd>←</kbd> sin texto, o <kbd>⇧Tab</kbd> | Vuelve desde la lista de acciones |
| <kbd>Esc</kbd> | Borra el texto; sin texto, vuelve desde la lista de acciones o cierra el panel |

Solo aparecen las acciones que puedes ejecutar en ese momento.

## Seguir donde lo dejaste {#restore}

:ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.windowRestoration] decide qué muestra Spooky al iniciarse:

| Opción | Cuando Spooky se inicia |
|---|---|
| :ui[settings.windowRestoration.always] | Vuelve a abrir tus ventanas y pestañas, cada una con el repositorio y la vista que mostraba al salir |
| :ui[settings.windowRestoration.never] | Muestra solo la ventana Repositorios |
| :ui[settings.windowRestoration.system] | Sigue el ajuste de macOS para conservar las ventanas al salir de una app. Es el valor predeterminado. |

Si un repositorio restaurado ya no se encuentra, su ventana indica que falta. Consulta [Repositorios que faltan](/guide/repositories/manager/#missing).

Activa :ui[settings.showLaunchWindow] para tener al inicio una ventana con tus repositorios recientes. Haz doble clic en uno, o selecciónalo y pulsa <kbd>↩</kbd>, para abrirlo. La ventana se cierra sola cuando una ventana de repositorio pasa al frente. Consulta ambos ajustes en [Ventanas y lista de repositorios](/guide/settings/general/#windows).

:::note[Repositorios de servidor]
Los repositorios de servidor restaurados vuelven a conectarse a sus servidores cuando Spooky se inicia.
:::

## Repositorios recientes y el Dock {#recent}

:ui[menu.file > menu.openRecent] muestra los repositorios que has abierto recientemente, en tu Mac y en servidores. :ui[menu.clearRecent], al final, vacía la lista. Tus marcadores de la ventana Repositorios se conservan.

Haz clic derecho en el icono de Spooky en el **Dock** para ver un menú con :ui[menu.newWindow] y tus repositorios recientes. Selecciona un repositorio para abrirlo. Funciona incluso cuando Spooky aún no está abierto.

También puedes soltar una carpeta sobre el icono de Spooky en el Dock para abrir el repositorio en el que está. Si la carpeta no está en un repositorio de Git, Spooky te ofrece crear uno.

## Abrir Spooky desde un enlace {#links}

Un enlace que empieza por `spooky://` abre un repositorio o un clon. Puedes poner estos enlaces en otras apps, en scripts o en notas.

### Abrir un repositorio {#link-open}

```
spooky://open?repository=<repository>&view=<view>
```

- `repository` es obligatorio. Es la ruta absoluta del repositorio en tu Mac, o `alias:path` para un repositorio de servidor, con codificación URL.
- `view` es opcional. Sin él, el repositorio se abre en la última vista que mostró.
- Dos formas abreviadas sustituyen a `view`: `branch=<name>` abre el historial de esa rama y `commit=<hash>` abre ese commit.

| `view` | Abre | Parámetros adicionales |
|---|---|---|
| `workingCopy` | La copia de trabajo | |
| `history` | El historial | `ref=<reference>`, un nombre de referencia completo como `refs/heads/main`; se puede repetir |
| `commit` | Un commit | `commit=<hash>` |
| `stashes` | Los stashes | |
| `reflog` | El reflog | |
| `pullRequests` | Las pull requests o merge requests | |
| `branchesReview` | La revisión de ramas | |
| `settings` | Los ajustes del repositorio | |
| `remote` | Un remoto | `remote=<name>` |
| `submodule` | Un submódulo | `path=<path>` |
| `worktree` | Un worktree | `path=<path>` |
| `fileHistory` | El historial de un archivo | `path=<path>` |
| `file` | Un archivo | `path=<path>` y, opcionalmente, `revision=<revision>` y `mode=blame` o `mode=raw` |

Por ejemplo, este enlace abre el historial de la rama `main` en el repositorio de `/Volumes/Projects/driftwood`:

```
spooky://open?repository=%2FVolumes%2FProjects%2Fdriftwood&branch=main
```

### Clonar un repositorio {#link-clone}

```
spooky://clone?url=<address>
```

Abre el diálogo de clonación con la dirección ya escrita. No se clona nada hasta que eliges dónde ponerlo y haces clic en :ui[clone.submit]. Consulta [Clonar un repositorio](/guide/repositories/manager/#clone).

Define :ui[app.name > settings.title] › :ui[settings.integration] › :ui[settings.github] como Spooky, y los enlaces de github.com que abren un repositorio en una app de escritorio abrirán también este diálogo de clonación. Consulta [Enlaces de github.com](/guide/settings/integration/#github-links).

Algunos enlaces no se pueden usar, por ejemplo uno que nombra una vista desconocida o da una ruta relativa. En esos casos, Spooky muestra :ui[link.invalid.title] y no hace nada más.

## Consulta también

- [Un recorrido por Spooky](/guide/start/tour/)
- [La ventana Repositorios](/guide/repositories/manager/)
- [Atajos de teclado](/reference/shortcuts/)
