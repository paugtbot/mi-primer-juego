--!strict
-- 🔁 EL BUCLE DEL JUEGO:
-- esperar jugadores -> ruleta -> minijuego -> resultados -> ... -> ¡CAMPEÓN!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Compartido.Config)
local Remotos = require(ReplicatedStorage.Compartido.Remotos)
local Efectos = require(script.Parent.Efectos)
local Jugadores = require(script.Parent.Jugadores)
local Lobby = require(script.Parent.Lobby)
local Modificadores = require(script.Parent.Modificadores)
local Ronda = require(script.Parent.Ronda)

local Minijuegos = script.Parent.Minijuegos
local LISTA: { Ronda.Minijuego } = {
	require(Minijuegos.SueloQueCae),
	require(Minijuegos.Meteoritos),
	require(Minijuegos.ReyColina),
	require(Minijuegos.PatataBomba),
	require(Minijuegos.Licuadora),
	require(Minijuegos.CarreraLoca),
	require(Minijuegos.SumoHielo),
	require(Minijuegos.RampaRodante),
}

local Juego = {}

local DORADO = Color3.fromRGB(255, 205, 40)
local VERDE = Color3.fromRGB(46, 213, 115)

local function estado(datos: { [string]: any })
	Remotos.Estado:FireAllClients(datos)
end

local function anuncio(texto: string, opciones: { [string]: any }?)
	Remotos.Anuncio:FireAllClients(texto, opciones or {})
end

local function minimoJugadores(): number
	return if RunService:IsStudio() then 1 else Config.MIN_JUGADORES
end

-- ===== Elegir minijuego (sin repetir hasta que salgan todos) =====

local bolsa: { Ronda.Minijuego } = {}
local ultimo: Ronda.Minijuego? = nil

local function siguienteMinijuego(): Ronda.Minijuego
	if #bolsa == 0 then
		for _, minijuego in LISTA do
			table.insert(bolsa, minijuego)
		end
		for i = #bolsa, 2, -1 do
			local j = math.random(1, i)
			bolsa[i], bolsa[j] = bolsa[j], bolsa[i]
		end
		-- Que no salga el mismo dos veces seguidas.
		if ultimo and bolsa[#bolsa] == ultimo and #bolsa > 1 then
			bolsa[#bolsa], bolsa[1] = bolsa[1], bolsa[#bolsa]
		end
	end
	local elegido = table.remove(bolsa) :: Ronda.Minijuego
	ultimo = elegido
	return elegido
end

-- ===== Fases =====

local function esperarJugadores()
	local soloDesde: number? = nil
	while true do
		local listos = #Jugadores.Listos()
		local minimo = minimoJugadores()
		if listos >= minimo then
			return
		end
		if listos >= 1 then
			local desde = soloDesde or os.clock()
			soloDesde = desde
			local falta = Config.ESPERA_SOLO - (os.clock() - desde)
			if falta <= 0 then
				anuncio("🧪 MODO PRÁCTICA", { Subtitulo = "¡Invita a tus amigos para jugar de verdad!", Duracion = 3 })
				return
			end
			estado({
				Fase = "espera",
				Texto = `⏳ Esperando locos ({listos}/{minimo}) · práctica en {math.ceil(falta)}`,
			})
		else
			soloDesde = nil
		end
		task.wait(1)
	end
end

local function intermedio(numero: number)
	local segundos = if RunService:IsStudio() then Config.TIEMPO_INTERMEDIO_STUDIO else Config.TIEMPO_INTERMEDIO
	for s = segundos, 1, -1 do
		estado({
			Fase = "intermedio",
			Texto = `🎲 Ronda {numero}/{Config.RONDAS_POR_PARTIDA} en...`,
			Tiempo = s,
		})
		task.wait(1)
	end
end

local function ruleta(titulo: string, opciones: { string }, elegido: number, duracion: number)
	Remotos.Ruleta:FireAllClients({
		Titulo = titulo,
		Opciones = opciones,
		Elegido = elegido,
		Duracion = duracion,
	})
	task.wait(duracion + 1.3)
end

-- Por si algo falla a mitad de ronda: lo deja todo limpio.
local function limpiezaDeEmergencia()
	Modificadores.QuitarMundo()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		arena:Destroy()
	end
	for _, jugador in Players:GetPlayers() do
		if Jugadores.EnRonda[jugador] then
			Jugadores.EnRonda[jugador] = nil
			Jugadores.Reaparecer(jugador)
		end
	end
end

local function jugarRonda(numero: number): boolean
	local minijuego = siguienteMinijuego()
	local modificador = Modificadores.Elegir(numero)

	-- 🎲 Ruleta del minijuego
	local nombres = {}
	local indice = 1
	for i, m in LISTA do
		table.insert(nombres, `{m.Emoji} {m.Nombre}`)
		if m == minijuego then
			indice = i
		end
	end
	estado({ Fase = "ruleta", Texto = `🎲 Ronda {numero}/{Config.RONDAS_POR_PARTIDA}: ¡girando la ruleta!` })
	ruleta("🎲 MINIJUEGO", nombres, indice, 3.5)

	-- 🌀 Ruleta del modo loco
	local nombresMod = {}
	local indiceMod = 1
	for i, m in Modificadores.Lista do
		table.insert(nombresMod, `{m.Emoji} {m.Nombre}`)
		if m.Id == modificador.Id then
			indiceMod = i
		end
	end
	ruleta("🌀 MODO LOCO", nombresMod, indiceMod, 3)
	if modificador.Id ~= "Normal" then
		anuncio(`{modificador.Emoji} {modificador.Nombre}`, {
			Subtitulo = modificador.Descripcion,
			Color = Color3.fromRGB(165, 94, 234),
			Duracion = 2.5,
		})
		task.wait(2.5)
	end

	local participantes = Jugadores.Listos()
	if #participantes == 0 then
		return false
	end

	-- 🏗️ Construir la arena y llevar a todos
	local ronda = Ronda.new(minijuego, modificador, participantes)
	estado({ Fase = "preparando", Texto = `{minijuego.Emoji} Preparando {minijuego.Nombre}...` })
	ronda:Construir()
	Modificadores.AplicarMundo(modificador)
	ronda:Preparar()

	-- 📢 Instrucciones mientras están congelados
	anuncio(`{minijuego.Emoji} {minijuego.Nombre}`, {
		Subtitulo = minijuego.Descripcion,
		Color = DORADO,
		Duracion = 4.5,
	})
	estado({
		Fase = "preparando",
		Texto = `{minijuego.Emoji} {minijuego.Nombre}`,
		Modo = `{modificador.Emoji} {modificador.Nombre}`,
	})
	task.wait(5)
	for i = 3, 1, -1 do
		anuncio(tostring(i), { Duracion = 0.9, Cuenta = true })
		task.wait(1)
	end
	anuncio("¡YA!", { Duracion = 1, Color = VERDE, Cuenta = true, Final = true })
	ronda:Iniciar()

	-- ⏱️ Jugar hasta que se acabe el tiempo o el minijuego termine
	local fin = os.clock() + minijuego.Duracion
	while not ronda.Terminada do
		local restante = fin - os.clock()
		if restante <= 0 then
			break
		end
		ronda.TiempoRestante = math.ceil(restante)
		estado(ronda:EstadoCliente())
		task.wait(0.25)
	end
	local porTiempo = not ronda.Terminada
	ronda.TiempoRestante = 0
	ronda:Detener()
	anuncio(if porTiempo then "⏰ ¡TIEMPO!" else "🏁 ¡FIN!", { Duracion = 2, Color = Color3.fromRGB(255, 165, 2) })
	local final = ronda:EstadoCliente()
	final.Fase = "fin"
	estado(final)
	task.wait(2)

	-- 🏆 Resultados y puntos
	local filas = ronda:Ranking()
	local datosFilas = {}
	local ganadores = {}
	for _, fila in filas do
		local puntos = Config.PUNTOS_POR_PUESTO[fila.Puesto] or 1
		Jugadores.SumarPuntos(fila.Jugador, puntos)
		table.insert(datosFilas, {
			Puesto = fila.Puesto,
			Nombre = fila.Jugador.DisplayName,
			Id = fila.Jugador.UserId,
			Detalle = fila.Detalle,
			Puntos = puntos,
			Total = Jugadores.Puntos(fila.Jugador),
		})
		if fila.Puesto == 1 then
			table.insert(ganadores, fila.Jugador.DisplayName)
			local raiz = Jugadores.Raiz(fila.Jugador)
			if raiz then
				Efectos.Confeti(raiz.Position + Vector3.new(0, 5, 0), 120)
			end
		end
	end
	if #ganadores > 0 then
		anuncio(`🏆 ¡{table.concat(ganadores, " y ")} gana!`, { Color = DORADO, Duracion = 3 })
	end
	Remotos.Resultados:FireAllClients({
		Titulo = `{minijuego.Emoji} {minijuego.Nombre}`,
		Filas = datosFilas,
		Duracion = Config.TIEMPO_RESULTADOS,
	})
	estado({ Fase = "resultados", Texto = "📊 Resultados de la ronda" })
	task.wait(Config.TIEMPO_RESULTADOS)

	-- 🧹 Volver al lobby
	Modificadores.QuitarMundo()
	ronda:Limpiar()
	return true
end

-- 👑 Ceremonia final con podio, confeti y fuegos artificiales.
local function ceremonia()
	local lista = Players:GetPlayers()
	if #lista == 0 then
		return
	end
	table.sort(lista, function(a, b)
		return Jugadores.Puntos(a) > Jugadores.Puntos(b)
	end)
	local maximo = Jugadores.Puntos(lista[1])
	local campeones = {}
	for _, jugador in lista do
		if Jugadores.Puntos(jugador) == maximo and maximo > 0 then
			table.insert(campeones, jugador.DisplayName)
			Jugadores.SumarCorona(jugador)
		end
	end
	if #campeones == 0 then
		Jugadores.ReiniciarPuntos()
		return
	end

	estado({ Fase = "ceremonia", Texto = "👑 ¡CEREMONIA DE CAMPEONES! 👑" })
	task.wait(1.5) -- que todos terminen de aparecer en el lobby

	local podio = {}
	for i = 1, math.min(3, #lista) do
		local jugador = lista[i]
		local personaje = jugador.Character
		local arriba = Lobby.Podio[i]
		if personaje and arriba then
			personaje:PivotTo(CFrame.lookAt(arriba + Vector3.new(0, 3.5, 0), arriba + Vector3.new(0, 3.5, 10)))
			local humanoide = Jugadores.Humanoide(jugador)
			if humanoide then
				humanoide.WalkSpeed = 0
				humanoide.JumpPower = 0
				task.delay(Config.TIEMPO_CEREMONIA - 2, function()
					if humanoide.Parent then
						humanoide.WalkSpeed = Config.VELOCIDAD_BASE
						humanoide.JumpPower = Config.SALTO_BASE
					end
				end)
			end
		end
		table.insert(podio, {
			Puesto = i,
			Nombre = jugador.DisplayName,
			Id = jugador.UserId,
			Puntos = Jugadores.Puntos(jugador),
		})
	end

	Remotos.Campeon:FireAllClients({ Nombres = campeones, Podio = podio })
	anuncio(`👑 ¡{table.concat(campeones, " y ")}: CAMPEÓN! 👑`, {
		Subtitulo = `{maximo} puntos · ¡Ganas una CORONA!`,
		Color = DORADO,
		Duracion = 6,
	})

	local fin = os.clock() + Config.TIEMPO_CEREMONIA
	while os.clock() < fin do
		Efectos.FuegoArtificial(Lobby.Podio[1] + Vector3.new(math.random(-30, 30), 0, math.random(-12, 12)))
		task.wait(0.4)
	end
	Jugadores.ReiniciarPuntos()
end

local function bucle()
	while true do
		esperarJugadores()
		local jugadas = 0
		for numero = 1, Config.RONDAS_POR_PARTIDA do
			if #Players:GetPlayers() == 0 then
				break
			end
			intermedio(numero)
			local ok, resultado = pcall(jugarRonda, numero)
			if not ok then
				warn("[LocuraTotal] Error en la ronda:", resultado)
				limpiezaDeEmergencia()
				task.wait(2)
			elseif resultado then
				jugadas += 1
			end
		end
		if jugadas > 0 then
			local ok, err = pcall(ceremonia :: any)
			if not ok then
				warn("[LocuraTotal] Error en la ceremonia:", err)
				Jugadores.ReiniciarPuntos()
			end
		end
		task.wait(1)
	end
end

function Juego.Iniciar()
	task.spawn(bucle)
end

return Juego
