# CodeXperience 🚜💻

CodeXperience es un **juego educativo e interactivo** diseñado para enseñar lógica de programación a través de un entorno inmersivo. El jugador asume el rol de un programador en una granja virtual, donde debe guiar a un tractor hacia su meta superando obstáculos mediante la creación de algoritmos con bloques de código.

El juego cuenta con un sistema de **Generación de Niveles Adaptativos** potenciado por Inteligencia Artificial, que ajusta la dificultad de los retos basándose en el código y las estructuras (como bucles `for` o condicionales `if`) que el jugador utiliza para resolverlos.

🌍 **Juega ahora en Itch.io:** *[(Demo)](https://stevenricardom.itch.io/codexperience)*

---

## ✨ Funcionalidades Principales

* **Aprende Programando:** Construye la ruta del tractor usando un sistema de arrastrar y soltar bloques (Avanzar, Girar, Interactuar, Bucles y Condicionales).
* **IA Adaptativa (Google Gemini):** Los niveles no están preprogramados. Una Inteligencia Artificial evalúa tu forma de programar y genera dinámicamente la posición de la meta y los obstáculos en tiempo real.
* **Modo Híbrido (VR y Escritorio):** 
  * Sumérgete completamente en la granja usando gafas de **Realidad Virtual**.
  * O juega cómodamente desde tu navegador web o PC en el **Modo Escritorio**.
* **Ejecución en Tiempo Real:** El tractor interpreta el código generado y se mueve físicamente por la cuadrícula del mundo 3D para completar la misión.

---

## 🎮 Controles

### Modo Escritorio (Web / PC)
* **W y D:** Moverse por la granja.
* **Ratón (Mouse):** Mirar alrededor. *(Nota: En la versión Web, haz un clic en la pantalla al cargar la granja para capturar el ratón).*
* **Clic Izquierdo:** Interactuar con los paneles de programación 3D, arrastrar bloques y ejecutar el código.
* **Rueda del raton:** Subir o bajar la camara.
* **Tecla ESC:** Liberar el cursor del ratón.

### Modo Realidad Virtual (Visores XR)
* **Joysticks:** Moverse y girar suavemente por el entorno.
* **Gatillos (Triggers) / Puntero Laser:** Apuntar e interactuar con los paneles de bloques.

---

## ⚙️ Aspectos Técnicos

* **Motor Gráfico:** [Godot Engine 4.3+](https://godotengine.org/)
* **Renderizado:** `gl_compatibility` optimizado para garantizar soporte amplio en navegadores web (WebGL 2.0).
* **Lenguaje principal:** GDScript.
* **Inteligencia Artificial:** Integración nativa mediante llamadas HTTP seguras a la API de **Google Gemini 3.5 Flash**.
* **Framework XR:** Utiliza `godot-xr-tools` para el manejo avanzado de manos, interacciones y el sistema de simulador híbrido para escritorio.
* **Plataforma de Exportación principal:** HTML5 (WebAssembly) con compresión VRAM `S3TC/BPTC` para escritorio y `ETC2/ASTC` para móviles/VR.

