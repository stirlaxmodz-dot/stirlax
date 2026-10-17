--[[
================================================================================
    S T I R L A X  M O D Z  —  Universal
    Menu unificado para Roblox (PC / Movil)
    v2.0.0

    Uso: pegar en el executor y ejecutar.
    Apertura del menu: tecla RightShift (PC) o boton flotante (movil).

    Todo lo que cambia entre juegos (nombres de partes, remotos, velocidades)
    esta junto, comentado, arriba de cada modulo: se toca ahi y nada mas.
================================================================================
]]

local StirlaxModz = {}
StirlaxModz.Version = "2.1.0"
StirlaxModz.Brand = "STIRLAX MODZ"

--------------------------------------------------------------------------------
-- 1. SERVICIOS
--------------------------------------------------------------------------------
local S = {}
local function svc(name)
    local ok, s = pcall(function() return game:GetService(name) end)
    if ok then return s end
    return nil
end

S.Players     = svc("Players")
S.RunService  = svc("RunService")
S.UIS         = svc("UserInputService")
S.Tween       = svc("TweenService")
S.Lighting    = svc("Lighting")
S.StarterGui  = svc("StarterGui")
S.Http        = svc("HttpService")
S.VirtualUser = svc("VirtualUser")
S.TextService = svc("TextService")
S.Stats       = svc("Stats")
S.CoreGui     = svc("CoreGui")
S.GuiService  = svc("GuiService")
S.Collection  = svc("CollectionService")
S.ContextAction = svc("ContextActionService")
S.TeleportService = svc("TeleportService")
S.Workspace   = game:FindFirstChildOfClass("Workspace") or game:FindFirstChild("Workspace") or workspace

--------------------------------------------------------------------------------
-- 2. CORE
--------------------------------------------------------------------------------
local Core = {}
Core.Flags = {}
Core.Version = StirlaxModz.Version
Core.Brand = StirlaxModz.Brand

function Core.log(...)
    print("[STIRLAX MODZ] " .. table.concat({ ... }, " "))
end

function Core.Hex(hex)
    local ok, c = pcall(function()
        hex = tostring(hex):gsub("#", "")
        return Color3.fromRGB(tonumber(hex:sub(1, 2), 16) or 0, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0)
    end)
    if ok then return c end
    return Color3.fromRGB(255, 255, 255)
end

function Core.Connect(signal, fn)
    if not signal then return nil end
    local ok, conn = pcall(function() return signal:Connect(fn) end)
    if ok then return conn end
    return nil
end

-- Estado de utilidades que el resto del script lee todo el tiempo.
function Core.Alive()
    local lp = S.Players and S.Players.LocalPlayer
    if not lp then return false end
    local char = lp.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

function Core.Character()
    local lp = S.Players and S.Players.LocalPlayer
    return lp and lp.Character or nil
end

function Core.Humanoid()
    local char = Core.Character()
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

function Core.Root()
    local char = Core.Character()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildOfClass("BasePart")
end

function Core.Head()
    local char = Core.Character()
    if not char then return nil end
    return char:FindFirstChild("Head")
end

function Core.Camera()
    local cam = S.Workspace
    if not cam then return nil end
    return cam.CurrentCamera or (workspace and workspace.CurrentCamera)
end

function Core.Viewport()
    local cam = Core.Camera()
    if cam and cam.ViewportSize then return cam.ViewportSize end
    return Vector2.new(1280, 720)
end

-- Devuelve datos utiles de cualquier jugador (o del jugador local).
function Core.GetPlayer(plr)
    if not plr then return nil end
    local char = plr.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildOfClass("BasePart")
    local head = char:FindFirstChild("Head")
    if not hum or not root then return nil end
    return { Player = plr, Character = char, Humanoid = hum, Root = root, Head = head }
end

function Core.IsAlive(plr)
    local d = Core.GetPlayer(plr)
    return d ~= nil and d.Humanoid.Health > 0
end

function Core.Distance(plr)
    local d = Core.GetPlayer(plr)
    local root = Core.Root()
    if not d or not root then return math.huge end
    return (d.Root.Position - root.Position).Magnitude
end

-- Un enemigo es alguien distinto de mi, vivo y (si corresponde) de otro equipo.
function Core.Friendly(plr)
    local lp = S.Players and S.Players.LocalPlayer
    if plr == lp then return true end
    if Core.Flags["aimbot_teamcheck"] or Core.Flags["esp_teamcheck"] then
        local a = lp and lp.Team
        local b = plr.Team
        if a and b and a == b then return true end
    end
    return false
end

-- Parte a la que apunta el aimbot: Head por defecto (auto-cabeza).
function Core.TargetPart(plr)
    local d = Core.GetPlayer(plr)
    if not d then return nil end
    local modo = Core.Flags["aimbot_part"] or "Head"
    if modo == "Head" and d.Head then return d.Head end
    if modo == "Torso" then return d.Character:FindFirstChild("UpperTorso") or d.Root end
    if modo == "Nearest" then
        local cam = Core.Camera()
        if not cam then return d.Head or d.Root end
        local best, bestD = d.Root, math.huge
        for _, p in ipairs(d.Character:GetChildren()) do
            if p:IsA("BasePart") then
                local depth = (p.Position - cam.CFrame.Position).Magnitude
                if depth < bestD then best, bestD = p, depth end
            end
        end
        return best
    end
    return d.Head or d.Root
end

-- Comprueba que no haya pared entre dos puntos (el "visible" del aimbot).
function Core.WallCheck(from, to)
    local ws = S.Workspace
    if not ws then return true end
    local params = RaycastParams and RaycastParams.new() or nil
    if params then
        pcall(function()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local lp = S.Players and S.Players.LocalPlayer
            local char = lp and lp.Character
            if char then params.FilterDescendantsInstances = { char } end
        end)
    end
    local ok, res = pcall(function()
        return ws:Raycast(from, (to - from), params)
    end)
    if not ok then return true end
    if not res then return true end
    -- Si lo primero que toca es una parte de un personaje, no hay pared.
    local hit = res.Instance
    if hit and hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid") then return true end
    return (to - res.Position).Magnitude < 2
end

-- Visibilidad real con la camara del juego: usa GetPartsObscuringTarget, que respeta
-- la geometria exacta de la vista (mejor que una linea recta en mapas con desniveles).
function Core.VisibleToCamera(worldPos, ignore)
    local cam = Core.Camera()
    if not cam then return true end
    local ok, list = pcall(function()
        return cam:GetPartsObscuringTarget({ worldPos }, ignore or {})
    end)
    if ok and type(list) == "table" then
        return #list == 0
    end
    return Core.WallCheck(cam.CFrame.Position, worldPos)
end

-- Proyecta un punto del mundo a la pantalla. Devuelve Vector2, onscreen.
function Core.ScreenPoint(pos)
    local cam = Core.Camera()
    if not cam then return Vector2.new(0, 0), false end
    local ok, sp, on = pcall(function()
        local v, o = cam:WorldToViewportPoint(pos)
        return Vector2.new(v.X, v.Y), o
    end)
    if ok and typeof(sp) == "Vector2" then return sp, on end
    -- Plan B: calculo propio con la camara.
    local vs = Core.Viewport()
    local origin = cam.CFrame.Position
    local rel = pos - origin
    local depth = rel:Dot(cam.CFrame.LookVector)
    if depth <= 0 then return Vector2.new(0, 0), false end
    local scale = (vs.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
    local right = cam.CFrame.RightVector
    local up = cam.CFrame.UpVector
    return Vector2.new(vs.X / 2 + rel:Dot(right) / depth * scale, vs.Y / 2 - rel:Dot(up) / depth * scale), true
end

-- Enemigos ordenados por cercania al centro de la mira (FOV).
function Core.GetTargets(requireVisible)
    local out = {}
    for _, plr in ipairs(S.Players:GetPlayers()) do
        if not Core.Friendly(plr) and Core.IsAlive(plr) then
            if not requireVisible or Core.WallCheck(
                Core.Camera().CFrame.Position, Core.TargetPart(plr).Position) then
                out[#out + 1] = plr
            end
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- 3. PROTECCION  (anti-expulsion, sigilo y el escaner del juego)
--
-- Reglas de oro de esta seccion:
--   * Nunca instalar un hook sin poder reconstruir el original.
--   * Verificar en el acto que el namecall siga sano; si no, restaurar solo.
--   * El kick del servidor no se puede frenar desde el cliente; el del cliente si.
--------------------------------------------------------------------------------
local Protection = {}
Core.Protection = Protection

Protection.Installed = false
Protection.Hooked = {}
Protection.KickGuardOk = false
Protection.KickAttempts = 0
Protection.TeleportAttempts = 0
Protection.Flinges = 0
Protection.StatusLabel = nil
Protection.ScanLabel = nil

-- Ajustes de seguridad: se tocan aca y en ningun otro lado.
local SEG = {
    FLING_MAX = 300,    -- velocidad horizontal que dispara el anti-fling
    STEALTH_CAP = 35,   -- cap de velocidad de caminata en modo sigiloso
}
Core.SEG = SEG

-- Nombre camuflado del GUI: los escaneres de los juegos buscan nombres
-- conocidos; con hide_gui (~= false) el menu usa un hex random.
Core._cloak = nil
function Core.CloakName()
    if Core.Flags["hide_gui"] == false then return "ModzInterface" end
    if not Core._cloak then
        Core._cloak = string.format("%x%x%x",
            math.random(1048576, 16777215), math.random(1048576, 16777215), os.time() % 16777216)
    end
    return Core._cloak
end

local function refrescarEstado()
    if Protection.StatusLabel then
        pcall(function()
            Protection.StatusLabel.Text = string.format("Kicks bloqueados: %d    Teleports: %d    Flinges: %d",
                Protection.KickAttempts, Protection.TeleportAttempts, Protection.Flinges)
        end)
    end
end
Protection.RefrescarEstado = refrescarEstado

-- Roblox marca idle a los 20 min; esto lo mantiene despierto sin moverse.
local function idleKick()
    local lp = S.Players and S.Players.LocalPlayer
    if not lp then return end
    pcall(function()
        if lp.Idled then end
    end)
    task.spawn(function()
        while task.wait(60) do
            pcall(function()
                if S.VirtualUser then S.VirtualUser:CaptureController() end
            end)
        end
    end)
end

-- Idle jump: evita que el juego te cuente como inactivo por no saltar.
local function idleJump()
    local uis = S.UIS
    if not uis then return end
    Core.Connect(uis.InputBegan, function() end)
end

-- Verifica que el namecall siga sano; si el hook rompe algo, esto lo delata.
function Protection.VerifyNamecall()
    local ok, res = pcall(function() return S.Players:GetChildren() end)
    return ok and type(res) == "table"
end

-- Anti-expulsion: hook del namecall que bloquea los Kick lanzados desde el
-- cliente (los juegos con deteccion propia hacen LocalPlayer:Kick()) y, si se
-- pide, los teleports forzados del juego. Con autoreparacion: si el executor no
-- soporta bien el hook, se restaura la metatabla al instante y no se rompe nada.
local function installKickGuard()
    if Protection.KickGuardOk then return true end
    local lp = S.Players and S.Players.LocalPlayer
    if not lp then return false end
    local ok = pcall(function()
        if type(getrawmetatable) ~= "function" then return end
        local mt = getrawmetatable(game)
        if not mt then return end
        local old
        pcall(function() old = rawget(mt, "__namecall") end)
        if type(old) ~= "function" then return end -- sin original reconstruible no se toca nada
        local hook = function(self, ...)
            local method = ""
            pcall(function()
                if type(getnamecallmethod) == "function" then method = getnamecallmethod() or "" end
            end)
            if method == "Kick" and self == lp
                and Core.Flags["bypass_enabled"] ~= false and Core.Flags["anti_kick"] ~= false then
                Protection.KickAttempts = Protection.KickAttempts + 1
                refrescarEstado()
                Core.Notify("Intento de expulsion bloqueado (" .. Protection.KickAttempts .. ")", "Anti-Expulsion")
                return nil
            end
            if Core.Flags["bypass_enabled"] ~= false and Core.Flags["teleport_guard"] == true
                and S.TeleportService and self == S.TeleportService
                and (method == "Teleport" or method == "TeleportAsync"
                    or method == "TeleportToPlaceInstance" or method == "TeleportToPrivateServer") then
                Protection.TeleportAttempts = Protection.TeleportAttempts + 1
                refrescarEstado()
                Core.Notify("Teleport del juego bloqueado (" .. Protection.TeleportAttempts .. ")", "Anti-Expulsion")
                return nil
            end
            return old(self, ...)
        end
        if type(newcclosure) == "function" then
            local okc, env = pcall(newcclosure, hook)
            if okc and type(env) == "function" then hook = env end
        end
        if type(setreadonly) == "function" then pcall(setreadonly, mt, false) end
        local backup
        pcall(function() backup = rawget(mt, "__namecall") end)
        mt.__namecall = hook
        Protection.NamecallMeta = mt
        Protection.NamecallBackup = backup
        if not Protection.VerifyNamecall() then
            mt.__namecall = backup
            Protection.NamecallMeta = nil
            Protection.NamecallBackup = nil
            error("verificacion del namecall fallo")
        end
        Protection.KickGuardOk = true
    end)
    if not ok or not Protection.KickGuardOk then
        Protection.KickGuardOk = false
        Core.Notify("Anti-Kick no soportado por este executor; el menu sigue igual", "Anti-Expulsion")
    end
    return Protection.KickGuardOk
end
Protection.InstallKickGuard = installKickGuard

function Protection.UninstallKickGuard()
    if not Protection.KickGuardOk then return end
    pcall(function()
        if Protection.NamecallMeta and Protection.NamecallBackup then
            Protection.NamecallMeta.__namecall = Protection.NamecallBackup
        end
    end)
    Protection.KickGuardOk = false
    Protection.NamecallMeta = nil
    Protection.NamecallBackup = nil
end

-- Decide si el hook tiene que estar puesto segun los flags actuales.
function Protection.Sync()
    local quiere = Core.Flags["bypass_enabled"] ~= false
        and (Core.Flags["anti_kick"] ~= false or Core.Flags["teleport_guard"] == true)
    if quiere then
        installKickGuard()
    else
        Protection.UninstallKickGuard()
    end
    refrescarEstado()
    return Protection.KickGuardOk
end

-- Filtra remotos peligrosos: algunos juegos kickean por eventos inesperados.
local function remoteFilter()
    local lp = S.Players and S.Players.LocalPlayer
    if not lp then return end
    local ok = pcall(function()
        if type(getconnections) ~= "function" then return end
        if lp.Character then
            local hum = lp.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                for _, c in ipairs(getconnections(hum.HealthChanged)) do
                    if tostring(c.Function):find("Kick") then c:Disconnect() end
                end
            end
        end
    end)
    if not ok then Core.log("remote filter: no disponible") end
end

-- El spoof viejo apilaba un SEGUNDO hook de namecall encima del de Kick y
-- rompia los metodos del juego (esa era la expulsion en el celular). Ahora el
-- toggle solo re-sincroniza el guard seguro y nada mas.
local function spoofExecutor()
    if not Core.Flags["bypass_spoof"] then return end
    Protection.Sync()
end

-- Proteccion de GUI: el menu vive en CoreGui (via gethui) con nombre
-- camuflado para que los escaneres de nombres no lo encuentren. Si el juego
-- intenta borrarlo, se re-parenta solo.
local function shieldGui(gui)
    if not gui then return end
    pcall(function()
        gui.Name = Core.CloakName()
    end)
    Core.Connect(gui.Destroying, function()
        task.defer(function()
            pcall(function() gui.Parent = gethui and gethui() or (S.CoreGui or S.StarterGui) end)
        end)
    end)
end

-- Guardian del personaje: repone las partes que el juego nos borra (fall damage
-- de ropa, anticheats que limpian accesorios, etc.)
local function characterGuard()
    task.spawn(function()
        while task.wait(2) do
            if Core.Flags["prot_charguard"] then
                pcall(function()
                    local lp = S.Players.LocalPlayer
                    if lp and lp.Character then
                        local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health <= 0 then return end
                        if not lp.Character:FindFirstChild("Head") then
                            lp.Character:BreakJoints()
                        end
                    end
                end)
            end
        end
    end)
end

-- Anti-Fling: si otro jugador te lanza (fling), la velocidad horizontal del
-- personaje se dispara y algunos juegos lo leen como exploit; la cortamos.
-- Anti-Freeze: si el juego te ancla el personaje para congelarte, lo libera.
function Protection.Step(dt)
    if Core.Flags["bypass_enabled"] ~= false and Core.Flags["anti_fling"] ~= false then
        if not Core.Flags["fly_enabled"] then
            local root = Core.Root()
            local hum = Core.Humanoid()
            if root and hum and hum.Health > 0 then
                local v = root.AssemblyLinearVelocity
                if Vector3.new(v.X, 0, v.Z).Magnitude > SEG.FLING_MAX then
                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
                    end)
                    Protection.Flinges = Protection.Flinges + 1
                    refrescarEstado()
                end
            end
        end
    end
    if Core.Flags["bypass_enabled"] ~= false and Core.Flags["anti_freeze"] == true then
        Protection.FreezeT = (Protection.FreezeT or 0) + (dt or 0)
        if Protection.FreezeT > 0.5 then
            Protection.FreezeT = 0
            local root = Core.Root()
            if root and root.Anchored == true then
                pcall(function() root.Anchored = false end)
                Core.Notify("Congelamiento liberado", "Anti-Freeze")
            end
        end
    end
end

-- Escaner de proteccion del juego: recorre las instancias visibles del cliente
-- y busca pistas de anti-cheats y sistemas de deteccion, para saber que
-- features conviene cuidar en este juego.
local SENALES_ALTO = { "anticheat", "anti_cheat", "anti-cheat", "antiexploit", "anti_exploit",
    "exploit", "honeypot", "canary", "integrity", "watchdog" }
local SENALES_MEDIO = { "detect", "verify", "guard", "shield", "sentinel", "servercheck",
    "clientcheck", "kick", "ban", "report", "moderation", "trap" }

function Protection.ScanGame()
    local hallazgos = {}
    local escaneadas = 0
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            escaneadas = escaneadas + 1
            if escaneadas > 20000 then break end
            local ok, nom = pcall(function() return obj.Name end)
            if ok and type(nom) == "string" and #nom > 1 then
                local l = nom:lower()
                local nivel
                for _, p in ipairs(SENALES_ALTO) do
                    if l:find(p, 1, true) then nivel = "ALTO" break end
                end
                if not nivel then
                    for _, p in ipairs(SENALES_MEDIO) do
                        if l:find(p, 1, true) then nivel = "MEDIO" break end
                    end
                end
                if nivel then
                    local clase = "?"
                    pcall(function() clase = obj.ClassName end)
                    hallazgos[#hallazgos + 1] = { nombre = nom, clase = clase, nivel = nivel }
                end
            end
        end
    end)
    table.sort(hallazgos, function(a, b)
        if a.nivel == b.nivel then return a.nombre < b.nombre end
        return a.nivel == "ALTO"
    end)
    local altos = 0
    for _, h in ipairs(hallazgos) do
        if h.nivel == "ALTO" then altos = altos + 1 end
    end
    local lineas = {}
    if #hallazgos == 0 then
        lineas[#lineas + 1] = "Sin rastros de anti-cheat. Igual cuida speed, fly y teleports largos."
    else
        lineas[#lineas + 1] = string.format("Detecte %d sistemas (riesgo %s).", #hallazgos, altos > 0 and "ALTO" or "medio")
        for i = 1, math.min(#hallazgos, 6) do
            local h = hallazgos[i]
            lineas[#lineas + 1] = "  [" .. h.nivel .. "] " .. h.nombre .. " (" .. h.clase .. ")"
        end
        if altos > 0 then
            lineas[#lineas + 1] = "Recomendado: Modo sigiloso activado y evitar speed/teleport/fly aca."
        end
    end
    local texto = table.concat(lineas, "\n")
    if Protection.ScanLabel then
        pcall(function() Protection.ScanLabel.Text = texto end)
    end
    Core.Notify("Escaneo listo: " .. #hallazgos .. " senales", "Escaner")
    return hallazgos
end

function Protection.Install()
    if Protection.Installed then return end
    Protection.Installed = true
    idleKick()
    idleJump()
    Protection.Sync()
    remoteFilter()
    characterGuard()
    pcall(function() spoofExecutor() end)
end

Core.ShieldGui = shieldGui
Core.AutoReinstall = function()
    task.spawn(function()
        while task.wait(5) do
            if Core.Flags["prot_reinstall"] then
                pcall(function() Protection.Sync() end)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- 4. UI
--------------------------------------------------------------------------------
--[[ ---------------------------------------------------------------------------
    UI: helpers, tema, ventana, pestañas, controles y notificaciones.
    Los controles escriben SIEMPRE en Core.Flags (fuente de verdad) y se
    registran en UI.Controls[flag] para poder forzarlos desde codigo/test.
--------------------------------------------------------------------------- ]]
local UI = {}
Core.UI = UI

UI.Controls = {}
UI.Tabs = {}
UI.Objects = {}
UI.Open = true
UI.Minimized = false
UI.Accent = "Stirlax"
UI.AccentColor = nil

-- Cada tema son dos colores: el par se usa como gradiente en los detalles.
UI.Accents = {
    Stirlax = { "FF2E4D", "B4001E" },
    Ruby    = { "FF3D6E", "FF8A3D" },
    Emerald = { "17C964", "29D0FF" },
    Gold    = { "FFC53D", "FF7A18" },
    Ice     = { "8AE7FF", "4D6BFF" },
    Candy   = { "FF5FD2", "9C5CFF" },
    Mono    = { "E6E6E6", "9AA0AA" },
}

local T = {}
UI.Theme = T
local function theme()
    local a = UI.Accents[UI.Accent] or UI.Accents.Stirlax
    T.bg        = Core.Hex("060608")
    T.bg2       = Core.Hex("0B0B11")
    T.bg3       = Core.Hex("131320")
    T.line      = Core.Hex("262638")
    T.text      = Core.Hex("F4F5FA")
    T.sub       = Core.Hex("8E92A8")
    T.accent    = Core.Hex(a[1])
    T.accent2   = Core.Hex(a[2])
    T.dark      = Core.Hex("030305")
    T.good      = Core.Hex("2BD98A")
    T.bad       = Core.Hex("FF4D6D")
    T.glow      = Core.Hex("FF2E4D")
end
theme()

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function new(class, props, parent)
    local ok, obj = pcall(Instance.new, class)
    if not ok or not obj then return nil end
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    if parent then pcall(function() obj.Parent = parent end) end
    return obj
end
UI.new = new

function UI.corner(obj, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, obj)
end
function UI.stroke(obj, color, thickness, trans)
    return new("UIStroke", {
        Color = color or T.line,
        Thickness = thickness or 1,
        Transparency = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, obj)
end
function UI.pad(obj, l, t, r, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or l or 0),
        PaddingRight = UDim.new(0, r or l or 0), PaddingBottom = UDim.new(0, b or t or l or 0),
    }, obj)
end
function UI.list(obj, padding, dir)
    return new("UIListLayout", {
        Padding = UDim.new(0, padding or 6),
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, obj)
end
function UI.grad(obj, c1, c2, rot)
    local list = {}
    local ok = pcall(function()
        if c1 and c2 then
            list = { ColorSequence.new({
                ColorSequenceKeypoint.new(0, c1),
                ColorSequenceKeypoint.new(1, c2),
            }) }
        end
    end)
    local props = { Rotation = rot or 45 }
    if ok and list[1] then props.Color = list[1] end
    return new("UIGradient", props, obj)
end
function UI.scale(obj, s)
    return new("UIScale", { Scale = s or 1 }, obj)
end

-- Vidrio: registro de fondos que siguen la transparencia global del menu.
UI.Glass = {}
function UI.glass(obj, factor)
    if not obj then return obj end
    local base = obj.BackgroundTransparency or 0
    UI.Glass[#UI.Glass + 1] = { Obj = obj, Factor = factor or 1, Base = base }
    pcall(function()
        local a = (tonumber(Core.Flags["ui_glass"]) or 28) / 100
        obj.BackgroundTransparency = math.clamp(base + a * (factor or 1), 0, 0.95)
    end)
    return obj
end
function UI.unglass(obj)
    for i = #UI.Glass, 1, -1 do
        if UI.Glass[i].Obj == obj then table.remove(UI.Glass, i) end
    end
end
function UI.ApplyGlass()
    local a = (tonumber(Core.Flags["ui_glass"]) or 28) / 100
    for _, g in ipairs(UI.Glass) do
        pcall(function()
            g.Obj.BackgroundTransparency = math.clamp(g.Base + a * g.Factor, 0, 0.95)
        end)
    end
end
function UI.UpdateBlur()
    pcall(function()
        if not S.Lighting then return end
        local bl = S.Lighting:FindFirstChild("StirlaxBlur")
        local want = Core.Flags["ui_blur"] and UI.Open and not UI.Minimized
        if want then
            if not bl then
                bl = new("BlurEffect", { Name = "StirlaxBlur" }, S.Lighting)
                if bl then bl.Size = 14 end
            end
            if bl then
                bl.Enabled = true
                bl.Size = 14
            end
        elseif bl then
            bl.Enabled = false
        end
    end)
end

-- Animacion decorativa: si el executor o el entorno no tweenea, no rompe nada.
function UI.Anim(obj, info, goal)
    local ok, tw = pcall(function() return S.Tween:Create(obj, info, goal) end)
    if ok and tw then pcall(function() tw:Play() end) end
    return ok
end

-- Brillo diagonal (efecto cristal) para tarjetas, barras y botones.
function UI.shine(parent, hex)
    if not parent then return nil end
    local sh = new("Frame", {
        Name = "Shine",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Core.Hex(hex or "FFFFFF"),
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
        ZIndex = (parent.ZIndex or 1) + 1,
    }, parent)
    UI.corner(sh, 12)
    local g = new("UIGradient", {}, sh)
    if g then
        pcall(function()
            g.Rotation = 115
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.42, 1),
                NumberSequenceKeypoint.new(0.5, 0.55),
                NumberSequenceKeypoint.new(0.58, 1),
                NumberSequenceKeypoint.new(1, 1),
            })
        end)
    end
    return sh
end

-- Fondo de lava: tres burbujas rojas que flotan lento detras del contenido.
-- Sólo son tres tweens largos: liviano incluso en movil.
function UI.lava(parent)
    if not parent then return nil end
    local holder = new("Frame", {
        Name = "Lava",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 0,
    }, parent)
    UI.corner(holder, 14)
    UI._lavaTweens = {}
    local defs = {
        { pos = UDim2.new(-0.15, 0, 0.55, 0), size = UDim2.new(0.8, 0, 0.9, 0), color = "FF2E4D", trans = 0.82, to = UDim2.new(0.45, 0, 0.4, 0), time = 13 },
        { pos = UDim2.new(0.55, 0, -0.25, 0), size = UDim2.new(0.75, 0, 0.85, 0), color = "7A0B1E", trans = 0.78, to = UDim2.new(0.05, 0, 0.05, 0), time = 17 },
        { pos = UDim2.new(0.05, 0, -0.35, 0), size = UDim2.new(0.6, 0, 0.7, 0), color = "B4001E", trans = 0.85, to = UDim2.new(0.3, 0, 0.6, 0), time = 11 },
    }
    for i, d in ipairs(defs) do
        local b = new("Frame", {
            Name = "Blob" .. i,
            Position = d.pos,
            Size = d.size,
            BackgroundColor3 = Core.Hex(d.color),
            BackgroundTransparency = d.trans,
            BorderSizePixel = 0,
            ZIndex = 0,
        }, holder)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
        local ok, tw = pcall(function()
            return S.Tween:Create(b, TweenInfo.new(d.time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = d.to })
        end)
        if ok and tw then
            pcall(function() tw:Play() end)
            table.insert(UI._lavaTweens, tw)
        end
    end
    local glow = new("Frame", {
        Name = "LavaGlow",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Core.Hex("FF2E4D"),
        BackgroundTransparency = 0.93,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, holder)
    UI.corner(glow, 14)
    local g = new("UIGradient", {}, glow)
    if g then
        pcall(function()
            g.Rotation = 90
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(1, 1),
            })
        end)
    end
    UI._lavaHolder = holder
    return holder
end

-- Pausa la lava cuando el menu esta cerrado: costo cero en segundo plano.
function UI.LavaActive(on)
    for _, tw in ipairs(UI._lavaTweens or {}) do
        pcall(function()
            if on then tw:Play() else tw:Pause() end
        end)
    end
end

-- Abrir / cerrar el menu en un solo lugar (visible, blur, lava y animacion).
function UI.SetOpen(open)
    UI.Open = open and true or false
    local win = UI.WindowObj
    if win and win.Root then
        win.Root.Visible = UI.Open
        if UI.Open and win.Escala and win.Escala.Obj then
            pcall(function()
                win.Escala.Obj.Scale = win.Escala.Base * 0.94
                local tw = S.Tween:Create(win.Escala.Obj,
                    TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Scale = win.Escala.Base })
                if tw then tw:Play() end
            end)
        end
    end
    if UI.UpdateBlur then UI.UpdateBlur() end
    if UI.LavaActive then UI.LavaActive(UI.Open) end
end

function UI.Slug(text)
    local s = tostring(text):lower()
    s = s:gsub("[áàä]", "a"):gsub("[éèë]", "e"):gsub("[íìï]", "i"):gsub("[óòö]", "o"):gsub("[úùü]", "u")
    s = s:gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    return s
end

-- Recolorea todo lo que se registró con UI.Tint(obj, "accent") etc.
local tinted = {}
function UI.Tint(obj, kind)
    tinted[#tinted + 1] = { obj = obj, kind = kind }
    local c = kind == "accent" and T.accent or (kind == "accent2" and T.accent2 or (kind == "sub" and T.sub or T.text))
    pcall(function()
        if obj.ClassName == "UIStroke" then obj.Color = c
        elseif obj.ClassName:find("Text") then obj.TextColor3 = c
        elseif obj.ClassName == "ImageLabel" or obj.ClassName == "ImageButton" then obj.ImageColor3 = c
        else obj.BackgroundColor3 = c end
    end)
    return obj
end

function UI.SetAccent(name)
    -- Acepta tanto un preset como un hex crudo ("#RRGGBB").
    if UI.Accents[name] then
        UI.Accent = name
        UI.AccentColor = nil
    else
        local hex = tostring(name):gsub("#", "")
        if #hex == 6 and tonumber(hex, 16) then
            UI.Accent = "Custom"
            if not UI.Accents.Custom then UI.Accents.Custom = { hex, hex } end
            UI.Accents.Custom[1] = hex
            UI.Accents.Custom[2] = hex
            UI.AccentColor = hex
        else
            return
        end
    end
    theme()
    for _, t in ipairs(tinted) do
        local c = t.kind == "accent" and T.accent or (t.kind == "accent2" and T.accent2 or (t.kind == "sub" and T.sub or T.text))
        pcall(function()
            if t.obj.ClassName == "UIStroke" then t.obj.Color = c
            elseif t.obj.ClassName:find("Text") then t.obj.TextColor3 = c
            elseif t.obj.ClassName == "ImageLabel" or t.obj.ClassName == "ImageButton" then t.obj.ImageColor3 = c
            else t.obj.BackgroundColor3 = c end
        end)
    end
    if UI.WindowObj then
        pcall(function() UI.WindowObj._refresh() end)
    end
end
UI.theme = theme

--------------------------------------------------------------------------------
-- Registro de controles (los flags son la fuente de verdad)
--------------------------------------------------------------------------------
function UI.Register(flag, ctrl)
    if flag == nil or flag == "" then flag = ctrl.Flag end
    if flag then UI.Controls[flag] = ctrl end
    return ctrl
end

function UI.Set(flag, value, fire)
    local c = UI.Controls[flag]
    if not c then
        Core.Flags[flag] = value
        return
    end
    if c.Set then
        c:Set(value, fire)
    else
        Core.Flags[flag] = value
    end
end

function UI.Get(flag)
    local c = UI.Controls[flag]
    if c and c.Value ~= nil then return c.Value end
    return Core.Flags[flag]
end

--------------------------------------------------------------------------------
-- Notificaciones y watermark
--------------------------------------------------------------------------------
local notifHolder = nil
function UI.Notify(text, title, duration)
    if not notifHolder then return end
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = T.bg3,
        BackgroundTransparency = 0.05,
        LayoutOrder = -os.clock() * 1000,
    }, notifHolder)
    UI.corner(card, 10)
    UI.stroke(card, T.accent, 1, 0.4)
    UI.glass(card, 0.6)
    local barra = new("Frame", {
        Size = UDim2.new(0, 3, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = T.accent,
    }, card)
    if barra then UI.grad(barra, T.accent, T.accent2, 90) end
    new("TextLabel", {
        Text = tostring(title or UI.BrandName or "STIRLAX MODZ"),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = T.text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -22, 0, 18),
        Position = UDim2.new(0, 16, 0, 6),
    }, card)
    new("TextLabel", {
        Text = tostring(text or ""),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = T.sub,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -22, 0, 16),
        Position = UDim2.new(0, 16, 0, 23),
    }, card)

    task.delay(duration or 3, function()
        pcall(function()
            local tween = S.Tween:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
            tween:Play()
            task.wait(0.3)
            card:Destroy()
            UI.unglass(card)
        end)
    end)
    return card
end
Core.Notify = UI.Notify

local watermark = nil
function UI.Watermark()
    if watermark then return watermark end
    watermark = new("Frame", {
        Size = UDim2.new(0, 210, 0, 26),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = T.bg2,
        BackgroundTransparency = 0.1,
    }, UI.Screen)
    UI.corner(watermark, 8)
    UI.stroke(watermark, T.accent, 1, 0.5)
    UI.glass(watermark, 0.7)
    UI.Tint(new("TextLabel", {
        Text = Core.Brand .. "  |  v" .. Core.Version,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = T.text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
    }, watermark), "accent")

    local info = new("TextLabel", {
        Text = "",
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = T.sub,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
    }, watermark)

    task.spawn(function()
        local frames, last = 0, os.clock()
        while task.wait(0.5) do
            frames = frames + 1
            local now = os.clock()
            local fps = math.floor(frames / math.max(now - last, 0.001))
            frames, last = 0, now
            local ping = 0
            pcall(function()
                ping = math.floor(S.Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            pcall(function()
                info.Text = string.format("%d fps  %d ms", fps, ping)
            end)
        end
    end)
    return watermark
end

--------------------------------------------------------------------------------
-- Color picker
--------------------------------------------------------------------------------
function UI.ColorPicker(initial, callback)
    local hex = tostring(initial or "FF3D6E"):gsub("#", "")
    local holder = new("Frame", {
        Name = "ColorPicker",
        Size = UDim2.new(0, 220, 0, 190),
        Position = UDim2.new(0.5, -110, 0.5, -95),
        BackgroundColor3 = T.bg2,
        ZIndex = 50,
    }, UI.Screen)
    UI.corner(holder, 12)
    UI.stroke(holder, T.accent, 1, 0.3)

    local preview = new("Frame", {
        Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(0, 14, 0, 14),
        BackgroundColor3 = Core.Hex(hex),
    }, holder)
    UI.corner(preview, 8)

    local box = new("TextBox", {
        Text = "#" .. hex:upper(),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = T.text,
        BackgroundColor3 = T.bg3,
        Size = UDim2.new(1, -80, 0, 40),
        Position = UDim2.new(0, 64, 0, 14),
        PlaceholderText = "#RRGGBB",
        ClearTextOnFocus = false,
    }, holder)
    UI.corner(box, 8)

    local r, g, b = tonumber(hex:sub(1, 2), 16) or 255, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0
    local sliders = {}
    local function bar(y, valor, canal)
        local track = new("Frame", {
            Size = UDim2.new(1, -28, 0, 8),
            Position = UDim2.new(0, 14, 0, y),
            BackgroundColor3 = canal == "R" and Core.Hex("FF4D6D") or (canal == "G" and Core.Hex("2BD98A") or Core.Hex("4D8BFF")),
        }, holder)
        UI.corner(track, 4)
        local fill = new("Frame", {
            Size = UDim2.new(valor / 255, 0, 1, 0),
            BackgroundColor3 = T.text,
        }, track)
        UI.corner(fill, 4)
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local function mover(px)
                    local rel = math.clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
                    if canal == "R" then r = math.floor(rel * 255) end
                    if canal == "G" then g = math.floor(rel * 255) end
                    if canal == "B" then b = math.floor(rel * 255) end
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    local h = string.format("%02X%02X%02X", r, g, b)
                    preview.BackgroundColor3 = Core.Hex(h)
                    box.Text = "#" .. h
                    if callback then callback(h) end
                end
                local conn
                conn = S.UIS.InputChanged:Connect(function()
                    local m = S.UIS:GetMouseLocation()
                    mover(m.X)
                end)
                task.delay(0.05, function() end)
                local conn2
                conn2 = S.UIS.InputEnded:Connect(function()
                    if conn then conn:Disconnect() end
                    if conn2 then conn2:Disconnect() end
                end)
            end
        end)
        sliders[canal] = fill
    end
    bar(70, r, "R")
    bar(92, g, "G")
    bar(114, b, "B")

    box.FocusLost:Connect(function()
        local h = box.Text:gsub("#", "")
        if #h == 6 and tonumber(h, 16) then
            r, g, b = tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
            preview.BackgroundColor3 = Core.Hex(h)
            if sliders.R then sliders.R.Size = UDim2.new(r / 255, 0, 1, 0) end
            if sliders.G then sliders.G.Size = UDim2.new(g / 255, 0, 1, 0) end
            if sliders.B then sliders.B.Size = UDim2.new(b / 255, 0, 1, 0) end
            if callback then callback(h:upper()) end
        end
    end)

    local close = new("TextButton", {
        Text = "Listo",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = T.text,
        BackgroundColor3 = T.accent,
        Size = UDim2.new(0, 80, 0, 32),
        Position = UDim2.new(0.5, -40, 1, -46),
    }, holder)
    UI.corner(close, 8)
    close.MouseButton1Click:Connect(function()
        if callback then callback(string.format("%02X%02X%02X", r, g, b)) end
        holder:Destroy()
    end)
    return holder
end
--------------------------------------------------------------------------------
-- Pantalla, ventana y pestañas
--------------------------------------------------------------------------------
local dragging = {}
local function makeDraggable(handle, target, onTap)
    local start, startPos, moved = nil, nil, false
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging[target] = true
            start = S.UIS:GetMouseLocation()
            local p = target.Position
            startPos = Vector2.new(p.X.Offset, p.Y.Offset)
            moved = false
        end
    end)
    S.UIS.InputChanged:Connect(function(input)
        if not dragging[target] then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local now = S.UIS:GetMouseLocation()
            local delta = now - start
            if math.abs(delta.X) + math.abs(delta.Y) > 6 then moved = true end
            pcall(function()
                target.Position = UDim2.new(0, startPos.X + delta.X, 0, startPos.Y + delta.Y)
            end)
        end
    end)
    S.UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging[target] and not moved and onTap then onTap() end
            dragging[target] = nil
        end
    end)
end
UI.Drag = makeDraggable

function UI.BuildScreen()
    local parent = nil
    pcall(function() if gethui then parent = gethui() end end)
    if not parent then parent = S.CoreGui end
    if not parent then
        local lp = S.Players and S.Players.LocalPlayer
        parent = lp and lp:FindFirstChildOfClass("PlayerGui")
    end
    if not parent and S.StarterGui then
        pcall(function() parent = S.StarterGui:FindFirstChildOfClass("PlayerGui") end)
    end
    UI.Screen = new("ScreenGui", {
        Name = Core.CloakName(),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 9999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parent)
    if not UI.Screen then
        UI.Screen = new("ScreenGui", { Name = Core.CloakName(), ResetOnSpawn = false })
    end
    notifHolder = new("Frame", {
        Size = UDim2.new(0, 260, 0, 300),
        Position = UDim2.new(1, -276, 0, 60),
        BackgroundTransparency = 1,
    }, UI.Screen)
    UI.list(notifHolder, 8)
    Core.ShieldGui(UI.Screen)
    return UI.Screen
end

function UI.Window(title)
    local vs = Core.Viewport()
    local escala = 1
    if vs.X < 760 or vs.Y < 520 then
        escala = math.clamp(math.min(vs.X / 700, vs.Y / 480), 0.55, 1)
    end

    local root = new("Frame", {
        Name = "Main",
        Size = UDim2.new(0, 620, 0, 400),
        Position = UDim2.new(0.5, -310, 0.5, -200),
        BackgroundColor3 = T.bg,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Visible = true,
    }, UI.Screen)
    UI.corner(root, 14)
    UI.stroke(root, T.line, 1, 0.15)
    local escalaObj = UI.scale(root, escala)
    UI.glass(root, 1)
    UI.lava(root)

    local top = new("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = T.bg2,
        BorderSizePixel = 0,
    }, root)
    UI.corner(top, 14)
    UI.glass(top, 0.8)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = T.bg2,
        BorderSizePixel = 0,
    }, top)
    UI.shine(top, "FF6B7A")

    local logo = new("Frame", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 12, 0.5, -14),
        BackgroundColor3 = T.accent,
    }, top)
    UI.corner(logo, 8)
    UI.grad(logo, T.accent, T.accent2, 135)
    new("TextLabel", {
        Text = "S",
        Font = Enum.Font.GothamBlack,
        TextSize = 16,
        TextColor3 = Core.Hex("0B0B12"),
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    }, logo)

    local titleLbl = new("TextLabel", {
        Text = string.upper(tostring(title or Core.Brand)),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 48, 0, 0),
    }, top)
    local verLbl = new("TextLabel", {
        Text = "v" .. Core.Version,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = T.sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(0, 48 + #tostring(title or Core.Brand) * 8, 0, 0),
    }, top)

    local btnMin = new("TextButton", {
        Text = "—",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = T.sub,
        BackgroundColor3 = T.bg3,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -76, 0.5, -15),
        AutoButtonColor = false,
    }, top)
    UI.corner(btnMin, 8)
    local btnClose = new("TextButton", {
        Text = "×",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = T.text,
        BackgroundColor3 = T.bad,
        BackgroundTransparency = 0.25,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -40, 0.5, -15),
        AutoButtonColor = false,
    }, top)
    UI.corner(btnClose, 8)

    -- Barra lateral de pestañas
    local sidebar = new("Frame", {
        Size = UDim2.new(0, 148, 1, -72),
        Position = UDim2.new(0, 10, 0, 54),
        BackgroundColor3 = T.bg2,
        BorderSizePixel = 0,
    }, root)
    UI.corner(sidebar, 10)
    UI.glass(sidebar, 0.9)
    UI.pad(sidebar, 8, 8, 8, 8)
    local sideList = UI.list(sidebar, 6)

    local content = new("Frame", {
        Size = UDim2.new(1, -176, 1, -72),
        Position = UDim2.new(0, 166, 0, 54),
        BackgroundColor3 = T.bg2,
        BorderSizePixel = 0,
    }, root)
    UI.corner(content, 10)
    UI.glass(content, 0.9)

    local footer = new("TextLabel", {
        Text = "RightShift para abrir o cerrar  •  ejecutando " .. Core.Brand,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = T.sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 14, 1, -20),
    }, root)

    local win = {
        Root = root, Top = top, Sidebar = sidebar, Content = content, Tabs = {}, Current = nil,
        MinimizeBtn = btnMin, CloseBtn = btnClose, ThemeBtn = themeBtn, Footer = footer,
        Escala = { Obj = escalaObj, Base = escala },
    }
    UI.WindowObj = win

    -- Botones de tema
    local themeBtn = new("TextButton", {
        Text = "TEMA",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = T.sub,
        BackgroundColor3 = T.bg3,
        Size = UDim2.new(0, 50, 0, 30),
        Position = UDim2.new(1, -134, 0.5, -15),
        AutoButtonColor = false,
    }, top)
    UI.corner(themeBtn, 8)
    local names = {}
    for k in pairs(UI.Accents) do
        if k ~= "Custom" then names[#names + 1] = k end
    end
    table.sort(names)
    local idx = 1
    themeBtn.MouseButton1Click:Connect(function()
        idx = idx % #names + 1
        UI.SetAccent(names[idx])
        UI.Notify("Tema: " .. names[idx], "Apariencia")
    end)

    btnMin.MouseButton1Click:Connect(function()
        UI.Minimized = not UI.Minimized
        for _, t in ipairs(win.Tabs) do
            if t.Page then t.Page.Visible = (not UI.Minimized) and (win.Current == t) end
        end
        sidebar.Visible = not UI.Minimized
        content.Visible = not UI.Minimized
        footer.Visible = not UI.Minimized
        pcall(function()
            root.Size = UI.Minimized and UDim2.new(0, 620, 0, 46) or UDim2.new(0, 620, 0, 400)
        end)
        UI.UpdateBlur()
    end)
    btnClose.MouseButton1Click:Connect(function()
        UI.SetOpen(false)
        UI.Notify("Menu cerrado. Toca el boton flotante.", "STIRLAX MODZ")
    end)

    makeDraggable(top, root, nil)
    win._refresh = function()
        pcall(function()
            top.BackgroundColor3 = T.bg2
            sidebar.BackgroundColor3 = T.bg2
            content.BackgroundColor3 = T.bg2
            titleLbl.TextColor3 = T.text
        end)
    end

    -- Tab(): crea boton lateral + pagina scrolleable
    function win:Tab(name, _orden)
        local page = new("ScrollingFrame", {
            Size = UDim2.new(1, -16, 1, -16),
            Position = UDim2.new(0, 8, 0, 8),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = T.accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        }, content)
        UI.list(page, 6)
        UI.pad(page, 4, 4, 4, 12)

        local btn = new("TextButton", {
            Text = string.upper(name),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = T.sub,
            BackgroundColor3 = T.bg3,
            BackgroundTransparency = 0.35,
            Size = UDim2.new(1, 0, 0, 34),
            AutoButtonColor = false,
        }, sidebar)
        UI.corner(btn, 8)
        local bar = new("Frame", {
            Size = UDim2.new(0, 3, 0, 16),
            Position = UDim2.new(0, 0, 0.5, -8),
            BackgroundColor3 = T.accent,
            BorderSizePixel = 0,
            Visible = false,
        }, btn)
        UI.corner(bar, 2)

        local tab = { Name = name, Page = page, Button = btn, Bar = bar }
        btn.MouseButton1Click:Connect(function()
            win:Select(tab)
        end)
        win.Tabs[#win.Tabs + 1] = tab
        UI.Tabs[name] = tab
        pcall(function()
            btn.MouseEnter:Connect(function()
                if win.Current ~= tab then
                    UI.Anim(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.15 })
                end
            end)
            btn.MouseLeave:Connect(function()
                if win.Current ~= tab then
                    UI.Anim(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.35 })
                end
            end)
        end)
        if not win.Current then win:Select(tab) end
        return tab
    end

    function win:Select(tab)
        win.Current = tab
        for _, t in ipairs(win.Tabs) do
            local sel = (t == tab)
            pcall(function()
                t.Button.BackgroundColor3 = sel and T.accent or T.bg3
                t.Button.BackgroundTransparency = sel and 0 or 0.35
                t.Button.TextColor3 = sel and Core.Hex("0B0B12") or T.sub
                t.Page.Visible = sel and not UI.Minimized
                if t.Bar then
                    t.Bar.Visible = sel
                    t.Bar.BackgroundColor3 = sel and T.text or T.line
                end
            end)
        end
    end

    return win
end

--------------------------------------------------------------------------------
-- Controles
--------------------------------------------------------------------------------
local function row(parent, height)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, height or 34),
        BackgroundColor3 = T.bg3,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
    }, parent)
    UI.corner(f, 8)
    UI.pad(f, 10, 0, 10, 0)
    UI.glass(f, 0.5)
    return f
end

function UI.Section(parent, text)
    local holder = new("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    }, parent)
    new("Frame", {
        Size = UDim2.new(0, 2, 0, 10),
        Position = UDim2.new(0, 0, 0.5, -5),
        BackgroundColor3 = T.accent,
    }, holder)
    new("TextLabel", {
        Text = string.upper(tostring(text)),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
    }, holder)
    local line = new("Frame", {
        Size = UDim2.new(0.42, -32, 0, 1),
        Position = UDim2.new(0.58, 0, 0.5, 0),
        BackgroundColor3 = T.line,
        BackgroundTransparency = 0.3,
    }, holder)
    UI.Tint(line, "accent")
    local lg = new("UIGradient", {}, line)
    if lg then
        pcall(function()
            lg.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.15),
                NumberSequenceKeypoint.new(1, 1),
            })
        end)
    end
    return holder
end

function UI.Label(parent, text)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    }, parent)
    local l = new("TextLabel", {
        Text = tostring(text),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = T.sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextWrapped = true,
    }, f)
    return { Type = "Label", Frame = f, Label = l }
end

function UI.Toggle(parent, opts)
    opts = opts or {}
    local flag = opts.Flag or UI.Slug(opts.Text)
    local f = row(parent, 34)
    local label = new("TextLabel", {
        Text = tostring(opts.Text or flag),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -60, 1, 0),
    }, f)
    local pill = new("Frame", {
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -40, 0.5, -10),
        BackgroundColor3 = T.line,
        BorderSizePixel = 0,
    }, f)
    UI.corner(pill, 10)
    local pillGrad = UI.grad(pill, T.accent, T.accent2, 135)
    if pillGrad then pillGrad.Enabled = false end
    local dot = new("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = T.text,
    }, pill)
    UI.corner(dot, 7)
    local btn = new("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 3,
    }, f)

    local ctrl = { Type = "Toggle", Flag = flag, Frame = f, Value = nil, Parent = parent,
        Button = btn, Pill = pill, Dot = dot }
    function ctrl:Set(v, fire)
        v = v and true or false
        self.Value = v
        Core.Flags[flag] = v
        pcall(function()
            local goal = v and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
            local tween = S.Tween:Create(dot, TweenInfo.new(0.15), { Position = goal })
            tween:Play()
            pill.BackgroundColor3 = v and T.accent or T.line
            pill.BackgroundTransparency = v and 0 or 0.25
            if pillGrad then pillGrad.Enabled = v end
            dot.BackgroundColor3 = v and T.text or T.sub
            label.TextColor3 = v and T.text or T.sub
        end)
        if fire and opts.Callback then
            local ok, err = pcall(opts.Callback, v)
            if not ok then Core.log("callback " .. flag .. ": " .. tostring(err)) end
        end
        return self
    end
    function ctrl:Toggle(fire) return self:Set(not self.Value, fire ~= false) end
    btn.MouseButton1Click:Connect(function() ctrl:Toggle() end)
    UI.Register(flag, ctrl)
    ctrl:Set(opts.Default ~= false, false)
    return ctrl
end

function UI.Slider(parent, opts)
    opts = opts or {}
    local flag = opts.Flag or UI.Slug(opts.Text)
    local min, max = opts.Min or 0, opts.Max or 100
    local f = row(parent, 42)
    local label = new("TextLabel", {
        Text = tostring(opts.Text or flag),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -80, 0, 18),
    }, f)
    local valueLbl = new("TextLabel", {
        Text = "0",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = T.accent,
        TextXAlignment = Enum.TextXAlignment.Right,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 70, 0, 18),
        Position = UDim2.new(1, -70, 0, 0),
    }, f)
    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = T.line,
        BorderSizePixel = 0,
    }, f)
    UI.corner(track, 3)
    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = T.accent,
        BorderSizePixel = 0,
    }, track)
    UI.corner(fill, 3)
    local knob = new("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, -6, 1, -9),
        BackgroundColor3 = T.text,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, f)
    UI.corner(knob, 6)
    UI.stroke(knob, T.accent, 1, 0.25)

    local ctrl = { Type = "Slider", Flag = flag, Frame = f, Min = min, Max = max, Value = min,
        Parent = parent, Track = track, Fill = fill, ValueLabel = valueLbl, Knob = knob }
    function ctrl:Set(v, fire)
        v = tonumber(v) or min
        v = math.clamp(v, min, max)
        if opts.Decimals == 0 then v = math.floor(v + 0.5) end
        self.Value = v
        Core.Flags[flag] = v
        pcall(function()
            local rel = (v - min) / math.max(max - min, 0.0001)
            local tween = S.Tween:Create(fill, TweenInfo.new(0.12), { Size = UDim2.new(rel, 0, 1, 0) })
            tween:Play()
            local tween2 = S.Tween:Create(knob, TweenInfo.new(0.12), { Position = UDim2.new(rel, -6, 1, -9) })
            tween2:Play()
            valueLbl.Text = (opts.Decimals == 0 and tostring(math.floor(v + 0.5)) or string.format("%.2f", v)) .. (opts.Suffix or "")
        end)
        if fire and opts.Callback then
            local ok, err = pcall(opts.Callback, v)
            if not ok then Core.log("callback " .. flag .. ": " .. tostring(err)) end
        end
        return self
    end
    local function fromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        ctrl:Set(min + rel * (max - min), true)
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local conn
            conn = S.UIS.InputChanged:Connect(function()
                local m = S.UIS:GetMouseLocation()
                fromX(m.X)
            end)
            local conn2
            conn2 = S.UIS.InputEnded:Connect(function()
                if conn then conn:Disconnect() end
                if conn2 then conn2:Disconnect() end
            end)
            fromX(S.UIS:GetMouseLocation().X)
        end
    end)
    UI.Register(flag, ctrl)
    ctrl:Set(opts.Default or min, false)
    return ctrl
end

function UI.Dropdown(parent, opts)
    opts = opts or {}
    local flag = opts.Flag or UI.Slug(opts.Text)
    local lista = opts.Options or {}
    local f = row(parent, 34)
    local label = new("TextLabel", {
        Text = tostring(opts.Text or flag),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -90, 1, 0),
    }, f)
    local btn = new("TextButton", {
        Text = tostring(opts.Default or lista[1] or "..."),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = T.text,
        BackgroundColor3 = T.bg,
        Size = UDim2.new(0, 84, 0, 24),
        Position = UDim2.new(1, -84, 0.5, -12),
        AutoButtonColor = false,
    }, f)
    UI.corner(btn, 6)

    local open = false
    local listaFrame = new("Frame", {
        Size = UDim2.new(0, 84, 0, 0),
        Position = UDim2.new(1, -84, 0, 34),
        BackgroundColor3 = T.dark,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 20,
    }, f)
    UI.corner(listaFrame, 6)
    UI.list(listaFrame, 2)

    local ctrl = { Type = "Dropdown", Flag = flag, Frame = f, Options = lista,
        Value = opts.Default or lista[1], Parent = parent, Btn = btn, Lista = listaFrame, Items = {} }
    function ctrl:Set(v, fire)
        for _, o in ipairs(lista) do
            if o == v then
                self.Value = v
                Core.Flags[flag] = v
                pcall(function() btn.Text = tostring(v) end)
                if fire and opts.Callback then
                    local ok, err = pcall(opts.Callback, v)
                    if not ok then Core.log("callback " .. flag .. ": " .. tostring(err)) end
                end
                return self
            end
        end
        return self
    end
    for _, o in ipairs(lista) do
        local item = new("TextButton", {
            Text = tostring(o),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = T.sub,
            BackgroundColor3 = T.dark,
            Size = UDim2.new(1, 0, 0, 24),
            AutoButtonColor = false,
        }, listaFrame)
        ctrl.Items[#ctrl.Items + 1] = item
        item.MouseButton1Click:Connect(function()
            ctrl:Set(o, true)
            open = false
            listaFrame.Visible = false
            listaFrame.Size = UDim2.new(0, 84, 0, 0)
        end)
    end
    btn.MouseButton1Click:Connect(function()
        open = not open
        listaFrame.Visible = open
        listaFrame.Size = UDim2.new(0, 84, 0, open and (#lista * 24 + 6) or 0)
    end)
    UI.Register(flag, ctrl)
    ctrl:Set(opts.Default or lista[1], false)
    return ctrl
end

function UI.Button(parent, opts)
    opts = opts or {}
    local flag = opts.Flag or UI.Slug(opts.Text)
    local f = new("TextButton", {
        Text = tostring(opts.Text or "Boton"),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = T.text,
        BackgroundColor3 = T.bg3,
        Size = UDim2.new(1, 0, 0, 32),
        AutoButtonColor = false,
    }, parent)
    UI.corner(f, 8)
    UI.Tint(f, "accent")
    pcall(function() f.BackgroundTransparency = 0.75 end)
    local ctrl = { Type = "Button", Flag = flag, Frame = f, Parent = parent }
    function ctrl:Fire()
        if opts.Callback then
            local ok, err = pcall(opts.Callback)
            if not ok then Core.log("callback " .. flag .. ": " .. tostring(err)) end
        end
        return self
    end
    f.MouseButton1Click:Connect(function() ctrl:Fire() end)
    UI.Register(flag, ctrl)
    return ctrl
end

function UI.Keybind(parent, opts)
    opts = opts or {}
    local flag = opts.Flag or UI.Slug(opts.Text)
    local f = row(parent, 34)
    new("TextLabel", {
        Text = tostring(opts.Text or flag),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -100, 1, 0),
    }, f)
    local btn = new("TextButton", {
        Text = tostring(opts.Default and opts.Default.Name or "None"),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = T.text,
        BackgroundColor3 = T.bg,
        Size = UDim2.new(0, 84, 0, 24),
        Position = UDim2.new(1, -84, 0.5, -12),
        AutoButtonColor = false,
    }, f)
    UI.corner(btn, 6)

    local ctrl = { Type = "Keybind", Flag = flag, Frame = f, Value = opts.Default, Parent = parent }
    local capturing = false
    function ctrl:Set(v, fire)
        self.Value = v
        Core.Flags[flag] = v
        pcall(function() btn.Text = v and tostring(v.Name or v) or "None" end)
        if fire and opts.Callback then
            local ok, err = pcall(opts.Callback, v)
            if not ok then Core.log("callback " .. flag .. ": " .. tostring(err)) end
        end
        return self
    end
    btn.MouseButton1Click:Connect(function()
        capturing = true
        btn.Text = "..."
    end)
    Core.Connect(S.UIS.InputBegan, function(input)
        if not capturing then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            capturing = false
            ctrl:Set(input.KeyCode, true)
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            capturing = false
            btn.Text = tostring(ctrl.Value and ctrl.Value.Name or "None")
        end
    end)
    UI.Register(flag, ctrl)
    ctrl:Set(opts.Default, false)
    return ctrl
end

function UI.Color(parent, opts)
    opts = opts or {}
    local flag = opts.Flag or UI.Slug(opts.Text)
    local f = row(parent, 34)
    new("TextLabel", {
        Text = tostring(opts.Text or "Color"),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -50, 1, 0),
    }, f)
    local swatch = new("TextButton", {
        Text = "",
        BackgroundColor3 = Core.Hex(opts.Default or "FF3D6E"),
        Size = UDim2.new(0, 42, 0, 22),
        Position = UDim2.new(1, -42, 0.5, -11),
        AutoButtonColor = false,
    }, f)
    UI.corner(swatch, 6)

    local ctrl = { Type = "Color", Flag = flag, Frame = f, Value = opts.Default or "FF3D6E",
        Parent = parent, Swatch = swatch }
    function ctrl:Set(v, fire)
        local hex = tostring(v or "FFFFFF"):gsub("#", "")
        if #hex ~= 6 then return self end
        self.Value = hex
        Core.Flags[flag] = hex
        pcall(function() swatch.BackgroundColor3 = Core.Hex(hex) end)
        if fire and opts.Callback then
            local ok, err = pcall(opts.Callback, hex)
            if not ok then Core.log("callback " .. flag .. ": " .. tostring(err)) end
        end
        return self
    end
    swatch.MouseButton1Click:Connect(function()
        UI.ColorPicker(ctrl.Value, function(hex) ctrl:Set(hex, true) end)
    end)
    UI.Register(flag, ctrl)
    ctrl:Set(opts.Default or "FF3D6E", false)
    return ctrl
end

--------------------------------------------------------------------------------
-- Boton flotante (overlay movil + PC)
--------------------------------------------------------------------------------
function UI.FloatingButton()
    local vs = Core.Viewport()
    local pos = UDim2.new(0, vs.X - 80, 0, vs.Y / 2 - 28)
    local btn = new("TextButton", {
        Name = "FloatingButton",
        Text = "",
        Size = UDim2.new(0, 58, 0, 58),
        Position = pos,
        BackgroundColor3 = T.bg2,
        AutoButtonColor = false,
        ZIndex = 100,
    }, UI.Screen)
    UI.corner(btn, 29)
    UI.stroke(btn, T.accent, 2, 0.1)
    UI.glass(btn, 0.5)
    local inner = new("Frame", {
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = T.bg3,
    }, btn)
    UI.corner(inner, 25)
    UI.glass(inner, 0.5)
    UI.shine(inner, "FFFFFF")
    local logo = new("TextLabel", {
        Text = "S",
        Font = Enum.Font.GothamBlack,
        TextSize = 22,
        TextColor3 = T.accent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    }, inner)

    makeDraggable(btn, btn, function()
        UI.SetOpen(not UI.Open)
    end)
    local resp = UI.scale(btn, 1)
    if resp then
        UI.Anim(resp, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.05 })
    end
    UI.FloatButton = btn
    return btn
end
--------------------------------------------------------------------------------
-- 5. MODULOS
--------------------------------------------------------------------------------
-- Constantes que cambian entre juegos: se tocan aca y en ningun otro lado.
local CONST = {
    -- Altura a la que se activa el rescate del anti-void.
    VOID_Y = -60,
    -- Altura del rescate vertical del anti-void (misma X/Z, no te manda al origen).
    VOID_RESCUE_ALTO = 60,
    -- Distancia maxima para el click teleport.
    CLICKTP_RANGE = 1200,
    -- Altura por defecto del levitar.
    HOVER_DEFAULT = 12,
    -- Radio (en pixeles) dentro del cual el triggerbot dispara.
    TRIGGER_RADIUS = 12,
    -- Cada cuantos frames se refresca el ESP.
    ESP_INTERVAL = 1,
}
Core.CONST = CONST

--------------------------------------------------------------------------------
-- COMBAT
--------------------------------------------------------------------------------
local Combat = {}
Core.Combat = Combat

Combat.FOVCircle = nil
Combat.Chams = {}
Combat.LastTarget = nil
Combat.LastTargetTime = 0
Combat.Now = 0
Combat.TargetLine = nil
Combat.TriggerSince = nil

local function ensureFovCircle()
    if Combat.FOVCircle then return Combat.FOVCircle end
    local ok, circle = pcall(function()
        if not Drawing then return nil end
        local c = Drawing.new("Circle")
        c.Thickness = 1
        c.NumSides = 64
        c.Transparency = 0.7
        c.Filled = false
        c.Visible = false
        return c
    end)
    if ok then Combat.FOVCircle = circle end
    return Combat.FOVCircle
end
Core.ensureFovCircle = ensureFovCircle

-- Elige el objetivo dentro del FOV. La prioridad decide quien gana:
-- Mira (FOV) = mas cerca de la cruz, Distancia = mas cerca mio, Vida = mas debil.
local function pickTarget()
    local cam = Core.Camera()
    if not cam then return nil end
    local vs = Core.Viewport()
    local center = Vector2.new(vs.X / 2, vs.Y / 2)
    local fov = tonumber(Core.Flags["aimbot_fov"]) or 120
    local radius = (fov / 100) * math.min(vs.X, vs.Y) / 2
    local requireVisible = Core.Flags["aimbot_wallcheck"]
    local prio = Core.Flags["aimbot_priority"] or "Mira (FOV)"
    local maxRange = tonumber(Core.Flags["aimbot_range"]) or 0
    local best, bestScore = nil, math.huge
    for _, plr in ipairs(S.Players:GetPlayers()) do
        if not Core.Friendly(plr) and Core.IsAlive(plr) then
            local part = Core.TargetPart(plr)
            local ok = part ~= nil
            if ok and maxRange > 0 then
                ok = (part.Position - cam.CFrame.Position).Magnitude <= maxRange
            end
            if ok and requireVisible then
                local dd = Core.GetPlayer(plr)
                ok = Combat.Visible(cam.CFrame.Position, part.Position, { Core.Character(), dd and dd.Character })
            end
            if ok then
                local sp, on = Core.ScreenPoint(part.Position)
                if on and (sp - center).Magnitude <= radius then
                    local score = (sp - center).Magnitude
                    if prio == "Distancia" then
                        score = (part.Position - cam.CFrame.Position).Magnitude
                    elseif prio == "Vida" then
                        local d = Core.GetPlayer(plr)
                        score = d and d.Humanoid.Health or 100
                    end
                    if score < bestScore then
                        best, bestScore = plr, score
                    end
                end
            end
        end
    end
    return best, bestScore
end
Combat.PickTarget = pickTarget

-- Chequeo de visibilidad segun el metodo elegido en el menu.
function Combat.Visible(from, to, ignore)
    local metodo = Core.Flags["aimbot_vis_method"] or "Camara (exacto)"
    if metodo == "Raycast" then
        return Core.WallCheck(from, to)
    end
    return Core.VisibleToCamera(to, ignore)
end

-- El objetivo actual sigue siendo valido? (vivo, visible y dentro del FOV con margen)
function Combat.StillValid(plr)
    if not plr or not Core.IsAlive(plr) or Core.Friendly(plr) then return false end
    local cam = Core.Camera()
    local part = Core.TargetPart(plr)
    if not cam or not part then return false end
    if Core.Flags["aimbot_wallcheck"] then
        local dd = Core.GetPlayer(plr)
        if not Combat.Visible(cam.CFrame.Position, part.Position, { Core.Character(), dd and dd.Character }) then return false end
    end
    local sp, on = Core.ScreenPoint(part.Position)
    if not on then return false end
    local vs = Core.Viewport()
    local center = Vector2.new(vs.X / 2, vs.Y / 2)
    local fov = tonumber(Core.Flags["aimbot_fov"]) or 120
    local radius = (fov / 100) * math.min(vs.X, vs.Y) / 2
    return (sp - center).Magnitude <= radius * 1.35
end

local function aimAt(plr, dt)
    local cam = Core.Camera()
    local part = Core.TargetPart(plr)
    if not cam or not part then return end

    local target = part.Position
    -- Prediccion: velocidad del enemigo + ping de la conexion.
    if Core.Flags["aimbot_prediction"] then
        local vel = part.AssemblyLinearVelocity or Vector3.new(0, 0, 0)
        local dist = (target - cam.CFrame.Position).Magnitude
        local ping = 0
        pcall(function()
            ping = tonumber(S.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) or 0
        end)
        target = target + vel * (dist / 900 + ping / 2000)
    end

    local metodo = Core.Flags["aimbot_method"] or "Camara suave"
    if metodo == "Mouse" then
        local sp, on = Core.ScreenPoint(target)
        if on then
            local vs = Core.Viewport()
            local dx = sp.X - vs.X / 2
            local dy = sp.Y - vs.Y / 2
            local suave = tonumber(Core.Flags["aimbot_smooth"]) or 4
            local factor = 1 / math.max(suave, 1)
            pcall(function()
                if type(mousemoverel) == "function" then
                    mousemoverel(dx * factor, dy * factor)
                end
            end)
        end
        return
    end

    local suave = tonumber(Core.Flags["aimbot_smooth"]) or 4
    local alpha = 0.02
    if metodo == "Camara instantanea" then
        alpha = 1
    else
        alpha = math.clamp(dt * (20 / math.max(suave, 1)), 0.02, 1)
    end
    local current = cam.CFrame
    local deseado = CFrame.lookAt(current.Position, target)
    local nuevo = current:Lerp(deseado, alpha)
    -- Jitter humanizado: micro-temblor aleatorio para que no se sienta robotico.
    if Core.Flags["aimbot_jitter"] then
        local amt = (tonumber(Core.Flags["aimbot_jitter_amount"]) or 30) / 100
        local ax = (math.random() - 0.5) * 2 * amt * 0.02
        local ay = (math.random() - 0.5) * 2 * amt * 0.02
        pcall(function() nuevo = nuevo * CFrame.Angles(ay, ax, 0) end)
    end
    pcall(function() cam.CFrame = nuevo end)
end
Combat.AimAt = aimAt

-- Silent aim: redirige el disparo moviendo el mouse (el juego cree que apuntas
-- a donde dispara). Se aplica solo el frame en que se dispara.
local function silentAim(plr)
    local cam = Core.Camera()
    local part = Core.TargetPart(plr)
    if not cam or not part then return end
    local sp, on = Core.ScreenPoint(part.Position)
    if not on then return end
    local vs = Core.Viewport()
    local dx = sp.X - vs.X / 2
    local dy = sp.Y - vs.Y / 2
    pcall(function()
        if type(mousemoverel) == "function" then
            mousemoverel(dx, dy)
            mousemoverel(-dx, -dy)
        end
    end)
    task.spawn(function()
        pcall(function() CamSilentPulse(cam, part) end)
    end)
end
Combat.SilentAim = silentAim

function CamSilentPulse(cam, part)
    local original = cam.CFrame
    local ok = pcall(function() cam.CFrame = CFrame.lookAt(original.Position, part.Position) end)
    if ok then
        task.delay(0.03, function()
            pcall(function() cam.CFrame = original end)
        end)
    end
end

-- Linea de ayuda hacia el objetivo actual (dibujo, solo visual)
local function ensureTargetLine()
    if Combat.TargetLine then return Combat.TargetLine end
    local ok, l = pcall(function()
        if not Drawing then return nil end
        local o = Drawing.new("Line")
        o.Thickness = 1
        o.Transparency = 0.55
        o.Visible = false
        return o
    end)
    if ok then Combat.TargetLine = l end
    return Combat.TargetLine
end
Combat.EnsureTargetLine = ensureTargetLine

-- Triggerbot con retardo configurable (ms bajo la mira antes de disparar)
-- Hay un enemigo visible debajo de la mira dentro del radio dado?
function Combat.EnemyUnderCrosshair(radio)
    local cam = Core.Camera()
    if not cam then return false end
    local vs = Core.Viewport()
    local center = Vector2.new(vs.X / 2, vs.Y / 2)
    radio = radio or tonumber(Core.Flags["trigger_radius"]) or CONST.TRIGGER_RADIUS
    for _, plr in ipairs(S.Players:GetPlayers()) do
        if not Core.Friendly(plr) and Core.IsAlive(plr) then
            local d = Core.GetPlayer(plr)
            local part = Core.TargetPart(plr)
            if part then
                local visible = true
                if Core.Flags["aimbot_wallcheck"] then
                    visible = Combat.Visible(cam.CFrame.Position, part.Position, { Core.Character(), d and d.Character })
                end
                if visible then
                    local sp, on = Core.ScreenPoint(part.Position)
                    if on and (sp - center).Magnitude <= radio then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function triggerbot()
    local radio = tonumber(Core.Flags["trigger_radius"]) or CONST.TRIGGER_RADIUS
    local delay = (tonumber(Core.Flags["trigger_delay"]) or 0) / 1000
    local objetivo = Combat.EnemyUnderCrosshair(radio)
    if not objetivo then
        Combat.TriggerSince = nil
        return false
    end
    if not Combat.TriggerSince then Combat.TriggerSince = Combat.Now end
    if (Combat.Now - Combat.TriggerSince) >= delay then
        pcall(function()
            if type(mouse1click) == "function" then mouse1click() end
        end)
        Core.LastTriggerShot = Combat.Now
        return true
    end
    return false
end

local aimHolding = false
function Combat.Step(dt)
    Combat.Now = (Combat.Now or 0) + dt
    local aimOn = Core.Flags["aimbot_enabled"]
    local key = Core.Flags["aimbot_key"]
    local usarTecla = Core.Flags["aimbot_hold"]
    if key and usarTecla then
        local presionada = false
        pcall(function() presionada = S.UIS:IsKeyDown(key) end)
        aimOn = aimOn and presionada
    end

    local circle = ensureFovCircle()
    local cam = Core.Camera()
    if circle then
        local mostrar = Core.Flags["aimbot_show_fov"] and (aimOn or not usarTecla)
        pcall(function()
            circle.Visible = mostrar and true or false
            if mostrar then
                local vs = Core.Viewport()
                circle.Position = Vector2.new(vs.X / 2, vs.Y / 2)
                local fov = tonumber(Core.Flags["aimbot_fov"]) or 120
                circle.Radius = (fov / 100) * math.min(vs.X, vs.Y) / 2
                local hex = Core.Flags["aimbot_fov_color"] or "FF3D6E"
                circle.Color = Core.Hex(hex)
            end
        end)
    end

    -- Dibujo de la linea al objetivo
    local line = ensureTargetLine()
    if line then
        local mostrarLinea = false
        if Core.Flags["aimbot_target_line"] and aimOn and Combat.LastTarget and Combat.StillValid(Combat.LastTarget) then
            local part = Core.TargetPart(Combat.LastTarget)
            if part then
                local sp, on = Core.ScreenPoint(part.Position)
                if on then
                    local vs = Core.Viewport()
                    mostrarLinea = true
                    pcall(function()
                        line.From = Vector2.new(vs.X / 2, vs.Y / 2)
                        line.To = sp
                        line.Color = Core.Hex(Core.Flags["aimbot_fov_color"] or "FF3D6E")
                        line.Thickness = 1
                        line.Transparency = 0.55
                    end)
                end
            end
        end
        pcall(function() line.Visible = mostrarLinea end)
    end

    if aimOn and cam then
        local target = pickTarget()
        -- Mantener el objetivo: modo pegajoso y/o retardo de cambio
        if Combat.LastTarget and Combat.StillValid(Combat.LastTarget) then
            local sticky = Core.Flags["aimbot_sticky"]
            local switchDelay = tonumber(Core.Flags["aimbot_switch_delay"]) or 0
            local puedeCambiar = true
            if switchDelay > 0 and Combat.LastTargetTime
                and (Combat.Now - Combat.LastTargetTime) < (switchDelay / 1000) then
                puedeCambiar = false
            elseif sticky and switchDelay <= 0 then
                puedeCambiar = false
            end
            if not puedeCambiar and target ~= Combat.LastTarget then
                target = Combat.LastTarget
            end
        end
        if target then
            if target ~= Combat.LastTarget then
                Combat.LastTargetTime = Combat.Now
            end
            Combat.LastTarget = target
            aimAt(target, dt)
            if Core.Flags["aimbot_silent"] and Core.UIS_Shooting and Core.UIS_Shooting() then
                silentAim(target)
            end
        end
    elseif Combat.LastTarget then
        Combat.LastTarget = nil
    end

    if Core.Flags["triggerbot_enabled"] then
        triggerbot()
    end
end

function Combat.Reset()
    if Combat.FOVCircle then
        pcall(function() Combat.FOVCircle.Visible = false end)
    end
    if Combat.TargetLine then
        pcall(function() Combat.TargetLine.Visible = false end)
    end
    Combat.LastTarget = nil
    Combat.TriggerSince = nil
end

--------------------------------------------------------------------------------
-- ESP
--------------------------------------------------------------------------------
local ESP = {}
Core.ESP = ESP

local function drawObj(kind)
    local ok, o = pcall(function()
        if not Drawing then return nil end
        return Drawing.new(kind)
    end)
    if ok then return o end
    return nil
end

local pool = {}
local function getDraw(key, kind)
    if pool[key] and not pool[key].Destroyed then return pool[key] end
    local o = drawObj(kind)
    if o then pool[key] = o end
    return o
end

local BONES_R15 = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "UpperTorso", "RightUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LowerTorso", "RightUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
}
local BONES_R6 = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}
ESP.BONES = BONES_R15
ESP.BONES_R6 = BONES_R6

local function applyChams(plr, enabled, hexFill, hexOutline, opacidad, fade)
    local d = Core.GetPlayer(plr)
    if not d then return end
    local existing = Combat.Chams[plr]
    if enabled then
        if not existing and d.Character then
            local ok, h = pcall(function()
                local n = Instance.new("Highlight")
                n.Name = "StirlaxChams"
                n.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                n.Parent = d.Character
                return n
            end)
            if ok and h then
                Combat.Chams[plr] = h
                existing = h
            end
        end
        if existing then
            pcall(function()
                existing.Adornee = d.Character
                existing.FillColor = Core.Hex(hexFill or "FF3D6E")
                existing.OutlineColor = Core.Hex(hexOutline or "FFFFFF")
                fade = tonumber(fade) or 1
                existing.FillTransparency = math.clamp(1 - (tonumber(opacidad) or 40) / 100 * fade, 0, 1)
                existing.OutlineTransparency = 0
                existing.Enabled = true
            end)
        end
    elseif existing then
        pcall(function() existing:Destroy() end)
        Combat.Chams[plr] = nil
    end
end

local frameCounter = 0
function ESP.Step(dt)
    dt = tonumber(dt) or 0
    frameCounter = frameCounter + 1
    local activo = Core.Flags["esp_enabled"]
    local cam = Core.Camera()
    if not cam then return end
    if not activo then
        for _, o in pairs(pool) do
            if o and o.Visible then pcall(function() o.Visible = false end) end
        end
        for plr in pairs(Combat.Chams) do
            applyChams(plr, false)
        end
        return
    end
    if frameCounter % math.max(CONST.ESP_INTERVAL, 1) ~= 0 then return end

    -- Rainbow: cajas y lineas comparten un tono que gira con el tiempo.
    local speed = tonumber(Core.Flags["esp_rainbow_speed"]) or 6
    ESP.Hue = ((ESP.Hue or 0) + dt * speed / 20) % 1
    local colorArcoiris = nil
    if Core.Flags["esp_rainbow"] then colorArcoiris = Color3.fromHSV(ESP.Hue, 0.85, 1) end

    local vs = Core.Viewport()
    local maxDist = tonumber(Core.Flags["esp_distance"]) or 500
    local estilo = Core.Flags["esp_box_style"] or "Contorno"
    local grosor = tonumber(Core.Flags["esp_box_thickness"]) or 1
    local largoEsq = (tonumber(Core.Flags["esp_corner_size"]) or 22) / 100
    local dinamico = Core.Flags["esp_health_dynamic"] ~= false
    local origen = Core.Flags["esp_line_origin"] or "Abajo"
    local usarFade = Core.Flags["esp_fade"]
    local usarGlow = Core.Flags["esp_glow"]
    local soloVisibles = Core.Flags["esp_visible_check"]
    local desde
    if origen == "Centro" then
        desde = Vector2.new(vs.X / 2, vs.Y / 2)
    elseif origen == "Arriba" then
        desde = Vector2.new(vs.X / 2, 0)
    elseif origen == "Mouse" then
        pcall(function() desde = S.UIS:GetMouseLocation() end)
        desde = desde or Vector2.new(vs.X / 2, vs.Y)
    else
        desde = Vector2.new(vs.X / 2, vs.Y)
    end
    local contorno = (estilo == "Contorno" or estilo == "Ambas")
    local esquinas = (estilo == "Esquinas" or estilo == "Ambas")
    local colorCaja = colorArcoiris or Core.Hex(Core.Flags["esp_box_color"] or "FFFFFF")
    local colorLinea = colorArcoiris or Core.Hex(Core.Flags["esp_line_color"] or "7C5CFF")
    local dibujados = {}
    for _, plr in ipairs(S.Players:GetPlayers()) do
        local d = Core.GetPlayer(plr)
        local mostrar = false
        local dist = 0
        if d and d.Humanoid.Health > 0 and plr ~= S.Players.LocalPlayer then
            if not Core.Friendly(plr) then
                dist = Core.Root() and (d.Root.Position - Core.Root().Position).Magnitude or 0
                if dist <= maxDist then mostrar = true end
                if mostrar and soloVisibles then
                    mostrar = Core.VisibleToCamera(d.Root.Position, { Core.Character(), d.Character })
                end
            end
        end
        if mostrar then
            local root = d.Root.Position
            local head = (d.Head and d.Head.Position or (root + Vector3.new(0, 2, 0)))
            local top = Core.ScreenPoint(head + Vector3.new(0, 0.8, 0))
            local bottom = Core.ScreenPoint(root - Vector3.new(0, 2.6, 0))
            local sp, on = Core.ScreenPoint(root)
            local alto = math.abs(bottom.Y - top.Y)
            local ancho = alto * 0.55
            -- Fade por distancia: cerca = solido, lejos = sutil.
            local fade = 1
            if usarFade then
                fade = 1 - math.clamp(dist / math.max(maxDist, 1), 0, 1) * 0.8
            end
            local function alpha(base)
                return math.clamp(fade * base, 0, 1)
            end

            if on or (Core.Flags["esp_offscreen"] and not on) then
                dibujados[#dibujados + 1] = plr

                -- Glow neon: dos halos mas grandes detras de la caja.
                for gi = 1, 2 do
                    local halo = getDraw("glow" .. gi .. "_" .. plr.Name, "Square")
                    if halo then
                        pcall(function()
                            halo.Visible = (usarGlow and on) and true or false
                            if halo.Visible then
                                local pad = (gi == 1) and 4 or 9
                                halo.Position = Vector2.new(top.X - ancho / 2 - pad, top.Y - pad)
                                halo.Size = Vector2.new(ancho + pad * 2, alto + pad * 2)
                                halo.Filled = true
                                halo.Color = colorCaja
                                halo.Transparency = 1 - alpha((gi == 1) and 0.22 or 0.1)
                            end
                        end)
                    end
                end

                -- Caja: contorno, esquinas o ambas
                local box = getDraw("box_" .. plr.Name, "Square")
                if box then
                    pcall(function()
                        box.Visible = (Core.Flags["esp_box"] and contorno and on) and true or false
                        box.Position = Vector2.new(top.X - ancho / 2, top.Y)
                        box.Size = Vector2.new(ancho, alto)
                        box.Color = colorCaja
                        box.Thickness = grosor
                        box.Filled = Core.Flags["esp_fill"] and true or false
                        if box.Filled then
                            box.Transparency = 1 - alpha(0.4)
                        else
                            box.Transparency = 1 - alpha(1)
                        end
                    end)
                end
                if Core.Flags["esp_box"] and esquinas and on then
                    local lx = ancho * largoEsq
                    local ly = alto * largoEsq
                    local esquinaDefs = {
                        { top.X - ancho / 2, top.Y, 1, 1 },
                        { top.X + ancho / 2, top.Y, -1, 1 },
                        { top.X - ancho / 2, bottom.Y, 1, -1 },
                        { top.X + ancho / 2, bottom.Y, -1, -1 },
                    }
                    for i, cdef in ipairs(esquinaDefs) do
                        local h = getDraw("boxh_" .. plr.Name .. "_" .. i, "Line")
                        if h then
                            pcall(function()
                                h.Visible = true
                                h.From = Vector2.new(cdef[1], cdef[2])
                                h.To = Vector2.new(cdef[1] + cdef[3] * lx, cdef[2])
                                h.Color = colorCaja
                                h.Thickness = grosor
                                h.Transparency = 1 - alpha(1)
                            end)
                        end
                        local v = getDraw("boxv_" .. plr.Name .. "_" .. i, "Line")
                        if v then
                            pcall(function()
                                v.Visible = true
                                v.From = Vector2.new(cdef[1], cdef[2])
                                v.To = Vector2.new(cdef[1], cdef[2] + cdef[4] * ly)
                                v.Color = colorCaja
                                v.Thickness = grosor
                                v.Transparency = 1 - alpha(1)
                            end)
                        end
                    end
                else
                    for i = 1, 4 do
                        local h = pool["boxh_" .. plr.Name .. "_" .. i]
                        local v = pool["boxv_" .. plr.Name .. "_" .. i]
                        if h then pcall(function() h.Visible = false end) end
                        if v then pcall(function() v.Visible = false end) end
                    end
                end
                -- Lineas de trazado
                local line = getDraw("line_" .. plr.Name, "Line")
                if line then
                    pcall(function()
                        line.Visible = (Core.Flags["esp_lines"] and on) and true or false
                        line.From = desde
                        line.To = Vector2.new(sp.X, bottom.Y)
                        line.Color = colorLinea
                        line.Thickness = 1
                        line.Transparency = 1 - alpha(0.5)
                    end)
                end
                -- Nombre
                local name = getDraw("name_" .. plr.Name, "Text")
                if name then
                    pcall(function()
                        name.Visible = (Core.Flags["esp_name"] and on) and true or false
                        name.Text = plr.Name
                        name.Position = Vector2.new(top.X, top.Y - 16)
                        name.Center = true
                        name.Outline = true
                        name.Size = 14
                        name.Color = Core.Hex(Core.Flags["esp_name_color"] or "FFFFFF")
                        name.Transparency = 1 - alpha(0.95)
                    end)
                end
                -- Vida: barra con color dinamico o fijo, y numero opcional
                local pct = math.clamp(d.Humanoid.Health / math.max(d.Humanoid.MaxHealth, 1), 0, 1)
                local hp = getDraw("hp_" .. plr.Name, "Square")
                if hp then
                    pcall(function()
                        local hh = alto * pct
                        hp.Visible = (Core.Flags["esp_health"] and on) and true or false
                        hp.Position = Vector2.new(top.X - ancho / 2 - 5, bottom.Y - hh)
                        hp.Size = Vector2.new(2, hh)
                        hp.Filled = true
                        hp.Transparency = 1 - alpha(1)
                        if dinamico then
                            hp.Color = Color3.fromHSV(0.33 * pct, 0.78, 0.98)
                        else
                            hp.Color = Core.Hex(Core.Flags["esp_health_color"] or "FF4D6D")
                        end
                    end)
                end
                local hpt = getDraw("hpt_" .. plr.Name, "Text")
                if hpt then
                    pcall(function()
                        hpt.Visible = (Core.Flags["esp_health_text"] and Core.Flags["esp_health"] and on) and true or false
                        hpt.Text = tostring(math.floor(d.Humanoid.Health + 0.5))
                        hpt.Position = Vector2.new(top.X - ancho / 2 - 16, bottom.Y - alto * pct - 6)
                        hpt.Center = true
                        hpt.Outline = true
                        hpt.Size = 11
                        hpt.Color = Core.Hex("FFFFFF")
                        hpt.Transparency = 1 - alpha(0.9)
                    end)
                end
                -- Distancia
                local distTxt = getDraw("dist_" .. plr.Name, "Text")
                if distTxt then
                    pcall(function()
                        distTxt.Visible = (Core.Flags["esp_distance_text"] and on) and true or false
                        distTxt.Text = string.format("%d m", (d.Root.Position - Core.Camera().CFrame.Position).Magnitude)
                        distTxt.Position = Vector2.new(top.X, bottom.Y + 2)
                        distTxt.Center = true
                        distTxt.Outline = true
                        distTxt.Size = 12
                        distTxt.Color = Core.Hex(Core.Flags["esp_dist_color"] or "C9CCDD")
                        distTxt.Transparency = 1 - alpha(0.8)
                    end)
                end
                -- Esqueleto: R15 si hay UpperTorso, si no R6
                local bones = nil
                if Core.Flags["esp_skeleton"] and on and d.Character then
                    bones = d.Character:FindFirstChild("UpperTorso") and BONES_R15 or BONES_R6
                end
                if bones then
                    for i, par in ipairs(bones) do
                        local ln = getDraw("skel_" .. plr.Name .. "_" .. i, "Line")
                        if ln then
                            local p1 = d.Character:FindFirstChild(par[1])
                            local p2 = d.Character:FindFirstChild(par[2])
                            if p1 and p2 then
                                local s1 = Core.ScreenPoint(p1.Position)
                                local s2 = Core.ScreenPoint(p2.Position)
                                pcall(function()
                                    ln.Visible = true
                                    ln.From = s1
                                    ln.To = s2
                                    ln.Color = Core.Hex(Core.Flags["esp_skel_color"] or "2BD98A")
                                    ln.Thickness = 1
                                    ln.Transparency = 1 - alpha(0.55)
                                end)
                            else
                                pcall(function() ln.Visible = false end)
                            end
                        end
                    end
                    for i = #bones + 1, 12 do
                        local ln = pool["skel_" .. plr.Name .. "_" .. i]
                        if ln then pcall(function() ln.Visible = false end) end
                    end
                else
                    for i = 1, 12 do
                        local ln = pool["skel_" .. plr.Name .. "_" .. i]
                        if ln then pcall(function() ln.Visible = false end) end
                    end
                end
                -- Chams
                applyChams(plr, Core.Flags["esp_chams"],
                    colorArcoiris or Core.Flags["esp_chams_color"],
                    Core.Flags["esp_chams_outline_color"], Core.Flags["esp_chams_opacity"], fade)
            end
        end
    end

    -- Apagar lo que sobra
    for k, o in pairs(pool) do
        local usado = false
        for _, plr in ipairs(dibujados) do
            if k:find(plr.Name, 1, true) then usado = true break end
        end
        if not usado and o and o.Visible then pcall(function() o.Visible = false end) end
    end
end

function ESP.Reset()
    for _, o in pairs(pool) do
        pcall(function() o.Visible = false end)
    end
    for plr in pairs(Combat.Chams) do
        applyChams(plr, false)
    end
end
--------------------------------------------------------------------------------
-- MOVEMENT
--------------------------------------------------------------------------------
local Movement = {}
Core.Movement = Movement

local function keyDown(key)
    local down = false
    pcall(function() down = S.UIS:IsKeyDown(key) end)
    return down
end

local flyVel = Vector3.new(0, 0, 0)
local hoverY = nil

-- Camara libre: WASD para volar, mouse para mirar, Space/Shift para subir y bajar.
local freecam = { activa = false, cf = nil, cfGuardado = nil, tipoGuardado = nil, yaw = 0, pitch = 0 }

local function freecamLook()
    local cy, sy = math.cos(freecam.yaw), math.sin(freecam.yaw)
    local cp, sp = math.cos(freecam.pitch), math.sin(freecam.pitch)
    return Vector3.new(-sy * cp, sp, -cy * cp)
end

local function freecamStep(dt, cam)
    if not cam then return end
    local activa = Core.Flags["freecam_enabled"]
    if activa and not freecam.activa then
        freecam.activa = true
        freecam.cf = cam.CFrame
        freecam.cfGuardado = cam.CFrame
        freecam.tipoGuardado = cam.CameraType
        local look = cam.CFrame.LookVector
        freecam.yaw = math.atan(-look.X, -look.Z)
        freecam.pitch = math.asin(math.clamp(look.Y, -1, 1))
        pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
    elseif not activa and freecam.activa then
        freecam.activa = false
        pcall(function()
            cam.CameraType = freecam.tipoGuardado or Enum.CameraType.Custom
            if freecam.cfGuardado then cam.CFrame = freecam.cfGuardado end
        end)
        return
    end
    if not freecam.activa or not freecam.cf then return end
    local speed = (tonumber(Core.Flags["freecam_speed"]) or 50) * 0.7
    local dir = freecamLook()
    local lateral = Vector3.new(dir.Z, 0, -dir.X)
    local move = Vector3.new(0, 0, 0)
    if keyDown(Enum.KeyCode.W) then move = move + dir end
    if keyDown(Enum.KeyCode.S) then move = move - dir end
    if keyDown(Enum.KeyCode.D) then move = move + lateral end
    if keyDown(Enum.KeyCode.A) then move = move - lateral end
    if keyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
    if keyDown(Enum.KeyCode.LeftShift) or keyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
    local pos = freecam.cf.Position
    if move.Magnitude > 0 then
        pos = pos + move.Unit * speed * dt
    end
    freecam.cf = CFrame.lookAt(pos, pos + dir)
    pcall(function() cam.CFrame = freecam.cf end)
end
Movement.FreeCam = freecam

local fcMouseConn = nil
function Movement.InstallFreeCam()
    if fcMouseConn then return end
    fcMouseConn = Core.Connect(S.UIS.InputChanged, function(input)
        if not Core.Flags["freecam_enabled"] or not freecam.activa then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement and input.Delta then
            freecam.yaw = freecam.yaw - (input.Delta.X or 0) * 0.004
            freecam.pitch = math.clamp(freecam.pitch - (input.Delta.Y or 0) * 0.004, -1.5, 1.5)
        end
    end)
end

local function humanParts()
    local char = Core.Character()
    if not char then return {} end
    local out = {}
    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") then out[#out + 1] = p end
    end
    return out
end

function Movement.Step(dt)
    local cam = Core.Camera()
    -- La camara libre funciona aunque no haya personaje.
    freecamStep(dt, cam)

    local hum = Core.Humanoid()
    local root = Core.Root()
    if not hum or not root then
        hoverY = nil
        return
    end

    -- Velocidad (el modo sigiloso la capa para no disparar anti-cheats)
    if Core.Flags["speed_enabled"] then
        local vel = tonumber(Core.Flags["speed_value"]) or 16
        if Core.Flags["stealth_mode"] ~= false and vel > SEG.STEALTH_CAP then
            if not Protection.SpeedClampWarned then
                Protection.SpeedClampWarned = true
                Core.Notify("Modo sigiloso: velocidad limitada a " .. SEG.STEALTH_CAP, "Sigilo")
            end
            vel = SEG.STEALTH_CAP
        end
        pcall(function() hum.WalkSpeed = vel end)
    else
        pcall(function()
            if hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
        end)
    end

    -- Salto alto
    if Core.Flags["jump_enabled"] then
        local jp = tonumber(Core.Flags["jump_value"]) or 50
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = jp
        end)
    end

    -- Fly
    if Core.Flags["fly_enabled"] and cam then
        local speed = tonumber(Core.Flags["fly_speed"]) or 60
        local dir = Vector3.new(0, 0, 0)
        if keyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if keyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if keyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if keyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if keyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if keyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then
            flyVel = dir.Unit * speed
        end
        pcall(function()
            hum.PlatformStand = false
            root.AssemblyLinearVelocity = flyVel
            root.CFrame = root.CFrame
        end)
        -- Sin input, frena de a poco para quedar flotando.
        if dir.Magnitude == 0 then
            flyVel = flyVel * 0.85
        end
    else
        flyVel = Vector3.new(0, 0, 0)
    end

    -- Levitar: mantiene la altura en la que lo activaste.
    if Core.Flags["hover_enabled"] then
        if not hoverY then hoverY = root.Position.Y end
        local altura = tonumber(Core.Flags["hover_height"]) or CONST.HOVER_DEFAULT
        local objetivo = hoverY + 0
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, (objetivo - root.Position.Y) * altura, root.AssemblyLinearVelocity.Z)
        end)
    else
        hoverY = nil
    end

    -- Noclip
    if Core.Flags["noclip_enabled"] then
        for _, p in ipairs(humanParts()) do
            pcall(function() p.CanCollide = false end)
        end
    end

    -- Anti-void: rescate vertical en tu misma posicion (no te manda al origen
    -- del mapa, que era un teletransporte regalado para los anti-cheats)
    if Core.Flags["antivoid_enabled"] then
        if root.Position.Y < CONST.VOID_Y then
            pcall(function()
                root.CFrame = CFrame.new(root.Position + Vector3.new(0, CONST.VOID_RESCUE_ALTO, 0))
            end)
            Core.Notify("Rescatado del void", "Anti-Void")
        end
    end

    -- Bunny hop
    if Core.Flags["bhop_enabled"] then
        local ok, estado = pcall(function() return hum:GetState() end)
        if ok and estado == Enum.HumanoidStateType.Landed and keyDown(Enum.KeyCode.Space) then
            pcall(function() hum.Jump = true end)
        end
    end
end

-- Teleport suave: en modo sigiloso el movimiento se hace en pasos cortos en
-- vez de un salto unico, para no disparar los chequeos de distancia.
function Movement.TeleportSuave(destino)
    local root = Core.Root()
    if not root then return end
    if Core.Flags["stealth_mode"] == false then
        pcall(function() root.CFrame = CFrame.new(destino) end)
        return
    end
    task.spawn(function()
        local desde = root.Position
        for i = 1, 6 do
            local t = i / 6
            local punto = Vector3.new(
                desde.X + (destino.X - desde.X) * t,
                desde.Y + (destino.Y - desde.Y) * t,
                desde.Z + (destino.Z - desde.Z) * t)
            pcall(function() root.CFrame = CFrame.new(punto) end)
            task.wait(0.03)
        end
    end)
end

function Movement.ClickTP()
    local cam = Core.Camera()
    local root = Core.Root()
    if not cam or not root then return end
    local params
    pcall(function()
        params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local char = Core.Character()
        if char then params.FilterDescendantsInstances = { char } end
    end)
    local destino = cam.CFrame.Position + cam.CFrame.LookVector * CONST.CLICKTP_RANGE
    local ok, res = pcall(function() return S.Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * CONST.CLICKTP_RANGE, params) end)
    if ok and res then destino = res.Position + Vector3.new(0, 3, 0) end
    Movement.TeleportSuave(destino)
end

function Movement.TeleportTo(plr)
    local d = Core.GetPlayer(plr)
    local root = Core.Root()
    if not d or not root then return end
    Movement.TeleportSuave(d.Root.Position + Vector3.new(0, 3, 0))
    Core.Notify("Teleport a " .. plr.Name, "Movement")
end

function Movement.TeleportNearest()
    local mejor, mejorD = nil, math.huge
    for _, plr in ipairs(S.Players:GetPlayers()) do
        if plr ~= S.Players.LocalPlayer and Core.IsAlive(plr) then
            local d = Core.Distance(plr)
            if d < mejorD then mejor, mejorD = plr, d end
        end
    end
    if mejor then Movement.TeleportTo(mejor) end
end

function Movement.Reset()
    flyVel = Vector3.new(0, 0, 0)
    hoverY = nil
    if freecam.activa then
        local cam = Core.Camera()
        freecam.activa = false
        pcall(function()
            if cam then
                cam.CameraType = freecam.tipoGuardado or Enum.CameraType.Custom
                if freecam.cfGuardado then cam.CFrame = freecam.cfGuardado end
            end
        end)
    end
end

-- Salto infinito: se conecta una sola vez.
local infJumpConn = nil
function Movement.InstallInfJump()
    if infJumpConn then return end
    infJumpConn = Core.Connect(S.UIS.JumpRequest, function()
        if not Core.Flags["infjump_enabled"] then return end
        pcall(function()
            local hum = Core.Humanoid()
            if hum then hum.Jump = true end
        end)
    end)
end

--------------------------------------------------------------------------------
-- MISC / WORLD
--------------------------------------------------------------------------------
local Misc = {}
Core.Misc = Misc

local estadoOriginal = nil
local function guardarEstado()
    if estadoOriginal then return end
    estadoOriginal = {}
    pcall(function()
        estadoOriginal.Brightness = S.Lighting.Brightness
        estadoOriginal.ClockTime = S.Lighting.ClockTime
        estadoOriginal.FogEnd = S.Lighting.FogEnd
        estadoOriginal.Ambient = S.Lighting.Ambient
        estadoOriginal.GlobalShadows = S.Lighting.GlobalShadows
    end)
end

local function aplicarLuz()
    guardarEstado()
    local full = Core.Flags["fullbright_enabled"]
    pcall(function()
        if full then
            S.Lighting.Brightness = 2
            S.Lighting.ClockTime = 14
            S.Lighting.Ambient = Color3.fromRGB(200, 200, 200)
            S.Lighting.GlobalShadows = false
        else
            if estadoOriginal then
                S.Lighting.Brightness = estadoOriginal.Brightness
                S.Lighting.ClockTime = estadoOriginal.ClockTime
                S.Lighting.Ambient = estadoOriginal.Ambient
                S.Lighting.GlobalShadows = estadoOriginal.GlobalShadows
            end
        end
        if Core.Flags["nofog_enabled"] then
            S.Lighting.FogEnd = 1e6
            S.Lighting.FogStart = 1e6
        elseif estadoOriginal then
            S.Lighting.FogEnd = estadoOriginal.FogEnd
        end
        if S.Lighting.TimeOfDay ~= nil and full then
            S.Lighting.TimeOfDay = "14:00:00"
        end
    end)
end

function Misc.Step(dt)
    if Core.Flags["fullbright_enabled"] or Core.Flags["nofog_enabled"] then
        aplicarLuz()
    end
    if Core.Flags["fov_camera"] then
        local cam = Core.Camera()
        if cam then pcall(function() cam.FieldOfView = tonumber(Core.Flags["fov_value"]) or 70 end) end
    end
end

function Misc.Reset()
    Core.Flags["fullbright_enabled"] = false
    Core.Flags["nofog_enabled"] = false
    aplicarLuz()
end

-- Guardar / cargar configuracion con el filesystem del executor (si existe).
function Misc.SaveConfig(archivo)
    archivo = archivo or "stirlaxmodz_config.lua"
    local ok, err = pcall(function()
        if type(writefile) ~= "function" then error("el executor no tiene writefile") end
        local t = {}
        for k, v in pairs(Core.Flags) do
            if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
                t[#t + 1] = "[" .. string.format("%q", k) .. "]=" .. (type(v) == "string" and string.format("%q", v) or tostring(v))
            end
        end
        writefile(archivo, "return {\n" .. table.concat(t, ",\n") .. "\n}")
    end)
    if ok then
        Core.Notify("Config guardada", "STIRLAX MODZ")
    else
        Core.Notify("No se pudo guardar: " .. tostring(err), "STIRLAX MODZ")
    end
    return ok
end

function Misc.LoadConfig(archivo, silencioso)
    archivo = archivo or "stirlaxmodz_config.lua"
    local ok, err = pcall(function()
        if type(isfile) ~= "function" or not isfile(archivo) then error("sin archivo guardado") end
        local chunk = loadstring(readfile(archivo))
        local cfg = chunk()
        for k, v in pairs(cfg) do
            if UI.Controls[k] then
                UI.Set(k, v, true)
            else
                Core.Flags[k] = v
            end
        end
    end)
    if ok then
        if not silencioso then Core.Notify("Config cargada", "STIRLAX MODZ") end
    else
        if not silencioso then Core.Notify("No se pudo cargar: " .. tostring(err), "STIRLAX MODZ") end
    end
    return ok
end

-- Auto-config por juego: cada PlaceId tiene su propio archivo de ajustes.
function Misc.PlaceId()
    local ok, id = pcall(function() return game.PlaceId end)
    if ok and id then return tostring(id) end
    return "0"
end

function Misc.GameConfigPath()
    return "stirlaxmodz_game_" .. Misc.PlaceId() .. ".lua"
end

function Misc.SaveGameConfig()
    local ok = Misc.SaveConfig(Misc.GameConfigPath())
    if ok then
        Core.Notify("Ajustes guardados para el juego " .. Misc.PlaceId(), "Auto-config")
    end
    return ok
end

function Misc.LoadGameConfig(silencioso)
    return Misc.LoadConfig(Misc.GameConfigPath(), silencioso)
end

function Misc.AutoConfig()
    task.spawn(function()
        task.wait(2)
        if Core.Flags["autoconfig_cargar"] then
            pcall(function() Misc.LoadGameConfig(true) end)
        end
    end)
end

-- Acceso rapido: boton de panico que apaga todo.
function Misc.Panic()
    Combat.Reset()
    ESP.Reset()
    Movement.Reset()
    if Core.Overlay then Core.Overlay.Reset() end
    if Core.PlayerList then Core.PlayerList.Reset() end
    for flag, ctrl in pairs(UI.Controls) do
        if ctrl.Type == "Toggle" then
            UI.Set(flag, false, true)
        end
    end
    Core.Notify("Todo apagado", "Panic")
end
--------------------------------------------------------------------------------
-- PLAYERS (lista en vivo con teleport y especteador)
--------------------------------------------------------------------------------
local PlayerList = {}
Core.PlayerList = PlayerList

PlayerList.Rows = {}
PlayerList.Spectating = nil
PlayerList.Holder = nil
PlayerList.UltimaFirma = ""
PlayerList.DrawNow = 0

local function plrInfo(plr)
    local d = Core.GetPlayer(plr)
    if not d then return ".." end
    local dist = Core.Root() and (d.Root.Position - Core.Root().Position).Magnitude or 0
    return string.format("%d vida  %d m", math.floor(d.Humanoid.Health + 0.5), math.floor(dist + 0.5))
end

function PlayerList.Teleport(plr)
    local d = Core.GetPlayer(plr)
    local char = Core.Character()
    if not d or not char then return end
    pcall(function()
        Movement.TeleportSuave(d.Root.Position + Vector3.new(2.5, 0, 2.5))
    end)
    Core.Notify("Teleport a " .. plr.Name, "STIRLAX MODZ")
end

function PlayerList.RefreshBotones()
    for _, r in ipairs(PlayerList.Rows) do
        pcall(function()
            local activo = (r.Player == PlayerList.Spectating)
            r.Ver.BackgroundColor3 = activo and T.accent or T.bg2
            r.Ver.BackgroundTransparency = activo and 0 or 0.2
            r.Ver.TextColor3 = activo and Core.Hex("0B0B12") or T.text
        end)
    end
end

function PlayerList.SetSpectate(plr)
    if PlayerList.Spectating == plr then
        PlayerList.Spectating = nil
        Core.Notify("Especteador apagado", "STIRLAX MODZ")
    else
        PlayerList.Spectating = plr
        Core.Notify("Especteando a " .. plr.Name, "STIRLAX MODZ")
    end
    PlayerList.RefreshBotones()
end

local function spectateStep()
    local plr = PlayerList.Spectating
    if not plr or not Core.IsAlive(plr) then return end
    local cam = Core.Camera()
    local d = Core.GetPlayer(plr)
    if not cam or not d then return end
    pcall(function()
        local head = d.Head or d.Root
        local base = d.Root.CFrame.LookVector
        cam.CFrame = CFrame.lookAt(head.Position - base * 6 + Vector3.new(0, 1.5, 0), head.Position)
    end)
end

local function hacerFila(plr)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = T.bg3,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
    }, PlayerList.Holder)
    if not f then return nil end
    UI.corner(f, 8)
    UI.glass(f, 0.5)
    local nombre = new("TextLabel", {
        Text = plr.Name,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Core.Friendly(plr) and T.good or T.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 104, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
    }, f)
    local info = new("TextLabel", {
        Text = plrInfo(plr),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = T.sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 104, 1, 0),
        Position = UDim2.new(0, 114, 0, 0),
    }, f)
    local tp = new("TextButton", {
        Text = "TP",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = T.text,
        BackgroundColor3 = T.bg2,
        BackgroundTransparency = 0.2,
        Size = UDim2.new(0, 34, 0, 22),
        Position = UDim2.new(1, -80, 0.5, -11),
        AutoButtonColor = false,
    }, f)
    UI.corner(tp, 6)
    local ver = new("TextButton", {
        Text = "VER",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = T.text,
        BackgroundColor3 = T.bg2,
        BackgroundTransparency = 0.2,
        Size = UDim2.new(0, 38, 0, 22),
        Position = UDim2.new(1, -40, 0.5, -11),
        AutoButtonColor = false,
    }, f)
    UI.corner(ver, 6)

    tp.MouseButton1Click:Connect(function() PlayerList.Teleport(plr) end)
    ver.MouseButton1Click:Connect(function() PlayerList.SetSpectate(plr) end)

    return { Frame = f, Nombre = nombre, Info = info, TP = tp, Ver = ver, Player = plr }
end

function PlayerList.Rebuild()
    if not PlayerList.Holder then return end
    for _, r in ipairs(PlayerList.Rows) do
        pcall(function() UI.unglass(r.Frame) end)
        pcall(function() r.Frame:Destroy() end)
    end
    PlayerList.Rows = {}
    local lista = {}
    for _, plr in ipairs(S.Players:GetPlayers()) do
        if plr ~= S.Players.LocalPlayer then
            lista[#lista + 1] = plr
        end
    end
    table.sort(lista, function(a, b) return (Core.Distance(a) or 0) < (Core.Distance(b) or 0) end)
    for _, plr in ipairs(lista) do
        local fila = hacerFila(plr)
        if fila then PlayerList.Rows[#PlayerList.Rows + 1] = fila end
    end
    PlayerList.RefreshBotones()
end

function PlayerList.Mount(page)
    PlayerList.Holder = page
    PlayerList.UltimaFirma = ""
    PlayerList.Rebuild()
end

local function firma()
    local t = {}
    for _, plr in ipairs(S.Players:GetPlayers()) do
        t[#t + 1] = plr.Name
    end
    table.sort(t)
    return table.concat(t, ",")
end

function PlayerList.Step(dt)
    dt = tonumber(dt) or 0
    spectateStep()
    PlayerList.DrawNow = (PlayerList.DrawNow or 0) + dt
    if PlayerList.DrawNow < 0.4 then return end
    PlayerList.DrawNow = 0
    if not PlayerList.Holder then return end
    local f = firma()
    if f ~= PlayerList.UltimaFirma then
        PlayerList.UltimaFirma = f
        PlayerList.Rebuild()
        return
    end
    for _, r in ipairs(PlayerList.Rows) do
        pcall(function()
            r.Info.Text = plrInfo(r.Player)
            r.Nombre.TextColor3 = Core.Friendly(r.Player) and T.good or T.text
        end)
    end
end

function PlayerList.Reset()
    PlayerList.Spectating = nil
    PlayerList.RefreshBotones()
end

--------------------------------------------------------------------------------
-- OVERLAY (crosshair + hitmarker)
--------------------------------------------------------------------------------
local Overlay = {}
Core.Overlay = Overlay

Overlay.Pool = {}
Overlay.HitTime = nil
Overlay.WasShooting = false
Overlay.HitCooldown = 0

local function odraw(key, kind)
    local o = Overlay.Pool[key]
    if o then return o end
    local ok, d = pcall(function()
        if not Drawing then return nil end
        return Drawing.new(kind)
    end)
    if ok and d then
        rawset(d, "Visible", false)
        Overlay.Pool[key] = d
    end
    return Overlay.Pool[key]
end
Overlay.Draw = odraw

-- Marca un impacto: el dibujo se queda unos decimas y se desvanece.
function Overlay.Hit()
    local now = Combat.Now or 0
    if now - (Overlay.HitCooldown or 0) < 0.12 then return end
    Overlay.HitCooldown = now
    Overlay.HitTime = now
end

local function setCrosshair(visible, vs)
    local centro = Vector2.new(vs.X / 2, vs.Y / 2)
    local estilo = Core.Flags["crosshair_style"] or "Cruz"
    local size = tonumber(Core.Flags["crosshair_size"]) or 10
    local gap = tonumber(Core.Flags["crosshair_gap"]) or 4
    local grosor = tonumber(Core.Flags["crosshair_thickness"]) or 1
    local color = Core.Hex(Core.Flags["crosshair_color"] or "FF2E4D")
    local cruz = (estilo == "Cruz" or estilo == "Cruz + punto")
    local punto = (estilo == "Punto" or estilo == "Cruz + punto")
    local circulo = (estilo == "Circulo")
    local defs = {
        { "top",    0, -1 },
        { "bottom", 0,  1 },
        { "left",  -1,  0 },
        { "right",  1,  0 },
    }
    for _, d in ipairs(defs) do
        local ln = odraw("ch_" .. d[1], "Line")
        if ln then
            pcall(function()
                ln.Visible = visible and cruz and true or false
                if ln.Visible then
                    ln.From = Vector2.new(centro.X + d[2] * gap, centro.Y + d[3] * gap)
                    ln.To = Vector2.new(centro.X + d[2] * (gap + size), centro.Y + d[3] * (gap + size))
                    ln.Color = color
                    ln.Thickness = grosor
                    ln.Transparency = 0.05
                end
            end)
        end
    end
    local dot = odraw("ch_dot", "Circle")
    if dot then
        pcall(function()
            dot.Visible = visible and punto and true or false
            if dot.Visible then
                dot.Position = centro
                dot.Radius = 2
                dot.Filled = true
                dot.Color = color
                dot.Transparency = 0.05
            end
        end)
    end
    local circ = odraw("ch_circle", "Circle")
    if circ then
        pcall(function()
            circ.Visible = visible and circulo and true or false
            if circ.Visible then
                circ.Position = centro
                circ.Radius = size
                circ.Thickness = grosor
                circ.Filled = false
                circ.Color = color
                circ.Transparency = 0.15
            end
        end)
    end
end

local function setHitmarker(visible, vs, t)
    local size = tonumber(Core.Flags["hitmarker_size"]) or 10
    local color = Core.Hex(Core.Flags["hitmarker_color"] or "FFFFFF")
    local centro = Vector2.new(vs.X / 2, vs.Y / 2)
    local signs = {
        { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 },
    }
    local inner = size * (0.15 + 0.35 * t)
    local outer = size * (0.5 + 0.5 * t)
    for i, sg in ipairs(signs) do
        local ln = odraw("hit_" .. i, "Line")
        if ln then
            pcall(function()
                ln.Visible = visible and true or false
                if ln.Visible then
                    ln.From = Vector2.new(centro.X + sg[1] * inner, centro.Y + sg[2] * inner)
                    ln.To = Vector2.new(centro.X + sg[1] * outer, centro.Y + sg[2] * outer)
                    ln.Color = color
                    ln.Thickness = 2
                    ln.Transparency = math.clamp(t, 0, 1)
                end
            end)
        end
    end
end

function Overlay.Step(dt)
    dt = tonumber(dt) or 0
    local vs = Core.Viewport()
    setCrosshair(Core.Flags["crosshair_enabled"], vs)

    if Core.Flags["hitmarker_enabled"] then
        -- Disparo del jugador con un enemigo debajo de la mira.
        local shooting = Core.Shooting and true or false
        if shooting and not Overlay.WasShooting then
            if Combat.EnemyUnderCrosshair and Combat.EnemyUnderCrosshair(14) then
                Overlay.Hit()
            end
        end
        Overlay.WasShooting = shooting
        -- Disparo del triggerbot.
        if Core.LastTriggerShot and (Combat.Now - Core.LastTriggerShot) < 0.1 then
            Core.LastTriggerShot = nil
            Overlay.Hit()
        end
        local t = Overlay.HitTime and (Combat.Now - Overlay.HitTime)
        if t and t >= 0 and t < 0.35 then
            setHitmarker(true, vs, t / 0.35)
        else
            Overlay.HitTime = nil
            setHitmarker(false, vs, 1)
        end
    else
        setHitmarker(false, vs, 1)
    end
end

function Overlay.Reset()
    for _, o in pairs(Overlay.Pool) do
        pcall(function() o.Visible = false end)
    end
    Overlay.HitTime = nil
end

--------------------------------------------------------------------------------
-- 6. BUCLE PRINCIPAL
--------------------------------------------------------------------------------
local Loop = {}
Core.Loop = Loop
Loop.Errores = {}
Loop.Frames = 0

local modules = { Combat, ESP, Movement, Misc, Overlay, PlayerList, Protection }
Core.Modules = modules

function Loop.Start()
    local rs = S.RunService
    if not rs then return end
    Core.Connect(rs.RenderStepped, function(dt)
        Loop.Frames = Loop.Frames + 1
        for _, m in ipairs(modules) do
            local ok, err = pcall(m.Step, dt or 0)
            if not ok then
                local k = tostring(m) .. tostring(err)
                if not Loop.Errores[k] then
                    Loop.Errores[k] = 0
                    Core.log("modulo con error: " .. tostring(err))
                end
                Loop.Errores[k] = Loop.Errores[k] + 1
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- 7. ESTADO DE INPUT Y APERTURA DEL MENU
--------------------------------------------------------------------------------
Core.Shooting = false
Core.Connect(S.UIS.InputBegan, function(input)
    pcall(function()
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Core.Shooting = true
        end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local key = Core.Flags["menu_key"]
            if key and input.KeyCode == key then
                UI.SetOpen(not UI.Open)
            end
            if Core.Flags["clicktp_key"] and input.KeyCode == Core.Flags["clicktp_key"] then
                Movement.ClickTP()
            end
        end
    end)
end)
Core.Connect(S.UIS.InputEnded, function(input)
    pcall(function()
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Core.Shooting = false
        end
    end)
end)
Core.UIS_Shooting = function() return Core.Shooting end

--------------------------------------------------------------------------------
-- 8. CONSTRUCCION DEL MENU
--------------------------------------------------------------------------------
local function buildMenu()
    local win = UI.Window(Core.Brand)
    UI.BuildScreenDone = true

    ------------------------------------------------------------------ COMBAT
    local combatTab = win:Tab("Combat")
    UI.Section(combatTab.Page, "Aimbot")
    UI.Toggle(combatTab.Page, { Text = "Aimbot", Flag = "aimbot_enabled", Default = false,
        Callback = function(v) if v then Core.Notify("Aimbot activado", "Combat") end end })
    UI.Dropdown(combatTab.Page, { Text = "Metodo", Flag = "aimbot_method",
        Options = { "Camara suave", "Camara instantanea", "Mouse" }, Default = "Camara suave" })
    UI.Dropdown(combatTab.Page, { Text = "Prioridad", Flag = "aimbot_priority",
        Options = { "Mira (FOV)", "Distancia", "Vida" }, Default = "Mira (FOV)" })
    UI.Keybind(combatTab.Page, { Text = "Tecla de apuntado", Flag = "aimbot_key", Default = Enum.KeyCode.E })
    UI.Toggle(combatTab.Page, { Text = "Solo al mantener la tecla", Flag = "aimbot_hold", Default = true })
    UI.Slider(combatTab.Page, { Text = "FOV", Flag = "aimbot_fov", Min = 5, Max = 360, Default = 180, Decimals = 0, Suffix = " px" })
    UI.Slider(combatTab.Page, { Text = "Suavidad", Flag = "aimbot_smooth", Min = 1, Max = 20, Default = 3, Decimals = 0 })
    UI.Dropdown(combatTab.Page, { Text = "Zona", Flag = "aimbot_part", Options = { "Head", "Torso", "Nearest" }, Default = "Head" })
    UI.Toggle(combatTab.Page, { Text = "Ignorar companeros", Flag = "aimbot_teamcheck", Default = true })
    UI.Toggle(combatTab.Page, { Text = "Chequeo de pared", Flag = "aimbot_wallcheck", Default = true })
    UI.Dropdown(combatTab.Page, { Text = "Visibilidad", Flag = "aimbot_vis_method",
        Options = { "Camara (exacto)", "Raycast" }, Default = "Camara (exacto)" })
    UI.Toggle(combatTab.Page, { Text = "Prediccion de movimiento", Flag = "aimbot_prediction", Default = true })
    UI.Toggle(combatTab.Page, { Text = "Dibujar circulo FOV", Flag = "aimbot_show_fov", Default = true })
    UI.Toggle(combatTab.Page, { Text = "Silent aim", Flag = "aimbot_silent", Default = false })
    UI.Toggle(combatTab.Page, { Text = "Modo pegajoso", Flag = "aimbot_sticky", Default = false })
    UI.Slider(combatTab.Page, { Text = "Retardo de cambio", Flag = "aimbot_switch_delay", Min = 0, Max = 800, Default = 120, Decimals = 0, Suffix = " ms" })
    UI.Slider(combatTab.Page, { Text = "Alcance maximo", Flag = "aimbot_range", Min = 0, Max = 1500, Default = 0, Decimals = 0, Suffix = " m" })
    UI.Toggle(combatTab.Page, { Text = "Linea al objetivo", Flag = "aimbot_target_line", Default = false })
    UI.Toggle(combatTab.Page, { Text = "Pulso humanizado", Flag = "aimbot_jitter", Default = false })
    UI.Slider(combatTab.Page, { Text = "Fuerza del pulso", Flag = "aimbot_jitter_amount", Min = 5, Max = 100, Default = 30, Decimals = 0, Suffix = "%" })
    UI.Color(combatTab.Page, { Text = "Color del FOV", Flag = "aimbot_fov_color", Default = "FF2E4D" })

    UI.Section(combatTab.Page, "Triggerbot")
    UI.Toggle(combatTab.Page, { Text = "Triggerbot", Flag = "triggerbot_enabled", Default = false })
    UI.Slider(combatTab.Page, { Text = "Radio del gatillo", Flag = "trigger_radius", Min = 2, Max = 80, Default = 12, Decimals = 0 })
    UI.Slider(combatTab.Page, { Text = "Retardo de disparo", Flag = "trigger_delay", Min = 0, Max = 500, Default = 60, Decimals = 0, Suffix = " ms" })

    ------------------------------------------------------------------ VISUALS
    local visTab = win:Tab("Visuals")
    UI.Section(visTab.Page, "ESP")
    UI.Toggle(visTab.Page, { Text = "ESP", Flag = "esp_enabled", Default = false,
        Callback = function(v) Core.Notify(v and "ESP activado" or "ESP apagado", "Visuals") end })
    UI.Toggle(visTab.Page, { Text = "Caja", Flag = "esp_box", Default = true })
    UI.Dropdown(visTab.Page, { Text = "Estilo de caja", Flag = "esp_box_style",
        Options = { "Contorno", "Esquinas", "Ambas" }, Default = "Contorno" })
    UI.Slider(visTab.Page, { Text = "Grosor de caja", Flag = "esp_box_thickness", Min = 1, Max = 4, Default = 1, Decimals = 0 })
    UI.Slider(visTab.Page, { Text = "Largo de esquinas", Flag = "esp_corner_size", Min = 8, Max = 60, Default = 22, Decimals = 0, Suffix = "%" })
    UI.Toggle(visTab.Page, { Text = "Relleno de caja", Flag = "esp_fill", Default = false })
    UI.Toggle(visTab.Page, { Text = "Nombre", Flag = "esp_name", Default = true })
    UI.Toggle(visTab.Page, { Text = "Barra de vida", Flag = "esp_health", Default = true })
    UI.Toggle(visTab.Page, { Text = "Vida con color dinamico", Flag = "esp_health_dynamic", Default = true })
    UI.Toggle(visTab.Page, { Text = "Numero de vida", Flag = "esp_health_text", Default = false })
    UI.Toggle(visTab.Page, { Text = "Distancia", Flag = "esp_distance_text", Default = true })
    UI.Toggle(visTab.Page, { Text = "Esqueleto", Flag = "esp_skeleton", Default = false })
    UI.Toggle(visTab.Page, { Text = "Chams (Highlight)", Flag = "esp_chams", Default = false })
    UI.Slider(visTab.Page, { Text = "Opacidad de chams", Flag = "esp_chams_opacity", Min = 0, Max = 100, Default = 40, Decimals = 0, Suffix = "%" })
    UI.Toggle(visTab.Page, { Text = "Ignorar companeros", Flag = "esp_teamcheck", Default = true })
    UI.Slider(visTab.Page, { Text = "Distancia maxima", Flag = "esp_distance", Min = 50, Max = 2000, Default = 500, Decimals = 0, Suffix = " m" })
    UI.Section(visTab.Page, "Efectos")
    UI.Toggle(visTab.Page, { Text = "Rainbow animado", Flag = "esp_rainbow", Default = false })
    UI.Slider(visTab.Page, { Text = "Velocidad del rainbow", Flag = "esp_rainbow_speed", Min = 1, Max = 20, Default = 6, Decimals = 0 })
    UI.Toggle(visTab.Page, { Text = "Glow neon", Flag = "esp_glow", Default = false })
    UI.Toggle(visTab.Page, { Text = "Desvanecer por distancia", Flag = "esp_fade", Default = false })
    UI.Toggle(visTab.Page, { Text = "Solo visibles (camara)", Flag = "esp_visible_check", Default = false })
    UI.Section(visTab.Page, "Lineas de trazado")
    UI.Toggle(visTab.Page, { Text = "Lineas", Flag = "esp_lines", Default = true })
    UI.Dropdown(visTab.Page, { Text = "Origen", Flag = "esp_line_origin",
        Options = { "Abajo", "Centro", "Arriba", "Mouse" }, Default = "Abajo" })
    UI.Section(visTab.Page, "Colores del ESP")
    UI.Color(visTab.Page, { Text = "Caja", Flag = "esp_box_color", Default = "FFFFFF" })
    UI.Color(visTab.Page, { Text = "Lineas", Flag = "esp_line_color", Default = "FF2E4D" })
    UI.Color(visTab.Page, { Text = "Vida", Flag = "esp_health_color", Default = "FF4D6D" })
    UI.Color(visTab.Page, { Text = "Nombre", Flag = "esp_name_color", Default = "FFFFFF" })
    UI.Color(visTab.Page, { Text = "Distancia", Flag = "esp_dist_color", Default = "C9CCDD" })
    UI.Color(visTab.Page, { Text = "Esqueleto", Flag = "esp_skel_color", Default = "2BD98A" })
    UI.Color(visTab.Page, { Text = "Chams relleno", Flag = "esp_chams_color", Default = "FF2E4D" })
    UI.Color(visTab.Page, { Text = "Chams contorno", Flag = "esp_chams_outline_color", Default = "FFFFFF" })

    ------------------------------------------------------------------ OVERLAY
    local ovTab = win:Tab("Overlay")
    UI.Section(ovTab.Page, "Crosshair")
    UI.Toggle(ovTab.Page, { Text = "Crosshair personalizado", Flag = "crosshair_enabled", Default = false })
    UI.Dropdown(ovTab.Page, { Text = "Estilo", Flag = "crosshair_style",
        Options = { "Cruz", "Punto", "Cruz + punto", "Circulo" }, Default = "Cruz" })
    UI.Slider(ovTab.Page, { Text = "Tamano", Flag = "crosshair_size", Min = 2, Max = 40, Default = 10, Decimals = 0 })
    UI.Slider(ovTab.Page, { Text = "Separacion del centro", Flag = "crosshair_gap", Min = 0, Max = 20, Default = 4, Decimals = 0 })
    UI.Slider(ovTab.Page, { Text = "Grosor", Flag = "crosshair_thickness", Min = 1, Max = 4, Default = 1, Decimals = 0 })
    UI.Color(ovTab.Page, { Text = "Color", Flag = "crosshair_color", Default = "FF2E4D" })
    UI.Section(ovTab.Page, "Hitmarker")
    UI.Toggle(ovTab.Page, { Text = "Hitmarker", Flag = "hitmarker_enabled", Default = true })
    UI.Slider(ovTab.Page, { Text = "Tamano del hitmarker", Flag = "hitmarker_size", Min = 4, Max = 30, Default = 10, Decimals = 0 })
    UI.Color(ovTab.Page, { Text = "Color del hitmarker", Flag = "hitmarker_color", Default = "FFFFFF" })

    ------------------------------------------------------------------ PLAYERS
    local plrTab = win:Tab("Players")
    UI.Section(plrTab.Page, "Jugadores")
    UI.Label(plrTab.Page, "Vida y distancia en vivo. TP te manda a su posicion y VER los espectea.")
    PlayerList.Mount(plrTab.Page)

    ------------------------------------------------------------------ MOVEMENT
    local movTab = win:Tab("Movement")
    UI.Section(movTab.Page, "Velocidad")
    UI.Toggle(movTab.Page, { Text = "Speed", Flag = "speed_enabled", Default = false })
    UI.Slider(movTab.Page, { Text = "Velocidad de caminata", Flag = "speed_value", Min = 8, Max = 250, Default = 40, Decimals = 0 })
    UI.Section(movTab.Page, "Vuelo")
    UI.Toggle(movTab.Page, { Text = "Fly", Flag = "fly_enabled", Default = false })
    UI.Slider(movTab.Page, { Text = "Velocidad de vuelo", Flag = "fly_speed", Min = 10, Max = 300, Default = 60, Decimals = 0 })
    UI.Toggle(movTab.Page, { Text = "Levitar", Flag = "hover_enabled", Default = false })
    UI.Slider(movTab.Page, { Text = "Altura de levitacion", Flag = "hover_height", Min = 1, Max = 40, Default = 12, Decimals = 0 })
    UI.Section(movTab.Page, "Salto")
    UI.Toggle(movTab.Page, { Text = "Salto alto", Flag = "jump_enabled", Default = false })
    UI.Slider(movTab.Page, { Text = "Fuerza de salto", Flag = "jump_value", Min = 50, Max = 500, Default = 120, Decimals = 0 })
    UI.Toggle(movTab.Page, { Text = "Salto infinito", Flag = "infjump_enabled", Default = false })
    UI.Toggle(movTab.Page, { Text = "Bunny hop", Flag = "bhop_enabled", Default = false })
    UI.Section(movTab.Page, "Utilidades")
    UI.Toggle(movTab.Page, { Text = "Noclip", Flag = "noclip_enabled", Default = false })
    UI.Toggle(movTab.Page, { Text = "Anti-void", Flag = "antivoid_enabled", Default = true })
    UI.Keybind(movTab.Page, { Text = "Tecla de click teleport", Flag = "clicktp_key", Default = Enum.KeyCode.T })
    UI.Button(movTab.Page, { Text = "Teleport al mas cercano", Flag = "btn_tp_nearest",
        Callback = function() Movement.TeleportNearest() end })
    UI.Section(movTab.Page, "Camara libre")
    UI.Toggle(movTab.Page, { Text = "Freecam (espectador)", Flag = "freecam_enabled", Default = false })
    UI.Slider(movTab.Page, { Text = "Velocidad de la camara", Flag = "freecam_speed", Min = 10, Max = 200, Default = 50, Decimals = 0 })

    ------------------------------------------------------------------ MISC
    local miscTab = win:Tab("Misc")
    UI.Section(miscTab.Page, "Mundo")
    UI.Toggle(miscTab.Page, { Text = "Fullbright", Flag = "fullbright_enabled", Default = false })
    UI.Toggle(miscTab.Page, { Text = "Sin niebla", Flag = "nofog_enabled", Default = false })
    UI.Toggle(miscTab.Page, { Text = "FOV de camara", Flag = "fov_camera", Default = false })
    UI.Slider(miscTab.Page, { Text = "FOV de camara", Flag = "fov_value", Min = 40, Max = 120, Default = 70, Decimals = 0 })
    UI.Section(miscTab.Page, "Interfaz")
    UI.Toggle(miscTab.Page, { Text = "Watermark", Flag = "watermark_enabled", Default = true })
    UI.Slider(miscTab.Page, { Text = "Transparencia del menu", Flag = "ui_glass", Min = 0, Max = 85, Default = 18, Decimals = 0, Suffix = "%",
        Callback = function() UI.ApplyGlass() end })
    UI.Toggle(miscTab.Page, { Text = "Difuminar el juego", Flag = "ui_blur", Default = false,
        Callback = function() UI.UpdateBlur() end })
    UI.Keybind(miscTab.Page, { Text = "Tecla del menu", Flag = "menu_key", Default = Enum.KeyCode.RightShift })
    UI.Button(miscTab.Page, { Text = "Reconstruir interface", Flag = "btn_rebuild",
        Callback = function()
            if UI.FloatButton then UI.FloatButton.Visible = true end
            UI.SetOpen(true)
            Core.Notify("Interface reiniciada", "STIRLAX MODZ")
        end })
    UI.Button(miscTab.Page, { Text = "Reaparecer personaje", Flag = "btn_respawn",
        Callback = function()
            pcall(function()
                local lp = S.Players.LocalPlayer
                if lp and lp.Character then
                    local hum = lp.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Health = 0 end
                end
            end)
        end })
    UI.Section(miscTab.Page, "Configuracion")
    UI.Button(miscTab.Page, { Text = "Guardar config", Flag = "btn_save", Callback = function() Misc.SaveConfig() end })
    UI.Button(miscTab.Page, { Text = "Cargar config", Flag = "btn_load", Callback = function() Misc.LoadConfig() end })
    UI.Button(miscTab.Page, { Text = "APAGAR TODO", Flag = "btn_panic", Callback = function() Misc.Panic() end })
    UI.Section(miscTab.Page, "Auto-config")
    UI.Toggle(miscTab.Page, { Text = "Cargar ajustes al entrar", Flag = "autoconfig_cargar", Default = false })
    UI.Button(miscTab.Page, { Text = "Guardar ajustes de este juego", Flag = "btn_save_game",
        Callback = function() Misc.SaveGameConfig() end })
    UI.Button(miscTab.Page, { Text = "Cargar ajustes de este juego", Flag = "btn_load_game",
        Callback = function() Misc.LoadGameConfig() end })
    UI.Label(miscTab.Page, "Juego actual: " .. Misc.PlaceId())

    ------------------------------------------------------------------ PROT
    ------------------------------------------------------------------ PROT
    local protTab = win:Tab("Prot")
    UI.Section(protTab.Page, "Bypass anti-cheat")
    UI.Toggle(protTab.Page, { Text = "Modo sigiloso", Flag = "stealth_mode", Default = true,
        Callback = function(v) Core.Notify(v and "Sigilo activado: velocidad capada y teleports suaves" or "Sigilo apagado", "Prot") end })
    UI.Toggle(protTab.Page, { Text = "Bypass activo", Flag = "bypass_enabled", Default = true,
        Callback = function(v)
            Protection.Sync()
            Core.Notify(v and "Bypass activado" or "Bypass apagado", "Prot")
        end })
    UI.Toggle(protTab.Page, { Text = "Anti-Kick", Flag = "anti_kick", Default = true,
        Callback = function() Protection.Sync() end })
    UI.Toggle(protTab.Page, { Text = "Anti-Fling", Flag = "anti_fling", Default = true })
    UI.Toggle(protTab.Page, { Text = "Anti-Freeze", Flag = "anti_freeze", Default = false })
    UI.Toggle(protTab.Page, { Text = "Ocultar GUI de deteccion", Flag = "hide_gui", Default = true,
        Callback = function(v)
            if UI.Screen then pcall(function() UI.Screen.Name = Core.CloakName() end) end
            Core.Notify(v and "GUI camuflada" or "GUI con nombre visible", "Prot")
        end })
    UI.Toggle(protTab.Page, { Text = "Spoof de executor", Flag = "bypass_spoof", Default = false,
        Callback = function() Protection.Sync() end })
    UI.Section(protTab.Page, "Anti-expulsion")
    UI.Toggle(protTab.Page, { Text = "Bloquear teleports del juego", Flag = "teleport_guard", Default = false,
        Callback = function(v)
            Protection.Sync()
            Core.Notify(v and "Teleport guard activado (puede frenar teleports legitimos)" or "Teleport guard apagado", "Anti-expulsion")
        end })
    Protection.StatusLabel = UI.Label(protTab.Page, "Kicks bloqueados: 0    Teleports: 0    Flinges: 0").Label
    UI.Section(protTab.Page, "Escaner del juego")
    UI.Button(protTab.Page, { Text = "Escanear proteccion del juego", Flag = "btn_scan",
        Callback = function() pcall(function() Protection.ScanGame() end) end })
    Protection.ScanLabel = UI.Label(protTab.Page, "Sin escanear.").Label
    UI.Section(protTab.Page, "Sistema")
    UI.Toggle(protTab.Page, { Text = "Anti-AFK", Flag = "antiafk_enabled", Default = true })
    UI.Toggle(protTab.Page, { Text = "Guardian de personaje", Flag = "prot_charguard", Default = false })
    UI.Toggle(protTab.Page, { Text = "Reinstalacion automatica", Flag = "prot_reinstall", Default = false })
    UI.Label(protTab.Page, "Si aun te expulsan: corre el Escaner y desconfia de speed, fly y teleports largos.")

    return win
end

--------------------------------------------------------------------------------
-- 9. ARRANQUE
--------------------------------------------------------------------------------
local function start()
    UI.BuildScreen()
    local win = buildMenu()
    UI.FloatingButton()
    UI.ApplyGlass()
    UI.UpdateBlur()

    Protection.Install()
    Movement.InstallInfJump()
    Movement.InstallFreeCam()
    Core.AutoReinstall()
    Misc.AutoConfig()
    Loop.Start()

    -- Watermark segun el flag
    task.spawn(function()
        local wm
        while task.wait(1) do
            if Core.Flags["watermark_enabled"] and not wm then
                wm = UI.Watermark()
            elseif not Core.Flags["watermark_enabled"] and wm then
                pcall(function() wm.Visible = false end)
            elseif Core.Flags["watermark_enabled"] and wm then
                pcall(function() wm.Visible = true end)
            end
        end
    end)

    Core.log("cargado v" .. Core.Version .. " | abrir con " .. tostring(Core.Flags["menu_key"] and Core.Flags["menu_key"].Name or "RightShift"))
    UI.Notify("STIRLAX MODZ v" .. Core.Version .. " listo", Core.Brand, 4)

    getgenv().StirlaxModz = {
        Core = Core, UI = UI, Combat = Combat, ESP = ESP, Movement = Movement, Misc = Misc,
        Protection = Protection, Loop = Loop, Version = Core.Version, Window = win,
        PlayerList = Core.PlayerList, Overlay = Core.Overlay,
    }
    return win
end

local ok, err = pcall(start)
if not ok then
    Core.log("error al iniciar: " .. tostring(err))
end

return StirlaxModz
