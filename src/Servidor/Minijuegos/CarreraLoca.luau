--!strict
-- 🏁 CARRERA LOCA: un circuito de obstáculos con lava, cintas, plataformas que
-- parpadean, trampolines y una licuadora. ¡El primero en llegar a la meta gana!

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Compartido.Config)
local C = require(script.Parent.Parent.Constructor)
local Efectos = require(script.Parent.Parent.Efectos)
local Jugadores = require(script.Parent.Parent.Jugadores)
local Ronda = require(script.Parent.Parent.Ronda)

type Ronda = Ronda.Ronda

local ANCHO = 26
local LARGO = 266
local ALTO_SUPERIOR = 22

type Punto = { Z: number, Y: number, Destino: CFrame }

-- Estado de la ronda actual (solo hay una a la vez).
local puntosControl: { Punto } = {}
local controlDe: { [Player]: number } = {}
local origenZ = 0
local metaZ = 0
local alturaMeta = 0
local plataformasParpadeo: { { Parte: Part, Grupo: number } } = {}
local barraMeta: Part? = nil

local LAVA = Color3.fromRGB(255, 90, 0)

local function suelo(ronda: Ronda, nombre: string, z1: number, z2: number, y: number, ancho: number?, color: Color3?): Part
	local A = ronda.Centro
	return C.Parte({
		Name = nombre,
		Size = Vector3.new(ancho or ANCHO, 2, z2 - z1),
		CFrame = CFrame.new(A.X, y - 1, (z1 + z2) / 2),
		Color = color or Color3.fromRGB(235, 235, 245),
		Parent = ronda.Carpeta,
	})
end

local function lava(ronda: Ronda, z1: number, z2: number, y: number)
	local A = ronda.Centro
	C.Parte({
		Name = "Lava",
		Size = Vector3.new(ANCHO + 30, 1, z2 - z1),
		CFrame = CFrame.new(A.X, y, (z1 + z2) / 2),
		Color = LAVA,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = ronda.Carpeta,
	})
end

local function control(ronda: Ronda, z: number, y: number)
	local A = ronda.Centro
	C.Parte({
		Name = "PuntoControl",
		Size = Vector3.new(ANCHO, 0.2, 2),
		CFrame = CFrame.new(A.X, y + 0.05, z),
		Color = Color3.fromRGB(46, 213, 115),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = ronda.Carpeta,
	})
	local destino = CFrame.lookAt(Vector3.new(A.X, y, z + 3), Vector3.new(A.X, y, z + 10))
	table.insert(puntosControl, { Z = z, Y = y, Destino = destino })
end

local function volverAlControl(ronda: Ronda, jugador: Player)
	local indice = controlDe[jugador] or 1
	local punto = puntosControl[indice]
	if punto then
		ronda:Teletransportar(jugador, punto.Destino + Vector3.new(math.random(-8, 8), 0, 0))
	end
end

local Minijuego: Ronda.Minijuego = {
	Id = "CarreraLoca",
	Nombre = "Carrera Loca",
	Emoji = "🏁",
	Descripcion = "¡Carrera de obstáculos! Lava, cintas locas, plataformas que desaparecen y trampolines. ¡Llega a la META!",
	Tipo = "carrera",
	Duracion = 120,
	AlturaMuerte = -15,

	Construir = function(ronda: Ronda): { CFrame }
		local A = ronda.Centro
		local G = A.Y -- suelo de abajo
		local U = A.Y + ALTO_SUPERIOR -- suelo de arriba
		local z0 = A.Z - LARGO / 2
		origenZ = z0
		table.clear(puntosControl)
		table.clear(controlDe)
		table.clear(plataformasParpadeo)

		-- 1) Salida
		suelo(ronda, "Salida", z0, z0 + 20, G, nil, Color3.fromRGB(30, 144, 255))
		control(ronda, z0 + 2, G)

		-- 2) Piedras saltarinas sobre lava
		lava(ronda, z0 + 20, z0 + 66, G - 6)
		for fila = 0, 4 do
			local z = z0 + 25 + fila * 8.5
			local columnas = { -8, 0, 8 }
			table.remove(columnas, math.random(1, 3)) -- quita una al azar
			for _, x in columnas do
				C.Parte({
					Name = "Piedra",
					Size = Vector3.new(6, 1.5, 6),
					CFrame = CFrame.new(A.X + x + math.random(-2, 2), G - 0.75 + math.random(0, 2), z),
					Color = Config.COLORES[(fila % #Config.COLORES) + 1],
					Parent = ronda.Carpeta,
				})
			end
		end

		-- 3) Descanso + cinta loca que te empuja hacia atrás
		suelo(ronda, "Descanso1", z0 + 64, z0 + 74, G)
		control(ronda, z0 + 66, G)
		local cinta = suelo(ronda, "CintaLoca", z0 + 74, z0 + 110, G, nil, Color3.fromRGB(50, 50, 60))
		cinta.AssemblyLinearVelocity = Vector3.new(0, 0, -11)
		for i = 0, 5 do
			C.Parte({
				Name = "Flecha",
				Size = Vector3.new(ANCHO - 4, 0.1, 1),
				CFrame = CFrame.new(A.X, G + 0.05, z0 + 77 + i * 6),
				Color = Color3.fromRGB(255, 221, 89),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = ronda.Carpeta,
			})
		end
		for _, x in { -ANCHO / 2 - 0.5, ANCHO / 2 + 0.5 } do
			C.Parte({
				Name = "Baranda",
				Size = Vector3.new(1, 2, 36),
				CFrame = CFrame.new(A.X + x, G + 1, z0 + 92),
				Color = Color3.fromRGB(255, 71, 87),
				Parent = ronda.Carpeta,
			})
		end
		for _, pos in { Vector3.new(-6, 0, 86), Vector3.new(6, 0, 98) } do
			C.Parte({
				Name = "Poste",
				Size = Vector3.new(3, 6, 3),
				CFrame = CFrame.new(A.X + pos.X, G + 3, z0 + pos.Z),
				Color = Color3.fromRGB(255, 165, 2),
				Parent = ronda.Carpeta,
			})
		end

		-- 4) Plataformas que parpadean
		suelo(ronda, "Descanso2", z0 + 110, z0 + 118, G)
		control(ronda, z0 + 112, G)
		lava(ronda, z0 + 118, z0 + 158, G - 6)
		for fila = 0, 4 do
			for columna = -1, 1 do
				local parte = C.Parte({
					Name = "Parpadeo",
					Size = Vector3.new(7, 1, 6.5),
					CFrame = CFrame.new(A.X + columna * 8.5, G - 0.5, z0 + 122 + fila * 8),
					Color = Color3.fromRGB(0, 210, 211),
					Material = Enum.Material.Neon,
					Parent = ronda.Carpeta,
				})
				table.insert(plataformasParpadeo, { Parte = parte, Grupo = (fila + columna) % 2 })
			end
		end

		-- 5) Trampolines para subir el muro
		suelo(ronda, "Descanso3", z0 + 158, z0 + 170, G)
		control(ronda, z0 + 160, G)
		for _, x in { -8, 0, 8 } do
			C.Disco(Vector3.new(A.X + x, G + 0.4, z0 + 165), 3.2, 0.4, {
				Name = "Trampolin",
				Color = Color3.fromRGB(255, 107, 203),
				Material = Enum.Material.Neon,
				Tags = { "Impulso" },
				Atributos = { Impulso = Vector3.new(0, 120, 14) },
				Parent = ronda.Carpeta,
			})
		end
		C.Parte({
			Name = "Muro",
			Size = Vector3.new(ANCHO, ALTO_SUPERIOR, 2),
			CFrame = CFrame.new(A.X, G + ALTO_SUPERIOR / 2 - 1, z0 + 171),
			Color = Color3.fromRGB(165, 94, 234),
			Parent = ronda.Carpeta,
		})

		-- 6) Arriba: licuadora pequeña
		suelo(ronda, "Arriba1", z0 + 170, z0 + 186, U)
		control(ronda, z0 + 174, U)
		C.Disco(Vector3.new(A.X, U, z0 + 202), 16, 2, {
			Name = "DiscoLicuadora",
			Color = Color3.fromRGB(255, 221, 89),
			Parent = ronda.Carpeta,
		})
		local barra, bisagra = C.BarraGiratoria(
			Vector3.new(A.X, U + 1.2, z0 + 202),
			32,
			1.4,
			0,
			Color3.fromRGB(255, 71, 87),
			ronda.Carpeta
		)
		bisagra.AngularVelocity = 0 -- arranca cuando empieza la carrera
		barraMeta = barra

		-- 7) Puente estrecho y META
		suelo(ronda, "Arriba2", z0 + 217, z0 + 228, U)
		control(ronda, z0 + 220, U)
		suelo(ronda, "Puente", z0 + 228, z0 + 250, U, 5, Color3.fromRGB(255, 165, 2))
		suelo(ronda, "Meta", z0 + 250, z0 + LARGO, U, nil, Color3.fromRGB(46, 213, 115))
		metaZ = z0 + 254
		alturaMeta = U

		for _, x in { -ANCHO / 2 + 1, ANCHO / 2 - 1 } do
			C.Parte({
				Name = "ColumnaMeta",
				Size = Vector3.new(2, 14, 2),
				CFrame = CFrame.new(A.X + x, U + 7, metaZ),
				Color = Color3.new(1, 1, 1),
				Parent = ronda.Carpeta,
			})
		end
		local cartel = C.Parte({
			Name = "CartelMeta",
			Size = Vector3.new(ANCHO, 4, 1),
			CFrame = CFrame.new(A.X, U + 15, metaZ) * CFrame.Angles(0, math.pi, 0),
			Color = Color3.fromRGB(20, 20, 35),
			Parent = ronda.Carpeta,
		})
		C.Cartel(cartel, Enum.NormalId.Front, "🏁 META 🏁", Color3.fromRGB(255, 221, 89), 20)

		return C.Parrilla(Vector3.new(A.X, G, z0 + 10), 4, 2, 5)
	end,

	Iniciar = function(ronda: Ronda)
		-- Arranca la licuadora pequeña.
		local barra = barraMeta
		if barra then
			local bisagra = barra:FindFirstChildOfClass("HingeConstraint")
			if bisagra then
				bisagra.AngularVelocity = 1.7
			end
		end

		-- Lava: si la tocas, vuelves al último punto de control.
		for _, parte in ronda.Carpeta:GetChildren() do
			if parte:IsA("BasePart") and parte.Name == "Lava" then
				ronda:Conectar(parte.Touched, function(otra: BasePart)
					local jugador = ronda:JugadorDeParte(otra)
					if jugador then
						ronda:Caer(jugador)
					end
				end)
			end
		end

		-- Plataformas que parpadean.
		task.spawn(function()
			local grupoActivo = 0
			while ronda.Activa do
				for _, p in plataformasParpadeo do
					local activa = p.Grupo == grupoActivo
					p.Parte.CanCollide = activa
					p.Parte.Transparency = if activa then 0 else 0.85
					p.Parte.Color = Color3.fromRGB(0, 210, 211)
				end
				if not ronda:Esperar(1.3) then
					break
				end
				-- Aviso: las que van a desaparecer se ponen rojas.
				for _, p in plataformasParpadeo do
					if p.Grupo == grupoActivo then
						p.Parte.Color = Color3.fromRGB(255, 71, 87)
					end
				end
				if not ronda:Esperar(0.5) then
					break
				end
				grupoActivo = 1 - grupoActivo
			end
		end)

		-- Progreso, puntos de control, golpes de la licuadora y meta.
		local ultimoGolpe: { [Player]: number } = {}
		ronda:Bucle(0.05, function()
			for _, jugador in ronda:Vivos() do
				local raiz = Jugadores.Raiz(jugador)
				if raiz then
					local pos = raiz.Position
					-- Progreso (metros recorridos)
					local recorrido = math.max(0, pos.Z - origenZ)
					if recorrido > ronda:ObtenerPuntaje(jugador) and pos.Y > ronda.Centro.Y - 4 then
						ronda:FijarPuntaje(jugador, recorrido)
					end
					-- Puntos de control
					local actual = controlDe[jugador] or 1
					for i = actual + 1, #puntosControl do
						local punto = puntosControl[i]
						if pos.Z >= punto.Z and pos.Y >= punto.Y - 2 then
							controlDe[jugador] = i
						end
					end
					-- Licuadora
					if barra and barra.Parent and os.clock() - (ultimoGolpe[jugador] or 0) > 1 then
						local centro = Vector3.new(barra.Position.X, barra.Position.Y, barra.Position.Z)
						local rel = pos - centro
						local dir = barra.CFrame.RightVector
						local perp = math.abs(rel.X * dir.Z - rel.Z * dir.X)
						local largo = math.abs(rel.X * dir.X + rel.Z * dir.Z)
						local pies = pos.Y - 3 * ronda.Escala
						if perp < 1.0 * ronda.Escala + 1 and largo < 17 and pies < centro.Y + 0.7 and pos.Y + 1.8 * ronda.Escala > centro.Y - 0.7 then
							ultimoGolpe[jugador] = os.clock()
							local lado = if rel.X >= 0 then 1 else -1
							Efectos.Empujar(jugador, Vector3.new(lado * 60, 50, -20), 1.2)
						end
					end
					-- ¡Meta!
					if pos.Z >= metaZ and pos.Y >= alturaMeta - 2 then
						ronda:Llegar(jugador)
					end
				end
			end
		end)
	end,

	AlCaer = function(ronda: Ronda, jugador: Player)
		volverAlControl(ronda, jugador)
	end,
}

return Minijuego
