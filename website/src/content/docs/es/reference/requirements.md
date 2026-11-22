---
title: "Requisitos del sistema"
description: "Consulta qué necesita Spooky de macOS, de Git y de tus servidores."
---

Esta página recoge lo que Spooky necesita en tu Mac y en los servidores a los que te conectas.

## Mac {#mac}

| Qué | Requisito |
|---|---|
| macOS | macOS 26 o posterior |
| Git | Git 2.41.0 o posterior. Spooky usa `/usr/bin/git` salvo que elijas otro junto a :ui[settings.gitProgram] en :ui[app.name > settings.title] › :ui[settings.gitConfig]. Consulta [Programa de Git](/guide/settings/identity/#git-program). |
| SSH | El SSH que viene con macOS. Los repositorios de servidor lo usan para conectarse. |

Spooky depende de funciones de Git añadidas en la versión 2.41.0, así que las versiones anteriores no sirven.

## Servidores {#servers}

Un servidor puede ser una máquina con Linux o un Mac. Spooky no necesita acceso de administrador en él, y no instala ningún servicio.

| Qué | Requisito |
|---|---|
| Inicio de sesión | Inicio de sesión por SSH con una clave, mediante un alias de host de `~/.ssh/config` en tu Mac. Una cuenta que solo puede iniciar sesión con contraseña no sirve. Consulta [Preparar SSH](/guide/server/prepare-ssh/). |
| Git | Git 2.41.0 o posterior, en el `PATH` que usan los inicios de sesión SSH no interactivos |
| Servidor SSH | OpenSSH con SFTP activado y el reenvío de sockets Unix permitido. Los dos lo están de forma predeterminada. `MaxSessions` tiene que ser 10 o más, que también es el valor predeterminado. |
| Solicitudes de frase de contraseña | OpenSSH 8.4 o posterior, si Git en el servidor necesita la frase de contraseña de una clave SSH |
| Perl | `/usr/bin/perl` con sus módulos estándar `IO::Socket::UNIX`, `JSON::PP`, `POSIX` y `Fcntl` |
| Archivos | Permiso de escritura en `~/.spooky/bin`, en tu carpeta de inicio del servidor, y en `/tmp` |
| Papelera | Opcional. En un Mac, Spooky usa `/usr/bin/trash`, que viene con macOS 15 y posteriores. En Linux, usa `gio` o `trash-put`. Si no hay ninguno, Spooky pregunta antes y después elimina los archivos definitivamente. |

Para ver qué ofrece un servidor antes de añadir un repositorio, ejecuta la prueba de [Preparar SSH](/guide/server/prepare-ssh/#test). También puedes comprobar un servidor en :ui[app.name > settings.title] › :ui[settings.environment]. Consulta [Comprobar un servidor](/guide/settings/general/#server-check).

## Opcional {#optional}

| Para usar | Necesitas |
|---|---|
| Git LFS | Git LFS 2.9.0 o posterior, en la máquina donde está el repositorio, en el `PATH` que Git usa ahí |
| Montajes sshfs | sshfs y macFUSE o FUSE-T en tu Mac |
| Montajes SMB | Compartir archivos por SMB en el servidor |
| Pull requests y merge requests | Una cuenta en github.com o GitLab.com, o en un GitLab autogestionado 9.0 o posterior |

## Consulta también

- [Instalar Spooky](/guide/start/install/)
- [Cómo funcionan los repositorios de servidor](/guide/server/overview/)
- [Datos y privacidad](/reference/data-privacy/)
