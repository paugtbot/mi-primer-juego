--!strict
-- 💥 Efectos del servidor: explosiones, empujones, confeti y fuegos artificiales.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Compartido.Config)
local Remotos = require(ReplicatedStorage.Compartido.Remotos)

local Efectos = {}

-- Explosión visual (no mata a nadie, solo hace bonito y ruido).
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

-- Lanza a un jugador por los aires. El propio jugador aplica la fuerza
-- en su ordenador (así funciona siempre, aunque su personaje sea "suyo").
function Efectos.Empujar(jugador: Player, velocidad: Vector3, segundosVolando: number?)
	Remotos.Empujon:FireClient(jugador, velocidad, segundosVolando or 0)
end

local function emisorConfeti(padre: Instance): ParticleEmitter
	local emisor = Instance.new("ParticleEmitter")
	emisor.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emisor.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.COLORES[1]),
		ColorSequenceKeypoint.new(0.25, Config.COLORES[3]),
		ColorSequenceKeypoint.new(0.5, Config.COLORES[4]),
		ColorSequenceKeypoint.new(0.75, Config.COLORES[5]),
		ColorSequenceKeypoint.new(1, Config.COLORES[7]),
	})
	emisor.Size = NumberSequence.new(0.6, 0.2)
	emisor.Lifetime = NumberRange.new(1.5, 3)
	emisor.Speed = NumberRange.new(25, 45)
	emisor.SpreadAngle = Vector2.new(60, 60)
	emisor.Acceleration = Vector3.new(0, -30, 0)
	emisor.RotSpeed = NumberRange.new(-200, 200)
	emisor.LightEmission = 0.6
	emisor.Parent = padre
	return emisor
end

-- Explosión de confeti en un punto.
-- (Usamos una ráfaga corta en vez de Emit(): un emisor recién creado en el
-- servidor a veces todavía no ha llegado a los jugadores y no se vería.)
function Efectos.Confeti(posicion: Vector3, cantidad: number?)
	local parte = Instance.new("Part")
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Transparency = 1
	parte.Size = Vector3.new(1, 1, 1)
	parte.CFrame = CFrame.new(posicion)
	local emisor = emisorConfeti(parte)
	emisor.Rate = (cantidad or 80) / 0.35
	emisor.Enabled = true
	parte.Parent = workspace
	task.delay(0.35, function()
		emisor.Enabled = false
	end)
	Debris:AddItem(parte, 5)
end

-- Fuego artificial: sube una bola brillante y explota en confeti.
function Efectos.FuegoArtificial(desde: Vector3)
	local color = Config.COLORES[math.random(1, #Config.COLORES)]
	local cohete = Instance.new("Part")
	cohete.Shape = Enum.PartType.Ball
	cohete.Size = Vector3.new(1.5, 1.5, 1.5)
	cohete.Material = Enum.Material.Neon
	cohete.Color = color
	cohete.Anchored = true
	cohete.CanCollide = false
	cohete.CanQuery = false
	cohete.CanTouch = false
	cohete.CFrame = CFrame.new(desde)
	cohete.Parent = workspace

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

	local altura = math.random(35, 60)
	local destino = desde + Vector3.new(math.random(-10, 10), altura, math.random(-10, 10))
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

-- Sonido en una parte (si no carga, no pasa nada).
function Efectos.Sonido(padre: Instance, id: string, volumen: number?, velocidad: number?)
	local sonido = Instance.new("Sound")
	sonido.SoundId = id
	sonido.Volume = volumen or 0.6
	sonido.PlaybackSpeed = velocidad or 1
	sonido.Parent = padre
	sonido:Play()
	Debris:AddItem(sonido, 4)
end

return Efectos
