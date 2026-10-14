--!strict
-- ☄️ LLUVIA DE METEORITOS: caen meteoritos que rompen el suelo y te mandan a volar.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local C = require(script.Parent.Parent.Constructor)
local Efectos = require(script.Parent.Parent.Efectos)
local Jugadores = require(script.Parent.Parent.Jugadores)
local Ronda = require(script.Parent.Parent.Ronda)

type Ronda = Ronda.Ronda

local RADIO = 46
local PASO = 9
local GROSOR = 3

local Minijuego: Ronda.Minijuego = {
	Id = "Meteoritos",
	Nombre = "Lluvia de Meteoritos",
	Emoji = "☄️",
	Descripcion = "¡Caen meteoritos del cielo! Huye de los círculos rojos. Cada vez caen más...",
	Tipo = "supervivencia",
	Duracion = 90,
	AlturaMuerte = -25,

	Construir = function(ronda: Ronda): { CFrame }
		local A = ronda.Centro
		local suelo = Instance.new("Folder")
		suelo.Name = "Suelo"
		suelo.Parent = ronda.Carpeta

		local n = math.ceil(RADIO / PASO)
		for ix = -n, n do
			for iz = -n, n do
				local x, z = ix * PASO, iz * PASO
				if x * x + z * z <= RADIO * RADIO then
					local tono = math.random(70, 110)
					C.Parte({
						Name = "Roca",
						Size = Vector3.new(PASO - 0.2, GROSOR, PASO - 0.2),
						CFrame = CFrame.new(A.X + x, A.Y - GROSOR / 2, A.Z + z),
						Color = Color3.fromRGB(tono, tono - 15, tono - 20),
						Material = Enum.Material.Basalt,
						Parent = suelo,
					})
				end
			end
		end
		return C.Circulo(A, 20, 8)
	end,

	Iniciar = function(ronda: Ronda)
		local A = ronda.Centro
		local suelo = ronda.Carpeta:FindFirstChild("Suelo")
		if not suelo then
			return
		end
		local inicio = os.clock()
		local ultimoGolpe: { [Player]: number } = {}

		local function impacto(punto: Vector3, radioRotura: number, radioEmpuje: number)
			Efectos.Explosion(punto, radioRotura + 2)
			-- Rompe el suelo: las rocas caen al vacío.
			for _, roca in suelo:GetChildren() do
				if roca:IsA("BasePart") and roca.Anchored then
					local d = Vector3.new(roca.Position.X - punto.X, 0, roca.Position.Z - punto.Z).Magnitude
					if d <= radioRotura then
						roca.Anchored = false
						roca.CanCollide = false
						roca.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), -10, math.random(-8, 8))
						roca.AssemblyAngularVelocity = Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3))
						Debris:AddItem(roca, 3)
					end
				end
			end
			-- Manda a volar a los jugadores cercanos.
			local ahora = os.clock()
			for _, jugador in ronda:Vivos() do
				local raiz = Jugadores.Raiz(jugador)
				if raiz and ahora - (ultimoGolpe[jugador] or 0) > 0.5 then
					local diferencia = raiz.Position - punto
					local d = diferencia.Magnitude
					if d <= radioEmpuje then
						ultimoGolpe[jugador] = ahora
						local fuerza = 1 - d / radioEmpuje
						local plano = Vector3.new(diferencia.X, 0, diferencia.Z)
						local direccion = if plano.Magnitude > 0.1 then plano.Unit else Vector3.new(1, 0, 0)
						Efectos.Empujar(jugador, direccion * (30 + 55 * fuerza) + Vector3.new(0, 40 + 45 * fuerza, 0), 1)
					end
				end
			end
		end

		local function lanzar(gigante: boolean)
			-- Elige dónde cae: a veces apunta a un jugador. ¡Cuidado!
			local objetivo: Vector3
			local vivos = ronda:Vivos()
			local raizObjetivo = if #vivos > 0 and math.random() < 0.45
				then Jugadores.Raiz(vivos[math.random(1, #vivos)])
				else nil
			if raizObjetivo then
				objetivo = Vector3.new(
					raizObjetivo.Position.X + math.random(-6, 6),
					A.Y,
					raizObjetivo.Position.Z + math.random(-6, 6)
				)
			else
				local angulo = math.random() * math.pi * 2
				local r = math.sqrt(math.random()) * (RADIO - 4)
				objetivo = A + Vector3.new(math.cos(angulo) * r, 0, math.sin(angulo) * r)
			end

			local radioAviso = if gigante then 16 else 7
			local aviso = C.Disco(objetivo + Vector3.new(0, 0.15, 0), radioAviso, 0.2, {
				Name = "Aviso",
				Color = Color3.fromRGB(255, 40, 40),
				Material = Enum.Material.Neon,
				Transparency = 0.35,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = ronda.Carpeta,
			})
			TweenService:Create(
				aviso,
				TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.8 }
			):Play()

			if not ronda:Esperar(if gigante then 2.2 else 1.3) then
				aviso:Destroy()
				return
			end

			local tamano = if gigante then 16 else 6
			local meteorito = C.Bola(
				objetivo + Vector3.new(math.random(-30, 30), 150, math.random(-30, 30)),
				tamano,
				{
					Name = "Meteorito",
					Color = Color3.fromRGB(255, 120, 20),
					Material = Enum.Material.Neon,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Parent = ronda.Carpeta,
				}
			)
			local fuego = Instance.new("Fire")
			fuego.Size = tamano * 1.5
			fuego.Heat = 20
			fuego.Parent = meteorito

			local caida = TweenService:Create(
				meteorito,
				TweenInfo.new(0.5, Enum.EasingStyle.Linear),
				{ CFrame = CFrame.new(objetivo) }
			)
			caida:Play()
			caida.Completed:Wait()
			meteorito:Destroy()
			aviso:Destroy()
			if ronda.Activa then
				if gigante then
					impacto(objetivo, 15, 22)
				else
					-- Rompe lo que hay dentro del círculo rojo y empuja un poco más allá.
					impacto(objetivo, 6.5, 10)
				end
			end
		end

		-- Meteoritos normales: cada vez más seguidos.
		task.spawn(function()
			while ronda.Activa do
				task.spawn(lanzar, false)
				local t = os.clock() - inicio
				task.wait(math.max(0.22, 1.1 - t * 0.012))
			end
		end)

		-- Meteorito GIGANTE cada 25 segundos.
		task.spawn(function()
			while ronda:Esperar(25) do
				ronda:Anunciar("☄️ ¡METEORITO GIGANTE!", Color3.fromRGB(255, 120, 20), 2)
				task.spawn(lanzar, true)
			end
		end)
	end,
}

return Minijuego
