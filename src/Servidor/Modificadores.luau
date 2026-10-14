--!strict
-- 🌀 MODOS LOCOS: cada ronda puede tener un modificador que lo cambia todo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Compartido.Config)
local Remotos = require(ReplicatedStorage.Compartido.Remotos)

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
	EfectosCliente: { string }?,
}

local Modificadores = {}

Modificadores.Lista = {
	{
		Id = "Normal",
		Nombre = "Sin locura",
		Emoji = "😐",
		Descripcion = "Ronda normal... por ahora.",
		Peso = 2,
	},
	{
		Id = "Lunar",
		Nombre = "Gravedad Lunar",
		Emoji = "🌙",
		Descripcion = "¡Saltos de astronauta y vuelos eternos!",
		Peso = 3,
		Gravedad = 55,
	},
	{
		Id = "Turbo",
		Nombre = "Modo Turbo",
		Emoji = "⚡",
		Descripcion = "¡Todo el mundo corre el doble de rápido!",
		Peso = 3,
		MultVelocidad = 1.9,
	},
	{
		Id = "Gigantes",
		Nombre = "Ataque de Gigantes",
		Emoji = "🦖",
		Descripcion = "¡Sois ENORMES!",
		Peso = 2,
		Escala = 1.8,
	},
	{
		Id = "Mini",
		Nombre = "Mini Locos",
		Emoji = "🐜",
		Descripcion = "¡Sois diminutos como hormigas!",
		Peso = 2,
		Escala = 0.5,
	},
	{
		Id = "Saltarin",
		Nombre = "Súper Salto",
		Emoji = "🦘",
		Descripcion = "¡Piernas de canguro para todos!",
		Peso = 2,
		MultSalto = 1.8,
	},
	{
		Id = "Disco",
		Nombre = "Noche Disco",
		Emoji = "🪩",
		Descripcion = "¡Se apagan las luces y empieza la fiesta!",
		Peso = 2,
		EfectosCliente = { "Disco" },
	},
	{
		Id = "OjoPez",
		Nombre = "Ojo de Pez",
		Emoji = "🐟",
		Descripcion = "¡La cámara se vuelve loquísima!",
		Peso = 2,
		EfectosCliente = { "OjoPez" },
	},
	{
		Id = "Hielo",
		Nombre = "Todo es Hielo",
		Emoji = "🧊",
		Descripcion = "¡Cuidado, que resbala!",
		Peso = 2,
		Hielo = true,
	},
	{
		Id = "Caos",
		Nombre = "CAOS TOTAL",
		Emoji = "🌀",
		Descripcion = "¡Varios modos locos a la vez!",
		Peso = 2,
	},
} :: { Modificador }

local function porId(id: string): Modificador?
	for _, m in Modificadores.Lista do
		if m.Id == id then
			return m
		end
	end
	return nil
end

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

-- Mezcla varios modificadores en uno solo (para CAOS TOTAL).
local function mezclar(partes: { Modificador }): Modificador
	local resultado: Modificador = {
		Id = "Caos",
		Nombre = "CAOS TOTAL",
		Emoji = "🌀",
		Descripcion = "",
		Peso = 0,
		EfectosCliente = {},
	}
	local nombres = {}
	for _, m in partes do
		table.insert(nombres, m.Emoji .. " " .. m.Nombre)
		if m.Gravedad then
			resultado.Gravedad = math.min(resultado.Gravedad or math.huge, m.Gravedad)
		end
		if m.MultVelocidad then
			resultado.MultVelocidad = (resultado.MultVelocidad or 1) * m.MultVelocidad
		end
		if m.MultSalto then
			resultado.MultSalto = (resultado.MultSalto or 1) * m.MultSalto
		end
		if m.Escala and not resultado.Escala then
			resultado.Escala = m.Escala
		end
		if m.Hielo then
			resultado.Hielo = true
		end
		if m.EfectosCliente then
			for _, efecto in m.EfectosCliente do
				table.insert(resultado.EfectosCliente :: { string }, efecto)
			end
		end
	end
	resultado.Descripcion = table.concat(nombres, " + ")
	return resultado
end

local ultimoId = ""

-- Elige un modo loco al azar (sin repetir el de la ronda anterior).
-- La primera ronda de cada partida es más tranquila.
function Modificadores.Elegir(numeroRonda: number): Modificador
	if numeroRonda == 1 and math.random() < 0.5 then
		ultimoId = "Normal"
		return porId("Normal") :: Modificador
	end
	local candidatos = {}
	for _, m in Modificadores.Lista do
		if m.Id ~= ultimoId then
			table.insert(candidatos, m)
		end
	end
	local elegido = elegirPonderado(candidatos)
	ultimoId = elegido.Id
	if elegido.Id ~= "Caos" then
		return elegido
	end

	-- CAOS: junta 2 o 3 modos distintos (sin Normal, sin repetir).
	local disponibles = {}
	for _, m in Modificadores.Lista do
		if m.Id ~= "Normal" and m.Id ~= "Caos" then
			table.insert(disponibles, m)
		end
	end
	local partes = {}
	local cantidad = math.random(2, 3)
	for _ = 1, cantidad do
		if #disponibles == 0 then
			break
		end
		local indice = math.random(1, #disponibles)
		local m = table.remove(disponibles, indice) :: Modificador
		-- No mezclar gigantes con mini.
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

-- Cosas que afectan a todo el mundo (gravedad, efectos visuales).
function Modificadores.AplicarMundo(mod: Modificador)
	workspace.Gravity = mod.Gravedad or Config.GRAVEDAD_NORMAL
	if mod.EfectosCliente then
		for _, efecto in mod.EfectosCliente do
			Remotos.Efecto:FireAllClients(efecto, true)
		end
	end
end

function Modificadores.QuitarMundo()
	workspace.Gravity = Config.GRAVEDAD_NORMAL
	Remotos.Efecto:FireAllClients("Todo", false)
end

-- Convierte todo el suelo de la arena en hielo resbaladizo.
function Modificadores.AplicarHielo(carpeta: Instance)
	local hielo = PhysicalProperties.new(0.9, 0.02, 0.1, 100, 1)
	for _, d in carpeta:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and d.CanCollide and d.Transparency < 1 then
			d.Material = Enum.Material.Ice
			d.CustomPhysicalProperties = hielo
		end
	end
end

return Modificadores
