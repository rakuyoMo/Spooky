---
title: "Etiquetas y remotos"
description: "Crea, publica y elimina etiquetas, y añade, edita, renombra y elimina remotos."
---

Las etiquetas aparecen en la barra lateral, en :ui[sidebar.tags], y los remotos en :ui[remote.group]. Unas y otros tienen su propio menú: haz clic derecho en uno de ellos para ver qué puedes hacer.

## Etiquetas {#tags}

Una etiqueta da a un commit un nombre que no se mueve, normalmente para una versión como `v0.4.0`. A diferencia de una rama, no avanza cuando haces commit.

Deja el puntero sobre una etiqueta para ver el commit al que apunta, y su mensaje si lo tiene. Haz doble clic en una etiqueta para hacer checkout de su commit. Consulta [Hacer checkout de una etiqueta o un commit](/guide/branches/branches/#checkout-revision).

Igual que las ramas, las etiquetas cuyo nombre contiene una `/` van en carpetas. Para mostrar solo las más recientes, u ordenarlas al revés, consulta [Filtrar y agrupar](/guide/branches/branches/#filter).

### Crear una etiqueta {#create-tag}

1. Selecciona :ui[menu.repository > tag.createMenu] (<kbd>⇧⌘T</kbd>). También puedes hacer clic en el botón de añadir de la parte inferior de la barra lateral y seleccionarlo en el menú. Para etiquetar una rama o un commit concretos, haz clic derecho en ese elemento y selecciona :ui[tag.createFrom]{1="main"} en el menú.
2. Escribe el nombre en :ui[reference.name].
3. :ui[tag.revision] es el commit que se etiqueta. Al principio es la rama en la que estás, o aquello en lo que hiciste clic derecho.
4. Escribe un :ui[tag.messageField] si quieres. Sin él, la etiqueta es solo un nombre para el commit. Con él, Git guarda además quién creó la etiqueta y cuándo.
5. Para firmar la etiqueta, selecciona :ui[tag.sign] y elige una clave en :ui[tag.signingKey]. :ui[tag.signingKey.configured] usa la clave configurada en Git. Una etiqueta firmada necesita un mensaje. Spooky recuerda si firmas.
6. Haz clic en :ui[tag.create.submit].

También puedes arrastrar un commit o una rama local a :ui[sidebar.tags] o a una carpeta de etiquetas.

Una etiqueta nueva solo existe en este repositorio hasta que la publicas. Para volver a quitarla, selecciona :ui[menu.edit > menu.undo] (<kbd>⌘Z</kbd>).

### Publicar una etiqueta {#publish-tag}

1. Haz clic derecho en la etiqueta y selecciona :ui[tag.publishMenu]{1="v0.4.0"} en el menú, o selecciona :ui[menu.repository > tag.publishMainMenu] en la barra de menús. También puedes arrastrar la etiqueta sobre un remoto.
2. Revisa :ui[tag.local] y :ui[sync.remote]. El remoto es el que sigue tu rama actual, salvo que hayas arrastrado la etiqueta sobre otro.
3. Selecciona :ui[sync.skipHooks] para hacer push sin ejecutar los hooks de Git del repositorio.
4. Haz clic en :ui[tag.publish].

Publicar una etiqueta se puede deshacer. Al deshacerlo, se vuelve a eliminar en el remoto.

Para hacer push de todas las etiquetas a un remoto de una vez, haz clic derecho en el remoto y selecciona :ui[tag.pushAll]{1="origin"} en el menú. El diálogo de push también puede enviar todas las etiquetas. Consulta [Push](/guide/branches/sync/#push).

### Eliminar una etiqueta {#delete-tag}

Haz clic derecho en la etiqueta y selecciona :ui[reference.deleteMenu]{1="v0.1.0"} en el menú. También puedes seleccionar una o varias etiquetas y pulsar <kbd>⌘⌫</kbd> mientras la barra lateral tiene el foco.

Spooky siempre pregunta antes. Para eliminar la etiqueta también en un remoto, selecciona :ui[tag.deleteRemote] y elige el remoto en :ui[sync.remote].

Eliminar una etiqueta solo en este repositorio se puede deshacer. Eliminarla en un remoto, no.

## Remotos {#remotes}

Un remoto es otra copia del repositorio de la que haces fetch y a la que haces push, a menudo en un servicio de alojamiento. El remoto del que clonaste suele llamarse `origin`.

En :ui[remote.group], cada remoto muestra sus ramas. Deja el puntero sobre un remoto para ver sus URL de fetch y de push.

Haz clic derecho en un remoto para ver su menú:

- :ui[remote.fetchMenu]{1="origin"} y :ui[sync.prune] abren el diálogo de fetch para este remoto. Consulta [Fetch](/guide/branches/sync/#fetch).
- :ui[remote.viewInBrowser]{1="origin"} abre la página web del remoto. Funciona con las URL HTTP(S), SSH y `git://`, pero no con las rutas locales.
- Los demás ítems añaden, editan, renombran y eliminan remotos, como se explica más abajo.

:::note[Repositorios de servidor]
A los remotos se accede desde el servidor, con la red y las claves SSH del servidor. Una URL que funciona en tu Mac puede no funcionar desde el servidor.
:::

### Añadir un remoto {#add-remote}

1. Selecciona :ui[menu.repository > remote.addMainMenu] en la barra de menús. También puedes hacer clic en el botón de añadir de la parte inferior de la barra lateral, o hacer clic derecho en :ui[remote.group], y seleccionar :ui[remote.addMenu] en el menú.
2. Escribe un nombre corto en :ui[reference.name], como `upstream`.
3. Pega la dirección en :ui[remote.url].
4. Haz clic en :ui[remote.add.submit].

Spooky comprueba la conexión antes de añadir el remoto. Si no puede conectarse, el diálogo sigue abierto. Puedes corregir una errata y volver a intentarlo. En cuanto el remoto está añadido, Spooky hace fetch de él.

### Ajustes del remoto {#remote-settings}

Haz clic en un remoto en la barra lateral para abrir sus ajustes. El selector de arriba tiene dos páginas:

- :ui[remote.page.general] muestra cómo se comunica Git con el remoto.
- :ui[remote.page.branches] muestra las ramas del remoto con el commit al que apunta cada una.

Deja el puntero sobre una fila de :ui[remote.page.general] para ver sus botones.

| Ajuste | Qué hace |
|---|---|
| :ui[remote.field.fetchURL] | De dónde hace fetch Spooky. Hacer clic derecho en el remoto y seleccionar :ui[remote.editConnection] también lo edita. |
| :ui[remote.skipFetchAll] | Deja este remoto fuera del fetch automático y de :ui[sync.fetchAll]. |
| :ui[remote.field.fetchRefspecs] | De qué ramas hacer fetch, y dónde guardarlas. |
| :ui[remote.field.pushURL] | Adónde hace push Spooky. Hasta que estableces una, el push usa la URL de fetch, que se muestra en gris. :ui[remote.action.unset] vuelve a ella. |
| :ui[remote.field.pushRefspecs] | De qué ramas hacer push, y adónde. |

Un refspec es una regla que asocia los nombres de rama de un lado con los nombres del otro. A la mayoría de los remotos les basta con el que configura Git. Para añadir uno, haz clic en :ui[remote.action.addRefspec] junto a :ui[remote.group.fetch] o :ui[remote.group.push].

Spooky comprueba una URL nueva antes de guardarla. Los cambios en los ajustes del remoto se pueden deshacer.

### Renombrar o eliminar un remoto {#rename-remote}

Haz clic derecho en el remoto y selecciona :ui[reference.renameMenu]{1="origin"} o :ui[reference.deleteMenu]{1="origin"} en el menú.

Eliminar un remoto lo quita de este repositorio junto con sus ramas remotas. El repositorio al que apunta no cambia. Tanto renombrarlo como eliminarlo se puede deshacer.

## Consulta también

- [Ramas](/guide/branches/branches/)
- [Fetch, pull y push](/guide/branches/sync/)
- [Deshacer y recuperar](/guide/work/undo/)
