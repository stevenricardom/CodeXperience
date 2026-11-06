# Desktop Programming Station Implementation Plan

**Goal:** Mejorar la presentación y los controles del simulador de escritorio y trasladar los cuatro paneles a un palco accesible junto al inicio del tractor.
**Architecture:** Un controlador local es el único dueño de los eventos de escritorio. Reutiliza los trackers simulados, el cuerpo de XRTools y los SubViewports existentes, sin inicializar hardware. Una escena independiente contiene el palco; un tema compartido unifica la interfaz.
**Tech stack:** Godot 4.7.2, GDScript, GL Compatibility, Jolt.
**Spec:** Diseño aprobado en esta conversación (2026-11-06), resumido debajo.

**Resultado:** Implementación y verificación realizadas. Regresión: 421 comprobaciones,
0 fallos (desktop 23, manos 114, UI 184, palco 100). Prueba renderizada de rampa,
selección E, arrastre nativo, ejecución y limpieza. Revisión propia únicamente:
las delegaciones de UI/palco agotaron créditos; queda pendiente revisión independiente.
Cambios sin commit/merge/push. Véase `docs/desktop-controls.md`.

## Diseño aprobado y restricciones
- Solo simulador de escritorio. Nunca inicializar ni probar OpenXR/visor real; conservar mainXR.tscn, sin ofrecerla en el menú.
- WASD para moverse y ratón para mirar. E activa un panel cercano. En programación la cámara y el movimiento quedan bloqueados; clic/rueda/arrastre operan el panel activo. E o Escape devuelve el control (E no sale mientras se escribe).
- Mantener cuatro paneles activos y todas las funciones existentes, incluida la vista cenital. No sustituirlos por una consola única.
- Palco próximo a la posición inicial del tractor, rampa caminable y colisiones, sin invadir su recorrido ni cerrar la vista al campo.
- Manos originales estilizadas con silueta suave, poses de reposo/apuntar/agarrar y transiciones discretas; no requieren mantener Q/E. Inspiración en accesibilidad de PEAK, sin copiar assets ni añadir escalada.
- Preservar cambios locales previos y configuración de Asset Placer. Reutilizar sus escenas con colisión cuando sea viable; comprobar las colisiones efectivas.
- Toda delegación usa variante low. Implementación directa con revisión independiente al final.

## Review Focus
1. Soltar o cancelar un arrastre fuera del panel, perder foco o salir: no queda botón pulsado ni bloque translúcido.
2. Teclas de escritura y WASD no mueven al jugador ni llegan a múltiples paneles.
3. No hay clics dobles por la convivencia de FunctionPointer y el cursor desktop.
4. Rampa/plataforma tienen un trayecto continuo y no intersectan la ruta del tractor.
5. Menú, enfoque y cursor se restauran tras cambiar de escena o perder foco.

## Task 1: Input de escritorio
- [ ] Añadir runner SceneTree con fallos contados y exit(1), y ver RED de las pruebas de entrada/salida, escritura, movimiento y botones.
- [ ] Crear desktop_interaction.gd y proveedor local de movimiento; asignar acciones de InputMap, desactivar el input antiguo del simulador y los punteros desktop duplicados.
- [ ] Enrutar eventos de ratón a coordenadas de un único SubViewport y liberar/cancelar arrastres en todas las salidas.
- [ ] Retirar acceso a visor real en menú sin borrar la escena.
- [ ] Ejecutar pruebas y comprobar GREEN.

## Task 2: Palco y paneles
- [ ] Añadir pruebas de física de rampa/suelo, recorrido y visibilidad de cuatro paneles; comprobar RED.
- [ ] Crear escena observation_deck.tscn con piezas existentes y colisión, trasladar ProgrammingConsole y ajustar punto de aparición.
- [ ] Verificar continuidad caminando y raycasts con Jolt; comprobar GREEN.

## Task 3: Presentación de interfaces
- [ ] Añadir pruebas de paleta → código, variables/condiciones, ejecutar/limpiar y tamaños mínimos; comprobar RED donde cambie el comportamiento.
- [ ] Aplicar tema compartido, jerarquía visual, encabezados y estados a menú y cuatro paneles sin romper sus NodePaths.
- [ ] Comprobar GREEN y revisar a 1280x720 y 1920x1080.

## Task 4: Manos
- [ ] Añadir pruebas de seguimiento sin Q/E, límites y retorno sin saltos; comprobar RED.
- [ ] Crear visuales locales estilizados y poses suavizadas, sin modificar assets vendor.
- [ ] Comprobar GREEN y examinar silueta/oclusión durante programación.

## Task 5: Verificación final
- [ ] Ejecutar toda la regresión y un arranque desktop; inspeccionar errores reales.
- [ ] Probar en ejecución E/clic/rueda/arrastre/Escape, subir la rampa, ejecutar y limpiar.
- [ ] Revisión independiente con variante low, corregir problemas importantes con RED→GREEN.
- [ ] Documentar controles, comandos de prueba y limitaciones de verificación; entregar sin merge/push.
