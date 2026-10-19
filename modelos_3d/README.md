# Modelos 3D — Zero (Roblox)

Repositorio centralizado de modelos 3D, assets visuales, armas y cosméticos para **Zero**.

## Estructura de Sets y Categorías

Para mantener el proyecto limpio y modular a medida que agreguemos más modelos, cada set temático o categoría tiene su propia subcarpeta encapsulada:

```text
modelos_3d/
  |-- set_demoniaco/              <-- Set Demoníaco (Bastón, Alas y Cola)
  |     |-- Baston_Demoniaco.fbx
  |     |-- Alas_Y_Cola_Demoniaca.fbx
  |     `-- Modelos_Demoniacos_Zero.blend
  |
  |-- [futuros_sets]/             <-- Próximos sets (Halloween, Armas, etc.)
  `-- README.md
```

---

## Catálogo Actual

### 1. `set_demoniaco/`
- **`Baston_Demoniaco.fbx`**:
  - Polígonos: **1,282** caras (~2,464 triángulos, límite < 2.6k tris).
  - Estructura: Asta gótica en espiral, empuñadura con cuero cruzado, collares con púas cónicas, punta de lanza pommel con rubí, jaula con 6 garras que sujetan el orbe central carmesí, alas de murciélago con nervaduras y membranas en Vertex Color.
  - Rol: Arma / Bastón de Cazador (Tool rígido o animado).
- **`Alas_Y_Cola_Demoniaca.fbx`**:
  - Polígonos: **874** caras (~1,732 triángulos).
  - Estructura: Alas principales superiores desplegadas, sub-alas inferiores colgantes a la espalda, y cola demoníaca con punta en pica.
  - Proporción: Calzado exacto sobre la espalda/torso R6 de Roblox.
  - Rol: Accesorio cosmético esquelético (listo para rigging / armature).
- **`Modelos_Demoniacos_Zero.blend`**:
  - Archivo maestro de Blender con colecciones separadas, materiales PBR y maniquí R6 de referencia en colección independiente.

---

## Cómo clonar o descargar solo la carpeta de modelos

Si el modelador o animador no desea clonar el código del juego ni el resto del repositorio:

### Opción A (Descarga directa desde la web)
Navegar a: `https://github.com/kevinS766/Zero/tree/main/modelos_3d` y descargar la subcarpeta o archivo deseado.

### Opción B (Sparse Checkout con Git)
Clona solo el árbol de `modelos_3d`:
```bash
git clone --depth 1 --no-checkout https://github.com/kevinS766/Zero.git
cd Zero
git sparse-checkout set modelos_3d
git checkout
```
De este modo solo se descargarán los modelos y no el resto del repositorio.
