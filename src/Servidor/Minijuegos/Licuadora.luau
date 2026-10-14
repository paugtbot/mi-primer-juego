--!strict
-- 🌪️ LA LICUADORA: dos barras gigantes giran cada vez más rápido. ¡Salta o vuela!

local C = require(script.Parent.Parent.Constructor)
local Efectos = require(script.Parent.Parent.Efectos)
local Jugadores = require(script.Parent.Parent.Jugadores)
local Ronda = require(script.Parent.Parent.Ronda)

type Ronda = Ronda.Ronda

local RADIO = 42
local GROSOR_BARRA = 1.4

type Barra = {
	Parte: Part,
	Bisagra: HingeConstraint,
	Altura: number,
	VelocidadInicial: number,
	VelocidadMaxima: number,
}

local barras: { Barra } = {}

-- ¿La barra está tocando a este jugador? (cálculo geométrico, muy fiable)
local function tocaBarra(barra: Barra, centro: Vector3, raiz: BasePart, escala: number, radioBarra: number): boolean
	local relativa = raiz.Position - centro
	local direccion = barra.Parte.CFrame.RightVector
	local perpendicular = math.abs(relativa.X * direccion.Z - relativa.Z * direccion.X)
	local largo = math.abs(relativa.X * direccion.X + relativa.Z * direccion.Z)
	if perpendicular > 1.0 * escala + GROSOR_BARRA / 2 + 0.3 or largo > radioBarra + 1 then
		return false
	end
	local pies = raiz.Position.Y - 3 * escala
	local cabeza = raiz.Position.Y + 1.8 * escala
	local abajo = barra.Parte.Position.Y - GROSOR_BARRA / 2
	local arriba = barra.Parte.Position.Y + GROSOR_BARRA / 2
	return pies < arriba and cabeza > abajo
end

-- Lanza al jugador en la dirección en la que gira la barra.
local function golpear(barra: Barra, centro: Vector3, jugador: Player, raiz: BasePart)
	local radial = Vector3.new(raiz.Position.X - centro.X, 0, raiz.Position.Z - centro.Z)
	local radialUnit = if radial.Magnitude > 0.1 then radial.Unit else Vector3.new(1, 0, 0)
	local sentido = if barra.Bisagra.AngularVelocity >= 0 then 1 else -1
	-- Tangente al giro (alrededor del eje Y).
	local tangente = Vector3.new(-radialUnit.Z, 0, radialUnit.X) * -sentido
	-- Al principio solo te tira al suelo; cuando la licuadora va rápido, ¡vuelas!
	local potencia = 25 + math.abs(barra.Bisagra.AngularVelocity) * 20
	Efectos.Empujar(jugador, tangente * potencia + radialUnit * 12 + Vector3.new(0, 45, 0), 1.1)
end

local Minijuego: Ronda.Minijuego = {
	Id = "Licuadora",
	Nombre = "La Licuadora",
	Emoji = "🌪️",
	Descripcion = "¡Dos barras gigantes giran cada vez más rápido! Salta por encima o saldrás volando.",
	Tipo = "supervivencia",
	Duracion = 75,
	AlturaMuerte = -25,

	Construir = function(ronda: Ronda): { CFrame }
		local A = ronda.Centro
		local plataforma = C.Disco(A, RADIO, 3, {
			Name = "Plataforma",
			Color = Color3.fromRGB(70, 80, 115),
			Material = Enum.Material.DiamondPlate,
			Parent = ronda.Carpeta,
		})
		C.Disco(A - Vector3.new(0, 0.3, 0), RADIO + 1, 2.6, {
			Name = "Borde",
			Color = Color3.fromRGB(165, 94, 234),
			Material = Enum.Material.Neon,
			Parent = ronda.Carpeta,
		})
		local pilar = C.Disco(A + Vector3.new(0, 8, 0), 2.5, 8, {
			Name = "Pilar",
			Color = Color3.fromRGB(255, 107, 203),
			Material = Enum.Material.Neon,
			Parent = ronda.Carpeta,
		})

		table.clear(barras)
		local definiciones = {
			{ Altura = 1.2, Inicial = 0.8, Maxima = 2.3, Color = Color3.fromRGB(255, 71, 87) },
			{ Altura = 3.8, Inicial = -0.55, Maxima = -1.8, Color = Color3.fromRGB(255, 221, 89) },
		}
		for _, def in definiciones do
			local parte, bisagra =
				C.BarraGiratoria(A + Vector3.new(0, def.Altura, 0), RADIO * 2, GROSOR_BARRA, 0, def.Color, ronda.Carpeta)
			-- La barra atraviesa el pilar y no debe chocar con él.
			for _, otra in { pilar, plataforma } do
				local sinChoque = Instance.new("NoCollisionConstraint")
				sinChoque.Part0 = parte
				sinChoque.Part1 = otra
				sinChoque.Parent = parte
			end
			table.insert(barras, {
				Parte = parte,
				Bisagra = bisagra,
				Altura = def.Altura,
				VelocidadInicial = def.Inicial,
				VelocidadMaxima = def.Maxima,
			})
		end
		-- Las dos barras tampoco chocan entre sí.
		if #barras == 2 then
			local sinChoque = Instance.new("NoCollisionConstraint")
			sinChoque.Part0 = barras[1].Parte
			sinChoque.Part1 = barras[2].Parte
			sinChoque.Parent = barras[1].Parte
		end

		return C.Circulo(A, 22, 8)
	end,

	Iniciar = function(ronda: Ronda)
		local A = ronda.Centro
		local inicio = os.clock()
		local ultimoGolpe: { [Player]: number } = {}
		local turbo = false

		-- Acelera las barras poco a poco.
		ronda:Bucle(0.5, function()
			local t = os.clock() - inicio
			local progreso = math.clamp(t / 55, 0, 1)
			for _, barra in barras do
				barra.Bisagra.AngularVelocity = barra.VelocidadInicial
					+ (barra.VelocidadMaxima - barra.VelocidadInicial) * progreso
			end
			if not turbo and t > 40 then
				turbo = true
				ronda:Anunciar("🌪️ ¡MODO TURBO LICUADORA!", Color3.fromRGB(255, 71, 87), 2)
			end
		end)

		-- Detecta golpes.
		ronda:Bucle(0.03, function()
			local ahora = os.clock()
			for _, jugador in ronda:Vivos() do
				local raiz = Jugadores.Raiz(jugador)
				if raiz and ahora - (ultimoGolpe[jugador] or 0) > 1.2 then
					for _, barra in barras do
						if barra.Parte.Parent and tocaBarra(barra, A, raiz, ronda.Escala, RADIO) then
							ultimoGolpe[jugador] = ahora
							golpear(barra, A, jugador, raiz)
							break
						end
					end
				end
			end
		end)
	end,
}

return Minijuego
