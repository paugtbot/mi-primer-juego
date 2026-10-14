--!strict
-- 🧱 Funciones para construir piezas rápido (partes, discos, bolas, carteles...).

local Constructor = {}

export type Props = { [string]: any }

-- Aplica propiedades a una instancia. Claves especiales:
--   Tags = {"Etiqueta1", ...}   -> etiquetas de CollectionService
--   Atributos = {Nombre = valor} -> atributos
--   Parent se asigna al final (más eficiente)
function Constructor.Aplicar(instancia: Instance, props: Props?)
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

local function base(parte: BasePart)
	parte.Anchored = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	parte.Material = Enum.Material.SmoothPlastic
end

-- Bloque normal.
function Constructor.Parte(props: Props?): Part
	local parte = Instance.new("Part")
	base(parte)
	Constructor.Aplicar(parte, props)
	return parte
end

-- Disco (cilindro tumbado en vertical). `arriba` es el centro de la cara de arriba.
function Constructor.Disco(arriba: Vector3, radio: number, grosor: number, props: Props?): Part
	local parte = Instance.new("Part")
	base(parte)
	parte.Shape = Enum.PartType.Cylinder
	parte.Size = Vector3.new(grosor, radio * 2, radio * 2)
	parte.CFrame = CFrame.new(arriba - Vector3.new(0, grosor / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	Constructor.Aplicar(parte, props)
	return parte
end

-- Bola.
function Constructor.Bola(centro: Vector3, diametro: number, props: Props?): Part
	local parte = Instance.new("Part")
	base(parte)
	parte.Shape = Enum.PartType.Ball
	parte.Size = Vector3.new(diametro, diametro, diametro)
	parte.CFrame = CFrame.new(centro)
	Constructor.Aplicar(parte, props)
	return parte
end

-- Rampa (cuña).
function Constructor.Cuna(props: Props?): WedgePart
	local parte = Instance.new("WedgePart")
	base(parte)
	Constructor.Aplicar(parte, props)
	return parte
end

-- Cartel con texto pegado a una cara de una parte.
function Constructor.Cartel(
	parte: BasePart,
	cara: Enum.NormalId,
	texto: string,
	colorTexto: Color3?,
	pixelesPorStud: number?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = cara
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelesPorStud or 25
	gui.LightInfluence = 0
	gui.Parent = parte

	local etiqueta = Instance.new("TextLabel")
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.BackgroundTransparency = 1
	etiqueta.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	etiqueta.TextScaled = true
	etiqueta.Text = texto
	etiqueta.TextColor3 = colorTexto or Color3.new(1, 1, 1)
	etiqueta.TextStrokeTransparency = 0
	etiqueta.TextStrokeColor3 = Color3.new(0, 0, 0)
	etiqueta.Parent = gui
	return etiqueta
end

-- Texto flotante que siempre mira a la cámara.
function Constructor.Flotante(
	adornee: BasePart,
	texto: string,
	alto: number,
	ancho: number,
	desplazamiento: Vector3?,
	color: Color3?
): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(ancho, alto)
	gui.StudsOffset = desplazamiento or Vector3.new(0, 3, 0)
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.MaxDistance = 400
	gui.Parent = adornee

	local etiqueta = Instance.new("TextLabel")
	etiqueta.Size = UDim2.fromScale(1, 1)
	etiqueta.BackgroundTransparency = 1
	etiqueta.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	etiqueta.TextScaled = true
	etiqueta.Text = texto
	etiqueta.TextColor3 = color or Color3.new(1, 1, 1)
	etiqueta.TextStrokeTransparency = 0
	etiqueta.Parent = gui
	return gui, etiqueta
end

-- Une dos partes para que se muevan juntas.
function Constructor.Soldar(a: BasePart, b: BasePart): WeldConstraint
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = a
	soldadura.Part1 = b
	soldadura.Parent = a
	return soldadura
end

-- Luz de colores.
function Constructor.Luz(parte: BasePart, color: Color3, brillo: number?, alcance: number?): PointLight
	local luz = Instance.new("PointLight")
	luz.Color = color
	luz.Brightness = brillo or 2
	luz.Range = alcance or 16
	luz.Parent = parte
	return luz
end

-- Puntos de aparición en círculo, mirando al centro. `centro` está a ras de suelo.
function Constructor.Circulo(centro: Vector3, radio: number, cantidad: number): { CFrame }
	local lista = {}
	for i = 1, cantidad do
		local angulo = (i - 1) / cantidad * math.pi * 2 + math.pi / cantidad
		local posicion = centro + Vector3.new(math.cos(angulo) * radio, 0, math.sin(angulo) * radio)
		table.insert(lista, CFrame.lookAt(posicion, Vector3.new(centro.X, posicion.Y, centro.Z)))
	end
	return lista
end

-- Puntos de aparición en filas (para carreras), mirando hacia +Z.
function Constructor.Parrilla(centro: Vector3, columnas: number, filas: number, separacion: number): { CFrame }
	local lista = {}
	for f = 1, filas do
		for c = 1, columnas do
			local x = (c - (columnas + 1) / 2) * separacion
			local z = (f - (filas + 1) / 2) * separacion
			local posicion = centro + Vector3.new(x, 0, z)
			table.insert(lista, CFrame.lookAt(posicion, posicion + Vector3.new(0, 0, 1)))
		end
	end
	return lista
end

-- Barra giratoria con motor (para licuadoras). Devuelve la barra y la bisagra.
-- La barra gira alrededor del eje Y que pasa por `centro`.
function Constructor.BarraGiratoria(
	centro: Vector3,
	largo: number,
	grosor: number,
	velocidad: number,
	color: Color3,
	padre: Instance
): (Part, HingeConstraint)
	local eje = Constructor.Parte({
		Name = "EjeBarra",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(centro),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = padre,
	})

	local barra = Constructor.Parte({
		Name = "Barra",
		Size = Vector3.new(largo, grosor, grosor),
		CFrame = CFrame.new(centro),
		Color = color,
		Material = Enum.Material.Neon,
		Anchored = false,
		CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0.5),
		Parent = padre,
	})

	-- El eje principal de las Attachment es X; lo giramos para que apunte hacia arriba (Y).
	local giro = CFrame.Angles(0, 0, math.rad(90))
	local a0 = Instance.new("Attachment")
	a0.CFrame = giro
	a0.Parent = eje
	local a1 = Instance.new("Attachment")
	a1.CFrame = giro
	a1.Parent = barra

	local bisagra = Instance.new("HingeConstraint")
	bisagra.Attachment0 = a0
	bisagra.Attachment1 = a1
	bisagra.ActuatorType = Enum.ActuatorType.Motor
	bisagra.MotorMaxTorque = math.huge
	bisagra.MotorMaxAcceleration = math.huge
	bisagra.AngularVelocity = velocidad
	bisagra.Parent = barra

	-- El servidor controla la barra para que todos la vean igual.
	pcall(function()
		barra:SetNetworkOwner(nil)
	end)

	return barra, bisagra
end

return Constructor
