---
title: "Cómo funcionan los repositorios de servidor"
description: "Descubre qué ocurre en el servidor y qué en tu Mac, qué guarda Spooky en el servidor y en qué se diferencian los repositorios de servidor de los locales."
---

Un repositorio de servidor es un repositorio de Git que está en otra máquina y que Spooky abre por SSH. Sus archivos se quedan en el servidor, y Git se ejecuta allí. No hace falta clonarlo antes en tu Mac. Esta página explica qué hace cada lado, qué deja Spooky en el servidor y qué funciona de otra manera que en un repositorio de tu Mac.

Para configurar uno, empieza por [Preparar SSH](/guide/server/prepare-ssh/) y sigue con [Añadir repositorio de servidor](/guide/server/add/).

## Qué ocurre en cada lado {#where}

Spooky se conecta con el SSH que viene con macOS. Usa un alias de host de tu archivo `~/.ssh/config`, así que inicia sesión en el servidor igual que el comando `ssh` en Terminal.

En el servidor:

- Git ejecuta todos los comandos, con el Git y el entorno del propio servidor.
- Spooky lee y escribe los archivos por la conexión SSH. Los archivos grandes llegan por SFTP, la parte de SSH dedicada a transferir archivos.
- Los archivos que eliminas, y los archivos nuevos que descartas, van a la papelera del servidor si tiene una.
- Fetch, pull y push acceden a remotos como GitHub desde el servidor. Usan la red del servidor y las claves SSH del servidor.

En tu Mac:

- Las ventanas, las listas y los diffs con los que trabajas.
- La conexión SSH con el servidor. Spooky mantiene una conexión por cada repositorio abierto y envía todos los comandos a través de ella.
- Las preguntas de Git en el servidor, como una contraseña o la frase de contraseña de una clave. Consulta [Solicitudes de contraseña y de frase de contraseña](/guide/server/connection/#prompts).
- Las solicitudes a GitHub y GitLab, como iniciar sesión en tu cuenta o cargar las pull requests.
- Las copias de los archivos que abres en Vista Rápida o en otra app.

:::note
Para un remoto al que se accede por SSH, el servidor tiene que conocer ya la clave de host del remoto. Si no la conoce, inicia sesión en el servidor y conéctate una vez al remoto desde allí.
:::

## Qué guarda Spooky en el servidor {#on-server}

Spooky no necesita acceso de administrador ni instala ningún servicio. Deja dos cosas en el servidor:

- **Un script de ayuda en `~/.spooky/bin/`**, en tu carpeta de inicio del servidor. Devuelve a tu Mac las preguntas de Git. Spooky lo pone ahí al conectarse y lo conserva para las conexiones siguientes. Los demás nombres de esa carpeta, terminados en `-askpass`, `-gpg`, etc., son enlaces al mismo archivo.
- **Archivos temporales en `/tmp/spooky-*`** mientras hay un repositorio abierto. Spooky los elimina cuando cierras el repositorio.

El script se ejecuta con `/usr/bin/perl`, que la mayoría de los servidores macOS y Linux ya tienen. Consulta la lista completa en [Requisitos del sistema](/reference/requirements/#servers).

Puedes eliminar `~/.spooky` en cualquier momento. Spooky vuelve a instalar el script la próxima vez que se conecta.

## En qué se diferencian los repositorios de servidor {#differences}

Un repositorio de servidor se abre en el mismo tipo de ventana que un repositorio de tu Mac. La mayoría de las vistas y los comandos funcionan igual. Estas son las señales visibles de que un repositorio está en un servidor:

::screenshot[Una ventana de repositorio de servidor. El título dice spooky-test:driftwood, con la vista y la rama actuales debajo. La barra de herramientas muestra el alias de host spooky-test. Una franja en la parte superior de la columna central indica que spooky-test está conectado. Debajo están el área de commit y la lista de archivos modificados. La columna derecha muestra los cambios del archivo seleccionado.]{name="hero" frame="window" markers="49.2,3.3 64.4,7.2 40,8.9"}

1. El título de la ventana empieza por el alias de host, como en `driftwood-server:driftwood`. La ventana Repositorios muestra los nombres de la misma manera.
2. El ítem :ui[toolbar.host] de la barra de herramientas muestra el alias de host.
3. El estado de la conexión aparece en la parte superior de la copia de trabajo, el historial y otras listas. Consulta [Estado de la conexión y reconexión](/guide/server/connection/).

Algunas cosas funcionan de otra manera:

| Qué | En un repositorio de servidor |
|---|---|
| Cambios hechos en el servidor | Spooky comprueba si hay cambios en el servidor cada 2 segundos mientras la ventana del repositorio está en primer plano, y cada 10 segundos en caso contrario. Si el servidor tarda en responder, lo comprueba con menos frecuencia. |
| Perder la conexión | Puedes seguir viendo lo último que leyó Spooky, pero no puedes cambiar nada hasta que se reconecte. |
| :ui[action.revealFinder] | El Finder necesita una carpeta en tu Mac que muestre los archivos del servidor. Consulta [Ubicación en este Mac](/guide/server/local-location/). |
| :ui[action.openTerminal] | Terminal inicia sesión en el servidor con `ssh` y va a la carpeta del repositorio. |
| :ui[action.copyPath] | La ruta copiada empieza por el alias de host, como en `driftwood-server:/srv/git/driftwood`. |
| Abrir un archivo en otra app | La mayoría de las apps reciben una copia del archivo. Spooky escribe tus cambios en el servidor cuando guardas. Consulta [Terminal y otras apps](/guide/server/local-location/#terminal). |
| Descartar o eliminar archivos | Spooky pregunta antes de descartar cambios, porque eso sobrescribe archivos en el servidor. Los archivos eliminados y los archivos nuevos descartados van a la papelera del servidor. Si el servidor no tiene papelera, Spooky pregunta antes y después los elimina definitivamente. |
| Ajustes de :ui[settings.environment] | Solo se aplican al Git de tu Mac. El Git de un servidor usa el entorno del propio servidor. Consulta [Entorno](/guide/settings/general/#environment). |

Puedes desactivar las confirmaciones para descartar cambios, eliminar archivos definitivamente y restaurar archivos en :ui[app.name > settings.title] › :ui[settings.general]. Consulta [Confirmaciones](/guide/settings/general/#confirmations).

## Consulta también

- [Preparar SSH](/guide/server/prepare-ssh/)
- [Añadir repositorio de servidor](/guide/server/add/)
- [Requisitos del sistema](/reference/requirements/)
