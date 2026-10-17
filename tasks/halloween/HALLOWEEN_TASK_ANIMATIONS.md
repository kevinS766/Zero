# Módulo de Animaciones — Evento de Halloween 2026 (Zero)

> **Rol del Agente**: Especialista en Animación R15/R6, Rigging y Reproducción Cinemática.
> **Archivo Exclusivo**: Este documento centraliza **todas** las animaciones del evento de Halloween para evitar colisiones de dependencias entre agentes.
> **Regla de Oro**: Ningún otro agente debe crear o modificar tracks de animación de Halloween sin coordinarse con este archivo.

---

## 1. Alcance y Objetivos
Crear, configurar, registrar y conectar todas las pistas de animación (`AnimationTrack`), IDs de asset (`rbxassetid://`), prioridades de animación (`Enum.AnimationPriority`) y triggers de reproducción para los personajes y props interactivos del evento.

---

## 2. Catálogo de Animaciones Requeridas

### 2.1 Habilidades de Cazador
1. **Lanza de Gransax — Suspensión en el Aire (`Gransax_Cast`)**:
   - **Tipo**: R15 y R6.
   - **Prioridad**: `Action4`.
   - **Descripción**: El Cazador se eleva brevemente en el aire, arquea el torso hacia atrás y levanta el brazo derecho sosteniendo la lanza cargada antes de lanzarla.
   - **Eventos de Animación (AnimationEvents)**:
     - `Materialize`: Instante exacto en que la lanza aparece en su mano derecha.
     - `Release`: Instante en que el proyectil es disparado hacia adelante.

2. **Alas Negras — Wind-up / Carga (`DarkWings_ChargeLoop`)**:
   - **Tipo**: R15 y R6.
   - **Prioridad**: `Action2`.
   - **Descripción**: Postura telegrafiada agachada hacia adelante mientras las alas oscuras se expanden y aletean lentamente acumulando energía. Debe ser un loop fluido.

3. **Alas Negras — Embestida Explosiva (`DarkWings_Dash`)**:
   - **Tipo**: R15 y R6.
   - **Prioridad**: `Action3`.
   - **Descripción**: Impulso horizontal aerodinámico de alta velocidad propulsado por las alas con brazos extendidos hacia atrás.

4. **Reacción a Aturdimiento / Stun (`Hunter_StunReaction` / `Runner_StunReaction`)**:
   - **Tipo**: R15 y R6.
   - **Prioridad**: `Action4`.
   - **Descripción**: El personaje se tambalea aturdido con la cabeza mareada y brazos caídos, impidiendo movimientos de correr/saltar durante 1.2s - 1.5s.

---

### 2.2 Habilidades de Corredor
1. **Lápida de Retorno — Invocación (`Grave_Cast`)**:
   - **Tipo**: R15 y R6.
   - **Prioridad**: `Action3`.
   - **Descripción**: Gesto rápido hacia el suelo (0.3s) plantando el ancla espiritual, sin congelar el movimiento horizontal del corredor.

2. **Parpadeo Sombrío — Salto Espectral (`Shadow_Blink`)**:
   - **Tipo**: R15 y R6.
   - **Prioridad**: `Action4`.
   - **Descripción**: Plegado rápido del cuerpo en el frame inicial de desvanecimiento y apertura elástica en la posición de destino (0.2s en total).

---

### 2.3 Mecánica del Ataúd Gótico (Prop & Rig)
1. **Ataúd — Azote Violento de Tapa (`Coffin_SlamShut`)**:
   - **Tipo**: Model Animation / Tween de Motor6D de la tapa.
   - **Descripción**: La tapa abierta del ataúd azota violentamente contra el marco en 0.25s con rebote elástico final.

2. **Runner Atrapado — Pose de Preso Gótico (`Coffin_TrappedPose`)**:
   - **Tipo**: R15 y R6.
   - **Prioridad**: `Action4` (Loop mientras está congelado).
   - **Descripción**: Brazos cruzados sobre el pecho estilo momia/vampiro durmiente o manos apoyadas en la madera frontal.

3. **Ataúd — Temblor Físico Progresivo en Rescate (`Coffin_RescueShake`)**:
   - **Tipo**: Procedural CFrame Shake / Animación procedural del ensamble.
   - **Descripción**: Vibración sutil que incrementa en intensidad mientras el rescatador mantiene la tecla `E`.

4. **Ataúd — Estallido de Tapa al Liberarse (`Coffin_BurstOpen`)**:
   - **Tipo**: Model Animation / Physics Impulse.
   - **Descripción**: La tapa vuela violentamente hacia atrás o estalla en pedazos con la salida triunfal del Runner.

---

## 3. Arquitectura y Ubicación en DataModel

```text
ReplicatedStorage/
  `-- ZeroAnimations/
        `-- Halloween/                 <-- [CREAR CARPETA]
              |-- Gransax_Cast         (Animation con AnimationId)
              |-- DarkWings_ChargeLoop (Animation con AnimationId)
              |-- DarkWings_Dash       (Animation con AnimationId)
              |-- Stunned              (Animation con AnimationId)
              |-- Grave_Cast           (Animation con AnimationId)
              |-- Shadow_Blink         (Animation con AnimationId)
              `-- Coffin_Trapped       (Animation con AnimationId)
```

---

## 4. Instrucciones de Implementación para el Subagente
1. Verificar si existen rigs R15 y R6 en `ReplicatedStorage.ZeroAnimations` como referencia de importación.
2. Crear un módulo `HalloweenAnimationConfig` en `ReplicatedStorage.Shared` para mapear los nombres clave de animaciones a sus correspondientes `AnimationId` (con fallbacks silenciosos si no se han subido aún los IDs definitivos).
3. Asegurar que las animaciones de acción tengan `Looped = false` y prioridades correctas (`Action3`/`Action4`) para que sobreescriban el ciclo de correr/caminar.
4. Conectar la reproducción de estas animaciones mediante señales remotas (`NetworkEvents`) o atributos (`ZeroDashSerial`, etc.) en lugar de acoplar lógica directamente en los servicios de servidor.

---

## 5. Check-list de Validación
- [ ] Carpeta `ReplicatedStorage.ZeroAnimations.Halloween` creada.
- [ ] `HalloweenAnimationConfig` registrado con todos los IDs y nombres clave.
- [ ] Prioridades y loops verificados para cada animación.
- [ ] Fallback procedural integrado en caso de que algún asset id no cargue.
