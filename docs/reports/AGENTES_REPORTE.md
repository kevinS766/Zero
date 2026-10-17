# Reporte de Ejecución — Agente #3: Rediseño de UI y Controllers de Interfaz

> **Fecha**: 13 de Octubre de 2026  
> **Agente**: Agente #3 (Polaris / Antigravity)  
> **Área**: UI / UX, Controllers de Cliente y Networking de Interfaz  
> **Estado**: Completado con éxito  

---

## 1. Objetivo General
Rediseñar por completo la interfaz de usuario de Zero (HUD, barras de estado, modales y botones de acción) reemplazando la maquetación fija y saturada previa por un HUD limpio, responsivo, moderno y coherente con la identidad arcade de Zero, resolviendo de forma definitiva los solapamientos entre `ZeroUI`, `CooldownHUD` y `RoleHUD`.

---

## 2. Archivos Modificados

| Archivo | Rol / Modificación |
|---|---|
| [`src/shared/ZeroUI.luau`](file:///C:/Users/polar/Zero/src/shared/ZeroUI.luau) | Reconstrucción estructural del ScreenGui con posicionamiento relativo por `AnchorPoint` y `UDim2.fromScale`, eliminando el lienzo rígido de 1600×900. |
| [`src/client/StarterPlayerScripts/ZeroUIClient.client.luau`](file:///C:/Users/polar/Zero/src/client/StarterPlayerScripts/ZeroUIClient.client.luau) | Controlador de cliente: bindings dinámicos a atributos de rol, economía, nivel, temporizador, lógica del drawer colapsable y adaptación fluida. |
| [`src/client/StarterPlayerScripts/ZeroUIExtrasClient.client.luau`](file:///C:/Users/polar/Zero/src/client/StarterPlayerScripts/ZeroUIExtrasClient.client.luau) | Micro-interacciones de modales, botón de retorno en regalos, ajuste responsivo de `ScrollingFrame` sin offsets destructivos y animación elástica de entrada. |
| [`src/client/StarterPlayerScripts/ZeroUIHover.client.luau`](file:///C:/Users/polar/Zero/src/client/StarterPlayerScripts/ZeroUIHover.client.luau) | Sistema unificado de feedback táctil y hover adaptativo (escala limpia sin rotación brusca en botones compactos del drawer y action HUD). |
| [`src/client/StarterPlayerScripts/Client/Controllers/CooldownHUD.luau`](file:///C:/Users/polar/Zero/src/client/StarterPlayerScripts/Client/Controllers/CooldownHUD.luau) | Unificación de barras de cooldown: desacoplado del centro de la pantalla e integrado en el Action HUD inferior derecho (`DashBars` + `CooldownSweep`). |
| [`src/client/StarterPlayerScripts/Client/Controllers/RoleHUD.luau`](file:///C:/Users/polar/Zero/src/client/StarterPlayerScripts/Client/Controllers/RoleHUD.luau) | Integración directa con el Header HUD de `ZeroUI`, eliminando banners duplicados y activando transiciones elásticas en cambios de rol. |

---

## 3. Arquitectura y Soluciones Implementadas

### A. Layout Responsivo Multiplataforma (PC, Consola y Móvil)
- **Problema previo**: Se utilizaba un lienzo estático en coordenadas absolutas de 1600×900 escalado de forma artificial con un `UIScale` global, lo que deformaba la interfaz en pantallas estrechas o móviles y descolocaba los botones.
- **Solución implementada**:
  - `HUD` ahora ocupa el 100% de la pantalla (`UDim2.fromScale(1, 1)`) con fondo transparente.
  - Cada subsistema del HUD cuenta con su propio `AnchorPoint` independiente:
    - **Header**: Anclaje superior central `(0.5, 0)` y esquinas superiores.
    - **Drawer lateral**: Anclaje vertical izquierdo `(0, 0.5)`.
    - **Action HUD**: Anclaje inferior derecho `(1, 1)`.
    - **Widgets de estado (Congelado y Rescate)**: Anclaje inferior central `(0.5, 1)`.

### B. Barra Superior (Header HUD)
- **Top-Left (Economía y Progresión)**:
  - `Currency`: Muestra contadores actualizados en tiempo real de Monedas (`Coins`) y Gemas (`Gems`) con iconos nítidos y formato compacto.
  - `Level`: Barra de experiencia proporcional con indicador de nivel actual (`NV X • Y/Z XP`).
- **Top-Center (Temporizador y Estado de Ronda)**:
  - `RoundStatus`: Visualizador de fase actual (`Phase`), reloj digital estilizado (`Timer`), y conteo en vivo de participantes (`Counts`).
  - `Role`: Insignia de rol dinámica ubicada justo debajo del reloj. Adopta colores y gradientes arcade acordes al estado (`Runner` = azul eléctrico, `Hunter` = rojo neón, `Frozen` = cian escarchado).
- **Top-Right (Ajustes y Espectador)**:
  - Botón circular de ajustes (`Open_Settings`) y botón contextual de espectador (`Open_Spectate`), accesibles sin tapar el juego.

### C. Cluster de Acción Inferior Derecho (Action HUD)
- **Dash ([Q])**:
  - Botón principal de Dash (`hud.Skill`) con badge de tecla `[Q]`, icono y texto de estado.
  - Marco de enfriamiento `CooldownSweep` que realiza un barrido visual animado durante el cooldown.
- **Habilidad Especial ([F] / [E])**:
  - Ranura para habilidad de Cazador (`hud.HunterSkill`) o habilidades de arma, con cuenta regresiva en segundos y barrido de recarga.
- **Micro-indicadores Direccionales (`DashBars`)**:
  - Tres micro-indicadores (`◀▶ Lados`, `▲ Frente`, `▼ Atrás`) situados directamente sobre el botón de Dash.
  - Coordinados por `CooldownHUD`, mostrando el estado ("OK" o cuenta regresiva) y barra de progreso de cada tipo de dash.

### D. Widgets de Rescate y Congelamiento (Bottom-Center)
- **Rescate (`hud.RescueState`)**:
  - Widget rectangular con tipografía FredokaOne ("MANTÉN E PARA RESCATAR") y barra horizontal de progreso continuo (`Track` y `Fill`).
- **Estado Congelado (`hud.FrozenState`)**:
  - Insignia no invasiva `❄️ ¡CONGELADO!` con temporizador restante en segundos y mensaje de apoyo.
  - Separados físicamente del Action HUD y de CooldownHUD para evitar solapamientos durante situaciones de combate intenso.

### E. Drawer Lateral Compacto y Colapsable (`hud.Navigation`)
- Se sustituyó la cuadrícula anterior de 8 botones masivos por una barra vertical delgada de 56 px de ancho.
- Incluye botón de colapso/expansión (`CollapseToggle`):
  - Al pulsar `◀`, la barra se oculta hacia el borde de la pantalla dejando un pestaña mínima `▶` para restaurarla.
  - Se oculta de forma automática al entrar a una partida activa (`enJuego()`), maximizando la visibilidad del jugador.
- Mantiene plena compatibilidad con dependencias externas como `ZeroPruebasClient`.

### F. Modales Responsivos
- Los paneles de **Tienda**, **Ruleta**, **Misiones**, **Ajustes**, **Inventario** y **Recompensas** ahora utilizan `UISizeConstraint` (máximo 940×660 px) y centrado automático `(0.5, 0.5)`.
- Se eliminaron las posiciones fijas que cortaban el contenido en pantallas de baja resolución.

---

## 4. Verificación de Salvaguardas y Archivos Prohibidos

Durante toda la ejecución se respetaron de forma estricta los límites del proyecto:
- **NO** se modificó `src/server/Server/Services/DebugCommandService.luau`
- **NO** se modificó `src/server/Server/Services/RoundService.luau`
- **NO** se modificó `src/server/Server/Services/CombatService.luau`
- **NO** se modificó `src/server/Server/Services/DashService.luau`
- **NO** se modificó `src/server/ZeroPruebas.luau` ni `src/client/StarterPlayerScripts/ZeroPruebasClient.client.luau`
- **NO** se modificó `src/server/Server/Services/RunnerAbilityService.luau` ni archivos bajo `src/shared/VFX/*`


---

# Reporte de Ejecución — Agente #2: Comandos Administrativos y Testing Zone

> **Fecha**: 13 de Octubre de 2026  
> **Agente**: Agente #2 (Polaris / Antigravity)  
> **Área**: Servicios de Servidor, Comandos Debug, Ciclo de Rondas y Testing Zone  
> **Estado**: Completado con éxito  

---

## 1. Objetivo General
Reparar de forma definitiva el funcionamiento de los comandos administrativos en el motor (`/startround`, `/endround`), implementar el comando `/nocooldowns` (`/nocd`), configurar el bypass de cooldown y el soporte para la penalización de Sobrecarga de Dash (`DashOverload`), y transformar la Zona de Pruebas (`ZeroArenaPruebas` / `ZeroPruebas`) en un entorno de pruebas interactivo en vivo con selector de rol Runner, catálogo de las 10 habilidades de Runner y dummies especializados reactivos.

---

## 2. Archivos Modificados

| Archivo | Rol / Modificación |
|---|---|
| [`src/server/Server/Services/DebugCommandService.luau`](file:///C:/Users/polar/Zero/src/server/Server/Services/DebugCommandService.luau) | Corrección del stripping de alias de `TextChatCommand` en comandos sin argumentos. Registro de `/nocooldowns` y `/nocd`. Verificación de permisos para el creador del juego y grupo. |
| [`src/server/Server/Services/RoundService.luau`](file:///C:/Users/polar/Zero/src/server/Server/Services/RoundService.luau) | Carga forzada de mapa con `MapService.finalizeChosenMap()` y `mapReady = true` al ejecutar `/startround`. Soporte para pruebas en solitario sin abortar por falta de rivales. |
| [`src/shared/Shared/Config/RoundConfig.luau`](file:///C:/Users/polar/Zero/src/shared/Shared/Config/RoundConfig.luau) | Configuración de permisos: inclusión del UserId de KaiBit23 (`121517633`), ID de grupo admin (`13912900`) y rango mínimo (`254`). |
| [`src/server/Server/Services/DashService.luau`](file:///C:/Users/polar/Zero/src/server/Server/Services/DashService.luau) | Lectura de `ZeroNoCooldown` (global y por jugador). Lectura y consumo de `DashOverload` elevando el siguiente cooldown a 9.5 s. |
| [`src/server/Server/Services/HunterClassService.luau`](file:///C:/Users/polar/Zero/src/server/Server/Services/HunterClassService.luau) | Lectura de `ZeroNoCooldown` para bypass inmediato de recargas en habilidades de clases Hunter (Rastreador, Acechador, Trampero). |
| [`src/server/ZeroPruebas.luau`](file:///C:/Users/polar/Zero/src/server/ZeroPruebas.luau) | Dummies interactivos especializados (congelado con `RescuePrompt`, atacante con parry reactivo y móviles con lentitud/empuje). Soporte para cambio de rol a Runner y equipamiento de las 10 habilidades. Activación de `ZeroNoCooldown` por defecto. |
| [`src/client/StarterPlayerScripts/ZeroPruebasClient.client.luau`](file:///C:/Users/polar/Zero/src/client/StarterPlayerScripts/ZeroPruebasClient.client.luau) | Interfaz ampliada con selector de roles `[ CAZADOR ]` / `[ CORREDOR ]` y catálogo desplegable con las 10 habilidades de Runner vinculadas a `RunnerAbilityConfig`. |

---

## 3. Arquitectura y Soluciones Implementadas

### A. Corrección de Comandos en TextChatService
- **Causa raíz diagnosticada**: En el sistema moderno de TextChatService, `TextChatCommand.Triggered(textSource, rawText)` consume el alias del comando. Al escribir `/startround` o `/endround`, el motor pasa `rawText` vacío (`""`), por lo que la función `executeCommand` no encontraba coincidencia de comando y fallaba silenciosamente.
- **Solución implementada**:
  - En `DebugCommandService.init`, la conexión de `Triggered` evalúa `rawText`. Si no inicia con `"/"`, reconstruye el comando original anteponiendo el `primaryAlias` con los argumentos recibidos.
  - Se habilitó ejecución tanto en TextChatService moderno como en Legacy Chat y mediante el evento interno `ServerStorage.ZeroDebugComando`.

### B. Comando `/nocooldowns` (`/nocd`) y Soporte `DashOverload`
- **Comando global**:
  - Se registró `/nocooldowns` con alias secundario `/nocd`. Alterna el atributo global `ServerScriptService:SetAttribute("ZeroNoCooldown", boolean)`.
- **Integración en DashService y HunterClassService**:
  - Ambos servicios consultan `ServerScriptService:GetAttribute("ZeroNoCooldown") == true` o `player:GetAttribute("ZeroNoCooldown") == true`. Si está activo, los tiempos de espera se reducen a 0 s.
- **Penalización de Sobrecarga de Dash (`DashOverload`)**:
  - `DashService.requestDash` verifica si el jugador tiene el atributo `DashOverload`. Al detectarlo, aplica un cooldown penalizado de 9.5 s a la recarga de ese dash, limpia el atributo del jugador y emite el valor al cliente mediante `DashExecute` para sincronizar la barra visual.

### C. Carga Forzada de Mapa y Partidas en Solitario en RoundService
- **Carga de Mapa sin Intermission**:
  - Al forzar `/startround`, el estado salta directamente a `ROUND_ACTIVE`. Si `mapReady` se encuentra en `false`, `RoundService` invoca `mapServiceRef.finalizeChosenMap()` y establece `mapReady = true` antes de disparar la teletransportación, evitando que los jugadores caigan al vacío o sean devueltos al lobby.
- **Soporte de Pruebas en Solitario**:
  - En `RoundService.startLoop`: Si el roster activo tiene 1 solo participante (`#eligibleRoster() <= 1`), no se cancela la ronda con "Faltan jugadores" por la ausencia de cazador rival ni se fuerza la reasignación destructiva de roles.
  - En `checkWinCondition()`: Se añadió una guarda para evitar declarar victoria automática del cazador por falta de corredores cuando se trata de una prueba individual.
  - En `onActorRemoved`: Solo se cancela por desconexión de cazador si hay más de 1 jugador en la partida.

### D. Permisos de Administrador en Servidores Live
- En `RoundConfig.luau` se registraron las credenciales de administración:
  - `ADMIN_USER_IDS`: Incluye el ID oficial de KaiBit23 (`121517633`).
  - `ADMIN_GROUP_ID`: `13912900` con rango mínimo `254`.
- En `DebugCommandService.isAuthorized`: Se valida automáticamente si `RunService:IsStudio()`, si el usuario es el creador directo de la experiencia (`game.CreatorId`), si su UserId figura en la lista o si cumple el rango en el grupo de Roblox.

### E. Zona de Pruebas (ZeroPruebas): Dummies y Modo Runner
- **ZeroNoCooldown en la Arena**:
  - Al teletransportarse a la arena (`accion == "ir"`), el servidor activa `p:SetAttribute("ZeroNoCooldown", true)`, y lo limpia al regresar al lobby (`salir`).
- **Dummy Congelado (Prueba de Desfibrilador)**:
  - Inicializado en estado `Frozen` con `Role = "Runner"` y `Highlight` cian.
  - Posee un `RescuePrompt` interactivo (`ActionText = "Rescatar (o Desfibrilador)"`).
  - Al ser rescatado por un jugador (o mediante el uso del `Desfibrilador`), se descongela y, tras 6 segundos, se auto-congela de nuevo restaurando su prompt para permitir pruebas consecutivas ilimitadas.
- **Dummy Atacante (Prueba de Bloqueo Rápido)**:
  - Inicializado con `Role = "Hunter"`.
  - Cada 2.5 s busca al jugador más cercano en un radio de 8.5 studs y lanza un ataque frontal.
  - Si el jugador activó `Bloqueo Rápido` (`BloqueoShield` o atributo `BloqueoRapido`), se activa un contraataque parry automático con `BloqueoRapidoVFX.parry`, aturdiendo al dummy durante 0.4 s y actualizando su cartel a `[¡PARRY RECHAZADO!]`. Si el jugador no bloquea, el golpe conecta y lo desplaza.
- **Dummies Móviles (Prueba de Mancha Resbaladiza y Pulso de Empuje)**:
  - Tienen rol `Hunter` y patrullan lateralmente.
  - Detectan charcos de `ManchaResbaladiza` (`SlickPuddle`) reduciendo su velocidad al 70% durante 1.5 s con la etiqueta `[LENTO (Mancha)]`.
  - Reaccionan a fuerzas de empuje de `PulsoEmpuje` desplazando su vector base hacia atrás.
- **Selector de Roles y Habilidades en Cliente (`ZeroPruebasClient`)**:
  - Botones superiores de alternancia `[ CAZADOR ]` y `[ CORREDOR ]`.
  - Al cambiar a Corredor, el inventario oculta las armas del cazador y presenta una lista de desplazamiento con las 10 habilidades de Runner configuradas en `RunnerAbilityConfig.ORDER`.
  - Al hacer clic en cualquier habilidad, se invoca `pedir("habilidad_runner", id)`, equipándola inmediatamente tanto en atributos del jugador como en el personaje y resaltando la selección con `▶`.

---

## 4. Verificación de Salvaguardas y Archivos Prohibidos

Durante la ejecución del Agente #2 se mantuvieron intactos los archivos protegidos:
- **NO** se modificó `src/server/Server/Services/CombatService.luau`
- **NO** se modificó `src/shared/ZeroUI.luau` ni `src/client/StarterPlayerScripts/ZeroUIClient.client.luau`
- **NO** se modificó `src/client/StarterPlayerScripts/Client/Controllers/RunnerAbilityController.luau`
- **NO** se modificó `src/server/Server/Services/RunnerAbilityService.luau`
- **NO** se modificó ningún archivo bajo `src/shared/VFX/*`


---

# Reporte de Ejecución — Agente #1: Habilidades de Runners y Sistema de VFX Modulares

> **Fecha**: 13 de Octubre de 2026  
> **Agente**: Agente #1 (Polaris / Antigravity)  
> **Área**: Lógica de Servidor, Red, Controllers de Cliente y Sistema de VFX de Runners  
> **Estado**: Completado con éxito  

---

## 1. Objetivo General
Implementar el sistema completo de 10 habilidades activas para Runners con su lógica autoritativa en el servidor, controlador en cliente, intercepción en el combate cuerpo a cuerpo y efectos visuales (VFX) modulares replicados mediante estándares procedurales (`TweenService`, `Debris`, esferas ForceField, Beams y ParticleEmitters).

---

## 2. Archivos Creados y Modificados

| Archivo | Estado | Rol / Modificación |
|---|---|---|
| [`src/shared/Shared/Config/RunnerAbilityConfig.luau`](file:///C:/Users/polar/Zero/src/shared/Shared/Config/RunnerAbilityConfig.luau) | **CREADO** | Configuración centralizada de las 10 habilidades (nombres, descripciones, cooldowns, radios, duraciones, empuje y multiplicadores). |
| [`src/server/Server/Services/RunnerAbilityService.luau`](file:///C:/Users/polar/Zero/src/server/Server/Services/RunnerAbilityService.luau) | **CREADO** | Servicio autoritativo: cooldowns, validación de rol `Runner` y estado `Active`, consulta de bypass `ZeroNoCooldown`, ejecución autoritativa, aturdimiento de cazadores y límites por ronda. |
| [`src/client/StarterPlayerScripts/Client/Controllers/RunnerAbilityController.luau`](file:///C:/Users/polar/Zero/src/client/StarterPlayerScripts/Client/Controllers/RunnerAbilityController.luau) | **CREADO** | Controlador de cliente: captura de input (`[F]` y gamepad `ButtonX`), debounce y predicción local de recarga, despacho al servidor y escucha de feedback. |
| [`src/shared/VFX/Runner/BloqueoRapidoVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/BloqueoRapidoVFX.luau) | **CREADO** | Escudo ForceField cian perimetral, destello de parry exitoso con chispas radiales y aturdimiento eléctrico sobre la cabeza del atacante. |
| [`src/shared/VFX/Runner/BombaHumoVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/BombaHumoVFX.luau) | **CREADO** | Nube densa de humo volumétrico procedural y partículas oscuras que anulan la visión directa y atenúan el outline. |
| [`src/shared/VFX/Runner/ManchaResbaladizaVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/ManchaResbaladizaVFX.luau) | **CREADO** | Charco plano con refracción y reflejo de aceite/vidrio en suelo, burbujas y salpicadura reactiva al resbalar. |
| [`src/shared/VFX/Runner/SuperSaltoVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/SuperSaltoVFX.luau) | **CREADO** | Anillo de choque horizontal en suelo, columna de viento explosiva vertical y estela ascendente. |
| [`src/shared/VFX/Runner/CamuflajeVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/CamuflajeVFX.luau) | **CREADO** | Onda de distorsión refractiva, aplicación de semitransparencia (0.85), ocultamiento de highlight y pop de humo al salir. |
| [`src/shared/VFX/Runner/DesfibriladorVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/DesfibriladorVFX.luau) | **CREADO** | Arco de rayo eléctrico continuo (`Beam`) entre rescatador y víctima, chispas de alta tensión y fractura luminosa del hielo. |
| [`src/shared/VFX/Runner/SenueloVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/SenueloVFX.luau) | **CREADO** | Cortina de humo rápida en el punto de aparición y desaparición del clon. |
| [`src/shared/VFX/Runner/PulsoEmpujeVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/PulsoEmpujeVFX.luau) | **CREADO** | Onda de choque cónica translúcida que viaja hacia adelante y ráfaga concentrada de viento cinético. |
| [`src/shared/VFX/Runner/InyeccionAdrenalinaVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/InyeccionAdrenalinaVFX.luau) | **CREADO** | Destello ardiente dorado/naranja, aura de energía pulsante y líneas de velocidad en el torso. |
| [`src/shared/VFX/Runner/SobrecargaDashVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/SobrecargaDashVFX.luau) | **CREADO** | Descarga eléctrica cian/roja intensa, chispas crepitantes y vapor de sobrecalentamiento en extremidades. |
| [`src/shared/VFX/Runner/RunnerVFX.luau`](file:///C:/Users/polar/Zero/src/shared/VFX/Runner/RunnerVFX.luau) | **CREADO** | Módulo índice y despachador central de eventos visuales sincronizado con `RunnerAbilityEffect`. |
| [`src/shared/Shared/Network/NetworkEvents.luau`](file:///C:/Users/polar/Zero/src/shared/Shared/Network/NetworkEvents.luau) | **MODIFICADO** | Registro de RemoteEvents `RunnerAbilityRequest`, `RunnerAbilityFeedback` y `RunnerAbilityEffect` con constantes y getters dedicados. |
| [`src/server/Server/Services/CombatService.luau`](file:///C:/Users/polar/Zero/src/server/Server/Services/CombatService.luau) | **MODIFICADO** | Intercepción de ataque: comprobación de guardia reactiva (`BloqueoRapidoActive` / `isBlocking`), aplicación de micro-aturdimiento al cazador y anulación del congelamiento. |
| [`src/server/Server.server.luau`](file:///C:/Users/polar/Zero/src/server/Server.server.luau) | **MODIFICADO** | Inyección de dependencias e inicialización de `RunnerAbilityService.init(PlayerStateService, RoundService)`. |
| [`src/client/StarterPlayerScripts/Client.client.luau`](file:///C:/Users/polar/Zero/src/client/StarterPlayerScripts/Client.client.luau) | **MODIFICADO** | Inicialización del controlador de cliente `RunnerAbilityController.init(CooldownHUD)`. |

---

## 3. Arquitectura y Soluciones Implementadas

### A. Catálogo Centralizado de Habilidades (`RunnerAbilityConfig`)
Se formalizó la lista oficial de 10 habilidades activas para los corredores en `RunnerAbilityConfig.luau`:
1. **Bloqueo Rápido**: Guardia reactiva de 0.6 s. Si el cazador golpea durante la ventana, el ataque es neutralizado por completo y el atacante recibe un micro-aturdimiento de 0.4 s (cooldown: 14 s).
2. **Bomba de Humo**: Cortina esférica de 14 studs de radio por 3 s. Corta visión directa y oculta el outline (`RoleHighlight`) de los corredores ubicados dentro del área (cooldown: 20 s).
3. **Mancha Resbaladiza**: Charco plano de aceite/hielo de 7 studs de radio colocado sobre el suelo por 8 s. Si el cazador lo pisa, reduce su velocidad de desplazamiento un 30% y su tracción durante 1.5 s (cooldown: 16 s).
4. **Super Salto**: Impulso vertical explosivo instantáneo (+75 studs/s en el eje Y) para ganar altura de escape o saltar sobre obstáculos (cooldown: 12 s).
5. **Camuflaje**: Invisibilidad parcial con semitransparencia (0.85) y remoción del highlight por 2 s. Realizar cualquier interacción o rescate cancela el efecto anticipadamente (cooldown: 18 s).
6. **Desfibrilador**: Rescate instantáneo sin canalizar la barra de rescate a compañeros congelados en un radio de 10 studs. Limitado autoritativamente a 1 solo uso por ronda por jugador.
7. **Señuelo**: Genera un clon con la apariencia, vestimenta y accesorios del corredor que corre en línea recta a velocidad estándar durante 3 s para confundir al cazador (cooldown: 22 s).
8. **Pulso de Empuje**: Onda cinética frontal en un cono de 130° (14 studs) que empuja al cazador varios studs hacia atrás sin inmovilizarlo ni congelarlo (cooldown: 16 s).
9. **Inyección de Adrenalina**: Bono de velocidad (+20%) durante 2.5 s. Activable por tecla y con sinergia pasiva reactiva al completar un rescate o quedar como último superviviente (cooldown: 20 s).
10. **Sobrecarga de Dash**: Reseteo instantáneo de la recarga del Dash para encadenar un segundo impulso consecutivo; activa el estado `player:SetAttribute("DashOverload", true)` que eleva el siguiente cooldown a 9.5 s (cooldown: 24 s).

### B. Servicio Autoritativo del Servidor (`RunnerAbilityService`)
- **Validaciones Rígidas**:
  - Verifica que el emisor posea el rol `Runner` y estado `Active` (no congelado ni en transición).
  - Comprueba que el personaje esté vivo y su `HumanoidRootPart` no esté anclado.
- **Bypass de Cooldowns para Pruebas**:
  - Consulta `ServerScriptService:GetAttribute("ZeroNoCooldown") == true` y atributos específicos del jugador (`p:GetAttribute("ZeroNoCooldown") == true`).
- **Mecánica de Micro-Aturdimiento**:
  - Implementa `applyStun(hunterPlayer, duration)`: suspende la velocidad del cazador (`WalkSpeed = 0`, `JumpPower = 0`, velocidad lineal a cero) y la restituye de forma limpia respetando estados especiales (como el boost de sigilo del Acechador).
- **Control de Usos Únicos por Ronda**:
  - Monitorea el atributo `RoundId` en `ReplicatedStorage`. Al reiniciar la ronda, limpia el registro `defibrillatorUsedThisRound` y vacía los contenedores en `Workspace.ZeroRuntime.RunnerZones` y `Decoys`.

### C. Intercepción de Ataques en Combate (`CombatService`)
- Se insertó una comprobación previa a `playerStateServiceRef.freezeRunner(targetPlayer, hunterPlayer)` en `CombatService.requestAttack`:
  - Si el Runner tiene activo el atributo `BloqueoRapidoActive` o `RunnerAbilityService.isBlocking(targetPlayer)`:
    - Se invoca `RunnerAbilityService.handleBlockedAttack(targetPlayer, hunterPlayer)`.
    - Se anula el congelamiento retornando `false`.
    - Se aturde al cazador atacante por 0.4 s.
    - Se emiten los eventos de feedback visual y auditivo de parry a todos los clientes.

### D. Controlador de Entrada y Predicción en Cliente (`RunnerAbilityController`)
- Captura la pulsación de la tecla `[F]` en teclado y el botón `[ButtonX]` en mandos de consola cuando el rol local es `Runner`.
- Aplica predicción local para evitar spam hacia el servidor mientras la habilidad se encuentra en tiempo de recarga.
- Provee interfaz pública (`request`, `selectAbility`, `isReady`, `getCooldownLeft`) para integrarse sin fricción con botones táctiles de móviles o menús de selección.

### E. Sistema Modular de VFX Replicados (`src/shared/VFX/Runner/`)
- Módulos independientes desacoplados para cada habilidad:
  - Generación procedural sin dependencias de IDs externos de mallas que pudieran faltar.
  - Uso de esferas ForceField con pulsación de opacidad, aros cilíndricos horizontales de choque, conos cinéticos y Beams eléctricos.
  - Supresión inteligente de `RoleHighlight` y etiquetas de cabeza durante el humo y camuflaje.
  - Despachador unificado `RunnerVFX.luau` compatible con resoluciones tanto en `ReplicatedStorage.VFX` como en `ReplicatedStorage.Shared.VFX`.

### F. Sincronización y Validación en Roblox Studio
- Todos los scripts creados y modificados se inyectaron directamente en el DataModel activo de Roblox Studio mediante herramientas MCP (`execute_luau`).
- Se verificó la carga de todos los módulos sin errores de compilación (`err: nil`, `10` habilidades registradas en el catálogo y servicios instanciados correctamente).

---

## 4. Verificación de Salvaguardas y Archivos Prohibidos

Durante la ejecución del Agente #1 se respetaron rigurosamente las fronteras de trabajo de los demás agentes:
- **NO** se modificó `src/server/Server/Services/DashService.luau`
- **NO** se modificó `src/server/Server/Services/DebugCommandService.luau`
- **NO** se modificó `src/server/Server/Services/RoundService.luau`
- **NO** se modificó `src/server/ZeroPruebas.luau` ni `src/client/StarterPlayerScripts/ZeroPruebasClient.client.luau`
- **NO** se modificó `src/shared/ZeroUI.luau` ni `src/client/StarterPlayerScripts/ZeroUIClient.client.luau`
- **NO** se modificó `src/client/StarterPlayerScripts/Client/Controllers/CooldownHUD.luau`
