--!strict
-- 🎳 RAMPA RODANTE: sube la rampa gigante mientras bajan bolas enormes rodando.
-- ¡El primero en llegar arriba gana! (Tú eres el bolo...)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Compartido.Config)
local C = require(script.Parent.Parent.Constructor)
local Efectos = require(script.Parent.Parent.Efectos)
local Jugadores = require(script.Parent.Parent.Jugadores)
local Ronda = require(script.Parent.Parent.Ronda)

type Ronda = Ronda.Ronda

local ANGULO = math.rad(12)
local LARGO = 220
local ANCHO = 40
local SUBIDA = LARGO * math.sin(ANGULO) -- ~45.7

local inicioZ = 0
local salidas: { CFrame } = {}

local Minijuego: Ronda.Minijuego = {
	Id = "RampaRodante",
	Nombre = "Rampa Rodante",
	Emoji = "🎳",
	Descripcion = "¡Sube la rampa hasta arriba mientras caen BOLAS GIGANTES rodando! El primero en llegar gana.",
	Tipo = "carrera",
	Duracion = 100,
	AlturaMuerte = -25,

	Construir = function(ronda: Ronda): { CFrame }
		local A = ronda.Centro
		-- Rampa inclinada (sube hacia +Z).
		local marco = CFrame.new(A + Vector3.new(0, SUBIDA / 2, 0)) * CFrame.Angles(-ANGULO, 0, 0)
		C.Parte({
			Name = "Rampa",
			Size = Vector3.new(ANCHO, 2, LARGO),
			CFrame = marco,
			Color = Color3.fromRGB(205, 160, 110),
			Material = Enum.Material.WoodPlanks,
			Parent = ronda.Carpeta,
		})
		for _, x in { -ANCHO / 2 - 1, ANCHO / 2 + 1 } do
			C.Parte({
				Name = "Pared",
				Size = Vector3.new(2, 9, LARGO),
				CFrame = marco * CFrame.new(x, 4.5, 0),
				Color = Color3.fromRGB(150, 220, 255),
				Material = Enum.Material.Glass,
				Transparency = 0.6,
				Parent = ronda.Carpeta,
			})
		end
		-- Rayas de colores para que se vea la velocidad.
		for i = 1, 10 do
			C.Parte({
				Name = "Raya",
				Size = Vector3.new(ANCHO, 0.1, 2),
				CFrame = marco * CFrame.new(0, 1.05, -LARGO / 2 + i * 20),
				Color = Config.COLORES[(i % #Config.COLORES) + 1],
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = ronda.Carpeta,
			})
		end

		-- Salida abajo.
		local abajo = marco * CFrame.new(0, 1, -LARGO / 2)
		local salidaZ = abajo.Position.Z - 12
		C.Parte({
			Name = "Salida",
			Size = Vector3.new(ANCHO, 2, 24),
			CFrame = CFrame.new(A.X, abajo.Position.Y - 1, salidaZ),
			Color = Color3.fromRGB(30, 144, 255),
			Parent = ronda.Carpeta,
		})
		inicioZ = salidaZ - 12

		-- Meta arriba.
		local arriba = marco * CFrame.new(0, 1, LARGO / 2)
		C.Parte({
			Name = "Meta",
			Size = Vector3.new(ANCHO, 2, 30),
			CFrame = CFrame.new(A.X, arriba.Position.Y - 1, arriba.Position.Z + 14.5),
			Color = Color3.fromRGB(46, 213, 115),
			Parent = ronda.Carpeta,
		})
		local cartel = C.Parte({
			Name = "CartelMeta",
			Size = Vector3.new(ANCHO, 5, 1),
			CFrame = CFrame.new(A.X, arriba.Position.Y + 16, arriba.Position.Z + 8) * CFrame.Angles(0, math.pi, 0),
			Color = Color3.fromRGB(20, 20, 35),
			Parent = ronda.Carpeta,
		})
		C.Cartel(cartel, Enum.NormalId.Front, "🏁 ¡SUBE HASTA AQUÍ! 🏁", Color3.fromRGB(255, 221, 89), 20)
		for _, x in { -ANCHO / 2 + 1, ANCHO / 2 - 1 } do
			C.Parte({
				Name = "ColumnaMeta",
				Size = Vector3.new(2, 16, 2),
				CFrame = CFrame.new(A.X + x, arriba.Position.Y + 8, arriba.Position.Z + 8),
				Color = Color3.new(1, 1, 1),
				Parent = ronda.Carpeta,
			})
		end

		salidas = C.Parrilla(Vector3.new(A.X, abajo.Position.Y, salidaZ), 4, 2, 6)
		return salidas
	end,

	Iniciar = function(ronda: Ronda)
		local A = ronda.Centro
		local inicio = os.clock()
		local bolas: { Part } = {}
		local ultimoGolpe: { [Player]: number } = {}
		local marco = CFrame.new(A + Vector3.new(0, SUBIDA / 2, 0)) * CFrame.Angles(-ANGULO, 0, 0)
		local arriba = marco * CFrame.new(0, 1, LARGO / 2)

		local function soltarBola(gigante: boolean)
			local diametro = if gigante then 26 else math.random(9, 15)
			local margen = math.floor(ANCHO / 2 - diametro / 2 - 1)
			local x = if gigante then 0 else math.random(-margen, margen)
			local salida = marco * CFrame.new(x, 1 + diametro / 2 + 1, LARGO / 2 - diametro / 2 - 4)
			local bola = C.Bola(salida.Position, diametro, {
				Name = "Bola",
				Color = Config.COLORES[math.random(1, #Config.COLORES)],
				Material = Enum.Material.SmoothPlastic,
				Anchored = false,
				CustomPhysicalProperties = PhysicalProperties.new(2, 0.4, 0.3),
				Parent = ronda.Carpeta,
			})
			bola.AssemblyLinearVelocity = marco.LookVector * 25 -- LookVector apunta rampa abajo
			pcall(function()
				bola:SetNetworkOwner(nil)
			end)
			Debris:AddItem(bola, 14)
			table.insert(bolas, bola)
		end

		-- Suelta bolas cada vez más seguido.
		task.spawn(function()
			while ronda.Activa do
				soltarBola(false)
				local t = os.clock() - inicio
				if not ronda:Esperar(math.max(0.55, 1.6 - t * 0.015)) then
					break
				end
			end
		end)

		-- BOLA GIGANTE cada 20 segundos.
		task.spawn(function()
			while ronda:Esperar(20) do
				ronda:Anunciar("🎳 ¡BOLA GIGANTE!", Color3.fromRGB(255, 165, 2), 2)
				soltarBola(true)
			end
		end)

		ronda:Bucle(0.05, function()
			-- Limpia bolas que ya cayeron.
			for i = #bolas, 1, -1 do
				local bola = bolas[i]
				if not bola.Parent or bola.Position.Y < A.Y - 40 then
					bola:Destroy()
					table.remove(bolas, i)
				end
			end

			local ahora = os.clock()
			for _, jugador in ronda:Vivos() do
				local raiz = Jugadores.Raiz(jugador)
				if raiz then
					local pos = raiz.Position
					-- Progreso
					local recorrido = math.max(0, pos.Z - inicioZ)
					if recorrido > ronda:ObtenerPuntaje(jugador) then
						ronda:FijarPuntaje(jugador, recorrido)
					end
					-- Golpes de bolas
					if ahora - (ultimoGolpe[jugador] or 0) > 1 then
						for _, bola in bolas do
							if (bola.Position - pos).Magnitude < bola.Size.X / 2 + 1.8 * ronda.Escala then
								ultimoGolpe[jugador] = ahora
								local lado = math.random(-20, 20)
								Efectos.Empujar(jugador, Vector3.new(lado, 45, -75), 1.2)
								break
							end
						end
					end
					-- ¡Meta!
					if pos.Z >= arriba.Position.Z + 3 and pos.Y >= arriba.Position.Y - 2 then
						ronda:Llegar(jugador)
					end
				end
			end
		end)
	end,

	AlCaer = function(ronda: Ronda, jugador: Player)
		if #salidas > 0 then
			ronda:Teletransportar(jugador, salidas[math.random(1, #salidas)])
		end
	end,
}

return Minijuego
