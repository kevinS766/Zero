# Módulo: Ataúd Gótico de Congelamiento y Rescate — Evento de Halloween 2026 (Zero)

> **Rol del Agente**: Diseñador de Mecánicas Visuales de Estado, Física Procedural y Feedback de Juego.
> **Dominio de Trabajo**: `ServerScriptService.Server.HalloweenCoffinService` y `StarterPlayerScripts.Client.HalloweenCoffinClient`.
> **Desacoplamiento**: Reemplaza visualmente el bloque de hielo cuando un jugador pasa a `Status == "Frozen"`. Conecta con los eventos existentes de `PlayerStateService` sin romper la lógica de congelamiento/descongelamiento de la ronda.

---

## 1. Alcance y Objetivos
Sustituir la estética del bloque de hielo tradicional por un **Ataúd Gótico de Madera**:
1. Encapsulamiento del Runner congelado dentro del modelo del ataúd.
2. Azote de la tapa de madera con cerrojo sonoro en el momento del impacto.
3. Feedback físico de temblor progresivo (`Shake`) y crujido mientras un compañero rescata ("Mantén E").
4. Estallido de la tapa y dispersión de murciélagos (`BatParticles`) al liberarse.

---

## 2. Especificación Técnica de Mecánicas

### 2.1 Aparición del Ataúd y Encierro
- **Trigger**: Escuchar el cambio del atributo `Status` a `"Frozen"` en cualquier jugador durante una ronda activa.
- **Instanciación**:
  - Clonar el modelo `GothicCoffin` desde `ReplicatedStorage.HalloweenAssets` a `Workspace.ZeroRuntime`.
  - Posicionar el ataúd exactamente en la orientación y posición (`CFrame`) del `HumanoidRootPart` del corredor congelado.
  - Asegurar que el Runner quede anclado dentro (`Anchored = true`) en la pose designada de reposo.
- **Azote de Tapa**:
  - La tapa del ataúd se cierra abruptamente en 0.25 segundos.
  - Reproducir SFX de portazo de madera pesada y cerrojo metálico gótico.

### 2.2 Proceso de Rescate y Temblor Físico (Shake)
- **Interacción con ProximityPrompt**:
  - Reemplazar visualmente el prompt de rescate estándar o superponerlo con la etiqueta *"Rescatar del Ataúd (Mantén E)"* (tiempo de canalización: 2.0s a 2.5s).
- **Temblor Progresivo (Procedural Shake)**:
  - Cuando un Runner activo interactúa con el `PromptButtonHoldBegan`:
    - Iniciar vibración procedural en el ataúd mediante un `RenderStepped` local en el cliente.
    - La amplitud del temblor aumenta proporcionalmente al porcentaje de la barra de progreso (de 0 a 1).
    - Reproducir crujidos de madera tensionada que alertan acústicamente a los jugadores cercanos sin necesidad de mirar la UI.
  - Si el rescate se interrumpe (`PromptButtonHoldEnded`), el temblor cesa inmediatamente.

### 2.3 Liberación y Estallido de Murciélagos
- **Trigger**: `RescueFeedback` exitoso o cambio de estado a `"Active"`.
- **Destrucción y Efecto**:
  - La tapa del ataúd o el modelo completo estalla hacia arriba o se disuelve instantáneamente.
  - Emisión de un burst de partículas de murciélagos negros (`BatParticles`) volando en espiral hacia el cielo durante 1.2 segundos.
  - Sonido de madera astillándose y chillido suave de murciélagos.
  - Limpieza formal de las instancias del ataúd en `Workspace.ZeroRuntime`.

---

## 3. Arquitectura y Ubicación en DataModel

```text
ReplicatedStorage/
  |-- HalloweenAssets/
  |     |-- GothicCoffinModel             <-- [MODELO DEL ATAÚD]
  |     `-- BatParticleEmitter            <-- [SISTEMA DE PARTÍCULAS DE MURCIÉLAGOS]
  `-- Shared/
        `-- CoffinConfig.luau             <-- [TIEMPOS DE AZOTE, CONFIGURACIÓN DE SHAKE Y SFX]

ServerScriptService/
  `-- Server/
        `-- HalloweenCoffinService.luau   <-- [SPAWN AUTORITATIVO Y LIMPIEZA DEL ATAÚD]

StarterPlayerScripts/
  `-- Client/
        `-- HalloweenCoffinClient.luau    <-- [SHAKE PROCEDURAL DURANTE PROMPT Y AUDIO LOCAL]
```

---

## 4. Interfaces y Contratos de Red

### En `ReplicatedStorage.Shared.NetworkEvents`:
- `RemoteEvent`: `CoffinSpawned` (Servidor -> Todos los Clientes: Ubicación y sincronización del ataúd).
- `RemoteEvent`: `CoffinRescueProgress` (Cliente -> Servidor / Servidor -> Clientes: Porcentaje de canalización para modular el temblor).
- `RemoteEvent`: `CoffinBurst` (Servidor -> Todos los Clientes: Liberación con estallido de murciélagos).

---

## 5. Check-list de Validación
- [ ] El ataúd se posiciona adecuadamente sin empujar al jugador fuera del suelo.
- [ ] El temblor procedural escala limpiamente con la barra de progreso de rescate.
- [ ] Estallido de partículas y limpieza garantizada de modelos en `Workspace.ZeroRuntime` al terminar la ronda o desconectarse el jugador.
- [ ] No rompe la verificación de victoria de congelados de `RoundService`.
