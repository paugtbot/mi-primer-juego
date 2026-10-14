--!strict
-- 🖥️ LA INTERFAZ: barra de estado, ruleta, anuncios gigantes, mensajes,
-- resultados, marcador, botón de espectar y confeti. Todo hecho con código.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Compartido"):WaitForChild("Config"))

local jugador = Players.LocalPlayer

local Interfaz = {}

local FUENTE = Enum.Font.FredokaOne
local OSCURO = Color3.fromRGB(20, 18, 36)
local BLANCO = Color3.new(1, 1, 1)
local DORADO = Color3.fromRGB(255, 205, 40)
local ROJO = Color3.fromRGB(255, 71, 87)

local SONIDO_PIP = "rbxasset://sounds/electronicpingshort.wav"

-- ===== Ayudantes =====

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
	local base = {
		BackgroundTransparency = 1,
		Font = FUENTE,
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

local function sonar(id: string, volumen: number?, velocidad: number?)
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Volume = volumen or 0.5
	sonido.PlaybackSpeed = velocidad or 1
	sonido.Parent = SoundService
	sonido:Play()
	Debris:AddItem(sonido, 4)
end

local function formatoTiempo(segundos: number): string
	local s = math.max(0, math.floor(segundos))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- ===== Elementos =====

local gui: ScreenGui
local barra: Frame
local bordeBarra: UIStroke
local textoEstado: TextLabel
local textoTiempo: TextLabel
local pildoraModo: TextLabel
local pildoraVivos: TextLabel
local anuncio: TextLabel
local escalaAnuncio: UIScale
local subtitulo: TextLabel
local ruleta: Frame
local tituloRuleta: TextLabel
local opcionRuleta: TextLabel
local escalaRuleta: UIScale
local feed: Frame
local resultados: Frame
local tituloResultados: TextLabel
local listaResultados: Frame
local escalaResultados: UIScale
local marcador: Frame
local filasMarcador: { TextLabel } = {}
local tituloMarcador: TextLabel
local panelEspectar: Frame
local nombreEspectar: TextLabel
local capaConfeti: Frame

local function crearBarra()
	barra = crear("Frame", {
		Name = "Barra",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.5, 0, 0, 54),
		BackgroundColor3 = OSCURO,
		BackgroundTransparency = 0.1,
	}, gui)
	crear("UISizeConstraint", { MinSize = Vector2.new(300, 54), MaxSize = Vector2.new(600, 54) }, barra)
	redondear(barra, 14)
	bordeBarra = borde(barra, Config.COLORES[1], 3)

	textoEstado = texto({
		Name = "Estado",
		Position = UDim2.new(0, 14, 0, 6),
		Size = UDim2.new(1, -120, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🤪 LOCURA TOTAL",
	}, barra)
	limiteTexto(textoEstado, 26)

	textoTiempo = texto({
		Name = "Tiempo",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 4),
		Size = UDim2.new(0, 96, 1, -8),
		TextColor3 = DORADO,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, barra)
	limiteTexto(textoTiempo, 34)

	local fila = crear("Frame", {
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
	pildoraModo = pildora("Modo", Color3.fromRGB(165, 94, 234), 1)
	pildoraVivos = pildora("Vivos", Color3.fromRGB(30, 144, 255), 2)
end

local function crearAnuncio()
	anuncio = texto({
		Name = "Anuncio",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.26, 0),
		Size = UDim2.new(0.9, 0, 0.14, 0),
		TextStrokeTransparency = 0,
		TextTransparency = 1,
		ZIndex = 5,
	}, gui)
	limiteTexto(anuncio, 96)
	escalaAnuncio = crear("UIScale", { Scale = 1 }, anuncio)

	subtitulo = texto({
		Name = "Subtitulo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.34, 0),
		Size = UDim2.new(0.7, 0, 0.09, 0),
		TextWrapped = true,
		TextStrokeTransparency = 0,
		TextTransparency = 1,
		ZIndex = 5,
	}, gui)
	limiteTexto(subtitulo, 34)
end

local function crearRuleta()
	ruleta = crear("Frame", {
		Name = "Ruleta",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.52, 0),
		Size = UDim2.new(0.5, 0, 0, 200),
		BackgroundColor3 = OSCURO,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 4,
	}, gui)
	crear("UISizeConstraint", { MinSize = Vector2.new(320, 200), MaxSize = Vector2.new(640, 200) }, ruleta)
	redondear(ruleta, 20)
	borde(ruleta, DORADO, 4)
	escalaRuleta = crear("UIScale", { Scale = 1 }, ruleta)

	tituloRuleta = texto({
		Name = "Titulo",
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(1, -20, 0, 44),
		TextColor3 = DORADO,
		ZIndex = 4,
	}, ruleta)

	local caja = crear("Frame", {
		Name = "Caja",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.new(1, -40, 0, 112),
		BackgroundColor3 = BLANCO,
		BackgroundTransparency = 0.88,
		ZIndex = 4,
	}, ruleta)
	redondear(caja, 14)

	opcionRuleta = texto({
		Name = "Opcion",
		Position = UDim2.new(0, 40, 0, 8),
		Size = UDim2.new(1, -80, 1, -16),
		ZIndex = 5,
	}, caja)
	crear("UIScale", { Scale = 1 }, opcionRuleta)

	texto({ Text = "▶", Position = UDim2.new(0, 6, 0.5, -16), Size = UDim2.new(0, 28, 0, 32), TextColor3 = ROJO, ZIndex = 5 }, caja)
	texto({ Text = "◀", Position = UDim2.new(1, -34, 0.5, -16), Size = UDim2.new(0, 28, 0, 32), TextColor3 = ROJO, ZIndex = 5 }, caja)
end

local function crearFeed()
	feed = crear("Frame", {
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
end

local function crearResultados()
	resultados = crear("Frame", {
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
	escalaResultados = crear("UIScale", { Scale = 1 }, resultados)

	tituloResultados = texto({
		Name = "Titulo",
		Position = UDim2.new(0, 12, 0.02, 0),
		Size = UDim2.new(1, -24, 0.11, 0),
		TextColor3 = DORADO,
		ZIndex = 6,
	}, resultados)

	listaResultados = crear("Frame", {
		Name = "Lista",
		Position = UDim2.new(0, 14, 0.15, 0),
		Size = UDim2.new(1, -28, 0.83, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, resultados)
	crear("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, listaResultados)
end

local function crearMarcador()
	marcador = crear("Frame", {
		Name = "Marcador",
		Position = UDim2.new(0, 10, 0, 110),
		Size = UDim2.new(0, 230, 0, 40 + 8 * 26),
		BackgroundColor3 = OSCURO,
		BackgroundTransparency = 0.2,
		Visible = false,
	}, gui)
	redondear(marcador, 12)
	tituloMarcador = texto({
		Name = "Titulo",
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -16, 0, 30),
		TextColor3 = DORADO,
		Text = "👑 MARCADOR",
	}, marcador)
	for i = 1, 8 do
		local fila = texto({
			Name = "Fila" .. i,
			Position = UDim2.new(0, 10, 0, 36 + (i - 1) * 26),
			Size = UDim2.new(1, -20, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = false,
		}, marcador)
		table.insert(filasMarcador, fila)
	end
end

-- ===== Espectar =====

local faseActual = ""
local vivosIds: { number } = {}
local espectandoId: number? = nil

local function camaraAMi()
	local personaje = jugador.Character
	local humanoide = if personaje then personaje:FindFirstChildOfClass("Humanoid") else nil
	local camara = workspace.CurrentCamera
	if humanoide and camara then
		camara.CameraSubject = humanoide
	end
end

local function espectar(id: number)
	local otro = Players:GetPlayerByUserId(id)
	local personaje = if otro then otro.Character else nil
	local humanoide = if personaje then personaje:FindFirstChildOfClass("Humanoid") else nil
	local camara = workspace.CurrentCamera
	if otro and humanoide and camara then
		camara.CameraSubject = humanoide
		espectandoId = id
		nombreEspectar.Text = "👀 " .. otro.DisplayName
	end
end

local function siguienteEspectar()
	if #vivosIds == 0 then
		return
	end
	local actual = if espectandoId then table.find(vivosIds, espectandoId) or 0 else 0
	espectar(vivosIds[(actual % #vivosIds) + 1])
end

local function dejarDeEspectar()
	espectandoId = nil
	nombreEspectar.Text = "¿Ver la ronda?"
	camaraAMi()
end

local function actualizarEspectar()
	local puede = faseActual == "ronda" and #vivosIds > 0 and table.find(vivosIds, jugador.UserId) == nil
	panelEspectar.Visible = puede
	if not puede then
		if espectandoId then
			dejarDeEspectar()
		end
	elseif espectandoId and table.find(vivosIds, espectandoId) == nil then
		siguienteEspectar()
	end
end

local function crearEspectar()
	panelEspectar = crear("Frame", {
		Name = "Espectar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0, 340, 0, 56),
		BackgroundColor3 = OSCURO,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	redondear(panelEspectar, 16)
	borde(panelEspectar, Config.COLORES[8], 3)

	nombreEspectar = texto({
		Name = "Nombre",
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.new(1, -200, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "¿Ver la ronda?",
	}, panelEspectar)
	limiteTexto(nombreEspectar, 22)

	local boton: TextButton = crear("TextButton", {
		Name = "Siguiente",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -60, 0.5, 0),
		Size = UDim2.new(0, 124, 0, 40),
		BackgroundColor3 = Config.COLORES[8],
		Font = FUENTE,
		Text = "👀 ESPECTAR",
		TextColor3 = BLANCO,
		TextScaled = true,
	}, panelEspectar)
	redondear(boton, 12)
	limiteTexto(boton, 20)
	boton.Activated:Connect(siguienteEspectar)

	local cerrar: TextButton = crear("TextButton", {
		Name = "Cerrar",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 40, 0, 40),
		BackgroundColor3 = ROJO,
		Font = FUENTE,
		Text = "✖",
		TextColor3 = BLANCO,
		TextScaled = true,
	}, panelEspectar)
	redondear(cerrar, 12)
	cerrar.Activated:Connect(dejarDeEspectar)

	jugador.CharacterAdded:Connect(function()
		espectandoId = nil
		nombreEspectar.Text = "¿Ver la ronda?"
	end)
end

-- ===== Confeti =====

local function confeti(cantidad: number)
	for _ = 1, cantidad do
		local x = math.random()
		local trozo = crear("Frame", {
			Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
			Position = UDim2.new(x, 0, -0.05, -math.random(0, 200)),
			BackgroundColor3 = Config.COLORES[math.random(1, #Config.COLORES)],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 10,
		}, capaConfeti)
		local duracion = 2 + math.random() * 2.5
		TweenService:Create(trozo, TweenInfo.new(duracion, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(x + (math.random() - 0.5) * 0.25, 0, 1.05, 0),
			Rotation = trozo.Rotation + math.random(-540, 540),
		}):Play()
		Debris:AddItem(trozo, duracion + 0.1)
	end
end

-- ===== API pública =====

function Interfaz.Crear()
	local playerGui = jugador:WaitForChild("PlayerGui")
	gui = crear("ScreenGui", {
		Name = "LocuraUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	crearBarra()
	crearAnuncio()
	crearRuleta()
	crearFeed()
	crearResultados()
	crearMarcador()
	crearEspectar()

	capaConfeti = crear("Frame", {
		Name = "Confeti",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 10,
	}, gui)

	-- Borde de la barra con colores del arcoíris.
	RunService.RenderStepped:Connect(function()
		bordeBarra.Color = Color3.fromHSV((os.clock() * 0.15) % 1, 0.75, 1)
	end)
end

local tokenAnuncio = 0
function Interfaz.Anuncio(mensaje: string, opciones: { [string]: any }?)
	local o: { [string]: any } = opciones or {}
	tokenAnuncio += 1
	local mio = tokenAnuncio

	anuncio.Text = mensaje
	anuncio.TextColor3 = if typeof(o.Color) == "Color3" then o.Color else BLANCO
	anuncio.TextTransparency = 0
	anuncio.TextStrokeTransparency = 0
	subtitulo.Text = if type(o.Subtitulo) == "string" then o.Subtitulo else ""
	subtitulo.TextTransparency = 0
	subtitulo.TextStrokeTransparency = 0

	escalaAnuncio.Scale = 0.3
	TweenService:Create(escalaAnuncio, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	if o.Cuenta then
		sonar(SONIDO_PIP, 0.6, if o.Final then 1.6 else 1)
	end

	local duracion = if type(o.Duracion) == "number" then o.Duracion else 2
	task.delay(duracion, function()
		if tokenAnuncio ~= mio then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(anuncio, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(subtitulo, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

function Interfaz.Estado(datos: { [string]: any })
	faseActual = if type(datos.Fase) == "string" then datos.Fase else ""
	textoEstado.Text = if type(datos.Texto) == "string" then datos.Texto else ""

	local tiempo = datos.Tiempo
	if type(tiempo) == "number" then
		textoTiempo.Text = if faseActual == "intermedio" then tostring(tiempo) else formatoTiempo(tiempo)
		textoTiempo.TextColor3 = if faseActual == "ronda" and tiempo <= 10 then ROJO else DORADO
	else
		textoTiempo.Text = ""
	end

	if type(datos.Modo) == "string" then
		pildoraModo.Text = datos.Modo
		pildoraModo.Visible = true
	else
		pildoraModo.Visible = false
	end

	if type(datos.Llegados) == "number" and type(datos.Total) == "number" then
		pildoraVivos.Text = `🏁 {datos.Llegados} en meta · 🏃 {datos.Vivos or 0} corriendo`
		pildoraVivos.Visible = true
	elseif type(datos.Vivos) == "number" and type(datos.Total) == "number" then
		pildoraVivos.Text = `🧍 {datos.Vivos}/{datos.Total} vivos`
		pildoraVivos.Visible = true
	else
		pildoraVivos.Visible = false
	end

	local lista = datos.Marcador
	if type(lista) == "table" then
		marcador.Visible = true
		local unidad = if type(datos.Unidad) == "string" then datos.Unidad else "pts"
		tituloMarcador.Text = "📈 MARCADOR (" .. unidad .. ")"
		for i, fila in filasMarcador do
			local dato = lista[i]
			if dato then
				fila.Visible = true
				fila.Text = `{i}. {dato.Nombre} — {dato.Puntos}`
				fila.TextColor3 = if dato.Id == jugador.UserId then DORADO else BLANCO
			else
				fila.Visible = false
			end
		end
	else
		marcador.Visible = false
	end

	vivosIds = if type(datos.VivosIds) == "table" then datos.VivosIds else {}
	actualizarEspectar()
end

local tokenRuleta = 0
function Interfaz.Ruleta(datos: { [string]: any })
	tokenRuleta += 1
	local mio = tokenRuleta
	local opciones: { string } = datos.Opciones
	local elegido: number = datos.Elegido
	local duracion: number = datos.Duracion or 3
	local n = #opciones
	if n == 0 then
		return
	end

	ruleta.Visible = true
	tituloRuleta.Text = datos.Titulo or ""
	opcionRuleta.TextColor3 = BLANCO
	escalaRuleta.Scale = 0.5
	TweenService:Create(escalaRuleta, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	local inicio = math.random(1, n)
	local pasos = 3 * n + ((elegido - inicio) % n)
	task.spawn(function()
		local anterior = 0
		for k = 1, pasos do
			if tokenRuleta ~= mio then
				return
			end
			-- Rápido al principio y cada vez más lento.
			local t = duracion * (k / pasos) ^ 3
			task.wait(math.max(0.03, t - anterior))
			anterior = t
			opcionRuleta.Text = opciones[((inicio - 1 + k) % n) + 1]
			sonar(SONIDO_PIP, 0.15, 2)
		end
		if tokenRuleta ~= mio then
			return
		end
		opcionRuleta.Text = opciones[elegido]
		opcionRuleta.TextColor3 = DORADO
		local escalaOpcion = opcionRuleta:FindFirstChildOfClass("UIScale")
		if escalaOpcion then
			escalaOpcion.Scale = 1.35
			TweenService:Create(escalaOpcion, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
		sonar(SONIDO_PIP, 0.7, 1.3)
		task.wait(1.2)
		if tokenRuleta == mio then
			ruleta.Visible = false
		end
	end)
end

function Interfaz.Feed(mensaje: string)
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
		LayoutOrder = math.floor(os.clock() * 100),
	}, feed)
	redondear(etiqueta, 8)
	crear("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}, etiqueta)

	-- Como mucho 6 mensajes a la vez.
	local mensajes = {}
	for _, hijo in feed:GetChildren() do
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
			local info = TweenInfo.new(0.5)
			TweenService:Create(etiqueta, info, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()
			Debris:AddItem(etiqueta, 0.6)
		end
	end)
end

local tokenResultados = 0
function Interfaz.Resultados(datos: { [string]: any })
	tokenResultados += 1
	local mio = tokenResultados

	for _, hijo in listaResultados:GetChildren() do
		if hijo:IsA("Frame") then
			hijo:Destroy()
		end
	end
	tituloResultados.Text = "📊 " .. tostring(datos.Titulo or "Resultados")

	local medallas = { "🥇", "🥈", "🥉" }
	local filas: { any } = datos.Filas or {}
	for i, fila in filas do
		if i > 8 then
			break
		end
		local soyYo = fila.Id == jugador.UserId
		local marco = crear("Frame", {
			Name = "Fila",
			Size = UDim2.new(1, 0, 0.125, -5),
			BackgroundColor3 = if soyYo then Color3.fromRGB(90, 70, 20) else Color3.fromRGB(45, 40, 70),
			LayoutOrder = i,
			ZIndex = 6,
		}, listaResultados)
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
			TextColor3 = Color3.fromRGB(46, 213, 115),
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
	end

	resultados.Visible = true
	escalaResultados.Scale = 0.4
	TweenService:Create(escalaResultados, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	local duracion = if type(datos.Duracion) == "number" then datos.Duracion else 6
	task.delay(duracion, function()
		if tokenResultados == mio then
			resultados.Visible = false
		end
	end)
end

function Interfaz.Campeon(datos: { [string]: any })
	local nombres: { string } = datos.Nombres or {}
	local soyCampeon = table.find(nombres, jugador.DisplayName) ~= nil
	task.spawn(function()
		for _ = 1, 4 do
			confeti(if soyCampeon then 90 else 50)
			task.wait(1.2)
		end
	end)
	sonar(SONIDO_PIP, 0.8, 0.8)
end

function Interfaz.Bienvenida()
	Interfaz.Anuncio("🤪 " .. Config.NOMBRE_JUEGO .. " 🤪", {
		Subtitulo = `{Config.MAX_JUGADORES} jugadores · 8 minijuegos · 0 piedad`,
		Color = DORADO,
		Duracion = 4,
	})
	confeti(40)
end

return Interfaz
