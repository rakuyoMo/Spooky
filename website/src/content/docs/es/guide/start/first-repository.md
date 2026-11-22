---
title: "Tu primer repositorio"
description: "Abre un repositorio en tu Mac y, de principio a fin, modifica tu trabajo, añádelo al stage, haz commit y haz push."
---

Esta página te guía por una ronda completa de trabajo. Abres un repositorio en tu Mac, modificas un archivo, añades el cambio al stage, haces commit y haces push del commit a un remoto.

Necesitas un repositorio de Git en tu Mac con un remoto al que puedas hacer push. Si aún no tienes ninguno, [La ventana Repositorios](/guide/repositories/manager/) explica cómo clonar o crear uno.

## Abrir el repositorio {#open}

1. Selecciona :ui[menu.file > action.openLocal] (<kbd>⌘O</kbd>).
2. Selecciona la carpeta del repositorio y haz clic en :ui[repositories.panel.prompt].

Spooky abre el repositorio y muestra su :ui[workspace.title]. También añade el repositorio a la lista Repositorios. La próxima vez podrás abrirlo desde allí.

Puedes elegir cualquier carpeta dentro del repositorio. Spooky abre el repositorio entero. Si la carpeta no está en un repositorio de Git, Spooky dice :ui[bookmarks.noRepository.title]. Haz clic en :ui[bookmarks.noRepository.create] para convertir la carpeta en un repositorio nuevo, o en :ui[action.cancel] para elegir otra.

:::note[Repositorios de servidor]
Para trabajar en un repositorio de un servidor, añádelo con :ui[action.addRemote]. [Añadir repositorio de servidor](/guide/server/add/) explica cómo. Una vez abierto, el resto de esta página funciona igual.
:::

## Hacer un cambio {#change}

Edita un archivo del repositorio con cualquier editor y guárdalo. Spooky detecta el cambio y muestra el archivo en :ui[workspace.title]. Si un cambio no aparece, haz clic en :ui[action.refresh] o pulsa <kbd>⌘R</kbd>.

Selecciona el archivo para ver qué ha cambiado en la columna derecha. Las líneas añadidas son verdes y las eliminadas, rojas.

## Añadir el cambio al stage {#stage}

Git no hace commit de todo lo que has cambiado. Solo hace commit de lo que añades al stage. El stage te permite elegir qué cambios entran en el próximo commit. Todo lo demás se queda en la copia de trabajo para más adelante.

Para añadir un archivo al stage, haz una de estas cosas:

- Marca la casilla que hay delante del archivo.
- Selecciona uno o varios archivos y pulsa <kbd>Espacio</kbd>.
- Haz clic en :ui[working.stageAll] para añadir al stage todos los archivos modificados.

Los archivos del stage mantienen la casilla marcada. Para añadir al stage solo algunas líneas de un archivo, consulta [Revisar y añadir cambios al stage](/guide/work/diff/).

## Hacer commit {#commit}

Un commit guarda los cambios del stage en el historial del repositorio. Lleva un mensaje que dice qué has cambiado y por qué.

1. Haz clic en :ui[working.subject] y escribe un resumen corto del cambio. El área de commit se expande mientras escribes.
2. Si quieres explicar algo más, escríbelo en :ui[working.body].
3. Haz clic en :ui[working.commit] o pulsa <kbd>⌘↩</kbd>.

::screenshot[El área de commit con el asunto “Add gust alerts and a humidity chart” escrito. Debajo están una descripción detallada vacía, las casillas para enmendar y firmar, el nombre y el correo del autor, y los botones para añadir todo al stage y hacer commit. La lista de archivos de abajo muestra tres archivos con la casilla marcada.]{name="start-commit" frame="closeup"}

Algunos detalles del área de commit expandida:

- El número al final del campo de asunto cuenta los caracteres que te quedan. Pasado ese punto, el asunto es más largo de lo recomendado.
- :ui[working.commit] permanece atenuado hasta que el asunto tiene algo de texto.
- El nombre y el correo de la derecha quedan registrados en el commit como su autor. Para cambiarlos, consulta [Perfiles de usuario y configuración de Git](/guide/settings/identity/).
- :ui[working.amend] y :ui[commit.signOff] se explican en [Hacer commit de los cambios](/guide/work/commit/).

Tras el commit, los archivos incluidos desaparecen de la lista. En la barra lateral, la rama actual muestra ahora ↑1. Es un commit que está en tu Mac y todavía no en el remoto.

## Hacer push {#push}

Hacer push envía tus commits al remoto. Los demás pueden obtenerlos de allí, y el remoto guarda una copia de seguridad.

1. Haz clic en :ui[sync.push] en la barra de herramientas, o selecciona :ui[menu.repository > sync.pushMenu] (<kbd>⇧⌘U</kbd>).
2. Comprueba que :ui[sync.destination] es la rama remota a la que quieres hacer push. Si la rama ya sigue una rama remota, esa es la que aparece seleccionada.
3. Haz clic en :ui[sync.pushHead].

::screenshot[El diálogo para hacer push de HEAD. Hace push de los commits nuevos de la rama local “main” al destino origin/main. Debajo hay una sección de opciones contraída y los botones para cancelar y hacer push de HEAD.]{name="sync" frame="dialog"}

Cuando termina el push, el ↑1 que hay junto a la rama desaparece. [Push](/guide/branches/sync/#push) explica :ui[dialog.options]. Para hacer push de una rama por primera vez, consulta [Publicar una rama](/guide/branches/sync/#publish).

:::tip
Mantén pulsada <kbd>⌥</kbd> y haz clic en el botón :ui[sync.push]. Se convierte en :ui[sync.quickPush] y hace push de la rama actual a su rama de seguimiento al instante, sin el diálogo.
:::

## Consulta también

- [Copia de trabajo](/guide/work/working-copy/)
- [Hacer commit de los cambios](/guide/work/commit/)
- [Fetch, pull y push](/guide/branches/sync/)
