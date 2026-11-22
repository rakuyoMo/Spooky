---
title: "Deshacer y recuperar"
description: "Descubre qué puede deshacer ⌘Z y por qué algunas operaciones no se pueden deshacer, y recupera commits perdidos con el reflog."
---

Casi todo lo que haces con un repositorio en Spooky se puede deshacer con <kbd>⌘Z</kbd>. Para lo demás, el reflog de Git recuerda por dónde han pasado tus ramas, así que un commit rara vez se pierde del todo.

## Deshacer y rehacer {#undo}

Selecciona :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>) para deshacer la última operación. La opción del menú incluye el nombre de la operación. Selecciona :ui[menu.edit > menu.redo] (<kbd>⇧⌘Z</kbd>) para volver a hacerla. Puedes retroceder por varias operaciones, empezando por la más reciente.

Puedes deshacer, por ejemplo:

- Añadir al stage, hacer commit y enmendar
- Descartar cambios y trasladar archivos a la papelera
- Guardar, aplicar y eliminar stashes
- Hacer checkout de ramas, crearlas, renombrarlas y eliminarlas, y crear etiquetas
- Fijar y archivar ramas, definir el upstream y avanzar rápido
- Fusionar, hacer rebase, hacer cherry-pick, revertir y restablecer
- Añadir, renombrar y eliminar remotos, y cambiar sus ajustes
- Publicar ramas y etiquetas, y renombrar ramas remotas
- Marcar archivos como assume-unchanged, activar Git LFS y cambiar submódulos

Los archivos que fueron a la papelera se devuelven desde la papelera. Si deshaces un restablecimiento mientras hay archivos con seguimiento modificados, Spooky pregunta antes si quieres guardarlos en un stash. El nuevo stash se queda en la lista.

Mientras escribes en un campo de texto, como el mensaje del commit, <kbd>⌘Z</kbd> deshace lo que has escrito.

Cada repositorio tiene un único historial de deshacer, compartido por todas sus ventanas. Spooky lo conserva hasta que sales de la app. Las instantáneas que necesita se guardan en la base de datos de Git del propio repositorio, y no se hace push de ellas a ningún sitio.

:::note[Repositorios de servidor]
Las instantáneas se guardan en el repositorio del servidor. Los archivos que fueron a la papelera del servidor se devuelven desde allí.
:::

## Lo que no se puede deshacer {#cant-undo}

Deshacer deja el repositorio como estaba. Algunos cambios quedan fuera de lo que Spooky puede restaurar:

- Eliminar ramas y etiquetas en un remoto. Eliminar una rama local junto con su rama remota es una excepción: deshacer vuelve a crear las dos.
- Cambiar la identidad del committer, las reglas de ignorado u otros ajustes de Git.
- Todo lo que haces mientras hay una fusión, un rebase u otra operación en curso, incluido continuarla o abortarla.
- Un rebase o un cherry-pick que se detiene en un conflicto. Una fusión o un revert que se detienen por conflictos se pueden deshacer, lo que los aborta.
- Los archivos nuevos que se eliminaron definitivamente, por ejemplo en un servidor sin papelera.
- Inicializar, sincronizar y reparar submódulos; todo lo que haces con worktrees; actualizar los hooks de Git LFS; y publicar un repositorio en un servicio de alojamiento. Consulta [Submódulos](/guide/advanced/submodules/#undo), [Worktrees](/guide/advanced/worktrees/#undo), [Git LFS](/guide/advanced/lfs/#undo) y [Publicar un repositorio](/guide/hosting/accounts/#publish).

Después de una de estas operaciones, la opción del menú dice que la operación no se puede deshacer. Las operaciones anteriores a ella tampoco se pueden deshacer ya.

Fetch, pull, push y la sincronización no se registran. No se pueden deshacer. Lo mismo vale para hacer fetch de submódulos y actualizarlos, y para hacer fetch, pull y push de contenido LFS.

## Cuando deshacer está bloqueado {#blocked}

Deshacer solo funciona mientras el repositorio sigue como lo dejó la operación. Cuando no es así, la opción del menú aparece atenuada y da un motivo entre paréntesis:

| Motivo | Qué hacer |
|---|---|
| :ui[undo.reason.busy] | Espera a que termine la operación en ejecución, o termina la fusión, el rebase u otra operación en curso. |
| :ui[undo.reason.disconnected] | Vuelve a conectar con el servidor. |
| :ui[undo.reason.changed] | El repositorio ha cambiado desde la operación: un pull o una sincronización trajeron commits, o Terminal u otra app lo modificaron. Déjalo como estaba, y deshacer vuelve a funcionar. |

Spooky comprueba el repositorio una vez más justo antes de deshacer nada. Si algo lo impide, se detiene y te dice por qué. No se cambia nada.

| Mensaje | Por qué |
|---|---|
| :ui[undo.error.changed] | El repositorio ya no coincide con lo que Spooky registró. |
| :ui[undo.error.untracked] | Restaurar sobrescribiría o eliminaría archivos sin seguimiento. |
| :ui[undo.error.hidden] | Hay archivos marcados como assume-unchanged con cambios locales, o el repositorio usa skip-worktree. |
| :ui[undo.error.inProgress] | Termina o aborta antes la fusión, el rebase, el cherry-pick o el revert. |
| :ui[undo.error.conflicts] | Resuelve antes los conflictos. Consulta [Resolver conflictos](/guide/work/conflicts/). |
| :ui[undo.error.trash] | Algunos archivos ya no están en la papelera, o ahora hay otros archivos donde estaban. |

## Recuperar commits con el reflog {#reflog}

Git lleva un registro de adónde han apuntado HEAD y cada rama local. Un commit que perdiste al restablecer, al hacer rebase o al eliminar una rama suele seguir ahí. Los cambios de los que nunca hiciste commit, no.

1. Selecciona :ui[menu.view > reflog.show] (<kbd>⌘6</kbd>).
2. En :ui[reflog.ref], en la parte superior, elige HEAD o una rama local.
3. Busca la entrada. Cada una muestra el hash corto, qué pasó y cuándo, con la descripción de Git debajo. Para filtrar la lista, escribe en el campo de búsqueda de la barra de herramientas.
4. Selecciona la entrada para ver los detalles del commit.

::screenshot[La vista del reflog para HEAD. Cada entrada muestra un hash corto, una acción como commit, checkout o reset, y una fecha, con el mensaje debajo. Los detalles del commit de la entrada seleccionada están a la derecha.]{name="work-reflog" frame="window" markers="36.5,9 44.1,37.1 84.4,21.3"}

1. El menú :ui[reflog.ref]
2. La entrada seleccionada
3. Los detalles del commit

Haz clic derecho en la entrada para recuperar el commit:

- :ui[reflog.createBranch]{1="9e0d36a7"} crea ahí una rama nueva. Tus ramas actuales se quedan como están.
- :ui[reflog.restore]{1="feature/units-toggle" 2="9e0d36a7"} devuelve a ese commit la rama que estás viendo. La copia de trabajo y el área de stage no cambian. Spooky pregunta antes, y puedes deshacerlo.
- :ui[reflog.cherryPick]{1="9e0d36a7"} copia el commit en la rama actual. También puedes arrastrar la entrada a :ui[workspace.title] o a la rama actual en la barra lateral.
- :ui[reflog.reset]{1="9e0d36a7"} abre el diálogo de restablecer, para mover la rama actual a ese commit.
- :ui[patch.menu]{1="9e0d36a7"} guarda el commit como un archivo de parche.

Para tener :ui[reflog.title] en la barra lateral, activa :ui[sidebar.showReflog] en :ui[sidebar.viewSettings].

:::caution
Git elimina las entradas antiguas del reflog con el tiempo. De forma predeterminada, las entradas se conservan 90 días, y 30 días cuando su commit ya no está en la rama. Recupera pronto los commits perdidos.
:::

:::note[Repositorios de servidor]
El reflog está en el repositorio del servidor. Spooky lo lee allí.
:::

## Consulta también

- [Hacer commit de los cambios](/guide/work/commit/)
- [Resolver conflictos](/guide/work/conflicts/)
- [Reescribir el historial](/guide/history/rewrite/)
