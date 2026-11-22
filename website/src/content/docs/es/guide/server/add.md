---
title: "Añadir repositorio de servidor"
description: "Rellena el diálogo Añadir repositorio de servidor, interpreta los resultados de la comprobación de la conexión, y clona o busca repositorios en el servidor."
---

Al añadir un repositorio de servidor, este pasa a tu lista Repositorios y se abre. Spooky comprueba antes la conexión. Si falta algo, el diálogo te dice qué corregir.

Antes de empezar, asegúrate de que Terminal puede conectarse al servidor sin preguntar nada. Consulta [Preparar SSH](/guide/server/prepare-ssh/).

Para abrir el diálogo, selecciona :ui[action.addRemote] en el menú :ui[menu.file], o en el menú del botón de añadir de la ventana Repositorios.

## Rellenar el diálogo {#dialog}

::screenshot[El diálogo Añadir repositorio de servidor. El alias de host es spooky-test. La ruta del repositorio es /srv/git/driftwood, con un botón para explorar al lado. El montaje en este Mac está definido como No montar. Los botones son para cancelar y abrir.]{name="add-server" frame="dialog"}

| Campo | Qué introducir |
|---|---|
| :ui[remote.host] | El nombre de `Host` de `~/.ssh/config`, como `driftwood-server`. Introduce solo el alias, sin nombre de usuario ni puerto. |
| :ui[remote.path] | La ruta completa del repositorio en el servidor, empezando por `/`, como `/srv/git/driftwood` |
| :ui[remote.mount] | Opcional. Hace que la carpeta del repositorio esté disponible en este Mac, para que el Finder pueda mostrarla. Consulta [Montar al añadir](/guide/server/local-location/#when-adding). |

Si no conoces la ruta, haz clic en :ui[clone.browse] cuando el alias de host esté escrito. Spooky muestra las carpetas del servidor, empezando por la ruta que has introducido o por tu carpeta de inicio allí. Los repositorios de Git llevan la marca :ui[browse.repository]. Las carpetas que no puedes leer aparecen atenuadas. Haz doble clic en una carpeta para entrar en ella y después haz clic en :ui[bookmarks.create.choosePrompt].

También puedes elegir una carpeta de dentro de un repositorio. Spooky abre el repositorio al que pertenece.

:ui[action.open] está disponible cuando el alias de host está escrito y la ruta empieza por `/`.

## La comprobación de la conexión {#check}

Al hacer clic en :ui[action.open], Spooky muestra :ui[remote.checking] en la parte inferior del diálogo y comprueba lo siguiente, en orden:

1. SSH inicia sesión con el alias de host.
2. Git está en el servidor, en la versión 2.41.0 o posterior.
3. La carpeta existe, y puedes abrirla y leerla.
4. La carpeta está en un repositorio de Git, y Git puede leer su estado.

Los campos quedan bloqueados durante la comprobación. Haz clic en :ui[action.cancel] para detenerla y cerrar el diálogo.

Cuando todo es correcto, Spooky prepara su script de ayuda en el servidor, añade el repositorio a la lista Repositorios y lo abre.

## Cuando la comprobación falla {#results}

El diálogo sigue abierto y conserva lo que has escrito. En la parte inferior muestra qué corregir, seguido de la salida original de SSH o de Git. Corrige el problema y vuelve a hacer clic en :ui[action.open].

| Qué ha fallado | Qué hacer |
|---|---|
| El alias de host no es válido | Introduce solo el alias de la línea `Host`, sin espacios, `@`, `:` ni `/`. |
| La huella digital del servidor es desconocida | Conéctate una vez en Terminal y comprueba la huella digital. Consulta [Conectarte una vez](/guide/server/prepare-ssh/#fingerprint). Spooky nunca acepta una huella digital por ti. |
| La huella digital del servidor ha cambiado | No te conectes todavía. Confirma antes el cambio con el propietario del servidor. |
| SSH no puede iniciar sesión | El servidor no acepta tu clave, o tu Mac no puede desbloquearla. Consulta [Probar cómo se conecta Spooky](/guide/server/prepare-ssh/#test). |
| No se puede acceder al servidor | Comprueba el alias de host y tu red, y vuelve a intentarlo. |
| No se encuentra Git | Instala Git 2.41.0 o posterior en el servidor. Si está instalado, los inicios de sesión por SSH no lo encuentran. La salida muestra el `PATH` que usa el servidor. Añádele la carpeta de Git en el archivo de inicio del shell del servidor. |
| Git es demasiado antiguo | Actualiza el Git del servidor a la versión 2.41.0 o posterior. |
| La carpeta no existe | Comprueba la ruta. Para empezar un repositorio nuevo ahí, haz clic en :ui[bookmarks.noRepository.create]. |
| Sin permiso para la carpeta | Tu usuario del servidor necesita permiso para abrir y leer la carpeta. |
| macOS bloquea la carpeta en el servidor | El servidor es un Mac, y el repositorio está en una carpeta protegida como Documentos. Activa el acceso total al disco para usuarios remotos, como en [Usar un Mac como servidor](/guide/server/prepare-ssh/#mac-server), o mueve el repositorio. |
| La carpeta no es un repositorio de Git | Elige la carpeta del repositorio, o haz clic en :ui[bookmarks.noRepository.create] para convertir esta carpeta en uno. Si la salida de Git menciona la propiedad, la carpeta pertenece a otro usuario del servidor. |
| Git no puede leer el estado | La salida de Git, debajo, explica el motivo. |
| No se puede preparar la sesión en el servidor | El SSH del servidor tiene que permitir el reenvío de sockets Unix. El servidor necesita además `/usr/bin/perl`, y tú necesitas acceso de escritura a `~/.spooky/bin` y `/tmp` en él. Consulta [Requisitos del sistema](/reference/requirements/#servers). |

::screenshot[El diálogo Añadir repositorio de servidor con el alias de host spooky-test y la ruta /srv/git/driftwood. Debajo de los campos, una advertencia pide comprobar que la ruta absoluta existe en el servidor seleccionado, seguida de la salida original, “Directory does not exist”. Los botones son para cancelar, crear el repositorio y abrir.]{name="server-add-error" frame="dialog"}

:ui[bookmarks.noRepository.create] ejecuta `git init` en esa carpeta, y antes crea la carpeta si no existe. Después, Spooky comprueba de nuevo la conexión y abre el nuevo repositorio.

Para ver el `PATH` y el Git que usa un servidor sin añadir un repositorio, abre :ui[app.name > settings.title] › :ui[settings.environment]. Introduce el alias de host en la parte inferior y haz clic en :ui[settings.environment.server.check]. Consulta [Comprobar un servidor](/guide/settings/general/#server-check).

## Variables de entorno de Git en el servidor {#environment}

Tras la comprobación, Spooky puede mostrar :ui[remote.environment.title]. El shell no interactivo del servidor define variables cuyo nombre empieza por `GIT_`. Cambian cómo Git encuentra los repositorios y lee sus ajustes, en todos los comandos que Spooky ejecuta allí.

Haz clic en :ui[action.close] y el repositorio se abre. Si Git se comporta en él de forma inesperada, quita esas variables de los archivos de inicio del shell del servidor.

## Clonar y buscar en un servidor {#clone-scan}

Hay otras dos formas de llevar un repositorio de servidor a la lista:

- **Clonar:** En el diálogo de clonación, selecciona un servidor en :ui[clone.to]. Git clona el repositorio en el servidor, y Spooky lo añade como repositorio de servidor. Consulta [Clonar un repositorio](/guide/repositories/manager/#clone).
- **Buscar:** Selecciona :ui[scan.menu] en el menú del botón de añadir y después un servidor en :ui[scan.in]. Spooky busca en la carpeta del servidor y muestra los repositorios que encuentra. Consulta [Buscar repositorios](/guide/repositories/manager/#scan).

## Consulta también

- [Preparar SSH](/guide/server/prepare-ssh/)
- [Estado de la conexión y reconexión](/guide/server/connection/)
- [Ubicación en este Mac](/guide/server/local-location/)
