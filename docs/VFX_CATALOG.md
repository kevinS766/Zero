# Catálogo de Efectos Visuales (VFX Pack)

Este documento detalla la estructura, inventario y posibles aplicaciones del pack de VFX importado en `Workspace.VFX`.

---

## 1. Diagnóstico del Estado Actual

1. **Ubicación actual**: `Workspace.VFX` (contiene 174 instancias directas).
2. **Duplicación detectada**: El pack parece haberse pegado dos veces consecutivas en Workspace (cada modelo y parte suelta tiene su duplicado idéntico, p. ej. 2x `Anime`, 2x `Big`, 2x `Auras`, 2x `Beams`, 2x `Particle Storage`, etc.).
3. **Estructura mixta**:
   - Modelos temáticos organizados por categorías de efectos compuestos.
   - Partes sueltas con `Decals` y `ParticleEmitters` individuales (ej. texturas de flipbooks, aros, rayos, humo).
4. **Texturas y Assets**: Cuenta con **241 texturas / flipbooks únicos** listos para producción.

> **Recomendación de Limpieza**:
> - Eliminar los duplicados gemelos.
> - Mover la versión limpia a `ReplicatedStorage.Assets.VFX` para que los clientes puedan clonarlos dinámicamente cuando un efecto se dispare (Dash, Congelamiento, Habilidad de Cazador, Rescate, etc.), sin ensuciar la geometría del Workspace.

---

## 2. Categorías y Efectos Clave

### A. Modelos Compuestos de Alta Utilidad

| Carpeta / Modelo | Efectos Destacados | Posible Uso en Zero |
| :--- | :--- | :--- |
| **`Anime`** (36 presets) | `Slash-01`, `Fire-Slash-01`, `Slashes-01`, `Slash-Impact-01`, `Smoke-01`, `Water-01/02`, `Wind-01/02`, `Punch-01/02/03`, `Shield-01`, `Shield-Break-01`, `ForceField-01`, `Stars-01`, `Realistic-Explosion-01` | **Ataque de Cuchillo**: Impactos de corte y slash en hits exitosos.<br>**Dash**: Ráfagas de viento/humo direccional al impulsarse.<br>**Rescate / Escudo**: Efecto al liberar o proteger a un Runner. |
| **`Big`** (5 presets) | `Explosion-01`, `Tornado-01`, `Ball-01`, `Lighting-01`, `Big-Crack-01` | **Trampas Trapper**: Efecto de detonación o grieta al activarse.<br>**Fin de Ronda**: Efecto dramático al ganar Cazador o Corredores. |
| **`Auras`** (5 presets) | `Fire-Aura-01`, `Water-Aura-01`, `RNG-Aura-01`, `RNG-Aura-02`, `RNG-Aura-03` | **Cazador Activo**: Aura amenazante o efecto visual de clase.<br>**Acechador (Stalker)**: Aura de sigilo / distorsión durante invisibilidad.<br>**Rastreador (Tracker)**: Siluetas o efectos de marcado. |
| **`Beams`** (3 presets) | `Waterfall-01`, `Lava-01`, `Wind-01` | Lazos / Rayos de rescate o trayectorias de proyectiles/habilidades. |
| **`Heads`** (6 presets) | `Glowing-Eyes-01`, `Flamming-Eyes-01`, `Angry-01`, `Surprised-01/02`, `Confused-01` | Expresiones cómicas o intimidantes para Hunters / Runners congelados. |
| **`vfx pack`** (4 presets) | `Explosion`, `Projectile`, estelas `Trail` | Proyectiles o estelas continuas de velocidad al correr. |

---

## 3. Biblioteca de Texturas y Partículas Sueltas (`Particle Storage` y Decals)

Contiene emisores listos con texturas avanzadas que pueden integrarse en cualquier `Attachment`:
- **Flipbooks**: `fire flipbook (1, 2, 3)`, `smoke flipbook (1, 2)`, `lighting flipbook`, `lightning explosion flipbook`.
- **Anillos y Ondas de Choque**: `lightning ring (1, 2, 3)`, `light ring`, `offcenter circle`, `circle thing`, `pentagon`, `octagon`.
- **Atmósfera y Brillos**: `glow`, `glow 2`, `light ray`, `light rays`, `tiny light ray`, `smoke/fog`, `flare`, `star thing`, `vortex`, `spinny`.

---

## 4. Oportunidades Directas de Integración con el Gameplay de Zero

1. **Congelamiento (`Frozen`)**:
   - Crear un efecto de estallido frío / cristales usando partículas de `Anime (Splash / Crack / Stars)` tintadas en cian/azul para la transición a congelado.
2. **Dash de Movimiento**:
   - Clonar un `Wind-01` o `Smoke-01` en el `HumanoidRootPart` del jugador hacia la dirección opuesta al impulso durante los 0.25s del Dash.
3. **Cuchillo del Cazador (`CombatService`)**:
   - Al llamar a `NetworkEvents.AttackHitFeedback`, instanciar `Slash-Impact-01` en la posición del impacto.
4. **Trampa del Trampero (`HunterClassService`)**:
   - Cuando la trampa se despliega en el suelo: aura sutil o `pentagon / circle ring`.
   - Cuando un Runner la pisa: `Big-Crack-01` + partículas de congelamiento instantáneo.
5. **Habilidad de Rastreador**:
   - Pulso expansivo usando `vortex` o `light ring` centrado en el Cazador.
