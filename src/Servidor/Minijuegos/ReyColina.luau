--!strict
-- 👑 REY DE LA COLINA: quédate en la cima dorada para sumar puntos.
-- ¡Todos tienen Martillo Loco para echarte!

local C = require(script.Parent.Parent.Constructor)
local Jugadores = require(script.Parent.Parent.Jugadores)
local Ronda = require(script.Parent.Parent.Ronda)

type Ronda = Ronda.Ronda

local RADIO_BASE = 50
local PISOS = { -- { radio, altura de arriba }
	{ 28, 4 },
	{ 17, 8 },
	{ 9, 12 },
}
local RADIO_ZONA = 9.5
local ALTURA_ZONA = 12

local function rampa(ronda: Ronda, anguloGrados: number, radio: number, abajo: number)
	local A = ronda.Centro
	local d = Vector3.new(math.cos(math.rad(anguloGrados)), 0, math.sin(math.rad(anguloGrados)))
	local posicion = A + d * (radio + 3.5) + Vector3.new(0, abajo + 2, 0)
	-- La parte alta de la cuña mira hacia el centro.
	C.Cuna({
		Name = "Rampa",
		Size = Vector3.new(7, 4, 8),
		CFrame = CFrame.lookAt(posicion, posicion + d),
		Color = Color3.fromRGB(200, 160, 110),
		Material = Enum.Material.WoodPlanks,
		Parent = ronda.Carpeta,
	})
end

local Minijuego: Ronda.Minijuego = {
	Id = "ReyColina",
	Nombre = "Rey de la Colina",
	Emoji = "👑",
	Descripcion = "¡Sube a la cima DORADA y quédate ahí para sumar puntos! Usa el Martillo Loco para echar a los demás.",
	Tipo = "puntos",
	Duracion = 60,
	AlturaMuerte = -30,
	Herramienta = true,
	UnidadPuntaje = "seg 👑",

	Construir = function(ronda: Ronda): { CFrame }
		local A = ronda.Centro
		C.Disco(A, RADIO_BASE, 4, {
			Name = "Base",
			Color = Color3.fromRGB(110, 210, 110),
			Material = Enum.Material.Grass,
			Parent = ronda.Carpeta,
		})
		C.Disco(A - Vector3.new(0, 0.3, 0), RADIO_BASE + 1, 3.4, {
			Name = "Borde",
			Color = Color3.fromRGB(255, 107, 203),
			Material = Enum.Material.Neon,
			Parent = ronda.Carpeta,
		})

		local colores = {
			Color3.fromRGB(140, 200, 90),
			Color3.fromRGB(170, 190, 80),
			Color3.fromRGB(255, 205, 40),
		}
		for i, piso in PISOS do
			local radio, altura = piso[1], piso[2]
			C.Disco(A + Vector3.new(0, altura, 0), radio, 4, {
				Name = "Piso" .. i,
				Color = colores[i],
				Material = if i == #PISOS then Enum.Material.Neon else Enum.Material.Grass,
				Parent = ronda.Carpeta,
			})
		end

		-- Rampas para subir (pocas, para que haya peleas).
		for _, angulo in { 0, 90, 180, 270 } do
			rampa(ronda, angulo, PISOS[1][1], 0)
		end
		for _, angulo in { 45, 225 } do
			rampa(ronda, angulo, PISOS[2][1], PISOS[1][2])
		end
		for _, angulo in { 135, 315 } do
			rampa(ronda, angulo, PISOS[3][1], PISOS[2][2])
		end

		local marcador = C.Parte({
			Name = "Marcador",
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(A + Vector3.new(0, ALTURA_ZONA + 14, 0)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = ronda.Carpeta,
		})
		C.Flotante(marcador, "👑 ZONA DEL REY 👑", 3, 16, Vector3.zero, Color3.fromRGB(255, 221, 89))

		return C.Circulo(A, 40, 8)
	end,

	Iniciar = function(ronda: Ronda)
		local A = ronda.Centro

		-- Corona flotante encima del líder.
		local soporte = C.Parte({
			Name = "Corona",
			Size = Vector3.new(1, 1, 1),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(A + Vector3.new(0, -500, 0)),
			Parent = ronda.Carpeta,
		})
		local corona, _ = C.Flotante(soporte, "👑", 4, 4, Vector3.new(0, 3.5, 0))
		corona.AlwaysOnTop = true
		local lider: Player? = nil

		ronda:Bucle(0.25, function()
			for _, jugador in ronda:Vivos() do
				local raiz = Jugadores.Raiz(jugador)
				if raiz then
					local plano = Vector3.new(raiz.Position.X - A.X, 0, raiz.Position.Z - A.Z).Magnitude
					local altura = raiz.Position.Y - A.Y
					if plano <= RADIO_ZONA and altura > ALTURA_ZONA and altura < ALTURA_ZONA + 10 * ronda.Escala then
						ronda:SumarPuntaje(jugador, 0.25)
					end
				end
			end

			-- ¿Quién va ganando?
			local mejor: Player? = nil
			local mejorPuntaje = 0
			for _, jugador in ronda:Vivos() do
				local p = ronda:ObtenerPuntaje(jugador)
				if p > mejorPuntaje then
					mejor, mejorPuntaje = jugador, p
				end
			end
			if mejor ~= lider then
				lider = mejor
				local cabeza = if mejor and mejor.Character then mejor.Character:FindFirstChild("Head") else nil
				if mejor and cabeza and cabeza:IsA("BasePart") then
					corona.Adornee = cabeza
					ronda:Feed(`👑 ¡{mejor.DisplayName} es el nuevo REY!`)
				else
					corona.Adornee = soporte
				end
			end
		end)
	end,
}

return Minijuego
