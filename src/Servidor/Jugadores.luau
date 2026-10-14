--!strict
-- 👥 Gestión de jugadores: entrar, salir, aparecer, puntos y coronas guardadas.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Compartido.Config)

local Jugadores = {}

-- Jugadores que están ahora mismo dentro de un minijuego.
Jugadores.EnRonda = {} :: { [Player]: boolean }

local cargando: { [Player]: boolean } = {}

-- Guardado de coronas (solo funciona si el juego está publicado y
-- "Enable Studio Access to API Services" está activado; si no, se ignora).
local almacen: DataStore? = nil
do
	local ok, resultado = pcall(function()
		return DataStoreService:GetDataStore("LocuraTotal_Coronas_v1")
	end)
	if ok then
		almacen = resultado
	end
end

local function clave(jugador: Player): string
	return "jugador_" .. jugador.UserId
end

local function valor(jugador: Player, nombre: string): IntValue?
	local stats = jugador:FindFirstChild("leaderstats")
	if not stats then
		return nil
	end
	local v = stats:FindFirstChild(nombre)
	if v and v:IsA("IntValue") then
		return v
	end
	return nil
end

local function guardar(jugador: Player)
	local tienda = almacen
	local coronas = valor(jugador, "Coronas")
	if not tienda or not coronas then
		return
	end
	local cantidad = coronas.Value
	local ok, err = pcall(function()
		tienda:SetAsync(clave(jugador), cantidad)
	end)
	if not ok then
		warn("[LocuraTotal] No se pudieron guardar las coronas:", err)
	end
end

local function cargar(jugador: Player)
	local tienda = almacen
	local coronas = valor(jugador, "Coronas")
	if not tienda or not coronas then
		return
	end
	local ok, resultado = pcall(function()
		return tienda:GetAsync(clave(jugador))
	end)
	if ok and typeof(resultado) == "number" then
		coronas.Value = resultado
	end
end

-- ===== Consultas útiles =====

function Jugadores.Humanoide(jugador: Player): Humanoid?
	local personaje = jugador.Character
	if not personaje then
		return nil
	end
	return personaje:FindFirstChildOfClass("Humanoid")
end

function Jugadores.Raiz(jugador: Player): BasePart?
	local personaje = jugador.Character
	if not personaje then
		return nil
	end
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if raiz and raiz:IsA("BasePart") then
		return raiz
	end
	return nil
end

function Jugadores.EstaVivo(jugador: Player): boolean
	local humanoide = Jugadores.Humanoide(jugador)
	return humanoide ~= nil and humanoide.Health > 0 and Jugadores.Raiz(jugador) ~= nil
end

-- Jugadores con el personaje vivo y listo para jugar.
function Jugadores.Listos(): { Player }
	local lista = {}
	for _, jugador in Players:GetPlayers() do
		if Jugadores.EstaVivo(jugador) and not cargando[jugador] then
			table.insert(lista, jugador)
		end
	end
	return lista
end

-- Vuelve a crear el personaje del jugador en el lobby.
function Jugadores.Reaparecer(jugador: Player)
	if cargando[jugador] or jugador.Parent ~= Players then
		return
	end
	cargando[jugador] = true
	task.spawn(function()
		-- LoadCharacterAsync es la versión nueva; si no existe, usamos la clásica.
		local ok, err = pcall(function()
			(jugador :: any):LoadCharacterAsync()
		end)
		if not ok and jugador.Parent == Players and not jugador.Character then
			ok, err = pcall(function()
				(jugador :: any):LoadCharacter()
			end)
		end
		if not ok then
			warn("[LocuraTotal] Error al reaparecer:", err)
		end
		cargando[jugador] = nil
	end)
end

-- ===== Puntos y coronas =====

function Jugadores.SumarPuntos(jugador: Player, cantidad: number)
	local puntos = valor(jugador, "Puntos")
	if puntos then
		puntos.Value += cantidad
	end
end

function Jugadores.Puntos(jugador: Player): number
	local puntos = valor(jugador, "Puntos")
	return if puntos then puntos.Value else 0
end

function Jugadores.ReiniciarPuntos()
	for _, jugador in Players:GetPlayers() do
		local puntos = valor(jugador, "Puntos")
		if puntos then
			puntos.Value = 0
		end
	end
end

function Jugadores.SumarCorona(jugador: Player)
	local coronas = valor(jugador, "Coronas")
	if coronas then
		coronas.Value += 1
		task.spawn(guardar, jugador)
	end
end

-- ===== Eventos =====

local function alAparecer(jugador: Player, personaje: Model)
	local encontrado = personaje:WaitForChild("Humanoid", 10)
	if not encontrado or not encontrado:IsA("Humanoid") then
		return
	end
	local humanoide = encontrado :: Humanoid
	humanoide.UseJumpPower = true
	humanoide.JumpPower = Config.SALTO_BASE
	humanoide.WalkSpeed = Config.VELOCIDAD_BASE

	humanoide.Died:Connect(function()
		task.wait(Config.TIEMPO_REAPARECER)
		if jugador.Parent == Players and jugador.Character == personaje then
			Jugadores.Reaparecer(jugador)
		end
	end)
end

local function alEntrar(jugador: Player)
	if #Players:GetPlayers() > Config.MAX_JUGADORES then
		jugador:Kick(`¡Servidor lleno! Este juego es para {Config.MAX_JUGADORES} locos como máximo. Prueba otro servidor.`)
		return
	end

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local puntos = Instance.new("IntValue")
	puntos.Name = "Puntos"
	puntos.Parent = stats
	local coronas = Instance.new("IntValue")
	coronas.Name = "Coronas"
	coronas.Parent = stats
	stats.Parent = jugador

	jugador.CharacterAdded:Connect(function(personaje)
		alAparecer(jugador, personaje)
	end)
	if jugador.Character then
		task.spawn(alAparecer, jugador, jugador.Character)
	else
		Jugadores.Reaparecer(jugador)
	end

	task.spawn(cargar, jugador)
end

function Jugadores.Iniciar()
	-- Nosotros decidimos cuándo aparece cada personaje.
	Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end

	Players.PlayerRemoving:Connect(function(jugador)
		Jugadores.EnRonda[jugador] = nil
		cargando[jugador] = nil
		guardar(jugador)
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, jugador in Players:GetPlayers() do
			guardar(jugador)
		end
	end)

	-- Si alguien se cae de la isla del lobby, vuelve a aparecer.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, jugador in Players:GetPlayers() do
				if not Jugadores.EnRonda[jugador] then
					local raiz = Jugadores.Raiz(jugador)
					if raiz and raiz.Position.Y < Config.ALTURA_VACIO_LOBBY then
						Jugadores.Reaparecer(jugador)
					end
				end
			end
		end
	end)
end

return Jugadores
