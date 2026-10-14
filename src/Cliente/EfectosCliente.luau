--!strict
-- ✨ Efectos que pasan en tu ordenador: trampolines, empujones, decoración que
-- gira, pista de baile y los efectos visuales de los MODOS LOCOS.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Compartido"):WaitForChild("Config"))

local jugador = Players.LocalPlayer

local EfectosCliente = {}

local function sonar(id: string, volumen: number, velocidad: number)
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Volume = volumen
	sonido.PlaybackSpeed = velocidad
	sonido.Parent = SoundService
	sonido:Play()
	Debris:AddItem(sonido, 4)
end

-- ===== Lanzar al jugador por los aires =====

local tokenVuelo = 0

function EfectosCliente.Lanzar(velocidad: Vector3, segundosVolando: number)
	local personaje = jugador.Character
	if not personaje then
		return
	end
	local raiz = personaje:FindFirstChild("HumanoidRootPart")
	local humanoide = personaje:FindFirstChildOfClass("Humanoid")
	if not raiz or not raiz:IsA("BasePart") or not humanoide or humanoide.Health <= 0 then
		return
	end

	if segundosVolando > 0 then
		-- Modo "muñeco de trapo": no puedes controlar al personaje mientras vuelas.
		tokenVuelo += 1
		local mio = tokenVuelo
		humanoide.PlatformStand = true
		raiz.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		task.delay(segundosVolando, function()
			if tokenVuelo == mio and humanoide.Parent then
				humanoide.PlatformStand = false
				humanoide:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end
	raiz.AssemblyLinearVelocity = velocidad
end

-- ===== Trampolines y cañones (partes con la etiqueta "Impulso") =====

local ultimoImpulso = 0

local function conectarImpulso(instancia: Instance)
	if not instancia:IsA("BasePart") then
		return
	end
	local parte = instancia
	parte.Touched:Connect(function(otra: BasePart)
		local personaje = jugador.Character
		if not personaje or not otra:IsDescendantOf(personaje) then
			return
		end
		local ahora = os.clock()
		if ahora - ultimoImpulso < 0.5 then
			return
		end
		local impulso = parte:GetAttribute("Impulso")
		if typeof(impulso) ~= "Vector3" then
			return
		end
		ultimoImpulso = ahora
		local vuelo = parte:GetAttribute("Vuelo")
		EfectosCliente.Lanzar(impulso, if typeof(vuelo) == "number" then vuelo else 0)
		sonar("rbxasset://sounds/action_jump.mp3", 0.8, 1.5)
	end)
end

-- ===== Decoración animada =====

local giratorios: { [BasePart]: number } = {}
local degradados: { [UIGradient]: boolean } = {}

local function alGirar(instancia: Instance)
	if instancia:IsA("BasePart") then
		local velocidad = instancia:GetAttribute("VelocidadGiro")
		giratorios[instancia] = if typeof(velocidad) == "number" then velocidad else 1
	end
end

local function alQuitarGiro(instancia: Instance)
	if instancia:IsA("BasePart") then
		giratorios[instancia] = nil
	end
end

local function alArcoIris(instancia: Instance)
	if instancia:IsA("UIGradient") then
		degradados[instancia] = true
	end
end

-- ===== Efectos de los MODOS LOCOS =====

local discoActivo = false
local ojoPezActivo = false
local guardado: { ClockTime: number, OutdoorAmbient: Color3, Brightness: number }? = nil
local efectoDisco: ColorCorrectionEffect? = nil

local function disco(activo: boolean)
	if activo == discoActivo then
		return
	end
	discoActivo = activo
	if activo then
		guardado = {
			ClockTime = Lighting.ClockTime,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness,
		}
		Lighting.ClockTime = 0
		Lighting.OutdoorAmbient = Color3.fromRGB(130, 100, 170)
		Lighting.Brightness = 1.5
		local efecto = Instance.new("ColorCorrectionEffect")
		efecto.Name = "DiscoLoco"
		efecto.Saturation = 0.6
		efecto.Contrast = 0.15
		efecto.Parent = Lighting
		efectoDisco = efecto
		task.spawn(function()
			local tono = 0
			while discoActivo and efecto.Parent do
				tono = (tono + 0.13) % 1
				TweenService:Create(efecto, TweenInfo.new(0.3), { TintColor = Color3.fromHSV(tono, 0.45, 1) }):Play()
				task.wait(0.3)
			end
		end)
	else
		local g = guardado
		if g then
			Lighting.ClockTime = g.ClockTime
			Lighting.OutdoorAmbient = g.OutdoorAmbient
			Lighting.Brightness = g.Brightness
		end
		if efectoDisco then
			efectoDisco:Destroy()
			efectoDisco = nil
		end
	end
end

local function ojoPez(activo: boolean)
	if activo == ojoPezActivo then
		return
	end
	ojoPezActivo = activo
	local camara = workspace.CurrentCamera
	if camara then
		TweenService:Create(camara, TweenInfo.new(1, Enum.EasingStyle.Sine), {
			FieldOfView = if activo then 115 else 70,
		}):Play()
	end
end

function EfectosCliente.Efecto(nombre: string, activo: boolean)
	if nombre == "Todo" then
		disco(false)
		ojoPez(false)
	elseif nombre == "Disco" then
		disco(activo)
	elseif nombre == "OjoPez" then
		ojoPez(activo)
	end
end

function EfectosCliente.Iniciar()
	for _, parte in CollectionService:GetTagged("Impulso") do
		conectarImpulso(parte)
	end
	CollectionService:GetInstanceAddedSignal("Impulso"):Connect(conectarImpulso)

	for _, parte in CollectionService:GetTagged("Girar") do
		alGirar(parte)
	end
	CollectionService:GetInstanceAddedSignal("Girar"):Connect(alGirar)
	CollectionService:GetInstanceRemovedSignal("Girar"):Connect(alQuitarGiro)

	for _, g in CollectionService:GetTagged("ArcoIris") do
		alArcoIris(g)
	end
	CollectionService:GetInstanceAddedSignal("ArcoIris"):Connect(alArcoIris)

	RunService.RenderStepped:Connect(function(dt: number)
		for parte, velocidad in giratorios do
			if parte.Parent then
				parte.CFrame = parte.CFrame * CFrame.Angles(0, velocidad * dt, 0)
			else
				giratorios[parte] = nil
			end
		end
		local rotacion = (os.clock() * 45) % 360
		for degradado in degradados do
			if degradado.Parent then
				degradado.Rotation = rotacion
			else
				degradados[degradado] = nil
			end
		end
	end)

	-- Pista de baile: cambia de color al ritmo.
	task.spawn(function()
		while true do
			for _, baldosa in CollectionService:GetTagged("Disco") do
				if baldosa:IsA("BasePart") then
					baldosa.Color = Config.COLORES[math.random(1, #Config.COLORES)]
				end
			end
			task.wait(0.45)
		end
	end)
end

return EfectosCliente
