---
title: "Instalar Spooky"
description: "Comprueba los requisitos del sistema, descarga Spooky, ábrelo por primera vez, mantenlo actualizado, elige su idioma y desinstálalo."
---

Esta página te lleva desde la descarga de Spooky hasta abrirlo por primera vez. También trata las actualizaciones, el idioma de la interfaz y cómo eliminar Spooky.

## Requisitos del sistema {#requirements}

- macOS 26 o posterior
- Git 2.41 o posterior

Spooky usa el Git de `/usr/bin/git` salvo que elijas otro. Para elegirlo, abre :ui[app.name > settings.title] (<kbd>⌘,</kbd>), haz clic en :ui[settings.gitConfig] y selecciona un programa en el menú :ui[settings.gitProgram]. El menú muestra los programas de Git que Spooky ha encontrado y que son lo bastante recientes. Selecciona :ui[settings.gitProgram.choose] para usar uno de otro lugar. La versión mínima aparece debajo del menú. Consulta [Programa de Git](/guide/settings/identity/#git-program).

:::note[Repositorios de servidor]
El servidor también necesita Git 2.41 o posterior. Spooky accede a él por SSH con un alias de host de `~/.ssh/config`. El Git que eliges en Ajustes solo se aplica a los repositorios de tu Mac. Los repositorios de servidor usan el Git del servidor. Consulta [Requisitos del sistema](/reference/requirements/) y [Preparar SSH](/guide/server/prepare-ssh/).
:::

## Descargar {#download}

1. Abre la [página de versiones de Spooky](https://github.com/rakuyoMo/Spooky/releases) en GitHub.
2. Busca la versión estable más reciente. Su nombre es `v` seguido del número de versión. Las versiones marcadas como **Pre-release** son versiones beta y alfa, y su número de versión termina en `-beta.` o `-alpha.` seguido de un número.
3. Descarga el archivo zip llamado `Spooky-` seguido del número de versión.
4. Haz doble clic en el archivo zip descargado para descomprimirlo.
5. Arrastra Spooky a tu carpeta **Aplicaciones**.

## Abrir Spooky por primera vez {#first-launch}

Spooky no está certificado por Apple. La primera vez que lo abres, macOS lo bloquea y muestra un aviso. Para abrirlo de todos modos:

1. Haz doble clic en Spooky en tu carpeta **Aplicaciones**. Cuando aparezca el aviso, ciérralo.
2. Selecciona **menú Apple › Ajustes del Sistema** y haz clic en **Privacidad y seguridad** en la barra lateral. Puede que tengas que desplazarte hacia abajo.
3. Ve a **Seguridad** y haz clic en **Abrir igualmente**. El botón está disponible durante una hora aproximadamente después de intentar abrir Spooky.
4. Introduce tu contraseña de inicio de sesión y haz clic en **Aceptar**.

macOS recuerda tu elección. A partir de entonces, Spooky se abre con normalidad. Empieza con la ventana Repositorios. [Un recorrido por Spooky](/guide/start/tour/) explica lo que ves en ella.

## Mantener Spooky actualizado {#updates}

De forma predeterminada, Spooky busca actualizaciones por su cuenta. :ui[app.name > updates.check] las busca en el momento.

Todas las actualizaciones están firmadas. Spooky comprueba la firma antes de instalar una actualización. Si una actualización no supera la comprobación, no sustituye a la copia que tienes.

Para cambiar cómo se actualiza Spooky, abre :ui[app.name > settings.title] y haz clic en :ui[settings.updates]:

| Ajuste | Qué hace |
|---|---|
| :ui[updates.channel] | Qué versiones recibes. Consulta [Canales de versiones](#channels). |
| :ui[updates.automaticChecks] | Busca actualizaciones en segundo plano. Activado de forma predeterminada. |
| :ui[updates.automaticDownloads] | Descarga las actualizaciones en segundo plano y las instala al salir de Spooky. Desactivado de forma predeterminada. Solo disponible si la búsqueda automática está activada y Spooky está en una carpeta en la que puedes escribir. |
| :ui[updates.interval] | Cada cuánto se buscan: :ui[updates.interval.hourly], :ui[updates.interval.daily] o :ui[updates.interval.weekly]. El valor predeterminado es cada día. Solo disponible si la búsqueda automática está activada. |

La última fila, :ui[updates.lastCheck], muestra cuándo buscó Spooky por última vez. Si aún no ha buscado, pone :ui[updates.never].

### Canales de versiones {#channels}

| Canal | Recibes |
|---|---|
| :ui[updates.channel.stable] | Las versiones estables. Es el valor predeterminado. |
| :ui[updates.channel.beta] | Las versiones estables y las beta |
| :ui[updates.channel.development] | Todas las versiones, incluidas las alfa |

### Qué ha cambiado {#whats-new}

La primera vez que inicias una versión nueva de Spooky, las ventanas de repositorio muestran :ui[whatsNew.card.title] en la parte inferior de la barra lateral. Haz clic en :ui[whatsNew.card.learnMore] para leer qué ha cambiado. También puedes cerrar la tarjeta sin más.

Para leer las notas más tarde, selecciona :ui[menu.help > help.whatsNew]. :ui[menu.help > help.releaseNotes] abre las versiones en GitHub.

## Elegir el idioma de la interfaz {#language}

Spooky está disponible en inglés, chino simplificado, chino tradicional, japonés, coreano, alemán, francés y español. Sigue el orden de idiomas que has definido en macOS. Si ninguno de tus idiomas está disponible, usa el inglés.

Para usar otro idioma solo en Spooky:

1. Selecciona **menú Apple › Ajustes del Sistema** y haz clic en **General** en la barra lateral.
2. Haz clic en **Idioma y región** y ve a **Aplicaciones**.
3. Haz clic en el botón **Añadir**, selecciona Spooky y un idioma, y haz clic en **Añadir**.
4. Si Spooky está abierto, sal de él y vuelve a abrirlo.

Para volver al idioma del sistema, selecciona Spooky en la misma lista y haz clic en el botón **Eliminar**.

## Desinstalar {#uninstall}

1. Sal de Spooky con :ui[app.name > menu.quit] (<kbd>⌘Q</kbd>).
2. Mueve Spooky de tu carpeta **Aplicaciones** a la **Papelera**.

Tus ajustes y datos se quedan en tu Mac. Para eliminarlos también:

- Ajustes: ejecuta `defaults delete com.rakuyo.spooky` en **Terminal**.
- Otros datos, como tus temas y los registros de Actividad: elimina la carpeta `~/Library/Application Support/Spooky/`.
- Cachés: elimina la carpeta `~/Library/Caches/com.rakuyo.spooky/` y los ítems de `~/Library/HTTPStorages/` cuyo nombre empieza por `com.rakuyo.spooky`.
- Contraseñas y tokens que ha guardado Spooky: elimina los ítems de tu llavero cuyo nombre empieza por `com.rakuyo.spooky.`.
- En cada servidor que has usado: elimina la carpeta `~/.spooky/` de tu carpeta de inicio en él.

Los repositorios conservan las entradas `branch.<name>.spooky-*` que Spooky añadió a su configuración de Git. [Datos y privacidad](/reference/data-privacy/) detalla qué guarda Spooky y dónde.

## Consulta también

- [Un recorrido por Spooky](/guide/start/tour/)
- [Requisitos del sistema](/reference/requirements/)
- [Datos y privacidad](/reference/data-privacy/)
