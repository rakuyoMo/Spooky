---
title: "La ventana Repositorios"
description: "Guarda repositorios como marcadores, agrúpalos, ábrelos, clónalos, créalos, búscalos en una carpeta y elimínalos, y localiza los que han desaparecido."
---

La ventana Repositorios guarda una lista de los repositorios con los que trabajas, en tu Mac y en servidores. Cada entrada es un marcador que apunta a un repositorio. Al eliminar un marcador, la carpeta del repositorio se queda donde está. Trasladar la carpeta a la papelera es una decisión aparte. Esta página explica cómo añadir, organizar, abrir y eliminar repositorios.

Para ir a la lista desde un repositorio, haz clic en :ui[toolbar.bookmarks] en la barra de herramientas o selecciona :ui[menu.view > menu.showRepositories] (<kbd>⌃⌘R</kbd>).

::screenshot[La ventana Repositorios. La barra lateral muestra dos grupos, Driftwood Labs y Notes, con repositorios dentro; uno de ellos es un repositorio de servidor cuyo nombre empieza por su alias de host. A la derecha están los detalles del repositorio seleccionado, driftwood: su ubicación, cuándo se abrió por última vez, su último commit, una descripción, la identidad del committer, la rama actual, el número de archivos modificados y el remoto.]{name="repositories" frame="window"}

## Añadir repositorios {#add}

El botón de añadir, en la parte inferior de la barra lateral, tiene un menú para añadir elementos a la lista:

| Ítem del menú | Qué hace |
|---|---|
| :ui[bookmarks.newGroup] | Añade un grupo debajo de la selección, listo para que escribas su nombre |
| :ui[bookmarks.add] | Añade repositorios que ya están en tu Mac. Puedes seleccionar varias carpetas a la vez. |
| :ui[action.addRemote] | Añade un repositorio de un servidor. Consulta [Añadir repositorio de servidor](/guide/server/add/). |
| :ui[bookmarks.create] | Crea un repositorio vacío. Consulta [Crear un repositorio](#create). |
| :ui[clone.menu] | Copia un repositorio desde un remoto. Consulta [Clonar un repositorio](#clone). |
| :ui[scan.menu] | Encuentra los repositorios que hay dentro de una carpeta. Consulta [Buscar repositorios](#scan). |

Las entradas nuevas van al grupo seleccionado. También puedes arrastrar carpetas de repositorios desde el Finder a la lista. Si abres un repositorio con :ui[menu.file > action.openLocal] y aún no está en la lista, se añade al final.

### Crear un repositorio {#create}

1. Selecciona :ui[bookmarks.create] en el menú del botón de añadir.
2. En :ui[bookmarks.create.name], escribe el nombre del nuevo repositorio. Es también el nombre de su carpeta.
3. Junto a :ui[bookmarks.create.location], haz clic en :ui[bookmarks.create.choose] para elegir la carpeta en la que se crea. Empieza en tu carpeta de inicio.
4. Haz clic en :ui[bookmarks.create.submit].

Spooky crea la carpeta, la convierte en un repositorio de Git vacío, la añade al grupo seleccionado y la abre.

### Clonar un repositorio {#clone}

Clonar copia un repositorio y su historial desde un remoto a una carpeta nueva.

1. En el menú del botón de añadir, selecciona :ui[clone.menu], o pulsa <kbd>⌃⌘C</kbd>.
2. En :ui[clone.url], introduce la dirección del repositorio, por ejemplo una que empiece por `https://` o `git@`.
3. En :ui[clone.to], selecciona :ui[clone.machine.local] o un servidor. Los servidores que ya usas están en la lista. Para usar otro, selecciona :ui[clone.machine.other] e introduce su :ui[remote.host].
4. En :ui[clone.directory], elige la carpeta en la que clonar. Spooky crea dentro una carpeta con el nombre del repositorio.
5. Deja :ui[clone.submodules] seleccionado para hacer también checkout de los submódulos del repositorio. Selecciona :ui[clone.lfs] si el repositorio guarda archivos grandes en Git LFS.
6. Haz clic en :ui[clone.submit].

Spooky comprueba primero que puede acceder al remoto. Si no puede, el diálogo sigue abierto y muestra el motivo. Corrige la dirección y vuelve a intentarlo. Si puede, el diálogo se cierra y el clon se ejecuta en segundo plano. Su progreso aparece en la fila del repositorio en la lista. Cuando el clon termina, Spooky envía una notificación :ui[clone.notification.title].

En tu Mac, la carpeta empieza en tu carpeta de inicio, o en la carpeta definida en :ui[app.name > settings.title] › :ui[settings.general] › :ui[settings.cloneDirectory]. Consulta [Clonación y terminal](/guide/settings/general/#cloning).

Mientras tienes clones recientes, :ui[toolbar.clone] aparece en la barra de herramientas. Haz clic en él para ver :ui[clone.recent.title]. Allí puedes detener un clon en curso, volver a iniciar uno fallido o cancelado con :ui[clone.retry], o quitarlo de la lista con :ui[clone.remove]. Haz doble clic en un clon terminado para abrirlo. :ui[clone.recent.clear] vacía la lista.

:::note[Repositorios de servidor]
Cuando clonas en un servidor, Spooky comprueba la conexión y ejecuta el clon allí. El nuevo repositorio se añade como repositorio de servidor. Para la carpeta, escribe una ruta absoluta del servidor o haz clic en :ui[clone.browse] para elegir una. Spooky recuerda la última carpeta que usaste en cada servidor.
:::

También puedes arrastrar la dirección de un repositorio a la lista para iniciar un clon. Un enlace también puede iniciarlo. Consulta [Ventanas y navegación](/guide/repositories/navigation/).

### Buscar repositorios {#scan}

1. Selecciona :ui[scan.menu] en el menú del botón de añadir.
2. En :ui[scan.in], selecciona :ui[clone.machine.local] o un servidor, y después la carpeta en la que buscar.
3. Haz clic en :ui[scan.start]. Los repositorios aparecen a medida que Spooky los encuentra. Para parar, haz clic en :ui[scan.stop].
4. Todos los repositorios encontrados quedan seleccionados. Anula la selección de los que no quieras y haz clic en :ui[scan.add].

Los repositorios que ya están en la lista no se muestran otra vez. Puedes buscar en varias carpetas o servidores, uno tras otro. Los resultados se acumulan.

## Organizar la lista {#organize}

- Para añadir un grupo, selecciona :ui[bookmarks.newGroup] en el menú del botón de añadir y escribe un nombre.
- Para reordenar las entradas o moverlas a otro grupo, arrástralas.
- Para renombrar una entrada, selecciónala y pulsa <kbd>↩</kbd>, o haz clic derecho en ella y selecciona :ui[bookmarks.rename]. Renombrar un repositorio en la lista no cambia el nombre de su carpeta.
- Para ordenar por nombre, haz clic derecho y selecciona :ui[bookmarks.sortChildren] para ordenar las entradas de un grupo, o :ui[bookmarks.sortParent] para ordenar el grupo en el que está una entrada.

Dos opciones de :ui[app.name > settings.title] › :ui[settings.general] cambian lo que muestra la lista:

- :ui[settings.showWorktreesInRepositoryList]: un repositorio con otros worktrees se puede expandir para verlos. Un worktree se abre igual que un repositorio. Desactivada de forma predeterminada.
- :ui[settings.showHostAliasesInRepositoryList]: los nombres de los repositorios de servidor empiezan por su alias de host. Activada de forma predeterminada.

Consulta [Ventanas y lista de repositorios](/guide/settings/general/#windows).

## Abrir un repositorio {#open}

Haz doble clic en un repositorio. Se abre en la misma ventana, en lugar de la lista. Si el repositorio ya está abierto en otra ventana, Spooky trae esa ventana al frente.

Haz clic derecho en un repositorio para ver más opciones:

- :ui[bookmarks.open]{1="driftwood"} y :ui[bookmarks.openNewWindow]{1="driftwood"}
- :ui[action.revealFinder], :ui[action.copyPath] y :ui[action.openTerminal]

Los detalles de la derecha tienen además los botones :ui[action.open] y :ui[bookmarks.multiple.delete]. Haz clic allí en :ui[bookmarks.detail.edit] para cambiar :ui[bookmarks.detail.description] y :ui[bookmarks.detail.identity]. :ui[bookmarks.detail.unset] quita la identidad definida solo para este repositorio. Junto a cada remoto, :ui[bookmarks.detail.viewInBrowser] abre su página web. La descripción y la identidad son las mismas que ves en [Ajustes del repositorio](/guide/settings/identity/#repository).

:::note[Repositorios de servidor]
:ui[action.copyPath] copia la ruta con el alias de host delante, como en `alias:/path/to/repository`. Spooky solo lee los detalles de un repositorio de servidor cuando lo seleccionas. Al seleccionar uno, puede que se conecte al servidor.
:::

## Cambiar la ubicación de un repositorio {#location}

Si un repositorio se ha movido, no hace falta eliminar su entrada y volver a añadirla.

1. Selecciona el repositorio. En los detalles, coloca el puntero sobre la fila :ui[bookmarks.detail.location] y haz clic en :ui[bookmarks.detail.edit].
2. Haz clic en :ui[localLocation.choose] y elige la carpeta en la que está ahora el repositorio.
3. Haz clic en :ui[action.ok].

Spooky comprueba primero que la nueva ubicación es un repositorio de Git. Si no lo es, el cuadro de diálogo sigue abierto y muestra el motivo. Si lo es, la entrada apunta a la nueva ubicación. Sigue en su grupo y conserva el nombre que le hayas puesto. Un nombre que nunca cambiaste sigue a la nueva carpeta. No puedes cambiar a una ubicación que ya está en la lista.

::screenshot[El cuadro de diálogo «Editar la ubicación del repositorio» de un repositorio de servidor. El alias de host es spooky-test. La ruta del repositorio es /srv/git/driftwood, con un botón Explorar al lado. Los botones son Cancelar y Aceptar.]{name="repositories-edit-location" frame="dialog"}

:::note[Repositorios de servidor]
El cuadro de diálogo tiene en su lugar :ui[remote.host] y :ui[remote.path]. Puedes cambiar solo uno, por ejemplo solo el alias de host. Haz clic en :ui[clone.browse] para elegir la ruta en el servidor. Spooky se conecta al servidor para comprobar la nueva ubicación.
:::

## Repositorios que faltan {#missing}

Si la carpeta de un repositorio se mueve, se renombra o se elimina, su nombre en la lista se vuelve gris y lleva una señal de advertencia. Sus detalles dicen :ui[bookmarks.detail.missing] Spooky comprueba los repositorios de tu Mac cada vez que aparece la lista.

Si abres un repositorio que falta, la ventana muestra :ui[missing.title]. Haz clic en :ui[action.refresh] para comprobarlo de nuevo, por ejemplo después de volver a conectar un disco. Haz clic en :ui[action.close] para volver a la lista.

Para arreglar la entrada, haz que apunte a donde está ahora el repositorio. Consulta [Cambiar la ubicación de un repositorio](#location).

:::note[Repositorios de servidor]
Spooky solo comprueba un repositorio de servidor cuando lo seleccionas o lo abres. Si Spooky no puede acceder al servidor, la ventana dice :ui[missing.unreachable.title]{1="alias"} y muestra lo que ha indicado SSH. Consulta [Estado de la conexión y reconexión](/guide/server/connection/).
:::

## Eliminar repositorios {#delete}

Selecciona una o varias entradas y haz una de estas cosas:

- Pulsa <kbd>⌫</kbd>.
- Haz clic derecho y selecciona :ui[bookmarks.delete]{1="driftwood"}, :ui[bookmarks.deleteFolder] para un grupo, o :ui[bookmarks.deleteMultiple]{1="2"} para varias entradas.
- Haz clic en :ui[bookmarks.multiple.delete] en los detalles.

Si la carpeta del repositorio aún existe, Spooky pregunta antes :ui[bookmarks.delete.title]{1="driftwood"}. Solo se eliminan los marcadores. Las carpetas se quedan donde están. Para trasladarlas también a la papelera, selecciona :ui[bookmarks.delete.trash]. Haz clic en :ui[bookmarks.delete.submit] para confirmar.

Los grupos vacíos y las entradas cuya carpeta ya no existe se eliminan al momento, sin preguntar.

:::caution
Trasladar a la papelera se lleva la carpeta entera del repositorio, incluidos los cambios de los que no has hecho commit. Puedes recuperarla hasta que vacíes la papelera. La casilla de la papelera se desmarca cada vez que se abre el diálogo.
:::

Si una carpeta no se puede mover, Spooky muestra :ui[bookmarks.trashFailed.title] y enumera las carpetas que se han quedado. Spooky nunca traslada a la papelera tu carpeta de inicio, una carpeta que la contenga ni el nivel superior de un disco.

:::note[Repositorios de servidor]
Spooky siempre pregunta antes de eliminar un repositorio de servidor. Su carpeta va a la papelera de ese servidor, no a la de tu Mac. Si la carpeta ya no está en el servidor, la casilla de la papelera aparece atenuada y solo se elimina el marcador.
:::

## Consulta también

- [Ventanas y navegación](/guide/repositories/navigation/)
- [Añadir repositorio de servidor](/guide/server/add/)
- [Worktrees](/guide/advanced/worktrees/)
