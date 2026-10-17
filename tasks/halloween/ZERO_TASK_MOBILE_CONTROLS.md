# Módulo: Controles Móviles y Auto-Attack — Evento de Halloween 2026 (Zero)

> **Rol del Agente**: Especialista en Optimización Móvil, Ergonomía de Entrada (Touch) y Accesibilidad.
> **Dominio de Trabajo**: `StarterPlayerScripts.Client.MobileControlsController` e integración con `UserInputService.TouchEnabled`.
> **Desacoplamiento**: Lógica 100% de cliente para dispositivos táctiles. No interfiere con servidores de combate ni sobrescribe inputs de teclado/ratón en PC.

---

## 1. Alcance y Objetivos
1. Diseñar y calibrar la **disposición táctil ergonómica para móviles**:
   - Botones de acción táctiles para Dash, Habilidades de Cazador/Runner y Rescate con hitboxes aumentadas.
2. Implementar la asistencia opcional de **Auto-Attack para Cazadores Móviles**:
   - Detección de proximidad y orientación hacia Runners activos para facilitar el remate táctil sin sacrificar el control de la cámara.
   - Interruptor (Toggle) de encendido/apagado en el menú de ajustes o HUD.

---

## 2. Especificación Técnica de Mecánicas

### 2.1 Botones de Acción Táctiles (Touch Action Cluster)
- **Detección de Dispositivo**:
  - Verificar `UserInputService.TouchEnabled` en el cliente. Si es verdadero, desplegar el cluster táctil móvil.
- **Distribución Ergonómica**:
  - Ubicado en la esquina inferior derecha en abanico natural del pulgar:
    - **Botón Primario**: Ataque / Cuchillo (o Habilidad principal de Hunter).
    - **Botón Secundario**: Habilidad especial (Q / F).
    - **Botón de Movilidad**: Dash.
    - **Botón Contextual**: Rescate (aparece automáticamente cuando el Runner está cerca de un ataúd/congelado).
- **Hitboxes Táctiles**:
  - Padding invisible extendido de 12px alrededor de cada botón para evitar pulsaciones fallidas.

### 2.2 Sistema de Asistencia "Auto-Attack" (Móvil)
- **Objetivo**: Ayudar a los jugadores de móvil a conectar golpes de cuchillo sin perder el seguimiento visual del objetivo con el pulgar derecho.
- **Funcionamiento**:
  - Exclusivo cuando el jugador tiene el rol `Hunter` en `ROUND_ACTIVE` y tiene activada la opción `AutoAttackEnabled == true`.
  - En cada frame (`RenderStepped`):
    - Realizar un escaneo de esfera/cono frontal (rango: 5.5 studs, ángulo: 90° frente al personaje).
    - Si un Runner activo no congelado entra en el cono de ataque y el cooldown de combate está listo:
      - Ejecutar automáticamente la llamada a `AttackRequest` hacia el servidor.
      - Reproducir feedback táctil suave (si el dispositivo soporta vibración con `HapticService`).
- **Control del Usuario**:
  - Opción visible en HUD o menú de configuración: `[ AUTO-ATAQUE MÓVIL: ON / OFF ]` con guardado local en `UserGameSettings` o atributo de sesión.

---

## 3. Arquitectura y Ubicación en DataModel

```text
StarterPlayerScripts/
  `-- Client/
        `-- MobileControlsController.luau  <-- [MANEJADOR TOUCH, AUTO-ATTACK Y CLUSTER MÓVIL]

ReplicatedStorage/
  `-- Shared/
        `-- MobileControlsConfig.luau      <-- [TAMAÑOS, RADIOS DE DETECCIÓN Y POSICIONES TOUCH]
```

---

## 4. Interfaces y Contratos de Red
- Utiliza los eventos existentes de `CombatService` (`AttackRequest`) y `DashController` sin requerir nuevos remotes de servidor.

---

## 5. Check-list de Validación
- [ ] No se activa en clientes de PC/Consola (`TouchEnabled == false`).
- [ ] Auto-Attack respeta el cooldown estricto del servidor (1.2s) sin provocar spam o desincronización.
- [ ] Toggle de activación/desactivación funcional en la interfaz.
- [ ] Botones táctiles responsivos con retroalimentación visual al presionar.
