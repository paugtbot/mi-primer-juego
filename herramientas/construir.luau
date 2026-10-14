--!nocheck
-- 🏗️ CONSTRUIR EL ARCHIVO DEL JUEGO (herramienta para desarrolladores)
--
-- Mete el lobby ya construido dentro de LocuraTotal.rbxlx. Así, al abrir el
-- archivo en Roblox Studio, se ve la isla (y se puede editar a mano). El juego
-- usa el lobby que encuentre en el archivo; si no hay, lo construye él solo.
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

local base = {
	game = game,
	workspace = workspace,
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
	task = task,
	math = math,
	string = string,
	table = table,
	print = print,
	warn = print,
	error = error,
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
}

local cache = {}
local function requerir(modulo)
	local clave = modulo:GetFullName()
	if cache[clave] == nil then
		local entorno = table.clone(base)
		entorno.script = modulo
		entorno.require = requerir
		cache[clave] = luau.load(modulo.Source, { debugName = clave, environment = entorno })()
	end
	return cache[clave]
end

math.randomseed(8) -- siempre el mismo lobby
local servidor = game:GetService("ServerScriptService"):FindFirstChild("Servidor")
local Lobby = requerir(servidor:FindFirstChild("Lobby"))
Lobby.Construir()

local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "No se construyó el lobby")
fs.writeFile(ruta, roblox.serializePlace(game, true)) -- true = formato XML (.rbxlx)
print(string.format("✅ Lobby metido en %s (%d objetos)", ruta, #lobby:GetDescendants()))
