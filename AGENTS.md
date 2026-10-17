# AGENTS.md — Zero Project Workspace Guide and Task Tracker

> **Context**: Zero is a fast-paced multiplayer Roblox game (Hunter vs Runner / Freeze Tag).
> **Team Division**:
> - **Polaris (You + Antigravity)**: Server logic, technical architecture, networking, state machines, and modular services managed directly via Roblox Studio MCP / Team Create.
> - **KaiBit23 (Studio / MCP)**: Maps, lighting, 3D props, character animations, VFX, audio, and visual interface designs directly inside Roblox Studio.

---

## Safeguards and Working Boundaries (CRITICAL)

### 1. Flujo de Trabajo en Roblox Studio (Team Create / MCP)
- **Código Centralizado en Roblox Studio**: Todo el código, servicios e instancias residen y se gestionan 100% en la sesión activa de Roblox Studio (`Lugar de KaiBit23: 10072026_1`) mediante las herramientas MCP de Studio (`script_read`, `script_search`, `multi_edit`, `execute_luau`, etc.).
- **Sin Rojo ni GitHub**: Se eliminó la carpeta local `src/` y ya no se realiza sincronización ni versionado con Rojo ni GitHub.
- **Zonas y Responsabilidades**:
  - `ServerScriptService.Server` (Servicios del servidor: combate, estados, rondas, bots, datos, economía, etc.).
  - `ReplicatedStorage.Shared` (Configuración, constantes y eventos de red).
  - `StarterPlayer.StarterPlayerScripts` (Controladores de cliente, HUD, animaciones, VFX).
- **Golden Integration Rule**:
  - Respetar los assets, interfaces y modelos administrados por KaiBit23 (`Workspace`, `ZeroUI`, `ZeroAnimations`, `ZeroAudio`, `ZeroSoundAssets`, etc.).
  - Si un asset falta o no ha sido importado aún, nuestros scripts usan un fallback silencioso sin romper la ejecución.

---

## Road Map and General Checklist (Official Division)

### Phase 1: Rounds and Lobby + Debug Commands [COMPLETED]
- [x] State definitions (`RoundConfig`, `RoundStates`).
- [x] State machine in `RoundService` (`WAITING`, `INTERMISSION`, `ROUND_ACTIVE`, `ROUND_END`).
- [x] Decoupled spawn detection (`ZeroLobby`, `Map1_PlazaUrbana`, `Map2_PatioDeCarga`, plus `SpawnPoints/Runners` and `SpawnPoints/Hunters`).
- [x] Authorized chat commands (`/startround`, `/endround`, `/setstate`).
- [x] Rediseño de flujo `INTERMISSION`: Runners al mapa al inicio; Hunter a plataforma blanca provisional (`ZeroRuntime`); teletransporte de combate y asignación de roles al expirar.

### Phase 2: Hunter and Runner (Roles and PlayerState) [COMPLETED]
- [x] Role management (`Hunter`, `Runner`, `Lobby`) via `PlayerStateService`.
- [x] Random distribution: 1 Hunter and remaining Runners upon entering `ROUND_ACTIVE`.
- [x] Network attribute synchronization (`Role`).
- [x] Provisional overhead tags and highlights for testing.
- [x] Hunter disconnect handling with clean round termination (y re-selección durante Intermission a plataforma).

### Phase 3: Knife and Combat (Hitbox and Cooldowns) [COMPLETED]
- [x] Authoritative server-side `CombatService`.
- [x] Strict server cooldown (1.2s).
- [x] Hitbox resolution using `FindFirstAncestorOfClass("Model")` to bypass accessories/hats.
- [x] Detection via forward cone (150 degrees) and maximum range (6 studs).
- [x] Decoupled network events (`AttackRequest`, `AttackHitFeedback`).
- [x] Bloqueo estricto autoritativo de ataques fuera de `ROUND_ACTIVE`.

### Phase 4: Freeze, Rescue, and Victory Condition [COMPLETED]
- [x] Frozen state: `WalkSpeed = 0`, `JumpPower = 0`, `JumpHeight = 0`, physical anchoring (`Anchored = true`).
- [x] Rescue `ProximityPrompt` ("Rescatar Companero", 2.5s, 10 studs).
- [x] Rescue logic: Exclusively available to Runners in `Active` status.
- [x] Immediate victory condition if all Runners are frozen (Hunter) or time expires (Runners).
- [x] Desactivar Reset Character (Anti-suicidio táctico en cliente y fallback en servidor).

### Phase 5: Dash (Movement) [COMPLETED]
- [x] Jumping physics exploit fixed while frozen (anchoring and state machine lock).
- [x] Server authoritative cooldown and validation.
- [x] Safeguard: Do not touch animations or particle effects for dash. Leave animation playback to KaiBit23.
- [x] Non-intrusive cooldown HUD decoupled from `StarterGui` (DashFeedback y visibilidad en Intermission).

### Phase 6: Hunter Classes and Abilities [COMPLETED]
- [x] Interactive class selection GUI prompt during `INTERMISSION`.
- [x] Server-side `HunterClassService`.
- [x] Class 1 - Tracker: Revela siluetas de Runners durante 4s (25s cooldown).
- [x] Class 2 - Stalker: Sigilo e invisibilidad temporal con aumento de velocidad (20s cooldown).
- [x] Class 3 - Trapper: Coloca trampas de congelamiento en el suelo (15s cooldown).
- [x] Habilidad de Cazador - Pánico / Confusión: Invierte temporalmente los controles de movimiento (WASD invertido) del Runner.
- [x] CooldownHUD integration displaying active class name and cooldown timer.
- [x] Manejo de re-selección de Hunter si abandona durante selección en Intermission.

### Phase 7: Maps and Rotation [COMPLETED]
- [x] Podios físicos de selección de mapa en Lobby (`Workspace.ZeroLobby.HunterClasses` adaptado a Map Selection).
- [x] Previews de mapa 1:1 subidas a Roblox Asset Server (`Map1Plaza` y `Map2`).
- [x] Contador de votos en tiempo real en los carteles del Lobby.
- [x] `MapService`: Votación por pedestales, desempates/azar y resolución precisa de spawns por mapa y rol.
- [x] Integración de `RoundService` con `MapService` para rondas dinámicas entre `Map1_PlazaUrbana` y `Map2_PatioDeCarga`.

### Phase 8: Bots, DataStore, and Leaderboards [IN PROGRESS]
- [ ] `BotService`: Support for filling lobbies with PathfindingService bots when players are missing.
- [x] `DataService`: Persistent data storage using `ProfileService` for player statistics (wins, hunter_tags, rescues, streaks).
- [x] `LeaderboardService`: Lobby leaderboards (TOP WINS y TOP HUNTERS) en `ZeroLobby.Leaderboards` con OrderedDataStore.

### Phase 9: Thematic Music System & Isla Tiki Integration [COMPLETED]
- [x] Dual-Channel Crossfader (`MusicController`) con canales continuos `VoiceA` y `VoiceB` modulados con `TweenService` (2.0s fade curvo).
- [x] Playlists temáticas y soporte para canciones locales en `MusicConfig` (`LOBBY`, `Map3_IslaTiki`, `Map1_PlazaUrbana`, `Map2_PatioDeCarga`).
- [x] Transiciones reactivas al ciclo de juego (`LOBBY` en espera/fin de ronda; música temática en mapa activo/intermission).
- [x] Registro formal de `Map3_IslaTiki` en `MapConfig` y sincronización de `CurrentMap` en `ReplicatedStorage` y `RoundStatusUpdate`.
- [x] Ruteo maestro de música en `SoundService.ZeroMusic` con carpeta dedicada `SoundService.ZeroMusicTracks` y resolución automática de pistas por nombre/ID.
- [x] Fase tensa de clímax (`TENSE` en `MusicConfig`): 7 pistas oficiales conectadas con IDs reales en `SoundService.ZeroMusicTracks` y `MusicConfig`. Transición con solapamiento dinámico (Overlap Crossfade): la pista tensa entra de inmediato a volumen completo mientras la anterior se desvanece suavemente a 0 en 1.0s, eliminando la zona muerta perceptual de decibeles (ley de Leibniz/Weber-Fechner).
- [x] Comandos de reloj en chat (`/settimer <segundos>`, `/settime <segundos>`, `/time <segundos>`) vinculados a `RoundService.setRemainingTime` para pruebas y control de tiempo en vivo.
- [x] Orden preestablecido rotativo continuo (`Shuffle = false` en `MusicConfig`): estado de lista persistente por tema en `MusicController` (1 → 2 → 3... cíclico sin repeticiones A-B-A entre rondas).

### Phase 10: Monetization, Gamepasses & Dual Economy [COMPLETED]
- [x] Economía dual: `Coins` (monedas para cajas/cosméticos) y `Gems` (gemas para habilidades y progresión).
- [x] Cuarteto oficial de Gamepasses conectado con IDs reales y renderizado en UI: `VIP` (2025170299), `2× COINS` (2026664283), `2× GEMS` (2025602282) y `2× XP` (2026748305).
- [x] Catálogo de Developer Products conectado en `MarketplaceService.ProcessReceipt` (`ZeroWheelServer`):
  - Cajas de armas/varitas: `Común` (3717525574), `Rara` (3717525639), `Épica` (3717562012) y `Legendaria` (3717525682).
  - Packs de monedas: `1K` (3717562334), `10K` (3717562596) y `100K` (3717562754).
  - Packs de gemas: `100` (3717565388), `200` (3717565549) y `300` (3717565572).
- [x] 12 iconos oficiales subidos al CDN de Roblox (`rbxassetid://`) y enlazados en `ZeroUI` y `ZeroArmasClient`.
- [x] Almacenamiento seguro en `DataService` (ProfileService) con multiplicador pasivo de `2× XP` permanente.
- [x] `MonetizationService`: Gestión de MarketplaceService, cache de pases, cosméticos VIP (trail y tag en chat) y multiplicadores 2x.
- [x] Integración de recompensas en `RoundService`, `CombatService` y `PlayerStateService` (victorias, tags y rescates).
- [x] `ShopController`: HUD dual en cliente, actualización de tarjetas de pases y manejo seguro de compras.
- [x] Comandos de testing: `/addcoins`, `/addgems`, `/simulatepass` y `/clearpasses`.

### Phase 11: Runner Abilities System [COMPLETED]
- [x] Configuración centralizada de habilidades en `RunnerAbilityConfig` (Catálogo oficial de 10 habilidades de supervivencia):
  1. `Bloqueo Rápido`: Guardia reactiva de 0.6s que niega impacto de cuchillo y aplica micro-stun de 0.4s al atacante.
  2. `Bomba de Humo`: Nube densa de 3s que corta visión directa y apaga contorno (outline).
  3. `Mancha Resbaladiza`: Fluido en suelo que reduce tracción y velocidad del cazador 30% por 1.5s.
  4. `Super Salto`: Impulso vertical seco para librar alturas y obstáculos.
  5. `Camuflaje`: Semitransparencia y borrado de outline por 2s (cancelable al saltar o rescatar).
  6. `Desfibrilador`: Rescate instantáneo sin canalizar barra de 1.5s (limitado a 1 uso por ronda).
  7. `Señuelo`: Clon visual que corre en línea recta por 3s para desviar la atención.
  8. `Pulso de Empuje`: Onda frontal de corto alcance que desplaza al cazador hacia atrás.
  9. `Inyección de Adrenalina`: +20% velocidad por 2.5s tras rescate exitoso o al ser el último corredor vivo.
  10. `Sobrecarga de Dash`: Doble dash consecutivo con penalización de cooldown posterior (6s a 9-10s).
- [x] Validación y ejecución autoritativa en `RunnerAbilityService` con chequeo estricto de rol y estado.
- [x] Integración de cliente con `RunnerAbilityController` y feedback en `CooldownHUD`.

### Phase 12: Responsive Arcade UI & Visual FX [COMPLETED]
- [x] Rediseño estructural de `ZeroUI` a layout relativo multiplataforma (100% responsivo, sin lienzos rígidos 1600x900).
- [x] Unificación del cluster de acción inferior derecho (`DashBars`, `CooldownSweep`, slots de habilidad [Q] y [F]/[E]).
- [x] Header HUD dinámico con medidores de nivel, monedas, gemas, insignias de rol adaptativas y temporizador.
- [x] Sistema de luces dinámicas de feria y marquesina (`ZeroTimerLuzFX` y `ZeroRuletaLuzFX`) con 7 patrones cíclicos.
- [x] Micro-interacciones táctiles, animaciones elásticas y hover unificado en modales y drawer.

### Phase 13: Halloween Event 2026 (Spooky Season) [PLANNING]
- [ ] Documento de especificación oficial: `HALLOWEEN_EVENT_DESIGN.md`.
- [ ] Moneda única de evento: `Calabazas` (Pumpkins) en pool dinámico continuo (8-12 en mapa, 4-15 valor RNG).
- [ ] Evento de ronda "Luna Roja": Skybox carmesí, niebla naranja, música tensa y spawn/valor x2.
- [ ] Ataúd gótico de congelamiento: Animación de tapa azotando, feedback de temblor físico (shake) en rescate y estallido de murciélagos al liberarse.
- [ ] Habilidades de Cazador de Halloween:
  - `Lanza de Gransax`: Proyectil relámpago/espectral a distancia en salto.
  - `Alas Negras`: Embestida frontal cargada (wind-up telegrafiado) con aturdimiento (`Stun` 1.2-1.5s).
- [ ] Habilidades de Runner de Halloween:
  - `Lápida de Retorno`: Ancla temporal / recall limitado a 2 usos por ronda.
  - `Parpadeo Sombrío`: Teletransporte instantáneo no físico en línea recta (12-14 studs) para cruzar rejas y obstáculos.
- [ ] Caja de Halloween (Única): Varitas y cosméticos con sistema de retorno porcentual por duplicados.
- [ ] Ruleta de Halloween: Giros diarios gratis por login y giros extra con Calabazas.
- [ ] Ajustes de controles móviles y opción de Auto-Attack.

---

## Directory Conventions
 
### Source Storage & Team Create Workflow
- **Código Centralizado en Studio**: Todo el código de Luau reside directamente dentro del DataModel de Roblox Studio. No se mantienen copias locales en disco (`src/` eliminada).
- **Flujo de Trabajo Directo**: Las lecturas, modificaciones y pruebas se realizan en tiempo real en la sesión de Team Create a través del servidor MCP de Roblox Studio.

### DataModel Structure & Responsibilities

```text
ReplicatedStorage/
  |-- Shared/                <-- [POLARIS] Código compartido (Config, Constants, Network)
  |-- ZeroUI                 <-- [KAIBIT23] Constructor y estilos visuales UI
  |-- ZeroWheelConfig        <-- [KAIBIT23] Configuración de premios y probabilidades de la ruleta
  |-- ZeroWheelController    <-- [KAIBIT23] Controlador cliente de la ruleta
  |-- ZeroAudio              <-- [KAIBIT23] Módulo de gestión y reproducción de audio
  |-- ZeroSoundAssets/       <-- [KAIBIT23] Efectos de sonido (Click, Hover, Coin, Freeze, etc.)
  |-- ZeroAnimations/        <-- [KAIBIT23] Animaciones R15 y Sources R6 (Walk, Run, Jump, Dash, etc.)
  |-- ZeroSprintRequest      <-- [KAIBIT23] RemoteEvent para activar sprint
  `-- ZeroWheelRequest       <-- [KAIBIT23] RemoteFunction para giros de ruleta

ServerScriptService/
  |-- Server/                <-- [POLARIS] Lógica y servicios del servidor
  |-- ZeroSprint             <-- [KAIBIT23] Servidor de sprint (+6 WalkSpeed respetando estados)
  |-- ZeroWheelServer        <-- [KAIBIT23] Servidor de economía y giros con DataStore
  `-- ZeroWheelRules         <-- [KAIBIT23] Reglas de validación y premios de ruleta

StarterPlayerScripts/
  |-- Client/                <-- [POLARIS] Controladores de cliente y llamadas remotas
  |-- ZeroUIClient           <-- [KAIBIT23] Controlador del HUD, Modales y despacho de acciones
  |-- ZeroMovement           <-- [KAIBIT23] Reproductor procedural R6 (Sprint, LandRoll, Dash)
  |-- ZeroAnimationClient    <-- [KAIBIT23] Enlazador de animaciones R15 y escucha de DashFeedback
  |-- ZeroControls           <-- [KAIBIT23] Manejador de Shift (sprint) y Ctrl (shift-lock)
  |-- ZeroTimerLuzFX         <-- [POLARIS] Luces dinámicas de marquesina en TimerDisplay (7 patrones cíclicos)
  |-- ZeroRuletaLuzFX        <-- [POLARIS] Luces dinámicas de feria en RuletaNueva (7 patrones cíclicos)
  `-- ZeroSoundClient        <-- [KAIBIT23] Escuchador reactivo de audio (conectado a NetworkEvents)

StarterGui/
  `-- ZeroUI/                <-- [KAIBIT23] ScreenGui principal (HUD, Toast, Modales, Ruleta)

Workspace/
  |-- ZeroLobby              <-- [KAIBIT23] Estructura de lobby, spawn, pedestales de clases
  |-- Map1_PlazaUrbana       <-- [KAIBIT23] Mapa Plaza Urbana (Barriers, Buildings, SpawnPoints)
  |-- Map2_PatioDeCarga      <-- [KAIBIT23] Mapa Patio de Carga (Barriers, Structures, SpawnPoints)
  |-- ZeroBots/              <-- [KAIBIT23] Modelos de bots para pruebas (ZERO Bot 5)
  `-- ZeroRuntime/           <-- [SISTEMA] Contenedor de instancias dinámicas (Traps, etc.)
```

---

## Contratos de Integración con KaiBit23

1. **Movimiento y Dash**:
   - `ZeroUIClient` invoca `DashController.request()` cuando el usuario presiona el botón HUD de habilidad como Runner.
   - `ZeroAnimationClient` y `ZeroMovement` escuchan `NetworkEvents.DashFeedback` y el atributo `ZeroDashSerial` para reproducir la animación/pose direccional (`DashFront`, `DashBack`, `DashLeft`, `DashRight`).

2. **Audio Reactivo (`ZeroSoundClient`)**:
   - Escucha los remotes de Polaris: `AttackHitFeedback` (sonido Hit), `HunterAbilityFeedback` (sonido Ability/Error), `ClassSelectionConfirmed` (sonido Class), `RescueFeedback` (sonido Rescue) y `RoundStatusUpdate` (sonido RoundStart/RoundEnd y Countdown en últimos 3s de Intermission).
   - Reacciona a cambios en atributos: `Status == "Frozen"` (Freeze), `Coins` (Coin) y `ZeroDashSerial` (Dash).

3. **Sprint (`ZeroSprint`)**:
   - Suma `+6` a la velocidad base al correr con Shift.
   - Detecta si el jugador está `Frozen` para mantener WalkSpeed en 0.
   - Preserva y adapta cambios en `WalkSpeed` emitidos por `HunterClassService` (p. ej. boost de Acechador) y congelamiento/rescate.

4. **Economía y Estadísticas (`ZeroWheelServer`)**:
   - Administra `leaderstats.Coins` y atributos `Coins`, `Spins`, `NextFreeSpinAt` respaldados por `DataStoreService` (`ZeroWheel_v1`).
