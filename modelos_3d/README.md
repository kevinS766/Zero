# Modelos 3D para Zero (Roblox)

Esta carpeta contiene los modelos 3D listos para animación e importación a Roblox Studio.

## Contenido

1. **`Baston_Demoniaco.fbx`**:
   - Polígonos: **1,282** caras (~2,464 triángulos, optimizado < 2.6k).
   - Estructura: Asta gótica en espiral, empuñadura de cuero cruzado, collares con púas cónicas, punta de lanza pommel con rubí, jaula con 6 garras que sujetan el orbe central carmesí, alas de murciélago con nervaduras y membranas en Vertex Color.
   - Diseñado para usarse como Tool / Weapon rígido o animado.

2. **`Alas_Y_Cola_Demoniaca.fbx`**:
   - Polígonos: **874** caras (~1,732 triángulos).
   - Estructura: Alas principales superiores desplegadas, sub-alas inferiores colgantes a la espalda, y cola demoníaca con punta en forma de pica.
   - Posicionado a escala exacta de torso/espalda R6 de Roblox.
   - Listo para colocar esqueleto (Armature) y hacer skinning/pesado de vértices.

3. **`Modelos_Demoniacos_Zero.blend`**:
   - Escena completa de Blender con materiales PBR configurados, maniquí R6 de referencia en colección separada (`Ref_RobloxAvatar`) y colecciones organizadas (`Baston_Demoniaco` y `Alas_Y_Cola_Demoniaca`).

---

## Cómo descargar solo esta carpeta

Si la otra persona no desea clonar todo el repositorio del juego, puede descargar solo esta carpeta mediante cualquiera de estos métodos:

### Opción A (Descarga directa desde GitHub - Sin Git)
1. Entrar a: `https://github.com/kevinS766/Zero/tree/main/modelos_3d`
2. Hacer clic en cada archivo y darle a **Download raw file**.

### Opción B (Clonado disperso con Git - Sparse Checkout)
Ejecutar en la terminal de Git:
```bash
git clone --depth 1 --no-checkout https://github.com/kevinS766/Zero.git
cd Zero
git sparse-checkout set modelos_3d
git checkout
```
Esto descargará **únicamente** la carpeta `modelos_3d/` sin descargar scripts ni el resto del proyecto.
