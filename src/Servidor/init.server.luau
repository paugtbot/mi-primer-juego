--!strict
-- 🤪 LOCURA TOTAL - Script principal del servidor
-- Construye el mundo, prepara a los jugadores y arranca el bucle del juego.

local Juego = require(script.Juego)
local Jugadores = require(script.Jugadores)
local Lobby = require(script.Lobby)

Lobby.Construir()
Jugadores.Iniciar()
Juego.Iniciar()

print("🤪 LOCURA TOTAL está listo. ¡Que empiece la locura!")
