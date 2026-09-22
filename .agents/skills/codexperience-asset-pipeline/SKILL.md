---
name: codexperience-asset-pipeline
description: >-
  Use this skill when the user asks to import 3D models (.glb/.gltf), generate collisions,
  pack scenes, or build MeshLibraries and GridMaps for the CodeXperience project.
---

# Pipeline de Assets 3D y MeshLibrary para CodeXperience

Procedimiento estándar para preparar assets 3D procedentes de `resources/models/` y convertirlos en piezas compatibles con `GridMap` y `MeshLibrary` en `assets/scenes/` y `assets/meshlibrary/`.

## Estructura Requerida de un Tile / Asset
Para que un elemento 3D funcione correctamente en Godot XR Tools y GridMap:
1. El nodo raíz debe ser el `MeshInstance3D`.
2. Como hijo directo debe ubicarse el `StaticBody3D` con sus `CollisionShape3D` (trimesh o convex).
3. La capa de colisión del `StaticBody3D` debe configurarse en la Capa 1 (`Environmet-World`) u 8 (`Tractors/Machine`) según corresponda.
4. Todos los subnodos deben tener `owner = root` para ser serializados en `.tscn` o `.tres`.

## Automatización con EditorScripts
- Ejecutar o adaptar `scripts/EditorScripts/EditorScript_make_local_collisions_scenes.gd` en el Editor de Godot para conversión por lotes.
- Ruta de origen habitual: `res://resources/models/farm_models/...`
- Ruta de destino habitual: `res://assets/scenes/farm_assets/...`
