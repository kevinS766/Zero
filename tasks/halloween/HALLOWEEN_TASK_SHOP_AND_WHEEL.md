# Módulo: Tienda de Evento, Caja y Ruleta de Halloween — Evento de Halloween 2026 (Zero)

> **Rol del Agente**: Desarrollador de UI/UX, Sistemas de Recompensas y Microtransacciones de Evento.
> **Dominio de Trabajo**: `ServerScriptService.Server.HalloweenStoreService`, `ReplicatedStorage.HalloweenStoreConfig` y `StarterPlayerScripts.Client.HalloweenStoreController`.
> **Desacoplamiento**: Maneja de forma aislada las transacciones de cajas y ruleta temática. Utiliza la moneda `Pumpkins` y no altera los Gamepasses principales ni la ruleta base de `ZeroWheelServer`.

---

## 1. Alcance y Objetivos
1. Diseñar y programar la **Caja de Halloween (Única)**:
   - Exclusiva para cosméticos de evento (varitas, efectos de golpe, estelas y skins temáticas).
   - Sin títulos genéricos de relleno.
   - **Sistema de Retorno por Duplicados**: Si el jugador ya posee el cosmético obtenido, se le reembolsa un porcentaje garantizado (40% - 50%) de Calabazas.
2. Implementar la **Ruleta de Halloween**:
   - Ruleta temática independiente ubicada en el Lobby o accesible desde el HUD del evento.
   - Giros diarios gratuitos por inicio de sesión (1 giro gratis cada 24h).
   - Opción de comprar giros adicionales utilizando la moneda del evento (`Pumpkins`).
3. **Regla de Clases**: Las clases del juego se mantienen exclusivas por compra directa con Gemas; **nunca** se colocan en cajas de azar.

---

## 2. Especificación Técnica de Mecánicas

### 2.1 Caja de Halloween (Única)
- **Costo de Apertura**: Valor calibrado en `Pumpkins` (p. ej. 150 Calabazas por caja) o Gemas de evento.
- **Tabla de Botín (Loot Table)**:
  - Varitas Cosméticas: *Varita Hueso Espectral*, *Báculo de Calabaza Flotante*, *Guadaña de la Luna Roja*.
  - Efectos de Remate / Congelamiento: *Estallido de Murciélagos*, *Llama Carmesí*.
- **Mecanismo Anti-Duplicados**:
  - Al procesar la apertura en el servidor (`HalloweenStoreService`):
    - Consultar el inventario del usuario en `DataService`.
    - Si el ID de item sorteado ya está desbloqueado: otorgar el reembolso de `Pumpkins` y enviar notificación: *"¡Objeto repetido! Has recibido +X Calabazas de compensación"*.

### 2.2 Ruleta de Halloween (Halloween Fortune Wheel)
- **Pool de Premios**:
  - Cantidades de Calabazas (+25, +50, +100, +250).
  - Paquetes de Gemas menores.
  - Cosmético épico de evento con baja probabilidad.
  - 1 Multiplicador de evento temporal (x1.5 Calabazas por 3 rondas).
- **Lógica de Giros**:
  - `DailyFreeSpin`: Comprobar `os.time() >= NextHalloweenFreeSpinAt`. Si aplica, costo = 0.
  - Giros adicionales: Consumen `X` Calabazas por giro.
  - Verificación estricta de saldo en servidor antes de disparar la animación de giro.

---

## 3. Arquitectura y Ubicación en DataModel

```text
ServerScriptService/
  `-- Server/
        `-- HalloweenStoreService.luau      <-- [LÓGICA AUTORITATIVA DE CAJAS Y RULETA]

ReplicatedStorage/
  `-- Shared/
        `-- HalloweenStoreConfig.luau       <-- [TABLAS DE PROBABILIDAD, PREMIOS Y COSTOS]

StarterPlayerScripts/
  `-- Client/
        `-- HalloweenStoreController.luau   <-- [INTERFAZ VISUAL, ANIMACIÓN DE RULETA Y APERTURA DE CAJA]
```

---

## 4. Interfaces y Contratos de Red

### En `ReplicatedStorage.Shared.NetworkEvents`:
- `RemoteFunction`: `OpenHalloweenCrate` (Cliente -> Servidor: Solicita abrir caja; devuelve item obtenido o compensación).
- `RemoteFunction`: `SpinHalloweenWheel` (Cliente -> Servidor: Solicita giro de ruleta; devuelve el índice del premio).
- `RemoteEvent`: `HalloweenInventoryUpdated` (Servidor -> Cliente: Notificación de nuevos cosméticos adquiridos).

---

## 5. Check-list de Validación
- [ ] Retorno porcentual por duplicados implementado y validado en servidor.
- [ ] Giro gratuito diario con timestamp persistente en `DataService`.
- [ ] Validación estricta de saldo de `Pumpkins` para evitar gastos negativos o duplicación de giros.
- [ ] Clases de Cazador excluidas de la ruleta y cajas (solo cosméticos).
