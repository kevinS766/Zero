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
  |-- set_lunar/                  <-- Set Lunar (Bastón y Lunas Gemelas)
  |     |-- Baston_Lunar.glb
  |     |-- Lunas_Gemelas.glb
  |     |-- Modelos_Lunares_Zero.blend
  |     `-- Modelos_Lunares_Roblox.blend
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

### 2. `set_lunar/`
- **`Baston_Lunar.glb`**:
  - Triángulos: **3,869** (10 partes unidas por material).
  - Estructura: mango de cuero trenzado, anillos y virola, banda de runas con 8 glifos, media luna con filigrana, gema de zafiro con bisel y garras, medallón, cordones y polvo estelar.
  - Altura real: **1.73 m**. Origen en la punta inferior; el punto de agarre está a **0.65 m** del origen.
  - Rol: Arma / Bastón Lunar (Tool en mano).
- **`Lunas_Gemelas.glb`**:
  - Triángulos: **2,802** (7 partes).
  - Estructura: dos lunas (A grande / B pequeña) con superficie lunar, auras, ribbons, cristales, anillos orbitales y polvo.
  - Tamaño del cluster: **0.75 m**. Origen en el centro (ideal para `PivotTo` / `ScaleTo`).
  - Rol: VFX invocado por la habilidad del bastón (no va equipado).
- **`Modelos_Lunares_Zero.blend`**:
  - Fuente editable de alta calidad (bastón 59k tris, lunas 34k) con curvas y modificadores intactos.
- **`Modelos_Lunares_Roblox.blend`**:
  - Versión optimizada y unida por material, desde la que se exportaron los GLB.
- **Materiales**: 10 en el bastón (plata, acero, cuero, cuerda, zafiro, runa, escarcha, hielo) y 7 en las lunas. Emisión azul tenue en `Lunar_Sapphire`, `Lunar_RuneIce` y `Lunar_FrostVein`.
- **Notas de importación**: GLB en Y-up; las lunas deben importarse como `Model` anclado, `CanCollide`/`CanQuery` en falso.

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
