--!nocheck
-- 🏗️ CONSTRUIR EL ARCHIVO DEL JUEGO (herramienta para desarrolladores)
--
-- Mete el lobby y la grada ya construidos dentro de LocuraTotal.rbxlx. Así, al
-- abrir el archivo en Roblox Studio, se ve la isla (y se puede editar a mano).
-- El script usa el lobby que encuentre en el juego; si no hay, lo construye él.
--
-- Uso (desde la carpeta del proyecto):
--   rojo build default.project.json -o LocuraTotal.rbxlx
--   lune run herramientas/construir.luau
--
-- (o simplemente: sh herramientas/construir.sh)

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local ruta = process.args[1] or "LocuraTotal.rbxlx"
if not fs.isFile(ruta) then
	print("No encuentro " .. ruta .. ". Ejecuta primero: rojo build default.project.json -o " .. ruta)
	process.exit(1)
end

local game = roblox.deserializePlace(fs.readFile(ruta))
local workspace = game:GetService("Workspace")
if workspace:FindFirstChild("Lobby") then
	print("El archivo ya tiene un lobby; no hago nada.")
	process.exit(0)
end

local script = game:GetService("ServerScriptService"):FindFirstChild("LocuraTotal")
assert(script, "No encuentro ServerScriptService.LocuraTotal")

-- Cargamos el script SIN arrancar el juego: cortamos en "¡ARRANCAMOS!" y
-- devolvemos las partes que construyen el mundo.
local fuente = script.Source
local corte = string.find(fuente, "-- 🚀 ¡ARRANCAMOS!", 1, true)
assert(corte, "No encuentro la sección de arranque en el script")
fuente = string.sub(fuente, 1, corte - 1) .. "\nreturn { Lobby = Lobby, Grada = Grada }\n"

-- Lune no calcula BasePart.Position a partir de CFrame: cambiamos sus lecturas.
fuente = string.gsub(fuente, "([%a_][%w_%.]*)%.Position(%s*=?=?)", function(receptor, sufijo)
	if string.match(sufijo, "^%s*=$") then
		return nil -- es una asignación: se deja igual
	end
	return "__posicion(" .. receptor .. ")" .. sufijo
end)

local entorno = {
	game = game,
	workspace = workspace,
	script = script,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Font = roblox.Font,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberRange = roblox.NumberRange,
	PhysicalProperties = roblox.PhysicalProperties,
	TweenInfo = { new = function() return {} end },
	OverlapParams = { new = function() return {} end },
	RaycastParams = { new = function() return {} end },
	task = task,
	os = os,
	math = math,
	string = string,
	table = table,
	print = print,
	warn = print,
	error = error,
	assert = assert,
	pcall = pcall,
	select = select,
	type = type,
	typeof = typeof,
	tostring = tostring,
	tonumber = tonumber,
	setmetatable = setmetatable,
	ipairs = ipairs,
	pairs = pairs,
	next = next,
	__posicion = function(x)
		if typeof(x) == "Instance" and x:IsA("BasePart") then
			return x.CFrame.Position
		end
		return x.Position
	end,
}

math.randomseed(8) -- siempre el mismo lobby
local mundo = luau.load(fuente, { debugName = "LocuraTotal", environment = entorno })()
mundo.Lobby.Construir()
mundo.Grada.Construir()

local lobby = workspace:FindFirstChild("Lobby")
local grada = workspace:FindFirstChild("Grada")
assert(lobby and grada, "No se construyó el mundo")
fs.writeFile(ruta, roblox.serializePlace(game, true)) -- true = formato XML (.rbxlx)
print(string.format("✅ Lobby (%d objetos) y grada (%d) metidos en %s", #lobby:GetDescendants(), #grada:GetDescendants(), ruta))
