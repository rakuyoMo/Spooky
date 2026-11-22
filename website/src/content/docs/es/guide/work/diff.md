---
title: "Revisar y añadir cambios al stage"
description: "Lee los cambios de un archivo, ajusta cómo se muestran los diffs y añade cambios al stage o descártalos por archivo, por fragmento o por línea."
---

Selecciona un archivo en la copia de trabajo, y la columna derecha muestra su diff: lo que ha cambiado, línea a línea. Desde ahí puedes añadir al stage solo las partes que corresponden al próximo commit y desechar el resto.

## Leer un diff {#read}

Un diff se divide en fragmentos. Un fragmento es un grupo de líneas modificadas con unas pocas líneas sin cambios alrededor. Su línea de cabecera indica dónde está el fragmento en el archivo.

- Las líneas añadidas son verdes, y las eliminadas, rojas. Las dos columnas de números de línea corresponden a la versión antigua y a la nueva del archivo.
- Cuando un archivo tiene cambios dentro y fuera del stage, cambia entre ellos con :ui[working.unstaged] y :ui[working.staged] en la parte superior de la columna. Un lado sin cambios aparece atenuado.
- La barra que hay bajo el diff muestra el número de fragmentos y cuántas líneas se han añadido y eliminado.
- Para una imagen, el diff muestra la imagen antigua y la nueva. :ui[diff.twoUp] las pone una junto a otra. :ui[diff.oneUp] muestra una cada vez, y cambias entre :ui[diff.old] y :ui[diff.new].

Un diff muy grande puede volver lenta la ventana, así que Spooky pregunta antes: :ui[working.largeDiff] Haz clic en :ui[working.showDiff] para verlo. El límite de tamaño es :ui[working.diffThreshold] en :ui[app.name > settings.title] › :ui[settings.general]. El valor predeterminado es de 20.000 kB. Consulta [Historial y diffs](/guide/settings/general/#history).

## Opciones del diff {#options}

La barra que hay bajo el diff tiene las opciones que cambias más a menudo:

- En su extremo izquierdo hay dos botones. Deja el puntero sobre ellos para ver sus nombres.
  - :ui[diff.ignoreWhitespace] deja fuera los cambios que solo afectan a espacios y tabulaciones. Si no ha cambiado nada más en el archivo, el diff dice :ui[diff.onlyWhitespace]
  - :ui[diff.showEntireFile] muestra el archivo entero con los cambios en su sitio. Solo se aplica al diff que estás viendo.
- En su extremo derecho, :ui[diff.context] define cuántas líneas sin cambios aparecen alrededor de cada cambio. El valor predeterminado es 3. También puedes elegirlo en :ui[menu.view > diff.contextMenu].

Los ajustes de espacios en blanco y de contexto se aplican en todas partes: en todos los repositorios, en la copia de trabajo y en el historial.

Hay más opciones en :ui[app.name > settings.title] › :ui[settings.text]:

| Ajuste | Qué hace |
|---|---|
| :ui[text.enableSyntaxColoring] | Colorea el código según su lenguaje. Activado de forma predeterminada. |
| :ui[text.syntaxColoringInDiffs] | Usa también los colores de sintaxis en los diffs. Desactivado de forma predeterminada. |
| :ui[text.showInvisibles] | Muestra los espacios, tabulaciones y finales de línea como símbolos |
| :ui[text.tabWidth] | El ancho de una tabulación, en espacios |

[Texto](/guide/settings/appearance/#text) explica más sobre estos ajustes. Los colores vienen del tema. Consulta [Temas](/guide/settings/appearance/#themes).

## Añadir archivos enteros al stage {#stage-file}

Añadir al stage es elegir los cambios que entran en el próximo commit. Para añadir archivos enteros al stage, haz una de estas cosas:

- Marca la casilla que hay delante del archivo. Si el archivo está seleccionado, se añaden al stage todos los archivos seleccionados.
- Selecciona archivos y pulsa <kbd>Espacio</kbd>. Si un archivo seleccionado tiene cambios fuera del stage, la barra espaciadora lo añade al stage. Si no, lo quita.
- Haz clic en :ui[working.stageAll] sobre la lista, o selecciona :ui[workspace.title > working.stageAllMenu] (<kbd>⇧⌘E</kbd>).

Para quitar del stage, desmarca la casilla, pulsa <kbd>Espacio</kbd> otra vez o selecciona :ui[workspace.title > working.unstageAllMenu] (<kbd>⌥⇧⌘E</kbd>). Cuando todo está en el stage, el botón :ui[working.stageAll] se convierte en :ui[working.unstageAll]. Mientras solo algunos cambios estén en el stage, mantén pulsada <kbd>⌥</kbd> para cambiarlo.

## Añadir fragmentos al stage {#chunks}

Cada fragmento tiene botones en el extremo derecho de su línea de cabecera:

- En el lado :ui[working.unstaged]: :ui[working.discardChunk] y :ui[working.stageChunk]
- En el lado :ui[working.staged]: :ui[working.unstageChunk]

El fragmento pasa al otro lado al instante. El resto del archivo se queda donde estaba.

## Añadir líneas al stage {#lines}

Cuando un fragmento mezcla cambios para commits distintos, añade al stage solo algunas de sus líneas.

1. Haz clic en el número de línea de una línea modificada para seleccionarla. Vuelve a hacer clic para anular la selección.
2. Para seleccionar más líneas, haz clic también en sus números. Arrastra sobre los números de línea para seleccionar una serie de líneas, o mantén pulsada <kbd>⇧</kbd> y haz clic para seleccionar todas las líneas intermedias.
3. Haz clic en :ui[working.stageLines] en la cabecera del fragmento.

::screenshot[Un fragmento del diff de src/readings.ts. Hay cinco líneas seleccionadas por sus números de línea, y la cabecera del fragmento muestra los botones Descartar líneas y Añadir líneas al stage.]{name="staging" frame="closeup"}

Solo se pueden seleccionar líneas modificadas. Cada fragmento tiene su propia selección, y sus botones actúan sobre las líneas seleccionadas en él. En el lado :ui[working.staged], el botón es :ui[working.unstageLines].

## Descartar cambios {#discard}

Descartar desecha los cambios que no quieres conservar.

- **Un archivo**: haz clic derecho en él y selecciona :ui[working.discard.menu] en el menú, o selecciona :ui[workspace.title > working.discardMenu] (<kbd>⇧⌘⌫</kbd>).
- **Todo**: selecciona :ui[workspace.title > working.discardAllMenu] en la barra de menús.
- **Un fragmento o algunas líneas**: haz clic en :ui[working.discardChunk] o :ui[working.discardLines] en la cabecera del fragmento.

Con los archivos, Spooky pregunta antes. Los archivos con seguimiento vuelven a como estaban en el último commit, incluidos los cambios del stage. Los archivos nuevos van a la papelera. Haz clic en :ui[working.discard] o :ui[working.discardAll.submit] para continuar.

Con los fragmentos y las líneas, Spooky pregunta :ui[working.discardContent.title] Marca :ui[dialog.doNotAskAgain] para saltarte la pregunta la próxima vez. Para recuperarla, activa :ui[settings.warnDiscardingChunks] en :ui[app.name > settings.title] › :ui[settings.general]. Consulta [Confirmaciones](/guide/settings/general/#confirmations).

:::caution
Los cambios descartados no están en ningún commit. La única forma de recuperarlos es :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>), y solo hasta que el repositorio vuelva a cambiar. Los archivos nuevos se recuperan de la papelera mientras sigan allí.
:::

:::note[Repositorios de servidor]
Descartar sobrescribe los archivos del servidor. Los archivos nuevos van a la papelera del servidor. Si el servidor no tiene papelera, se eliminan definitivamente. La pregunta tiene :ui[dialog.doNotAskAgain]. Para recuperarla, activa :ui[settings.warnDiscardingOnServer] en :ui[settings.general].
:::

## Comparar en otra app {#external}

Para ver un cambio en una app de comparación, como FileMerge o Kaleidoscope:

- Deja el puntero sobre el nombre del archivo en la parte superior de la columna derecha y haz clic en :ui[externalTool.action.diffTool]. Compara el lado que estás viendo.
- O haz clic derecho en el archivo y elige en el submenú :ui[externalTool.compare]: :ui[externalTool.compare.workingTreeToBase], :ui[externalTool.compare.workingTreeToIndex] o :ui[externalTool.compare.indexToBase].

La primera vez, Spooky pregunta qué app usar. Para cambiarla más adelante, usa :ui[externalTool.diffTool] en :ui[app.name > settings.title] › :ui[settings.gitConfig]. Spooky funciona con Araxis Merge, BBEdit, Beyond Compare, DeltaWalker, FileMerge, Kaleidoscope, P4Merge, TextMate y Visual Studio Code. Consulta [Herramientas de comparación y de fusión](/guide/settings/integration/#diff-merge-tools).

:::note[Repositorios de servidor]
La app de comparación recibe copias de los archivos en una carpeta temporal de tu Mac. La carpeta se elimina cuando cierras el repositorio.
:::

## Consulta también

- [Copia de trabajo](/guide/work/working-copy/)
- [Hacer commit de los cambios](/guide/work/commit/)
- [Deshacer y recuperar](/guide/work/undo/)
