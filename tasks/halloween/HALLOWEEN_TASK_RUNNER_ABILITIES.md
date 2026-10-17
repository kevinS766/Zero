# Módulo: Habilidades de Corredor — Evento de Halloween 2026 (Zero)

> **Rol del Agente**: Desarrollador de Mecánicas de Supervivencia y Movimiento en Servidor / Cliente.
> **Dominio de Trabajo**: `ServerScriptService.Server.RunnerHalloweenService` y `StarterPlayerScripts.Client.RunnerHalloweenController`.
> **Desacoplamiento**: No tocar animaciones (delegadas al módulo de animaciones). Integrar de forma limpia con `RunnerAbilityConfig` y el HUD de habilidades sin alterar la lógica de cazadores.

---

## 1. Alcance y Objetivos
Implementar la lógica completa de las dos habilidades temáticas para los Corredores (Runners):
1. **Lápida de Retorno** (Ancla Temporal / Recall con límite de 2 usos por ronda).
2. **Parpadeo Sombrío** (Blink / Teletransporte cuántico instantáneo atravesando obstáculos delgados).

---

## 2. Especificación Técnica de Habilidades

### 2.1 Habilidad 1: "Lápida de Retorno" (Recall)
- **Mecánica**:
  1. **Invocación del Ancla**:
     - Al presionar la tecla de habilidad, el Runner planta una lápida luminosa (`GraveAnchor`) en su posición actual (`CFrame`).
     - Se instancia un modelo provisional de lápida con brillo espectral en `Workspace.ZeroRuntime` visible para todos los jugadores.
     - Se inicia una ventana activa de **4.0 segundos**.
  2. **Activación del Retorno**:
     - Si el jugador presiona nuevamente la tecla dentro de la ventana de 4 segundos, o si el tiempo expira: el Runner se teletransporta instantáneamente de regreso al `CFrame` de la lápida.
     - Destello espectral y sonido sutil de tumba en origen y destino.
     - La lápida se destruye de inmediato.
  3. **Restricciones y Balance Estricto**:
     - **Máximo 2 usos por ronda por jugador**: Al agotarse las 2 cargas, la habilidad se bloquea hasta la siguiente ronda (`ROUND_ACTIVE`).
     - Si el jugador es congelado (`Status == "Frozen"`) mientras la ventana de 4 segundos está activa, el retorno se cancela inmediatamente para evitar exploits de rescate automático.
  4. **Cooldown entre usos**: 15 segundos (dentro del límite de 2 cargas).

### 2.2 Habilidad 2: "Parpadeo Sombrío" (Blink)
- **Mecánica**:
  1. **Teletransporte No Físico**:
     - Desplazamiento instantáneo (en el mismo frame) de **12 a 14 studs** en la dirección frontal de la cámara (`LookVector`).
     - A diferencia del Dash físico (que colisiona con cualquier pieza o pared gruesa), el Parpadeo atraviesa rejas delgadas, barrotes y huecos de barandillas.
  2. **Validación de Espacio y Anti-Clip**:
     - Lanzar un `Raycast` desde la posición actual hasta el destino deseado ignorando piezas marcadas como "Permeable" o delgadas (< 1 stud de espesor).
     - Si la posición final colisiona con el interior de un bloque sólido macizo (pared gruesa o terreno no jugable), retraer el punto de teletransporte a la superficie libre más cercana para evitar quedar atrapado dentro de geometrías.
  3. **Feedback Audiovisual**:
     - Rastro de sombras y partículas de humo negro en la posición inicial y final.
  4. **Cooldown Elevado**: 20 segundos (recurso de escape de emergencia de alto valor).

---

## 3. Arquitectura y Ubicación en DataModel

```text
ServerScriptService/
  `-- Server/
        `-- RunnerHalloweenService.luau     <-- [LÓGICA AUTORITATIVA DE RECALL Y BLINK]

StarterPlayerScripts/
  `-- Client/
        `-- RunnerHalloweenController.luau  <-- [CLIENTE: INPUT, PREDICCIÓN Y VFX LOCAL]

ReplicatedStorage/
  `-- Shared/
        `-- RunnerHalloweenConfig.luau      <-- [CONFIGURACIÓN DE CARGAS, COOLDOWNS Y DISTANCIAS]
```

---

## 4. Interfaces y Contratos de Red

### En `ReplicatedStorage.Shared.NetworkEvents`:
- `RemoteEvent`: `RunnerRecallRequest` (Cliente -> Servidor: Plantar ancla / Forzar retorno).
- `RemoteEvent`: `RunnerBlinkRequest` (Cliente -> Servidor: Petición de teletransporte con vector dirección).
- `RemoteEvent`: `RunnerHalloweenFeedback` (Servidor -> Clientes: Actualización de cargas restantes y VFX).

---

## 5. Check-list de Validación
- [ ] Límite de 2 usos por ronda para la Lápida verificado en el servidor.
- [ ] Cancelación de retorno si el Runner es congelado durante la ventana de recall.
- [ ] Validación de pared delgada vs pared gruesa en el Parpadeo Sombrío para prevenir bugs fuera de mapa.
- [ ] Integración con el sistema de Cooldown HUD existente en cliente.
