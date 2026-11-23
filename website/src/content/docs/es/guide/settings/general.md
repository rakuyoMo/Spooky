---
title: "General, actualizaciones y entorno"
description: "Oriéntate en la ventana Ajustes y define las opciones de las páginas General, Actualizaciones y Entorno."
---

Los ajustes se aplican a Spooky en conjunto. La mayoría surten efecto en cuanto los cambias. No hay botón Guardar.

## La ventana Ajustes {#window}

Selecciona :ui[app.name > settings.title] (<kbd>⌘,</kbd>). Las páginas están en la parte superior de la ventana, y el título muestra la página en la que estás.

| Página | Qué define | Se explica en |
|---|---|---|
| :ui[settings.general] | La clonación, las operaciones en segundo plano, las confirmaciones, el historial, la lista de archivos y las ventanas | [General](#general) |
| :ui[settings.appearance] | Claro u oscuro, y el icono de la app | [Apariencia y temas](/guide/settings/appearance/#appearance) |
| :ui[settings.gitConfig] | El programa de Git, tu identidad global de Git, la firma y las herramientas externas de diff y de fusión | [Perfiles de usuario y configuración de Git](/guide/settings/identity/#git-config) |
| :ui[settings.text] | El coloreado de sintaxis, los caracteres invisibles y el ancho de tabulación en los diffs y los archivos | [Apariencia y temas](/guide/settings/appearance/#text) |
| :ui[settings.editor] | Cómo se comprueba y se ajusta el mensaje del commit | [Apariencia y temas](/guide/settings/appearance/#editor) |
| :ui[settings.themes] | Los colores y el tipo de letra de los diffs y los archivos | [Apariencia y temas](/guide/settings/appearance/#themes) |
| :ui[settings.profiles] | Las identidades entre las que puedes cambiar al hacer commit | [Perfiles de usuario y configuración de Git](/guide/settings/identity/#profiles) |
| :ui[settings.accounts] | Las cuentas de GitHub y GitLab | [Cuentas de alojamiento](/guide/hosting/accounts/) |
| :ui[settings.sshHosts] | Los alias de host de tus servidores, guardados en `~/.ssh/config` | [Preparar SSH](/guide/server/prepare-ssh/#alias) |
| :ui[settings.integration] | Los enlaces de github.com, el agente SSH y los informes de fallos | [Integración](/guide/settings/integration/#integration-page) |
| :ui[settings.environment] | Las variables de entorno para el Git de este Mac, y una comprobación del entorno de un servidor | [Entorno](#environment) |
| :ui[settings.updates] | Cómo se actualiza Spooky | [Actualizaciones](#updates) |

Los ajustes de un solo repositorio, como su identidad y su firma, están en la ventana del repositorio. Consulta [Ajustes del repositorio](/guide/settings/identity/#repository).

## General {#general}

La página :ui[settings.general] es una lista larga. Las secciones siguientes la recorren de arriba abajo.

::screenshot[La página General de la ventana Ajustes, con la ubicación de los clones, la app de terminal, las opciones de operaciones y de confirmación, las opciones del historial y de los diffs, y las opciones de la lista de archivos.]{name="settings-general" frame="window"}

### Clonación y terminal {#cloning}

| Ajuste | Qué hace |
|---|---|
| :ui[settings.cloneDirectory] | Dónde sugiere el diálogo de clonación poner los repositorios nuevos. Al principio es tu carpeta de inicio. El menú muestra también `~/Development` si la tienes. Selecciona :ui[settings.cloneDirectory.select] para elegir otra carpeta. |
| :ui[settings.terminal] | La app que usa :ui[action.openTerminal]. Consulta [Terminal](/guide/settings/integration/#terminal). |

### Operaciones {#operations}

| Ajuste | Predeterminado | Qué hace |
|---|---|---|
| :ui[settings.autoFetch] | Cada 30 minutos | Cada cuánto hace fetch Spooky en segundo plano. Consulta [Hacer fetch automáticamente](/guide/branches/sync/#auto-fetch). |
| :ui[stash.offerAutoStash] | Activado | Cuando los cambios locales bloquean una operación, pregunta si quieres guardarlos antes en un stash. Consulta [Stash automático](/guide/work/stash/#auto-stash). |
| :ui[settings.autoUpdateSubmodules] | Desactivado | Actualiza, sin preguntar, los submódulos con checkout tras las operaciones que mueven sus punteros. Consulta [Actualizar después de otras operaciones](/guide/advanced/submodules/#auto-update). |
| :ui[branch.cleanNames] | Activado | Corrige para Git los nombres de ramas, etiquetas y remotos mientras escribes. Consulta [Crear una rama](/guide/branches/branches/#create). |
| :ui[settings.autoArchive] | Desactivado | Archiva las ramas que parecen terminadas. Consulta [Archivar automáticamente](/guide/branches/review/#auto-archive). |

### Confirmaciones {#confirmations}

Cada una de estas preguntas tiene :ui[dialog.doNotAskAgain]. Al seleccionarlo allí, se desactiva aquí el ajuste correspondiente. Vuelve a activar el ajuste para que la pregunta aparezca de nuevo. Los cuatro están activados al principio.

| Ajuste | Pregunta antes de |
|---|---|
| :ui[settings.warnDiscardingChunks] | Descartar fragmentos o líneas, en cualquier repositorio. Consulta [Descartar cambios](/guide/work/diff/#discard). |
| :ui[settings.warnDiscardingOnServer] | Descartar archivos enteros en un repositorio de servidor |
| :ui[settings.warnDeletingOnServer] | Eliminar archivos definitivamente en un servidor que no tiene papelera |
| :ui[settings.warnRestoringOnServer] | Restaurar archivos desde una revisión en un repositorio de servidor. Consulta [Restaurar un archivo desde una revisión](/guide/history/file-views/#restore). |

En un repositorio local, descartar archivos enteros siempre pregunta.

### Historial y diffs {#history}

| Ajuste | Predeterminado | Qué hace |
|---|---|---|
| :ui[history.pageSize] | 100 | Cuántos commits carga el historial cada vez: 100, 200, 500 o 1000 |
| :ui[settings.dateFormat] | Absoluto | Las fechas absolutas son cortas, como 26/10/26. Las fechas relativas dicen “Hoy” o “Ayer” para esos dos días y escriben las demás fechas completas. El menú muestra un ejemplo de cada una. |
| :ui[history.mergeDiff] | :ui[history.mergeDiff.firstParent] | Qué muestra el conjunto de cambios de un commit de fusión. Consulta [El conjunto de cambios](/guide/history/commit-details/#changeset). |
| :ui[working.diffThreshold] | 20.000 | Los diffs de más kilobytes que este valor preguntan antes de mostrarse. Selecciona un valor o escribe uno. Consulta [Leer un diff](/guide/work/diff/#read). |

El formato de fecha se aplica al historial, los stashes, el historial del archivo y el reflog.

### Lista de archivos {#file-list}

| Ajuste | Predeterminado | Qué hace |
|---|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] | O abre el archivo en tu herramienta de comparación |
| :ui[files.openSubmodules] | Activado | Al hacer doble clic en un submódulo, se abre en Spooky y no en otra app |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] | O muestra el archivo en Vista Rápida |
| :ui[files.fontSize] | :ui[files.fontSize.medium] | O :ui[files.fontSize.regular] |
| :ui[files.truncation] | :ui[files.truncation.beginning] | O acorta por el medio los nombres largos |

Consulta en [Ajustes de la lista de archivos](/guide/work/working-copy/#settings) cómo funcionan en la copia de trabajo.

### Ventanas y lista de repositorios {#windows}

| Ajuste | Predeterminado | Qué hace |
|---|---|---|
| :ui[settings.windowRestoration] | :ui[settings.windowRestoration.system] | Qué vuelve a abrir Spooky al iniciarse. Consulta [Seguir donde lo dejaste](/guide/repositories/navigation/#restore). |
| :ui[settings.showLaunchWindow] | Desactivado | Muestra una ventana con tus repositorios recientes cuando Spooky se inicia |
| :ui[settings.showWorktreesInRepositoryList] | Desactivado | Muestra los worktrees de cada repositorio en la lista Repositorios |
| :ui[settings.showHostAliasesInRepositoryList] | Activado | Muestra el alias de host de cada repositorio de servidor en la lista Repositorios |
| :ui[settings.showDeveloperMenu] | Desactivado | Añade el menú :ui[menu.developer], con herramientas para probar el propio Spooky |

## Actualizaciones {#updates}

La página :ui[settings.updates] define el canal de versiones, si Spooky busca actualizaciones y las descarga por su cuenta, y cada cuánto las busca. [Mantener Spooky actualizado](/guide/start/install/#updates) explica cada opción.

## Entorno {#environment}

Las apps abiertas desde el Finder o el Dock no reciben el entorno que tienes en Terminal. Por ejemplo, a `PATH` le pueden faltar carpetas como `/opt/homebrew/bin`. Entonces puede que no se encuentren los hooks de Git, los asistentes de credenciales o Git LFS. La página :ui[settings.environment] lo soluciona para el Git de este Mac.

### Variables en este Mac {#local-variables}

| Ajuste | Qué hace |
|---|---|
| :ui[settings.environment.loginShell] | Inicia una vez tu shell de inicio de sesión, lee las variables que definen sus archivos de inicio y se las pasa a Git. La tabla de debajo muestra lo que se ha leído. Activado al principio. |
| :ui[settings.environment.custom] | Las variables que añades tú. Haz clic en el botón de añadir para añadir una, y en el de eliminar para quitar la seleccionada. Tienen prioridad sobre las del shell de inicio de sesión. |

Algunas cosas que conviene saber:

- Los cambios se aplican al siguiente comando de Git. No hace falta reiniciar Spooky.
- El shell de inicio de sesión se lee de nuevo cada vez que Spooky se inicia. Si la lectura falla, la página te lo indica.
- Si dos variables personalizadas tienen el mismo nombre, gana la de más abajo. Una variable con un nombre no válido se queda en la tabla, pero no se pasa a Git.
- Para usar un agente SSH distinto del del sistema, define `SSH_AUTH_SOCK` aquí o en tu shell de inicio de sesión. Consulta [Agente SSH](/guide/settings/integration/#ssh-agent).

:::note[Repositorios de servidor]
Estas variables solo se aplican al Git de este Mac. El Git de un servidor usa el entorno del propio servidor.
:::

### Comprobar un servidor {#server-check}

En la parte inferior de la página puedes ver el entorno que recibe Git en un servidor, sin añadir un repositorio:

1. Escribe un alias de host en el campo :ui[remote.host]. También puedes elegir uno en el menú :ui[settings.environment.server.hosts]. Muestra los servidores de tus repositorios de servidor.
2. Haz clic en :ui[settings.environment.server.check].

::screenshot[La comprobación de un servidor, en la parte inferior de la página Entorno de Ajustes. Se ha comprobado un alias de host, y el resultado muestra el Git encontrado en el servidor con su versión.]{name="settings-environment" frame="closeup"}

El resultado muestra el Git que encuentran los inicios de sesión por SSH y su versión, o :ui[settings.environment.server.noGit]. Debajo aparecen cada carpeta de `PATH` y los nombres de las variables que empiezan por `GIT_`. Si no se encuentra Git, consulta [No se encuentra Git en el servidor](/reference/troubleshooting/#server-path).

## Consulta también

- [Apariencia y temas](/guide/settings/appearance/)
- [Perfiles de usuario y configuración de Git](/guide/settings/identity/)
- [Integración](/guide/settings/integration/)
- [Instalar Spooky](/guide/start/install/)
