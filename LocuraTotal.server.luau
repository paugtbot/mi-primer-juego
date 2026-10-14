--!strict
--[[
	🤪 LOCURA TOTAL — juego de fiesta para 8 jugadores (Roblox)
	=============================================================
	TODO el juego está en ESTE ÚNICO SCRIPT.

	CÓMO USARLO:
	  1. Abre Roblox Studio y crea un lugar nuevo (por ejemplo, "Baseplate").
	  2. En el Explorer: botón derecho en ServerScriptService → Insert Object → Script.
	  3. Borra lo que trae el Script y pega TODO este código.
	  4. Pulsa ▶ Play. ¡Ya está! (En Studio puedes jugar solo para probar.)

	Para jugar con amigos: File → Publish to Roblox, y en la configuración del
	juego pon el tamaño del servidor (Server Size / Max Players) a 8.

	El mundo (lobby, grada y minijuegos) se construye solo al empezar.
	Puedes cambiar casi todo en la sección ⚙️ CONFIGURACIÓN de aquí abajo.

	QUÉ HAY DENTRO:
	  • 13 minijuegos que se eligen votando (pisando una plataforma del lobby)
	  • 12 MODOS LOCOS que se eligen con una ruleta
	  • Cajas sorpresa ❓ con poderes, Martillo Loco 🔨, botón rojo 🔴 "NO PULSAR"
	  • Grada para ver la ronda cuando te eliminan, podio y fuegos artificiales
	  • Coronas 👑, victorias, niveles y títulos que se guardan para siempre
]]

-- =====================================================================
-- 🧰 SERVICIOS DE ROBLOX
-- =====================================================================

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

-- =====================================================================
-- ⚙️ CONFIGURACIÓN (¡cambia estos números para modificar el juego!)
-- =====================================================================

local Config = {
	NOMBRE = "LOCURA TOTAL",

	-- 👥 Jugadores
	MAX_JUGADORES = 8, -- el juego está pensado para 8 locos
	MIN_JUGADORES = 2, -- mínimo para una partida normal
	ESPERA_SOLO = 20, -- si estás solo este tiempo, empieza el modo práctica

	-- ⏱️ Tiempos (segundos)
	RONDAS_POR_PARTIDA = 6,
	TIEMPO_VOTACION = 15,
	TIEMPO_VOTACION_STUDIO = 8, -- más corto al probar en Roblox Studio
	TIEMPO_RESULTADOS = 6,
	TIEMPO_CEREMONIA = 14,
	TIEMPO_REAPARECER = 2.5,

	-- 🏆 Puntos según el puesto (1º, 2º, 3º...)
	PUNTOS_POR_PUESTO = { 10, 7, 5, 4, 3, 2, 1, 1 },
	ULTIMA_RONDA_DOBLE = true, -- la última ronda de cada partida vale el doble

	-- 🎁 Extras
	CAJAS_SORPRESA = true, -- cajas ❓ con poderes en algunos minijuegos
	BOTON_ROJO_ESPERA = 25, -- segundos de recarga del botón rojo del lobby
	GUARDAR_DATOS = true, -- guardar coronas, victorias y nivel (juego publicado)
	QUITAR_BASEPLATE = true, -- quita el suelo gris de la plantilla "Baseplate"

	-- 🗺️ Dónde está todo
	LOBBY = Vector3.new(0, 50, 0),
	ARENA = Vector3.new(0, 120, 420),
	GRADA = Vector3.new(-100, 162, 420),
	VACIO_LOBBY = -60, -- si caes por debajo de esta altura (fuera de una ronda), reapareces

	-- 🏃 Movimiento normal
	VELOCIDAD = 16,
	SALTO = 50,
	GRAVEDAD = 196.2,

	-- 🎨 Colores locos (uno por jugador)
	COLORES = {
		Color3.fromRGB(255, 71, 87), -- rojo
		Color3.fromRGB(255, 165, 2), -- naranja
		Color3.fromRGB(255, 221, 89), -- amarillo
		Color3.fromRGB(46, 213, 115), -- verde
		Color3.fromRGB(30, 144, 255), -- azul
		Color3.fromRGB(165, 94, 234), -- morado
		Color3.fromRGB(255, 107, 203), -- rosa
		Color3.fromRGB(0, 210, 211), -- turquesa
	},
}

local FUENTE = Font.fromEnum(Enum.Font.FredokaOne)
local OSCURO = Color3.fromRGB(20, 18, 36)
local BLANCO = Color3.new(1, 1, 1)
local DORADO = Color3.fromRGB(255, 205, 40)
local ROJO = Color3.fromRGB(255, 71, 87)
local VERDE = Color3.fromRGB(46, 213, 115)
local MORADO = Color3.fromRGB(165, 94, 234)
local NARANJA = Color3.fromRGB(255, 165, 2)
local CIAN = Color3.fromRGB(0, 210, 211)

local SONIDOS = {
	Pip = "rbxasset://sounds/electronicpingshort.wav",
	Golpe = "rbxasset://sounds/swordslash.wav",
	Swing = "rbxasset://sounds/swordlunge.wav",
	Salto = "rbxasset://sounds/action_jump.mp3",
}

-- Cosas del mundo que se rellenan al construirlo.
local Mundo = {
	Grada = {} :: { CFrame }, -- sitios de la grada de espectadores
	Podio = { -- superficie de los 3 bloques del podio
		Config.LOBBY + Vector3.new(0, 6, -40),
		Config.LOBBY + Vector3.new(-9, 4, -40),
		Config.LOBBY + Vector3.new(9, 2.5, -40),
	} :: { Vector3 },
}

-- =====================================================================
-- 🔧 UTILIDADES
-- =====================================================================

local Util = {}

function Util.Elegir<T>(lista: { T }): T
	return lista[math.random(1, #lista)]
end

function Util.Mezclar<T>(lista: { T }): { T }
	for i = #lista, 2, -1 do
		local j = math.random(1, i)
		lista[i], lista[j] = lista[j], lista[i]
	end
	return lista
end

function Util.Aleatorio(minimo: number, maximo: number): number
	return minimo + math.random() * (maximo - minimo)
end

function Util.FormatoTiempo(segundos: number): string
	local s = math.max(0, math.floor(segundos))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Dirección horizontal (sin altura) de `desde` a `hacia`.
function Util.Direccion(desde: Vector3, hacia: Vector3, porDefecto: Vector3?): Vector3
	local plano = Vector3.new(hacia.X - desde.X, 0, hacia.Z - desde.Z)
	if plano.Magnitude < 0.05 then
		return porDefecto or Vector3.new(1, 0, 0)
	end
	return plano.Unit
end

function Util.DistanciaPlana(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Un punto al azar dentro de un círculo (repartido de forma uniforme).
function Util.PuntoEnCirculo(centro: Vector3, radio: number): Vector3
	local angulo = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * radio
	return centro + Vector3.new(math.cos(angulo) * r, 0, math.sin(angulo) * r)
end

-- Cambia una propiedad solo si es distinta (ahorra red).
local function poner(objeto: Instance, propiedad: string, valor: any)
	if (objeto :: any)[propiedad] ~= valor then
		(objeto :: any)[propiedad] = valor
	end
end

-- =====================================================================
-- 🧱 CONSTRUCTOR: funciones para crear piezas rápido
-- =====================================================================

local C = {}

export type Props = { [string]: any }

-- Aplica propiedades. Claves especiales: Tags = {...}, Atributos = {...}.
-- Parent se pone al final (es más eficiente).
function C.Aplicar(instancia: Instance, props: Props?)
	if not props then
		return
	end
	for clave, valor in props do
		if clave ~= "Parent" and clave ~= "Tags" and clave ~= "Atributos" then
			(instancia :: any)[clave] = valor
		end
	end
	if props.Atributos then
		for nombre, valor in props.Atributos do
			instancia:SetAttribute(nombre, valor)
		end
	end
	if props.Tags then
		for _, etiqueta in props.Tags do
			instancia:AddTag(etiqueta)
		end
	end
	if props.Parent then
		instancia.Parent = props.Parent
	end
end

local function baseParte(parte: BasePart)
	parte.Anchored = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	parte.Material = Enum.Material.SmoothPlastic
end

function C.Parte(props: Props?): Part
	local parte = Instance.new("Part")
	baseParte(parte)
	C.Aplicar(parte, props)
	return parte
end

-- Disco (cilindro en vertical). `arriba` = centro de la cara de arriba.
function C.Disco(arriba: Vector3, radio: number, grosor: number, props: Props?): Part
	local parte = Instance.new("Part")
	baseParte(parte)
	parte.Shape = Enum.PartType.Cylinder
	parte.Size = Vector3.new(grosor, radio * 2, radio * 2)
	parte.CFrame = CFrame.new(arriba - Vector3.new(0, grosor / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	C.Aplicar(parte, props)
	return parte
end

function C.Bola(centro: Vector3, diametro: number, props: Props?): Part
	local parte = Instance.new("Part")
	baseParte(parte)
	parte.Shape = Enum.PartType.Ball
	parte.Size = Vector3.new(diametro, diametro, diametro)
	parte.CFrame = CFrame.new(centro)
	C.Aplicar(parte, props)
	return parte
end

function C.Cuna(props: Props?): WedgePart
	local parte = Instance.new("WedgePart")
	baseParte(parte)
	C.Aplicar(parte, props)
	return parte
end

-- Cartel con texto pegado a una cara de una parte.
function C.Cartel(parte: BasePart, cara: Enum.NormalId, texto: string, color: Color3?, pixelesPorStud: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = cara
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelesPorStud or 25
	gui.LightInfluence = 0
	gui.Parent = parte

	local etiqueta = Instance.new("TextLabel")
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.BackgroundTransparency = 1
	etiqueta.FontFace = FUENTE
	etiqueta.TextScaled = true
	etiqueta.Text = texto
	etiqueta.TextColor3 = color or BLANCO
	etiqueta.TextStrokeTransparency = 0
	etiqueta.Parent = gui
	return etiqueta
end

-- Texto flotante que siempre mira a la cámara.
function C.Flotante(adornee: BasePart, texto: string, alto: number, ancho: number, desplazamiento: Vector3?, color: Color3?): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(ancho, alto)
	gui.StudsOffset = desplazamiento or Vector3.new(0, 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Adornee = adornee
	gui.Parent = adornee

	local etiqueta = Instance.new("TextLabel")
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.BackgroundTransparency = 1
	etiqueta.FontFace = FUENTE
	etiqueta.TextScaled = true
	etiqueta.Text = texto
	etiqueta.TextColor3 = color or BLANCO
	etiqueta.TextStrokeTransparency = 0
	etiqueta.Parent = gui
	return gui, etiqueta
end

function C.Soldar(a: BasePart, b: BasePart): WeldConstraint
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = a
	soldadura.Part1 = b
	soldadura.Parent = a
	return soldadura
end

function C.Luz(parte: BasePart, color: Color3, brillo: number?, alcance: number?): PointLight
	local luz = Instance.new("PointLight")
	luz.Color = color
	luz.Brightness = brillo or 2
	luz.Range = alcance or 16
	luz.Parent = parte
	return luz
end

-- Puntos de aparición en círculo, mirando al centro (`centro` a ras de suelo).
function C.Circulo(centro: Vector3, radio: number, cantidad: number): { CFrame }
	local lista = {}
	for i = 1, cantidad do
		local angulo = (i - 1) / cantidad * math.pi * 2 + math.pi / cantidad
		local posicion = centro + Vector3.new(math.cos(angulo) * radio, 0, math.sin(angulo) * radio)
		table.insert(lista, CFrame.lookAt(posicion, Vector3.new(centro.X, posicion.Y, centro.Z)))
	end
	return lista
end

-- Puntos de aparición en filas (para carreras), mirando hacia +Z.
function C.Parrilla(centro: Vector3, columnas: number, filas: number, separacion: number): { CFrame }
	local lista = {}
	for f = 1, filas do
		for c = 1, columnas do
			local posicion = centro
				+ Vector3.new((c - (columnas + 1) / 2) * separacion, 0, (f - (filas + 1) / 2) * separacion)
			table.insert(lista, CFrame.lookAt(posicion, posicion + Vector3.new(0, 0, 1)))
		end
	end
	return lista
end

-- Une una parte a un eje fijo con un motor (bisagra vertical). Devuelve la bisagra.
-- Con física: se ve suave para todos los jugadores.
local GIRO_VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- el eje X de la bisagra pasa a ser Y
function C.Motor(parte: BasePart, velocidad: number): HingeConstraint
	local eje = C.Parte({
		Name = "Eje" .. parte.Name,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(parte.CFrame.Position),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parte.Parent,
	})
	local a0 = Instance.new("Attachment")
	a0.CFrame = GIRO_VERTICAL
	a0.Parent = eje
	local a1 = Instance.new("Attachment")
	a1.CFrame = parte.CFrame:ToObjectSpace(eje.CFrame * GIRO_VERTICAL)
	a1.Parent = parte

	local bisagra = Instance.new("HingeConstraint")
	bisagra.Attachment0 = a0
	bisagra.Attachment1 = a1
	bisagra.ActuatorType = Enum.ActuatorType.Motor
	bisagra.MotorMaxTorque = math.huge
	bisagra.MotorMaxAcceleration = math.huge
	bisagra.AngularVelocity = velocidad
	bisagra.Parent = parte
	parte.Anchored = false
	pcall(function()
		parte:SetNetworkOwner(nil)
	end)
	return bisagra
end

-- Barra giratoria (licuadoras). Arranca parada; pon AngularVelocity para que gire.
function C.BarraGiratoria(centro: Vector3, largo: number, grosor: number, color: Color3, padre: Instance): (Part, HingeConstraint)
	local barra = C.Parte({
		Name = "Barra",
		Size = Vector3.new(largo, grosor, grosor),
		CFrame = CFrame.new(centro),
		Color = color,
		Material = Enum.Material.Neon,
		CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0.5),
		Parent = padre,
	})
	return barra, C.Motor(barra, 0)
end

-- =====================================================================
-- 🖥️ INTERFAZ (la crea el servidor para cada jugador)
-- =====================================================================

type UIJugador = {
	Gui: ScreenGui,
	Estado: TextLabel,
	Tiempo: TextLabel,
	Modo: TextLabel,
	Info: TextLabel,
	Poder: TextLabel,
	Dobles: TextLabel,
	Anuncio: TextLabel,
	EscalaAnuncio: UIScale,
	Subtitulo: TextLabel,
	Ruleta: Frame,
	TituloRuleta: TextLabel,
	OpcionRuleta: TextLabel,
	EscalaRuleta: UIScale,
	Feed: Frame,
	Resultados: Frame,
	TituloResultados: TextLabel,
	ListaResultados: Frame,
	EscalaResultados: UIScale,
	Marcador: Frame,
	TituloMarcador: TextLabel,
	FilasMarcador: { TextLabel },
	Consejo: TextLabel,
	TokenAnuncio: number,
	TokenPoder: number,
}

export type FilaMarcador = { Nombre: string, Puntos: number, Id: number }

export type DatosEstado = {
	Fase: string,
	Texto: string,
	Tiempo: number?,
	Modo: string?,
	Info: string?,
	Dobles: boolean?,
	Marcador: { FilaMarcador }?,
	Unidad: string?,
}

export type OpcionesAnuncio = {
	Color: Color3?,
	Duracion: number?,
	Subtitulo: string?,
	Cuenta: boolean?, -- suena un "pip"
	Final: boolean?, -- "pip" más agudo
}

export type FilaResultado = {
	Puesto: number,
	Nombre: string,
	Id: number,
	Detalle: string,
	Puntos: number,
	Total: number,
}

local UI = {
	Por = {} :: { [Player]: UIJugador },
}

local CONSEJOS = {
	"💡 Pisa una plataforma de votación del lobby para elegir el próximo minijuego",
	"💡 Las cajas ❓ dan poderes: turbo, escudo, globo, onda expansiva...",
	"💡 Con el Martillo Loco 🔨 haz clic para mandar a volar a los demás",
	"💡 Prueba el cañón humano 🚀 del lobby: lleva a una isla secreta",
	"💡 El botón rojo del lobby... mejor NO lo pulses 😈",
	"💡 La última ronda de cada partida vale PUNTOS DOBLES 🔥",
	"💡 Si te eliminan, verás la ronda desde la grada 👀",
	"💡 Gana partidas para conseguir coronas 👑 y subir de nivel",
	"💡 En Luz Roja, Luz Verde... ¡ni se te ocurra moverte en rojo! 🔴",
}

local function crear(clase: string, props: { [string]: any }, padre: Instance?): any
	local objeto = Instance.new(clase :: any)
	for clave, valor in props do
		(objeto :: any)[clave] = valor
	end
	if padre then
		objeto.Parent = padre
	end
	return objeto
end

local function redondear(objeto: Instance, radio: number)
	crear("UICorner", { CornerRadius = UDim.new(0, radio) }, objeto)
end

local function borde(objeto: Instance, color: Color3, grosor: number): UIStroke
	return crear("UIStroke", {
		Color = color,
		Thickness = grosor,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, objeto)
end

local function texto(props: { [string]: any }, padre: Instance?): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = FUENTE,
		TextColor3 = BLANCO,
		TextScaled = true,
		TextStrokeTransparency = 0.2,
		Text = "",
	}
	for clave, valor in props do
		base[clave] = valor
	end
	return crear("TextLabel", base, padre)
end

local function limiteTexto(objeto: Instance, maximo: number)
	crear("UITextSizeConstraint", { MaxTextSize = maximo }, objeto)
end

local function arcoiris(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.COLORES[1]),
		ColorSequenceKeypoint.new(0.2, Config.COLORES[2]),
		ColorSequenceKeypoint.new(0.4, Config.COLORES[3]),
		ColorSequenceKeypoint.new(0.6, Config.COLORES[4]),
		ColorSequenceKeypoint.new(0.8, Config.COLORES[5]),
		ColorSequenceKeypoint.new(1, Config.COLORES[7]),
	})
end

function UI.Crear(jugador: Player)
	local playerGui = jugador:WaitForChild("PlayerGui", 10)
	if not playerGui or UI.Por[jugador] then
		return
	end
	local vieja = playerGui:FindFirstChild("LocuraUI")
	if vieja then
		vieja:Destroy()
	end

	local gui: ScreenGui = crear("ScreenGui", {
		Name = "LocuraUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)

	-- Barra de arriba
	local barra: Frame = crear("Frame", {
		Name = "Barra",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.5, 0, 0, 54),
		BackgroundColor3 = OSCURO,
		BackgroundTransparency = 0.1,
	}, gui)
	crear("UISizeConstraint", { MinSize = Vector2.new(300, 54), MaxSize = Vector2.new(620, 54) }, barra)
	redondear(barra, 14)
	local bordeBarra = borde(barra, BLANCO, 3)
	local degradado = crear("UIGradient", { Color = arcoiris() }, bordeBarra)
	TweenService:Create(degradado, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
		Rotation = 360,
	}):Play()

	local estado = texto({
		Name = "Estado",
		Position = UDim2.new(0, 14, 0, 6),
		Size = UDim2.new(1, -120, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🤪 " .. Config.NOMBRE,
	}, barra)
	limiteTexto(estado, 26)
	local tiempo = texto({
		Name = "Tiempo",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 4),
		Size = UDim2.new(0, 96, 1, -8),
		TextColor3 = DORADO,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, barra)
	limiteTexto(tiempo, 34)

	-- Fila de "pastillas" bajo la barra
	local fila: Frame = crear("Frame", {
		Name = "Fila",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.new(1, -20, 0, 30),
		BackgroundTransparency = 1,
	}, gui)
	crear("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, fila)
	local function pildora(nombre: string, color: Color3, orden: number): TextLabel
		local p = texto({
			Name = nombre,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextScaled = false,
			TextSize = 20,
			BackgroundTransparency = 0.05,
			BackgroundColor3 = color,
			LayoutOrder = orden,
			Visible = false,
		}, fila)
		redondear(p, 15)
		crear("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, p)
		return p
	end

	-- Anuncio gigante
	local anuncio = texto({
		Name = "Anuncio",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.27, 0),
		Size = UDim2.new(0.9, 0, 0.14, 0),
		TextStrokeTransparency = 0,
		TextTransparency = 1,
		ZIndex = 5,
	}, gui)
	limiteTexto(anuncio, 96)
	local escalaAnuncio: UIScale = crear("UIScale", { Scale = 1 }, anuncio)
	local subtitulo = texto({
		Name = "Subtitulo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.35, 0),
		Size = UDim2.new(0.7, 0, 0.09, 0),
		TextWrapped = true,
		TextStrokeTransparency = 0,
		TextTransparency = 1,
		ZIndex = 5,
	}, gui)
	limiteTexto(subtitulo, 34)

	-- Ruleta
	local ruleta: Frame = crear("Frame", {
		Name = "Ruleta",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.55, 0),
		Size = UDim2.new(0.5, 0, 0, 200),
		BackgroundColor3 = OSCURO,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 4,
	}, gui)
	crear("UISizeConstraint", { MinSize = Vector2.new(320, 200), MaxSize = Vector2.new(640, 200) }, ruleta)
	redondear(ruleta, 20)
	borde(ruleta, DORADO, 4)
	local escalaRuleta: UIScale = crear("UIScale", { Scale = 1 }, ruleta)
	local tituloRuleta = texto({
		Name = "Titulo",
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 0, 44),
		TextColor3 = DORADO,
		ZIndex = 4,
	}, ruleta)
	local caja: Frame = crear("Frame", {
		Name = "Caja",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.new(1, -40, 0, 112),
		BackgroundColor3 = BLANCO,
		BackgroundTransparency = 0.88,
		ZIndex = 4,
	}, ruleta)
	redondear(caja, 14)
	local opcionRuleta = texto({
		Name = "Opcion",
		Position = UDim2.new(0, 40, 0, 8),
		Size = UDim2.new(1, -80, 1, -16),
		ZIndex = 5,
	}, caja)
	texto({ Text = "▶", Position = UDim2.new(0, 6, 0.5, -16), Size = UDim2.new(0, 28, 0, 32), TextColor3 = ROJO, ZIndex = 5 }, caja)
	texto({ Text = "◀", Position = UDim2.new(1, -34, 0.5, -16), Size = UDim2.new(0, 28, 0, 32), TextColor3 = ROJO, ZIndex = 5 }, caja)

	-- Mensajes de la derecha
	local feed: Frame = crear("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 110),
		Size = UDim2.new(0, 300, 0, 300),
		BackgroundTransparency = 1,
	}, gui)
	crear("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}, feed)

	-- Resultados
	local resultados: Frame = crear("Frame", {
		Name = "Resultados",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.64, 0),
		Size = UDim2.new(0.46, 0, 0.56, 0),
		BackgroundColor3 = OSCURO,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 6,
	}, gui)
	crear("UISizeConstraint", { MinSize = Vector2.new(300, 200), MaxSize = Vector2.new(580, 430) }, resultados)
	redondear(resultados, 20)
	borde(resultados, Config.COLORES[5], 4)
	local escalaResultados: UIScale = crear("UIScale", { Scale = 1 }, resultados)
	local tituloResultados = texto({
		Name = "Titulo",
		Position = UDim2.new(0, 12, 0.02, 0),
		Size = UDim2.new(1, -24, 0.11, 0),
		TextColor3 = DORADO,
		ZIndex = 6,
	}, resultados)
	local listaResultados: Frame = crear("Frame", {
		Name = "Lista",
		Position = UDim2.new(0, 14, 0.15, 0),
		Size = UDim2.new(1, -28, 0.83, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, resultados)
	crear("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, listaResultados)

	-- Marcador (minijuegos de puntos)
	local marcador: Frame = crear("Frame", {
		Name = "Marcador",
		Position = UDim2.new(0, 10, 0, 110),
		Size = UDim2.new(0, 230, 0, 40 + 8 * 26),
		BackgroundColor3 = OSCURO,
		BackgroundTransparency = 0.2,
		Visible = false,
	}, gui)
	redondear(marcador, 12)
	local tituloMarcador = texto({
		Name = "Titulo",
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -16, 0, 30),
		TextColor3 = DORADO,
	}, marcador)
	local filasMarcador = {}
	for i = 1, 8 do
		table.insert(
			filasMarcador,
			texto({
				Name = "Fila" .. i,
				Position = UDim2.new(0, 10, 0, 36 + (i - 1) * 26),
				Size = UDim2.new(1, -20, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = false,
			}, marcador)
		)
	end

	-- Consejo de abajo
	local consejo = texto({
		Name = "Consejo",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(0.42, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTransparency = 0.15,
		Text = Util.Elegir(CONSEJOS),
	}, gui)
	limiteTexto(consejo, 20)

	UI.Por[jugador] = {
		Gui = gui,
		Estado = estado,
		Tiempo = tiempo,
		Modo = pildora("Modo", MORADO, 1),
		Info = pildora("Info", Color3.fromRGB(30, 144, 255), 2),
		Poder = pildora("Poder", NARANJA, 3),
		Dobles = pildora("Dobles", ROJO, 4),
		Anuncio = anuncio,
		EscalaAnuncio = escalaAnuncio,
		Subtitulo = subtitulo,
		Ruleta = ruleta,
		TituloRuleta = tituloRuleta,
		OpcionRuleta = opcionRuleta,
		EscalaRuleta = escalaRuleta,
		Feed = feed,
		Resultados = resultados,
		TituloResultados = tituloResultados,
		ListaResultados = listaResultados,
		EscalaResultados = escalaResultados,
		Marcador = marcador,
		TituloMarcador = tituloMarcador,
		FilasMarcador = filasMarcador,
		Consejo = consejo,
		TokenAnuncio = 0,
		TokenPoder = 0,
	}
	gui.Parent = playerGui
end

function UI.Quitar(jugador: Player)
	UI.Por[jugador] = nil
end

local function pildoraTexto(etiqueta: TextLabel, valor: string?)
	if valor then
		poner(etiqueta, "Text", valor)
		poner(etiqueta, "Visible", true)
	else
		poner(etiqueta, "Visible", false)
	end
end

function UI.Estado(d: DatosEstado)
	for jugador, ui in UI.Por do
		poner(ui.Estado, "Text", d.Texto)
		local t = d.Tiempo
		if t then
			local reloj = d.Fase == "ronda" or d.Fase == "fin"
			poner(ui.Tiempo, "Text", if reloj then Util.FormatoTiempo(t) else tostring(t))
			poner(ui.Tiempo, "TextColor3", if d.Fase == "ronda" and t <= 10 then ROJO else DORADO)
		else
			poner(ui.Tiempo, "Text", "")
		end
		pildoraTexto(ui.Modo, d.Modo)
		pildoraTexto(ui.Info, d.Info)
		pildoraTexto(ui.Dobles, if d.Dobles then "🔥 PUNTOS x2" else nil)

		local lista = d.Marcador
		if lista then
			poner(ui.Marcador, "Visible", true)
			poner(ui.TituloMarcador, "Text", "📈 MARCADOR " .. (d.Unidad or ""))
			for i, fila in ui.FilasMarcador do
				local dato = lista[i]
				if dato then
					poner(fila, "Visible", true)
					poner(fila, "Text", `{i}. {dato.Nombre} — {dato.Puntos}`)
					poner(fila, "TextColor3", if dato.Id == jugador.UserId then DORADO else BLANCO)
				else
					poner(fila, "Visible", false)
				end
			end
		else
			poner(ui.Marcador, "Visible", false)
		end
	end
end

local function mostrarAnuncio(ui: UIJugador, mensaje: string, o: OpcionesAnuncio)
	ui.TokenAnuncio += 1
	local mio = ui.TokenAnuncio
	ui.Anuncio.Text = mensaje
	ui.Anuncio.TextColor3 = o.Color or BLANCO
	ui.Anuncio.TextTransparency = 0
	ui.Anuncio.TextStrokeTransparency = 0
	ui.Subtitulo.Text = o.Subtitulo or ""
	ui.Subtitulo.TextTransparency = 0
	ui.Subtitulo.TextStrokeTransparency = 0
	ui.EscalaAnuncio.Scale = 0.4
	TweenService:Create(ui.EscalaAnuncio, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(o.Duracion or 2, function()
		if ui.TokenAnuncio ~= mio then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(ui.Anuncio, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(ui.Subtitulo, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- Sonido para todo el mundo.
local function sonidoGlobal(id: string, volumen: number?, velocidad: number?)
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Volume = volumen or 0.5
	sonido.PlaybackSpeed = velocidad or 1
	sonido.Parent = SoundService
	sonido:Play()
	Debris:AddItem(sonido, 4)
end

-- Texto gigante en el centro. Si pasas `solo`, solo lo ve ese jugador.
function UI.Anuncio(mensaje: string, opciones: OpcionesAnuncio?, solo: Player?)
	local o: OpcionesAnuncio = opciones or {}
	if solo then
		local ui = UI.Por[solo]
		if ui then
			mostrarAnuncio(ui, mensaje, o)
		end
		return
	end
	for _, ui in UI.Por do
		mostrarAnuncio(ui, mensaje, o)
	end
	if o.Cuenta then
		sonidoGlobal(SONIDOS.Pip, 0.6, if o.Final then 1.6 else 1)
	end
end

-- Mensaje pequeño a la derecha ("X se cayó").
function UI.Feed(mensaje: string)
	local orden = math.floor(os.clock() * 100)
	for _, ui in UI.Por do
		local etiqueta = texto({
			Size = UDim2.new(1, 0, 0, 30),
			TextScaled = false,
			TextSize = 18,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0.35,
			BackgroundColor3 = Color3.new(0, 0, 0),
			Text = mensaje,
			LayoutOrder = orden,
		}, nil)
		redondear(etiqueta, 8)
		crear("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}, etiqueta)
		etiqueta.Parent = ui.Feed

		local mensajes = {}
		for _, hijo in ui.Feed:GetChildren() do
			if hijo:IsA("TextLabel") then
				table.insert(mensajes, hijo)
			end
		end
		if #mensajes > 6 then
			table.sort(mensajes, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			for i = 1, #mensajes - 6 do
				mensajes[i]:Destroy()
			end
		end
		task.delay(5, function()
			if etiqueta.Parent then
				TweenService:Create(etiqueta, TweenInfo.new(0.5), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
					BackgroundTransparency = 1,
				}):Play()
				Debris:AddItem(etiqueta, 0.6)
			end
		end)
	end
end

-- Ruleta que gira y se para en `elegido`. Espera hasta que termina.
function UI.Ruleta(titulo: string, opciones: { string }, elegido: number, duracion: number)
	local n = #opciones
	if n == 0 then
		return
	end
	for _, ui in UI.Por do
		ui.Ruleta.Visible = true
		ui.TituloRuleta.Text = titulo
		ui.OpcionRuleta.TextColor3 = BLANCO
		ui.EscalaRuleta.Scale = 0.5
		TweenService:Create(ui.EscalaRuleta, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
	local inicio = math.random(1, n)
	local pasos = 3 * n + ((elegido - inicio) % n)
	local anterior = 0
	for k = 1, pasos do
		-- Rápido al principio y cada vez más lento.
		local t = duracion * (k / pasos) ^ 3
		task.wait(math.max(0.04, t - anterior))
		anterior = t
		local textoOpcion = opciones[((inicio - 1 + k) % n) + 1]
		for _, ui in UI.Por do
			ui.OpcionRuleta.Text = textoOpcion
		end
		sonidoGlobal(SONIDOS.Pip, 0.12, 2)
	end
	for _, ui in UI.Por do
		ui.OpcionRuleta.Text = opciones[elegido]
		ui.OpcionRuleta.TextColor3 = DORADO
		ui.EscalaRuleta.Scale = 1.12
		TweenService:Create(ui.EscalaRuleta, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
	sonidoGlobal(SONIDOS.Pip, 0.7, 1.3)
	task.wait(1.2)
	for _, ui in UI.Por do
		ui.Ruleta.Visible = false
	end
end

local tokenResultados = 0
function UI.Resultados(titulo: string, filas: { FilaResultado }, duracion: number)
	tokenResultados += 1
	local mio = tokenResultados
	local medallas = { "🥇", "🥈", "🥉" }
	for jugador, ui in UI.Por do
		for _, hijo in ui.ListaResultados:GetChildren() do
			if hijo:IsA("Frame") then
				hijo:Destroy()
			end
		end
		ui.TituloResultados.Text = "📊 " .. titulo
		for i, fila in filas do
			if i > 8 then
				break
			end
			local soyYo = fila.Id == jugador.UserId
			local marco: Frame = crear("Frame", {
				Name = "Fila",
				Size = UDim2.new(1, 0, 0.125, -5),
				BackgroundColor3 = if soyYo then Color3.fromRGB(90, 70, 20) else Color3.fromRGB(45, 40, 70),
				LayoutOrder = i,
				ZIndex = 6,
			}, nil)
			redondear(marco, 10)
			if soyYo then
				borde(marco, DORADO, 2)
			end
			texto({
				Text = medallas[fila.Puesto] or `{fila.Puesto}º`,
				Position = UDim2.new(0, 6, 0, 4),
				Size = UDim2.new(0, 40, 1, -8),
				ZIndex = 7,
			}, marco)
			texto({
				Text = `{fila.Nombre}  <font color="#BBBBBB">{fila.Detalle}</font>`,
				RichText = true,
				Position = UDim2.new(0, 52, 0, 6),
				Size = UDim2.new(1, -170, 1, -12),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 7,
			}, marco)
			texto({
				Text = `+{fila.Puntos}`,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -64, 0, 4),
				Size = UDim2.new(0, 52, 1, -8),
				TextColor3 = VERDE,
				ZIndex = 7,
			}, marco)
			texto({
				Text = tostring(fila.Total),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 4),
				Size = UDim2.new(0, 52, 1, -8),
				TextColor3 = DORADO,
				ZIndex = 7,
			}, marco)
			marco.Parent = ui.ListaResultados
		end
		ui.Resultados.Visible = true
		ui.EscalaResultados.Scale = 0.4
		TweenService:Create(ui.EscalaResultados, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
	task.delay(duracion, function()
		if tokenResultados == mio then
			for _, ui in UI.Por do
				ui.Resultados.Visible = false
			end
		end
	end)
end

-- Pastilla naranja con el poder que tienes ahora (nil = quitarla).
function UI.Poder(jugador: Player, textoPoder: string?, duracion: number?)
	local ui = UI.Por[jugador]
	if not ui then
		return
	end
	ui.TokenPoder += 1
	local mio = ui.TokenPoder
	pildoraTexto(ui.Poder, textoPoder)
	if textoPoder and duracion then
		task.delay(duracion, function()
			if ui.TokenPoder == mio then
				pildoraTexto(ui.Poder, nil)
			end
		end)
	end
end

function UI.IniciarConsejos()
	task.spawn(function()
		while true do
			task.wait(12)
			local consejo = Util.Elegir(CONSEJOS)
			for _, ui in UI.Por do
				ui.Consejo.Text = consejo
			end
		end
	end)
end

-- =====================================================================
-- 👥 JUGADORES: aparecer, puntos, datos guardados y etiqueta de nombre
-- =====================================================================

type DatosGuardados = { Coronas: number, Victorias: number, Partidas: number, XP: number }
type Estadisticas = { Martillazos: number, Mandados: number, Vuelos: number, Cajas: number }

local Jugadores = {
	EnRonda = {} :: { [Player]: boolean }, -- jugadores dentro de un minijuego ahora mismo
	Datos = {} :: { [Player]: DatosGuardados },
	Stats = {} :: { [Player]: Estadisticas }, -- estadísticas de la partida (para los premios)
	Escudo = {} :: { [Player]: number }, -- hasta cuándo tiene escudo
	UltimoGolpe = {} :: { [Player]: { Por: Player, T: number } }, -- quién le golpeó por última vez
}

local cargando: { [Player]: boolean } = {}
local destinoAlAparecer: { [Player]: CFrame } = {}
local datosCargados: { [Player]: boolean } = {}

local almacen: DataStore? = nil
if Config.GUARDAR_DATOS then
	local ok, resultado = pcall(function()
		return DataStoreService:GetDataStore("LocuraTotal_v2")
	end)
	if ok then
		almacen = resultado
	end
end

local TITULOS = {
	{ Nivel = 1, Nombre = "🐣 Novato" },
	{ Nivel = 3, Nombre = "🙂 Loquillo" },
	{ Nivel = 5, Nombre = "🤪 Loco" },
	{ Nivel = 8, Nombre = "🌀 Muy Loco" },
	{ Nivel = 12, Nombre = "🔥 Locura Total" },
	{ Nivel = 17, Nombre = "👑 Leyenda del Caos" },
}

function Jugadores.Nivel(xp: number): number
	return math.floor(math.sqrt(xp / 15)) + 1
end

function Jugadores.Titulo(nivel: number): string
	local titulo = TITULOS[1].Nombre
	for _, t in TITULOS do
		if nivel >= t.Nivel then
			titulo = t.Nombre
		end
	end
	return titulo
end

function Jugadores.Humanoide(jugador: Player): Humanoid?
	local personaje = jugador.Character
	if not personaje then
		return nil
	end
	return personaje:FindFirstChildOfClass("Humanoid")
end

function Jugadores.Raiz(jugador: Player): BasePart?
	local personaje = jugador.Character
	if not personaje then
		return nil
	end
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	if raiz and raiz:IsA("BasePart") then
		return raiz
	end
	return nil
end

function Jugadores.EstaVivo(jugador: Player): boolean
	local humanoide = Jugadores.Humanoide(jugador)
	return humanoide ~= nil and humanoide.Health > 0 and Jugadores.Raiz(jugador) ~= nil
end

-- Jugadores con el personaje vivo y listo para jugar.
function Jugadores.Listos(): { Player }
	local lista = {}
	for _, jugador in Players:GetPlayers() do
		if Jugadores.EstaVivo(jugador) and not cargando[jugador] then
			table.insert(lista, jugador)
		end
	end
	return lista
end

local function valor(jugador: Player, nombre: string): IntValue?
	local stats = jugador:FindFirstChild("leaderstats")
	local v = if stats then stats:FindFirstChild(nombre) else nil
	if v and v:IsA("IntValue") then
		return v
	end
	return nil
end

function Jugadores.ActualizarEtiqueta(jugador: Player)
	local datos = Jugadores.Datos[jugador]
	local personaje = jugador.Character
	local cabeza = if personaje then personaje:FindFirstChild("Head") else nil
	local etiqueta = if cabeza then cabeza:FindFirstChild("Etiqueta") else nil
	if not datos or not etiqueta then
		return
	end
	local nivel = Jugadores.Nivel(datos.XP)
	local sub = etiqueta:FindFirstChild("Sub")
	if sub and sub:IsA("TextLabel") then
		local coronas = if datos.Coronas > 0 then ` · 👑{datos.Coronas}` else ""
		sub.Text = `Nv {nivel} {Jugadores.Titulo(nivel)}{coronas}`
	end
	local nivelValor = valor(jugador, "Nivel")
	if nivelValor then
		nivelValor.Value = nivel
	end
	local coronasValor = valor(jugador, "Coronas")
	if coronasValor then
		coronasValor.Value = datos.Coronas
	end
end

local function crearEtiqueta(jugador: Player, personaje: Model)
	local cabeza = personaje:WaitForChild("Head", 5)
	if not cabeza or not cabeza:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Etiqueta"
	gui.Size = UDim2.new(0, 220, 0, 48)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = cabeza

	local nombre = Instance.new("TextLabel")
	nombre.Name = "Nombre"
	nombre.Size = UDim2.fromScale(1, 0.58)
	nombre.BackgroundTransparency = 1
	nombre.FontFace = FUENTE
	nombre.TextScaled = true
	nombre.TextColor3 = BLANCO
	nombre.TextStrokeTransparency = 0
	nombre.Text = jugador.DisplayName
	nombre.Parent = gui

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.Position = UDim2.fromScale(0, 0.58)
	sub.Size = UDim2.fromScale(1, 0.42)
	sub.BackgroundTransparency = 1
	sub.FontFace = FUENTE
	sub.TextScaled = true
	sub.TextColor3 = DORADO
	sub.TextStrokeTransparency = 0
	sub.Parent = gui

	gui.Parent = cabeza
	Jugadores.ActualizarEtiqueta(jugador)
end

-- Suma a los datos guardados (Coronas, Victorias, Partidas o XP).
function Jugadores.Sumar(jugador: Player, campo: string, cantidad: number)
	local datos = Jugadores.Datos[jugador]
	if datos then
		(datos :: any)[campo] += cantidad
		Jugadores.ActualizarEtiqueta(jugador)
	end
end

-- Suma a las estadísticas de la partida (para los premios del final).
function Jugadores.Stat(jugador: Player, campo: string, cantidad: number?)
	local stats = Jugadores.Stats[jugador]
	if stats then
		(stats :: any)[campo] += cantidad or 1
	end
end

function Jugadores.ReiniciarStats()
	for _, jugador in Players:GetPlayers() do
		Jugadores.Stats[jugador] = { Martillazos = 0, Mandados = 0, Vuelos = 0, Cajas = 0 }
	end
end

function Jugadores.SumarPuntos(jugador: Player, cantidad: number)
	local puntos = valor(jugador, "Puntos")
	if puntos then
		puntos.Value += cantidad
	end
end

function Jugadores.Puntos(jugador: Player): number
	local puntos = valor(jugador, "Puntos")
	return if puntos then puntos.Value else 0
end

function Jugadores.ReiniciarPuntos()
	for _, jugador in Players:GetPlayers() do
		local puntos = valor(jugador, "Puntos")
		if puntos then
			puntos.Value = 0
		end
	end
end

function Jugadores.Guardar(jugador: Player)
	local tienda = almacen
	local datos = Jugadores.Datos[jugador]
	if not tienda or not datos or not datosCargados[jugador] then
		return
	end
	local copia = table.clone(datos)
	local ok, err = pcall(function()
		tienda:SetAsync("jugador_" .. jugador.UserId, copia)
	end)
	if not ok then
		warn("[LocuraTotal] No se pudieron guardar los datos:", err)
	end
end

local function cargarDatos(jugador: Player)
	local tienda = almacen
	if not tienda then
		return
	end
	local ok, resultado = pcall(function()
		return tienda:GetAsync("jugador_" .. jugador.UserId)
	end)
	if not ok or jugador.Parent ~= Players then
		return
	end
	datosCargados[jugador] = true
	local datos = Jugadores.Datos[jugador]
	if datos and type(resultado) == "table" then
		for _, campo in { "Coronas", "Victorias", "Partidas", "XP" } do
			local guardado = resultado[campo]
			if type(guardado) == "number" then
				(datos :: any)[campo] += guardado
			end
		end
		Jugadores.ActualizarEtiqueta(jugador)
	end
end

-- Vuelve a crear el personaje. Si das `destino`, aparece allí (si no, en el lobby).
function Jugadores.Reaparecer(jugador: Player, destino: CFrame?)
	if jugador.Parent ~= Players then
		return
	end
	if destino then
		destinoAlAparecer[jugador] = destino
	else
		destinoAlAparecer[jugador] = nil
	end
	if cargando[jugador] then
		return
	end
	cargando[jugador] = true
	task.spawn(function()
		-- LoadCharacterAsync es la versión nueva; si no existe, usamos la clásica.
		local ok, err = pcall(function()
			(jugador :: any):LoadCharacterAsync()
		end)
		if not ok and jugador.Parent == Players and not jugador.Character then
			ok, err = pcall(function()
				(jugador :: any):LoadCharacter()
			end)
		end
		if not ok then
			warn("[LocuraTotal] Error al reaparecer:", err)
		end
		cargando[jugador] = nil
	end)
end

local function alAparecer(jugador: Player, personaje: Model)
	local encontrado = personaje:WaitForChild("Humanoid", 10)
	if not encontrado or not encontrado:IsA("Humanoid") then
		return
	end
	local humanoide = encontrado :: Humanoid
	humanoide.UseJumpPower = true
	humanoide.JumpPower = Config.SALTO
	humanoide.WalkSpeed = Config.VELOCIDAD
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local destino = destinoAlAparecer[jugador]
	if destino then
		destinoAlAparecer[jugador] = nil
		local raiz = personaje:WaitForChild("HumanoidRootPart", 5)
		if raiz and personaje.Parent then
			personaje:PivotTo(destino + Vector3.new(0, 3.7, 0))
		end
	end

	humanoide.Died:Connect(function()
		task.wait(Config.TIEMPO_REAPARECER)
		if jugador.Parent == Players and jugador.Character == personaje then
			Jugadores.Reaparecer(jugador)
		end
	end)

	task.spawn(crearEtiqueta, jugador, personaje)
end

local function alEntrar(jugador: Player)
	if #Players:GetPlayers() > Config.MAX_JUGADORES then
		jugador:Kick(`¡Servidor lleno! Este juego es para {Config.MAX_JUGADORES} locos como máximo. Prueba otro servidor.`)
		return
	end

	Jugadores.Datos[jugador] = { Coronas = 0, Victorias = 0, Partidas = 0, XP = 0 }
	Jugadores.Stats[jugador] = { Martillazos = 0, Mandados = 0, Vuelos = 0, Cajas = 0 }

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, nombre in { "Puntos", "Coronas", "Nivel" } do
		local v = Instance.new("IntValue")
		v.Name = nombre
		v.Value = if nombre == "Nivel" then 1 else 0
		v.Parent = stats
	end
	stats.Parent = jugador

	task.spawn(UI.Crear, jugador)
	jugador.CharacterAdded:Connect(function(personaje)
		alAparecer(jugador, personaje)
	end)
	if jugador.Character then
		task.spawn(alAparecer, jugador, jugador.Character)
	else
		Jugadores.Reaparecer(jugador)
	end
	task.spawn(cargarDatos, jugador)
end

function Jugadores.Iniciar()
	-- Nosotros decidimos cuándo aparece cada personaje.
	Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end

	Players.PlayerRemoving:Connect(function(jugador)
		Jugadores.Guardar(jugador)
		Jugadores.EnRonda[jugador] = nil
		Jugadores.Datos[jugador] = nil
		Jugadores.Stats[jugador] = nil
		Jugadores.Escudo[jugador] = nil
		Jugadores.UltimoGolpe[jugador] = nil
		cargando[jugador] = nil
		destinoAlAparecer[jugador] = nil
		datosCargados[jugador] = nil
		UI.Quitar(jugador)
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, jugador in Players:GetPlayers() do
			Jugadores.Guardar(jugador)
		end
	end)

	-- Si alguien se cae fuera de una ronda, vuelve al lobby.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, jugador in Players:GetPlayers() do
				if not Jugadores.EnRonda[jugador] then
					local raiz = Jugadores.Raiz(jugador)
					if raiz and raiz.Position.Y < Config.VACIO_LOBBY then
						Jugadores.Reaparecer(jugador)
					end
				end
			end
		end
	end)
end

-- =====================================================================
-- 💥 EFECTOS: explosiones, empujones, confeti, fuegos artificiales
-- =====================================================================

local Efectos = {}
local tokenVuelo: { [Player]: number } = {}

-- Explosión visual (no hace daño).
function Efectos.Explosion(posicion: Vector3, radio: number)
	local explosion = Instance.new("Explosion")
	explosion.Position = posicion
	explosion.BlastRadius = radio
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace
	Debris:AddItem(explosion, 3)
end

function Efectos.Sonido(padre: Instance, id: string, volumen: number?, velocidad: number?)
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Volume = volumen or 0.6
	sonido.PlaybackSpeed = velocidad or 1
	sonido.Parent = padre
	sonido:Play()
	Debris:AddItem(sonido, 4)
end

-- Ráfaga de confeti. (Ráfaga corta en vez de Emit(): un emisor recién creado
-- en el servidor a veces aún no ha llegado a los jugadores y no se vería.)
function Efectos.Confeti(posicion: Vector3, cantidad: number?)
	local parte = Instance.new("Part")
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Transparency = 1
	parte.Size = Vector3.new(1, 1, 1)
	parte.CFrame = CFrame.new(posicion)

	local emisor = Instance.new("ParticleEmitter")
	emisor.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emisor.Color = arcoiris()
	emisor.Size = NumberSequence.new(0.6, 0.2)
	emisor.Lifetime = NumberRange.new(1.5, 3)
	emisor.Speed = NumberRange.new(25, 45)
	emisor.SpreadAngle = Vector2.new(60, 60)
	emisor.Acceleration = Vector3.new(0, -30, 0)
	emisor.RotSpeed = NumberRange.new(-200, 200)
	emisor.LightEmission = 0.6
	emisor.Rate = (cantidad or 80) / 0.35
	emisor.Parent = parte

	parte.Parent = workspace
	task.delay(0.35, function()
		emisor.Enabled = false
	end)
	Debris:AddItem(parte, 5)
end

-- Fuego artificial: sube una bola brillante y explota en confeti.
function Efectos.FuegoArtificial(desde: Vector3)
	local color = Util.Elegir(Config.COLORES)
	local cohete = C.Bola(desde, 1.5, {
		Name = "Cohete",
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.6, 0)
	a0.Parent = cohete
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.6, 0)
	a1.Parent = cohete
	local estela = Instance.new("Trail")
	estela.Attachment0 = a0
	estela.Attachment1 = a1
	estela.Color = ColorSequence.new(color)
	estela.Lifetime = 0.5
	estela.LightEmission = 1
	estela.Parent = cohete
	cohete.Parent = workspace

	local destino = desde + Vector3.new(math.random(-10, 10), math.random(35, 60), math.random(-10, 10))
	local tween = TweenService:Create(
		cohete,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(destino) }
	)
	tween:Play()
	tween.Completed:Once(function()
		Efectos.Confeti(destino, 120)
		cohete:Destroy()
	end)
end

-- Da un impulso al personaje (una fuerza muy corta dentro del personaje: así
-- funciona aunque el personaje lo controle el ordenador del jugador).
function Efectos.Impulso(jugador: Player, velocidad: Vector3): boolean
	local raiz = Jugadores.Raiz(jugador)
	if not raiz then
		return false
	end
	local adjunto = raiz:FindFirstChild("AdjuntoLoco")
	if not adjunto or not adjunto:IsA("Attachment") then
		local nuevo = Instance.new("Attachment")
		nuevo.Name = "AdjuntoLoco"
		nuevo.Parent = raiz
		adjunto = nuevo
	end
	local viejo = raiz:FindFirstChild("Empujon")
	if viejo then
		viejo:Destroy()
	end
	local fuerza = Instance.new("LinearVelocity")
	fuerza.Name = "Empujon"
	fuerza.Attachment0 = adjunto :: Attachment
	fuerza.RelativeTo = Enum.ActuatorRelativeTo.World
	fuerza.MaxForce = math.huge
	fuerza.VectorVelocity = velocidad
	fuerza.Parent = raiz
	Debris:AddItem(fuerza, 0.15)
	return true
end

-- Manda a volar a un jugador. `vuelo` = segundos como muñeco de trapo.
-- `atacante` = quién lo empujó (para saber quién eliminó a quién).
function Efectos.Empujar(jugador: Player, velocidad: Vector3, vuelo: number?, atacante: Player?)
	if (Jugadores.Escudo[jugador] or 0) > os.clock() then
		local raiz = Jugadores.Raiz(jugador)
		if raiz then
			Efectos.Sonido(raiz, SONIDOS.Golpe, 0.5, 2) -- ¡el escudo lo para!
		end
		return
	end
	if not Efectos.Impulso(jugador, velocidad) then
		return
	end
	local humanoide = Jugadores.Humanoide(jugador)
	local segundos = vuelo or 0
	if humanoide and segundos > 0 then
		local token = (tokenVuelo[jugador] or 0) + 1
		tokenVuelo[jugador] = token
		humanoide.PlatformStand = true
		task.delay(segundos, function()
			if tokenVuelo[jugador] == token and humanoide.Parent then
				humanoide.PlatformStand = false
			end
		end)
		Jugadores.Stat(jugador, "Vuelos")
	end
	if atacante and atacante ~= jugador then
		Jugadores.UltimoGolpe[jugador] = { Por = atacante, T = os.clock() }
	end
end

-- =====================================================================
-- 🔨 EL MARTILLO LOCO
-- =====================================================================

local Herramientas = {}

local ALCANCE_MARTILLO = 9
local ESPERA_MARTILLO = 0.7

local function crearMartillo(color: Color3): Tool
	local herramienta = Instance.new("Tool")
	herramienta.Name = "Martillo Loco"
	herramienta.ToolTip = "¡Haz clic para mandar a volar a los demás!"
	herramienta.CanBeDropped = false
	herramienta.RequiresHandle = true
	-- Misma forma de agarrar que la espada clásica de Roblox.
	herramienta.GripPos = Vector3.new(0, 0, -1.5)
	herramienta.GripForward = Vector3.new(-1, 0, 0)
	herramienta.GripRight = Vector3.new(0, 1, 0)
	herramienta.GripUp = Vector3.new(0, 0, 1)

	local mango = Instance.new("Part")
	mango.Name = "Handle"
	mango.Size = Vector3.new(0.6, 0.6, 5)
	mango.Color = Color3.fromRGB(255, 221, 89)
	mango.Material = Enum.Material.SmoothPlastic
	mango.CanCollide = false
	mango.Massless = true
	mango.Parent = herramienta

	local cabeza = Instance.new("Part")
	cabeza.Name = "Cabeza"
	cabeza.Shape = Enum.PartType.Cylinder
	cabeza.Size = Vector3.new(3.2, 2.4, 2.4)
	cabeza.Color = color
	cabeza.Material = Enum.Material.SmoothPlastic
	cabeza.CanCollide = false
	cabeza.Massless = true
	cabeza.CFrame = mango.CFrame * CFrame.new(0, 0, 2.6)
	cabeza.Parent = herramienta
	C.Soldar(mango, cabeza)
	return herramienta
end

-- Da un Martillo Loco y se lo pone en la mano.
-- `alGolpear(atacante, victima)` se llama cada vez que golpea a alguien.
function Herramientas.DarMartillo(
	jugador: Player,
	color: Color3,
	fuerza: number?,
	alGolpear: ((Player, Player) -> ())?
)
	local mochila = jugador:FindFirstChildOfClass("Backpack")
	local humanoide = Jugadores.Humanoide(jugador)
	if not mochila or not humanoide then
		return
	end
	local herramienta = crearMartillo(color)
	local multiplicador = fuerza or 1
	local ultimo = 0

	herramienta.Activated:Connect(function()
		local ahora = os.clock()
		if ahora - ultimo < ESPERA_MARTILLO then
			return
		end
		ultimo = ahora
		local raiz = Jugadores.Raiz(jugador)
		if not raiz then
			return
		end

		-- Animación de golpe (el script Animate de Roblox la reconoce).
		local animacion = Instance.new("StringValue")
		animacion.Name = "toolanim"
		animacion.Value = "Slash"
		animacion.Parent = herramienta
		Debris:AddItem(animacion, 1)
		local mango = herramienta:FindFirstChild("Handle")
		if mango then
			Efectos.Sonido(mango, SONIDOS.Swing, 0.7, 0.8 + math.random() * 0.4)
		end

		local adelante = raiz.CFrame.LookVector
		for _, otro in Players:GetPlayers() do
			local raizOtro = Jugadores.Raiz(otro)
			if otro ~= jugador and raizOtro and Jugadores.EstaVivo(otro) then
				local distancia = (raizOtro.Position - raiz.Position).Magnitude
				if distancia <= ALCANCE_MARTILLO then
					local direccion = Util.Direccion(raiz.Position, raizOtro.Position, adelante)
					-- Solo golpea lo que tienes delante (o pegado a ti).
					if direccion:Dot(adelante) > 0.2 or distancia < 3.5 then
						Efectos.Empujar(
							otro,
							direccion * 85 * multiplicador + Vector3.new(0, 45 * multiplicador, 0),
							1,
							jugador
						)
						Efectos.Sonido(raizOtro, SONIDOS.Golpe, 0.8, 0.6)
						Jugadores.Stat(jugador, "Martillazos")
						if alGolpear then
							task.spawn(alGolpear, jugador, otro)
						end
					end
				end
			end
		end
	end)

	herramienta.Parent = mochila
	humanoide:EquipTool(herramienta)
end

-- =====================================================================
-- 🌀 MODOS LOCOS
-- =====================================================================

export type Modificador = {
	Id: string,
	Nombre: string,
	Emoji: string,
	Descripcion: string,
	Peso: number, -- cuanto más alto, más veces sale
	Gravedad: number?,
	MultVelocidad: number?,
	MultSalto: number?,
	Escala: number?,
	Hielo: boolean?,
	Disco: boolean?,
	Niebla: boolean?,
	Fantasma: boolean?,
	GravedadLoca: boolean?,
}

local Modificadores = {}

Modificadores.Lista = {
	{ Id = "Normal", Nombre = "Sin locura", Emoji = "😐", Descripcion = "Ronda normal... por ahora.", Peso = 2 },
	{ Id = "Lunar", Nombre = "Gravedad Lunar", Emoji = "🌙", Descripcion = "¡Saltos de astronauta!", Peso = 3, Gravedad = 55 },
	{ Id = "Turbo", Nombre = "Modo Turbo", Emoji = "⚡", Descripcion = "¡Todos corren el doble!", Peso = 3, MultVelocidad = 1.9 },
	{ Id = "Gigantes", Nombre = "Ataque de Gigantes", Emoji = "🦖", Descripcion = "¡Sois ENORMES!", Peso = 2, Escala = 1.8 },
	{ Id = "Mini", Nombre = "Mini Locos", Emoji = "🐜", Descripcion = "¡Sois diminutos como hormigas!", Peso = 2, Escala = 0.5 },
	{ Id = "Saltarin", Nombre = "Súper Salto", Emoji = "🦘", Descripcion = "¡Piernas de canguro!", Peso = 2, MultSalto = 1.8 },
	{ Id = "Disco", Nombre = "Noche Disco", Emoji = "🪩", Descripcion = "¡Se apagan las luces y empieza la fiesta!", Peso = 2, Disco = true },
	{ Id = "Niebla", Nombre = "Niebla Total", Emoji = "🌫️", Descripcion = "¡No se ve NADA!", Peso = 2, Niebla = true },
	{ Id = "Fantasma", Nombre = "Modo Fantasma", Emoji = "👻", Descripcion = "¡Todos sois casi invisibles!", Peso = 2, Fantasma = true },
	{ Id = "Hielo", Nombre = "Todo es Hielo", Emoji = "🧊", Descripcion = "¡Cuidado, que resbala!", Peso = 2, Hielo = true },
	{ Id = "GravedadLoca", Nombre = "Gravedad Loca", Emoji = "🔄", Descripcion = "¡La gravedad cambia cada pocos segundos!", Peso = 2, GravedadLoca = true },
	{ Id = "Caos", Nombre = "CAOS TOTAL", Emoji = "🌀", Descripcion = "¡Varios modos locos a la vez!", Peso = 2 },
} :: { Modificador }

local function elegirPonderado(lista: { Modificador }): Modificador
	local total = 0
	for _, m in lista do
		total += m.Peso
	end
	local tirada = math.random() * total
	for _, m in lista do
		tirada -= m.Peso
		if tirada <= 0 then
			return m
		end
	end
	return lista[#lista]
end

-- Junta varios modos en uno (para CAOS TOTAL).
local function mezclar(partes: { Modificador }): Modificador
	local r: Modificador = { Id = "Caos", Nombre = "CAOS TOTAL", Emoji = "🌀", Descripcion = "", Peso = 0 }
	local nombres = {}
	for _, m in partes do
		table.insert(nombres, m.Emoji .. " " .. m.Nombre)
		if m.Gravedad then
			r.Gravedad = math.min(r.Gravedad or math.huge, m.Gravedad)
		end
		if m.MultVelocidad then
			r.MultVelocidad = (r.MultVelocidad or 1) * m.MultVelocidad
		end
		if m.MultSalto then
			r.MultSalto = (r.MultSalto or 1) * m.MultSalto
		end
		r.Escala = r.Escala or m.Escala
		r.Hielo = r.Hielo or m.Hielo
		r.Disco = r.Disco or m.Disco
		r.Niebla = r.Niebla or m.Niebla
		r.Fantasma = r.Fantasma or m.Fantasma
		r.GravedadLoca = r.GravedadLoca or m.GravedadLoca
	end
	r.Descripcion = table.concat(nombres, " + ")
	return r
end

local ultimoModo = ""

-- Elige un modo loco (sin repetir el anterior). La 1ª ronda es más tranquila.
function Modificadores.Elegir(numeroRonda: number): Modificador
	if numeroRonda == 1 and math.random() < 0.5 then
		ultimoModo = "Normal"
		return Modificadores.Lista[1]
	end
	local candidatos = {}
	for _, m in Modificadores.Lista do
		if m.Id ~= ultimoModo then
			table.insert(candidatos, m)
		end
	end
	local elegido = elegirPonderado(candidatos)
	ultimoModo = elegido.Id
	if elegido.Id ~= "Caos" then
		return elegido
	end

	-- CAOS: junta 2 o 3 modos distintos (sin Normal ni Caos; nunca gigantes + mini).
	local disponibles = {}
	for _, m in Modificadores.Lista do
		if m.Id ~= "Normal" and m.Id ~= "Caos" then
			table.insert(disponibles, m)
		end
	end
	local partes = {}
	for _ = 1, math.random(2, 3) do
		if #disponibles == 0 then
			break
		end
		local m = table.remove(disponibles, math.random(1, #disponibles)) :: Modificador
		if m.Escala then
			for i = #disponibles, 1, -1 do
				if disponibles[i].Escala then
					table.remove(disponibles, i)
				end
			end
		end
		table.insert(partes, m)
	end
	return mezclar(partes)
end

function Modificadores.Indice(mod: Modificador): number
	for i, m in Modificadores.Lista do
		if m.Id == mod.Id then
			return i
		end
	end
	return 1
end

local tokenMundo = 0
local guardadoLuces: { [string]: any } = {}

local function atmosfera(): Atmosphere?
	return Lighting:FindFirstChildOfClass("Atmosphere")
end

-- Lo que afecta a todo el mundo: gravedad, luces, niebla...
function Modificadores.AplicarMundo(mod: Modificador)
	tokenMundo += 1
	local mio = tokenMundo
	workspace.Gravity = mod.Gravedad or Config.GRAVEDAD
	guardadoLuces = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		OutdoorAmbient = Lighting.OutdoorAmbient,
	}
	local atm = atmosfera()
	if atm then
		guardadoLuces.Densidad = atm.Density
		guardadoLuces.Bruma = atm.Haze
		guardadoLuces.ColorAtm = atm.Color
	end

	if mod.Disco then
		Lighting.ClockTime = 0
		Lighting.Brightness = 1.5
		Lighting.OutdoorAmbient = Color3.fromRGB(130, 100, 170)
		local efecto = Instance.new("ColorCorrectionEffect")
		efecto.Name = "DiscoLoco"
		efecto.Saturation = 0.6
		efecto.Contrast = 0.15
		efecto.Parent = Lighting
		task.spawn(function()
			local tono = 0
			while tokenMundo == mio and efecto.Parent do
				tono = (tono + 0.13) % 1
				TweenService:Create(efecto, TweenInfo.new(0.3), { TintColor = Color3.fromHSV(tono, 0.45, 1) }):Play()
				task.wait(0.3)
			end
		end)
	end

	if mod.Niebla and atm then
		atm.Density = 0.82
		atm.Haze = 3
		atm.Color = Color3.fromRGB(200, 200, 210)
	end

	if mod.GravedadLoca then
		task.spawn(function()
			local opciones = {
				{ Valor = 35, Texto = "🪶 casi flotas" },
				{ Valor = 80, Texto = "🌙 lunar" },
				{ Valor = 196.2, Texto = "🌍 normal" },
				{ Valor = 330, Texto = "🧱 superpesada" },
			}
			local anterior = 0
			while tokenMundo == mio do
				task.wait(5)
				if tokenMundo ~= mio then
					break
				end
				local indice = math.random(1, #opciones - 1)
				if indice >= anterior then
					indice += 1 -- nunca repite la misma
				end
				anterior = indice
				local o = opciones[indice]
				workspace.Gravity = o.Valor
				UI.Feed("🔄 Gravedad: " .. o.Texto)
			end
		end)
	end
end

function Modificadores.QuitarMundo()
	tokenMundo += 1
	workspace.Gravity = Config.GRAVEDAD
	if guardadoLuces.ClockTime then
		Lighting.ClockTime = guardadoLuces.ClockTime
		Lighting.Brightness = guardadoLuces.Brightness
		Lighting.OutdoorAmbient = guardadoLuces.OutdoorAmbient
	end
	local atm = atmosfera()
	if atm and guardadoLuces.Densidad then
		atm.Density = guardadoLuces.Densidad
		atm.Haze = guardadoLuces.Bruma
		atm.Color = guardadoLuces.ColorAtm
	end
	local disco = Lighting:FindFirstChild("DiscoLoco")
	if disco then
		disco:Destroy()
	end
	guardadoLuces = {}
end

-- Lo que afecta a cada personaje (modo fantasma).
function Modificadores.AplicarPersonaje(mod: Modificador, personaje: Model)
	if not mod.Fantasma then
		return
	end
	for _, d in personaje:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Transparency = math.max(d.Transparency, 0.85)
		elseif d:IsA("Decal") then
			d.Transparency = 0.85
		end
	end
end

-- Convierte todo el suelo de la arena en hielo.
function Modificadores.AplicarHielo(carpeta: Instance)
	local hielo = PhysicalProperties.new(0.9, 0.02, 0.1, 100, 1)
	for _, d in carpeta:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and d.CanCollide and d.Transparency < 1 then
			d.Material = Enum.Material.Ice
			d.CustomPhysicalProperties = hielo
		end
	end
end

-- =====================================================================
-- 🎮 RONDA: quién sigue vivo, puntos, eliminaciones y limpieza
-- =====================================================================

export type TipoJuego = "supervivencia" | "puntos" | "carrera"
type EstadoParticipante = "vivo" | "eliminado" | "meta" | "fuera"

export type Minijuego = {
	Id: string,
	Nombre: string,
	Emoji: string,
	Descripcion: string,
	Tipo: TipoJuego,
	Duracion: number,
	AlturaMuerte: number, -- relativa al centro de la arena
	Herramienta: boolean?, -- ¿dar Martillo Loco?
	FuerzaMartillo: number?,
	MultVelocidad: number?,
	MultSalto: number?,
	UnidadPuntaje: string?,
	Cajas: number?, -- radio donde salen cajas sorpresa (nil = sin cajas)
	Construir: (ronda: Ronda) -> { CFrame },
	Iniciar: (ronda: Ronda) -> (),
	AlCaer: ((ronda: Ronda, jugador: Player) -> ())?,
	AlEliminar: ((ronda: Ronda, jugador: Player) -> ())?,
	AlGolpear: ((ronda: Ronda, atacante: Player, victima: Player) -> ())?,
}

export type Fila = { Jugador: Player, Puesto: number, Detalle: string }

local Ronda = {}
Ronda.__index = Ronda

type DatosRonda = {
	Minijuego: Minijuego,
	Modificador: Modificador,
	Participantes: { Player },
	Estados: { [Player]: EstadoParticipante },
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
	Dobles: boolean,
	Iniciada: boolean,
	Activa: boolean,
	Terminada: boolean,
	TiempoRestante: number,
	Conexiones: { RBXScriptConnection },
}

export type Ronda = typeof(setmetatable({} :: DatosRonda, Ronda))

local FRASES_CAIDA = {
	"se cayó al vacío 🕳️",
	"aprendió a volar... mal 🪽",
	"se fue de vacaciones al abismo 🏖️",
	"dijo adiós muy fuerte 👋",
	"cayó como una patata 🥔",
	"se tiró de cabeza 🤸",
	"no vio el borde 🙈",
	"probó la caída libre 🪂",
}

function Ronda.new(minijuego: Minijuego, modificador: Modificador, participantes: { Player }, dobles: boolean): Ronda
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Arena"
	local datos: DatosRonda = {
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
		Centro = Config.ARENA,
		Spawns = {},
		Escala = modificador.Escala or 1,
		Velocidad = Config.VELOCIDAD * (minijuego.MultVelocidad or 1) * (modificador.MultVelocidad or 1),
		Salto = Config.SALTO * (minijuego.MultSalto or 1) * (modificador.MultSalto or 1),
		Dobles = dobles,
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

-- ----- Utilidades para los minijuegos -----

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

-- Espera y dice si la ronda sigue activa (para salir de bucles largos).
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

-- Si `parte` es de un jugador vivo de la ronda, lo devuelve.
function Ronda.JugadorDeParte(self: Ronda, parte: Instance): Player?
	local modelo = parte:FindFirstAncestorOfClass("Model")
	while modelo do
		local jugador = Players:GetPlayerFromCharacter(modelo)
		if jugador then
			return if self.Estados[jugador] == "vivo" then jugador else nil
		end
		modelo = modelo:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function Ronda.Teletransportar(self: Ronda, jugador: Player, destino: CFrame)
	local personaje = jugador.Character
	if personaje then
		personaje:PivotTo(destino + Vector3.new(0, 3.2 * self.Escala + 0.5, 0))
	end
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

function Ronda.Feed(_self: Ronda, mensaje: string)
	UI.Feed(mensaje)
end

function Ronda.Anunciar(_self: Ronda, mensaje: string, color: Color3?, duracion: number?)
	UI.Anuncio(mensaje, { Color = color, Duracion = duracion })
end

function Ronda.ColorDe(self: Ronda, jugador: Player): Color3
	return self.Colores[jugador] or BLANCO
end

-- ----- Eliminaciones, llegadas y caídas -----

function Ronda.ComprobarFin(self: Ronda)
	if self.Terminada or not self.Iniciada then
		return
	end
	local vivos = #self:Vivos()
	if self.Minijuego.Tipo == "supervivencia" then
		if vivos <= (if #self.Participantes >= 2 then 1 else 0) then
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

	-- ¿Alguien le empujó hace poco? ¡Se lleva el mérito!
	local golpe = Jugadores.UltimoGolpe[jugador]
	if golpe and os.clock() - golpe.T < 5 and golpe.Por.Parent == Players then
		self:Feed(`💥 {golpe.Por.DisplayName} eliminó a {jugador.DisplayName}`)
		Jugadores.Stat(golpe.Por, "Mandados")
	else
		self:Feed(`💀 {jugador.DisplayName} {motivo or "quedó eliminado"}`)
	end
	Jugadores.UltimoGolpe[jugador] = nil
	UI.Anuncio("¡ELIMINADO!", { Color = ROJO, Duracion = 2, Subtitulo = "Mira el resto de la ronda desde la grada 👀" }, jugador)

	local alEliminar = self.Minijuego.AlEliminar
	if alEliminar then
		task.spawn(alEliminar, self, jugador)
	end

	task.delay(1.5, function()
		if jugador.Parent == Players and not Jugadores.EnRonda[jugador] then
			Jugadores.Reaparecer(jugador, if #Mundo.Grada > 0 then Util.Elegir(Mundo.Grada) else nil)
		end
	end)
	self:ComprobarFin()
end

-- Un jugador se ha ido del juego: deja de contar.
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

-- Para carreras: ha cruzado la meta.
function Ronda.Llegar(self: Ronda, jugador: Player)
	if self.Estados[jugador] ~= "vivo" then
		return
	end
	self.Estados[jugador] = "meta"
	table.insert(self.OrdenLlegada, jugador)
	local puesto = #self.OrdenLlegada
	self:Feed(`🏁 {jugador.DisplayName} llegó a la meta en el puesto {puesto}`)
	UI.Anuncio(`¡META! Puesto {puesto}`, { Color = VERDE, Duracion = 2.5 }, jugador)
	local raiz = Jugadores.Raiz(jugador)
	if raiz then
		Efectos.Confeti(raiz.Position + Vector3.new(0, 4, 0), 100)
	end
	self:ComprobarFin()
end

-- Si te caes en un juego que no es de supervivencia, vuelves a empezar.
function Ronda.Caer(self: Ronda, jugador: Player)
	local ahora = os.clock()
	if ahora - (self.UltimaCaida[jugador] or 0) < 1 then
		return
	end
	self.UltimaCaida[jugador] = ahora
	local humanoide = Jugadores.Humanoide(jugador)
	if humanoide then
		humanoide.PlatformStand = false
	end
	local alCaer = self.Minijuego.AlCaer
	if alCaer then
		alCaer(self, jugador)
	elseif #self.Spawns > 0 then
		self:Teletransportar(jugador, Util.Elegir(self.Spawns))
	end
end

-- Cada frame: revisa caídas, muertes y jugadores que se fueron.
function Ronda.Vigilar(self: Ronda)
	if not self.Activa or not self.Iniciada then
		return
	end
	local limite = self.Centro.Y + self.Minijuego.AlturaMuerte
	for _, jugador in self.Participantes do
		if self.Estados[jugador] == "vivo" then
			if jugador.Parent ~= Players then
				self:Abandonar(jugador)
			else
				local humanoide = Jugadores.Humanoide(jugador)
				local raiz = Jugadores.Raiz(jugador)
				if not humanoide or not raiz or humanoide.Health <= 0 then
					self:Eliminar(jugador, "se desintegró 💨")
				elseif raiz.Position.Y < limite then
					if self.Minijuego.Tipo == "supervivencia" then
						self:Eliminar(jugador, Util.Elegir(FRASES_CAIDA))
					else
						self:Caer(jugador)
					end
				end
			end
		end
	end
end

-- ----- Ciclo de vida -----

-- 1) Construye la arena.
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
	self:Conectar(Players.PlayerRemoving, function(jugador: Player)
		self:Abandonar(jugador)
	end)
	for i, jugador in self.Participantes do
		local personaje = jugador.Character
		local humanoide = Jugadores.Humanoide(jugador)
		if personaje and humanoide and humanoide.Health > 0 then
			Jugadores.EnRonda[jugador] = true
			Jugadores.UltimoGolpe[jugador] = nil
			humanoide.PlatformStand = false
			if personaje:GetScale() ~= self.Escala then
				local escala = self.Escala
				pcall(function()
					personaje:ScaleTo(escala)
				end)
			end
			Modificadores.AplicarPersonaje(self.Modificador, personaje)
			humanoide.UseJumpPower = true
			humanoide.WalkSpeed = 0
			humanoide.JumpPower = 0
			if #self.Spawns > 0 then
				self:Teletransportar(jugador, self.Spawns[((i - 1) % #self.Spawns) + 1])
			end
			if self.Minijuego.Herramienta then
				Herramientas.DarMartillo(jugador, self:ColorDe(jugador), self.Minijuego.FuerzaMartillo, function(atacante, victima)
					local alGolpear = self.Minijuego.AlGolpear
					if alGolpear and self.Activa then
						alGolpear(self, atacante, victima)
					end
				end)
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
		Jugadores.Escudo[jugador] = nil
		if estaba and jugador.Parent == Players then
			Jugadores.Reaparecer(jugador)
		end
		UI.Poder(jugador, nil)
	end
	local carpeta = self.Carpeta
	task.delay(1, function()
		carpeta:Destroy()
	end)
end

-- ----- Resultados -----

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
		table.insert(filas, { Jugador = jugador, Puesto = puesto, Detalle = `{math.floor(puntaje)} {sufijo}` })
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

-- Lo que se ve en la barra de arriba durante la ronda.
function Ronda.Estado(self: Ronda, fase: string): DatosEstado
	local vivos = #self:Vivos()
	local info: string
	if self.Minijuego.Tipo == "carrera" then
		info = `🏁 {#self.OrdenLlegada} en meta · 🏃 {vivos} corriendo`
	elseif self.Minijuego.Tipo == "supervivencia" then
		info = `🧍 {vivos}/{#self.Participantes} vivos`
	else
		info = `🧍 {vivos} jugando`
	end
	local marcador: { FilaMarcador }? = nil
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
		local filas = {}
		for _, jugador in lista do
			table.insert(filas, {
				Nombre = jugador.DisplayName,
				Puntos = math.floor(self:ObtenerPuntaje(jugador)),
				Id = jugador.UserId,
			})
		end
		marcador = filas
	end
	return {
		Fase = fase,
		Texto = `{self.Minijuego.Emoji} {self.Minijuego.Nombre}`,
		Tiempo = self.TiempoRestante,
		Modo = `{self.Modificador.Emoji} {self.Modificador.Nombre}`,
		Info = info,
		Dobles = self.Dobles,
		Marcador = marcador,
		Unidad = self.Minijuego.UnidadPuntaje,
	}
end

-- =====================================================================
-- ❓ CAJAS SORPRESA con poderes
-- =====================================================================

type Poder = {
	Emoji: string,
	Nombre: string,
	Aplicar: (ronda: Ronda, jugador: Player) -> (),
}

local DURACION_PODER = 8

local PODERES: { Poder } = {
	{
		Emoji = "⚡",
		Nombre = "TURBO",
		Aplicar = function(ronda, jugador)
			local humanoide = Jugadores.Humanoide(jugador)
			if humanoide then
				humanoide.WalkSpeed = ronda.Velocidad * 1.7
				task.delay(DURACION_PODER, function()
					if humanoide.Parent and ronda.Activa and ronda:EstaVivo(jugador) then
						humanoide.WalkSpeed = ronda.Velocidad
					end
				end)
			end
		end,
	},
	{
		Emoji = "🦘",
		Nombre = "SÚPER MUELLE",
		Aplicar = function(ronda, jugador)
			local humanoide = Jugadores.Humanoide(jugador)
			if humanoide then
				humanoide.JumpPower = ronda.Salto * 1.7
				task.delay(DURACION_PODER, function()
					if humanoide.Parent and ronda.Activa and ronda:EstaVivo(jugador) then
						humanoide.JumpPower = ronda.Salto
					end
				end)
			end
		end,
	},
	{
		Emoji = "🛡️",
		Nombre = "ESCUDO",
		Aplicar = function(_ronda, jugador)
			Jugadores.Escudo[jugador] = os.clock() + DURACION_PODER
			local personaje = jugador.Character
			if personaje then
				local campo = Instance.new("ForceField")
				campo.Parent = personaje
				Debris:AddItem(campo, DURACION_PODER)
			end
		end,
	},
	{
		Emoji = "💥",
		Nombre = "ONDA EXPANSIVA",
		Aplicar = function(ronda, jugador)
			local raiz = Jugadores.Raiz(jugador)
			if not raiz then
				return
			end
			Efectos.Explosion(raiz.Position, 12)
			for _, otro in ronda:Vivos() do
				local raizOtro = Jugadores.Raiz(otro)
				if otro ~= jugador and raizOtro and (raizOtro.Position - raiz.Position).Magnitude < 22 then
					local direccion = Util.Direccion(raiz.Position, raizOtro.Position)
					Efectos.Empujar(otro, direccion * 90 + Vector3.new(0, 55, 0), 1.2, jugador)
				end
			end
		end,
	},
	{
		Emoji = "🎈",
		Nombre = "GLOBO",
		Aplicar = function(_ronda, jugador)
			local raiz = Jugadores.Raiz(jugador)
			if not raiz then
				return
			end
			local adjunto = raiz:FindFirstChild("AdjuntoLoco")
			if not adjunto or not adjunto:IsA("Attachment") then
				local nuevo = Instance.new("Attachment")
				nuevo.Name = "AdjuntoLoco"
				nuevo.Parent = raiz
				adjunto = nuevo
			end
			local globo = Instance.new("VectorForce")
			globo.Name = "Globo"
			globo.Attachment0 = adjunto :: Attachment
			globo.RelativeTo = Enum.ActuatorRelativeTo.World
			globo.ApplyAtCenterOfMass = true
			globo.Force = Vector3.new(0, raiz.AssemblyMass * workspace.Gravity * 0.65, 0)
			globo.Parent = raiz
			Debris:AddItem(globo, DURACION_PODER)
		end,
	},
}

local Poderes = {}

function Poderes.Iniciar(ronda: Ronda, radio: number)
	local A = ronda.Centro
	local cajas: { Part } = {}
	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Include
	parametros.FilterDescendantsInstances = { ronda.Carpeta }

	local function crearCaja()
		for _ = 1, 8 do
			local punto = Util.PuntoEnCirculo(A, radio)
			local golpe = workspace:Raycast(punto + Vector3.new(0, 160, 0), Vector3.new(0, -260, 0), parametros)
			if golpe and golpe.Instance:IsA("BasePart") and golpe.Instance.CanCollide then
				local caja = C.Parte({
					Name = "CajaSorpresa",
					Size = Vector3.new(2.6, 2.6, 2.6),
					CFrame = CFrame.new(golpe.Position + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, math.rad(45), math.rad(20)),
					Color = DORADO,
					Material = Enum.Material.Neon,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Parent = ronda.Carpeta,
				})
				local brillo = Instance.new("Sparkles")
				brillo.SparkleColor = DORADO
				brillo.Parent = caja
				C.Flotante(caja, "❓", 2.5, 2.5, Vector3.new(0, 2.6, 0), BLANCO)
				table.insert(cajas, caja)
				return
			end
		end
	end

	task.spawn(function()
		while ronda:Esperar(Util.Aleatorio(5, 9)) do
			for i = #cajas, 1, -1 do
				if not cajas[i].Parent then
					table.remove(cajas, i)
				end
			end
			if #cajas < 3 then
				crearCaja()
			end
		end
	end)

	ronda:Bucle(0.1, function()
		for i = #cajas, 1, -1 do
			local caja = cajas[i]
			if caja.Parent then
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz and (raiz.Position - caja.Position).Magnitude < 3.5 * ronda.Escala + 1.5 then
						table.remove(cajas, i)
						local posicion = caja.Position
						caja:Destroy()
						local poder = Util.Elegir(PODERES)
						poder.Aplicar(ronda, jugador)
						Jugadores.Stat(jugador, "Cajas")
						Efectos.Confeti(posicion, 40)
						local nombre = `{poder.Emoji} {poder.Nombre}`
						UI.Anuncio(`¡{nombre}!`, { Color = NARANJA, Duracion = 1.5 }, jugador)
						UI.Poder(jugador, nombre, if poder.Nombre == "ONDA EXPANSIVA" then 2 else DURACION_PODER)
						ronda:Feed(`🎁 {jugador.DisplayName} cogió {nombre}`)
						break
					end
				end
			end
		end
	end)
end

-- =====================================================================
-- 🎲 LOS MINIJUEGOS
-- Cada minijuego dice cómo se construye (Construir) y qué pasa (Iniciar).
-- Para crear uno nuevo, copia uno parecido y añádelo a la lista.
-- =====================================================================

local MINIJUEGOS: { Minijuego } = {}

local LAVA = Color3.fromRGB(255, 90, 0)

-- ---------------------------------------------------------------------
-- 🟦 SUELO QUE CAE: 3 pisos de baldosas que desaparecen al pisarlas
-- ---------------------------------------------------------------------
do
	local PISOS = 3
	local SEPARACION = 22
	local TAMANO = 7
	local PASO = 7.4
	local RADIO = 44
	local COLORES_PISO = { CIAN, Color3.fromRGB(255, 107, 203), Color3.fromRGB(255, 221, 89) }

	table.insert(MINIJUEGOS, {
		Id = "SueloQueCae",
		Nombre = "Suelo que Cae",
		Emoji = "🟦",
		Descripcion = "¡Las baldosas desaparecen al pisarlas! 3 pisos sobre la lava. Sé el último en pie.",
		Tipo = "supervivencia",
		Duracion = 120,
		AlturaMuerte = -(PISOS - 1) * SEPARACION - 10,
		Cajas = 30,

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
				Color = LAVA,
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

			-- Qué baldosas hay bajo los pies de cada jugador.
			ronda:Bucle(0.05, function()
				local retraso = if os.clock() - inicio > 60 then 0.4 else 0.6
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz then
						-- Caja alta bajo el personaje: funciona con avatares altos y bajos.
						local pies = raiz.Position - Vector3.new(0, 3 * ronda.Escala, 0)
						local caja = Vector3.new(2.4 * ronda.Escala, 3 * ronda.Escala, 2.4 * ronda.Escala)
						for _, parte in workspace:GetPartBoundsInBox(CFrame.new(pies), caja, filtro) do
							romper(parte, retraso)
						end
					end
				end
			end)

			-- A los 40 segundos... ¡TERREMOTO! Caen baldosas solas.
			task.spawn(function()
				if not ronda:Esperar(40) then
					return
				end
				ronda:Anunciar("🌋 ¡TERREMOTO!", NARANJA, 2)
				while ronda.Activa do
					local lista = baldosas:GetChildren()
					for _ = 1, 3 do
						if #lista > 0 then
							local elegida = Util.Elegir(lista)
							if elegida:IsA("BasePart") then
								romper(elegida, 1.2)
							end
						end
					end
					task.wait(0.6)
				end
			end)
		end,
	})
end

-- ---------------------------------------------------------------------
-- ☄️ LLUVIA DE METEORITOS
-- ---------------------------------------------------------------------
do
	local RADIO = 46
	local PASO = 9
	local GROSOR = 3

	table.insert(MINIJUEGOS, {
		Id = "Meteoritos",
		Nombre = "Lluvia de Meteoritos",
		Emoji = "☄️",
		Descripcion = "¡Caen meteoritos que rompen el suelo! Huye de los círculos rojos. Cada vez caen más...",
		Tipo = "supervivencia",
		Duracion = 90,
		AlturaMuerte = -25,
		Cajas = 38,

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
				for _, roca in suelo:GetChildren() do
					if roca:IsA("BasePart") and roca.Anchored and Util.DistanciaPlana(roca.Position, punto) <= radioRotura then
						roca.Anchored = false
						roca.CanCollide = false
						roca.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), -10, math.random(-8, 8))
						Debris:AddItem(roca, 3)
					end
				end
				local ahora = os.clock()
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz and ahora - (ultimoGolpe[jugador] or 0) > 0.5 then
						local d = (raiz.Position - punto).Magnitude
						if d <= radioEmpuje then
							ultimoGolpe[jugador] = ahora
							local fuerza = 1 - d / radioEmpuje
							local direccion = Util.Direccion(punto, raiz.Position)
							Efectos.Empujar(jugador, direccion * (30 + 55 * fuerza) + Vector3.new(0, 40 + 45 * fuerza, 0), 1)
						end
					end
				end
			end

			local function lanzar(gigante: boolean)
				-- A veces apunta a un jugador. ¡Cuidado!
				local objetivo: Vector3
				local vivos = ronda:Vivos()
				local raizObjetivo = if #vivos > 0 and math.random() < 0.45 then Jugadores.Raiz(Util.Elegir(vivos)) else nil
				if raizObjetivo then
					objetivo = Vector3.new(
						raizObjetivo.Position.X + math.random(-6, 6),
						A.Y,
						raizObjetivo.Position.Z + math.random(-6, 6)
					)
				else
					objetivo = Util.PuntoEnCirculo(A, RADIO - 4)
				end

				local aviso = C.Disco(objetivo + Vector3.new(0, 0.15, 0), if gigante then 16 else 7, 0.2, {
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
				local meteorito = C.Bola(objetivo + Vector3.new(math.random(-30, 30), 150, math.random(-30, 30)), tamano, {
					Name = "Meteorito",
					Color = Color3.fromRGB(255, 120, 20),
					Material = Enum.Material.Neon,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Parent = ronda.Carpeta,
				})
				local fuego = Instance.new("Fire")
				fuego.Size = tamano * 1.5
				fuego.Heat = 20
				fuego.Parent = meteorito
				local caida = TweenService:Create(meteorito, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {
					CFrame = CFrame.new(objetivo),
				})
				caida:Play()
				caida.Completed:Wait()
				meteorito:Destroy()
				aviso:Destroy()
				if ronda.Activa then
					if gigante then
						impacto(objetivo, 15, 22)
					else
						impacto(objetivo, 6.5, 10)
					end
				end
			end

			task.spawn(function()
				while ronda.Activa do
					task.spawn(lanzar, false)
					task.wait(math.max(0.22, 1.1 - (os.clock() - inicio) * 0.012))
				end
			end)
			task.spawn(function()
				while ronda:Esperar(25) do
					ronda:Anunciar("☄️ ¡METEORITO GIGANTE!", NARANJA, 2)
					task.spawn(lanzar, true)
				end
			end)
		end,
	})
end

-- ---------------------------------------------------------------------
-- 👑 REY DE LA COLINA: quédate en la cima dorada para sumar puntos
-- ---------------------------------------------------------------------
do
	local RADIO_BASE = 50
	local PISOS = { { Radio = 28, Altura = 4 }, { Radio = 17, Altura = 8 }, { Radio = 9, Altura = 12 } }
	local RADIO_ZONA = 9.5
	local ALTURA_ZONA = 12

	local function rampa(ronda: Ronda, anguloGrados: number, radio: number, abajo: number)
		local d = Vector3.new(math.cos(math.rad(anguloGrados)), 0, math.sin(math.rad(anguloGrados)))
		local posicion = ronda.Centro + d * (radio + 3.5) + Vector3.new(0, abajo + 2, 0)
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

	table.insert(MINIJUEGOS, {
		Id = "ReyColina",
		Nombre = "Rey de la Colina",
		Emoji = "👑",
		Descripcion = "¡Sube a la cima DORADA y quédate ahí para sumar puntos! Usa el Martillo Loco para echar a los demás.",
		Tipo = "puntos",
		Duracion = 60,
		AlturaMuerte = -30,
		Herramienta = true,
		UnidadPuntaje = "seg 👑",
		Cajas = 44,

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
			local colores = { Color3.fromRGB(140, 200, 90), Color3.fromRGB(170, 190, 80), DORADO }
			for i, piso in PISOS do
				C.Disco(A + Vector3.new(0, piso.Altura, 0), piso.Radio, 4, {
					Name = "Piso" .. i,
					Color = colores[i],
					Material = if i == #PISOS then Enum.Material.Neon else Enum.Material.Grass,
					Parent = ronda.Carpeta,
				})
			end
			for _, angulo in { 0, 90, 180, 270 } do
				rampa(ronda, angulo, PISOS[1].Radio, 0)
			end
			for _, angulo in { 45, 225 } do
				rampa(ronda, angulo, PISOS[2].Radio, PISOS[1].Altura)
			end
			for _, angulo in { 135, 315 } do
				rampa(ronda, angulo, PISOS[3].Radio, PISOS[2].Altura)
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
			local corona, _ = C.Flotante(soporte, "👑", 4, 4, Vector3.new(0, 4.5, 0))
			corona.AlwaysOnTop = true
			local lider: Player? = nil

			ronda:Bucle(0.25, function()
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz then
						local altura = raiz.Position.Y - A.Y
						if
							Util.DistanciaPlana(raiz.Position, A) <= RADIO_ZONA
							and altura > ALTURA_ZONA
							and altura < ALTURA_ZONA + 10 * ronda.Escala
						then
							ronda:SumarPuntaje(jugador, 0.25)
						end
					end
				end
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
	})
end

-- ---------------------------------------------------------------------
-- 💣 PATATA BOMBA: pásale la bomba a otro antes de que explote
-- ---------------------------------------------------------------------
do
	local LADO = 70
	local ALTO_PARED = 16

	type EstadoBomba = {
		Portador: Player?,
		Bomba: Part?,
		Resaltado: Highlight?,
		Texto: TextLabel?,
		ExplotaEn: number,
		UltimoPase: number,
		SiguienteEn: number?,
	}
	local estado: EstadoBomba? = nil

	local function quitarBomba(e: EstadoBomba)
		local anterior = e.Portador
		if anterior then
			local humanoide = Jugadores.Humanoide(anterior)
			if humanoide and humanoide.WalkSpeed > 0 then
				humanoide.WalkSpeed = humanoide.WalkSpeed / 1.25
			end
		end
		if e.Bomba then
			e.Bomba:Destroy()
		end
		if e.Resaltado then
			e.Resaltado:Destroy()
		end
		e.Bomba, e.Resaltado, e.Texto, e.Portador = nil, nil, nil, nil
	end

	local function ponerBomba(ronda: Ronda, e: EstadoBomba, jugador: Player): boolean
		local personaje = jugador.Character
		local cabeza = if personaje then personaje:FindFirstChild("Head") else nil
		if not personaje or not cabeza or not cabeza:IsA("BasePart") then
			return false
		end
		quitarBomba(e)
		local bomba = C.Bola(Vector3.zero, 2.6 * ronda.Escala, {
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
		chispas.SparkleColor = NARANJA
		chispas.Parent = bomba
		C.Soldar(cabeza, bomba)
		local _, texto = C.Flotante(bomba, "💣", 2.5, 4, Vector3.new(0, 2.5 * ronda.Escala, 0), ROJO)
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
		e.Portador, e.Bomba, e.Resaltado, e.Texto = jugador, bomba, resaltado, texto
		e.UltimoPase = os.clock()
		UI.Anuncio("💣 ¡TIENES LA BOMBA!", { Color = ROJO, Duracion = 1.5, Subtitulo = "¡Toca a alguien para pasársela!" }, jugador)
		return true
	end

	local function nuevaBomba(ronda: Ronda, e: EstadoBomba)
		local vivos = ronda:Vivos()
		if not ronda.Activa or #vivos == 0 or (#vivos == 1 and #ronda.Participantes > 1) then
			return
		end
		local elegido = Util.Elegir(vivos)
		if ponerBomba(ronda, e, elegido) then
			e.ExplotaEn = os.clock() + Util.Aleatorio(9, 14)
			ronda:Feed(`💣 ¡{elegido.DisplayName} tiene la bomba!`)
		end
	end

	local function explotar(ronda: Ronda, e: EstadoBomba)
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
			if otro ~= victima and raizOtro and (raizOtro.Position - posicion).Magnitude < 14 then
				Efectos.Empujar(otro, Util.Direccion(posicion, raizOtro.Position) * 70 + Vector3.new(0, 40, 0), 0.8)
			end
		end
		e.SiguienteEn = os.clock() + 2.9
		task.wait(0.4)
		ronda:Eliminar(victima, "¡EXPLOTÓ! 💥")
	end

	table.insert(MINIJUEGOS, {
		Id = "PatataBomba",
		Nombre = "Patata Bomba",
		Emoji = "💣",
		Descripcion = "¡Alguien tiene una BOMBA en la cabeza! Si la tienes, toca a otro para pasársela antes de que explote.",
		Tipo = "supervivencia",
		Duracion = 150,
		AlturaMuerte = -20,
		Cajas = 28,

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
			for _, p in {
				{ Vector3.new(0, 0, mitad), Vector3.new(LADO + 4, 0, 2) },
				{ Vector3.new(0, 0, -mitad), Vector3.new(LADO + 4, 0, 2) },
				{ Vector3.new(mitad, 0, 0), Vector3.new(2, 0, LADO + 4) },
				{ Vector3.new(-mitad, 0, 0), Vector3.new(2, 0, LADO + 4) },
			} do
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
				Color = MORADO,
				Material = Enum.Material.Neon,
				Parent = ronda.Carpeta,
			})
			return C.Circulo(A, 26, 8)
		end,

		Iniciar = function(ronda: Ronda)
			local e: EstadoBomba = { ExplotaEn = 0, UltimoPase = 0 }
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
				local raiz = Jugadores.Raiz(portador)
				if os.clock() - e.UltimoPase < 0.8 or not raiz then
					return
				end
				for _, otro in ronda:Vivos() do
					local raizOtro = Jugadores.Raiz(otro)
					if otro ~= portador and raizOtro and (raizOtro.Position - raiz.Position).Magnitude < 4.5 * ronda.Escala then
						if ponerBomba(ronda, e, otro) then
							ronda:Feed(`💣 {portador.DisplayName} le pasó la bomba a {otro.DisplayName}`)
						end
						return
					end
				end
			end)

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
				e.SiguienteEn = os.clock() + 1
			end
		end,
	})
end

-- ---------------------------------------------------------------------
-- 🌪️ LA LICUADORA: dos barras gigantes que giran cada vez más rápido
-- ---------------------------------------------------------------------
do
	local RADIO = 42
	local GROSOR = 1.4

	type Barra = { Parte: Part, Bisagra: HingeConstraint, Inicial: number, Maxima: number }
	local barras: { Barra } = {}

	-- ¿La barra toca a este jugador? (cálculo geométrico, muy fiable)
	local function tocaBarra(barra: Barra, centro: Vector3, raiz: BasePart, escala: number): boolean
		local relativa = raiz.Position - centro
		local direccion = barra.Parte.CFrame.RightVector
		local perpendicular = math.abs(relativa.X * direccion.Z - relativa.Z * direccion.X)
		local largo = math.abs(relativa.X * direccion.X + relativa.Z * direccion.Z)
		if perpendicular > 1.0 * escala + GROSOR / 2 + 0.3 or largo > RADIO + 1 then
			return false
		end
		local pies = raiz.Position.Y - 3 * escala
		local cabeza = raiz.Position.Y + 1.8 * escala
		local y = barra.Parte.Position.Y
		return pies < y + GROSOR / 2 and cabeza > y - GROSOR / 2
	end

	table.insert(MINIJUEGOS, {
		Id = "Licuadora",
		Nombre = "La Licuadora",
		Emoji = "🌪️",
		Descripcion = "¡Dos barras gigantes giran cada vez más rápido! Salta por encima o saldrás volando.",
		Tipo = "supervivencia",
		Duracion = 75,
		AlturaMuerte = -25,
		Cajas = 36,

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
				Color = MORADO,
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
			for _, def in {
				{ Altura = 1.2, Inicial = 0.8, Maxima = 2.3, Color = ROJO },
				{ Altura = 3.8, Inicial = -0.55, Maxima = -1.8, Color = Color3.fromRGB(255, 221, 89) },
			} do
				local parte, bisagra = C.BarraGiratoria(A + Vector3.new(0, def.Altura, 0), RADIO * 2, GROSOR, def.Color, ronda.Carpeta)
				for _, otra in { pilar, plataforma } do
					local sinChoque = Instance.new("NoCollisionConstraint")
					sinChoque.Part0 = parte
					sinChoque.Part1 = otra
					sinChoque.Parent = parte
				end
				table.insert(barras, { Parte = parte, Bisagra = bisagra, Inicial = def.Inicial, Maxima = def.Maxima })
			end
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

			ronda:Bucle(0.5, function()
				local t = os.clock() - inicio
				local progreso = math.clamp(t / 55, 0, 1)
				for _, barra in barras do
					barra.Bisagra.AngularVelocity = barra.Inicial + (barra.Maxima - barra.Inicial) * progreso
				end
				if not turbo and t > 40 then
					turbo = true
					ronda:Anunciar("🌪️ ¡MODO TURBO LICUADORA!", ROJO, 2)
				end
			end)

			ronda:Bucle(0.03, function()
				local ahora = os.clock()
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz and ahora - (ultimoGolpe[jugador] or 0) > 1.2 then
						for _, barra in barras do
							if barra.Parte.Parent and tocaBarra(barra, A, raiz, ronda.Escala) then
								ultimoGolpe[jugador] = ahora
								-- Lanza en la dirección del giro. Al principio solo tumba; luego, ¡vuelas!
								local radial = Util.Direccion(A, raiz.Position)
								local sentido = if barra.Bisagra.AngularVelocity >= 0 then 1 else -1
								local tangente = Vector3.new(-radial.Z, 0, radial.X) * -sentido
								local potencia = 25 + math.abs(barra.Bisagra.AngularVelocity) * 20
								Efectos.Empujar(jugador, tangente * potencia + radial * 12 + Vector3.new(0, 45, 0), 1.1)
								break
							end
						end
					end
				end
			end)
		end,
	})
end

-- ---------------------------------------------------------------------
-- 🏁 CARRERA LOCA: lava, cinta, plataformas que parpadean, trampolines...
-- ---------------------------------------------------------------------
do
	local ANCHO = 26
	local LARGO = 266
	local ALTO_SUPERIOR = 22

	type Punto = { Z: number, Y: number, Destino: CFrame }
	local puntosControl: { Punto } = {}
	local controlDe: { [Player]: number } = {}
	local parpadeo: { { Parte: Part, Grupo: number } } = {}
	local origenZ, metaZ, alturaMeta = 0, 0, 0
	local barraMeta: Part? = nil

	local function suelo(ronda: Ronda, nombre: string, z1: number, z2: number, y: number, ancho: number?, color: Color3?): Part
		return C.Parte({
			Name = nombre,
			Size = Vector3.new(ancho or ANCHO, 2, z2 - z1),
			CFrame = CFrame.new(ronda.Centro.X, y - 1, (z1 + z2) / 2),
			Color = color or Color3.fromRGB(235, 235, 245),
			Parent = ronda.Carpeta,
		})
	end

	local function lava(ronda: Ronda, z1: number, z2: number, y: number)
		C.Parte({
			Name = "Lava",
			Size = Vector3.new(ANCHO + 30, 1, z2 - z1),
			CFrame = CFrame.new(ronda.Centro.X, y, (z1 + z2) / 2),
			Color = LAVA,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = ronda.Carpeta,
		})
	end

	local function control(ronda: Ronda, z: number, y: number)
		local x = ronda.Centro.X
		C.Parte({
			Name = "PuntoControl",
			Size = Vector3.new(ANCHO, 0.2, 2),
			CFrame = CFrame.new(x, y + 0.05, z),
			Color = VERDE,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = ronda.Carpeta,
		})
		table.insert(puntosControl, { Z = z, Y = y, Destino = CFrame.lookAt(Vector3.new(x, y, z + 3), Vector3.new(x, y, z + 10)) })
	end

	table.insert(MINIJUEGOS, {
		Id = "CarreraLoca",
		Nombre = "Carrera Loca",
		Emoji = "🏁",
		Descripcion = "¡Carrera de obstáculos! Lava, cintas locas, plataformas que desaparecen y trampolines. ¡Llega a la META!",
		Tipo = "carrera",
		Duracion = 120,
		AlturaMuerte = -15,

		Construir = function(ronda: Ronda): { CFrame }
			local A = ronda.Centro
			local G, U = A.Y, A.Y + ALTO_SUPERIOR
			local z0 = A.Z - LARGO / 2
			origenZ = z0
			table.clear(puntosControl)
			table.clear(controlDe)
			table.clear(parpadeo)

			-- 1) Salida
			suelo(ronda, "Salida", z0, z0 + 20, G, nil, Color3.fromRGB(30, 144, 255))
			control(ronda, z0 + 2, G)

			-- 2) Piedras sobre lava
			lava(ronda, z0 + 20, z0 + 66, G - 6)
			for fila = 0, 4 do
				local columnas = { -8, 0, 8 }
				table.remove(columnas, math.random(1, 3))
				for _, x in columnas do
					C.Parte({
						Name = "Piedra",
						Size = Vector3.new(6, 1.5, 6),
						CFrame = CFrame.new(A.X + x + math.random(-2, 2), G - 0.75 + math.random(0, 2), z0 + 25 + fila * 8.5),
						Color = Config.COLORES[(fila % #Config.COLORES) + 1],
						Parent = ronda.Carpeta,
					})
				end
			end

			-- 3) Cinta loca que te empuja hacia atrás
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
					Color = ROJO,
					Parent = ronda.Carpeta,
				})
			end
			for _, pos in { Vector3.new(-6, 0, 86), Vector3.new(6, 0, 98) } do
				C.Parte({
					Name = "Poste",
					Size = Vector3.new(3, 6, 3),
					CFrame = CFrame.new(A.X + pos.X, G + 3, z0 + pos.Z),
					Color = NARANJA,
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
						Color = CIAN,
						Material = Enum.Material.Neon,
						Parent = ronda.Carpeta,
					})
					table.insert(parpadeo, { Parte = parte, Grupo = (fila + columna) % 2 })
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
				Color = MORADO,
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
			barraMeta = C.BarraGiratoria(Vector3.new(A.X, U + 1.2, z0 + 202), 32, 1.4, ROJO, ronda.Carpeta)

			-- 7) Puente estrecho y META
			suelo(ronda, "Arriba2", z0 + 217, z0 + 228, U)
			control(ronda, z0 + 220, U)
			suelo(ronda, "Puente", z0 + 228, z0 + 250, U, 5, NARANJA)
			suelo(ronda, "Meta", z0 + 250, z0 + LARGO, U, nil, VERDE)
			metaZ, alturaMeta = z0 + 254, U
			for _, x in { -ANCHO / 2 + 1, ANCHO / 2 - 1 } do
				C.Parte({
					Name = "ColumnaMeta",
					Size = Vector3.new(2, 14, 2),
					CFrame = CFrame.new(A.X + x, U + 7, metaZ),
					Color = BLANCO,
					Parent = ronda.Carpeta,
				})
			end
			local cartel = C.Parte({
				Name = "CartelMeta",
				Size = Vector3.new(ANCHO, 4, 1),
				CFrame = CFrame.new(A.X, U + 15, metaZ) * CFrame.Angles(0, math.pi, 0),
				Color = OSCURO,
				Parent = ronda.Carpeta,
			})
			C.Cartel(cartel, Enum.NormalId.Front, "🏁 META 🏁", Color3.fromRGB(255, 221, 89), 20)
			return C.Parrilla(Vector3.new(A.X, G, z0 + 10), 4, 2, 5)
		end,

		Iniciar = function(ronda: Ronda)
			local barra = barraMeta
			local bisagra = if barra then barra:FindFirstChildOfClass("HingeConstraint") else nil
			if bisagra then
				bisagra.AngularVelocity = 1.7
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

			-- Plataformas que parpadean (las que se van a ir, se ponen rojas).
			task.spawn(function()
				local grupoActivo = 0
				while ronda.Activa do
					for _, p in parpadeo do
						local activa = p.Grupo == grupoActivo
						p.Parte.CanCollide = activa
						p.Parte.Transparency = if activa then 0 else 0.85
						p.Parte.Color = CIAN
					end
					if not ronda:Esperar(1.3) then
						break
					end
					for _, p in parpadeo do
						if p.Grupo == grupoActivo then
							p.Parte.Color = ROJO
						end
					end
					if not ronda:Esperar(0.5) then
						break
					end
					grupoActivo = 1 - grupoActivo
				end
			end)

			local ultimoGolpe: { [Player]: number } = {}
			ronda:Bucle(0.05, function()
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz then
						local pos = raiz.Position
						local recorrido = math.max(0, pos.Z - origenZ)
						if recorrido > ronda:ObtenerPuntaje(jugador) and pos.Y > ronda.Centro.Y - 4 then
							ronda:FijarPuntaje(jugador, recorrido)
						end
						local actual = controlDe[jugador] or 1
						for i = actual + 1, #puntosControl do
							local punto = puntosControl[i]
							if pos.Z >= punto.Z and pos.Y >= punto.Y - 2 then
								controlDe[jugador] = i
							end
						end
						if barra and barra.Parent and os.clock() - (ultimoGolpe[jugador] or 0) > 1 then
							local centro = barra.Position
							local rel = pos - centro
							local dir = barra.CFrame.RightVector
							local perp = math.abs(rel.X * dir.Z - rel.Z * dir.X)
							local largo = math.abs(rel.X * dir.X + rel.Z * dir.Z)
							local pies = pos.Y - 3 * ronda.Escala
							if perp < ronda.Escala + 1 and largo < 17 and pies < centro.Y + 0.7 and pos.Y + 1.8 * ronda.Escala > centro.Y - 0.7 then
								ultimoGolpe[jugador] = os.clock()
								Efectos.Empujar(jugador, Vector3.new(if rel.X >= 0 then 60 else -60, 50, -20), 1.2)
							end
						end
						if pos.Z >= metaZ and pos.Y >= alturaMeta - 2 then
							ronda:Llegar(jugador)
						end
					end
				end
			end)
		end,

		AlCaer = function(ronda: Ronda, jugador: Player)
			local punto = puntosControl[controlDe[jugador] or 1]
			if punto then
				ronda:Teletransportar(jugador, punto.Destino + Vector3.new(math.random(-8, 8), 0, 0))
			end
		end,
	})
end

-- ---------------------------------------------------------------------
-- 🧊 SUMO EN EL HIELO: pista resbaladiza que encoge + viento + martillos
-- ---------------------------------------------------------------------
do
	local RADIO_INICIAL = 32
	local RADIO_MINIMO = 10

	table.insert(MINIJUEGOS, {
		Id = "SumoHielo",
		Nombre = "Sumo en el Hielo",
		Emoji = "🧊",
		Descripcion = "¡Pista de HIELO que encoge! Usa el Martillo Loco para echar a los demás. Cuidado con el viento...",
		Tipo = "supervivencia",
		Duracion = 90,
		AlturaMuerte = -15,
		Herramienta = true,
		FuerzaMartillo = 1.25,
		Cajas = 14,

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
				Color = CIAN,
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
			nieve.Color = ColorSequence.new(BLANCO)
			nieve.LightEmission = 0.5
			nieve.SpreadAngle = Vector2.new(15, 15)
			nieve.Parent = nube
			return C.Circulo(A, 18, 8)
		end,

		Iniciar = function(ronda: Ronda)
			local pista = ronda.Carpeta:FindFirstChild("PistaHielo")
			local bordeHielo = ronda.Carpeta:FindFirstChild("BordeHielo")
			task.spawn(function()
				local radio = RADIO_INICIAL
				while ronda:Esperar(10) and radio > RADIO_MINIMO do
					radio = math.max(RADIO_MINIMO, radio - 4)
					ronda:Anunciar("⚠️ ¡LA PISTA ENCOGE!", CIAN, 1.5)
					if pista and pista:IsA("BasePart") then
						TweenService:Create(pista, TweenInfo.new(1.5), { Size = Vector3.new(4, radio * 2, radio * 2) }):Play()
					end
					if bordeHielo and bordeHielo:IsA("BasePart") then
						TweenService:Create(bordeHielo, TweenInfo.new(1.5), { Size = Vector3.new(3.4, radio * 2 + 2, radio * 2 + 2) }):Play()
					end
				end
			end)
			task.spawn(function()
				while ronda:Esperar(Util.Aleatorio(12, 16)) do
					local angulo = math.random() * math.pi * 2
					local direccion = Vector3.new(math.cos(angulo), 0, math.sin(angulo))
					ronda:Anunciar("💨 ¡RÁFAGA DE VIENTO!", Color3.fromRGB(200, 230, 255), 1.5)
					task.wait(1)
					for _, jugador in ronda:Vivos() do
						Efectos.Empujar(jugador, direccion * 55 + Vector3.new(0, 14, 0), 0.4)
					end
				end
			end)
		end,
	})
end

-- ---------------------------------------------------------------------
-- 🎳 RAMPA RODANTE: sube la rampa mientras bajan bolas gigantes
-- ---------------------------------------------------------------------
do
	local ANGULO = math.rad(12)
	local LARGO = 220
	local ANCHO = 40
	local SUBIDA = LARGO * math.sin(ANGULO)
	local inicioZ = 0
	local salidas: { CFrame } = {}

	local function marcoRampa(A: Vector3): CFrame
		return CFrame.new(A + Vector3.new(0, SUBIDA / 2, 0)) * CFrame.Angles(-ANGULO, 0, 0)
	end

	table.insert(MINIJUEGOS, {
		Id = "RampaRodante",
		Nombre = "Rampa Rodante",
		Emoji = "🎳",
		Descripcion = "¡Sube la rampa hasta arriba mientras bajan BOLAS GIGANTES rodando! El primero en llegar gana.",
		Tipo = "carrera",
		Duracion = 100,
		AlturaMuerte = -25,

		Construir = function(ronda: Ronda): { CFrame }
			local A = ronda.Centro
			local marco = marcoRampa(A)
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

			local arriba = marco * CFrame.new(0, 1, LARGO / 2)
			C.Parte({
				Name = "Meta",
				Size = Vector3.new(ANCHO, 2, 30),
				CFrame = CFrame.new(A.X, arriba.Position.Y - 1, arriba.Position.Z + 14.5),
				Color = VERDE,
				Parent = ronda.Carpeta,
			})
			local cartel = C.Parte({
				Name = "CartelMeta",
				Size = Vector3.new(ANCHO, 5, 1),
				CFrame = CFrame.new(A.X, arriba.Position.Y + 16, arriba.Position.Z + 8) * CFrame.Angles(0, math.pi, 0),
				Color = OSCURO,
				Parent = ronda.Carpeta,
			})
			C.Cartel(cartel, Enum.NormalId.Front, "🏁 ¡SUBE HASTA AQUÍ! 🏁", Color3.fromRGB(255, 221, 89), 20)
			for _, x in { -ANCHO / 2 + 1, ANCHO / 2 - 1 } do
				C.Parte({
					Name = "ColumnaMeta",
					Size = Vector3.new(2, 16, 2),
					CFrame = CFrame.new(A.X + x, arriba.Position.Y + 8, arriba.Position.Z + 8),
					Color = BLANCO,
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
			local marco = marcoRampa(A)
			local arriba = marco * CFrame.new(0, 1, LARGO / 2)

			local function soltarBola(gigante: boolean)
				local diametro = if gigante then 26 else math.random(9, 15)
				local margen = math.floor(ANCHO / 2 - diametro / 2 - 1)
				local x = if gigante then 0 else math.random(-margen, margen)
				local salida = marco * CFrame.new(x, 1 + diametro / 2 + 1, LARGO / 2 - diametro / 2 - 4)
				local bola = C.Bola(salida.Position, diametro, {
					Name = "Bola",
					Color = Util.Elegir(Config.COLORES),
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

			task.spawn(function()
				while ronda.Activa do
					soltarBola(false)
					if not ronda:Esperar(math.max(0.55, 1.6 - (os.clock() - inicio) * 0.015)) then
						break
					end
				end
			end)
			task.spawn(function()
				while ronda:Esperar(20) do
					ronda:Anunciar("🎳 ¡BOLA GIGANTE!", NARANJA, 2)
					soltarBola(true)
				end
			end)

			ronda:Bucle(0.05, function()
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
						local recorrido = math.max(0, pos.Z - inicioZ)
						if recorrido > ronda:ObtenerPuntaje(jugador) then
							ronda:FijarPuntaje(jugador, recorrido)
						end
						if ahora - (ultimoGolpe[jugador] or 0) > 1 then
							for _, bola in bolas do
								if (bola.Position - pos).Magnitude < bola.Size.X / 2 + 1.8 * ronda.Escala then
									ultimoGolpe[jugador] = ahora
									Efectos.Empujar(jugador, Vector3.new(math.random(-20, 20), 45, -75), 1.2)
									break
								end
							end
						end
						if pos.Z >= arriba.Position.Z + 3 and pos.Y >= arriba.Position.Y - 2 then
							ronda:Llegar(jugador)
						end
					end
				end
			end)
		end,

		AlCaer = function(ronda: Ronda, jugador: Player)
			if #salidas > 0 then
				ronda:Teletransportar(jugador, Util.Elegir(salidas))
			end
		end,
	})
end

-- ---------------------------------------------------------------------
-- 🎨 PINTA EL SUELO (NUEVO): pinta baldosas de tu color pisándolas
-- ---------------------------------------------------------------------
do
	local N = 14
	local PASO = 6.2
	local TAM = 6
	local GRIS = Color3.fromRGB(225, 225, 232)

	table.insert(MINIJUEGOS, {
		Id = "PintaSuelo",
		Nombre = "Pinta el Suelo",
		Emoji = "🎨",
		Descripcion = "¡Pinta baldosas de TU color pisándolas! Gana quien tenga más suelo pintado. (Puedes repintar las de los demás 😈)",
		Tipo = "puntos",
		Duracion = 60,
		AlturaMuerte = -25,
		Herramienta = true,
		FuerzaMartillo = 0.9,
		UnidadPuntaje = "🎨",
		Cajas = 38,

		Construir = function(ronda: Ronda): { CFrame }
			local A = ronda.Centro
			local lienzo = Instance.new("Folder")
			lienzo.Name = "Lienzo"
			lienzo.Parent = ronda.Carpeta
			for ix = 1, N do
				for iz = 1, N do
					C.Parte({
						Name = "Baldosa",
						Size = Vector3.new(TAM, 1, TAM),
						CFrame = CFrame.new(A + Vector3.new((ix - (N + 1) / 2) * PASO, -0.5, (iz - (N + 1) / 2) * PASO)),
						Color = GRIS,
						Parent = lienzo,
					})
				end
			end
			C.Parte({
				Name = "Base",
				Size = Vector3.new(N * PASO + 3, 1, N * PASO + 3),
				CFrame = CFrame.new(A - Vector3.new(0, 1.6, 0)),
				Color = Color3.fromRGB(40, 40, 60),
				Material = Enum.Material.Neon,
				Parent = ronda.Carpeta,
			})
			return C.Circulo(A, 30, 8)
		end,

		Iniciar = function(ronda: Ronda)
			local lienzo = ronda.Carpeta:FindFirstChild("Lienzo")
			if not lienzo then
				return
			end
			local dueno: { [BasePart]: Player } = {}
			local cuenta: { [Player]: number } = {}

			for _, jugador in ronda:Vivos() do
				local personaje = jugador.Character
				if personaje then
					local resaltado = Instance.new("Highlight")
					resaltado.Name = "ColorPintura"
					resaltado.FillColor = ronda:ColorDe(jugador)
					resaltado.FillTransparency = 0.55
					resaltado.OutlineColor = ronda:ColorDe(jugador)
					resaltado.Parent = personaje
				end
				UI.Anuncio("🎨 ¡ESTE ES TU COLOR!", { Color = ronda:ColorDe(jugador), Duracion = 2 }, jugador)
			end

			local function pintar(baldosa: BasePart, jugador: Player)
				local anterior = dueno[baldosa]
				if anterior == jugador then
					return
				end
				if anterior then
					cuenta[anterior] = math.max(0, (cuenta[anterior] or 0) - 1)
				end
				dueno[baldosa] = jugador
				cuenta[jugador] = (cuenta[jugador] or 0) + 1
				baldosa.Color = ronda:ColorDe(jugador)
			end

			local filtro = OverlapParams.new()
			filtro.FilterType = Enum.RaycastFilterType.Include
			filtro.FilterDescendantsInstances = { lienzo }

			ronda:Bucle(0.08, function()
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz then
						local pies = raiz.Position - Vector3.new(0, 3 * ronda.Escala, 0)
						local caja = Vector3.new(3 * ronda.Escala, 3 * ronda.Escala, 3 * ronda.Escala)
						for _, baldosa in workspace:GetPartBoundsInBox(CFrame.new(pies), caja, filtro) do
							pintar(baldosa, jugador)
						end
					end
				end
				for _, jugador in ronda.Participantes do
					ronda:FijarPuntaje(jugador, cuenta[jugador] or 0)
				end
			end)

			-- ¡Bombas de pintura! Pintan un círculo enorme del color de alguien.
			task.spawn(function()
				while ronda:Esperar(12) do
					local vivos = ronda:Vivos()
					if #vivos > 0 then
						local jugador = Util.Elegir(vivos)
						local raiz = Jugadores.Raiz(jugador)
						if raiz then
							ronda:Anunciar(`🎨 ¡BOMBA DE PINTURA de {jugador.DisplayName}!`, ronda:ColorDe(jugador), 2)
							Efectos.Explosion(raiz.Position, 10)
							for _, baldosa in lienzo:GetChildren() do
								if baldosa:IsA("BasePart") and Util.DistanciaPlana(baldosa.Position, raiz.Position) < 10 then
									pintar(baldosa, jugador)
								end
							end
						end
					end
				end
			end)
		end,
	})
end

-- ---------------------------------------------------------------------
-- 🚦 LUZ ROJA, LUZ VERDE (NUEVO): corre en verde, ¡quieto en rojo!
-- ---------------------------------------------------------------------
do
	local LARGO = 170
	local ANCHO = 44
	local metaZ, origenZ = 0, 0
	local cabezaMuneca: Model? = nil
	local luz: Part? = nil
	local cartel: TextLabel? = nil
	local salidas: { CFrame } = {}

	local function construirMuneca(ronda: Ronda, base: Vector3)
		-- Cuerpo (vestido naranja)
		C.Parte({
			Name = "Vestido",
			Size = Vector3.new(8, 12, 6),
			CFrame = CFrame.new(base + Vector3.new(0, 6, 0)),
			Color = Color3.fromRGB(255, 150, 30),
			Parent = ronda.Carpeta,
		})
		C.Parte({
			Name = "Cuello",
			Size = Vector3.new(8.4, 1.5, 6.4),
			CFrame = CFrame.new(base + Vector3.new(0, 11.5, 0)),
			Color = Color3.fromRGB(255, 221, 89),
			Parent = ronda.Carpeta,
		})
		-- Cabeza (un modelo que gira entero)
		local modelo = Instance.new("Model")
		modelo.Name = "CabezaMuneca"
		local centro = base + Vector3.new(0, 16, 0)
		local cabeza = C.Bola(centro, 7, { Name = "Cabeza", Color = Color3.fromRGB(255, 220, 180), Parent = modelo })
		C.Bola(centro + Vector3.new(0, 0.8, 0.6), 7.3, { Name = "Pelo", Color = Color3.fromRGB(30, 25, 25), Parent = modelo })
		for _, x in { -3.6, 3.6 } do
			C.Bola(centro + Vector3.new(x, 0.6, 0.8), 2.6, { Name = "Coleta", Color = Color3.fromRGB(30, 25, 25), Parent = modelo })
		end
		for _, x in { -1.3, 1.3 } do
			C.Bola(centro + Vector3.new(x, 0.4, -3.15), 1.1, { Name = "Ojo", Color = Color3.new(0, 0, 0), Parent = modelo })
		end
		C.Parte({
			Name = "Boca",
			Size = Vector3.new(1.6, 0.4, 0.4),
			CFrame = CFrame.new(centro + Vector3.new(0, -1.5, -3.2)),
			Color = ROJO,
			Parent = modelo,
		})
		modelo.PrimaryPart = cabeza
		modelo.Parent = ronda.Carpeta
		cabezaMuneca = modelo
	end

	local function girarCabeza(mirando: boolean)
		local modelo = cabezaMuneca
		if modelo then
			local centro = modelo:GetPivot().Position
			-- mirando = hacia los jugadores (que vienen desde -Z)
			modelo:PivotTo(CFrame.new(centro) * CFrame.Angles(0, if mirando then 0 else math.pi, 0))
		end
	end

	table.insert(MINIJUEGOS, {
		Id = "LuzRoja",
		Nombre = "Luz Roja, Luz Verde",
		Emoji = "🚦",
		Descripcion = "¡Corre hacia la meta cuando esté VERDE! Si te mueves cuando esté en ROJO... ¡BOOM!",
		Tipo = "carrera",
		Duracion = 90,
		AlturaMuerte = -20,

		Construir = function(ronda: Ronda): { CFrame }
			local A = ronda.Centro
			local z0 = A.Z - LARGO / 2
			origenZ = z0
			metaZ = z0 + LARGO - 14
			C.Parte({
				Name = "Campo",
				Size = Vector3.new(ANCHO, 2, LARGO + 10),
				CFrame = CFrame.new(A.X, A.Y - 1, A.Z),
				Color = Color3.fromRGB(230, 200, 140),
				Material = Enum.Material.Sand,
				Parent = ronda.Carpeta,
			})
			for _, z in { z0 + 10, metaZ } do
				C.Parte({
					Name = "Linea",
					Size = Vector3.new(ANCHO, 0.1, 1.5),
					CFrame = CFrame.new(A.X, A.Y + 0.05, z),
					Color = if z == metaZ then ROJO else BLANCO,
					Material = Enum.Material.Neon,
					CanCollide = false,
					CanQuery = false,
					Parent = ronda.Carpeta,
				})
			end
			-- Vallas + paredes invisibles para no salirse
			for _, x in { -ANCHO / 2 - 0.5, ANCHO / 2 + 0.5 } do
				C.Parte({
					Name = "Valla",
					Size = Vector3.new(1, 4, LARGO + 10),
					CFrame = CFrame.new(A.X + x, A.Y + 2, A.Z),
					Color = Color3.fromRGB(46, 160, 90),
					Parent = ronda.Carpeta,
				})
				C.Parte({
					Name = "ParedInvisible",
					Size = Vector3.new(1, 80, LARGO + 10),
					CFrame = CFrame.new(A.X + x, A.Y + 40, A.Z),
					Transparency = 1,
					Parent = ronda.Carpeta,
				})
			end
			C.Parte({
				Name = "ParedInvisible",
				Size = Vector3.new(ANCHO + 2, 80, 1),
				CFrame = CFrame.new(A.X, A.Y + 40, z0 - 5),
				Transparency = 1,
				Parent = ronda.Carpeta,
			})

			local baseMuneca = Vector3.new(A.X, A.Y, z0 + LARGO + 2)
			construirMuneca(ronda, baseMuneca)
			girarCabeza(false)
			local semaforo = C.Parte({
				Name = "Semaforo",
				Size = Vector3.new(16, 5, 1),
				CFrame = CFrame.new(baseMuneca + Vector3.new(0, 25, -2)),
				Color = OSCURO,
				Parent = ronda.Carpeta,
			})
			cartel = C.Cartel(semaforo, Enum.NormalId.Front, "🟢 ¡CORRE!", VERDE, 20)
			luz = C.Bola(baseMuneca + Vector3.new(0, 31, -2), 5, {
				Name = "Luz",
				Color = VERDE,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = ronda.Carpeta,
			})
			salidas = C.Parrilla(Vector3.new(A.X, A.Y, z0 + 5), 4, 2, 6)
			return salidas
		end,

		Iniciar = function(ronda: Ronda)
			local quietos: { [Player]: Vector3 } = {}
			local vigilando = false
			local inicio = os.clock()

			local function semaforo(color: Color3, mensaje: string)
				if luz then
					luz.Color = color
				end
				if cartel then
					cartel.Text = mensaje
					cartel.TextColor3 = color
				end
			end

			task.spawn(function()
				while ronda.Activa do
					vigilando = false
					girarCabeza(false)
					semaforo(VERDE, "🟢 ¡CORRE!")
					ronda:Anunciar("🟢 ¡LUZ VERDE!", VERDE, 1)
					local verde = Util.Aleatorio(2, 4.5) * (if os.clock() - inicio > 40 then 0.7 else 1)
					if not ronda:Esperar(verde) then
						break
					end
					girarCabeza(true)
					semaforo(ROJO, "🔴 ¡QUIETO!")
					ronda:Anunciar("🔴 ¡LUZ ROJA!", ROJO, 1)
					sonidoGlobal(SONIDOS.Pip, 0.7, 0.6)
					if not ronda:Esperar(0.6) then -- un momento para frenar
						break
					end
					table.clear(quietos)
					for _, jugador in ronda:Vivos() do
						local raiz = Jugadores.Raiz(jugador)
						if raiz then
							quietos[jugador] = raiz.Position
						end
					end
					vigilando = true
					if not ronda:Esperar(Util.Aleatorio(2, 3.5)) then
						break
					end
				end
			end)

			ronda:Bucle(0.1, function()
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz then
						local pos = raiz.Position
						local recorrido = math.max(0, pos.Z - origenZ)
						if recorrido > ronda:ObtenerPuntaje(jugador) then
							ronda:FijarPuntaje(jugador, recorrido)
						end
						if pos.Z >= metaZ then
							ronda:Llegar(jugador)
						elseif vigilando then
							local antes = quietos[jugador]
							if antes and (Util.DistanciaPlana(pos, antes) > 2.2 * ronda.Escala or pos.Y - antes.Y > 2.5) then
								quietos[jugador] = nil
								Efectos.Explosion(pos, 6)
								Efectos.Empujar(jugador, Vector3.new(0, 90, -40), 1.5)
								ronda:Eliminar(jugador, "se movió en ROJO 🔴")
							end
						end
					end
				end
			end)
		end,

		AlCaer = function(ronda: Ronda, jugador: Player)
			if #salidas > 0 then
				ronda:Teletransportar(jugador, Util.Elegir(salidas))
			end
		end,
	})
end

-- ---------------------------------------------------------------------
-- 🌋 LA LAVA SUBE (NUEVO): escala la torre antes de que te alcance
-- ---------------------------------------------------------------------
do
	local PASOS = 22
	local ALTURA_PASO = 3.6
	local CIMA = PASOS * ALTURA_PASO + 3.5
	local lavaParte: Part? = nil

	table.insert(MINIJUEGOS, {
		Id = "LavaSube",
		Nombre = "La Lava Sube",
		Emoji = "🌋",
		Descripcion = "¡La lava sube sin parar! Escala la torre de plataformas hasta la cima dorada. Con martillos... 😈",
		Tipo = "supervivencia",
		Duracion = 110,
		AlturaMuerte = -15,
		Herramienta = true,
		FuerzaMartillo = 0.8,
		Cajas = 22,

		Construir = function(ronda: Ronda): { CFrame }
			local A = ronda.Centro
			C.Disco(A, 32, 3, {
				Name = "Base",
				Color = Color3.fromRGB(60, 50, 50),
				Material = Enum.Material.Basalt,
				Parent = ronda.Carpeta,
			})
			for k = 1, PASOS do
				for s = 0, 1 do
					local angulo = k * 0.42 + s * math.pi
					local radio = 22 - k * 0.5
					C.Parte({
						Name = "Plataforma",
						Size = Vector3.new(8, 1.2, 8),
						CFrame = CFrame.new(A + Vector3.new(math.cos(angulo) * radio, k * ALTURA_PASO - 0.6, math.sin(angulo) * radio))
							* CFrame.Angles(0, -angulo, 0),
						Color = Color3.fromHSV(0.55 - (k / PASOS) * 0.5, 0.6, 1),
						Parent = ronda.Carpeta,
					})
				end
			end
			local cima = C.Disco(A + Vector3.new(0, CIMA, 0), 10, 2, {
				Name = "Cima",
				Color = DORADO,
				Material = Enum.Material.Neon,
				Parent = ronda.Carpeta,
			})
			C.Flotante(cima, "🏆 CIMA", 3, 10, Vector3.new(0, 6, 0), DORADO)
			local lava = C.Parte({
				Name = "Lava",
				Size = Vector3.new(140, 6, 140),
				CFrame = CFrame.new(A - Vector3.new(0, 9, 0)),
				Color = LAVA,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = ronda.Carpeta,
			})
			local burbujas = Instance.new("ParticleEmitter")
			burbujas.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60))
			burbujas.Rate = 40
			burbujas.Lifetime = NumberRange.new(0.8, 1.5)
			burbujas.Speed = NumberRange.new(4, 10)
			burbujas.Size = NumberSequence.new(1.2, 0)
			burbujas.LightEmission = 1
			burbujas.EmissionDirection = Enum.NormalId.Top
			burbujas.Parent = lava
			lavaParte = lava
			return C.Circulo(A, 20, 8)
		end,

		Iniciar = function(ronda: Ronda)
			local A = ronda.Centro
			local lava = lavaParte
			if not lava then
				return
			end
			ronda:Anunciar("🌋 ¡La lava empieza a subir!", NARANJA, 2)
			if not ronda:Esperar(4) then
				return
			end
			-- Sube hasta quedarse justo debajo de la cima al final de la ronda.
			local subida = ronda.Minijuego.Duracion - 15
			TweenService:Create(lava, TweenInfo.new(subida, Enum.EasingStyle.Linear), {
				CFrame = CFrame.new(A.X, A.Y + CIMA - 6, A.Z),
			}):Play()
			ronda:Bucle(0.1, function()
				local arriba = lava.Position.Y + 3
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz and raiz.Position.Y - 2.5 * ronda.Escala < arriba then
						local fuego = Instance.new("Fire")
						fuego.Size = 8
						fuego.Parent = raiz
						Debris:AddItem(fuego, 2)
						Efectos.Empujar(jugador, Vector3.new(0, 70, 0), 1)
						ronda:Eliminar(jugador, "se derritió en la lava 🔥")
					end
				end
			end)
			task.spawn(function()
				if ronda:Esperar(subida / 2) then
					ronda:Anunciar("🔥 ¡La lava va por la MITAD!", NARANJA, 2)
				end
			end)
		end,
	})
end

-- ---------------------------------------------------------------------
-- 🧱 MURO LOCO (NUEVO): ponte en el hueco o salta los muros bajitos
-- ---------------------------------------------------------------------
do
	local ANCHO = 50
	local FONDO = 34
	local ALTO = 12
	local HUECO = 8

	type Muro = { Partes: { Part }, Huecos: { number }, Bajo: boolean, ZAnterior: number, Golpeados: { [Player]: boolean } }

	table.insert(MINIJUEGOS, {
		Id = "MuroLoco",
		Nombre = "Muro Loco",
		Emoji = "🧱",
		Descripcion = "¡Vienen muros con agujeros! Ponte en el HUECO o salta los muros bajitos... ¡o saldrás volando!",
		Tipo = "supervivencia",
		Duracion = 80,
		AlturaMuerte = -20,
		Herramienta = true,
		FuerzaMartillo = 0.7,
		Cajas = 14,

		Construir = function(ronda: Ronda): { CFrame }
			local A = ronda.Centro
			C.Parte({
				Name = "Plataforma",
				Size = Vector3.new(ANCHO, 2, FONDO),
				CFrame = CFrame.new(A - Vector3.new(0, 1, 0)),
				Color = Color3.fromRGB(90, 200, 255),
				Parent = ronda.Carpeta,
			})
			for i = -2, 2 do
				C.Parte({
					Name = "Raya",
					Size = Vector3.new(0.4, 0.1, FONDO),
					CFrame = CFrame.new(A + Vector3.new(i * 10, 0.05, 0)),
					Color = BLANCO,
					Material = Enum.Material.Neon,
					CanCollide = false,
					CanQuery = false,
					Parent = ronda.Carpeta,
				})
			end
			return C.Parrilla(A, 4, 2, 8)
		end,

		Iniciar = function(ronda: Ronda)
			local A = ronda.Centro
			local inicio = os.clock()
			local muros: { Muro } = {}

			local function crearMuro()
				local t = os.clock() - inicio
				local velocidad = math.min(45, 22 + t * 0.35)
				local bajo = math.random() < 0.25
				local huecos: { number } = {}
				if not bajo then
					for _ = 1, if math.random() < 0.5 then 1 else 2 do
						for _ = 1, 10 do
							local x = math.random(-(ANCHO // 2 - 5), ANCHO // 2 - 5)
							local valido = true
							for _, h in huecos do
								if math.abs(h - x) < 12 then
									valido = false
								end
							end
							if valido then
								table.insert(huecos, x)
								break
							end
						end
					end
					table.sort(huecos)
				end
				local altura = if bajo then 3 else ALTO
				local color = Util.Elegir(Config.COLORES)
				local zInicio = A.Z + 70
				local tramos = {}
				local x = -ANCHO / 2 - 2
				for _, h in huecos do
					if h - HUECO / 2 > x then
						table.insert(tramos, { x, h - HUECO / 2 })
					end
					x = h + HUECO / 2
				end
				if ANCHO / 2 + 2 > x then
					table.insert(tramos, { x, ANCHO / 2 + 2 })
				end
				local muro: Muro = { Partes = {}, Huecos = huecos, Bajo = bajo, ZAnterior = zInicio, Golpeados = {} }
				local duracion = 140 / velocidad
				for _, tramo in tramos do
					local parte = C.Parte({
						Name = "Muro",
						Size = Vector3.new(tramo[2] - tramo[1], altura, 2),
						CFrame = CFrame.new(A.X + (tramo[1] + tramo[2]) / 2, A.Y + altura / 2, zInicio),
						Color = color,
						Material = Enum.Material.Neon,
						CanCollide = false,
						CanQuery = false,
						CanTouch = false,
						Parent = ronda.Carpeta,
					})
					local tween = TweenService:Create(parte, TweenInfo.new(duracion, Enum.EasingStyle.Linear), {
						CFrame = parte.CFrame - Vector3.new(0, 0, 140),
					})
					tween:Play()
					Debris:AddItem(parte, duracion + 0.2)
					table.insert(muro.Partes, parte)
				end
				if #muro.Partes > 0 then
					table.insert(muros, muro)
				end
			end

			ronda:Anunciar("🧱 ¡AQUÍ VIENEN LOS MUROS!", NARANJA, 2)
			task.spawn(function()
				if not ronda:Esperar(2) then
					return
				end
				while ronda.Activa do
					crearMuro()
					if not ronda:Esperar(math.max(1.8, 4 - (os.clock() - inicio) * 0.04)) then
						break
					end
				end
			end)

			ronda:Bucle(0.05, function()
				for i = #muros, 1, -1 do
					local muro = muros[i]
					local primera = muro.Partes[1]
					if not primera.Parent then
						table.remove(muros, i)
						continue
					end
					local z = primera.Position.Z
					local margen = 1 + 1.2 * ronda.Escala
					for _, jugador in ronda:Vivos() do
						local raiz = Jugadores.Raiz(jugador)
						if raiz and not muro.Golpeados[jugador] then
							local pos = raiz.Position
							-- ¿El muro ha pasado por donde está el jugador?
							if pos.Z <= muro.ZAnterior + margen and pos.Z >= z - margen then
								local pies = pos.Y - 3 * ronda.Escala
								local salvo = if muro.Bajo then pies > A.Y + 2.7 else pies > A.Y + ALTO
								for _, h in muro.Huecos do
									if math.abs(pos.X - (A.X + h)) < HUECO / 2 - 0.9 * ronda.Escala then
										salvo = true
									end
								end
								if not salvo then
									muro.Golpeados[jugador] = true
									Efectos.Empujar(jugador, Vector3.new(math.random(-15, 15), 40, -90), 1.3)
									Efectos.Sonido(raiz, SONIDOS.Golpe, 0.8, 0.7)
								end
							end
						end
					end
					muro.ZAnterior = z
				end
			end)
		end,
	})
end

-- ---------------------------------------------------------------------
-- 💎 FIEBRE DE GEMAS (NUEVO): coge gemas... y róbaselas a martillazos
-- ---------------------------------------------------------------------
do
	local RADIO = 44
	local gemas: { Part } = {}
	local ultimoAviso = 0

	-- Para no llenar la pantalla de mensajes: como mucho uno cada 2 segundos.
	local function avisar(ronda: Ronda, mensaje: string)
		if os.clock() - ultimoAviso > 2 then
			ultimoAviso = os.clock()
			ronda:Feed(mensaje)
		end
	end

	local function crearGema(ronda: Ronda, posicion: Vector3, valor: number)
		local dorada = valor >= 5
		local gema = C.Parte({
			Name = "Gema",
			Size = if dorada then Vector3.new(2.2, 2.2, 2.2) else Vector3.new(1.4, 2.2, 1.4),
			CFrame = CFrame.new(posicion + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.random() * 3, if dorada then math.rad(45) else 0),
			Color = if dorada then DORADO else CIAN,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Atributos = { Valor = valor },
			Parent = ronda.Carpeta,
		})
		if dorada then
			local brillo = Instance.new("Sparkles")
			brillo.SparkleColor = DORADO
			brillo.Parent = gema
		end
		table.insert(gemas, gema)
	end

	local function soltarGemas(ronda: Ronda, jugador: Player, cantidad: number)
		local raiz = Jugadores.Raiz(jugador)
		local actual = math.floor(ronda:ObtenerPuntaje(jugador))
		local perdidas = math.min(cantidad, actual)
		if not raiz or perdidas <= 0 then
			return 0
		end
		ronda:FijarPuntaje(jugador, actual - perdidas)
		local A = ronda.Centro
		for _ = 1, perdidas do
			local punto = Util.PuntoEnCirculo(Vector3.new(raiz.Position.X, A.Y, raiz.Position.Z), 7)
			if Util.DistanciaPlana(punto, A) > RADIO - 3 then
				punto = A + Util.Direccion(A, punto) * (RADIO - 3)
			end
			crearGema(ronda, punto, 1)
		end
		return perdidas
	end

	table.insert(MINIJUEGOS, {
		Id = "Gemas",
		Nombre = "Fiebre de Gemas",
		Emoji = "💎",
		Descripcion = "¡Coge todas las gemas que puedas! Las doradas valen 5. Si le das con el martillo a alguien, ¡le haces soltar gemas!",
		Tipo = "puntos",
		Duracion = 60,
		AlturaMuerte = -25,
		Herramienta = true,
		UnidadPuntaje = "💎",

		Construir = function(ronda: Ronda): { CFrame }
			local A = ronda.Centro
			C.Disco(A, RADIO, 4, {
				Name = "Suelo",
				Color = Color3.fromRGB(120, 90, 200),
				Material = Enum.Material.Slate,
				Parent = ronda.Carpeta,
			})
			C.Disco(A - Vector3.new(0, 0.3, 0), RADIO + 1, 3.4, {
				Name = "Borde",
				Color = CIAN,
				Material = Enum.Material.Neon,
				Parent = ronda.Carpeta,
			})
			for i = 1, 6 do
				local angulo = i / 6 * math.pi * 2
				C.Bola(A + Vector3.new(math.cos(angulo) * 24, 1, math.sin(angulo) * 24), math.random(5, 8), {
					Name = "Roca",
					Color = Color3.fromRGB(110, 100, 120),
					Material = Enum.Material.Rock,
					Parent = ronda.Carpeta,
				})
			end
			return C.Circulo(A, 32, 8)
		end,

		Iniciar = function(ronda: Ronda)
			local A = ronda.Centro
			table.clear(gemas)
			local function limpiar()
				for i = #gemas, 1, -1 do
					if not gemas[i].Parent then
						table.remove(gemas, i)
					end
				end
			end
			for _ = 1, 10 do
				crearGema(ronda, Util.PuntoEnCirculo(A, RADIO - 4), 1)
			end
			task.spawn(function()
				while ronda:Esperar(0.5) do
					limpiar()
					if #gemas < 14 then
						crearGema(ronda, Util.PuntoEnCirculo(A, RADIO - 4), if math.random() < 0.08 then 5 else 1)
					end
				end
			end)
			task.spawn(function()
				while ronda:Esperar(20) do
					ronda:Anunciar("💎 ¡LLUVIA DE GEMAS!", CIAN, 2)
					for _ = 1, 15 do
						crearGema(ronda, Util.PuntoEnCirculo(A, RADIO - 4), if math.random() < 0.15 then 5 else 1)
					end
				end
			end)
			ronda:Bucle(0.1, function()
				for _, jugador in ronda:Vivos() do
					local raiz = Jugadores.Raiz(jugador)
					if raiz then
						for i = #gemas, 1, -1 do
							local gema = gemas[i]
							if gema.Parent and (gema.Position - raiz.Position).Magnitude < 3.5 * ronda.Escala + 1 then
								local valorGema = gema:GetAttribute("Valor")
								local puntos = if type(valorGema) == "number" then valorGema else 1
								ronda:SumarPuntaje(jugador, puntos)
								if puntos >= 5 then
									ronda:Feed(`👑 {jugador.DisplayName} cogió una GEMA DORADA (+5)`)
									Efectos.Confeti(gema.Position, 40)
								end
								gema:Destroy()
								table.remove(gemas, i)
							end
						end
					end
				end
			end)
		end,

		AlGolpear = function(ronda: Ronda, atacante: Player, victima: Player)
			local perdidas = soltarGemas(ronda, victima, 3)
			if perdidas > 0 then
				avisar(ronda, `💎 ¡{atacante.DisplayName} le hizo soltar {perdidas} gemas a {victima.DisplayName}!`)
			end
		end,

		AlCaer = function(ronda: Ronda, jugador: Player)
			local actual = math.floor(ronda:ObtenerPuntaje(jugador))
			local perdidas = math.min(2, actual)
			ronda:FijarPuntaje(jugador, actual - perdidas)
			if perdidas > 0 then
				avisar(ronda, `💎 {jugador.DisplayName} se cayó y perdió {perdidas} gemas`)
			end
			ronda:Teletransportar(jugador, Util.Elegir(ronda.Spawns))
		end,
	})
end

-- =====================================================================
-- 🦘 IMPULSOS: trampolines y cañones (partes con la etiqueta "Impulso")
-- =====================================================================

local Impulsos = {}
local ultimoImpulso: { [Player]: number } = {}

local function conectarImpulso(instancia: Instance)
	if not instancia:IsA("BasePart") then
		return
	end
	local parte = instancia
	parte.Touched:Connect(function(otra: BasePart)
		local personaje = otra:FindFirstAncestorOfClass("Model")
		local jugador = if personaje then Players:GetPlayerFromCharacter(personaje) else nil
		if not jugador then
			return
		end
		local ahora = os.clock()
		local impulso = parte:GetAttribute("Impulso")
		if ahora - (ultimoImpulso[jugador] or 0) < 0.6 or typeof(impulso) ~= "Vector3" then
			return
		end
		ultimoImpulso[jugador] = ahora
		local vuelo = parte:GetAttribute("Vuelo")
		if typeof(vuelo) == "number" and vuelo > 0 then
			Efectos.Empujar(jugador, impulso, vuelo)
		else
			Efectos.Impulso(jugador, impulso)
		end
		Efectos.Sonido(parte, SONIDOS.Salto, 0.8, 1.5)
	end)
end

function Impulsos.Iniciar()
	for _, parte in CollectionService:GetTagged("Impulso") do
		conectarImpulso(parte)
	end
	CollectionService:GetInstanceAddedSignal("Impulso"):Connect(conectarImpulso)
	Players.PlayerRemoving:Connect(function(jugador)
		ultimoImpulso[jugador] = nil
	end)
end

-- =====================================================================
-- 🏝️ EL LOBBY: isla flotante, votación, trampolines, cañón, isla secreta,
-- botón rojo y podio. Si ya existe en el juego (lo has editado en Studio),
-- se usa tal cual.
-- =====================================================================

local Lobby = {}
local L = Config.LOBBY
local ISLA_SECRETA = L + Vector3.new(205, 0, 0)
local POSICIONES_VOTO = { L + Vector3.new(-20, 0, 44), L + Vector3.new(0, 0, 48), L + Vector3.new(20, 0, 44) }
local COLORES_VOTO = { Color3.fromRGB(30, 144, 255), MORADO, Color3.fromRGB(255, 107, 203) }

local function construirLuces()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then
		atm = Instance.new("Atmosphere")
	end
	local atmosferaLoca = atm :: Atmosphere
	atmosferaLoca.Density = 0.28
	atmosferaLoca.Offset = 0.2
	atmosferaLoca.Color = Color3.fromRGB(220, 190, 255)
	atmosferaLoca.Decay = Color3.fromRGB(120, 100, 170)
	atmosferaLoca.Glare = 0.3
	atmosferaLoca.Haze = 1.2
	atmosferaLoca.Parent = Lighting
	if not Lighting:FindFirstChild("BrilloLoco") then
		local resplandor = Instance.new("BloomEffect")
		resplandor.Name = "BrilloLoco"
		resplandor.Intensity = 0.7
		resplandor.Size = 28
		resplandor.Threshold = 1.6
		resplandor.Parent = Lighting
	end
	if not Lighting:FindFirstChild("ColoresLocos") then
		local color = Instance.new("ColorCorrectionEffect")
		color.Name = "ColoresLocos"
		color.Saturation = 0.2
		color.Contrast = 0.05
		color.Parent = Lighting
	end
end

-- Quita el suelo gris y los puntos de aparición de la plantilla "Baseplate".
local function limpiarPlantilla()
	if Config.QUITAR_BASEPLATE then
		local base = workspace:FindFirstChild("Baseplate")
		if base and base:IsA("BasePart") then
			base:Destroy()
		end
	end
	local lobby = workspace:FindFirstChild("Lobby")
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and not (lobby and d:IsDescendantOf(lobby)) then
			d.Enabled = false
		end
	end
end

local function construirIsla(centro: Vector3, radio: number, padre: Instance)
	C.Disco(centro, radio, 8, {
		Name = "Cesped",
		Color = Color3.fromRGB(96, 200, 96),
		Material = Enum.Material.Grass,
		Parent = padre,
	})
	local y = centro.Y - 8
	for _, capa in { { 0.9, 10 }, { 0.72, 12 }, { 0.5, 14 }, { 0.26, 16 } } do
		C.Disco(Vector3.new(centro.X, y, centro.Z), radio * capa[1], capa[2], {
			Name = "Roca",
			Color = Color3.fromRGB(120, 92, 70),
			Material = Enum.Material.Rock,
			Parent = padre,
		})
		y -= capa[2]
	end
end

local function cartelDePie(nombre: string, posicion: Vector3, tamano: Vector2, texto: string, color: Color3, padre: Instance): TextLabel
	local tablero = C.Parte({
		Name = nombre,
		Size = Vector3.new(tamano.X, tamano.Y, 1),
		CFrame = CFrame.lookAt(posicion, Vector3.new(L.X, posicion.Y, L.Z)), -- la cara Front mira al centro
		Color = Color3.fromRGB(20, 20, 35),
		Parent = padre,
	})
	C.Parte({
		Name = "Pata",
		Size = Vector3.new(1.5, posicion.Y - L.Y, 1.5),
		CFrame = CFrame.new(Vector3.new(posicion.X, (posicion.Y + L.Y) / 2, posicion.Z)),
		Color = Color3.fromRGB(60, 40, 90),
		Parent = padre,
	})
	return C.Cartel(tablero, Enum.NormalId.Front, texto, color, 20)
end

local function construirCanon(desde: Vector3, haciaX: number, padre: Instance)
	local base = C.Disco(desde + Vector3.new(0, 0.6, 0), 4.5, 0.6, {
		Name = "Canon",
		Color = NARANJA,
		Material = Enum.Material.Neon,
		Tags = { "Impulso" },
		Atributos = { Impulso = Vector3.new(130 * haciaX, 120, 0), Vuelo = 1.1 },
		Parent = padre,
	})
	C.Parte({
		Name = "TuboCanon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 4, 4),
		CFrame = CFrame.new(desde + Vector3.new(-5 * haciaX, 3, 0)) * CFrame.Angles(0, 0, math.rad(if haciaX > 0 then 40 else 140)),
		Color = Color3.fromRGB(50, 50, 60),
		Material = Enum.Material.Metal,
		Parent = padre,
	})
	C.Flotante(base, "🚀 CAÑÓN HUMANO", 2, 10, Vector3.new(0, 6, 0), NARANJA)
end

function Lobby.Construir()
	construirLuces()
	local existente = workspace:FindFirstChild("Lobby")
	if existente then
		for i = 1, 3 do
			local bloque = existente:FindFirstChild("Podio" .. i, true)
			if bloque and bloque:IsA("BasePart") then
				Mundo.Podio[i] = bloque.Position + Vector3.new(0, bloque.Size.Y / 2, 0)
			end
		end
		return
	end

	local carpeta = Instance.new("Folder")
	carpeta.Name = "Lobby"
	construirIsla(L, 75, carpeta)

	-- 8 puntos de aparición de colores
	for i = 1, 8 do
		local angulo = math.rad((i - 1) * 45 + 22.5)
		local posicion = L + Vector3.new(math.cos(angulo) * 27, 0, math.sin(angulo) * 27)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.AllowTeamChangeOnTouch = false
		spawn.Duration = 0
		spawn.Size = Vector3.new(7, 1, 7)
		spawn.CFrame = CFrame.lookAt(posicion, Vector3.new(L.X, posicion.Y, L.Z))
		spawn.Color = Config.COLORES[i]
		spawn.Material = Enum.Material.Neon
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = carpeta
	end

	-- Pista de baile y bola de discoteca
	for x = 1, 7 do
		for z = 1, 7 do
			C.Parte({
				Name = "Baldosa",
				Size = Vector3.new(3.85, 0.4, 3.85),
				CFrame = CFrame.new(L + Vector3.new((x - 4) * 4, 0, (z - 4) * 4)),
				Color = Util.Elegir(Config.COLORES),
				Material = Enum.Material.Neon,
				Tags = { "Disco" },
				Parent = carpeta,
			})
		end
	end
	local bola = C.Bola(L + Vector3.new(0, 26, 0), 7, {
		Name = "BolaDisco",
		Color = Color3.fromRGB(230, 230, 255),
		Material = Enum.Material.Foil,
		Reflectance = 0.6,
		CanCollide = false,
		Tags = { "Girar" },
		Parent = carpeta,
	})
	C.Luz(bola, Color3.fromRGB(255, 120, 255), 3, 40)
	C.Motor(bola, 1.5)

	-- Cartel gigante del título
	local tablero = C.Parte({
		Name = "Titulo",
		Size = Vector3.new(66, 18, 2),
		CFrame = CFrame.new(L + Vector3.new(0, 28, -62)) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(30, 20, 50),
		Parent = carpeta,
	})
	local titulo = C.Cartel(tablero, Enum.NormalId.Front, Config.NOMBRE, BLANCO, 20)
	local degradado = Instance.new("UIGradient")
	degradado.Color = arcoiris()
	degradado.Parent = titulo
	local subtitulo = C.Parte({
		Name = "Subtitulo",
		Size = Vector3.new(50, 5, 1),
		CFrame = CFrame.new(L + Vector3.new(0, 16, -61)) * CFrame.Angles(0, math.pi, 0),
		Color = ROJO,
		Material = Enum.Material.Neon,
		Parent = carpeta,
	})
	C.Cartel(subtitulo, Enum.NormalId.Front, "8 JUGADORES · 13 MINIJUEGOS · 0 PIEDAD", BLANCO, 20)
	for _, x in { -30, 30 } do
		C.Parte({
			Name = "Poste",
			Size = Vector3.new(2, 38, 2),
			CFrame = CFrame.new(L + Vector3.new(x, 19, -63)),
			Color = Color3.fromRGB(60, 40, 90),
			Parent = carpeta,
		})
	end

	cartelDePie(
		"ComoSeJuega",
		L + Vector3.new(-52, 9, -22),
		Vector2.new(26, 16),
		"¿CÓMO SE JUEGA?\n\n🗳️ Vota el minijuego pisando una plataforma\n🎰 La ruleta elige un MODO LOCO\n🏃 ¡Sobrevive, empuja y corre!\n🏆 Ganas puntos según tu puesto\n👑 Tras 6 rondas: ¡CAMPEÓN!",
		Color3.fromRGB(255, 221, 89),
		carpeta
	)
	cartelDePie(
		"Trucos",
		L + Vector3.new(52, 9, -22),
		Vector2.new(26, 16),
		"TRUCOS\n\n🦘 Trampolines rosas: ¡a volar!\n🚀 Cañón: lleva a la isla secreta\n🔨 Martillo: haz clic para empujar\n❓ Cajas: poderes sorpresa\n🔴 El botón rojo... NO LO PULSES",
		CIAN,
		carpeta
	)

	-- Podio de campeones
	local coloresPodio = { DORADO, Color3.fromRGB(200, 205, 215), Color3.fromRGB(205, 127, 50) }
	for i, arriba in Mundo.Podio do
		local alto = arriba.Y - L.Y
		local bloque = C.Parte({
			Name = "Podio" .. i,
			Size = Vector3.new(8, alto, 8),
			CFrame = CFrame.new(arriba - Vector3.new(0, alto / 2, 0)) * CFrame.Angles(0, math.pi, 0),
			Color = coloresPodio[i],
			Parent = carpeta,
		})
		C.Cartel(bloque, Enum.NormalId.Front, tostring(i), BLANCO, 20)
	end

	-- Plataformas de votación
	for i, posicion in POSICIONES_VOTO do
		C.Parte({
			Name = "Voto" .. i,
			Size = Vector3.new(12, 0.6, 12),
			CFrame = CFrame.new(posicion + Vector3.new(0, 0.3, 0)),
			Color = COLORES_VOTO[i],
			Material = Enum.Material.Neon,
			Parent = carpeta,
		})
		local cartel = C.Parte({
			Name = "CartelVoto" .. i,
			Size = Vector3.new(12, 7, 0.6),
			CFrame = CFrame.lookAt(posicion + Vector3.new(0, 6, 7), posicion + Vector3.new(0, 6, 0)),
			Color = OSCURO,
			Parent = carpeta,
		})
		C.Cartel(cartel, Enum.NormalId.Front, "🗳️\nVOTA AQUÍ", COLORES_VOTO[i], 20)
	end

	-- Trampolines
	for i = 0, 3 do
		local angulo = math.rad(i * 90 + 45)
		local centro = L + Vector3.new(math.cos(angulo) * 52, 0, math.sin(angulo) * 52)
		C.Disco(centro + Vector3.new(0, 0.8, 0), 6, 0.8, {
			Name = "BordeTrampolin",
			Color = Color3.fromRGB(30, 30, 30),
			Parent = carpeta,
		})
		local cama = C.Disco(centro + Vector3.new(0, 1.1, 0), 5, 0.4, {
			Name = "Trampolin",
			Color = Color3.fromRGB(255, 107, 203),
			Material = Enum.Material.Neon,
			Tags = { "Impulso" },
			Atributos = { Impulso = Vector3.new(0, 150, 0) },
			Parent = carpeta,
		})
		C.Flotante(cama, "🦘", 3, 3, Vector3.new(0, 4, 0))
	end

	-- Cañón humano e isla secreta
	construirCanon(L + Vector3.new(46, 0, 12), 1, carpeta)
	construirIsla(ISLA_SECRETA, 26, carpeta)
	C.Parte({
		Name = "Pedestal",
		Size = Vector3.new(6, 4, 6),
		CFrame = CFrame.new(ISLA_SECRETA + Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Marble,
		Parent = carpeta,
	})
	local corona = C.Disco(ISLA_SECRETA + Vector3.new(0, 7, 0), 3, 3, {
		Name = "CoronaSecreta",
		Color = DORADO,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Tags = { "Girar" },
		Parent = carpeta,
	})
	C.Luz(corona, DORADO, 4, 30)
	C.Flotante(corona, "🏝️ ¡ENCONTRASTE LA ISLA SECRETA!", 2, 14, Vector3.new(0, 6, 0), Color3.fromRGB(255, 221, 89))
	C.Motor(corona, 1)
	construirCanon(ISLA_SECRETA + Vector3.new(-14, 0, 0), -1, carpeta)

	-- Botón rojo "NO PULSAR"
	local pedestal = C.Parte({
		Name = "PedestalBoton",
		Size = Vector3.new(5, 3, 5),
		CFrame = CFrame.new(L + Vector3.new(-46, 1.5, 12)),
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Metal,
		Parent = carpeta,
	})
	local boton = C.Disco(pedestal.Position + Vector3.new(0, 2.2, 0), 2, 0.8, {
		Name = "BotonRojo",
		Color = Color3.fromRGB(255, 30, 30),
		Material = Enum.Material.Neon,
		Parent = carpeta,
	})
	C.Flotante(boton, "⚠️ NO PULSAR ⚠️", 2, 10, Vector3.new(0, 4, 0), ROJO)
	local aviso = Instance.new("ProximityPrompt")
	aviso.Name = "Pulsar"
	aviso.ActionText = "¡NO PULSAR!"
	aviso.ObjectText = "Botón rojo"
	aviso.HoldDuration = 0.5
	aviso.MaxActivationDistance = 10
	aviso.RequiresLineOfSight = false
	aviso.Parent = boton

	-- Decoración: pilares de neón y dados gigantes que giran
	for i = 1, 8 do
		local angulo = math.rad((i - 1) * 45)
		local pilar = C.Parte({
			Name = "Pilar",
			Size = Vector3.new(2.5, 14, 2.5),
			CFrame = CFrame.new(L + Vector3.new(math.cos(angulo) * 70, 7, math.sin(angulo) * 70)),
			Color = Config.COLORES[i],
			Material = Enum.Material.Neon,
			Parent = carpeta,
		})
		C.Luz(pilar, Config.COLORES[i], 2, 20)
	end
	for i = 1, 6 do
		local angulo = math.rad(i * 60 + 15)
		local radio = 40 + (i % 2) * 15
		local dado = C.Parte({
			Name = "DadoLoco",
			Size = Vector3.new(5, 5, 5),
			CFrame = CFrame.new(L + Vector3.new(math.cos(angulo) * radio, 22 + (i % 3) * 6, math.sin(angulo) * radio))
				* CFrame.Angles(math.rad(45), math.rad(i * 20), 0),
			Color = Config.COLORES[(i % #Config.COLORES) + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
			Tags = { "Girar" },
			Parent = carpeta,
		})
		C.Motor(dado, 0.6 + i * 0.15)
	end

	carpeta.Parent = workspace
end

-- Botón rojo: eventos locos para los que están en el lobby.
local ultimoBoton = -math.huge

local function enElLobby(): { Player }
	local lista = {}
	for _, jugador in Players:GetPlayers() do
		local raiz = Jugadores.Raiz(jugador)
		if raiz and not Jugadores.EnRonda[jugador] and (raiz.Position - L).Magnitude < 160 then
			table.insert(lista, jugador)
		end
	end
	return lista
end

local EVENTOS_BOTON: { { Nombre: string, Hacer: () -> () } } = {
	{
		Nombre = "🚀 ¡DESPEGUE!",
		Hacer = function()
			for _, jugador in enElLobby() do
				Efectos.Empujar(jugador, Vector3.new(math.random(-20, 20), 160, math.random(-20, 20)), 1.4)
			end
		end,
	},
	{
		Nombre = "🏀 ¡LLUVIA DE PELOTAS!",
		Hacer = function()
			for _ = 1, 40 do
				local bola = C.Bola(
					Util.PuntoEnCirculo(L, 50) + Vector3.new(0, math.random(60, 90), 0),
					math.random(3, 6),
					{
						Name = "Pelota",
						Color = Util.Elegir(Config.COLORES),
						Anchored = false,
						CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.9, 1, 100),
						Parent = workspace,
					}
				)
				Debris:AddItem(bola, 14)
			end
		end,
	},
	{
		Nombre = "🐜 ¡TODOS MINI!",
		Hacer = function()
			for _, jugador in enElLobby() do
				local personaje = jugador.Character
				if personaje then
					pcall(function()
						personaje:ScaleTo(0.5)
					end)
					task.delay(15, function()
						if personaje.Parent and not Jugadores.EnRonda[jugador] then
							pcall(function()
								personaje:ScaleTo(1)
							end)
						end
					end)
				end
			end
		end,
	},
	{
		Nombre = "🎆 ¡FIESTA!",
		Hacer = function()
			for _ = 1, 12 do
				Efectos.FuegoArtificial(Util.PuntoEnCirculo(L, 60))
				task.wait(0.25)
			end
		end,
	},
	{
		Nombre = "🌪️ ¡TORNADO!",
		Hacer = function()
			for _, jugador in enElLobby() do
				local raiz = Jugadores.Raiz(jugador)
				if raiz then
					local radial = Util.Direccion(L, raiz.Position)
					Efectos.Empujar(jugador, Vector3.new(-radial.Z, 0, radial.X) * 80 + Vector3.new(0, 60, 0), 1.2)
				end
			end
		end,
	},
	{
		Nombre = "🦘 ¡SÚPER SALTOS!",
		Hacer = function()
			for _, jugador in enElLobby() do
				local humanoide = Jugadores.Humanoide(jugador)
				if humanoide then
					humanoide.JumpPower = 110
					task.delay(15, function()
						if humanoide.Parent and not Jugadores.EnRonda[jugador] then
							humanoide.JumpPower = Config.SALTO
						end
					end)
				end
			end
		end,
	},
}

function Lobby.Conectar()
	local carpeta = workspace:FindFirstChild("Lobby")
	if not carpeta then
		return
	end
	for _, parte in CollectionService:GetTagged("Girar") do
		if parte:IsA("BasePart") and not parte.Anchored then
			pcall(function()
				parte:SetNetworkOwner(nil)
			end)
		end
	end

	-- Pista de baile: cambia de color al ritmo.
	task.spawn(function()
		while true do
			for _, baldosa in CollectionService:GetTagged("Disco") do
				if baldosa:IsA("BasePart") then
					baldosa.Color = Util.Elegir(Config.COLORES)
				end
			end
			task.wait(0.45)
		end
	end)

	local boton = carpeta:FindFirstChild("BotonRojo", true)
	local aviso = if boton then boton:FindFirstChildOfClass("ProximityPrompt") else nil
	if aviso then
		aviso.Triggered:Connect(function(jugador: Player)
			local ahora = os.clock()
			if ahora - ultimoBoton < Config.BOTON_ROJO_ESPERA then
				UI.Anuncio("⏳ El botón se está recargando...", { Color = NARANJA, Duracion = 1.5 }, jugador)
				return
			end
			ultimoBoton = ahora
			local evento = Util.Elegir(EVENTOS_BOTON)
			UI.Anuncio(`🔴 ¡{jugador.DisplayName} PULSÓ EL BOTÓN!`, { Subtitulo = evento.Nombre, Color = ROJO, Duracion = 3 })
			UI.Feed(`🔴 {jugador.DisplayName} pulsó el botón rojo: {evento.Nombre}`)
			task.spawn(evento.Hacer)
		end)
	end
end

-- =====================================================================
-- 🗳️ VOTACIÓN: pisa una plataforma del lobby para elegir el minijuego
-- =====================================================================

local Votacion = {}

local function plataformaVoto(i: number): BasePart?
	local carpeta = workspace:FindFirstChild("Lobby")
	local parte = if carpeta then carpeta:FindFirstChild("Voto" .. i, true) else nil
	return if parte and parte:IsA("BasePart") then parte else nil
end

local function cartelVoto(i: number): TextLabel?
	local carpeta = workspace:FindFirstChild("Lobby")
	local parte = if carpeta then carpeta:FindFirstChild("CartelVoto" .. i, true) else nil
	local gui = if parte then parte:FindFirstChildOfClass("SurfaceGui") else nil
	local etiqueta = if gui then gui:FindFirstChildOfClass("TextLabel") else nil
	return etiqueta
end

function Votacion.Contar(): { number }
	local votos = { 0, 0, 0 }
	for _, jugador in Players:GetPlayers() do
		local raiz = Jugadores.Raiz(jugador)
		if raiz and not Jugadores.EnRonda[jugador] then
			for i = 1, 3 do
				local plataforma = plataformaVoto(i)
				if plataforma then
					local local_ = plataforma.CFrame:PointToObjectSpace(raiz.Position)
					local mitad = plataforma.Size / 2
					if math.abs(local_.X) <= mitad.X + 0.5 and math.abs(local_.Z) <= mitad.Z + 0.5 and local_.Y > -1 and local_.Y < 10 then
						votos[i] += 1
						break
					end
				end
			end
		end
	end
	return votos
end

function Votacion.Mostrar(opciones: { Minijuego }, votos: { number }?)
	for i = 1, 3 do
		local etiqueta = cartelVoto(i)
		local m = opciones[i]
		if etiqueta and m then
			local v = if votos then votos[i] else 0
			etiqueta.Text = `{m.Emoji}\n{m.Nombre}\n🗳️ {v}`
		end
	end
end

function Votacion.Ocultar(ganador: number?)
	for i = 1, 3 do
		local etiqueta = cartelVoto(i)
		if etiqueta then
			if i == ganador then
				etiqueta.Text = "🏆\n¡GANADOR!"
			else
				etiqueta.Text = "🗳️\nVOTA AQUÍ"
			end
		end
	end
end

-- =====================================================================
-- 👀 GRADA: desde aquí los eliminados ven el resto de la ronda
-- =====================================================================

local Grada = {}

function Grada.Construir()
	local P = Config.GRADA
	local LARGO_GRADA = 150
	if not workspace:FindFirstChild("Grada") then
		local carpeta = Instance.new("Folder")
		carpeta.Name = "Grada"
		C.Parte({
			Name = "Suelo",
			Size = Vector3.new(24, 2, LARGO_GRADA),
			CFrame = CFrame.new(P - Vector3.new(0, 1, 0)),
			Color = Color3.fromRGB(60, 60, 90),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Parent = carpeta,
		})
		-- Barandilla de cristal mirando a la arena (+X)
		C.Parte({
			Name = "Barandilla",
			Size = Vector3.new(1, 5, LARGO_GRADA),
			CFrame = CFrame.new(P + Vector3.new(12.5, 2.5, 0)),
			Color = Color3.fromRGB(150, 220, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.6,
			Parent = carpeta,
		})
		-- Paredes y techo invisibles (para no caerse a la arena ni con súper salto)
		for _, def in {
			{ Vector3.new(12.5, 30, 0), Vector3.new(1, 60, LARGO_GRADA) },
			{ Vector3.new(-12.5, 30, 0), Vector3.new(1, 60, LARGO_GRADA) },
			{ Vector3.new(0, 30, LARGO_GRADA / 2), Vector3.new(26, 60, 1) },
			{ Vector3.new(0, 30, -LARGO_GRADA / 2), Vector3.new(26, 60, 1) },
			{ Vector3.new(0, 60, 0), Vector3.new(26, 1, LARGO_GRADA) },
		} do
			C.Parte({
				Name = "Invisible",
				Size = def[2],
				CFrame = CFrame.new(P + def[1]),
				Transparency = 1,
				Parent = carpeta,
			})
		end
		-- Bancos
		for z = -60, 60, 20 do
			C.Parte({
				Name = "Banco",
				Size = Vector3.new(3, 1.5, 14),
				CFrame = CFrame.new(P + Vector3.new(-8, 0.75, z)),
				Color = Util.Elegir(Config.COLORES),
				Parent = carpeta,
			})
		end
		local cartel = C.Parte({
			Name = "Cartel",
			Size = Vector3.new(1, 8, 40),
			CFrame = CFrame.new(P + Vector3.new(-11.5, 10, 0)),
			Color = OSCURO,
			Parent = carpeta,
		})
		C.Cartel(cartel, Enum.NormalId.Right, "👀 GRADA DE ESPECTADORES 👀", Color3.fromRGB(255, 221, 89), 20)
		carpeta.Parent = workspace
	end

	table.clear(Mundo.Grada)
	for z = -60, 60, 12 do
		local posicion = P + Vector3.new(-2, 0, z)
		table.insert(Mundo.Grada, CFrame.lookAt(posicion, posicion + Vector3.new(1, 0, 0)))
	end
end

-- =====================================================================
-- 🔁 EL BUCLE DEL JUEGO
-- votar → ruleta del modo loco → minijuego → resultados → ... → ¡CAMPEÓN!
-- =====================================================================

local Juego = {}

local bolsa: { Minijuego } = {}
local ultimoMinijuego: Minijuego? = nil

local function minimoJugadores(): number
	return if RunService:IsStudio() then 1 else Config.MIN_JUGADORES
end

-- 3 opciones para votar. La primera es la que más tiempo lleva sin salir.
local function sacarOpciones(): { Minijuego }
	if #bolsa < 4 then
		for _, m in Util.Mezclar(table.clone(MINIJUEGOS)) do
			if not table.find(bolsa, m) then
				table.insert(bolsa, m)
			end
		end
	end
	local opciones = {}
	for _, m in bolsa do
		if m ~= ultimoMinijuego and #opciones < 3 then
			table.insert(opciones, m)
		end
	end
	return opciones
end

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
				UI.Anuncio("🧪 MODO PRÁCTICA", { Subtitulo = "¡Invita a tus amigos para jugar de verdad!", Duracion = 3 })
				return
			end
			UI.Estado({ Fase = "espera", Texto = `⏳ Esperando locos ({listos}/{minimo}) · práctica en {math.ceil(falta)}` })
		else
			soloDesde = nil
		end
		task.wait(1)
	end
end

local function votar(numero: number, dobles: boolean): Minijuego
	local opciones = sacarOpciones()
	local orden = Util.Mezclar(table.clone(opciones))
	Votacion.Mostrar(orden)
	UI.Anuncio("🗳️ ¡A VOTAR!", {
		Subtitulo = "Pisa la plataforma del minijuego que quieras jugar",
		Color = CIAN,
		Duracion = 3,
	})
	local segundos = if RunService:IsStudio() then Config.TIEMPO_VOTACION_STUDIO else Config.TIEMPO_VOTACION
	local votos = { 0, 0, 0 }
	for s = segundos, 1, -1 do
		votos = Votacion.Contar()
		Votacion.Mostrar(orden, votos)
		local resumen = {}
		for i, m in orden do
			table.insert(resumen, `{m.Emoji} {votos[i]}`)
		end
		UI.Estado({
			Fase = "votacion",
			Texto = `🗳️ Ronda {numero}/{Config.RONDAS_POR_PARTIDA}: ¡vota pisando una plataforma!`,
			Tiempo = s,
			Info = table.concat(resumen, "  ·  "),
			Dobles = dobles,
		})
		task.wait(1)
	end
	votos = Votacion.Contar()

	local maximo = math.max(votos[1], votos[2], votos[3])
	local elegido = opciones[1]
	local indiceGanador = table.find(orden, elegido)
	if maximo > 0 then
		local empatados = {}
		for i = 1, #orden do
			if votos[i] == maximo then
				table.insert(empatados, i)
			end
		end
		local ganador = Util.Elegir(empatados)
		indiceGanador = ganador
		elegido = orden[ganador]
	end
	Votacion.Ocultar(indiceGanador)
	local posicion = table.find(bolsa, elegido)
	if posicion then
		table.remove(bolsa, posicion)
	end
	ultimoMinijuego = elegido
	UI.Anuncio(`{elegido.Emoji} {elegido.Nombre}`, {
		Subtitulo = if maximo > 0 then `🗳️ ¡Ganó la votación con {maximo} voto(s)!` else "🤷 Nadie votó... ¡elijo yo!",
		Color = DORADO,
		Duracion = 2.5,
	})
	task.wait(2.5)
	return elegido
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

-- Los que están en la grada (o perdidos lejos del lobby) vuelven al lobby.
local function traerAlLobby()
	for _, jugador in Players:GetPlayers() do
		local raiz = Jugadores.Raiz(jugador)
		if not Jugadores.EnRonda[jugador] and raiz and (raiz.Position - L).Magnitude > 250 then
			Jugadores.Reaparecer(jugador)
		end
	end
end

local function jugarRonda(numero: number, minijuego: Minijuego, dobles: boolean): boolean
	-- 🎰 Ruleta del modo loco
	local modificador = Modificadores.Elegir(numero)
	local nombresModo = {}
	for _, m in Modificadores.Lista do
		table.insert(nombresModo, `{m.Emoji} {m.Nombre}`)
	end
	UI.Estado({ Fase = "ruleta", Texto = `{minijuego.Emoji} {minijuego.Nombre}: ¡girando la ruleta!`, Dobles = dobles })
	UI.Ruleta("🌀 MODO LOCO", nombresModo, Modificadores.Indice(modificador), 3)
	if modificador.Id ~= "Normal" then
		UI.Anuncio(`{modificador.Emoji} {modificador.Nombre}`, {
			Subtitulo = modificador.Descripcion,
			Color = MORADO,
			Duracion = 2.5,
		})
		task.wait(2.5)
	end

	local participantes = Jugadores.Listos()
	if #participantes == 0 then
		return false
	end

	-- 🏗️ Construir la arena y llevar a todos
	local ronda = Ronda.new(minijuego, modificador, participantes, dobles)
	UI.Estado({ Fase = "preparando", Texto = `{minijuego.Emoji} Preparando {minijuego.Nombre}...`, Dobles = dobles })
	ronda:Construir()
	Modificadores.AplicarMundo(modificador)
	ronda:Preparar()

	UI.Anuncio(`{minijuego.Emoji} {minijuego.Nombre}`, { Subtitulo = minijuego.Descripcion, Color = DORADO, Duracion = 4.5 })
	UI.Estado({
		Fase = "preparando",
		Texto = `{minijuego.Emoji} {minijuego.Nombre}`,
		Modo = `{modificador.Emoji} {modificador.Nombre}`,
		Dobles = dobles,
	})
	task.wait(5)
	for i = 3, 1, -1 do
		UI.Anuncio(tostring(i), { Duracion = 0.9, Cuenta = true })
		task.wait(1)
	end
	UI.Anuncio("¡YA!", { Duracion = 1, Color = VERDE, Cuenta = true, Final = true })
	ronda:Iniciar()
	if Config.CAJAS_SORPRESA and minijuego.Cajas then
		Poderes.Iniciar(ronda, minijuego.Cajas)
	end

	-- ⏱️ A jugar hasta que se acabe el tiempo o el minijuego termine
	local fin = os.clock() + minijuego.Duracion
	while not ronda.Terminada do
		local restante = fin - os.clock()
		if restante <= 0 then
			break
		end
		ronda.TiempoRestante = math.ceil(restante)
		UI.Estado(ronda:Estado("ronda"))
		task.wait(0.25)
	end
	local porTiempo = not ronda.Terminada
	ronda.TiempoRestante = 0
	ronda:Detener()
	UI.Anuncio(if porTiempo then "⏰ ¡TIEMPO!" else "🏁 ¡FIN!", { Duracion = 2, Color = NARANJA })
	UI.Estado(ronda:Estado("fin"))
	task.wait(2)

	-- 🏆 Resultados y puntos
	local filas = ronda:Ranking()
	local datosFilas: { FilaResultado } = {}
	local ganadores = {}
	for _, fila in filas do
		local puntos = (Config.PUNTOS_POR_PUESTO[fila.Puesto] or 1) * (if dobles then 2 else 1)
		Jugadores.SumarPuntos(fila.Jugador, puntos)
		Jugadores.Sumar(fila.Jugador, "XP", puntos)
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
			Jugadores.Sumar(fila.Jugador, "Victorias", 1)
			local raiz = Jugadores.Raiz(fila.Jugador)
			if raiz then
				Efectos.Confeti(raiz.Position + Vector3.new(0, 5, 0), 120)
			end
		end
	end
	if #ganadores > 0 then
		UI.Anuncio(`🏆 ¡{table.concat(ganadores, " y ")} gana!`, { Color = DORADO, Duracion = 3 })
	end
	UI.Resultados(`{minijuego.Emoji} {minijuego.Nombre}`, datosFilas, Config.TIEMPO_RESULTADOS)
	UI.Estado({ Fase = "resultados", Texto = "📊 Resultados de la ronda", Dobles = dobles })
	task.wait(Config.TIEMPO_RESULTADOS)

	-- 🧹 Volver al lobby
	Modificadores.QuitarMundo()
	ronda:Limpiar()
	traerAlLobby()
	return true
end

local PREMIOS = {
	{ Titulo = "🔨 Rey del Martillo", Campo = "Martillazos", Unidad = "martillazos" },
	{ Titulo = "💥 Terminator", Campo = "Mandados", Unidad = "eliminados" },
	{ Titulo = "🚀 Piloto de Pruebas", Campo = "Vuelos", Unidad = "vuelos" },
	{ Titulo = "🎁 Cazacajas", Campo = "Cajas", Unidad = "cajas" },
}

-- 👑 Ceremonia final: podio, coronas, premios y fuegos artificiales.
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
		Jugadores.Sumar(jugador, "Partidas", 1)
		if Jugadores.Puntos(jugador) == maximo and maximo > 0 then
			table.insert(campeones, jugador.DisplayName)
			Jugadores.Sumar(jugador, "Coronas", 1)
		end
	end
	if #campeones == 0 then
		Jugadores.ReiniciarPuntos()
		return
	end

	UI.Estado({ Fase = "ceremonia", Texto = "👑 ¡CEREMONIA DE CAMPEONES! 👑" })
	task.wait(1.5) -- que todos terminen de aparecer en el lobby

	for i = 1, math.min(3, #lista) do
		local jugador = lista[i]
		local personaje = jugador.Character
		local arriba = Mundo.Podio[i]
		if personaje and arriba then
			personaje:PivotTo(CFrame.lookAt(arriba + Vector3.new(0, 3.5, 0), arriba + Vector3.new(0, 3.5, 10)))
			local humanoide = Jugadores.Humanoide(jugador)
			if humanoide then
				humanoide.WalkSpeed = 0
				humanoide.JumpPower = 0
				task.delay(Config.TIEMPO_CEREMONIA - 2, function()
					if humanoide.Parent then
						humanoide.WalkSpeed = Config.VELOCIDAD
						humanoide.JumpPower = Config.SALTO
					end
				end)
			end
		end
	end

	UI.Anuncio(`👑 ¡{table.concat(campeones, " y ")}: CAMPEÓN! 👑`, {
		Subtitulo = `{maximo} puntos · ¡Ganas una CORONA!`,
		Color = DORADO,
		Duracion = 5,
	})
	UI.Feed(`👑 {table.concat(campeones, " y ")} gana la partida con {maximo} puntos`)

	task.spawn(function()
		local fin = os.clock() + Config.TIEMPO_CEREMONIA
		while os.clock() < fin do
			Efectos.FuegoArtificial(Mundo.Podio[1] + Vector3.new(math.random(-30, 30), 0, math.random(-12, 12)))
			task.wait(0.4)
		end
	end)

	-- Premios divertidos de la partida
	task.wait(5)
	for _, premio in PREMIOS do
		local mejor: Player? = nil
		local mejorValor = 0
		for _, jugador in Players:GetPlayers() do
			local stats = Jugadores.Stats[jugador]
			local valorStat = if stats then (stats :: any)[premio.Campo] else 0
			if valorStat > mejorValor then
				mejor, mejorValor = jugador, valorStat
			end
		end
		if mejor then
			UI.Anuncio(premio.Titulo, { Subtitulo = `{mejor.DisplayName} · {mejorValor} {premio.Unidad}`, Color = NARANJA, Duracion = 2 })
			UI.Feed(`🏅 {premio.Titulo}: {mejor.DisplayName} ({mejorValor} {premio.Unidad})`)
			task.wait(2.2)
		end
	end
	task.wait(1)

	for _, jugador in Players:GetPlayers() do
		task.spawn(Jugadores.Guardar, jugador)
	end
	Jugadores.ReiniciarPuntos()
end

local function bucle()
	while true do
		esperarJugadores()
		Jugadores.ReiniciarStats()
		local jugadas = 0
		for numero = 1, Config.RONDAS_POR_PARTIDA do
			if #Players:GetPlayers() == 0 then
				break
			end
			local dobles = Config.ULTIMA_RONDA_DOBLE and numero == Config.RONDAS_POR_PARTIDA
			if dobles then
				UI.Anuncio("🔥 ¡ÚLTIMA RONDA!", { Subtitulo = "¡Esta ronda vale PUNTOS DOBLES!", Color = ROJO, Duracion = 3 })
				task.wait(3)
			end
			local ok, resultado = pcall(function()
				local minijuego = votar(numero, dobles)
				return jugarRonda(numero, minijuego, dobles)
			end)
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

-- =====================================================================
-- 🚀 ¡ARRANCAMOS!
-- =====================================================================

limpiarPlantilla()
Lobby.Construir()
Lobby.Conectar()
Grada.Construir()
Impulsos.Iniciar()
Jugadores.Iniciar()
UI.IniciarConsejos()
Juego.Iniciar()

print(`🤪 {Config.NOMBRE} está listo: {#MINIJUEGOS} minijuegos y {#Modificadores.Lista} modos locos. ¡Que empiece la locura!`)
