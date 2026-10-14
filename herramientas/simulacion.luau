--!nocheck
-- 🧪 SIMULACIÓN DE LOCURA TOTAL (herramienta para desarrolladores)
--
-- Ejecuta el código REAL del juego (servidor + cliente) fuera de Roblox usando
-- Lune, con 8 bots, una física muy simplificada (gravedad, suelos, paredes,
-- empujones) y el tiempo acelerado. Sirve para encontrar errores sin abrir
-- Roblox Studio: si algo del juego falla, aquí sale en rojo.
--
-- Uso (desde la carpeta del proyecto):
--   rojo build default.project.json -o LocuraTotal.rbxlx
--   lune run herramientas/simulacion.luau            -- velocidad x25
--   lune run herramientas/simulacion.luau 40         -- velocidad x40
--   lune run herramientas/simulacion.luau 25 otro.rbxlx  -- probar otro archivo
--
-- No hace falta para jugar: solo es para probar el código.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Enum = roblox.Enum

local ACELERACION = tonumber(process.args[1]) or 25
local LIMITE_VIRTUAL = 2400 -- segundos de juego como máximo
local NOMBRES_BOTS = { "Pepito", "Lola", "Toni", "Marta", "Kiko", "Nuria", "Paco", "Sara" }

-- ===================================================================
-- Registro de errores
-- ===================================================================

local errores: { string } = {}
local avisos: { string } = {}
local destruidos: { [string]: number } = {}
local registro: { string } = {}

local function lineaDelJuego(texto: string): string
	for linea in string.gmatch(texto, "[^\n]+") do
		local encontrado = string.match(linea, "(%a+Service%.[%w%.]+[^\n]-:%d+)")
			or string.match(linea, "(StarterPlayer%.[%w%.]+[^\n]-:%d+)")
			or string.match(linea, "(ReplicatedStorage%.[%w%.]+[^\n]-:%d+)")
		if encontrado then
			return encontrado
		end
	end
	return string.sub(texto, 1, 160)
end

local function anotarError(mensaje: any)
	local texto = tostring(mensaje)
	if string.find(texto, "Instance has been destroyed", 1, true) then
		-- En Roblox cambiar propiedades de algo destruido NO da error; en Lune sí.
		local donde = lineaDelJuego(texto)
		destruidos[donde] = (destruidos[donde] or 0) + 1
		return
	end
	table.insert(errores, texto)
	print("\27[31m❌ ERROR:\27[0m " .. texto)
end

-- ===================================================================
-- Tiempo virtual (acelerado)
-- ===================================================================

local inicioReal = os.clock()
local function reloj(): number
	return (os.clock() - inicioReal) * ACELERACION
end

local function conRastro(err: any): string
	local ok, rastro = pcall(debug.traceback)
	return tostring(err) .. "\n" .. (if ok then tostring(rastro) else "")
end

local function proteger(funcion, ...)
	return function(...)
		local ok, err = xpcall(funcion, conRastro, ...)
		if not ok then
			anotarError(err)
		end
	end
end

local tareas = {}
function tareas.wait(segundos: number?): number
	local real = task.wait((segundos or 0) / ACELERACION)
	return (real or 0) * ACELERACION
end
function tareas.delay(segundos: number?, funcion, ...)
	if type(funcion) == "thread" then
		return task.delay((segundos or 0) / ACELERACION, funcion, ...)
	end
	return task.delay((segundos or 0) / ACELERACION, proteger(funcion), ...)
end
function tareas.spawn(funcion, ...)
	if type(funcion) == "thread" then
		return task.spawn(funcion, ...)
	end
	return task.spawn(proteger(funcion), ...)
end
function tareas.defer(funcion, ...)
	if type(funcion) == "thread" then
		return task.defer(funcion, ...)
	end
	return task.defer(proteger(funcion), ...)
end
tareas.cancel = task.cancel

local osVirtual = setmetatable({ clock = reloj }, { __index = os })

-- ===================================================================
-- Señales (eventos) falsas
-- ===================================================================

local function nuevaSenal()
	local senal = { _conexiones = {} }
	function senal:Connect(funcion)
		local conexion = { Connected = true }
		function conexion:Disconnect()
			conexion.Connected = false
		end
		table.insert(senal._conexiones, { f = funcion, c = conexion })
		return conexion
	end
	function senal:Once(funcion)
		local conexion
		conexion = senal:Connect(function(...)
			conexion:Disconnect()
			funcion(...)
		end)
		return conexion
	end
	function senal:Wait()
		local hilo = coroutine.running()
		senal:Once(function(...)
			task.spawn(hilo, ...)
		end)
		return coroutine.yield()
	end
	function senal:Fire(...)
		local vivas = {}
		for _, x in senal._conexiones do
			if x.c.Connected then
				table.insert(vivas, x)
				tareas.spawn(x.f, ...)
			end
		end
		senal._conexiones = vivas
	end
	return senal
end

local senales = setmetatable({}, { __mode = "k" })
local function senalDe(objeto, nombre: string)
	local tabla = senales[objeto]
	if not tabla then
		tabla = {}
		senales[objeto] = tabla
	end
	local senal = tabla[nombre]
	if not senal then
		senal = nuevaSenal()
		tabla[nombre] = senal
	end
	return senal
end

for _, par in {
	{ "BasePart", "Touched" },
	{ "Humanoid", "Died" },
	{ "Player", "CharacterAdded" },
	{ "Players", "PlayerAdded" },
	{ "Players", "PlayerRemoving" },
	{ "RunService", "Heartbeat" },
	{ "RunService", "RenderStepped" },
	{ "Tool", "Activated" },
	{ "GuiButton", "Activated" },
	{ "RemoteEvent", "OnClientEvent" },
	{ "RemoteEvent", "OnServerEvent" },
} do
	roblox.implementProperty(par[1], par[2], function(self)
		return senalDe(self, par[2])
	end)
end

-- ===================================================================
-- Cargar el juego
-- ===================================================================

local ruta = process.args[2] or "LocuraTotal.rbxlx"
if not fs.isFile(ruta) then
	print("No encuentro " .. ruta .. ". Ejecuta primero: rojo build default.project.json -o LocuraTotal.rbxlx")
	process.exit(1)
end
local game = roblox.deserializePlace(fs.readFile(ruta))
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local camara = Instance.new("Camera")
camara.Parent = workspace
workspace.CurrentCamera = camara

local jugadorLocal = nil
local bots: { [any]: any } = {} -- estado de física de cada bot

-- ===================================================================
-- Métodos de Roblox que Lune no trae
-- ===================================================================

local metodo = roblox.implementMethod


metodo("Instance", "WaitForChild", function(self, nombre, limite)
	local fin = reloj() + (limite or 5)
	while true do
		local hijo = self:FindFirstChild(nombre)
		if hijo then
			return hijo
		end
		if reloj() > fin then
			if limite then
				return nil
			end
			anotarError("WaitForChild no encontró '" .. nombre .. "' en " .. self:GetFullName())
			return nil
		end
		tareas.wait(0.1)
	end
end)

metodo("Model", "GetPivot", function(self)
	local raiz = self.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
	if raiz then
		return raiz.CFrame
	end
	return CFrame.new()
end)
metodo("Model", "PivotTo", function(self, destino)
	local delta = destino * self:GetPivot():Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)
metodo("Model", "ScaleTo", function(self, escala)
	self:SetAttribute("EscalaSimulada", escala)
end)

-- Avisa de las partes con etiquetas nuevas (como GetInstanceAddedSignal).
local CollectionService = game:GetService("CollectionService")
local etiquetadosVistos = setmetatable({}, { __mode = "k" })
local function avisarEtiquetasNuevas()
	for _, d in workspace:GetDescendants() do
		if not etiquetadosVistos[d] then
			etiquetadosVistos[d] = true
			for _, etiqueta in d:GetTags() do
				senalDe(CollectionService, "Agregado_" .. etiqueta):Fire(d)
			end
		end
	end
end
metodo("CollectionService", "GetTagged", function(_self, etiqueta)
	local lista = {}
	for _, d in game:GetDescendants() do
		if d:HasTag(etiqueta) then
			table.insert(lista, d)
		end
	end
	return lista
end)
metodo("CollectionService", "GetInstanceAddedSignal", function(self, etiqueta)
	return senalDe(self, "Agregado_" .. etiqueta)
end)
metodo("CollectionService", "GetInstanceRemovedSignal", function(self, etiqueta)
	return senalDe(self, "Quitado_" .. etiqueta)
end)

metodo("TweenService", "Create", function(_self, objeto, info, propiedades)
	for clave in propiedades do
		-- Falla si la propiedad no existe (como en Roblox).
		local ok, err = pcall(function()
			return objeto[clave]
		end)
		if not ok and string.find(tostring(err), "not a valid member", 1, true) then
			anotarError("Tween con propiedad inválida: " .. tostring(err))
		end
	end
	local tween = { Completed = nuevaSenal() }
	function tween:Play()
		tareas.delay(info.Time or 1, function()
			local ok, err = pcall(function()
				for clave, valor in propiedades do
					objeto[clave] = valor
				end
			end)
			if not ok and not string.find(tostring(err), "destroyed", 1, true) then
				anotarError("Tween: " .. tostring(err))
			end
			tween.Completed:Fire(Enum.PlaybackState.Completed)
		end)
	end
	function tween:Cancel() end
	function tween:Pause() end
	return tween
end)

metodo("Debris", "AddItem", function(_self, objeto, tiempo)
	tareas.delay(tiempo or 10, function()
		pcall(function()
			objeto:Destroy()
		end)
	end)
end)

metodo("RunService", "IsStudio", function()
	return true
end)
metodo("DataModel", "BindToClose", function() end)
metodo("Sound", "Play", function() end)
metodo("ParticleEmitter", "Emit", function() end)
metodo("BasePart", "SetNetworkOwner", function(self)
	if self.Anchored then
		error("Network Ownership API cannot be called on Anchored parts")
	end
end)
metodo("Humanoid", "EquipTool", function(self, herramienta)
	herramienta.Parent = self.Parent
end)
metodo("Humanoid", "ChangeState", function() end)

metodo("Players", "GetPlayers", function(self)
	local lista = {}
	for _, hijo in self:GetChildren() do
		if hijo:IsA("Player") then
			table.insert(lista, hijo)
		end
	end
	return lista
end)
metodo("Players", "GetPlayerFromCharacter", function(self, modelo)
	for _, hijo in self:GetChildren() do
		if hijo:IsA("Player") and hijo.Character == modelo then
			return hijo
		end
	end
	return nil
end)
metodo("Players", "GetPlayerByUserId", function(self, id)
	for _, hijo in self:GetChildren() do
		if hijo:IsA("Player") and hijo.UserId == id then
			return hijo
		end
	end
	return nil
end)
roblox.implementProperty("Players", "LocalPlayer", function()
	return jugadorLocal
end)

local expulsados: { string } = {}
metodo("Player", "Kick", function(self, mensaje)
	table.insert(expulsados, self.Name .. ": " .. tostring(mensaje))
	senalDe(Players, "PlayerRemoving"):Fire(self)
	self.Parent = nil
end)

local function crearPersonaje(jugador)
	tareas.wait(0.3)
	if jugador.Parent ~= Players then
		return
	end
	local viejo = jugador.Character
	if viejo then
		viejo:Destroy()
	end
	local modelo = Instance.new("Model")
	modelo.Name = jugador.Name
	local raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = Vector3.new(2, 2, 1)
	raiz.Transparency = 1
	raiz.Parent = modelo
	local cabeza = Instance.new("Part")
	cabeza.Name = "Head"
	cabeza.Size = Vector3.new(2, 1, 1)
	cabeza.CFrame = CFrame.new(0, 1.5, 0)
	cabeza.Parent = modelo
	local humanoide = Instance.new("Humanoid")
	humanoide.MaxHealth = 100
	humanoide.Health = 100
	humanoide.WalkSpeed = 16
	humanoide.JumpPower = 50
	humanoide.UseJumpPower = true
	humanoide.PlatformStand = false
	humanoide.Parent = modelo
	raiz.AssemblyLinearVelocity = Vector3.zero
	raiz.Anchored = false
	modelo.PrimaryPart = raiz

	local spawns = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			table.insert(spawns, d)
		end
	end
	local spawn = spawns[math.random(1, #spawns)]
	modelo:PivotTo(spawn.CFrame + Vector3.new(0, 3.5, 0))
	modelo.Parent = workspace
	jugador.Character = modelo
	bots[jugador] = { dir = Vector3.new(1, 0, 0), ragdollHasta = 0, tocando = {} }
	senalDe(jugador, "CharacterAdded"):Fire(modelo)
end
metodo("Player", "LoadCharacterAsync", crearPersonaje)
metodo("Player", "LoadCharacter", crearPersonaje)

-- ===================================================================
-- Física muy simplificada
-- ===================================================================

local OverlapParamsFalso = {
	new = function()
		return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {} }
	end,
}
local TweenInfoFalso = {
	new = function(tiempo)
		return { Time = tiempo or 1 }
	end,
}

local function extension(parte): (Vector3, Vector3)
	local cf, s = parte.CFrame, parte.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local ex = math.abs(r.X) * s.X / 2 + math.abs(u.X) * s.Y / 2 + math.abs(l.X) * s.Z / 2
	local ey = math.abs(r.Y) * s.X / 2 + math.abs(u.Y) * s.Y / 2 + math.abs(l.Y) * s.Z / 2
	local ez = math.abs(r.Z) * s.X / 2 + math.abs(u.Z) * s.Y / 2 + math.abs(l.Z) * s.Z / 2
	return cf.Position, Vector3.new(ex, ey, ez)
end

local function solapan(c1: Vector3, e1: Vector3, c2: Vector3, e2: Vector3): boolean
	return math.abs(c1.X - c2.X) <= e1.X + e2.X
		and math.abs(c1.Y - c2.Y) <= e1.Y + e2.Y
		and math.abs(c1.Z - c2.Z) <= e1.Z + e2.Z
end

local function esDePersonaje(parte): boolean
	local modelo = parte:FindFirstAncestorOfClass("Model")
	return modelo ~= nil and modelo:FindFirstChildOfClass("Humanoid") ~= nil
end

metodo("Workspace", "GetPartBoundsInBox", function(self, cf, tamano, parametros)
	local candidatas = {}
	if parametros and parametros.FilterType == Enum.RaycastFilterType.Include then
		for _, raiz in parametros.FilterDescendantsInstances do
			if raiz:IsA("BasePart") then
				table.insert(candidatas, raiz)
			end
			for _, d in raiz:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(candidatas, d)
				end
			end
		end
	else
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(candidatas, d)
			end
		end
	end
	local resultado = {}
	local mitad = tamano / 2
	for _, parte in candidatas do
		local c, e = extension(parte)
		if solapan(cf.Position, mitad, c, e) then
			table.insert(resultado, parte)
		end
	end
	return resultado
end)

-- Altura de la cara de arriba de una parte (aunque esté girada) bajo (x, z).
local function alturaSuperficie(parte, x: number, z: number, desdeY: number): number?
	local cf = parte.CFrame
	local origen = cf:PointToObjectSpace(Vector3.new(x, desdeY, z))
	local direccion = cf:VectorToObjectSpace(Vector3.new(0, -1, 0))
	local mitad = parte.Size / 2
	local tMin, tMax = -math.huge, math.huge
	for _, eje in { "X", "Y", "Z" } do
		local o, d, m = origen[eje], direccion[eje], mitad[eje]
		if math.abs(d) < 1e-6 then
			if o < -m or o > m then
				return nil
			end
		else
			local t1, t2 = (-m - o) / d, (m - o) / d
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return nil
			end
		end
	end
	if tMax < 0 then
		return nil
	end
	return desdeY - math.max(tMin, 0)
end

type Solida = { parte: any, c: Vector3, e: Vector3 }
local estaticas: { Solida } = {}
local estaticasToque: { Solida } = {}

-- Partes sólidas y "tocables" de este momento (el lobby se calcula una sola vez).
local function listasDelMundo(): ({ Solida }, { Solida })
	local solidas = table.clone(estaticas)
	local tocables = table.clone(estaticasToque)
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		for _, d in arena:GetDescendants() do
			if d:IsA("BasePart") then
				local choca, toca = d.CanCollide, d.CanTouch
				if choca or toca then
					local c, e = extension(d)
					local s = { parte = d, c = c, e = e }
					if choca then
						table.insert(solidas, s)
					end
					if toca then
						table.insert(tocables, s)
					end
				end
			end
		end
	end
	return solidas, tocables
end

local function arenaCentro(): Vector3
	return Vector3.new(0, 120, 420)
end

local function empujarBot(jugador, velocidad, vuelo)
	local estado = bots[jugador]
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	if estado and raiz then
		raiz.AssemblyLinearVelocity = velocidad
		estado.ragdollHasta = reloj() + (vuelo or 0)
	end
end

local metaPara: { [any]: number } = {}

local function moverBot(jugador, estado, dt: number, solidas: { Solida }, tocables: { Solida })
	local personaje = jugador.Character
	if not personaje or not personaje.Parent then
		return
	end
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	local humanoide = personaje:FindFirstChildOfClass("Humanoid")
	if not raiz or not humanoide or humanoide.Health <= 0 then
		return
	end

	local pos = raiz.CFrame.Position
	local v = raiz.AssemblyLinearVelocity
	local arena = workspace:FindFirstChild("Arena")
	local enArena = arena ~= nil and (pos - arenaCentro()).Magnitude < 400

	-- Dirección: los bots "listos" vuelven hacia el centro si se alejan.
	local ragdoll = humanoide.PlatformStand or estado.ragdollHasta > reloj()
	local entrada = Vector3.zero
	if not ragdoll and humanoide.WalkSpeed > 0 then
		local esCarrera = arena and (arena:FindFirstChild("CintaLoca") or arena:FindFirstChild("Rampa"))
		if math.random() < 0.08 * dt * 10 then
			local angulo = math.random() * math.pi * 2
			estado.dir = Vector3.new(math.cos(angulo), 0, math.sin(angulo))
			if enArena and esCarrera then
				estado.dir = Vector3.new(estado.dir.X * 0.4, 0, 1).Unit
			elseif enArena then
				local hacia = Vector3.new(arenaCentro().X - pos.X, 0, arenaCentro().Z - pos.Z)
				if hacia.Magnitude > 22 and math.random() < 0.7 then
					estado.dir = hacia.Unit
				end
			end
		end
		entrada = estado.dir * humanoide.WalkSpeed
	end

	v = v - Vector3.new(0, workspace.Gravity * dt, 0)
	local nueva = pos + (v + entrada) * dt

	-- Paredes: si choca de lado con algo alto, no avanza en horizontal.
	local cuerpoE = Vector3.new(0.9, 1.6, 0.9)
	local cuerpoNuevo = nueva + Vector3.new(0, 0.6, 0)
	local cuerpoViejo = pos + Vector3.new(0, 0.6, 0)
	for _, s in solidas do
		if solapan(cuerpoNuevo, cuerpoE, s.c, s.e) and not solapan(cuerpoViejo, cuerpoE, s.c, s.e) then
			local arriba = alturaSuperficie(s.parte, nueva.X, nueva.Z, nueva.Y + 60)
			local esEscalon = arriba ~= nil and arriba <= nueva.Y - 3 + 1.6
			if not esEscalon then
				nueva = Vector3.new(pos.X, nueva.Y, pos.Z)
				estado.dir = -estado.dir
				break
			end
		end
	end

	-- Suelo: miramos debajo de los dos pies (5 puntos), no solo del centro.
	local piesAntes, piesNuevos = pos.Y - 3, nueva.Y - 3
	local avance = Vector3.new(nueva.X - pos.X, 0, nueva.Z - pos.Z).Magnitude
	local desde = piesAntes + 1.2 + avance * 0.6 -- permite subir rampas
	local mejor: number? = nil
	local columnaC = Vector3.new(nueva.X, (desde + piesNuevos) / 2, nueva.Z)
	local columnaE = Vector3.new(1, math.abs(desde - piesNuevos) / 2 + 0.5, 1)
	for _, s in solidas do
		if solapan(columnaC, columnaE, s.c, s.e) then
			for _, o in { { 0, 0 }, { 0.8, 0.8 }, { -0.8, 0.8 }, { 0.8, -0.8 }, { -0.8, -0.8 } } do
				local altura = alturaSuperficie(s.parte, nueva.X + o[1], nueva.Z + o[2], desde)
				if altura and altura >= piesNuevos - 0.05 and (mejor == nil or altura > mejor) then
					mejor = altura
				end
			end
		end
	end
	if mejor and v.Y <= 0 then
		nueva = Vector3.new(nueva.X, mejor + 3, nueva.Z)
		v = Vector3.new(v.X * 0.5, 0, v.Z * 0.5)
	end

	raiz.AssemblyLinearVelocity = v
	personaje:PivotTo(CFrame.new(nueva) * (raiz.CFrame - raiz.CFrame.Position))

	-- Toques: dispara Touched en las partes que roza (lava, trampolines...).
	local toca = {}
	local tC, tE = nueva, Vector3.new(1.2, 3.2, 1.2)
	for _, s in tocables do
		local parte = s.parte
		if solapan(tC, tE, s.c, s.e) then
			toca[parte] = true
			if not estado.tocando[parte] then
				senalDe(parte, "Touched"):Fire(raiz)
				-- Los demás bots hacen lo que haría su script de cliente.
				if jugador ~= jugadorLocal and parte:HasTag("Impulso") then
					local impulso = parte:GetAttribute("Impulso")
					if impulso then
						empujarBot(jugador, impulso, parte:GetAttribute("Vuelo") or 0)
					end
				end
			end
		end
	end
	estado.tocando = toca

	-- En las carreras, cada bot "sabe" llegar a la meta en algún momento.
	if enArena and arena then
		local meta = arena:FindFirstChild("Meta")
		if meta and humanoide.WalkSpeed > 0 then
			local cuando = metaPara[jugador]
			if not cuando then
				cuando = reloj() + math.random(15, 140)
				metaPara[jugador] = cuando
			end
			if reloj() > cuando then
				metaPara[jugador] = math.huge
				personaje:PivotTo(CFrame.new(meta.CFrame.Position + Vector3.new(math.random(-5, 5), 4, 5)))
				raiz.AssemblyLinearVelocity = Vector3.zero
			end
		end
		-- Rey de la colina: a veces alguien sube a la cima.
		local cima = arena:FindFirstChild("Piso3")
		if cima and humanoide.WalkSpeed > 0 and math.random() < 0.01 then
			personaje:PivotTo(CFrame.new(cima.CFrame.Position + Vector3.new(math.random(-4, 4), 4, math.random(-4, 4))))
		end
	else
		metaPara[jugador] = nil
	end
end

-- Mueve las cosas sueltas de la arena (barras, bolas, rocas que caen).
local function moverMundo(dt: number)
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return
	end
	for _, d in arena:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored then
			local bisagra = d:FindFirstChildOfClass("HingeConstraint")
			if bisagra then
				local giro = CFrame.Angles(0, bisagra.AngularVelocity * dt, 0)
				local centro = d.CFrame.Position
				d.CFrame = CFrame.new(centro) * giro * (d.CFrame - centro)
			elseif d.Name == "Bola" then
				d.CFrame = d.CFrame + Vector3.new(0, -0.2126, -1) * 30 * dt
			else
				d.CFrame = d.CFrame + Vector3.new(0, -40 * dt, 0)
			end
		end
	end
end

-- ===================================================================
-- Entorno para ejecutar los scripts del juego
-- ===================================================================

local function globales()
	return {
		game = game,
		workspace = workspace,
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = Enum,
		Font = roblox.Font,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		PhysicalProperties = roblox.PhysicalProperties,
		BrickColor = roblox.BrickColor,
		Rect = roblox.Rect,
		TweenInfo = TweenInfoFalso,
		OverlapParams = OverlapParamsFalso,
		RaycastParams = OverlapParamsFalso,
		task = tareas,
		os = osVirtual,
		math = math,
		string = string,
		table = table,
		coroutine = coroutine,
		utf8 = utf8,
		buffer = buffer,
		bit32 = bit32,
		debug = debug,
		print = function(...)
			table.insert(registro, "PRINT " .. table.concat({ ... }, " "))
		end,
		warn = function(...)
			local partes = {}
			for _, x in { ... } do
				table.insert(partes, tostring(x))
			end
			local texto = table.concat(partes, " ")
			table.insert(avisos, texto)
			print("\27[33m⚠️ AVISO:\27[0m " .. texto)
		end,
		error = error,
		assert = assert,
		pcall = pcall,
		xpcall = xpcall,
		select = select,
		type = type,
		typeof = typeof,
		tostring = tostring,
		tonumber = tonumber,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		rawlen = rawlen,
		ipairs = ipairs,
		pairs = pairs,
		next = next,
		unpack = table.unpack,
	}
end

-- Lune no calcula BasePart.Position a partir de CFrame. Para la simulación,
-- cambiamos las LECTURAS de ".Position" por una función que sí lo hace.
local function posicionDe(x)
	if typeof(x) == "Instance" and x:IsA("BasePart") then
		return x.CFrame.Position
	end
	return x.Position
end

local function adaptar(fuente: string): string
	return (
		string.gsub(fuente, "([%a_][%w_%.]*)%.Position(%s*=?=?)", function(receptor, sufijo)
			if string.match(sufijo, "^%s*=$") then
				return nil -- es una asignación: se deja igual
			end
			return "__posicion(" .. receptor .. ")" .. sufijo
		end)
	)
end

local function crearCargador()
	local base = globales()
	base.__posicion = posicionDe
	local cache = {}
	local function requerir(modulo)
		local clave = modulo:GetFullName()
		if cache[clave] ~= nil then
			return cache[clave]
		end
		local entorno = table.clone(base)
		entorno.script = modulo
		entorno.require = requerir
		local funcion = luau.load(adaptar(modulo.Source), { debugName = clave, environment = entorno })
		local resultado = funcion()
		cache[clave] = resultado
		return resultado
	end
	local function ejecutar(script)
		local entorno = table.clone(base)
		entorno.script = script
		entorno.require = requerir
		local funcion = luau.load(adaptar(script.Source), { debugName = script:GetFullName(), environment = entorno })
		tareas.spawn(funcion)
	end
	return requerir, ejecutar
end

-- ===================================================================
-- Remotos: del servidor a los clientes
-- ===================================================================

local cuenta: { [string]: number } = {}
local titulosJugados: { string } = {}
local campeonVisto = false

local function resumir(nombre: string, a, b)
	cuenta[nombre] = (cuenta[nombre] or 0) + 1
	local t = string.format("[%6.1f] ", reloj())
	if nombre == "Anuncio" then
		local sub = if type(b) == "table" and b.Subtitulo then " — " .. b.Subtitulo else ""
		table.insert(registro, t .. "📢 " .. tostring(a) .. sub)
	elseif nombre == "Feed" then
		table.insert(registro, t .. "   " .. tostring(a))
	elseif nombre == "Ruleta" then
		table.insert(registro, t .. "🎰 " .. a.Titulo .. " → " .. a.Opciones[a.Elegido])
	elseif nombre == "Resultados" then
		table.insert(titulosJugados, a.Titulo)
		local filas = {}
		for _, f in a.Filas do
			table.insert(filas, string.format("%dº %s (%s) +%d=%d", f.Puesto, f.Nombre, f.Detalle, f.Puntos, f.Total))
		end
		table.insert(registro, t .. "📊 " .. a.Titulo .. ": " .. table.concat(filas, " | "))
	elseif nombre == "Campeon" then
		campeonVisto = true
		table.insert(registro, t .. "👑 CAMPEÓN: " .. table.concat(a.Nombres, ", "))
	end
end

metodo("RemoteEvent", "FireAllClients", function(self, ...)
	resumir(self.Name, ...)
	if self.Name == "Empujon" then
		for jugador in bots do
			if jugador ~= jugadorLocal then
				empujarBot(jugador, ...)
			end
		end
	end
	senalDe(self, "OnClientEvent"):Fire(...)
end)
metodo("RemoteEvent", "FireClient", function(self, jugador, ...)
	cuenta[self.Name .. " (a uno)"] = (cuenta[self.Name .. " (a uno)"] or 0) + 1
	if self.Name == "Empujon" and jugador ~= jugadorLocal then
		empujarBot(jugador, ...)
	end
	if jugador == jugadorLocal then
		senalDe(self, "OnClientEvent"):Fire(...)
	end
end)

-- ===================================================================
-- ¡A jugar!
-- ===================================================================

print("🧪 Simulando LOCURA TOTAL a velocidad x" .. ACELERACION .. "...")

local requerirServidor, ejecutarServidor = crearCargador()
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local scriptServidor = ServerScriptService:FindFirstChild("Servidor")

-- Una partida que pase por los 8 minijuegos.
local Config = requerirServidor(ReplicatedStorage.Compartido.Config)
Config.RONDAS_POR_PARTIDA = 8
local Jugadores = requerirServidor(scriptServidor.Jugadores)

ejecutarServidor(scriptServidor)
tareas.wait(1)

local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "No se construyó el lobby")
for _, d in lobby:GetDescendants() do
	if d:IsA("BasePart") then
		local c, e = extension(d)
		if d.CanCollide then
			table.insert(estaticas, { parte = d, c = c, e = e })
		end
		if d.CanTouch then
			table.insert(estaticasToque, { parte = d, c = c, e = e })
		end
	end
end
print(string.format("🏝️ Lobby construido: %d piezas", #lobby:GetDescendants()))

-- 9 jugadores: el noveno debería ser expulsado (máximo 8).
local lista = {}
for i = 1, 9 do
	local jugador = Instance.new("Player")
	jugador.Name = NOMBRES_BOTS[i] or ("Bot" .. i)
	jugador.DisplayName = jugador.Name
	jugador.UserId = 1000 + i
	Instance.new("Backpack").Parent = jugador
	Instance.new("PlayerGui").Parent = jugador
	jugador.Parent = Players
	if i == 1 then
		jugadorLocal = jugador
		pcall(function()
			Players.LocalPlayer = jugador
		end)
	end
	table.insert(lista, jugador)
	senalDe(Players, "PlayerAdded"):Fire(jugador)
	tareas.wait(0.2)
end

-- Cliente (lo que ve Pepito).
local _, ejecutarCliente = crearCargador()
local scriptCliente = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Cliente")
ejecutarCliente(scriptCliente)

-- Motores: Heartbeat, física de bots y del mundo.
local RunService = game:GetService("RunService")
local ultimo = reloj()
local salirDeLaPartida = false
task.spawn(function()
	while not salirDeLaPartida do
		task.wait(1 / 120)
		local ahora = reloj()
		local dt = math.min(ahora - ultimo, 0.3)
		ultimo = ahora
		avisarEtiquetasNuevas()
		senalDe(RunService, "Heartbeat"):Fire(dt)
		senalDe(RunService, "RenderStepped"):Fire(dt)
		local ok, err = xpcall(function()
			moverMundo(dt)
			local solidas, tocables = listasDelMundo()
			for jugador, estado in bots do
				if jugador.Parent == Players then
					moverBot(jugador, estado, dt, solidas, tocables)
				end
			end
		end, conRastro)
		if not ok then
			print("💥 Fallo en el simulador (no en el juego): " .. tostring(err))
			salirDeLaPartida = true
		end
	end
end)

-- A mitad de partida, Kiko se va del juego.
local seFue = false
task.spawn(function()
	while #titulosJugados < 3 do
		task.wait(0.05)
	end
	tareas.wait(30)
	local kiko = lista[5]
	senalDe(Players, "PlayerRemoving"):Fire(kiko)
	if kiko.Character then
		kiko.Character:Destroy() -- en Roblox el personaje desaparece al salir
	end
	kiko.Parent = nil
	bots[kiko] = nil
	seFue = true
	table.insert(registro, string.format("[%6.1f] 🚪 Kiko se fue del juego", reloj()))
end)

-- Los bots hacen clic con el martillo y Pepito usa el botón de ESPECTAR.
local clics, espectados = 0, 0
task.spawn(function()
	while not salirDeLaPartida do
		tareas.wait(0.6)
		for jugador in bots do
			local personaje = jugador.Character
			local herramienta = personaje and personaje:FindFirstChildOfClass("Tool")
			if herramienta and math.random() < 0.6 then
				clics += 1
				senalDe(herramienta, "Activated"):Fire()
			end
		end
		local gui = jugadorLocal and jugadorLocal:FindFirstChild("PlayerGui")
		local panel = gui and gui:FindFirstChild("LocuraUI") and gui.LocuraUI:FindFirstChild("Espectar")
		if panel and panel.Visible then
			espectados += 1
			local boton = panel:FindFirstChild(if math.random() < 0.85 then "Siguiente" else "Cerrar")
			if boton then
				senalDe(boton, "Activated"):Fire()
			end
		end
	end
end)

-- Esperar a que termine la partida (o al límite de tiempo).
local puntosAntes = {}
while reloj() < LIMITE_VIRTUAL and not salirDeLaPartida do
	task.wait(0.1)
	if campeonVisto then
		for _, jugador in Players:GetPlayers() do
			puntosAntes[jugador.Name] = Jugadores.Puntos(jugador)
		end
		tareas.wait(Config.TIEMPO_CEREMONIA + 3)
		break
	end
end
salirDeLaPartida = true

-- ===================================================================
-- Informe
-- ===================================================================

print("\n================ 📜 LO QUE PASÓ EN LA PARTIDA ================")
for _, linea in registro do
	print(linea)
end

local comprobaciones = {}
local function comprobar(nombre: string, ok: boolean, detalle: string?)
	table.insert(comprobaciones, { nombre = nombre, ok = ok, detalle = detalle })
end

local distintos = {}
for _, t in titulosJugados do
	distintos[t] = true
end
local numDistintos = 0
for _ in distintos do
	numDistintos += 1
end
comprobar("Se jugaron 8 rondas", #titulosJugados == 8, tostring(#titulosJugados))
comprobar("Los 8 minijuegos son distintos", numDistintos == 8, tostring(numDistintos))
comprobar("Hubo ceremonia de campeón", campeonVisto)
comprobar("El 9º jugador fue expulsado (máx. 8)", #expulsados == 1, table.concat(expulsados, "; "))
comprobar("Un jugador se fue a mitad y el juego siguió", seFue)
comprobar("La gravedad volvió a la normalidad", math.abs(workspace.Gravity - 196.2) < 0.01, tostring(workspace.Gravity))
comprobar("La arena se borró al final", workspace:FindFirstChild("Arena") == nil)

local coronas, todosACero = 0, true
for _, jugador in Players:GetPlayers() do
	local stats = jugador:FindFirstChild("leaderstats")
	if stats then
		coronas += stats.Coronas.Value
		if stats.Puntos.Value ~= 0 then
			todosACero = false
		end
	end
end
comprobar("El campeón ganó una corona", coronas >= 1, tostring(coronas))
comprobar("Los puntos se reiniciaron tras la ceremonia", todosACero)
comprobar("Los bots usaron el Martillo Loco", clics > 0, tostring(clics) .. " golpes")
comprobar("Pepito usó el botón de ESPECTAR", espectados > 0, tostring(espectados) .. " veces")
comprobar("Sin errores de Lua", #errores == 0, tostring(#errores))
comprobar("Sin avisos (warn)", #avisos == 0, tostring(#avisos))

print("\n================ ✅ COMPROBACIONES ================")
local fallos = 0
for _, c in comprobaciones do
	print((if c.ok then "✅ " else "❌ ") .. c.nombre .. (if c.detalle then "  (" .. c.detalle .. ")" else ""))
	if not c.ok then
		fallos += 1
	end
end

print("\n📈 Mensajes enviados a los clientes:")
local nombres = {}
for nombre in cuenta do
	table.insert(nombres, nombre)
end
table.sort(nombres)
for _, nombre in nombres do
	print(string.format("   %-22s %d", nombre, cuenta[nombre]))
end

local hayDestruidos = next(destruidos) ~= nil
if hayDestruidos then
	print("\nℹ️  Cambios en objetos ya borrados (en Roblox no dan error, en Lune sí):")
	for donde, veces in destruidos do
		print(string.format("   %4dx %s", veces, donde))
	end
end

print(string.format("\nTiempo de juego simulado: %.0f s (real: %.1f s)", reloj(), os.clock() - inicioReal))
if fallos == 0 then
	print("\27[32m🎉 ¡TODO BIEN!\27[0m")
	process.exit(0)
else
	print("\27[31m💥 " .. fallos .. " comprobación(es) fallaron\27[0m")
	process.exit(1)
end
