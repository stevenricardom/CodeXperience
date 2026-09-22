# Contexto y Directrices de Desarrollo - CodeXperience

## 1. Visión y Propósito del Proyecto
CodeXperience es un **Serious Game 3D interactivo y adaptativo** desarrollado en **Godot Engine 4.x**, diseñado para enseñar y evaluar lógica algorítmica y resolución de problemas.
- **Bucle de juego**: Granjero que opera y programa tractores automatizados para cultivar, cosechar y comerciar en un entorno 3D.
- **Consola de programación (XR/PC)**: UI 2D proyectada en `SubViewport` 3D con `CodeEdit`, autocompletado, resaltado sintáctico y comandos rápidos adaptados a Realidad Virtual y pantalla plana.
- **Desafíos con restricciones de hardware**: Tractores avanzados con restricciones lógicas o físicas (p. ej. restricción de bucles `for` o condicionales `if`), exigiendo optimización de código al estudiante.
- **IA Adaptativa**: Ajuste procedural de dificultad y desafíos mediante formato JSON basado en el rendimiento del usuario (errores, tiempos, líneas de código), complementado por NPCs interactivos.

## 2. Stack Tecnológico y Configuración del Motor
- **Motor**: Godot Engine 4.7+ (Standard / .NET).
- **Renderizador**: `gl_compatibility` (driver D3D12 en Windows) para soporte y estabilidad multiplataforma (Desktop, Web, XR).
- **Física 3D**: `Jolt Physics` (`3d/physics_engine="Jolt Physics"`).
- **XR Framework**: `Godot XR Tools` (`XROrigin3D`, `XRCamera3D`, `XRToolsPlayerBody`, locomoción directa y giro).
- **Emulación XR**: Plugin `XR Simulator` para desarrollo y pruebas completas sin visor físico mediante ratón y teclado.
- **Plugins Activos**:
  - `res://addons/godot-xr-tools/plugin.cfg`
  - `res://addons/godot-asset-placer-1.7.0-alpha1/addons/asset_placer/plugin.cfg`
- **Autoloads Globales**:
  - `XRToolsUserSettings`: Configuración de usuario de Godot XR Tools.
  - `XRToolsRumbleManager`: Gestión de vibración háptica en mandos XR.
  - `XrSimulator`: Emulador de entradas XR en escritorio.

## 3. Matriz de Capas de Física 3D (3D Physics Layers)
Es estrictamente obligatorio respetar la asignación de capas de física en colisionadores, raycasts y áreas:
- **Capa 1 (Bit 1)**: `Environmet-World` (Terreno, plataformas, estructuras estáticas del mundo).
- **Capa 2 (Bit 2)**: `PlayerBody` (Cuerpo físico del jugador, colisión con el suelo y paredes).
- **Capa 3 (Bit 3)**: `Pickeables` (Objetos interactivos y agarrables).
- **Capa 4 (Bit 4)**: `Wall-Walking` (Superficies especiales de escalada/caminar por paredes).
- **Capa 5 (Bit 5)**: `IU/LaserPointing` (Paneles de interfaz, botones, consolas interactivas vía raycast/puntero).
- **Capa 6 (Bit 6)**: `TeleportArea` (Áreas transitables mediante teletransporte XR).
- **Capa 7 (Bit 7)**: `TeleportTarget` (Puntos objetivos de teletransporte).
- **Capa 8 (Bit 8)**: `Tractors/Machine` (Tractores, maquinaria agrícola y vehículos programables).

## 4. Esquema de Jugador Híbrido (Desktop & OpenXR)
- **Escena Principal de Jugador**: `scenes/player/playerXR_Desktop/PlayerXR_Desktop.tscn`.
- **Detección Automática**: `hand_limiter.gd` detecta si el visor XR está activo (`get_viewport().use_xr`). En modo plano / simulador:
  - Aplica límites de rotación y traslación a los mandos virtuales para mantenerlos frente a la cámara con ergonomía natural.
  - Retorno suave a la posición de reposo (`rest_local`) cuando no se presionan las teclas de manipulación (teclas Q y E del `XrSimulator`).
  - Movimiento por teclado mediante `XRToolsDesktopMovementDirect` (W, A, S, D).

## 5. Pipeline de Assets 3D y GridMap
- Los modelos importados en formato `.glb` / `.gltf` se procesan mediante EditorScripts (`scripts/EditorScripts/`):
  - La jerarquía requerida para `MeshLibrary` y `GridMap` debe tener la malla `MeshInstance3D` como raíz y su colisionador `StaticBody3D` (`CollisionShape3D`) como hijo directo, con todos los nodos asignados al `owner` de la escena empaquetada.
  - `assets/meshlibrary/` contiene las librerías exportadas (`.tres`) divididas por temas (`assets_farm_tiles.tres`, `assets_nature_tiles.tres`, `assets_platforms_mesh.tres`).
  - Escenas de mundo (`scenes/world/world.tscn`) organizan el terreno mediante GridMaps especializados (`tiles_platforms`, `farm_medium_small_tiles`, `ground_plants`).

## 6. Convenciones de GDScript y Código
- **Tipado estático obligatorio**: Declarar siempre tipos de variables, parámetros y retornos (`var velocidad: float = 5.0`, `func calcular_ruta(...) -> PackedVector3Array:`).
- **Nomenclatura**:
  - Archivos y métodos: `snake_case` (ej. `player_desktop.gd`, `hand_limiter.gd`, `_physics_process()`).
  - Nodos y clases: `PascalCase` (ej. `PlayerXR_Desktop`, `XROrigin3D`).
  - Constantes: `SCREAMING_SNAKE_CASE` (ej. `SPEED`, `JUMP_VELOCITY`).
- **Idioma de documentación y comentarios**: Español en comentarios, docstrings y mensajes de UI, manteniendo el código limpio y profesional.
