# Documento de Diseño: Evento de Halloween 2026 (Zero)

Documento oficial de planificación y especificación técnica de mecánicas, economía y habilidades para la actualización de Halloween.

---

## 1. Economía y Recompensas
- **Moneda Única de Evento**: `Calabazas` (Pumpkins).
  - Se obtienen recolectándolas físicamente por el mapa durante la ronda.
  - No se añaden monedas secundarias para evitar sobrecarga en la economía (ya existen Monedas y Gemas).
- **Spawn de Calabazas en Mapa**:
  - Sistema de pool dinámico continuo (8 a 12 calabazas activas en todo momento).
  - Respawn automático tras ser recogida una unidad.
  - Efecto de aparición: Escala elástica (pop), outline negro estilo cartoon, destello (glint) diagonal periódico y partículas doradas sutiles.
  - Rango de recompensa por recogida: 4 a 15 Calabazas (RNG).
  - Sin marcado visual del jugador al recoger (prioridad a la fluidez).
  - El Cazador no obtiene calabazas al congelar (evita efecto bola de nieve).
- **Evento Dinámico de Mapa: "Luna Roja" (Blood Moon)**:
  - Activación por probabilidad o en el clímax de la ronda.
  - Transición atmosférica en Skybox a rojo carmesí con niebla naranja.
  - Pista musical temática tensa.
  - Multiplicador de spawn y valor de calabazas (x2).

---

## 2. Tienda, Cajas y Ruleta
- **Caja de Halloween (Única)**:
  - Solo contiene varitas cosméticas, efectos visuales y skins exclusivas.
  - Sin títulos genéricos de relleno.
  - Sistema de retorno por duplicados: reembolso porcentual de moneda al salir un objeto repetido.
- **Ruleta de Halloween**:
  - Ruleta independiente a la ruleta estándar del lobby.
  - Giros diarios gratuitos por inicio de sesión.
  - Posibilidad de comprar giros adicionales utilizando Calabazas del evento.
- **Clases del Juego**:
  - Se mantienen exclusivas por compra directa con Gemas (nunca en cajas de azar).

---

## 3. Game Feel y Efectos Visuales
- **Ataúd de Halloween (Sustitución de Bloque de Hielo)**:
  - Al ser congelado, el Runner queda encerrado en un ataúd gótico de madera.
  - Animación de entrada: Azote violento de tapa con sonido de cerrojo.
  - Feedback de rescate ("Mantén E"): Temblor físico progresivo (shake) del ataúd y crujido de madera que delata visualmente el progreso sin mirar la interfaz.
  - Animación de salida: Estallido de tapa y dispersión de murciélagos al completar el rescate.

---

## 4. Habilidades del Cazador (Halloween)

### Habilidad 1: "Lanza de Gransax" (Ataque a Distancia / Rayo Espectral)
- **Inspiración**: *Bolt of Gransax* (Elden Ring).
- **Mecánica**:
  - El Cazador se eleva en el aire en suspensión durante un breve instante.
  - Materializa una lanza roja/espectral de gran tamaño cargada de energía.
  - Arroja la lanza a gran velocidad hacia el punto objetivo.
  - Impacto directo o de área pequeña que inflige daño/congelamiento o desestabilización al objetivo.

### Habilidad 2: "Alas Negras" (Embestida Cargada / Stun)
- **Mecánica**:
  - **Fase de Carga (Wind-up)**: Al mantener la tecla, el Cazador despliega dos alas oscuras y entra en postura de carga reduciendo ligeramente su velocidad.
  - **Fase de Impulso**: Al liberar la tecla (o completarse la carga), realiza una embestida frontal explosiva a alta velocidad propulsada por las alas.
  - **Fase de Impacto**: Si impacta contra un Runner en su trayectoria, le aplica aturdimiento (`Stun`) de 1.2s a 1.5s, dejándolo inmovilizado y expuesto al remate.
  - **Counterplay**: El sonido de viento y la postura telegrafiada permiten al Runner esquivar lateralmente con Dash si reacciona a tiempo.

---

## 5. Habilidades de Corredor (Halloween)

### Habilidad 1: "Lápida de Retorno" (Ancla Temporal / Recall)
- **Mecánica**:
  - Al activar, el Runner coloca una lápida espectral luminosa en su posición actual.
  - Se activa una ventana de 4 segundos donde el Runner puede desplazarse libremente.
  - Al presionar nuevamente la tecla (o al terminar los 4 segundos), se teletransporta de regreso a la posición de la lápida.
- **Balance Estricto**:
  - **Limitada a exactamente 2 usos por ronda** (evita abusos y spam).
  - El Cazador puede ver la lápida en el suelo y predecir el retorno si lee la jugada.

### Habilidad 2: "Parpadeo Sombrío" (Blink / Teletransporte Instantáneo)
- **Mecánica**:
  - Teletransporte cuántico instantáneo en línea recta de 12 a 14 studs en la dirección de la cámara.
  - A diferencia del Dash físico (que tiene aceleración y choca con objetos), el Parpadeo atraviesa rejas delgadas, huecos de barandillas y modelos de jugadores.
  - No tiene tiempo de viaje (frame 0 de punto A a punto B).
- **Balance Estricto**:
  - Cooldown elevado (~20 segundos) para que sea un recurso de escape crítico y no sustituya al Dash base.

---

## 6. Mejoras Generales de Sistema
- Configuración de controles personalizados para dispositivos móviles.
- Asistencia / opción de Auto-Attack para Cazadores en plataformas móviles.
