# 🚜 Serious Game 3D: Automatización Agrícola e Introducción a la Programación

[![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.x-blue?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac%20%7C%20Linux%20%7C%20XR-lightgrey)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#)

Un **Serious Game 3D interactivo y adaptativo** diseñado para enseñar y evaluar la lógica algorítmica y la resolución de problemas en estudiantes. El juego combina mecánicas de gestión de granjas, automatización de tractores mediante programación e interacciones inmersivas híbridas (PC de escritorio y Realidad Virtual/XR).

---

## 🌟 Características Principales

* **🎮 Bucle de Jugabilidad Agrícola:** El jugador encarna a un granjero que opera y programa tractores automatizados para cultivar, cosechar y comercializar productos en un entorno 3D.
* **⌨️ Consola de Programación Integrada (XR/PC):** Entorno interactivo proyectado en espacios 3D (*Interfaces 2D en SubViewports 3D*) con editor de código (`CodeEdit`), autocompletado, resaltado de sintaxis y botones de inserción rápida de comandos diseñados para VR/XR.
* **🧩 Desafíos Algorítmicos con Restricciones de Hardware:** Los tractores avanzados imponen limitaciones físicas o lógicas (por ejemplo, prohibir bucles `for` o condicionales `if`), obligando al usuario a optimizar algoritmos bajo reglas específicas.
* **🤖 Componente de IA y Evaluación Adaptativa:**
  * **NPC Interactivos:** Un granjero vecino visita la parcela periódicamente para solicitar apoyo técnico y algorítmico.
  * **Dificultad Dinámica por JSON:** La IA procesa las métricas de rendimiento del estudiante (errores, tiempo de resolución, líneas de código) y genera proceduralmente nuevos retos adaptados a sus necesidades.
* **🥽 Soporte Híbrido (Desktop & OpenXR):**
  * **Modo Realidad Virtual:** Control total en visores XR usando **Godot XR Tools** (`XROrigin3D`, `XRCamera3D`, mandos con físicas de `XRToolsPlayerBody`, manos dinámicas y proveedores de locomoción).
  * **Emulación / Fallback Autónomo:** Integra un simulador de entradas (`XR Simulator`) para probar y desarrollar las mecánicas inmersivas completas desde el ratón y teclado sin requerir un casco XR físico.

---

## 🏗️ Arquitectura Técnica

### Stack Tecnológico
* **Motor:** Godot Engine 4.x (renderizador *Compatibility* para máxima portabilidad en Web/Desktop).
* **Ecosistema VR:** [Godot XR Tools](https://godotvr.github.io/godot-xr-tools/), plugin `XR Simulator` y estándar **OpenXR**.
* **Lenguaje principal:** GDScript con tipado fuerte.

### Estructura del Jugador XR Híbrido
```text
PlayerXR (XROrigin3D)
├── XRCamera3D 
├── LeftHand (XRController3D)
│   ├── Mesh (left_hand.tscn)
│   └── MovementDirect (movement_direct.tscn)
├── RightHand (XRController3D)
│   ├── Mesh (right_hand.tscn)
│   └── MovementTurn (movement_turn.tscn)
└── XRToolsPlayerBody (CapsuleShape3D & Físicas)
```

## 🚀 Instalación y Configuración

### Prerrequisitos
1. Descargar e instalar **[Godot Engine 4.x](https://godotengine.org/download)** (versión *Standard* o *.NET*).
2. Clonar el repositorio:
   ```bash
   git clone https://github.com/tu-usuario/tu-repositorio.git
   ```

### Pasos Iniciales en Godot
1. Abre Godot Engine e importa el archivo `project.godot`.
2. Ve a **Proyecto -> Configuración del Proyecto -> Plugins** y asegúrate de activar **Godot XR Tools**.
3. Verifica en **Proyecto -> Configuración del Proyecto -> XR -> OpenXR** que el **Default Action Map** apunte a `openxr_action_map.tres` y que la opción **Enabled** esté activada.
4. Para construir mapas con el `GridMap`, asegúrate de usar el script de herramienta incluido para organizar tus tiles como hermanos paralelos (`MeshInstance3D` y `StaticBody3D`) antes de exportar a `.tres` o `.meshlib`.

---

## 🎮 Mandos y Controles de Desarrollo

### Modo Con Visor VR (OpenXR)
* **Gatillo / Primary Action:** Interactuar con la consola de comandos y la UI.
* **Joystick Izquierdo:** Caminar por el mapa (`MovementDirect`).
* **Joystick Derecho:** Girar la vista (`MovementTurn`).

### Modo Simulador (Desarrollo en Pantalla Plana)
Si ejecutas el juego sin un visor conectado, `main.gd` detectará la ausencia del hardware e inyectará automáticamente el **XR Simulator**:
* **W, A, S, D:** Desplazamiento por el mapa.
* **Clic Derecho (Sostener) + Mover Ratón:** Rotar la cabeza / mirada (`XRCamera3D`).
* **Shift (Sostener) + Mover Ratón:** Mover mano izquierda (`LeftHand`).
* **Alt (Sostener) + Mover Ratón:** Mover mano derecha (`RightHand`).
* **Clic Izquierdo:** Simular el gatillo del mando seleccionado.

---

## 📄 Licencia
Este proyecto se distribuye bajo la licencia **MIT**. Consulta el archivo `LICENSE` para más detalles.
