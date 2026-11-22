---
title: "Apariencia y temas"
description: "Elige la apariencia, usa un tema integrado o crea, importa y exporta los tuyos, define las opciones de texto y del editor, y elige un icono para la app."
---

Cuatro páginas de :ui[app.name > settings.title] deciden el aspecto de Spooky: :ui[settings.appearance] para la app en conjunto, :ui[settings.themes] para los colores de los diffs y los archivos, :ui[settings.text] para cómo se muestra el texto, y :ui[settings.editor] para el mensaje del commit.

## Apariencia {#appearance}

Haz clic en una imagen de la fila :ui[settings.appearance.label] para cambiar toda la app:

- :ui[appearance.system] sigue a macOS. Es el valor predeterminado.
- :ui[appearance.light] y :ui[appearance.dark] se mantienen iguales use lo que use macOS.

En una ventana de repositorio, también puedes cambiarla desde las [acciones rápidas](/guide/repositories/navigation/#quick-actions): busca la apariencia y ejecuta :ui[quickActions.setAppearance].

## Icono de la app {#app-icon}

Debajo de la apariencia, :ui[settings.appIcon.label] muestra los iconos que puedes elegir, en dos series:

| Serie | Iconos |
|---|---|
| :ui[appIcon.series.hideAndSeek] | :ui[appIcon.rise] (el icono predeterminado), :ui[appIcon.front], :ui[appIcon.hide], :ui[appIcon.reveal] |
| :ui[appIcon.series.cherryPick] | :ui[appIcon.midnight], :ui[appIcon.perch], :ui[appIcon.cherryPick], :ui[appIcon.armful] |

Pasa el puntero sobre un icono para verlo en grande a la izquierda. Debajo están las cuatro formas en que aparece en el Dock: tal cual, conectado a un servidor, oscuro, y oscuro mientras está conectado. Haz clic en el icono para usarlo. Cuando los iconos tienen el foco del teclado, las teclas de flecha pasan de uno a otro y <kbd>Espacio</kbd> usa aquel en el que estás.

El nuevo icono aparece en el Dock, en el selector de apps (<kbd>⌘Tab</kbd>) y en el Finder, incluso cuando Spooky no está abierto. Algunas cosas que conviene saber:

- Mientras hay un repositorio de servidor conectado, el icono se ilumina. En los iconos de :ui[appIcon.series.hideAndSeek], se encienden las luces del servidor. En los de :ui[appIcon.series.cherryPick], los ojos del fantasma se convierten en estrellas brillantes.
- La versión oscura aparece cuando el estilo de iconos y widgets de **Ajustes del Sistema › Apariencia** es oscuro, o es automático mientras Spooky está en oscuro. Con un estilo transparente o tintado, el icono no se ilumina.
- Cuando cambias a :ui[appIcon.rise] o desde él, el Dock se reinicia una vez. De lo contrario, un Spooky fijado en el Dock seguiría mostrando el icono anterior.
- Spooky guarda cualquier otro icono dentro de `Spooky.app`. Si no puede escribir ahí, la página indica el motivo, y el icono no cambia.

## Temas {#themes}

Un tema define el tipo de letra y los colores que usan los diffs y el contenido de los archivos. Spooky incluye dos: Default para la apariencia clara y Default (Dark) para la oscura.

El tema seleccionado en la lista es el que usa la apariencia actual. La clara y la oscura recuerdan cada una el suyo. Para definir el tema de la otra apariencia, cambia antes a ella. Las acciones rápidas también pueden cambiar de tema, con :ui[quickActions.applyTheme].

::screenshot[La página Temas de la ventana Ajustes. La lista de la izquierda tiene Default y Default (Dark), con Default seleccionado, y los botones de añadir y eliminar abajo. A la derecha hay un campo de tipo de letra con Menlo-Regular 11.0, una lista de tipos de texto como texto sin formato, palabra clave, cadena y comentario, cada uno en su color, y selectores de color para el color de letra, el fondo, la selección, lo añadido y lo eliminado. Debajo hay una breve previsualización de un diff con líneas sin cambios, eliminadas y añadidas.]{name="themes" frame="window" markers="13.3,30 9.4,95.3 58.3,17.8 61.1,37.3 66.7,56.9 61.1,82.7"}

1. La lista de temas
2. :ui[themes.add] y :ui[themes.remove]
3. El tipo de letra
4. Los tipos de texto que distingue el coloreado de sintaxis
5. Los selectores de color
6. Una previsualización de un diff con este tema

### Crear y editar un tema {#edit-theme}

1. Haz clic en el botón de añadir que hay debajo de la lista. Spooky añade :ui[themes.newName], con los colores del tema integrado de la apariencia actual, y selecciona su nombre.
2. Escribe un nombre y pulsa <kbd>Retorno</kbd>.
3. Haz clic en el campo de tipo de letra para elegir un tipo y un tamaño en el panel de tipos de letra.
4. Selecciona un tipo de texto en la lista y haz clic en :ui[themes.text] para cambiar su color. :ui[themes.background], :ui[themes.selection], :ui[themes.added] y :ui[themes.deleted] definen los colores que rodean al texto.

Los cambios se guardan al momento. La previsualización los muestra sobre la marcha. Para renombrar un tema más tarde, selecciónalo y pulsa <kbd>Retorno</kbd>.

Puedes editar los temas integrados, pero no renombrarlos ni eliminarlos. Para eliminar otro tema, selecciónalo y haz clic en el botón de eliminar. Spooky pregunta antes, porque no se puede deshacer. Una apariencia que usaba ese tema vuelve a su tema integrado.

### Compartir temas {#share-themes}

Cada tema es un archivo `.spookytheme`.

- **Exportar**: arrastra un tema de la lista a una carpeta del Finder.
- **Importar**: arrastra archivos `.spookytheme` a la lista. También puedes abrirlos desde el Finder o soltarlos sobre el icono de Spooky en el Dock.

Si ya existe un tema con el mismo nombre, Spooky pregunta si quieres sustituirlo. Un archivo que no es un tema válido se omite con un mensaje.

Spooky guarda los temas en `~/Library/Application Support/Spooky/Themes/`. Consulta [Datos y privacidad](/reference/data-privacy/#mac).

## Texto {#text}

La página :ui[settings.text] define el aspecto del texto en los diffs y en el contenido de los archivos. Los colores vienen del tema.

| Ajuste | Predeterminado | Qué hace |
|---|---|---|
| :ui[text.enableSyntaxColoring] | Activado | Colorea el código según su lenguaje |
| :ui[text.syntaxColoringInDiffs] | Desactivado | Usa también los colores de sintaxis en los diffs. Necesita el coloreado de sintaxis activado. |
| :ui[text.showInvisibles] | Desactivado | Muestra los espacios, las tabulaciones y los finales de línea como símbolos |
| :ui[text.tabWidth] | 4 | El ancho de una tabulación, de 1 a 100 espacios |

## Editor {#editor}

La página :ui[settings.editor] configura los campos del mensaje del commit. Consulta en [Escribir el mensaje](/guide/work/commit/#write) cómo se comportan.

| Ajuste | Predeterminado | Qué hace |
|---|---|---|
| :ui[editor.showsCounter] | Activado | Cuenta hacia atrás los caracteres que quedan en el asunto |
| :ui[editor.subjectLimit] | 50 | La longitud máxima recomendada del asunto, en caracteres. Selecciona un valor o escribe uno de 1 a 1000. |
| :ui[editor.wrapping] | :ui[editor.softWrap] | O :ui[editor.hardWrap], con un tipo de letra de ancho fijo y sin ajuste de línea automático |
| :ui[editor.bodyLimit] | 72 | El límite de línea para :ui[editor.hardWrap] |
| :ui[editor.showsGuide] | Activado | Dibuja una línea en ese límite, para :ui[editor.hardWrap] |
| :ui[editor.warnsComments] | Activado | Avisa de las líneas que Git trataría como comentarios. Consulta [Comentarios en el mensaje](/guide/work/commit/#comments). |
| :ui[editor.stripsComments] | Desactivado | Quita esas líneas al hacer commit. Disponible mientras el aviso está desactivado. |
| :ui[editor.completesIssues] | Activado | Completa los números de incidencia después de `#`. Consulta [Autocompletar](/guide/work/commit/#autocomplete). |

## Consulta también

- [General, actualizaciones y entorno](/guide/settings/general/)
- [Revisar y añadir cambios al stage](/guide/work/diff/)
- [Hacer commit de los cambios](/guide/work/commit/)
- [Ventanas y navegación](/guide/repositories/navigation/)
