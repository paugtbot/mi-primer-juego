--!strict
-- 🤪 LOCURA TOTAL - Script principal del cliente (lo que ve cada jugador).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotos = require(ReplicatedStorage:WaitForChild("Compartido"):WaitForChild("Remotos"))
local EfectosCliente = require(script.EfectosCliente)
local Interfaz = require(script.Interfaz)

Interfaz.Crear()
EfectosCliente.Iniciar()

Remotos.Estado.OnClientEvent:Connect(function(datos)
	Interfaz.Estado(datos)
end)
Remotos.Anuncio.OnClientEvent:Connect(function(mensaje, opciones)
	Interfaz.Anuncio(mensaje, opciones)
end)
Remotos.Ruleta.OnClientEvent:Connect(function(datos)
	Interfaz.Ruleta(datos)
end)
Remotos.Feed.OnClientEvent:Connect(function(mensaje)
	Interfaz.Feed(mensaje)
end)
Remotos.Resultados.OnClientEvent:Connect(function(datos)
	Interfaz.Resultados(datos)
end)
Remotos.Campeon.OnClientEvent:Connect(function(datos)
	Interfaz.Campeon(datos)
end)
Remotos.Empujon.OnClientEvent:Connect(function(velocidad, segundosVolando)
	EfectosCliente.Lanzar(velocidad, segundosVolando)
end)
Remotos.Efecto.OnClientEvent:Connect(function(nombre, activo)
	EfectosCliente.Efecto(nombre, activo)
end)

Interfaz.Bienvenida()
