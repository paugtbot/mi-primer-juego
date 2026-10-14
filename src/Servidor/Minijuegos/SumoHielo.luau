--!strict
-- 🧊 SUMO EN EL HIELO: pista de hielo resbaladiza que encoge, ráfagas de viento
-- y Martillos Locos. ¡Échalos a todos al agua helada!

local TweenService = game:GetService("TweenService")

local C = require(script.Parent.Parent.Constructor)
local Efectos = require(script.Parent.Parent.Efectos)
local Jugadores = require(script.Parent.Parent.Jugadores)
local Ronda = require(script.Parent.Parent.Ronda)

type Ronda = Ronda.Ronda

local RADIO_INICIAL = 32
local RADIO_MINIMO = 10

local Minijuego: Ronda.Minijuego = {
	Id = "SumoHielo",
	Nombre = "Sumo en el Hielo",
	Emoji = "🧊",
	Descripcion = "¡Pista de HIELO que encoge! Usa el Martillo Loco para echar a los demás. Cuidado con el viento...",
	Tipo = "supervivencia",
	Duracion = 90,
	AlturaMuerte = -15,
	Herramienta = true,
	FuerzaMartillo = 1.25,

	Construir = function(ronda: Ronda): { CFrame }
		local A = ronda.Centro
		C.Disco(A, RADIO_INICIAL, 4, {
			Name = "PistaHielo",
			Color = Color3.fromRGB(175, 225, 255),
			Material = Enum.Material.Ice,
			CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.03, 0.1, 100, 1),
			Parent = ronda.Carpeta,
		})
		C.Disco(A - Vector3.new(0, 0.4, 0), RADIO_INICIAL + 1, 3.4, {
			Name = "BordeHielo",
			Color = Color3.fromRGB(0, 210, 211),
			Material = Enum.Material.Neon,
			Parent = ronda.Carpeta,
		})
		C.Parte({
			Name = "AguaHelada",
			Size = Vector3.new(220, 1, 220),
			CFrame = CFrame.new(A - Vector3.new(0, 35, 0)),
			Color = Color3.fromRGB(40, 120, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			CanCollide = false,
			CanQuery = false,
			Parent = ronda.Carpeta,
		})

		-- Nieve cayendo.
		local nube = C.Parte({
			Name = "Nube",
			Size = Vector3.new(90, 1, 90),
			CFrame = CFrame.new(A + Vector3.new(0, 45, 0)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = ronda.Carpeta,
		})
		local nieve = Instance.new("ParticleEmitter")
		nieve.EmissionDirection = Enum.NormalId.Bottom
		nieve.Rate = 80
		nieve.Lifetime = NumberRange.new(6, 9)
		nieve.Speed = NumberRange.new(5, 9)
		nieve.Size = NumberSequence.new(0.35)
		nieve.Color = ColorSequence.new(Color3.new(1, 1, 1))
		nieve.LightEmission = 0.5
		nieve.SpreadAngle = Vector2.new(15, 15)
		nieve.Parent = nube

		return C.Circulo(A, 18, 8)
	end,

	Iniciar = function(ronda: Ronda)
		local pista = ronda.Carpeta:FindFirstChild("PistaHielo")
		local borde = ronda.Carpeta:FindFirstChild("BordeHielo")

		-- La pista encoge cada 10 segundos.
		task.spawn(function()
			local radio = RADIO_INICIAL
			while ronda:Esperar(10) do
				if radio <= RADIO_MINIMO then
					break
				end
				radio = math.max(RADIO_MINIMO, radio - 4)
				ronda:Anunciar("⚠️ ¡LA PISTA ENCOGE!", Color3.fromRGB(0, 210, 211), 1.5)
				if pista and pista:IsA("BasePart") then
					TweenService:Create(pista, TweenInfo.new(1.5), { Size = Vector3.new(4, radio * 2, radio * 2) }):Play()
				end
				if borde and borde:IsA("BasePart") then
					TweenService:Create(borde, TweenInfo.new(1.5), { Size = Vector3.new(3.4, radio * 2 + 2, radio * 2 + 2) })
						:Play()
				end
			end
		end)

		-- Ráfagas de viento que empujan a todos hacia el mismo lado.
		task.spawn(function()
			while ronda:Esperar(math.random(12, 16)) do
				local angulo = math.random() * math.pi * 2
				local direccion = Vector3.new(math.cos(angulo), 0, math.sin(angulo))
				ronda:Anunciar("💨 ¡RÁFAGA DE VIENTO!", Color3.fromRGB(200, 230, 255), 1.5)
				task.wait(1)
				for _, jugador in ronda:Vivos() do
					if Jugadores.Raiz(jugador) then
						Efectos.Empujar(jugador, direccion * 55 + Vector3.new(0, 14, 0), 0.4)
					end
				end
			end
		end)
	end,
}

return Minijuego
