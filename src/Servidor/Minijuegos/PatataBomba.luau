--!strict
-- 💣 PATATA BOMBA: alguien lleva una bomba en la cabeza. Tócale a otro para pasársela.
-- Cuando el tiempo llega a cero... ¡BOOM!

local C = require(script.Parent.Parent.Constructor)
local Efectos = require(script.Parent.Parent.Efectos)
local Jugadores = require(script.Parent.Parent.Jugadores)
local Ronda = require(script.Parent.Parent.Ronda)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotos = require(ReplicatedStorage.Compartido.Remotos)

type Ronda = Ronda.Ronda

local LADO = 70
local ALTO_PARED = 16

type Estado = {
	Portador: Player?,
	Bomba: Part?,
	Resaltado: Highlight?,
	Texto: TextLabel?,
	ExplotaEn: number,
	UltimoPase: number,
	SiguienteEn: number?, -- cuándo sale la próxima bomba (si ahora no hay)
}

-- Solo hay una ronda a la vez, así que guardamos el estado aquí.
local estado: Estado? = nil

local function quitarBomba(e: Estado)
	local anterior = e.Portador
	if anterior then
		local humanoide = Jugadores.Humanoide(anterior)
		if humanoide and humanoide.WalkSpeed > 0 then
			humanoide.WalkSpeed = humanoide.WalkSpeed / 1.25
		end
	end
	if e.Bomba then
		e.Bomba:Destroy()
		e.Bomba = nil
	end
	if e.Resaltado then
		e.Resaltado:Destroy()
		e.Resaltado = nil
	end
	e.Texto = nil
	e.Portador = nil
end

local function ponerBomba(ronda: Ronda, e: Estado, jugador: Player): boolean
	local personaje = jugador.Character
	local cabeza = if personaje then personaje:FindFirstChild("Head") else nil
	if not personaje or not cabeza or not cabeza:IsA("BasePart") then
		return false
	end
	quitarBomba(e)

	local tamano = 2.6 * ronda.Escala
	local bomba = C.Bola(Vector3.zero, tamano, {
		Name = "Bomba",
		Color = Color3.fromRGB(25, 25, 25),
		Anchored = false,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
	})
	bomba.CFrame = cabeza.CFrame * CFrame.new(0, 2.4 * ronda.Escala, 0)
	local chispas = Instance.new("Sparkles")
	chispas.SparkleColor = Color3.fromRGB(255, 165, 2)
	chispas.Parent = bomba
	C.Soldar(cabeza, bomba)
	local _, texto = C.Flotante(bomba, "💣", 2.5, 4, Vector3.new(0, 2.5 * ronda.Escala, 0), Color3.fromRGB(255, 71, 87))
	bomba.Parent = personaje

	local resaltado = Instance.new("Highlight")
	resaltado.FillColor = Color3.fromRGB(255, 40, 40)
	resaltado.FillTransparency = 0.6
	resaltado.OutlineColor = Color3.fromRGB(255, 221, 89)
	resaltado.Parent = personaje

	local humanoide = Jugadores.Humanoide(jugador)
	if humanoide then
		humanoide.WalkSpeed = ronda.Velocidad * 1.25
	end

	e.Portador = jugador
	e.Bomba = bomba
	e.Resaltado = resaltado
	e.Texto = texto
	e.UltimoPase = os.clock()
	Remotos.Anuncio:FireClient(jugador, "💣 ¡TIENES LA BOMBA!", {
		Color = Color3.fromRGB(255, 71, 87),
		Duracion = 1.5,
		Subtitulo = "¡Toca a alguien para pasársela!",
	})
	return true
end

local function nuevaBomba(ronda: Ronda, e: Estado)
	local vivos = ronda:Vivos()
	if not ronda.Activa or #vivos == 0 then
		return
	end
	if #vivos == 1 and #ronda.Participantes > 1 then
		return
	end
	local elegido = vivos[math.random(1, #vivos)]
	if ponerBomba(ronda, e, elegido) then
		e.ExplotaEn = os.clock() + math.random(90, 140) / 10
		ronda:Feed(`💣 ¡{elegido.DisplayName} tiene la bomba!`)
	end
end

local function explotar(ronda: Ronda, e: Estado)
	local victima = e.Portador
	if not victima then
		return
	end
	local raiz = Jugadores.Raiz(victima)
	local posicion = if raiz then raiz.Position else ronda.Centro
	quitarBomba(e)

	Efectos.Explosion(posicion, 14)
	Efectos.Confeti(posicion, 60)
	Efectos.Empujar(victima, Vector3.new(math.random(-30, 30), 170, math.random(-30, 30)), 2)
	for _, otro in ronda:Vivos() do
		local raizOtro = Jugadores.Raiz(otro)
		if otro ~= victima and raizOtro then
			local diferencia = raizOtro.Position - posicion
			if diferencia.Magnitude < 14 then
				local plano = Vector3.new(diferencia.X, 0, diferencia.Z)
				local direccion = if plano.Magnitude > 0.1 then plano.Unit else Vector3.new(0, 0, 1)
				Efectos.Empujar(otro, direccion * 70 + Vector3.new(0, 40, 0), 0.8)
			end
		end
	end
	e.SiguienteEn = os.clock() + 2.9
	task.wait(0.4)
	ronda:Eliminar(victima, "¡EXPLOTÓ! 💥")
end

local Minijuego: Ronda.Minijuego = {
	Id = "PatataBomba",
	Nombre = "Patata Bomba",
	Emoji = "💣",
	Descripcion = "¡Alguien tiene una BOMBA en la cabeza! Si la tienes, toca a otro para pasársela antes de que explote.",
	Tipo = "supervivencia",
	Duracion = 150,
	AlturaMuerte = -20,

	Construir = function(ronda: Ronda): { CFrame }
		local A = ronda.Centro
		local colores = { Color3.fromRGB(255, 221, 89), Color3.fromRGB(255, 107, 203) }
		local n = 7
		local tam = LADO / n
		for ix = 1, n do
			for iz = 1, n do
				C.Parte({
					Name = "Suelo",
					Size = Vector3.new(tam, 2, tam),
					CFrame = CFrame.new(A + Vector3.new((ix - (n + 1) / 2) * tam, -1, (iz - (n + 1) / 2) * tam)),
					Color = colores[((ix + iz) % 2) + 1],
					Parent = ronda.Carpeta,
				})
			end
		end

		-- Paredes de cristal + paredes invisibles altas + techo (por si hay súper salto).
		local mitad = LADO / 2 + 1
		local paredes = {
			{ Vector3.new(0, 0, mitad), Vector3.new(LADO + 4, 0, 2) },
			{ Vector3.new(0, 0, -mitad), Vector3.new(LADO + 4, 0, 2) },
			{ Vector3.new(mitad, 0, 0), Vector3.new(2, 0, LADO + 4) },
			{ Vector3.new(-mitad, 0, 0), Vector3.new(2, 0, LADO + 4) },
		}
		for _, p in paredes do
			C.Parte({
				Name = "Pared",
				Size = p[2] + Vector3.new(0, ALTO_PARED, 0),
				CFrame = CFrame.new(A + p[1] + Vector3.new(0, ALTO_PARED / 2, 0)),
				Color = Color3.fromRGB(150, 220, 255),
				Material = Enum.Material.Glass,
				Transparency = 0.6,
				Parent = ronda.Carpeta,
			})
			C.Parte({
				Name = "ParedInvisible",
				Size = p[2] + Vector3.new(0, 80, 0),
				CFrame = CFrame.new(A + p[1] + Vector3.new(0, 40, 0)),
				Transparency = 1,
				Parent = ronda.Carpeta,
			})
		end
		C.Parte({
			Name = "Techo",
			Size = Vector3.new(LADO + 4, 2, LADO + 4),
			CFrame = CFrame.new(A + Vector3.new(0, 80, 0)),
			Transparency = 1,
			Parent = ronda.Carpeta,
		})

		-- Obstáculos para esconderse.
		for _, posicion in { Vector3.new(17, 0, 17), Vector3.new(-17, 0, 17), Vector3.new(17, 0, -17), Vector3.new(-17, 0, -17) } do
			C.Parte({
				Name = "Caja",
				Size = Vector3.new(7, 7, 7),
				CFrame = CFrame.new(A + posicion + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, math.rad(math.random(0, 90)), 0),
				Color = Color3.fromRGB(190, 130, 70),
				Material = Enum.Material.WoodPlanks,
				Parent = ronda.Carpeta,
			})
		end
		C.Disco(A + Vector3.new(0, 2.5, 0), 6, 2.5, {
			Name = "Centro",
			Color = Color3.fromRGB(165, 94, 234),
			Material = Enum.Material.Neon,
			Parent = ronda.Carpeta,
		})

		return C.Circulo(A, 26, 8)
	end,

	Iniciar = function(ronda: Ronda)
		local e: Estado = {
			Portador = nil,
			Bomba = nil,
			Resaltado = nil,
			Texto = nil,
			ExplotaEn = 0,
			UltimoPase = 0,
			SiguienteEn = nil,
		}
		estado = e
		nuevaBomba(ronda, e)

		ronda:Bucle(0.05, function()
			local portador = e.Portador
			if not portador then
				local siguiente = e.SiguienteEn
				if siguiente and os.clock() >= siguiente then
					e.SiguienteEn = nil
					nuevaBomba(ronda, e)
				end
				return
			end
			if not ronda:EstaVivo(portador) then
				quitarBomba(e)
				e.SiguienteEn = os.clock() + 1
				return
			end

			local restante = e.ExplotaEn - os.clock()
			if e.Texto then
				e.Texto.Text = `💣 {math.max(0, math.ceil(restante))}`
			end
			if restante <= 0 then
				explotar(ronda, e)
				return
			end

			-- ¿Está tocando a alguien? ¡Se la pasa!
			if os.clock() - e.UltimoPase < 0.8 then
				return
			end
			local raiz = Jugadores.Raiz(portador)
			if not raiz then
				return
			end
			for _, otro in ronda:Vivos() do
				if otro ~= portador then
					local raizOtro = Jugadores.Raiz(otro)
					if raizOtro and (raizOtro.Position - raiz.Position).Magnitude < 4.5 * ronda.Escala then
						if ponerBomba(ronda, e, otro) then
							ronda:Feed(`💣 {portador.DisplayName} le pasó la bomba a {otro.DisplayName}`)
						end
						return
					end
				end
			end
		end)

		-- Cuando acaba la ronda, borramos la bomba.
		task.spawn(function()
			while ronda.Activa do
				task.wait(0.5)
			end
			if estado == e then
				quitarBomba(e)
				estado = nil
			end
		end)
	end,

	AlEliminar = function(_ronda: Ronda, jugador: Player)
		local e = estado
		if e and e.Portador == jugador then
			quitarBomba(e)
			e.SiguienteEn = os.clock() + 1 -- el bucle principal pondrá otra
		end
	end,
}

return Minijuego
