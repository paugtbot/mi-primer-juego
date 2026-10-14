--!strict
-- 🏝️ EL LOBBY: isla flotante con pista de baile, trampolines, cañón humano,
-- podio de campeones y una isla secreta. Todo se construye con código.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Compartido.Config)
local C = require(script.Parent.Constructor)

local Lobby = {}

local L = Config.LOBBY_CENTRO

-- Posiciones (superficie) del podio: [1] oro, [2] plata, [3] bronce.
Lobby.Podio = {
	L + Vector3.new(0, 6, -40),
	L + Vector3.new(-9, 4, -40),
	L + Vector3.new(9, 2.5, -40),
} :: { Vector3 }

local function construirLuces()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	if Lighting:FindFirstChild("AtmosferaLoca") then
		return -- ya estaban puestas (vienen en el archivo del juego)
	end

	local atmosfera = Instance.new("Atmosphere")
	atmosfera.Name = "AtmosferaLoca"
	atmosfera.Density = 0.28
	atmosfera.Offset = 0.2
	atmosfera.Color = Color3.fromRGB(220, 190, 255)
	atmosfera.Decay = Color3.fromRGB(120, 100, 170)
	atmosfera.Glare = 0.3
	atmosfera.Haze = 1.2
	atmosfera.Parent = Lighting

	local resplandor = Instance.new("BloomEffect")
	resplandor.Name = "BrilloLoco"
	resplandor.Intensity = 0.7
	resplandor.Size = 28
	resplandor.Threshold = 1.6
	resplandor.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "ColoresLocos"
	color.Saturation = 0.2
	color.Contrast = 0.05
	color.Parent = Lighting
end

local function construirIsla(centro: Vector3, radio: number, padre: Instance)
	C.Disco(centro, radio, 8, {
		Name = "Cesped",
		Color = Color3.fromRGB(96, 200, 96),
		Material = Enum.Material.Grass,
		Parent = padre,
	})
	-- Roca de debajo (forma de isla flotante).
	local capas = { { 0.9, 10 }, { 0.72, 12 }, { 0.5, 14 }, { 0.26, 16 } }
	local y = centro.Y - 8
	for _, capa in capas do
		C.Disco(Vector3.new(centro.X, y, centro.Z), radio * capa[1], capa[2], {
			Name = "Roca",
			Color = Color3.fromRGB(120, 92, 70),
			Material = Enum.Material.Rock,
			Parent = padre,
		})
		y -= capa[2]
	end
end

local function construirSpawns(padre: Instance)
	for i = 1, 8 do
		local angulo = math.rad((i - 1) * 45 + 22.5)
		local posicion = L + Vector3.new(math.cos(angulo) * 27, 0, math.sin(angulo) * 27)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.AllowTeamChangeOnTouch = false
		spawn.Duration = 0
		spawn.Size = Vector3.new(7, 1, 7)
		spawn.CFrame = CFrame.lookAt(posicion, Vector3.new(L.X, posicion.Y, L.Z))
		spawn.Color = Config.COLORES[i]
		spawn.Material = Enum.Material.Neon
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = padre
	end
end

local function construirPistaDisco(padre: Instance)
	local lado = 7
	local tam = 4
	for x = 1, lado do
		for z = 1, lado do
			local px = (x - (lado + 1) / 2) * tam
			local pz = (z - (lado + 1) / 2) * tam
			C.Parte({
				Name = "Baldosa",
				Size = Vector3.new(tam - 0.15, 0.4, tam - 0.15),
				CFrame = CFrame.new(L + Vector3.new(px, 0, pz)),
				Color = Config.COLORES[math.random(1, #Config.COLORES)],
				Material = Enum.Material.Neon,
				Tags = { "Disco" },
				Parent = padre,
			})
		end
	end
	-- Bola de discoteca girando encima.
	local bola = C.Bola(L + Vector3.new(0, 26, 0), 7, {
		Name = "BolaDisco",
		Color = Color3.fromRGB(230, 230, 255),
		Material = Enum.Material.Foil,
		Reflectance = 0.6,
		CanCollide = false,
		Tags = { "Girar" },
		Atributos = { VelocidadGiro = 1.5 },
		Parent = padre,
	})
	C.Luz(bola, Color3.fromRGB(255, 120, 255), 3, 40)
	C.Parte({
		Name = "Cuerda",
		Size = Vector3.new(0.2, 40, 0.2),
		CFrame = CFrame.new(L + Vector3.new(0, 49.5, 0)),
		Color = Color3.fromRGB(40, 40, 40),
		CanCollide = false,
		Parent = padre,
	})
end

local function construirCarteles(padre: Instance)
	-- Cartel gigante del título.
	local tablero = C.Parte({
		Name = "Titulo",
		Size = Vector3.new(66, 18, 2),
		CFrame = CFrame.new(L + Vector3.new(0, 28, -62)) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(30, 20, 50),
		Parent = padre,
	})
	local titulo = C.Cartel(tablero, Enum.NormalId.Front, Config.NOMBRE_JUEGO, Color3.new(1, 1, 1), 20)
	local degradado = Instance.new("UIGradient")
	degradado.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.COLORES[1]),
		ColorSequenceKeypoint.new(0.2, Config.COLORES[2]),
		ColorSequenceKeypoint.new(0.4, Config.COLORES[3]),
		ColorSequenceKeypoint.new(0.6, Config.COLORES[4]),
		ColorSequenceKeypoint.new(0.8, Config.COLORES[5]),
		ColorSequenceKeypoint.new(1, Config.COLORES[7]),
	})
	degradado.Parent = titulo
	degradado:AddTag("ArcoIris")

	local subtitulo = C.Parte({
		Name = "Subtitulo",
		Size = Vector3.new(50, 5, 1),
		CFrame = CFrame.new(L + Vector3.new(0, 16, -61)) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(255, 71, 87),
		Material = Enum.Material.Neon,
		Parent = padre,
	})
	C.Cartel(subtitulo, Enum.NormalId.Front, "8 JUGADORES · 8 MINIJUEGOS · 0 PIEDAD", Color3.new(1, 1, 1), 20)

	for _, x in { -30, 30 } do
		C.Parte({
			Name = "Poste",
			Size = Vector3.new(2, 38, 2),
			CFrame = CFrame.new(L + Vector3.new(x, 19, -63)),
			Color = Color3.fromRGB(60, 40, 90),
			Parent = padre,
		})
	end

	-- Cartel de instrucciones.
	local posicion = L + Vector3.new(-52, 9, -22)
	local reglas = C.Parte({
		Name = "ComoSeJuega",
		Size = Vector3.new(26, 16, 1),
		CFrame = CFrame.lookAt(posicion, Vector3.new(L.X, posicion.Y, L.Z)), -- la cara Front mira al centro
		Color = Color3.fromRGB(20, 20, 35),
		Parent = padre,
	})
	local texto = C.Cartel(
		reglas,
		Enum.NormalId.Front,
		"¿CÓMO SE JUEGA?\n\n🎲 La ruleta elige un minijuego loco\n🌀 ...y un MODO LOCO\n🏃 ¡Sobrevive, empuja y corre!\n🏆 Ganas puntos según tu puesto\n👑 Tras 6 rondas: ¡CAMPEÓN!",
		Color3.fromRGB(255, 221, 89),
		20
	)
	texto.TextXAlignment = Enum.TextXAlignment.Center

	-- Cartel de controles.
	local posicion2 = L + Vector3.new(52, 9, -22)
	local controles = C.Parte({
		Name = "Controles",
		Size = Vector3.new(26, 16, 1),
		CFrame = CFrame.lookAt(posicion2, Vector3.new(L.X, posicion2.Y, L.Z)),
		Color = Color3.fromRGB(20, 20, 35),
		Parent = padre,
	})
	C.Cartel(
		controles,
		Enum.NormalId.Front,
		"TRUCOS\n\n🦘 Trampolines: ¡salta en los rosas!\n🚀 Cañón humano: ¡vuela a la isla secreta!\n🔨 Martillo: haz clic para empujar\n👀 Si te eliminan: botón ESPECTAR",
		Color3.fromRGB(0, 210, 211),
		20
	)

	for _, p in { posicion, posicion2 } do
		C.Parte({
			Name = "Pata",
			Size = Vector3.new(1.5, 9, 1.5),
			CFrame = CFrame.new(Vector3.new(p.X, L.Y + 0.5, p.Z)),
			Color = Color3.fromRGB(60, 40, 90),
			Parent = padre,
		})
	end
end

local function construirPodio(padre: Instance)
	local colores = {
		Color3.fromRGB(255, 205, 40),
		Color3.fromRGB(200, 205, 215),
		Color3.fromRGB(205, 127, 50),
	}
	for i, arriba in Lobby.Podio do
		local alto = arriba.Y - L.Y
		local bloque = C.Parte({
			Name = "Podio" .. i,
			Size = Vector3.new(8, alto, 8),
			CFrame = CFrame.new(arriba - Vector3.new(0, alto / 2, 0)) * CFrame.Angles(0, math.pi, 0),
			Color = colores[i],
			Material = Enum.Material.SmoothPlastic,
			Parent = padre,
		})
		C.Cartel(bloque, Enum.NormalId.Front, tostring(i), Color3.new(1, 1, 1), 20)
	end
end

local function construirTrampolines(padre: Instance)
	for i = 0, 3 do
		local angulo = math.rad(i * 90 + 45)
		local centro = L + Vector3.new(math.cos(angulo) * 52, 0, math.sin(angulo) * 52)
		C.Disco(centro + Vector3.new(0, 0.8, 0), 6, 0.8, {
			Name = "BordeTrampolin",
			Color = Color3.fromRGB(30, 30, 30),
			Parent = padre,
		})
		local cama = C.Disco(centro + Vector3.new(0, 1.1, 0), 5, 0.4, {
			Name = "Trampolin",
			Color = Color3.fromRGB(255, 107, 203),
			Material = Enum.Material.Neon,
			Tags = { "Impulso" },
			Atributos = { Impulso = Vector3.new(0, 150, 0) },
			Parent = padre,
		})
		C.Flotante(cama, "🦘", 3, 3, Vector3.new(0, 4, 0))
	end
end

local ISLA_SECRETA = L + Vector3.new(205, 0, 0)

local function construirCanon(desde: Vector3, haciaX: number, padre: Instance)
	local base = C.Disco(desde + Vector3.new(0, 0.6, 0), 4.5, 0.6, {
		Name = "Canon",
		Color = Color3.fromRGB(255, 165, 2),
		Material = Enum.Material.Neon,
		Tags = { "Impulso" },
		Atributos = { Impulso = Vector3.new(130 * haciaX, 120, 0), Vuelo = 1.1 },
		Parent = padre,
	})
	-- Tubo decorativo inclinado.
	C.Parte({
		Name = "TuboCanon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 4, 4),
		CFrame = CFrame.new(desde + Vector3.new(-5 * haciaX, 3, 0)) * CFrame.Angles(0, 0, math.rad(if haciaX > 0 then 40 else 140)),
		Color = Color3.fromRGB(50, 50, 60),
		Material = Enum.Material.Metal,
		Parent = padre,
	})
	C.Flotante(base, "🚀 CAÑÓN HUMANO", 2, 10, Vector3.new(0, 6, 0), Color3.fromRGB(255, 165, 2))
end

local function construirIslaSecreta(padre: Instance)
	construirIsla(ISLA_SECRETA, 26, padre)
	-- Estatua de corona dorada.
	C.Parte({
		Name = "Pedestal",
		Size = Vector3.new(6, 4, 6),
		CFrame = CFrame.new(ISLA_SECRETA + Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Marble,
		Parent = padre,
	})
	local corona = C.Disco(ISLA_SECRETA + Vector3.new(0, 7, 0), 3, 3, {
		Name = "CoronaSecreta",
		Color = Color3.fromRGB(255, 205, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Tags = { "Girar" },
		Atributos = { VelocidadGiro = 1 },
		Parent = padre,
	})
	C.Luz(corona, Color3.fromRGB(255, 205, 40), 4, 30)
	C.Flotante(corona, "🏝️ ¡ENCONTRASTE LA ISLA SECRETA!", 2, 14, Vector3.new(0, 6, 0), Color3.fromRGB(255, 221, 89))
	construirCanon(ISLA_SECRETA + Vector3.new(-14, 0, 0), -1, padre)
end

local function construirDecoracion(padre: Instance)
	-- Pilares de neón alrededor de la isla.
	for i = 1, 8 do
		local angulo = math.rad((i - 1) * 45)
		local posicion = L + Vector3.new(math.cos(angulo) * 70, 0, math.sin(angulo) * 70)
		local pilar = C.Parte({
			Name = "Pilar",
			Size = Vector3.new(2.5, 14, 2.5),
			CFrame = CFrame.new(posicion + Vector3.new(0, 7, 0)),
			Color = Config.COLORES[i],
			Material = Enum.Material.Neon,
			Parent = padre,
		})
		C.Luz(pilar, Config.COLORES[i], 2, 20)
	end
	-- Dados gigantes flotando y girando.
	for i = 1, 6 do
		local angulo = math.rad(i * 60 + 15)
		local radio = 40 + (i % 2) * 15
		C.Parte({
			Name = "DadoLoco",
			Size = Vector3.new(5, 5, 5),
			CFrame = CFrame.new(L + Vector3.new(math.cos(angulo) * radio, 22 + (i % 3) * 6, math.sin(angulo) * radio))
				* CFrame.Angles(math.rad(45), math.rad(i * 20), 0),
			Color = Config.COLORES[(i % #Config.COLORES) + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
			Tags = { "Girar" },
			Atributos = { VelocidadGiro = 0.6 + i * 0.15 },
			Parent = padre,
		})
	end
end

-- Si el lobby ya viene en el archivo del juego (o lo has editado en Studio),
-- lo usamos tal cual; solo leemos dónde está el podio.
local function usarLobbyExistente(carpeta: Instance)
	for i = 1, 3 do
		local bloque = carpeta:FindFirstChild("Podio" .. i, true)
		if bloque and bloque:IsA("BasePart") then
			Lobby.Podio[i] = bloque.Position + Vector3.new(0, bloque.Size.Y / 2, 0)
		end
	end
end

function Lobby.Construir()
	construirLuces()

	local existente = workspace:FindFirstChild("Lobby")
	if existente then
		usarLobbyExistente(existente)
		return
	end

	local carpeta = Instance.new("Folder")
	carpeta.Name = "Lobby"
	construirIsla(L, 75, carpeta)
	construirSpawns(carpeta)
	construirPistaDisco(carpeta)
	construirCarteles(carpeta)
	construirPodio(carpeta)
	construirTrampolines(carpeta)
	construirCanon(L + Vector3.new(46, 0, 12), 1, carpeta)
	construirIslaSecreta(carpeta)
	construirDecoracion(carpeta)

	carpeta.Parent = workspace
end

return Lobby
