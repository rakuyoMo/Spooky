---
title: "Perfiles de usuario y configuración de Git"
description: "Gestiona los perfiles de usuario y la configuración de Git, y ajusta las opciones de un solo repositorio."
---

Git registra un nombre y un correo con cada commit, y puede firmarlo con una clave. Spooky te ofrece tres lugares para configurarlos:

- :ui[settings.profiles], en :ui[app.name > settings.title], guarda las identidades entre las que cambias.
- :ui[settings.gitConfig], en :ui[app.name > settings.title], define el programa de Git y tu identidad y tu firma globales.
- Los ajustes de un solo repositorio tienen prioridad sobre los globales en ese repositorio.

## Perfiles de usuario {#profiles}

Un perfil de usuario es un nombre, un correo y una clave de firma opcional, guardados bajo un título como “Work”. Spooky guarda los perfiles en este Mac. Puedes usarlos tanto en repositorios locales como en repositorios de servidor.

Para añadir un perfil:

1. Selecciona :ui[app.name > settings.title] › :ui[settings.profiles].
2. Haz clic en el botón de añadir que hay debajo de la lista.
3. Rellena los campos :ui[profiles.title], :ui[profiles.userName] y :ui[profiles.email]. Si quieres, elige una :ui[profiles.signingKey] entre las claves encontradas en este Mac.
4. Haz clic en :ui[profiles.create.submit].

El título, el nombre de usuario y el correo son obligatorios. Dos perfiles no pueden tener el mismo título, ni tener a la vez el mismo nombre de usuario y el mismo correo.

Para cambiar un perfil, selecciónalo y haz clic en :ui[profiles.edit]. Para eliminar uno, selecciónalo y haz clic en el botón de eliminar. Eliminar un perfil no cambia ningún ajuste de Git.

Si la identidad que usas ahora aún no es un perfil, selecciona :ui[profiles.addCurrent]{1="alex@example.com"} en su menú. Introduce un título y haz clic en :ui[profiles.add.submit].

### Usar un perfil {#use-profile}

Haz clic en la imagen que hay junto a una identidad para ver tus perfiles, con una marca de verificación junto al que está en uso. Lo que cambia al elegir un perfil depende de dónde lo elijas:

| Dónde | Qué cambia | Pregunta antes |
|---|---|---|
| El área de commit, o :ui[bookmarks.detail.identity] en los [ajustes del repositorio](#repository) | Los ajustes de Git propios de este repositorio. Consulta [Elegir quién hace el commit](/guide/work/commit/#identity). | Sí |
| :ui[settings.gitConfig] en Ajustes | Tus ajustes globales de Git en este Mac | No |

El nombre y el correo del perfil se escriben en `user.name` y `user.email`. Un perfil con clave de firma define además `user.signingkey` y `gpg.format`.

Las [acciones rápidas](/guide/repositories/navigation/#quick-actions) también muestran tus perfiles. :ui[quickActions.setCommitter] funciona como el área de commit. :ui[quickActions.setGlobalUser] define, tras preguntar, el nombre y el correo en tus ajustes globales de Git de la máquina en la que está el repositorio.

:::note[Repositorios de servidor]
Elegir un perfil para un repositorio de servidor cambia los ajustes del repositorio en el servidor. Las demás herramientas que hacen commit allí usan la misma identidad. En un repositorio de servidor, :ui[quickActions.setGlobalUser] escribe en tus ajustes globales del servidor.
:::

## Configuración de Git {#git-config}

La página :ui[settings.gitConfig] tiene cuatro partes: el programa de Git, tu identidad, la firma y las herramientas externas. Las herramientas se explican en [Integración](/guide/settings/integration/#diff-merge-tools).

::screenshot[La página Configuración de Git de la ventana Ajustes, con el binario de Git, el nombre y el correo globales, los ajustes de firma y las herramientas de comparación y de fusión.]{name="settings-git-config" frame="window" markers="18,15.7 18,27.4 18,42.9 18,81.7"}

1. El programa de Git
2. Tu identidad
3. La firma
4. Las herramientas externas

### Programa de Git {#git-program}

:ui[settings.gitProgram] muestra los programas de Git de este Mac que son lo bastante recientes, con sus versiones. Spooky busca en los lugares habituales: `/usr/bin/git` (marcado como el del sistema, y el que se usa al principio), Command Line Tools, Xcode, Homebrew y MacPorts.

Para usar un Git que no está en la lista, selecciona :ui[settings.gitProgram.choose] y elige el programa. Si el archivo no es Git, o su versión es demasiado antigua, Spooky te dice por qué y conserva el que tenías. La línea de debajo del menú muestra la versión mínima que acepta Spooky.

:::note[Repositorios de servidor]
Este ajuste solo se aplica a los repositorios locales. Los repositorios de servidor usan el Git del servidor. Consulta [Requisitos del sistema](/reference/requirements/#servers).
:::

### Identidad global {#global-identity}

:ui[gitConfig.userName] y :ui[gitConfig.email] son los valores globales `user.name` y `user.email` de Git. Todos los repositorios de este Mac los usan, salvo que tengan los suyos.

Los cambios se guardan cuando pulsas <kbd>Retorno</kbd> o sales del campo. Vaciar un campo quita el ajuste. La línea de debajo muestra en qué archivo se guardan, normalmente `~/.gitconfig`.

Haz clic en la imagen de la derecha para elegir un [perfil](#use-profile) o gestionarlos.

### Firma {#signing}

Estos ajustes deciden cómo firma Git los commits en todos los repositorios de este Mac que no definen los suyos.

| Ajuste | Qué hace |
|---|---|
| :ui[gitConfig.sshProgram] | El programa que firma con claves SSH. Al principio se usa :ui[gitConfig.sshProgram.system]. Si 1Password está instalado, su programa de firma también aparece. |
| :ui[gitConfig.gpgProgram] | El programa GnuPG para las claves OpenPGP. Muestra las versiones de este Mac que son lo bastante recientes. Selecciona :ui[gitConfig.gpgProgram.select] para elegir otro. |
| :ui[gitConfig.signingKey] | La clave con la que firmar: una clave secreta de tu anillo de claves de GnuPG, o una clave cargada en el agente SSH. Elegir una clave indica además a Git si debe firmar con OpenPGP o con SSH. |
| :ui[gitConfig.allowedSigners] | El archivo con las claves SSH en cuyas firmas confías, que se usa cuando Git comprueba las firmas. Selecciona `~/.ssh/allowed_signers`, elige otro archivo o selecciona :ui[gitConfig.allowedSigners.none]. |
| :ui[gitConfig.signCommits] | Firma todos los commits |
| :ui[gitConfig.ensureEmailMatch] | Avisa cuando el correo de la clave OpenPGP no es tu correo global. Activado al principio. |

Cuando algo necesita tu atención, como un programa de firma que no se puede ejecutar, aparece un botón de advertencia amarillo junto al ajuste. Haz clic en él para ver qué pasa.

Los commits firmados y la solicitud de la frase de contraseña se explican en [Firmar commits](/guide/work/commit/#signing).

## Ajustes del repositorio {#repository}

Cada repositorio tiene sus propios ajustes. Para verlos, haz clic en :ui[repositorySettings.title] bajo :ui[workspace.group] en la barra lateral. Los botones de arriba cambian entre cuatro secciones.

Los cambios se escriben en los ajustes de Git propios del repositorio, y esperan en la cola con las demás operaciones del repositorio. Todo lo que un repositorio no define viene de tus ajustes globales.

::screenshot[Los ajustes del repositorio en la ventana principal, en la pestaña General, con el nombre, la ruta, la descripción, la identidad y los ajustes de firma del repositorio.]{name="settings-repository" frame="window" markers="70.4,9.8 60,38.8"}

1. Los botones que cambian de sección
2. :ui[bookmarks.detail.identity]

### General {#repository-general}

| Ítem | Qué muestra |
|---|---|
| :ui[repositorySettings.name] y :ui[repositorySettings.path] | Dónde está el repositorio |
| :ui[repositorySettings.localLocation] | En los repositorios de servidor, dónde está la carpeta del repositorio en este Mac. Consulta [Definir la ubicación](/guide/server/local-location/#set). |
| :ui[bookmarks.detail.description] | Una descripción del repositorio, que también aparece en [la ventana Repositorios](/guide/repositories/manager/). Haz clic en :ui[bookmarks.detail.edit] para cambiarla. |
| :ui[bookmarks.detail.identity] | El nombre y el correo con los que hace commit este repositorio. Haz clic en la imagen para usar un [perfil](#use-profile), o en :ui[bookmarks.detail.edit] para escribir un nombre y un correo solo para este repositorio. |

Bajo :ui[repositorySettings.signing], :ui[repositorySettings.signCommits], :ui[repositorySettings.signingKey] y :ui[repositorySettings.allowedSigners] funcionan como los [globales](#signing), solo para este repositorio.

### Git LFS, archivos ignorados y excluidos {#repository-files}

- :ui[repositorySettings.lfs] muestra la versión de Git LFS y los :ui[repositorySettings.lfs.patterns]. Consulta [Git LFS](/guide/advanced/lfs/).
- :ui[repositorySettings.ignores] muestra las reglas del `.gitignore` del nivel superior del repositorio. Haz commit de este archivo para compartir las reglas con los demás.
- :ui[repositorySettings.excludes] muestra las reglas del `info/exclude` de Git. Solo se aplican a esta copia del repositorio.

Haz clic en :ui[repositorySettings.openInEditor] para cambiar las reglas. El archivo se abre en la app que tu Mac usa para él. Si el archivo aún no existe, Spooky lo crea antes.

:::note[Repositorios de servidor]
Los ajustes se leen y se escriben en el servidor. Solo puedes cambiarlos mientras el repositorio está conectado. :ui[repositorySettings.openInEditor] abre el archivo igual que la copia de trabajo abre los archivos del servidor. Consulta [Terminal y otras apps](/guide/server/local-location/#terminal).
:::

## Consulta también

- [Hacer commit de los cambios](/guide/work/commit/)
- [General, actualizaciones y entorno](/guide/settings/general/)
- [Integración](/guide/settings/integration/)
- [Requisitos del sistema](/reference/requirements/)
