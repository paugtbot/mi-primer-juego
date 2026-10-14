--!nocheck
-- 🧪 SIMULACIÓN DE LOCURA TOTAL (herramienta para desarrolladores)
--
-- Ejecuta el script REAL del juego fuera de Roblox usando Lune, con 8 bots,
-- una física muy simplificada (gravedad, suelos, paredes, empujones) y el
-- tiempo acelerado. Los bots votan, pulsan el botón rojo, cogen cajas, usan
-- el martillo... y se comprueba que no salte ningún error.
--
-- Uso (desde la carpeta del proyecto):
--   rojo build default.project.json -o LocuraTotal.rbxlx
--   lune run herramientas/simulacion.luau [velocidad] [archivo.rbxlx] [rondas]
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
local RUTA = process.args[2] or "LocuraTotal.rbxlx"
local RONDAS = tonumber(process.args[3]) or 13
local LIMITE_VIRTUAL = 4000
local NOMBRES_BOTS = { "Pepito", "Lola", "Toni", "Marta", "Kiko", "Nuria", "Paco", "Sara", "Intruso" }
local ARENA = Vector3.new(0, 120, 420)
local GRADA = Vector3.new(-100, 162, 420)
local LOBBY = Vector3.new(0, 50, 0)

-- ===================================================================
-- Registro de errores
-- ===================================================================

local errores: { string } = {}
local avisos: { string } = {}
local destruidos: { [string]: number } = {}
local registro: { string } = {}

local function lineaDelJuego(texto: string): string
	for linea in string.gmatch(texto, "[^\n]+") do
		local encontrado = string.match(linea, "(LocuraTotal[^\n]-:%d+)")
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

local function proteger(funcion)
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

-- Tabla normal (no débil): si Lune borrara la entrada, se perderían las conexiones.
local senales = {}
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
	{ "Tool", "Activated" },
	{ "ProximityPrompt", "Triggered" },
} do
	roblox.implementProperty(par[1], par[2], function(self)
		return senalDe(self, par[2])
	end)
end

-- ===================================================================
-- Cargar el juego
-- ===================================================================

if not fs.isFile(RUTA) then
	print("No encuentro " .. RUTA .. ". Ejecuta primero: rojo build default.project.json -o LocuraTotal.rbxlx")
	process.exit(1)
end
local game = roblox.deserializePlace(fs.readFile(RUTA))
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

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

-- Terreno: Lune no tiene vóxeles. Cada relleno sólido se convierte en una
-- parte invisible (su caja) para que los bots puedan pisarlo. El agua no.
if not workspace:FindFirstChildOfClass("Terrain") then
	local terreno = Instance.new("Terrain")
	terreno.Name = "Terrain"
	terreno.Parent = workspace
end
local carpetaTerreno = Instance.new("Folder")
carpetaTerreno.Name = "TerrenoSimulado"
carpetaTerreno.Parent = workspace
local function bloqueTerreno(cf, tamano, material)
	if material == Enum.Material.Water or material == Enum.Material.Air then
		return
	end
	local parte = Instance.new("Part")
	parte.Name = "Terreno"
	parte.Anchored = true
	parte.CanTouch = false
	parte.Transparency = 1
	parte.CFrame = cf
	parte.Size = tamano
	parte.Parent = carpetaTerreno
end
metodo("Terrain", "FillBlock", function(_self, cf, tamano, material)
	bloqueTerreno(cf, tamano, material)
end)
metodo("Terrain", "FillWedge", function(_self, cf, tamano, material)
	bloqueTerreno(cf, tamano, material)
end)
metodo("Terrain", "FillBall", function(_self, centro, radio, material)
	bloqueTerreno(CFrame.new(centro), Vector3.new(radio * 2, radio * 2, radio * 2), material)
end)
metodo("Terrain", "FillCylinder", function(_self, cf, alto, radio, material)
	bloqueTerreno(cf, Vector3.new(radio * 2, alto, radio * 2), material)
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
metodo("Model", "GetScale", function(self)
	return self:GetAttribute("EscalaSimulada") or 1
end)

-- Avisa de las partes con etiquetas nuevas (como GetInstanceAddedSignal).
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

metodo("TweenService", "Create", function(_self, objeto, info, propiedades)
	for clave in propiedades do
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
metodo("BasePart", "SetNetworkOwner", function(self)
	if self.Anchored then
		error("Network Ownership API cannot be called on Anchored parts")
	end
end)
metodo("Humanoid", "EquipTool", function(self, herramienta)
	herramienta.Parent = self.Parent
end)

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
	raiz.Anchored = false
	raiz.AssemblyLinearVelocity = Vector3.zero
	raiz.Parent = modelo
	local cabeza = Instance.new("Part")
	cabeza.Name = "Head"
	cabeza.Size = Vector3.new(2, 1, 1)
	cabeza.CFrame = CFrame.new(0, 1.5, 0)
	cabeza.Transparency = 0
	cabeza.Parent = modelo
	local cara = Instance.new("Decal")
	cara.Name = "face"
	cara.Parent = cabeza
	local humanoide = Instance.new("Humanoid")
	humanoide.MaxHealth = 100
	humanoide.Health = 100
	humanoide.WalkSpeed = 16
	humanoide.JumpPower = 50
	humanoide.UseJumpPower = true
	humanoide.PlatformStand = false
	humanoide.Parent = modelo
	modelo.PrimaryPart = raiz

	local spawns = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d.Enabled then
			table.insert(spawns, d)
		end
	end
	local spawn = spawns[math.random(1, #spawns)]
	modelo:PivotTo(spawn.CFrame + Vector3.new(0, 3.5, 0))
	modelo.Parent = workspace
	jugador.Character = modelo
	bots[jugador] = { dir = Vector3.new(1, 0, 0), tocando = {} }
	senalDe(jugador, "CharacterAdded"):Fire(modelo)
end
metodo("Player", "LoadCharacterAsync", crearPersonaje)

-- ===================================================================
-- Física muy simplificada
-- ===================================================================

local ParamsFalsos = {
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

local function candidatasDe(parametros)
	local lista = {}
	if parametros and parametros.FilterType == Enum.RaycastFilterType.Include then
		for _, raiz in parametros.FilterDescendantsInstances do
			if raiz:IsA("BasePart") then
				table.insert(lista, raiz)
			end
			for _, d in raiz:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(lista, d)
				end
			end
		end
	else
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(lista, d)
			end
		end
	end
	return lista
end

metodo("Workspace", "GetPartBoundsInBox", function(_self, cf, tamano, parametros)
	local resultado = {}
	local mitad = tamano / 2
	for _, parte in candidatasDe(parametros) do
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

-- Raycast solo hacia abajo (es lo único que usa el juego).
metodo("Workspace", "Raycast", function(_self, origen, direccion, parametros)
	local mejor, mejorParte = nil, nil
	for _, parte in candidatasDe(parametros) do
		if parte.CanQuery then
			local altura = alturaSuperficie(parte, origen.X, origen.Z, origen.Y)
			if altura and altura >= origen.Y + direccion.Y and (mejor == nil or altura > mejor) then
				mejor, mejorParte = altura, parte
			end
		end
	end
	if mejor then
		return { Position = Vector3.new(origen.X, mejor, origen.Z), Instance = mejorParte, Normal = Vector3.new(0, 1, 0) }
	end
	return nil
end)

type Solida = { parte: any, c: Vector3, e: Vector3 }
local estaticas: { Solida } = {}
local estaticasToque: { Solida } = {}

local function anotarEstaticas(carpeta)
	for _, d in carpeta:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored then
			local c, e = extension(d)
			if d.CanCollide then
				table.insert(estaticas, { parte = d, c = c, e = e })
			end
			if d.CanTouch then
				table.insert(estaticasToque, { parte = d, c = c, e = e })
			end
		end
	end
end

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
	-- Los empujones del juego son una LinearVelocity dentro del personaje.
	local empujon = raiz:FindFirstChild("Empujon")
	if empujon and empujon:IsA("LinearVelocity") then
		v = empujon.VectorVelocity
	end
	local gravedad = workspace.Gravity * (if raiz:FindFirstChild("Globo") then 0.35 else 1)

	local arena = workspace:FindFirstChild("Arena")
	local enArena = arena ~= nil and (pos - ARENA).Magnitude < 400
	local entrada = Vector3.zero
	if not humanoide.PlatformStand and humanoide.WalkSpeed > 0 then
		local esCarrera = arena and (arena:FindFirstChild("CintaLoca") or arena:FindFirstChild("Rampa") or arena:FindFirstChild("Campo"))
		if math.random() < 0.8 * dt then
			local angulo = math.random() * math.pi * 2
			estado.dir = Vector3.new(math.cos(angulo), 0, math.sin(angulo))
			if enArena and esCarrera then
				estado.dir = Vector3.new(estado.dir.X * 0.4, 0, 1).Unit
			elseif enArena then
				local hacia = Vector3.new(ARENA.X - pos.X, 0, ARENA.Z - pos.Z)
				if hacia.Magnitude > 18 and math.random() < 0.7 then
					estado.dir = hacia.Unit
				end
			end
		end
		-- Algunos bots son "listos" en Color Loco y Sillas Musicales.
		if estado.listo == nil then
			estado.listo = math.random() < 0.65
		end
		if enArena and arena and estado.listo then
			local objetivo = nil
			local colores = arena:FindFirstChild("Colores")
			local seguro = colores and colores:GetAttribute("Seguro")
			local sillas = arena:FindFirstChild("Sillas")
			local mejorD = math.huge
			if seguro and seguro ~= 0 then
				for _, b in colores:GetChildren() do
					if b:GetAttribute("Indice") == seguro then
						local d = Vector3.new(b.CFrame.Position.X - pos.X, 0, b.CFrame.Position.Z - pos.Z).Magnitude
						if d < mejorD then
							objetivo, mejorD = b, d
						end
					end
				end
			elseif sillas then
				for _, d in sillas:GetDescendants() do
					if d.Name == "Silla" and d:GetAttribute("Libre") then
						local dist = Vector3.new(d.CFrame.Position.X - pos.X, 0, d.CFrame.Position.Z - pos.Z).Magnitude
						if dist < mejorD then
							objetivo, mejorD = d, dist
						end
					end
				end
			end
			if objetivo then
				local hacia = Vector3.new(objetivo.CFrame.Position.X - pos.X, 0, objetivo.CFrame.Position.Z - pos.Z)
				estado.dir = if hacia.Magnitude > 1.2 then hacia.Unit else Vector3.zero
			end
		end
		entrada = estado.dir * humanoide.WalkSpeed
	end

	v = v - Vector3.new(0, gravedad * dt, 0)
	local nueva = pos + (v + entrada) * dt

	-- Paredes
	local cuerpoE = Vector3.new(0.9, 1.6, 0.9)
	local cuerpoNuevo, cuerpoViejo = nueva + Vector3.new(0, 0.6, 0), pos + Vector3.new(0, 0.6, 0)
	for _, s in solidas do
		if solapan(cuerpoNuevo, cuerpoE, s.c, s.e) and not solapan(cuerpoViejo, cuerpoE, s.c, s.e) then
			local arriba = alturaSuperficie(s.parte, nueva.X, nueva.Z, nueva.Y + 60)
			if not (arriba ~= nil and arriba <= nueva.Y - 3 + 1.6) then
				nueva = Vector3.new(pos.X, nueva.Y, pos.Z)
				estado.dir = -estado.dir
				break
			end
		end
	end

	-- Suelo (5 puntos bajo los pies). Los personajes escalados son más altos o bajos.
	local alto = 3 * (personaje:GetAttribute("EscalaSimulada") or 1)
	local piesAntes, piesNuevos = pos.Y - alto, nueva.Y - alto
	local avance = Vector3.new(nueva.X - pos.X, 0, nueva.Z - pos.Z).Magnitude
	local desde = piesAntes + 1.2 + avance * 0.6
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
		nueva = Vector3.new(nueva.X, mejor + alto, nueva.Z)
		v = Vector3.new(v.X * 0.5, 0, v.Z * 0.5)
	end
	raiz.AssemblyLinearVelocity = v
	personaje:PivotTo(CFrame.new(nueva) * (raiz.CFrame - raiz.CFrame.Position))

	-- Toques (lava, trampolines...)
	local toca = {}
	for _, s in tocables do
		if solapan(nueva, Vector3.new(1.2, 3.2, 1.2), s.c, s.e) then
			toca[s.parte] = true
			if not estado.tocando[s.parte] then
				senalDe(s.parte, "Touched"):Fire(raiz)
			end
		end
	end
	estado.tocando = toca

	-- Trucos de bot: llegar a la meta en carreras, subir a la cima del rey...
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
		local cima = arena:FindFirstChild("Piso3")
		if cima and humanoide.WalkSpeed > 0 and math.random() < 0.1 * dt then
			personaje:PivotTo(CFrame.new(cima.CFrame.Position + Vector3.new(math.random(-4, 4), 4, math.random(-4, 4))))
		end
	else
		metaPara[jugador] = nil
	end
end

-- Mueve lo suelto de la arena (barras con motor, bolas, rocas que caen).
local function moverMundo(dt: number)
	for _, carpeta in { workspace:FindFirstChild("Arena"), workspace:FindFirstChild("Lobby") } do
		for _, d in carpeta and carpeta:GetDescendants() or {} do
			if d:IsA("BasePart") and not d.Anchored and not d:FindFirstAncestorOfClass("Model") then
				local bisagra = d:FindFirstChildOfClass("HingeConstraint")
				if bisagra then
					local centro = d.CFrame.Position
					d.CFrame = CFrame.new(centro) * CFrame.Angles(0, bisagra.AngularVelocity * dt, 0) * (d.CFrame - centro)
				elseif d.Name == "Bola" then
					d.CFrame = d.CFrame + Vector3.new(0, -0.2126, -1) * 30 * dt
				else
					d.CFrame = d.CFrame + Vector3.new(0, -40 * dt, 0)
				end
			end
		end
	end
end

-- ===================================================================
-- Ejecutar el script del juego
-- ===================================================================

-- Lune no calcula BasePart.Position ni AssemblyMass. Para la simulación,
-- cambiamos sus LECTURAS por funciones que sí lo hacen.
local function posicionDe(x)
	if typeof(x) == "Instance" and x:IsA("BasePart") then
		return x.CFrame.Position
	end
	return x.Position
end
local function masaDe(_x)
	return 15
end

local function adaptar(fuente: string): string
	fuente = string.gsub(fuente, "([%a_][%w_%.]*)%.Position(%s*=?=?)", function(receptor, sufijo)
		if string.match(sufijo, "^%s*=$") then
			return nil -- es una asignación: se deja igual
		end
		return "__posicion(" .. receptor .. ")" .. sufijo
	end)
	fuente = string.gsub(fuente, "([%a_][%w_%.]*)%.AssemblyMass", "__masa(%1)")
	-- Partida de prueba con más rondas para ver muchos minijuegos.
	fuente = string.gsub(fuente, "RONDAS_POR_PARTIDA = %d+,", "RONDAS_POR_PARTIDA = " .. RONDAS .. ",", 1)
	return fuente
end

local entorno = {
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
	TweenInfo = TweenInfoFalso,
	OverlapParams = ParamsFalsos,
	RaycastParams = ParamsFalsos,
	task = tareas,
	os = osVirtual,
	math = math,
	string = string,
	table = table,
	coroutine = coroutine,
	utf8 = utf8,
	debug = debug,
	print = function(...)
		local partes = {}
		for _, x in { ... } do
			table.insert(partes, tostring(x))
		end
		table.insert(registro, "PRINT " .. table.concat(partes, " "))
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
	ipairs = ipairs,
	pairs = pairs,
	next = next,
	__posicion = posicionDe,
	__masa = masaDe,
}

print("🧪 Simulando LOCURA TOTAL a velocidad x" .. ACELERACION .. " (" .. RONDAS .. " rondas)...")

local script = game:GetService("ServerScriptService"):FindFirstChild("LocuraTotal")
assert(script, "No encuentro ServerScriptService.LocuraTotal en " .. RUTA)
entorno.script = script
local funcion = luau.load(adaptar(script.Source), { debugName = "LocuraTotal", environment = entorno })
tareas.spawn(funcion)
tareas.wait(1)

assert(workspace:FindFirstChild("Lobby"), "No se construyó el lobby")
assert(workspace:FindFirstChild("Grada"), "No se construyó la grada")
anotarEstaticas(workspace.Lobby)
anotarEstaticas(workspace.Grada)
anotarEstaticas(carpetaTerreno)
print(string.format("🏝️ Lobby: %d objetos · 👀 Grada: %d objetos", #workspace.Lobby:GetDescendants(), #workspace.Grada:GetDescendants()))

-- 9 jugadores: el noveno debería ser expulsado (máximo 8).
local lista = {}
for i = 1, 9 do
	local jugador = Instance.new("Player")
	jugador.Name = NOMBRES_BOTS[i]
	jugador.DisplayName = jugador.Name
	jugador.UserId = 1000 + i
	Instance.new("Backpack").Parent = jugador
	Instance.new("PlayerGui").Parent = jugador
	jugador.Parent = Players
	table.insert(lista, jugador)
	senalDe(Players, "PlayerAdded"):Fire(jugador)
	tareas.wait(0.2)
end
local pepito = lista[1]

-- ===================================================================
-- Motores: Heartbeat, física, y lo que hacen los bots
-- ===================================================================

local salir = false
local ultimo = reloj()
task.spawn(function()
	while not salir do
		task.wait(1 / 120)
		local ahora = reloj()
		local dt = math.min(ahora - ultimo, 0.3)
		ultimo = ahora
		avisarEtiquetasNuevas()
		senalDe(game:GetService("RunService"), "Heartbeat"):Fire(dt)
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
			salir = true
		end
	end
end)

-- Lo que ve Pepito en su pantalla (para el registro de la partida).
local function etiquetaDe(gui, ruta: { string })
	local actual = gui
	for _, nombre in ruta do
		actual = actual and actual:FindFirstChild(nombre)
	end
	return actual
end

local rondasJugadas: { string } = {}
local campeonVisto = false
local votosGanados = 0
local enGrada = 0
local textosFeed: { string } = {}
task.spawn(function()
	local ultimoAnuncio, ultimoResultado = "", ""
	local vistos = setmetatable({}, { __mode = "k" })
	while not salir do
		tareas.wait(0.1)
		local gui = pepito:FindFirstChild("PlayerGui") and pepito.PlayerGui:FindFirstChild("LocuraUI")
		if gui then
			local t = string.format("[%6.1f] ", reloj())
			local anuncio = etiquetaDe(gui, { "Anuncio" })
			local sub = etiquetaDe(gui, { "Subtitulo" })
			if anuncio and anuncio.TextTransparency < 0.5 and anuncio.Text ~= ultimoAnuncio then
				ultimoAnuncio = anuncio.Text
				local s = if sub and sub.Text ~= "" then " — " .. sub.Text else ""
				table.insert(registro, t .. "📢 " .. anuncio.Text .. s)
				if string.find(anuncio.Text, "CAMPEÓN", 1, true) then
					campeonVisto = true
				end
				if string.find(s, "Ganó la votación", 1, true) then
					votosGanados += 1
				end
			end
			local feed = etiquetaDe(gui, { "Feed" })
			if feed then
				for _, hijo in feed:GetChildren() do
					if hijo:IsA("TextLabel") and not vistos[hijo] then
						vistos[hijo] = true
						table.insert(registro, t .. "   " .. hijo.Text)
						table.insert(textosFeed, hijo.Text)
					end
				end
			end
			local resultados = etiquetaDe(gui, { "Resultados" })
			local titulo = etiquetaDe(gui, { "Resultados", "Titulo" })
			if resultados and resultados.Visible and titulo and titulo.Text .. #rondasJugadas ~= ultimoResultado then
				tareas.wait(0.05)
				ultimoResultado = titulo.Text .. (#rondasJugadas + 1)
				table.insert(rondasJugadas, titulo.Text)
				local filas = {}
				for _, fila in resultados.Lista:GetChildren() do
					if fila:IsA("Frame") then
						local textos = {}
						for _, e in fila:GetChildren() do
							if e:IsA("TextLabel") then
								table.insert(textos, (string.gsub(e.Text, "<[^>]+>", "")))
							end
						end
						table.insert(filas, { orden = fila.LayoutOrder, texto = table.concat(textos, " ") })
					end
				end
				table.sort(filas, function(a, b)
					return a.orden < b.orden
				end)
				local partes = {}
				for _, f in filas do
					table.insert(partes, f.texto)
				end
				table.insert(registro, t .. titulo.Text .. ": " .. table.concat(partes, " | "))
			end
			-- ¿Votación? Algunos bots se suben a las plataformas.
			local estadoTexto = etiquetaDe(gui, { "Barra", "Estado" })
			if estadoTexto and string.find(estadoTexto.Text, "vota", 1, true) and math.random() < 0.15 then
				local quien = lista[math.random(1, 8)]
				local plataforma = workspace.Lobby:FindFirstChild("Voto" .. math.random(1, 3))
				if quien.Character and quien.Parent == Players and plataforma then
					quien.Character:PivotTo(CFrame.new(plataforma.CFrame.Position + Vector3.new(math.random(-3, 3), 3.5, math.random(-3, 3))))
				end
			end
		end
		for jugador in bots do
			local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
			if raiz and (raiz.CFrame.Position - GRADA).Magnitude < 90 then
				enGrada += 1
			end
		end
	end
end)

-- Los bots hacen clic con el martillo y, a veces, pulsan el botón rojo.
local clics, botonazos = 0, 0
task.spawn(function()
	local aviso = workspace.Lobby:FindFirstChild("BotonRojo", true):FindFirstChildOfClass("ProximityPrompt")
	while not salir do
		tareas.wait(0.6)
		for jugador in bots do
			local personaje = jugador.Character
			local herramienta = personaje and personaje:FindFirstChildOfClass("Tool")
			if herramienta and math.random() < 0.6 then
				clics += 1
				senalDe(herramienta, "Activated"):Fire()
			end
		end
		if math.random() < 0.04 then
			botonazos += 1
			senalDe(aviso, "Triggered"):Fire(lista[math.random(1, 8)])
		end
	end
end)

-- A mitad de partida, Kiko se va del juego.
local seFue = false
task.spawn(function()
	while #rondasJugadas < 3 do
		task.wait(0.05)
	end
	tareas.wait(30)
	local kiko = lista[5]
	senalDe(Players, "PlayerRemoving"):Fire(kiko)
	if kiko.Character then
		kiko.Character:Destroy()
	end
	kiko.Parent = nil
	bots[kiko] = nil
	seFue = true
	table.insert(registro, string.format("[%6.1f] 🚪 Kiko se fue del juego", reloj()))
end)

while reloj() < LIMITE_VIRTUAL and not salir do
	task.wait(0.1)
	if campeonVisto then
		tareas.wait(22)
		break
	end
end
salir = true

-- ===================================================================
-- Informe
-- ===================================================================

print("\n================ 📜 LO QUE PASÓ EN LA PARTIDA ================")
for _, linea in registro do
	print(linea)
end

local function feedContiene(trozo: string): boolean
	for _, t in textosFeed do
		if string.find(t, trozo, 1, true) then
			return true
		end
	end
	return false
end

local comprobaciones = {}
local function comprobar(nombre: string, ok: boolean, detalle: string?, opcional: boolean?)
	table.insert(comprobaciones, { nombre = nombre, ok = ok, detalle = detalle, opcional = opcional })
end

local distintos, numDistintos = {}, 0
for _, t in rondasJugadas do
	if not distintos[t] then
		distintos[t] = true
		numDistintos += 1
	end
end
comprobar("Se jugaron todas las rondas", #rondasJugadas == RONDAS, tostring(#rondasJugadas))
comprobar("Muchos minijuegos distintos", numDistintos >= math.min(RONDAS, 11), tostring(numDistintos))
comprobar("Hubo ceremonia de campeón", campeonVisto)
comprobar("El 9º jugador fue expulsado (máx. 8)", #expulsados == 1, table.concat(expulsados, "; "))
comprobar("Un jugador se fue a mitad y el juego siguió", seFue)
comprobar("La gravedad volvió a la normalidad", math.abs(workspace.Gravity - 196.2) < 0.01, tostring(workspace.Gravity))
comprobar("La arena se borró al final", workspace:FindFirstChild("Arena") == nil)
comprobar("Hubo votaciones con votos", votosGanados > 0, tostring(votosGanados))
comprobar("Los eliminados fueron a la grada", enGrada > 0)
comprobar("Alguien cogió una caja sorpresa", feedContiene("cogió ⚡") or feedContiene("cogió 🦘") or feedContiene("cogió 🛡") or feedContiene("cogió 💥") or feedContiene("cogió 🎈"))
comprobar("Alguien pulsó el botón rojo", feedContiene("pulsó el botón rojo"), tostring(botonazos) .. " intentos")
comprobar("Hubo eliminaciones con mérito", feedContiene("eliminó a"), nil, true)
local spawnsFuera = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("SpawnLocation") and d.Enabled and not d:IsDescendantOf(workspace.Lobby) then
		spawnsFuera += 1
	end
end
comprobar("No queda el Baseplate de la plantilla", workspace:FindFirstChild("Baseplate") == nil)
comprobar("Solo se aparece en el lobby", spawnsFuera == 0, tostring(spawnsFuera))
comprobar("Hubo premios al final", feedContiene("🏅"))

local coronas, todosACero, niveles = 0, true, 0
for _, jugador in Players:GetPlayers() do
	local stats = jugador:FindFirstChild("leaderstats")
	if stats then
		coronas += stats.Coronas.Value
		niveles += stats.Nivel.Value
		if stats.Puntos.Value ~= 0 then
			todosACero = false
		end
	end
end
comprobar("El campeón ganó una corona", coronas >= 1, tostring(coronas))
comprobar("Los jugadores subieron de nivel", niveles > #Players:GetPlayers(), tostring(niveles))
comprobar("Los puntos se reiniciaron tras la ceremonia", todosACero)
comprobar("Los bots usaron el Martillo Loco", clics > 0, tostring(clics) .. " clics")
comprobar("Sin errores de Lua", #errores == 0, tostring(#errores))
comprobar("Sin avisos (warn)", #avisos == 0, tostring(#avisos))

print("\n================ ✅ COMPROBACIONES ================")
local fallos = 0
for _, c in comprobaciones do
	local icono = if c.ok then "✅ " elseif c.opcional then "⚠️  " else "❌ "
	print(icono .. c.nombre .. (if c.detalle then "  (" .. c.detalle .. ")" else "") .. (if not c.ok and c.opcional then " (depende del azar)" else ""))
	if not c.ok and not c.opcional then
		fallos += 1
	end
end
print("\n🎲 Minijuegos jugados:")
for t in distintos do
	print("   " .. t)
end
if next(destruidos) ~= nil then
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
