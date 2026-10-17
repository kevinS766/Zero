# Módulo: Habilidades de Cazador — Evento de Halloween 2026 (Zero)

> **Rol del Agente**: Ingeniero de Mecánicas de Combate y Habilidades de Servidor / Cliente.
> **Dominio de Trabajo**: `ServerScriptService.Server.HunterHalloweenService` y `StarterPlayerScripts.Client.HunterHalloweenController`.
> **Desacoplamiento**: No modificar animaciones directamente (estas son manejadas por el módulo de animaciones). Solo activar atributos o eventos de red (`NetworkEvents`).

---

## 1. Alcance y Objetivos
Implementar la lógica completa de las dos habilidades temáticas del Cazador de Halloween:
1. **Lanza de Gransax** (Ataque a Distancia / Rayo Espectral).
2. **Alas Negras** (Embestida Cargada / Aturdimiento Stun).

---

## 2. Especificación Técnica de Habilidades

### 2.1 Habilidad 1: "Lanza de Gransax"
- **Inspiración**: *Bolt of Gransax* (Elden Ring).
- **Activación**: Tecla asignada de habilidad (p. ej. `F` o botón HUD de habilidad).
- **Flujo de Ejecución**:
  1. **Suspensión**: El Cazador se eleva en el aire suspendido durante 0.5s (`BodyVelocity` o `LinearVelocity` neutralizando gravedad Y).
  2. **Materialización**: En el cliente/servidor aparece el modelo de la lanza roja/espectral en la mano del cazador.
  3. **Lanzamiento de Proyectil**: Al expirar la suspensión (o trigger de animación), se dispara un proyectil a alta velocidad (180-220 studs/s) hacia la dirección a la que apunta el jugador.
  4. **Colisión / Hitbox**:
     - Detección de impacto mediante `Raycast` o `GetPartsInPart` en servidor con radio de explosión de 6-8 studs.
     - Si impacta a un Runner: Le aplica congelamiento directo (`Status = "Frozen"`) o daño/desestabilización crítica autoritativa.
  5. **Cooldown**: 28 a 32 segundos.

### 2.2 Habilidad 2: "Alas Negras"
- **Activación**: Mantener presionado el botón / tecla de habilidad.
- **Flujo de Ejecución**:
  1. **Fase de Carga (Wind-up)**:
     - Mantener presionado: El Cazador despliega alas oscuras (VFX/accesorios temporales).
     - Velocidad de movimiento reducida a un 70% durante la carga.
     - Tiempo mínimo de carga: 0.8s. Tiempo máximo: 2.5s (liberación forzada al límite).
     - Telegrafiado sonoro y visual audible/visible para los Runners cercanos.
  2. **Fase de Impulso (Embestida Explosiva)**:
     - Al soltar la tecla (si la carga >= 0.8s), se aplica un impulso horizontal violento hacia el frente (`LinearVelocity` de 80-100 studs/s durante 0.5s).
  3. **Impacto y Aturdimiento (`Stun`)**:
     - Hitbox frontal durante el avance (radio de 5 studs).
     - Al impactar a un Runner: Cancela la embestida, aplica efecto de sonido seco y le asigna el estado `Stunned = true` durante 1.2s - 1.5s (`WalkSpeed = 0`, `JumpPower = 0`, pantalla con efecto de distorsión sutil).
     - El aturdimiento deja al Runner vulnerable a un remate con cuchillo antes de que pueda recuperarse.
  4. **Cooldown**: 22 a 25 segundos.

---

## 3. Arquitectura y Ubicación en DataModel

```text
ServerScriptService/
  `-- Server/
        `-- HunterHalloweenService.luau     <-- [CREAR SERVICIO AUTORITATIVO]

StarterPlayerScripts/
  `-- Client/
        `-- HunterHalloweenController.luau  <-- [CREAR CONTROLADOR DE ENTRADA Y FX]

ReplicatedStorage/
  `-- Shared/
        `-- HunterHalloweenConfig.luau      <-- [CONFIGURACIÓN DE TIEMPOS, VELOCIDADES Y RADIOS]
```

---

## 4. Interfaces y Contratos de Red

### En `ReplicatedStorage.Shared.NetworkEvents`:
- `RemoteEvent`: `HunterGransaxCast` (Cliente -> Servidor: Petición de lanzamiento con dirección de mira).
- `RemoteEvent`: `HunterWingsCharge` (Cliente -> Servidor: Inicio / Liberación de carga de alas).
- `RemoteEvent`: `HunterAbilityFXFeedback` (Servidor -> Clientes: Replicación de efectos visuales, proyectiles y sonidos).

---

## 5. Check-list de Validación
- [ ] Módulo de configuración `HunterHalloweenConfig` creado con balance de cooldowns.
- [ ] `HunterHalloweenService` con validaciones de rol autoritativas (solo rol `Hunter` activo en `ROUND_ACTIVE`).
- [ ] Raycast y detección de impacto de la Lanza de Gransax en servidor.
- [ ] Fase de carga y embestida de Alas Negras con estado `Stunned` funcional.
- [ ] Sin interferencias con `HunterClassService` estándar (ejecución modular independiente).
