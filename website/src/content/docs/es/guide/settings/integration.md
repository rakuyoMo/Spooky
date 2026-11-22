---
title: "Integración"
description: "Elige herramientas externas de diff y de fusión, editores y terminales, y configura la integración con el Finder."
---

Spooky trabaja con otras apps de tu Mac: tu navegador, las apps de comparación y de fusión, los editores, un terminal y el Finder. Esta página muestra dónde se configura cada una.

## La página Integración {#integration-page}

:ui[app.name > settings.title] › :ui[settings.integration] tiene tres ajustes.

### Enlaces de github.com {#github-links}

En github.com, el botón que abre un repositorio en una app de escritorio envía un enlace a tu Mac. :ui[settings.github] decide qué app lo recibe. El menú muestra las apps de tu Mac que pueden abrir estos enlaces.

Selecciona Spooky, y estos enlaces abrirán el diálogo de clonación. Consulta [Clonar un repositorio](/guide/repositories/navigation/#link-clone).

### Agente SSH {#ssh-agent}

Un agente SSH mantiene listas las claves desbloqueadas. Spooky lo usa para iniciar sesión en servidores y remotos por SSH, y para firmar commits con claves SSH.

:ui[settings.sshAgent] tiene una sola opción, :ui[settings.sshAgent.system]. Spooky lo busca en este orden:

1. `SSH_AUTH_SOCK` entre tus propias variables de la página :ui[settings.environment] (consulta [Variables en este Mac](/guide/settings/general/#local-variables))
2. `SSH_AUTH_SOCK` de tu shell de inicio de sesión, si su lectura está activada allí
3. El agente que macOS inicia por ti

Para usar otro agente, como el de un gestor de contraseñas, define `SSH_AUTH_SOCK` en la página :ui[settings.environment] o en tu shell de inicio de sesión.

Si el agente no está en ejecución, aparece un botón de advertencia amarillo junto al menú. Haz clic en él para ver qué hacer.

:::note[Repositorios de servidor]
Spooky nunca reenvía tu agente a un servidor. El Git del servidor usa el agente y las claves de esa máquina.
:::

### Informes de fallos {#crash-reports}

Si Spooky se cerró de forma inesperada la última vez, al abrirlo de nuevo pregunta si quieres informar del fallo. Selecciona :ui[settings.crashReports.always] para saltarte la pregunta y abrir directamente la página de incidencias. Está desactivado al principio.

Consulta en [Informes de fallos](/reference/data-privacy/#crash-reports) qué contiene el informe.

## Herramientas de comparación y de fusión {#diff-merge-tools}

Las herramientas se definen en la página :ui[settings.gitConfig].

| Ajuste | Qué hace |
|---|---|
| :ui[externalTool.diffTool] | La app que compara archivos. Al principio, :ui[externalTool.noneSelected]. |
| :ui[externalTool.directoryDiff] | Cuando comparas varios archivos, los abre como dos carpetas en una sola ventana. Solo Kaleidoscope lo admite. Las demás apps abren los archivos de uno en uno. Activado al principio. |
| :ui[externalTool.mergeTool] | La app que resuelve conflictos. Al principio, :ui[externalTool.noneSelected]. |
| :ui[externalTool.keepBackups] | Conserva el archivo tal como estaba antes de la fusión, a su lado y con `.orig` al final. Desactivado al principio. |

Spooky funciona con estas apps:

| App | Comparar | Fusionar |
|---|---|---|
| Araxis Merge | Sí | Sí |
| BBEdit | Sí | No |
| Beyond Compare | Sí | Sí |
| DeltaWalker | Sí | Sí |
| FileMerge | Sí | Sí |
| Kaleidoscope | Sí | Sí |
| P4Merge | Sí | Sí |
| TextMate | Sí | No |
| Visual Studio Code | Sí | Sí |

Los menús muestran también las apps que no están instaladas, pero no puedes elegirlas. Si usas una herramienta antes de elegir una, Spooky pregunta qué app usar.

Para usarlas, consulta [Comparar en otra app](/guide/work/diff/#external) y [Fusionar en otra app](/guide/work/conflicts/#merge-tool).

## Editores {#editors}

Spooky no tiene un ajuste de editor propio. Para abrir un archivo en otra app, haz clic derecho en él en la copia de trabajo y selecciona :ui[files.open] o :ui[files.openWith]. El submenú :ui[files.openWith] muestra las apps que pueden abrir el archivo, con la app predeterminada primero. El mismo submenú está en el árbol de archivos de un commit y en el asistente de conflictos.

En un repositorio de servidor, Visual Studio Code, Visual Studio Code Insiders y Cursor abren el archivo directamente en el servidor, si tienen instalada su extensión Remote SSH. Las demás apps reciben una copia. Cuando guardas, Spooky escribe tus cambios en el servidor. Consulta [Terminal y otras apps](/guide/server/local-location/#terminal).

## Terminal {#terminal}

:ui[settings.terminal], en la página :ui[settings.general], elige la app para :ui[action.openTerminal]. Spooky funciona con Terminal, iTerm, Warp, Ghostty, WezTerm y Otty. El menú muestra las que están instaladas. Al principio se usa Terminal.

Encontrarás :ui[action.openTerminal] en estos lugares:

- El menú :ui[menu.file]
- :ui[toolbar.terminal] en la barra de herramientas
- El menú de la copia de trabajo en la barra lateral
- El menú de un archivo o una carpeta en la lista de archivos de la copia de trabajo. El terminal se abre en esa carpeta, o en la carpeta en la que está el archivo.
- Los menús de los repositorios de la ventana Repositorios y de los clones recientes
- El menú de un worktree en la barra lateral
- Las [acciones rápidas](/guide/repositories/navigation/#quick-actions)

En un repositorio local, el terminal se abre en la carpeta de este Mac. En un repositorio de servidor, inicia sesión con SSH y va a la carpeta del servidor. Consulta [Terminal y otras apps](/guide/server/local-location/#terminal).

La primera vez que Spooky abre Terminal o iTerm, macOS pregunta si Spooky puede controlarlo. Si no lo permites, Spooky muestra :ui[error.terminal]. Para permitirlo más tarde, ve a **menú Apple › Ajustes del Sistema › Privacidad y seguridad › Automatización** y activa la app bajo Spooky.

## Finder {#finder}

- **Mostrar una carpeta**: :ui[action.revealFinder] muestra la carpeta del repositorio o un archivo en el Finder. En un repositorio de servidor, necesita una ubicación en este Mac. Consulta [Mostrar en el Finder](/guide/server/local-location/#show-in-finder).
- **Añadir repositorios**: arrastra carpetas de repositorios desde el Finder a la ventana Repositorios. Consulta [Añadir repositorios](/guide/repositories/manager/#add).
- **El Dock**: suelta una carpeta sobre el icono de Spooky para abrir el repositorio en el que está. Haz clic derecho en el icono para elegir un repositorio reciente, incluidos los repositorios de servidor. Consulta [Repositorios recientes y el Dock](/guide/repositories/navigation/#recent).
- **Temas**: abre un archivo `.spookytheme` en el Finder para añadir el tema. Consulta [Compartir temas](/guide/settings/appearance/#share-themes).

## Consulta también

- [General, actualizaciones y entorno](/guide/settings/general/)
- [Perfiles de usuario y configuración de Git](/guide/settings/identity/)
- [Ubicación en este Mac](/guide/server/local-location/)
- [Preparar SSH](/guide/server/prepare-ssh/)
