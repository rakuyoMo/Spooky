---
title: "Historial del archivo y blame"
description: "Sigue un archivo a lo largo de su historial, mira quién cambió cada línea con el blame, consulta un archivo como estaba en una revisión y restáuralo desde esa revisión."
---

Estas vistas examinan un archivo cada vez: los commits que lo cambiaron, quién escribió cada línea y cómo era en cualquier momento del pasado.

## Historial del archivo {#file-history}

Para ver todos los commits que cambiaron un archivo:

- En la copia de trabajo, haz clic derecho en el archivo y selecciona :ui[fileHistory.showHistoryOf]{1="units.ts"}.
- O deja el puntero sobre el nombre del archivo en la parte superior de la columna derecha y haz clic en :ui[fileHistory.title].
- En los [detalles del commit](/guide/history/commit-details/#changeset), haz clic derecho en un archivo del conjunto de cambios o del árbol de archivos y selecciona la misma opción.

En la copia de trabajo, también puedes seleccionar una carpeta y hacer clic en :ui[fileHistory.title] en la parte superior de la columna derecha. El historial abarca entonces todos los archivos que contiene.

La columna izquierda muestra los commits, del más reciente al más antiguo, agrupados por mes. Arriba están el nombre del archivo y el número de commits. Haz clic en el nombre del archivo para cambiar a otro archivo.

Selecciona un commit para ver a la derecha lo que cambió en el archivo. Cambia a :ui[showFile.raw] para ver el archivo entero como estaba en ese commit, o vuelve a :ui[fileHistory.diff]. Deja el puntero sobre el hash corto de arriba para ver más:

- :ui[blame.title] muestra quién escribió cada línea en ese commit. Consulta [Blame](#blame).
- :ui[fileHistory.showCommit] abre el commit en los [detalles a página completa](/guide/history/commit-details/#full-page).
- :ui[externalTool.action.diffTool] abre el cambio en tu herramienta de comparación.

::screenshot[El historial del archivo src/units.ts. La columna izquierda muestra el nombre del archivo y el número de commits, con los commits que lo cambiaron agrupados por mes. A la derecha está lo que el commit seleccionado cambió en el archivo. El puntero está sobre el hash corto. Los botones Blame, Mostrar commit y Herramienta de comparación aparecen arriba a la derecha, junto al selector Diff y Original.]{name="history-file-history" frame="window" markers="28.5,9 94,13.25 78,13.25"}

1. El nombre del archivo y el número de commits
2. El selector entre :ui[fileHistory.diff] y :ui[showFile.raw]
3. Los botones que aparecen mientras el puntero está sobre el hash corto

Haz doble clic en un commit, o pulsa <kbd>Retorno</kbd>, para abrirlo también en los detalles a página completa. Haz clic derecho en un commit para ver las mismas acciones, además de restaurar y exportar el archivo en ese commit.

### Buscar en el historial del archivo {#file-history-search}

Escribe en el campo de búsqueda de la barra de herramientas para acotar la lista. Haz clic en la lupa del campo para elegir qué buscar: :ui[fileHistory.scope.message], :ui[fileHistory.scope.hash], :ui[fileHistory.scope.author] o :ui[fileHistory.scope.committer].

- Los mensajes, autores y committers coinciden con el texto que escribes, sin distinguir mayúsculas de minúsculas. Los autores y committers coinciden por nombre o por correo.
- Un hash de commit, una rama o una etiqueta muestran el commit más reciente hasta ese punto que cambió el archivo.

## Blame {#blame}

El blame muestra el archivo entero, con una columna a la derecha que indica qué commit cambió por última vez cada bloque de líneas. Cada bloque muestra el avatar del autor, la primera línea del mensaje del commit, el autor y cuánto tiempo hace.

- En la copia de trabajo, haz clic derecho en un archivo y selecciona :ui[blame.show]{1="units.ts"}. O deja el puntero sobre el nombre del archivo en la parte superior de la columna derecha y haz clic en :ui[blame.title].
- En el conjunto de cambios o el árbol de archivos de un commit, selecciona :ui[fileHistory.blameAt]{1="units.ts" 2="e2dda2bc"} para ver el archivo como estaba entonces.

::screenshot[El blame de src/units.ts. El archivo está a la izquierda. La columna de la derecha muestra el avatar, el mensaje, el autor y la antigüedad del commit que cambió por última vez cada bloque. Los bloques de Drop trailing zeros from temperatures están resaltados.]{name="history-blame" frame="window" markers="84,22 84,82.5"}

1. La columna que muestra qué commit cambió por última vez cada bloque
2. Los bloques resaltados del commit en el que has hecho clic

Haz clic en un bloque para ver un resumen de su commit. Todos los bloques de ese commit se resaltan. Haz doble clic en un bloque para abrir su commit en los detalles a página completa. Para hacer la columna más ancha o más estrecha, arrastra su borde izquierdo. Spooky recuerda la anchura.

El blame necesita un archivo del que ya se haya hecho commit. No puede mostrar archivos nuevos o sin seguimiento, archivos binarios ni submódulos.

## Ver un archivo en una revisión {#show-file}

Para leer un archivo como estaba en cualquier commit, sin cambiar tu copia de trabajo:

- En la copia de trabajo, haz clic derecho en un archivo y selecciona :ui[showFile.show]{1="units.ts"}. Muestra la versión de HEAD.
- En el conjunto de cambios o el árbol de archivos de un commit, selecciona :ui[fileHistory.showAt]{1="units.ts" 2="e2dda2bc"}.

La cabecera se lee como una ruta: revisión › archivo.

- Haz clic en la revisión para elegir otro commit. Haz doble clic en un commit de la lista para cambiar a él.
- Haz clic en el nombre del archivo para elegir otro archivo del mismo commit.
- :ui[showFile.raw] y :ui[blame.title] cambian entre el archivo sin más y el [blame](#blame).
- Deja el puntero sobre la cabecera para ver :ui[fileHistory.title] y :ui[fileHistory.showCommit].

Bajo la cabecera, Spooky cuenta las personas que han cambiado el archivo, con sus avatares. El texto usa tu tema y los ajustes de :ui[app.name > settings.title] › :ui[settings.text]. Consulta [Texto](/guide/settings/appearance/#text).

Como el blame, esta vista no puede mostrar archivos nuevos o sin seguimiento, archivos binarios ni submódulos.

## Restaurar un archivo desde una revisión {#restore}

Para dejar un archivo como estaba en un commit anterior:

1. Haz clic derecho en el commit en el historial del archivo y selecciona :ui[fileHistory.restoreAt]{1="units.ts" 2="e2dda2bc"} en el menú. En los [detalles del commit](/guide/history/commit-details/#changeset), la opción es :ui[fileHistory.restoreInWorkingCopy]{1="units.ts" 2="e2dda2bc"}.
2. Spooky pregunta antes. Haz clic en :ui[fileHistory.restore.submit].

Se sustituyen los cambios del archivo, tanto los que están en el stage como los que están fuera. Si el archivo no existía en ese commit, se elimina. No se hace ningún commit: el archivo restaurado aparece en la copia de trabajo como un cambio en el stage.

Para deshacerlo, selecciona :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

Puedes restaurar varios archivos o carpetas a la vez desde el conjunto de cambios o el árbol de archivos.

:::note[Repositorios de servidor]
El archivo se sobrescribe en el servidor. Marca :ui[dialog.doNotAskAgain] para saltarte la pregunta la próxima vez. Para que vuelva a preguntar, activa :ui[settings.warnRestoringOnServer] en :ui[app.name > settings.title] › :ui[settings.general]. Consulta [Confirmaciones](/guide/settings/general/#confirmations).
:::

## Consulta también

- [Detalles del commit](/guide/history/commit-details/)
- [Copia de trabajo](/guide/work/working-copy/)
- [Deshacer y recuperar](/guide/work/undo/)
