---
title: "Guía del usuario"
description: "Descubre cómo está organizada esta guía y por dónde empezar a leer."
---

Esta guía explica cómo hacer el trabajo diario con Git en Spooky. Abarca los repositorios de tu Mac y los que se quedan en otra máquina a la que accedes por SSH. Cada página trata un tipo de tarea y empieza diciendo para qué te sirve.

Si acabas de empezar con Spooky, lee en orden las páginas de Primeros pasos. Si tus repositorios están en un servidor, sigue con Repositorios de servidor.

En Spooky, :ui[menu.help > help.help] (<kbd>⌘?</kbd>) abre este sitio web. Muchos diálogos tienen además un botón de ayuda, que abre la parte de esta guía dedicada a ese diálogo.

## Cómo está organizada la guía {#organization}

| Grupo | De qué trata |
|---|---|
| [Primeros pasos](/guide/start/install/) | Instalar y actualizar Spooky, las partes de sus ventanas, y un primer commit y push |
| [Repositorios](/guide/repositories/manager/) | Tener a mano tus repositorios, ventanas y pestañas, ir atrás y adelante, y las acciones rápidas |
| [Repositorios de servidor](/guide/server/overview/) | Cómo trabaja Spooky con los repositorios de un servidor, preparar SSH, añadir un repositorio de servidor, la conexión y la ubicación en este Mac |
| [Trabajo diario](/guide/work/working-copy/) | La copia de trabajo, revisar y añadir cambios al stage, hacer commit, stashes, conflictos y deshacer |
| [Historial](/guide/history/browse/) | Explorar el historial, detalles del commit, historial del archivo y blame, y reescribir el historial |
| [Ramas y sincronización](/guide/branches/branches/) | Ramas, etiquetas y remotos, fetch, pull y push, fusionar y hacer rebase, y poner orden en las ramas |
| [Colaboración](/guide/hosting/accounts/) | Cuentas de alojamiento, pull requests y merge requests |
| [Más funciones de Git](/guide/advanced/submodules/) | Submódulos, worktrees, Git LFS y cómo se ponen en cola las operaciones |
| [Ajustes e integración](/guide/settings/general/) | Ajustes, apariencia y temas, perfiles de usuario y configuración de Git, y el trabajo con otras apps |
| [Referencia](/reference/shortcuts/) | Atajos de teclado, requisitos del sistema, datos y privacidad, y solución de problemas |

## Convenciones {#conventions}

### Nombres en pantalla {#names}

Los nombres de botones, menús, opciones y ventanas van en negrita, como :ui[working.commit]. Salen directamente de Spooky. Si usas Spooky en el idioma de esta página, verás los mismos nombres en pantalla.

Una ruta de menú como :ui[menu.file > action.openLocal] significa: haz clic en el primer nombre en la barra de menús y selecciona el siguiente en ese menú.

Algunas páginas nombran también partes de macOS, como **Ajustes del Sistema**. Están escritas tal como las muestra macOS.

### Atajos de teclado {#shortcuts}

Los atajos se muestran como teclas, por ejemplo <kbd>⇧⌘A</kbd>. Mantén pulsadas las teclas modificadoras y pulsa la última tecla. Los símbolos son los mismos que macOS muestra en sus menús.

| Símbolo | Tecla |
|---|---|
| <kbd>⌘</kbd> | Comando |
| <kbd>⇧</kbd> | Mayúsculas |
| <kbd>⌥</kbd> | Opción |
| <kbd>⌃</kbd> | Control |
| <kbd>↩</kbd> | Retorno |
| <kbd>⌫</kbd> | Suprimir |

Todos los atajos están en [Atajos de teclado](/reference/shortcuts/).

### Notas sobre los repositorios de servidor {#server-notes}

Un repositorio de servidor se queda en otra máquina, y Spooky lo abre por SSH. La mayoría de las tareas funcionan igual en ellos. Cuando algo cambia, la página lo indica en una nota como esta:

:::note[Repositorios de servidor]
Una nota con este título te dice qué es distinto en un repositorio de servidor. Si solo usas repositorios en tu Mac, puedes saltarte estas notas.
:::

## Consulta también

- [Instalar Spooky](/guide/start/install/)
- [Un recorrido por Spooky](/guide/start/tour/)
- [Cómo funcionan los repositorios de servidor](/guide/server/overview/)
