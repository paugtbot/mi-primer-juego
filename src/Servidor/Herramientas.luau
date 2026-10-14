--!strict
-- 🔨 El Martillo Loco: un martillo de goma gigante que manda a volar a los demás.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Efectos = require(script.Parent.Efectos)
local Jugadores = require(script.Parent.Jugadores)

local Herramientas = {}

local ALCANCE = 9 -- distancia a la que golpea
local ESPERA = 0.7 -- segundos entre golpes

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

	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = mango
	soldadura.Part1 = cabeza
	soldadura.Parent = mango

	return herramienta
end

-- Da un Martillo Loco al jugador y se lo pone en la mano.
-- `fuerza` multiplica lo lejos que manda a volar (1 = normal).
function Herramientas.DarMartillo(jugador: Player, color: Color3, fuerza: number?)
	local mochila = jugador:FindFirstChildOfClass("Backpack")
	local humanoide = Jugadores.Humanoide(jugador)
	if not mochila or not humanoide then
		return
	end

	local herramienta = crearMartillo(color)
	local multiplicador = fuerza or 1
	local ultimoGolpe = 0

	herramienta.Activated:Connect(function()
		local ahora = os.clock()
		if ahora - ultimoGolpe < ESPERA then
			return
		end
		ultimoGolpe = ahora

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
			Efectos.Sonido(mango, "rbxasset://sounds/swordlunge.wav", 0.7, 0.8 + math.random() * 0.4)
		end

		local adelante = raiz.CFrame.LookVector
		for _, otro in Players:GetPlayers() do
			if otro ~= jugador then
				local raizOtro = Jugadores.Raiz(otro)
				if raizOtro and Jugadores.EstaVivo(otro) then
					local diferencia = raizOtro.Position - raiz.Position
					local distancia = diferencia.Magnitude
					if distancia <= ALCANCE and distancia > 0.01 then
						local plano = Vector3.new(diferencia.X, 0, diferencia.Z)
						local direccion = if plano.Magnitude > 0.01 then plano.Unit else adelante
						-- Solo golpea lo que tienes delante (o pegado a ti).
						if direccion:Dot(adelante) > 0.2 or distancia < 3.5 then
							local velocidad = direccion * 85 * multiplicador + Vector3.new(0, 45 * multiplicador, 0)
							Efectos.Empujar(otro, velocidad, 1)
							Efectos.Sonido(raizOtro, "rbxasset://sounds/swordslash.wav", 0.8, 0.6)
						end
					end
				end
			end
		end
	end)

	herramienta.Parent = mochila
	humanoide:EquipTool(herramienta)
end

return Herramientas
