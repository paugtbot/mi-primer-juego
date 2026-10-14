--!strict
-- 🎮 Una ronda de minijuego: quién sigue vivo, puntos, eliminaciones y limpieza.
-- Los minijuegos usan las funciones de aquí para no repetir código.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Compartido.Config)
local Remotos = require(ReplicatedStorage.Compartido.Remotos)
local Efectos = require(script.Parent.Efectos)
local Herramientas = require(script.Parent.Herramientas)
local Jugadores = require(script.Parent.Jugadores)
local Modificadores = require(script.Parent.Modificadores)

export type TipoJuego = "supervivencia" | "puntos" | "carrera"
type EstadoJugador = "vivo" | "eliminado" | "meta" | "fuera"

export type Minijuego = {
	Id: string,
	Nombre: string,
	Emoji: string,
	Descripcion: string,
	Tipo: TipoJuego,
	Duracion: number,
	AlturaMuerte: number, -- relativa al centro de la arena (ej: -30)
	Herramienta: boolean?, -- ¿dar Martillo Loco?
	FuerzaMartillo: number?,
	MultVelocidad: number?,
	MultSalto: number?,
	UnidadPuntaje: string?, -- texto para el marcador (ej: "👑")
	Construir: (ronda: Ronda) -> { CFrame },
	Iniciar: (ronda: Ronda) -> (),
	AlCaer: ((ronda: Ronda, jugador: Player) -> ())?,
	AlEliminar: ((ronda: Ronda, jugador: Player) -> ())?,
}

export type Fila = {
	Jugador: Player,
	Puesto: number,
	Detalle: string,
}

local Ronda = {}
Ronda.__index = Ronda

type Datos = {
	Minijuego: Minijuego,
	Modificador: Modificadores.Modificador,
	Participantes: { Player },
	Estados: { [Player]: EstadoJugador },
	Puntaje: { [Player]: number },
	OrdenEliminacion: { Player },
	OrdenLlegada: { Player },
	UltimaCaida: { [Player]: number },
	Colores: { [Player]: Color3 },
	Carpeta: Folder,
	Centro: Vector3,
	Spawns: { CFrame },
	Escala: number,
	Velocidad: number,
	Salto: number,
	Iniciada: boolean,
	Activa: boolean,
	Terminada: boolean,
	TiempoRestante: number,
	Conexiones: { RBXScriptConnection },
}

export type Ronda = typeof(setmetatable({} :: Datos, Ronda))

local FRASES_CAIDA = {
	"se cayó al vacío 🕳️",
	"aprendió a volar... mal 🪽",
	"se fue de vacaciones al abismo 🏖️",
	"dijo adiós muy fuerte 👋",
	"cayó como una patata 🥔",
	"se tiró de cabeza 🤸",
	"no vio el borde 🙈",
}

function Ronda.new(minijuego: Minijuego, modificador: Modificadores.Modificador, participantes: { Player }): Ronda
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Arena"

	local datos: Datos = {
		Minijuego = minijuego,
		Modificador = modificador,
		Participantes = table.clone(participantes),
		Estados = {},
		Puntaje = {},
		OrdenEliminacion = {},
		OrdenLlegada = {},
		UltimaCaida = {},
		Colores = {},
		Carpeta = carpeta,
		Centro = Config.ARENA_CENTRO,
		Spawns = {},
		Escala = modificador.Escala or 1,
		Velocidad = Config.VELOCIDAD_BASE * (minijuego.MultVelocidad or 1) * (modificador.MultVelocidad or 1),
		Salto = Config.SALTO_BASE * (minijuego.MultSalto or 1) * (modificador.MultSalto or 1),
		Iniciada = false,
		Activa = true,
		Terminada = false,
		TiempoRestante = minijuego.Duracion,
		Conexiones = {},
	}
	for i, jugador in datos.Participantes do
		datos.Estados[jugador] = "vivo"
		datos.Puntaje[jugador] = 0
		datos.Colores[jugador] = Config.COLORES[((i - 1) % #Config.COLORES) + 1]
	end
	return setmetatable(datos, Ronda)
end

-- ===== Utilidades para los minijuegos =====

function Ronda.Conectar(self: Ronda, senal: RBXScriptSignal, funcion: (...any) -> ()): RBXScriptConnection
	local conexion = senal:Connect(funcion)
	table.insert(self.Conexiones, conexion)
	return conexion
end

-- Repite `funcion` cada `intervalo` segundos mientras la ronda siga activa.
function Ronda.Bucle(self: Ronda, intervalo: number, funcion: () -> ())
	task.spawn(function()
		while self.Activa do
			local ok, err = pcall(funcion :: any)
			if not ok then
				warn("[LocuraTotal] Error en el minijuego:", err)
			end
			task.wait(intervalo)
		end
	end)
end

-- Espera y devuelve si la ronda sigue activa (para salir de bucles largos).
function Ronda.Esperar(self: Ronda, segundos: number): boolean
	task.wait(segundos)
	return self.Activa
end

function Ronda.Vivos(self: Ronda): { Player }
	local lista = {}
	for _, jugador in self.Participantes do
		if self.Estados[jugador] == "vivo" then
			table.insert(lista, jugador)
		end
	end
	return lista
end

function Ronda.EstaVivo(self: Ronda, jugador: Player): boolean
	return self.Estados[jugador] == "vivo"
end

-- Si `parte` pertenece al personaje de un jugador vivo de la ronda, lo devuelve.
function Ronda.JugadorDeParte(self: Ronda, parte: Instance): Player?
	local modelo = parte:FindFirstAncestorOfClass("Model")
	while modelo do
		local jugador = Players:GetPlayerFromCharacter(modelo)
		if jugador then
			if self.Estados[jugador] == "vivo" then
				return jugador
			end
			return nil
		end
		modelo = modelo:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function Ronda.Teletransportar(self: Ronda, jugador: Player, destino: CFrame)
	local personaje = jugador.Character
	if not personaje then
		return
	end
	local raiz = Jugadores.Raiz(jugador)
	if raiz then
		raiz.AssemblyLinearVelocity = Vector3.zero
	end
	personaje:PivotTo(destino + Vector3.new(0, 3.2 * self.Escala + 0.5, 0))
end

function Ronda.SumarPuntaje(self: Ronda, jugador: Player, cantidad: number)
	self.Puntaje[jugador] = (self.Puntaje[jugador] or 0) + cantidad
end

function Ronda.FijarPuntaje(self: Ronda, jugador: Player, cantidad: number)
	self.Puntaje[jugador] = cantidad
end

function Ronda.ObtenerPuntaje(self: Ronda, jugador: Player): number
	return self.Puntaje[jugador] or 0
end

function Ronda.Feed(_self: Ronda, texto: string)
	Remotos.Feed:FireAllClients(texto)
end

function Ronda.Anunciar(_self: Ronda, texto: string, color: Color3?, duracion: number?)
	Remotos.Anuncio:FireAllClients(texto, { Color = color, Duracion = duracion })
end

-- ===== Eliminaciones, llegadas y caídas =====

function Ronda.ComprobarFin(self: Ronda)
	if self.Terminada or not self.Iniciada then
		return
	end
	local vivos = #self:Vivos()
	if self.Minijuego.Tipo == "supervivencia" then
		local umbral = if #self.Participantes >= 2 then 1 else 0
		if vivos <= umbral then
			self.Terminada = true
		end
	elseif vivos == 0 then
		self.Terminada = true
	end
end

function Ronda.Eliminar(self: Ronda, jugador: Player, motivo: string?)
	if self.Estados[jugador] ~= "vivo" then
		return
	end
	self.Estados[jugador] = "eliminado"
	table.insert(self.OrdenEliminacion, jugador)
	Jugadores.EnRonda[jugador] = nil

	self:Feed(`💀 {jugador.DisplayName} {motivo or "quedó eliminado"}`)
	Remotos.Anuncio:FireClient(jugador, "¡ELIMINADO!", { Color = Color3.fromRGB(255, 71, 87), Duracion = 2 })

	local alEliminar = self.Minijuego.AlEliminar
	if alEliminar then
		task.spawn(alEliminar, self, jugador)
	end

	task.delay(1.5, function()
		if jugador.Parent == Players and not Jugadores.EnRonda[jugador] then
			Jugadores.Reaparecer(jugador)
		end
	end)

	self:ComprobarFin()
end

-- Para carreras: el jugador ha cruzado la meta.
function Ronda.Llegar(self: Ronda, jugador: Player)
	if self.Estados[jugador] ~= "vivo" then
		return
	end
	self.Estados[jugador] = "meta"
	table.insert(self.OrdenLlegada, jugador)
	local puesto = #self.OrdenLlegada

	self:Feed(`🏁 {jugador.DisplayName} llegó a la meta en el puesto {puesto}`)
	Remotos.Anuncio:FireClient(jugador, `¡META! Puesto {puesto}`, { Color = Color3.fromRGB(46, 213, 115), Duracion = 2.5 })
	local raiz = Jugadores.Raiz(jugador)
	if raiz then
		Efectos.Confeti(raiz.Position + Vector3.new(0, 4, 0), 100)
	end

	self:ComprobarFin()
end

-- Para juegos que no son de supervivencia: si te caes, vuelves a empezar.
function Ronda.Caer(self: Ronda, jugador: Player)
	local ahora = os.clock()
	if ahora - (self.UltimaCaida[jugador] or 0) < 1 then
		return
	end
	self.UltimaCaida[jugador] = ahora

	local alCaer = self.Minijuego.AlCaer
	if alCaer then
		alCaer(self, jugador)
	elseif #self.Spawns > 0 then
		self:Teletransportar(jugador, self.Spawns[math.random(1, #self.Spawns)])
	end
end

-- Un jugador se ha ido del juego: deja de contar (sin mensaje de "eliminado").
function Ronda.Abandonar(self: Ronda, jugador: Player)
	local estado = self.Estados[jugador]
	if estado == nil or estado == "fuera" then
		return
	end
	self.Estados[jugador] = "fuera"
	Jugadores.EnRonda[jugador] = nil
	if estado == "vivo" then
		self:Feed(`🚪 {jugador.DisplayName} abandonó la locura`)
		local alEliminar = self.Minijuego.AlEliminar
		if alEliminar then
			task.spawn(alEliminar, self, jugador)
		end
	end
	self:ComprobarFin()
end

-- Se ejecuta cada frame: revisa caídas y muertes.
function Ronda.Vigilar(self: Ronda)
	if not self.Activa or not self.Iniciada then
		return
	end
	local limite = self.Centro.Y + self.Minijuego.AlturaMuerte
	for _, jugador in self.Participantes do
		if self.Estados[jugador] == "vivo" and jugador.Parent ~= Players then
			self:Abandonar(jugador)
		elseif self.Estados[jugador] == "vivo" then
			local humanoide = Jugadores.Humanoide(jugador)
			local raiz = Jugadores.Raiz(jugador)
			if not humanoide or not raiz or humanoide.Health <= 0 then
				self:Eliminar(jugador, "se desintegró 💨")
			elseif raiz.Position.Y < limite then
				if self.Minijuego.Tipo == "supervivencia" then
					self:Eliminar(jugador, FRASES_CAIDA[math.random(1, #FRASES_CAIDA)])
				else
					self:Caer(jugador)
				end
			end
		end
	end
end

-- ===== Ciclo de vida de la ronda =====

-- 1) Construye la arena del minijuego.
function Ronda.Construir(self: Ronda)
	local vieja = workspace:FindFirstChild("Arena")
	if vieja then
		vieja:Destroy()
	end
	self.Carpeta.Parent = workspace
	self.Spawns = self.Minijuego.Construir(self)
	if self.Modificador.Hielo then
		Modificadores.AplicarHielo(self.Carpeta)
	end
end

-- 2) Lleva a todos a la arena, aplica el modo loco y los congela.
function Ronda.Preparar(self: Ronda)
	-- Si alguien se va (incluso durante la cuenta atrás), deja de contar.
	self:Conectar(Players.PlayerRemoving, function(jugador: Player)
		self:Abandonar(jugador)
	end)
	for i, jugador in self.Participantes do
		local personaje = jugador.Character
		local humanoide = Jugadores.Humanoide(jugador)
		if personaje and humanoide and humanoide.Health > 0 then
			Jugadores.EnRonda[jugador] = true
			if self.Escala ~= 1 then
				local escala = self.Escala
				pcall(function()
					personaje:ScaleTo(escala)
				end)
			end
			humanoide.UseJumpPower = true
			humanoide.WalkSpeed = 0
			humanoide.JumpPower = 0
			if #self.Spawns > 0 then
				self:Teletransportar(jugador, self.Spawns[((i - 1) % #self.Spawns) + 1])
			end
			if self.Minijuego.Herramienta then
				Herramientas.DarMartillo(jugador, self.Colores[jugador], self.Minijuego.FuerzaMartillo)
			end
		else
			self.Estados[jugador] = "fuera"
		end
	end
end

-- 3) ¡YA! Descongela a todos y arranca el minijuego.
function Ronda.Iniciar(self: Ronda)
	self.Iniciada = true
	for _, jugador in self:Vivos() do
		local humanoide = Jugadores.Humanoide(jugador)
		if humanoide then
			humanoide.WalkSpeed = self.Velocidad
			humanoide.JumpPower = self.Salto
		end
	end

	self:Conectar(RunService.Heartbeat, function()
		self:Vigilar()
	end)
	for _, jugador in self.Participantes do
		if jugador.Parent ~= Players then
			self:Abandonar(jugador)
		end
	end

	task.spawn(function()
		local ok, err = pcall(self.Minijuego.Iniciar :: any, self)
		if not ok then
			warn("[LocuraTotal] Error al iniciar el minijuego:", err)
		end
	end)

	self:ComprobarFin()
end

-- 4) Para todo (los bucles de los minijuegos terminan solos).
function Ronda.Detener(self: Ronda)
	self.Activa = false
	self.Terminada = true
	for _, conexion in self.Conexiones do
		conexion:Disconnect()
	end
	table.clear(self.Conexiones)
end

-- 5) Devuelve a todos al lobby y borra la arena.
function Ronda.Limpiar(self: Ronda)
	self:Detener()
	for _, jugador in self.Participantes do
		local estaba = Jugadores.EnRonda[jugador]
		Jugadores.EnRonda[jugador] = nil
		if estaba and jugador.Parent == Players then
			Jugadores.Reaparecer(jugador)
		end
	end
	local carpeta = self.Carpeta
	task.delay(1, function()
		carpeta:Destroy()
	end)
end

-- ===== Resultados =====

local function ordenarPorPuntaje(self: Ronda, lista: { Player }, desde: number, filas: { Fila }, sufijo: string)
	table.sort(lista, function(a, b)
		return self:ObtenerPuntaje(a) > self:ObtenerPuntaje(b)
	end)
	local puestoAnterior = desde
	local puntajeAnterior: number? = nil
	for i, jugador in lista do
		local puntaje = self:ObtenerPuntaje(jugador)
		local puesto = if puntajeAnterior ~= nil and puntaje == puntajeAnterior then puestoAnterior else desde + i - 1
		puestoAnterior = puesto
		puntajeAnterior = puntaje
		table.insert(filas, {
			Jugador = jugador,
			Puesto = puesto,
			Detalle = `{math.floor(puntaje)} {sufijo}`,
		})
	end
end

function Ronda.Ranking(self: Ronda): { Fila }
	local filas: { Fila } = {}
	local function sigue(jugador: Player): boolean
		return jugador.Parent == Players and self.Estados[jugador] ~= "fuera"
	end

	local tipo = self.Minijuego.Tipo
	if tipo == "supervivencia" then
		local supervivientes = 0
		for _, jugador in self.Participantes do
			if self.Estados[jugador] == "vivo" and sigue(jugador) then
				supervivientes += 1
				table.insert(filas, { Jugador = jugador, Puesto = 1, Detalle = "¡Sobrevivió!" })
			end
		end
		local siguiente = supervivientes + 1
		for i = #self.OrdenEliminacion, 1, -1 do
			local jugador = self.OrdenEliminacion[i]
			if sigue(jugador) then
				table.insert(filas, { Jugador = jugador, Puesto = siguiente, Detalle = "Eliminado" })
				siguiente += 1
			end
		end
	elseif tipo == "puntos" then
		local lista = {}
		for _, jugador in self.Participantes do
			if sigue(jugador) then
				table.insert(lista, jugador)
			end
		end
		ordenarPorPuntaje(self, lista, 1, filas, self.Minijuego.UnidadPuntaje or "pts")
	else
		for _, jugador in self.OrdenLlegada do
			if sigue(jugador) then
				table.insert(filas, { Jugador = jugador, Puesto = #filas + 1, Detalle = "🏁 Meta" })
			end
		end
		local resto = {}
		for _, jugador in self.Participantes do
			if self.Estados[jugador] ~= "meta" and sigue(jugador) then
				table.insert(resto, jugador)
			end
		end
		local antes = #filas
		ordenarPorPuntaje(self, resto, antes + 1, filas, "m")
		for i = antes + 1, #filas do
			filas[i].Detalle = "No llegó (" .. filas[i].Detalle .. ")"
		end
	end
	return filas
end

-- Información para la barra de arriba de cada jugador.
function Ronda.EstadoCliente(self: Ronda): { [string]: any }
	local vivosIds = {}
	for _, jugador in self:Vivos() do
		table.insert(vivosIds, jugador.UserId)
	end

	local marcador = nil
	if self.Minijuego.Tipo == "puntos" then
		local lista = {}
		for _, jugador in self.Participantes do
			if jugador.Parent == Players and self.Estados[jugador] ~= "fuera" then
				table.insert(lista, jugador)
			end
		end
		table.sort(lista, function(a, b)
			return self:ObtenerPuntaje(a) > self:ObtenerPuntaje(b)
		end)
		marcador = {}
		for _, jugador in lista do
			table.insert(marcador, {
				Nombre = jugador.DisplayName,
				Puntos = math.floor(self:ObtenerPuntaje(jugador)),
				Id = jugador.UserId,
			})
		end
	end

	return {
		Fase = "ronda",
		Texto = `{self.Minijuego.Emoji} {self.Minijuego.Nombre}`,
		Tiempo = self.TiempoRestante,
		Modo = `{self.Modificador.Emoji} {self.Modificador.Nombre}`,
		Vivos = #vivosIds,
		Total = #self.Participantes,
		VivosIds = vivosIds,
		Marcador = marcador,
		Unidad = self.Minijuego.UnidadPuntaje,
		Llegados = if self.Minijuego.Tipo == "carrera" then #self.OrdenLlegada else nil,
	}
end

return Ronda
