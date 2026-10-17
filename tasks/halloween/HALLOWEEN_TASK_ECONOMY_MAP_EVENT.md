# Módulo: Economía de Calabazas y Evento "Luna Roja" — Evento de Halloween 2026 (Zero)

> **Rol del Agente**: Diseñador de Economía de Juego, Eventos Dinámicos de Servidor y DataStore.
> **Dominio de Trabajo**: `ServerScriptService.Server.PumpkinEventService`, persistencia de datos en `DataService` y renderizado atmosférico en cliente.
> **Desacoplamiento**: Maneja el ciclo de vida de los coleccionables en el mapa y la atmósfera global. No afecta directamente las habilidades ni el combate.

---

## 1. Alcance y Objetivos
1. Crear el sistema de **Calabazas** (moneda única de evento coleccionable en mapas durante rondas).
2. Implementar el pool dinámico continuo de recolección (8 a 12 unidades activas simultáneas con respawn automático).
3. Diseñar el evento climático aleatorio de clímax **"Luna Roja" (Blood Moon)** con multiplicador x2 y efectos visuales de cielo/niebla.
4. Integrar la persistencia de `Pumpkins` en `DataService` (ProfileService) y replicación al HUD.

---

## 2. Especificación Técnica de Mecánicas

### 2.1 Moneda Única: Calabazas (`Pumpkins`)
- **Regla Estricta**: No crear monedas secundarias para evitar saturación económica.
- **Persistencia**: Atributo de jugador `Pumpkins` y clave persistente en el perfil de `ProfileService` (`DataService`).
- **Lógica de Recolección**:
  - Detección de contacto con Runner (`Touched` en servidor con debouncing estricto por jugador).
  - Los Cazadores **NO** obtienen calabazas al congelar ni al tocarlas (evita snowballing).
  - Rango de recompensa base por unidad recogida: **4 a 15 Calabazas (RNG)**.
  - Sin marcado visual del corredor al recoger para mantener la fluidez táctica.

### 2.2 Pool Dinámico Continuo de Spawn
- **Capacidad**: Mantener entre **8 y 12 calabazas** activas en todo momento en el mapa en curso (`Map1_PlazaUrbana`, `Map2_PatioDeCarga`, `Map3_IslaTiki`).
- **Generación de Puntos de Spawn**:
  - Detectar puntos viables en el mapa mediante raycasts descendentes hacia el suelo del mapa.
  - Al ser recogida una calabaza, esperar de 2 a 4 segundos y reaparecer una nueva unidad en otra ubicación al azar.
- **Efectos Visuales del Modelo de Calabaza**:
  - Modelo ligero optimizado en `Workspace.ZeroRuntime.HalloweenPumpkins`.
  - Animación de aparición: Pop elástico (Tween de escala de 0 a 1).
  - Efecto de destello diagonal periódico (Highlight o ParticleEmitter sutil con destellos dorados).
  - Rotación flotante suave en eje Y.

### 2.3 Evento de Clímax: "Luna Roja" (Blood Moon)
- **Probabilidad**: 25% de probabilidad de activación por ronda, o activarse en los últimos 45 segundos de la partida.
- **Efectos del Evento**:
  - **Atmósfera**: Tween en `Lighting` cambiando `Sky` a rojo carmesí, `ColorCorrectionEffect` con tinte rojizo y `Atmosphere.Density` con niebla naranja espeluznante.
  - **Música**: Transición reactiva a pista tensa del evento vía `SoundService.ZeroMusic`.
  - **Multiplicador de Evento**:
    - El pool de calabazas se duplica temporalmente (hasta 16-20 calabazas en mapa).
    - El valor de recogida por calabaza se multiplica por 2 (de 8 a 30 Calabazas por recogida).
  - **Banner en Pantalla**: Notificación reactiva en HUD: *"¡LA LUNA ROJA HA ASCENDIDO! (CALABAZAS x2)"*.

---

## 3. Arquitectura y Ubicación en DataModel

```text
ServerScriptService/
  `-- Server/
        `-- PumpkinEventService.luau       <-- [POOL DE SPAWN, DETECCIÓN Y MULTIPLICADOR]

StarterPlayerScripts/
  `-- Client/
        `-- BloodMoonClient.luau           <-- [TRANSICIÓN VISUAL SUAVE DE LIGHTING Y BANNER]

ReplicatedStorage/
  `-- Shared/
        `-- PumpkinConfig.luau             <-- [LÍMITES DEL POOL, PROBABILIDADES Y MULTIPLICADORES]
```

---

## 4. Interfaces y Contratos de Red

### En `ReplicatedStorage.Shared.NetworkEvents`:
- `RemoteEvent`: `PumpkinCollectedFeedback` (Servidor -> Cliente: Efecto de sonido 'pop/coin' local y suma en HUD).
- `RemoteEvent`: `BloodMoonTriggered` (Servidor -> Todos los Clientes: Inicio / Fin del evento de Luna Roja con estado booleano).

---

## 5. Check-list de Validación
- [ ] Atributo `Pumpkins` registrado e inicializado en `DataService`.
- [ ] Pool dinámico de calabazas que mantiene 8-12 activas y las limpia al terminar la ronda (`ROUND_END`).
- [ ] Verificación de que el Hunter no pueda recolectar calabazas ni acumular por congelar.
- [ ] Transición fluida de iluminación en `BloodMoonClient` con restauración garantizada al volver al Lobby.
