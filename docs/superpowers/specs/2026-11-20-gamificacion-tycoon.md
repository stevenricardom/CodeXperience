# Gamificación "Granja Tycoon" — Diseño acordado

**Fecha:** 2026-11-20 · **Origen:** sesión /grill-me · **Alcance:** solo escritorio (`main.tscn`); `mainXR.tscn` intacto.

## Bucle principal
```
Nivel (IA o local) → programar → ejecutar → ⭐ + 🪙 → Tienda (bloques / edificios) → granja crece + nuevas misiones → Objetivo siguiente
```
Meta final: barra **"Granja restaurada" = 100 %** → pantalla de créditos/certificado → modo libre.

## Decisiones
| # | Tema | Decisión |
|---|------|----------|
| 1 | Fantasía | Restaurar/expandir la granja: edificios 3D + desbloqueos jugables |
| 2 | Recompensa | 3 estrellas calculadas **localmente**: ⭐1 llegar/cumplir, ⭐2 bloques ≤ N (par), ⭐3 primer intento y sin pista. 🪙 = 10 × estrellas (+ bonos) |
| 3 | Bloques | Bloqueados al inicio (solo avanzar/girar). Se compran. La IA recibe la lista de bloques desbloqueados |
| 4 | Misiones | **Llegar** (actual) y **Sembrar** (casillas marcadas + `interactuar()`, luego llegar a la meta). Sembrar requiere tener Interactuar |
| 5 | Tienda | Kiosco físico cerca del palco, Viewport2Din3D + `StationTheme`, se activa con E |
| 6 | Edificios | Lotes predefinidos en `main.tscn`, ocultos con letrero "Se vende: X 🪙"; al comprar aparecen con tween de escala + partículas |
| 7 | Bonos | Silo +10 % 🪙 · Pozo 1 pista gratis/nivel · Gallinero +1 🪙/estrella · Molino +50 % en Sembrar · todos suman a "Granja restaurada" |
| 8 | Pistas | Campo `"hint"` en el JSON del nivel (sin llamada extra). Botón Pista: 5 🪙 (gratis 1/nivel con Pozo). Usarla quita ⭐3 |
| 9 | Guardado | Autoload `GameState` → `user://save.json` tras cada nivel/compra (IndexedDB en Web). Menú: Continuar / Nueva partida |
| 10 | Robustez IA | Generador local de respaldo (sin API key o fallo). BFS valida resolubilidad y calcula N, también para respuestas de Gemini |
| 11 | Guía | ~12 "Objetivos del Granjero" lineales, uno a la vez, con recompensa extra |
| 12 | UI | HUD `CanvasLayer` (🪙 + objetivo actual) y popup de resultado (⭐⭐⭐ + 🪙) |
| 13 | Fuera de v1 | Ampliar el campo, colocación libre, idle/ingresos pasivos, VR |

## Economía (un solo archivo de config, p. ej. `scripts/game/economy.gd`)
| Bloques | 🪙 | Edificios | 🪙 |
|---|---|---|---|
| Interactuar (habilita Sembrar) | 30 | Cercas | 40 |
| FOR | 50 | Pozo | 60 |
| Variables | 80 | Gallinero | 90 |
| WHILE | 100 | Silo | 120 |
| IF / ELSE | 120 | Molino | 150 |
| | | Granero | 250 |

Total ≈ 1100 🪙 ≈ 45–50 niveles. Pista: 5 🪙.

## Puntos de integración con el código actual
- `scenes/main/main.gd` `_on_code_execution_requested`: evaluar victoria por tipo de misión, contar bloques (líneas no vacías de `code_text`), intentos y pista → `GameState.award_level(...)`.
- `scenes/main/ai_level_manager.gd`: ampliar prompt/JSON (`mission`, `plant_cells`, `par_blocks`, `hint`, bloques permitidos); validar con BFS; fallback local; marcar casillas de siembra en el GridMap.
- `scenes/tractor/tractor.gd` `interactuar()`: registrar la casilla sembrada para la misión Sembrar.
- `scenes/ui/panel_actions/panel_actions.gd` y `panel_variables.gd`: ocultar/deshabilitar botones según `GameState.unlocked_blocks` (con candado 🔒 y precio).
- `scenes/ui/panel_code`: botón Pista y popup de resultado.
- Nuevos: autoload `GameState`, panel/escena de Tienda (kiosco), lotes de edificios en `main.tscn` con los modelos de `resources/models/farm_models/structures` (Barn, Silo, Windmill, Chicken_Coop, Well, Fence), HUD.
- `scenes/ui/main_menu`: Continuar / Nueva partida.
