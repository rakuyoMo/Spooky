---
title: "Explorar el historial"
description: "Explora la lista y el gráfico de commits, lee las insignias de referencias, busca y filtra commits, y cambia las opciones de visualización."
---

La vista :ui[history.title] muestra los commits de un repositorio, del más reciente al más antiguo, junto a un gráfico de cómo se conectan. Selecciona un commit para ver sus detalles a la derecha.

::screenshot[La vista del historial de un repositorio. La cabecera que hay sobre la lista dice Todas las ramas, remotos y etiquetas, con el botón de opciones de visualización en su extremo derecho. Los commits están agrupados bajo noviembre de 2026. Unas líneas de colores a la izquierda conectan los commits, e insignias como HEAD, main y v0.4.0 aparecen junto a los nombres de los autores. A la derecha están los detalles del commit seleccionado, con los botones Cambios y Árbol arriba.]{name="history" frame="window" markers="50,13.75 42,23 22.5,62 81,9"}

1. La cabecera: lo que muestra la lista y las opciones de visualización
2. Insignias de las ramas y etiquetas que apuntan a un commit
3. El gráfico de commits
4. Detalles del commit seleccionado. Consulta [Detalles del commit](/guide/history/commit-details/).

## Abrir el historial {#open}

- :ui[menu.view > menu.showHistory] (<kbd>⌘2</kbd>), o :ui[history.title] en la barra lateral, muestra juntas todas las ramas, ramas remotas y etiquetas. La cabecera dice :ui[history.all].
- Haz clic en una rama, una etiqueta o una rama remota en la barra lateral para ver solo su historial. Haz clic en otras con <kbd>⌘</kbd> pulsada para verlas juntas.
- :ui[menu.view > history.showHead] (<kbd>⌘0</kbd>) muestra el historial de la rama en la que estás.

Cuando miras una rama local con un upstream, la cabecera muestra los dos, como en `main › origin/main`. La lista incluye entonces los commits del upstream de los que aún no has hecho pull.

## La lista de commits {#list}

Cada fila muestra el avatar y el nombre del autor, la fecha, el hash corto y la primera línea del mensaje. De forma predeterminada, los commits se agrupan por mes.

Cuando la lista muestra una rama local con un upstream:

- ↑ marca un commit del que no has hecho push.
- ↓ marca un commit del que no has hecho pull. Estas filas aparecen atenuadas.

Spooky carga los primeros 100 commits. Carga los 100 siguientes cuando te desplazas hasta el final. Para cargar más cada vez, cambia :ui[history.pageSize] en :ui[app.name > settings.title] › :ui[settings.general]. En la misma página, :ui[settings.dateFormat] define el aspecto de las fechas de la lista. Consulta [Historial y diffs](/guide/settings/general/#history).

Haz clic en un commit para seleccionarlo. Con <kbd>⇧</kbd> o <kbd>⌘</kbd> pulsada, el clic selecciona varios. <kbd>⌘C</kbd> copia los hashes completos de los commits seleccionados. Haz doble clic en un commit para abrir sus detalles a página completa.

Haz clic derecho en un commit para ver todo lo que puedes hacer con él. Si el commit no está seleccionado, el menú actúa solo sobre ese commit. Tu selección se queda como está.

## El gráfico de commits {#graph}

El gráfico de la izquierda dibuja cada commit como un punto, con líneas que bajan hasta sus padres. Un commit de fusión tiene más de una línea hacia abajo.

Para ocultarlo, desactiva :ui[history.showGraph] en las [opciones de visualización](#view-options) (<kbd>⌃⌘G</kbd>). :ui[history.firstParentOnly] sigue solo el primer padre de cada fusión. Los commits que entraron mediante una fusión se dejan fuera.

## Insignias de referencias {#badges}

Las insignias que hay junto al nombre del autor muestran qué apunta a un commit:

| Insignia | Apunta al commit |
|---|---|
| HEAD azul | El commit del que tienes hecho checkout |
| Azul | Una rama local |
| Gris | Una rama remota |
| Amarilla | Una etiqueta |
| Roja | Un stash |

La rama en la que estás va primero. Las insignias que no caben se contraen en “…”.

Haz clic en la insignia de una etiqueta para ver la firma de la etiqueta: la clave y si es válida, o :ui[signature.unsigned].

## Buscar y filtrar {#search}

1. Pulsa <kbd>⌘F</kbd>, o haz clic en el campo de búsqueda de la barra de herramientas.
2. Haz clic en la lupa del campo para elegir qué buscar: :ui[history.search.message], :ui[history.search.author], :ui[history.search.committer], :ui[history.search.file], :ui[history.search.hash], :ui[history.search.sinceDate] o :ui[history.search.untilDate].
3. Escribe. La lista muestra solo los commits que coinciden.

Mientras escribes, Spooky sugiere autores, committers y rutas de archivos. Al buscar en los mensajes, las sugerencias también te dejan cambiar a otro tipo de búsqueda. Si escribes una fecha, la primera sugerencia busca los commits desde esa fecha.

Cómo coincide cada tipo:

- Los mensajes, autores y committers coinciden como expresiones regulares, sin distinguir mayúsculas de minúsculas.
- Un archivo coincide con los commits que lo cambiaron. Una carpeta coincide con los commits que cambiaron algo dentro de ella.
- Un hash de commit necesita al menos los 4 primeros caracteres.

La búsqueda aparece como una línea bajo la cabecera. Para añadir otra condición, haz clic en el botón de añadir y elige su tipo en el menú del principio de la nueva línea. Para una fecha, elige :ui[history.search.after], :ui[history.search.before] o :ui[history.search.range]. Para quitar una condición, haz clic en su botón de eliminar.

Con varias condiciones:

- Las condiciones de tipos distintos deben cumplirse todas.
- De varias condiciones del mismo tipo, basta con que un commit cumpla una. Las fechas son la excepción: un commit debe cumplir todas las condiciones de fecha.

La búsqueda termina cuando cambias a otra vista.

## Opciones de visualización {#view-options}

Haz clic en el botón de opciones de visualización, en el extremo derecho de la cabecera, o selecciona :ui[menu.view > history.title]:

| Opción | Qué hace |
|---|---|
| :ui[history.showGraph] | Muestra el gráfico de commits. Activado de forma predeterminada. |
| :ui[history.firstParentOnly] | Sigue solo el primer padre de cada fusión |
| :ui[history.sortBy] | :ui[history.sort.topo] mantiene juntos los commits de cada línea de trabajo. :ui[history.sort.date] los ordena por fecha. Mientras se muestra el gráfico, :ui[history.sort.topo] sigue activado. Cuando los dos están activados, se usa el orden por fecha. |
| :ui[history.groupBy] | Agrupa los commits por día, semana o mes bajo encabezados, o no los agrupa. Solo se aplica al ordenar por fecha. |
| :ui[history.medium] / :ui[history.small] | Dos líneas por commit, o una. Las filas pequeñas solo se aplican mientras se muestra el gráfico. |
| :ui[signature.verify] | Marca los commits firmados. Consulta [Firmas](/guide/history/commit-details/#signatures). |
| :ui[history.compareBranches] | Consulta [Comparar con otra rama](#compare-branches) |

Estas opciones se aplican a todas las ventanas y a todos los repositorios. Spooky las recuerda.

## Comparar con otra rama {#compare-branches}

Para ver cómo se relaciona una rama local con otra:

1. Haz clic en la rama en la barra lateral.
2. Haz clic en el botón de comparar de la cabecera. También puedes activar :ui[history.compareBranches] en las opciones de visualización, o pulsar <kbd>⌃⌥⌘C</kbd>.
3. Junto a :ui[history.compareTo], elige la otra rama en el menú. Spooky empieza con la rama padre de la rama, si la tiene.

Una fila de la lista marca dónde se separan las dos ramas. Los commits que hay debajo pertenecen también a la otra rama. Aparecen atenuados. Si la rama aún no tiene commits propios, la lista dice :ui[history.noNewCommits].

La cabecera también puede mostrar dos insignias. Una cuenta los commits de la otra rama que esta rama aún no tiene. La otra aparece cuando fusionar la otra rama provocaría conflictos. Haz clic en ella para ver los archivos.

## Encontrar un commit en el historial {#reveal}

Cuando la lista muestra solo algunas ramas, haz clic derecho en un commit y selecciona :ui[quickActions.revealInHistory]. La lista cambia a todas las ramas y selecciona el commit.

Si el commit está muy atrás, más allá de los primeros 10.000 commits, Spooky pregunta antes de cargar el historial hasta ahí. Si el commit no está en el historial, una línea sobre la lista lo indica.

## Consulta también

- [Detalles del commit](/guide/history/commit-details/)
- [Reescribir el historial](/guide/history/rewrite/)
- [Ramas](/guide/branches/branches/)
