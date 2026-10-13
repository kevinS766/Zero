# Zero (Por debajo de cero)

Zero es un juego multijugador rápido y competitivo en Roblox con temática de supervivencia y congelamiento (Hunter vs Runner / Freeze Tag).

---

## Modos y Roles

* **Corredores (Runners)**: Deben huir del cazador, utilizar la habilidad de desplazamiento (*Dash*), salvar a sus compañeros congelados con interacción por proximidad y sobrevivir hasta que se agote el tiempo.
* **Cazador (Hunter)**: Debe congelar a todos los corredores antes de que se agote el tiempo utilizando su cuchillo, agilidad y habilidades únicas de clase.
  * **Rastreador (Tracker)**: Revela las siluetas de los corredores cercanos a través de obstáculos.
  * **Acechador (Stalker)**: Invisibilidad temporal y aumento de velocidad de desplazamiento.
  * **Trampero (Trapper)**: Coloca trampas en el suelo que congelan a los corredores que las pisen.

---

## Arquitectura del Proyecto

El código está completamente estructurado y modularizado:

```text
Zero/
├── src/
│   ├── server/           # Servicios autoritativos del servidor (ServerScriptService)
│   │   ├── Services/     # CombatService, RoundService, DashService, BotService, MapService, DataService, etc.
│   │   └── ...           # Manejo de economía, ruleta, armas y sprint
│   ├── client/           # Controladores de cliente (StarterPlayerScripts)
│   │   ├── Controllers/  # CooldownHUD, DashController, RoleHUD, MusicController, ShopController, etc.
│   │   └── ...           # Controladores visuales, animaciones, VFX, cámara y sonido
│   ├── shared/           # Configuraciones y constantes compartidas (ReplicatedStorage)
│   │   ├── Config/       # CombatConfig, DashConfig, HunterClassConfig, MapConfig, RoundConfig, etc.
│   │   ├── Constants/    # HunterClasses, PlayerRoles, PlayerStatus, RoundStates
│   │   └── Network/      # Definiciones de eventos remotos (NetworkEvents)
│   ├── startergui/       # Scripts y lógica de interfaces (StarterGui)
│   └── replicatedfirst/  # Pantallas de carga inicial (ReplicatedFirst)
├── assets/
│   └── maps/             # Previews y miniaturas de mapas
├── docs/                 # Documentación técnica, bitácoras y registros
│   └── archive/          # Reportes y documentos históricos (ignorado en Git)
├── tools/                # Scripts de automatización y exportación
│   └── sync_server.py    # Servidor local de sincronización desde Roblox Studio
├── AGENTS.md             # Guía operativa y tracker de fases del proyecto
├── TODO_LIST_ZERO.md     # Tracker de tareas, bugs y mejoras visuales
└── VFX_CATALOG.md        # Catálogo de efectos visuales (VFX)
```

---

## Sincronización desde Roblox Studio a Git

Para mantener el repositorio de GitHub actualizado con los cambios que se hagan en Studio:

1. Inicia el servidor de sincronización en tu terminal:
   ```bash
   python tools/sync_server.py
   ```
2. Ejecuta en la **Command Bar** de Roblox Studio (o mediante la herramienta de automatización):
   ```luau
   -- Exporta automáticamente todos los scripts al disco local
   local HttpService = game:GetService("HttpService")
   local services = {
       { name = "ServerScriptService", svc = game:GetService("ServerScriptService") },
       { name = "ReplicatedStorage", svc = game:GetService("ReplicatedStorage") },
       { name = "StarterPlayer", svc = game:GetService("StarterPlayer") },
       { name = "StarterGui", svc = game:GetService("StarterGui") },
       { name = "ReplicatedFirst", svc = game:GetService("ReplicatedFirst") },
       { name = "ServerStorage", svc = game:GetService("ServerStorage") },
   }
   for _, s in ipairs(services) do
       local scripts = {}
       for _, desc in ipairs(s.svc:GetDescendants()) do
           if desc:IsA("LuaSourceContainer") then
               local parts = {}
               local cur = desc
               while cur and cur ~= s.svc do
                   table.insert(parts, 1, cur.Name)
                   cur = cur.Parent
               end
               table.insert(scripts, {
                   service = s.name,
                   path = table.concat(parts, "/"),
                   class = desc.ClassName,
                   source = desc.Source
               })
           end
       end
       if #scripts > 0 then
           HttpService:PostAsync("http://127.0.0.1:34567", HttpService:JSONEncode({ scripts = scripts }), Enum.HttpContentType.ApplicationJson)
       end
   end
   print("¡Todos los scripts exportados exitosamente!")
   ```
3. Haz `git commit` y `git push` a tu repositorio:
   ```bash
   git add .
   git commit -m "feat: actualizar scripts desde Studio"
   git push origin main
   ```

---

## Equipo y Créditos

* **Polaris**: Lógica de servidor, arquitectura técnica, networking, máquinas de estado y servicios modulares.
* **KaiBit23**: Construcción de mapas, iluminación, props 3D, animaciones de personajes, VFX, audio y diseño visual de interfaz.
