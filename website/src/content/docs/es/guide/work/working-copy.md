---
title: "Copia de trabajo"
description: "Lee el estado de los archivos modificados, muéstralos en lista o en árbol, ordénalos y búscalos, gestiona los archivos sin seguimiento e ignorados, y usa las acciones de archivo y Vista Rápida."
---

La copia de trabajo muestra lo que has cambiado desde el último commit. Aquí eliges los cambios del próximo commit, examinas los archivos y evitas que Git siga archivos que no debería.

Para abrirla, haz clic en :ui[workspace.title] en la parte superior de la barra lateral, o selecciona :ui[menu.view > menu.showWorkingCopy] (<kbd>⌘1</kbd>). El área de commit está en la parte superior de la columna central, y debajo aparecen los archivos modificados. [Hacer commit de los cambios](/guide/work/commit/) explica el área de commit.

## Leer el estado {#status}

Cada archivo modificado tiene una fila con una casilla, dos indicadores de estado y su nombre.

- La casilla muestra si el cambio está en el stage. Un guion significa que solo una parte del archivo está en el stage.
- El indicador izquierdo es el cambio que está en el stage. El derecho es el cambio que aún está fuera del stage.
- Las letras son los códigos de estado de Git: M de modificado, A de añadido, D de eliminado y R de renombrado. Un archivo nuevo que Git aún no sigue muestra ?, y un archivo ignorado muestra !.
- Un archivo con un conflicto muestra dos códigos de conflicto, como U U. Consulta [Resolver conflictos](/guide/work/conflicts/).

Deja el puntero sobre los indicadores para ver el estado con palabras.

La línea que hay sobre la lista muestra la rama actual, seguida de la rama remota a la que sigue. Si no sigue ninguna, la línea dice :ui[branch.noTracking].

Spooky actualiza la lista por su cuenta cuando cambian los archivos. Para volver a leerlo todo, haz clic en :ui[action.refresh] o pulsa <kbd>⌘R</kbd>.

:::note[Repositorios de servidor]
Spooky comprueba si hay cambios en el servidor cada 2 segundos mientras la ventana del repositorio está en primer plano, y cada 10 segundos en caso contrario. Cuando el servidor tarda en responder, lo comprueba con menos frecuencia. Un cambio hecho en el servidor puede tardar ese tiempo en aparecer. Consulta [En qué se diferencian los repositorios de servidor](/guide/server/overview/#differences).
:::

## Mostrar una lista o un árbol {#view}

El menú :ui[menu.view > files.statusMenu] cambia lo que muestra la lista. El botón del extremo derecho de la línea de la rama tiene las mismas opciones.

| Opción | Qué hace |
|---|---|
| :ui[working.list] (<kbd>⌃⌘L</kbd>) | Una fila por archivo, con su ruta completa |
| :ui[working.tree] (<kbd>⌃⌘T</kbd>) | Archivos agrupados en sus carpetas. Haz doble clic en una carpeta para expandirla o contraerla. |
| :ui[files.showNonModified] (<kbd>⌃⌘M</kbd>) | Muestra todos los archivos del repositorio, no solo los modificados. Disponible en el árbol. |
| :ui[files.showIgnored] (<kbd>⌃⌘I</kbd>) | Muestra los archivos que Git ignora |
| :ui[files.showAssumeUnchanged] | Muestra los archivos marcados como assume-unchanged. Consulta [Archivos sin seguimiento e ignorados](#untracked-ignored). |

Cada repositorio recuerda si muestra una lista o un árbol. Un repositorio empieza como lista. Las demás opciones se aplican a todos los repositorios.

## Ordenar {#sort}

Haz clic en la cabecera de la columna :ui[status.filename] o :ui[status.column] para ordenar por ella. Vuelve a hacer clic para invertir el orden. El orden es el mismo en todos los repositorios y ventanas.

El primer clic en :ui[status.column] pone primero los archivos que están en el stage. Después van los demás cambios, luego los archivos nuevos y, por último, los que no tienen cambios y los ignorados.

## Buscar un archivo {#search}

1. Pulsa <kbd>⌘F</kbd>, o haz clic en el campo de búsqueda de la barra de herramientas. Dice :ui[history.search.forFile].
2. Escribe parte de la ruta del archivo. Spooky sugiere archivos que contienen esas letras en el mismo orden.
3. Elige un archivo para mostrar solo esa ruta. La última sugerencia muestra todos los archivos cuya ruta contiene lo que has escrito.

Pulsa <kbd>Esc</kbd> para salir del campo de búsqueda. La lista sigue filtrada. Vacía el campo de búsqueda para volver a ver todos los archivos.

## Archivos sin seguimiento e ignorados {#untracked-ignored}

Un archivo nuevo está sin seguimiento hasta que lo añades al stage y haces commit. Los archivos sin seguimiento muestran ? y aparecen junto a los demás cambios. Para incluir uno en el próximo commit, añádelo al stage como cualquier otro cambio.

Algunos archivos nunca deberían entrar en un commit, como los resultados de compilación o las notas locales. Para que Git no los muestre, haz clic derecho en el archivo y elige una regla:

- :ui[files.ignore] añade la regla al archivo `.gitignore` de la raíz del repositorio. Haz commit de `.gitignore`, y la regla se aplica a todos los que usan el repositorio.
- :ui[files.exclude] añade la regla a `info/exclude` en la carpeta de Git. La regla solo se aplica a esta copia del repositorio y nunca entra en un commit.

Ambos submenús te permiten ignorar solo este ítem, todos los ítems con el mismo nombre, todos los ítems con la misma extensión o un patrón que escribas.

Las reglas de ignorado no se aplican a los archivos que Git ya sigue. Si ignoras un archivo con seguimiento, Spooky pregunta si también quieres dejar de seguirlo. Haz clic en :ui[files.untrack] para dejar de seguirlo, o en :ui[files.untrackIgnored.skip] para seguir haciéndolo. En ambos casos, el archivo se queda en tu carpeta.

Para dejar de seguir un archivo sin una regla de ignorado, haz clic derecho en él y selecciona :ui[files.untrack]. El próximo commit lo quita del repositorio, y el archivo se queda en tu carpeta.

:ui[files.mark > files.assumeUnchanged.set] indica a Git que deje fuera tus cambios locales en un archivo con seguimiento, por ejemplo un archivo de configuración que solo editas en tu Mac. El archivo desaparece de la lista. Para volver a verlo, activa :ui[files.showAssumeUnchanged] y selecciona :ui[files.mark > files.assumeUnchanged.unset].

## Acciones de archivo {#file-actions}

Haz clic derecho en un archivo para ver sus acciones. Si haces clic derecho en una fila de la selección, la acción se aplica a todos los archivos seleccionados. Fuera de la selección, solo se aplica a la fila en la que has hecho clic.

::screenshot[El menú contextual de src/readings.ts en la copia de trabajo. De arriba abajo, tiene opciones para abrir el archivo y copiar su ruta, Vista Rápida, añadirlo al stage y trasladarlo a la papelera, los conflictos, descartar y guardar en un stash, el blame y el historial del archivo, ignorarlo y comparar.]{name="work-file-menu" frame="closeup"}

| Para | Selecciona |
|---|---|
| Abrir el archivo | :ui[files.open], o una app de :ui[files.openWith]. También puedes hacer doble clic en el archivo. |
| Copiar su ruta | :ui[workspace.copyPathMenu] o :ui[working.copyRelative] |
| Mostrarlo en el Finder o en Terminal | :ui[action.revealFinder] o :ui[action.openTerminal] |
| Moverlo o renombrarlo | :ui[files.move.menu] |
| Trasladarlo a la papelera | :ui[files.trash], o pulsa <kbd>⌘⌫</kbd> |
| Desechar tus cambios | :ui[working.discard.menu] (consulta [Descartar cambios](/guide/work/diff/#discard)) |
| Guardarlo en un stash | Consulta [Guardar algunos archivos en un stash](/guide/work/stash/#partial). |
| Restaurar una versión anterior | :ui[files.revert.menu] |
| Ver su historial | :ui[quickActions.showFileHistory] o :ui[quickActions.showBlame] (consulta [Historial del archivo y blame](/guide/history/file-views/)) |
| Compararlo en otra app | :ui[externalTool.compare] (consulta [Comparar en otra app](/guide/work/diff/#external)) |

:ui[files.trash] no pregunta antes. Un archivo con seguimiento que trasladas a la papelera aparece como una eliminación en el stage. Para recuperarlo, selecciona :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

:::note[Repositorios de servidor]
:ui[files.trash] traslada los archivos a la papelera del servidor. Si el servidor no tiene papelera, la opción dice :ui[files.delete], y Spooky pregunta antes de eliminar los archivos definitivamente. La mayoría de las apps reciben una copia del archivo, y Spooky escribe tus cambios en el servidor cuando guardas. Consulta [Terminal y otras apps](/guide/server/local-location/#terminal).
:::

## Vista Rápida {#quick-look}

Para previsualizar un archivo sin abrir una app, haz clic derecho en él y selecciona :ui[files.quickLook.single]{1="README.md"}.

Si usas Vista Rápida a menudo, haz que la barra espaciadora la abra: selecciona :ui[app.name > settings.title] › :ui[settings.general] y pon :ui[files.spacebar] en :ui[files.spacebar.quickLook]. De forma predeterminada, la barra espaciadora añade los archivos seleccionados al stage o los quita de él. Consulta [Lista de archivos](/guide/settings/general/#file-list).

:::note[Repositorios de servidor]
Spooky descarga primero el archivo a una carpeta temporal de tu Mac. La carpeta se elimina cuando cierras el repositorio.
:::

## Ajustes de la lista de archivos {#settings}

Están en :ui[app.name > settings.title] › :ui[settings.general]:

| Ajuste | Opciones |
|---|---|
| :ui[files.doubleClick] | :ui[files.doubleClick.openFile] (predeterminado) o :ui[files.doubleClick.openDiff] |
| :ui[files.spacebar] | :ui[files.spacebar.toggleStaging] (predeterminado) o :ui[files.spacebar.quickLook] |
| :ui[files.fontSize] | :ui[files.fontSize.regular] o :ui[files.fontSize.medium] (predeterminado) |
| :ui[files.truncation] | :ui[files.truncation.beginning] (predeterminado) o :ui[files.truncation.middle] |

Consulta [Lista de archivos](/guide/settings/general/#file-list).

## Consulta también

- [Revisar y añadir cambios al stage](/guide/work/diff/)
- [Hacer commit de los cambios](/guide/work/commit/)
- [Historial del archivo y blame](/guide/history/file-views/)
