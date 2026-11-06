# Estación de escritorio

- **WASD:** caminar; **ratón:** mirar.
- Sube la rampa situada junto al punto de aparición para acceder al palco.
- Mira un panel cercano y pulsa **E** para programar. La cámara queda fija.
- **Clic / arrastrar / rueda:** operar el panel seleccionado.
- **E o Escape:** volver a explorar. Al escribir, E sigue siendo texto; usa Escape para salir.
- Perder el foco de la ventana cancela la interacción. Haz clic para recuperar el control.

Solo se utiliza el simulador de escritorio: no se inicializa OpenXR ni se prueba hardware VR.
Las escenas de visor existentes se conservan, pero no aparecen en el menú.

## Regresión

Ejecuta con Godot 4.7.2, después de importar el proyecto:

```text
godot --headless --path . --script res://tests/desktop_regression.gd
godot --headless --path . --script res://tests/hands_regression.gd
godot --headless --path . --script res://tests/ui_regression.gd
godot --headless --path . --script res://tests/deck_regression.gd
```

Cada runner cuenta fallos y termina con código distinto de cero si falla.
En Windows, espera a que termine el ejecutable (por ejemplo, `Start-Process -Wait -PassThru`);
el ejecutable gráfico puede regresar inmediatamente al invocarlo desde PowerShell.

Verificación renderizada realizada: subir caminando la rampa, vista despejada del tractor,
selección con E, arrastre nativo que cambia el orden de los bloques, ejecución de avanzar y limpieza.
Las pruebas de layout cubren 960×540, 1280×720 y 1920×1080; no sustituyen una prueba de comodidad del usuario.
