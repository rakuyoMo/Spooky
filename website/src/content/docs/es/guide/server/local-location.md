---
title: "Ubicación en este Mac"
description: "Da a un repositorio de servidor una ubicación en este Mac mediante la búsqueda automática, un montaje SMB o sshfs, o una carpeta que elijas, para que Mostrar en el Finder, Terminal y los editores externos puedan abrirlo."
---

El Finder solo puede mostrar carpetas de tu Mac. Los archivos de un repositorio de servidor están en el servidor. Para mostrarlos en el Finder, Spooky necesita una carpeta en este Mac en la que aparezcan los archivos del servidor, normalmente un volumen de red montado. Esa carpeta es la ubicación del repositorio en este Mac.

Esta página explica cómo encuentra o monta Spooky esa carpeta, y cómo abren Terminal y otras apps un repositorio de servidor.

## Mostrar en el Finder {#show-in-finder}

:ui[action.revealFinder] está siempre disponible en un repositorio de servidor. Lo encontrarás en estos lugares:

- El menú :ui[menu.file]
- :ui[toolbar.finder] en la barra de herramientas. Para añadirlo, selecciona :ui[menu.view > menu.customizeToolbar] y arrástralo a la barra de herramientas.
- La fila :ui[workspace.title] de la barra lateral, al hacer clic derecho en ella
- Las [acciones rápidas](/guide/repositories/navigation/#quick-actions)
- La ventana Repositorios, al hacer clic derecho en un repositorio de servidor
- Los archivos de la copia de trabajo, al hacer clic derecho en ellos. El Finder selecciona esos archivos.

Si la ubicación se conoce y la carpeta está ahí, el Finder se abre al momento. Si no, Spooky muestra una hoja y sigue estos pasos:

1. Si el repositorio no está conectado, Spooky se conecta primero.
2. Busca la carpeta, y la monta si el método es SMB o sshfs.
3. Si sigue sin encontrar la carpeta, la hoja se convierte en el formulario para definir la ubicación, con el motivo arriba. Consulta [Definir la ubicación](#set).

Haz clic en :ui[action.cancel] para cerrar la hoja. Tus ajustes no cambian.

## Definir la ubicación {#set}

1. En la barra lateral, bajo :ui[workspace.group], haz clic en :ui[repositorySettings.title].
2. En la página :ui[repositorySettings.general], busca :ui[repositorySettings.localLocation]. Muestra el método y la carpeta, o por qué no hay carpeta, como :ui[localLocation.notMounted].
3. Pasa el puntero sobre la fila y haz clic en :ui[localLocation.change] cuando aparezca. El repositorio tiene que estar conectado.
4. En :ui[localLocation.title], selecciona un método junto a :ui[localLocation.method].
5. Haz clic en :ui[localLocation.mount] para un montaje, o en :ui[localLocation.save] para los demás métodos.

Mientras Spooky monta o comprueba la carpeta, el formulario queda bloqueado. Haz clic en :ui[action.cancel] para parar. Se mantiene tu ajuste anterior.

La ubicación se guarda en este Mac para cada repositorio de servidor. Spooky no la escribe en el repositorio ni en el servidor.

Si un montaje SMB o sshfs se ha expulsado, la fila muestra :ui[localLocation.mountAgain]. Haz clic en él para volver a montar la carpeta.

## Métodos {#methods}

El menú :ui[localLocation.method] solo muestra los métodos que funcionan en ese momento. El método actual aparece siempre.

### Automático {#automatic}

:ui[localLocation.method.automatic] es el valor predeterminado. Spooky busca entre los volúmenes de red ya montados en este Mac, como los volúmenes SMB, NFS, AFP, WebDAV y sshfs. No importa qué app los montó. Un volumen cuenta si su servidor tiene la misma dirección que tu alias de host.

Después, Spooky busca la carpeta del repositorio dentro del volumen. Para asegurarse de que es el mismo repositorio, Spooky pone un momento un archivo vacío en la carpeta de Git del repositorio en el servidor, comprueba que aparece en el volumen y lo elimina.

### Montaje SMB {#smb}

:ui[localLocation.method.smbMount] monta una carpeta compartida del servidor con SMB, el protocolo para compartir archivos que usa macOS. Aparece cuando el servidor responde en el puerto de SMB en menos de 2 segundos.

1. Selecciona :ui[localLocation.method.smbMount] y haz clic en :ui[localLocation.mount].
2. macOS muestra las carpetas compartidas del servidor, o te pide antes que inicies sesión. Selecciona la carpeta compartida que contiene el repositorio.

Spooky recuerda la carpeta compartida y la próxima vez la monta de nuevo sin preguntar. Si el repositorio no está en la carpeta compartida que has elegido, el formulario muestra :ui[localLocation.notInShare] Elige otra carpeta compartida y vuelve a intentarlo.

Si el servidor es un Mac, activa **Compartir archivos** en **menú Apple › Ajustes del Sistema › General › Compartir** en ese Mac.

### Montaje sshfs {#sshfs}

:ui[localLocation.method.sshfsMount] monta la carpeta del repositorio por SSH, con el mismo alias de host que usa Spooky. Necesita sshfs y macFUSE o FUSE-T en este Mac. Spooky busca `sshfs` en `/opt/homebrew/bin`, en `/usr/local/bin` y en tu `PATH`. Si no está instalado, este método no aparece.

1. Selecciona :ui[localLocation.method.sshfsMount].
2. Junto a :ui[localLocation.mountAt], haz clic en :ui[localLocation.choose] y elige una carpeta vacía de este Mac. Los archivos del servidor aparecen ahí.
3. Haz clic en :ui[localLocation.mount].

### Carpeta elegida {#chosen-folder}

:ui[localLocation.method.chosenFolder] te deja elegir la carpeta tú mismo, por ejemplo una que has montado de otra manera.

1. Selecciona :ui[localLocation.method.chosenFolder].
2. Junto a :ui[localLocation.folder], haz clic en :ui[localLocation.choose] y elige la carpeta del repositorio.
3. Haz clic en :ui[localLocation.save]. Spooky comprueba la carpeta antes de guardar.

Spooky nunca expulsa un volumen que ha montado. Cuando vuelvas a abrir el repositorio más adelante, Spooky lo montará de nuevo en segundo plano, sin preguntar nada.

## Montar al añadir {#when-adding}

Cuando [añades un repositorio de servidor](/guide/server/add/), :ui[remote.mount] configura la ubicación en el mismo paso. Empieza en :ui[remote.mount.none]. Cuando escribes el alias de host, el menú muestra :ui[remote.mount.smb] y :ui[remote.mount.sshfs] si están disponibles. Si no lo está ninguno, muestra :ui[remote.mount.unavailable].

- **SMB:** Cuando se abre el repositorio, macOS muestra las carpetas compartidas del servidor o una ventana de inicio de sesión. Si cancelas, el repositorio se abre igualmente, y :ui[repositorySettings.localLocation], en sus ajustes, muestra por qué no está montado.
- **sshfs:** Aparece una fila adicional, :ui[localLocation.mountAt]. Elige una carpeta vacía. Spooky monta ahí el repositorio cuando se abre.

Si cambias el alias de host, el menú vuelve a :ui[remote.mount.none].

## Terminal y otras apps {#terminal}

Estos comandos funcionan en un repositorio de servidor sin una ubicación en este Mac:

- **:ui[action.openTerminal]** abre la app de terminal elegida en :ui[app.name > settings.title] › :ui[settings.general], inicia sesión con `ssh -t` y el alias de host, y va a la carpeta del repositorio. Si el servidor no permite un terminal, Spooky se conecta de nuevo sin él. Los comandos siguen funcionando, pero la edición de líneas y los programas a pantalla completa no. Lo encontrarás en el menú :ui[menu.file], como :ui[toolbar.terminal] en la barra de herramientas, y al hacer clic derecho en la copia de trabajo o en un repositorio de la ventana Repositorios. Para elegir la app de terminal, consulta [Terminal](/guide/settings/integration/#terminal).
- **:ui[action.copyPath]** copia la ruta con el alias de host delante, como `driftwood-server:/srv/git/driftwood`.
- **:ui[files.open] y :ui[files.openWith]**, en la copia de trabajo, abren un archivo en otra app. Visual Studio Code, Visual Studio Code Insiders y Cursor abren el archivo directamente en el servidor, si hay instalada una extensión Remote SSH. Las demás apps reciben una copia en este Mac. Cuando guardas, Spooky escribe la copia en el servidor.

Si el archivo del servidor ha cambiado entretanto, Spooky pregunta antes de escribir: :ui[externalTool.fileChanged]. Haz clic en :ui[externalTool.overwrite] para sustituirlo por tu copia. Spooky elimina las copias cuando cierras el repositorio.

Vista Rápida y las herramientas externas de diff y de fusión también trabajan con copias. Cuando una herramienta de fusión termina, Spooky escribe el resultado en el servidor y lo añade al stage.

## Consulta también

- [Cómo funcionan los repositorios de servidor](/guide/server/overview/)
- [Añadir repositorio de servidor](/guide/server/add/)
- [Integración](/guide/settings/integration/)
