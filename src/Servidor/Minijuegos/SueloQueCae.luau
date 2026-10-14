--!strict
-- 🟦 SUELO QUE CAE: 3 pisos de baldosas que desaparecen al pisarlas. ¡No te pares!

local TweenService = game:GetService("TweenService")

local C = require(script.Parent.Parent.Constructor)
local Jugadores = require(script.Parent.Parent.Jugadores)
local Ronda = require(script.Parent.Parent.Ronda)

type Ronda = Ronda.Ronda

local PISOS = 3
local SEPARACION = 22 -- altura entre pisos
local TAMANO = 7
local PASO = 7.4
local RADIO = 44

local COLORES_PISO = {
	Color3.fromRGB(0, 210, 211),
	Color3.fromRGB(255, 107, 203),
	Color3.fromRGB(255, 221, 89),
}

local ROJO = Color3.fromRGB(255, 71, 87)
local BLANCO = Color3.new(1, 1, 1)

local Minijuego: Ronda.Minijuego = {
	Id = "SueloQueCae",
	Nombre = "Suelo que Cae",
	Emoji = "🟦",
	Descripcion = "¡Las baldosas desaparecen al pisarlas! Hay 3 pisos encima de la lava. Sé el último en pie.",
	Tipo = "supervivencia",
	Duracion = 120,
	AlturaMuerte = -(PISOS - 1) * SEPARACION - 10,

	Construir = function(ronda: Ronda): { CFrame }
		local A = ronda.Centro
		local baldosas = Instance.new("Folder")
		baldosas.Name = "Baldosas"
		baldosas.Parent = ronda.Carpeta

		local n = math.ceil(RADIO / PASO)
		for piso = 1, PISOS do
			local y = A.Y - (piso - 1) * SEPARACION
			for ix = -n, n do
				for iz = -n, n do
					local x, z = ix * PASO, iz * PASO
					if x * x + z * z <= RADIO * RADIO then
						C.Parte({
							Name = "Baldosa",
							Size = Vector3.new(TAMANO, 1.2, TAMANO),
							CFrame = CFrame.new(A.X + x, y - 0.6, A.Z + z),
							Color = COLORES_PISO[piso],
							Atributos = { Piso = piso },
							Parent = baldosas,
						})
					end
				end
			end
		end

		C.Parte({
			Name = "Lava",
			Size = Vector3.new(180, 2, 180),
			CFrame = CFrame.new(A.X, A.Y - (PISOS - 1) * SEPARACION - 20, A.Z),
			Color = Color3.fromRGB(255, 90, 0),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = ronda.Carpeta,
		})

		return C.Circulo(A, 24, 8)
	end,

	Iniciar = function(ronda: Ronda)
		local baldosas = ronda.Carpeta:FindFirstChild("Baldosas")
		if not baldosas then
			return
		end
		local inicio = os.clock()
		local tocadas: { [BasePart]: boolean } = {}

		local function romper(baldosa: BasePart, retraso: number)
			if tocadas[baldosa] then
				return
			end
			tocadas[baldosa] = true
			baldosa.Color = BLANCO
			task.delay(retraso * 0.3, function()
				baldosa.Color = ROJO
			end)
			task.delay(retraso, function()
				baldosa.CanCollide = false
				baldosa.CanQuery = false
				TweenService:Create(baldosa, TweenInfo.new(0.25), { Transparency = 1 }):Play()
				task.delay(0.3, function()
					baldosa:Destroy()
				end)
			end)
		end

		local filtro = OverlapParams.new()
		filtro.FilterType = Enum.RaycastFilterType.Include
		filtro.FilterDescendantsInstances = { baldosas }

		-- Mira qué baldosas hay bajo los pies de cada jugador.
		ronda:Bucle(0.05, function()
			local transcurrido = os.clock() - inicio
			local retraso = if transcurrido > 60 then 0.4 else 0.6
			for _, jugador in ronda:Vivos() do
				local raiz = Jugadores.Raiz(jugador)
				if raiz then
					local pies = raiz.Position - Vector3.new(0, 3.1 * ronda.Escala, 0)
					local caja = Vector3.new(2.4 * ronda.Escala, 1.8, 2.4 * ronda.Escala)
					for _, parte in workspace:GetPartBoundsInBox(CFrame.new(pies), caja, filtro) do
						romper(parte, retraso)
					end
				end
			end
		end)

		-- A partir de los 40 segundos, ¡TERREMOTO! Caen baldosas solas.
		task.spawn(function()
			if not ronda:Esperar(40) then
				return
			end
			ronda:Anunciar("🌋 ¡TERREMOTO!", Color3.fromRGB(255, 120, 0), 2)
			while ronda.Activa do
				local lista = baldosas:GetChildren()
				for _ = 1, 3 do
					if #lista > 0 then
						local elegida = lista[math.random(1, #lista)]
						if elegida:IsA("BasePart") then
							romper(elegida, 1.2)
						end
					end
				end
				task.wait(0.6)
			end
		end)
	end,
}

return Minijuego
