---
title: "Preparar SSH"
description: "Configura una clave SSH y un alias de host en ~/.ssh/config, y asegúrate de que puedes conectarte desde Terminal antes de añadir un repositorio de servidor."
---

Spooky inicia sesión en un servidor con SSH, igual que Terminal. No puede escribir una contraseña por ti, así que necesita una clave SSH. Esta página configura una clave y un nombre corto para el servidor, y después comprueba que Terminal se conecta sin preguntar nada. Cuando eso funciona, Spooky también puede conectarse.

Si `ssh` ya te deja iniciar sesión en el servidor sin contraseña, pasa a [Probar cómo se conecta Spooky](#test).

## Qué necesitas {#before}

- Una cuenta en el servidor en la que puedas iniciar sesión con SSH. Pregunta al propietario del servidor si no estás seguro.
- Git 2.41.0 o posterior en el servidor.
- La app **Terminal** en tu Mac.

Los comandos de esta página se escriben en Terminal. Escribe o pega cada uno y pulsa Retorno.

## Comprobar si tienes una clave {#key-check}

Una clave SSH es un par de archivos. La clave privada se queda en tu Mac. La clave pública termina en `.pub` y va al servidor.

```sh
ls ~/.ssh
```

Si en la lista están `id_ed25519` e `id_ed25519.pub`, ya tienes una clave. Pasa a [Añadir un alias de host](#alias). Otro par, como `id_rsa` e `id_rsa.pub`, también sirve. Usa su nombre en lugar de `id_ed25519` en los pasos siguientes.

Si ves “No such file or directory”, o no hay ningún par de claves en la lista, crea uno.

## Crear una clave {#create-key}

```sh
ssh-keygen -t ed25519 -C "alex@example.com"
```

Pon tu propia dirección de correo entre las comillas. Es solo una etiqueta que te ayuda a reconocer la clave.

1. Cuando te pregunte dónde guardar la clave, pulsa Retorno para mantener el lugar sugerido.
2. Introduce una frase de contraseña y vuelve a introducirla. No se muestra nada mientras escribes. La frase de contraseña protege la clave si alguien copia el archivo.

Al terminar, `~/.ssh` contiene `id_ed25519` e `id_ed25519.pub`.

## Añadir un alias de host {#alias}

Un alias de host es un nombre corto para un servidor. Lo escribes en Terminal y en Spooky, en lugar de la dirección del servidor y tu nombre de usuario. Los alias van en el archivo `~/.ssh/config`.

1. Abre el archivo en TextEdit. Este comando crea el archivo si aún no existe:

   ```sh
   touch ~/.ssh/config && open -e ~/.ssh/config
   ```

2. Añade estas líneas al final, con tus propios datos:

   ```
   Host driftwood-server
       HostName 203.0.113.10
       User alex
       IdentityFile ~/.ssh/id_ed25519
       AddKeysToAgent yes
       UseKeychain yes
   ```

3. Guarda el archivo y cierra TextEdit.

| Línea | Qué poner |
|---|---|
| `Host` | El alias. Usa una sola palabra sin espacios, `@`, `:` ni `/`, y que no empiece por `-`. |
| `HostName` | La dirección o el nombre del servidor, como `203.0.113.10` o `server.example.com` |
| `User` | Tu nombre de usuario en el servidor |
| `IdentityFile` | La clave privada que has creado o encontrado antes |
| `AddKeysToAgent`, `UseKeychain` | La primera vez que escribes la frase de contraseña, tu Mac la guarda en el llavero. Después, SSH desbloquea la clave sin preguntar. Spooky depende de esto, porque nunca pide la frase de contraseña al iniciar sesión. |

Si el SSH del servidor usa un puerto distinto del 22, añade una línea como `Port 2222`.

## Conectarte una vez {#fingerprint}

La primera vez que te conectas a un servidor, SSH te pide que confirmes la huella digital del servidor. Spooky nunca acepta una huella digital por ti, así que hazlo antes en Terminal.

```sh
ssh driftwood-server
```

1. SSH muestra la huella digital del servidor, una línea que empieza por `SHA256:`, y pregunta si quieres continuar.
2. Compárala con la huella digital que te dé el propietario del servidor. En el servidor, este comando la muestra:

   ```sh
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

3. Si coinciden, escribe `yes` y pulsa Retorno. Tu Mac recuerda el servidor y no volverá a preguntar.

Lo que ocurre después depende del servidor:

- Si SSH pide la frase de contraseña de tu clave, introdúcela. Tu Mac la guarda en el llavero.
- Si has iniciado sesión, tu clave ya está en el servidor. Escribe `exit` y pasa a [Probar cómo se conecta Spooky](#test).
- Si SSH pide tu contraseña del servidor, pulsa <kbd>⌃C</kbd> por ahora. El paso siguiente pone tu clave en el servidor.

:::caution
Si SSH avisa de que la identificación del host remoto ha cambiado, no continúes. Pregunta al propietario del servidor si el servidor se ha reinstalado o sustituido.
:::

## Poner la clave pública en el servidor {#copy-key}

Si puedes iniciar sesión en el servidor con una contraseña, este comando copia allí tu clave pública. Introduce tu contraseña del servidor cuando te la pida.

```sh
ssh-copy-id -i ~/.ssh/id_ed25519.pub driftwood-server
```

Si el servidor no admite contraseñas, envía tu clave pública al propietario del servidor. Este comando la copia al portapapeles:

```sh
pbcopy < ~/.ssh/id_ed25519.pub
```

Pídele que la añada a `~/.ssh/authorized_keys` en tu carpeta de inicio del servidor. La clave pública se puede compartir sin riesgo. Nunca envíes el archivo sin `.pub`.

## Probar cómo se conecta Spooky {#test}

```sh
ssh -o BatchMode=yes driftwood-server git --version
```

Este comando inicia sesión igual que Spooky, sin preguntar nada. Funciona si muestra enseguida una versión 2.41.0 o posterior, como `git version 2.47.1`. Ya puedes [añadir el repositorio de servidor](/guide/server/add/).

Si muestra otra cosa:

| Qué ves | Qué hacer |
|---|---|
| `Permission denied` | El servidor aún no acepta tu clave, o tu Mac no puede desbloquearla. Revisa [Poner la clave pública en el servidor](#copy-key) y [Después de reiniciar tu Mac](#after-restart). |
| `Host key verification failed` | Tu Mac aún no conoce el servidor. Consulta [Conectarte una vez](#fingerprint). |
| `Could not resolve hostname`, `Connection refused` u `Operation timed out` | Revisa `HostName` y `Port` en `~/.ssh/config`, y asegúrate de que el servidor está encendido y accesible. |
| Un mensaje con `command not found` | Git no está instalado en el servidor, o los inicios de sesión por SSH no lo encuentran. Pregunta al propietario del servidor. |
| Una versión anterior a la 2.41.0 | Pide al propietario del servidor que actualice Git. |

## Después de reiniciar tu Mac {#after-restart}

Si la prueba funcionaba antes pero falla con `Permission denied` tras un reinicio, vuelve a cargar tu clave. Las claves cuya frase de contraseña está guardada en el llavero se cargan con:

```sh
ssh-add --apple-load-keychain
```

## Usar otro agente SSH {#agent}

Un agente SSH mantiene las claves desbloqueadas listas para SSH. Spooky usa el agente del sistema, el que macOS inicia por ti. Si tus claves están en otro agente, por ejemplo el de un gestor de contraseñas, define `SSH_AUTH_SOCK` con el socket de ese agente. Añádela como variable personalizada en :ui[app.name > settings.title] › :ui[settings.environment], o defínela en tu shell de inicio de sesión. Spooky usará entonces ese agente para iniciar sesión en los servidores. Consulta [Agente SSH](/guide/settings/integration/#ssh-agent).

## Usar un Mac como servidor {#mac-server}

Otro Mac puede hacer de servidor. En ese Mac:

1. Selecciona **menú Apple › Ajustes del Sistema**, haz clic en **General** y después en **Compartir**.
2. Activa **Sesión remota**.
3. Si el repositorio está en una carpeta protegida, como Documentos o Escritorio, haz clic en el botón de información que hay junto a **Sesión remota** y activa **Permitir acceso total al disco a usuarios remotos**.

Después, sigue esta página desde tu propio Mac, con la dirección de ese Mac en `HostName`.

## Consulta también

- [Cómo funcionan los repositorios de servidor](/guide/server/overview/)
- [Añadir repositorio de servidor](/guide/server/add/)
- [Requisitos del sistema](/reference/requirements/#servers)
