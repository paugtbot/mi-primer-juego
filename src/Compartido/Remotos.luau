--!strict
-- 📡 Todos los RemoteEvents del juego en un solo sitio.
-- Están creados en ReplicatedStorage > Remotos (ver default.project.json).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local carpeta = ReplicatedStorage:WaitForChild("Remotos")

local function remoto(nombre: string): RemoteEvent
	return carpeta:WaitForChild(nombre) :: RemoteEvent
end

return {
	Estado = remoto("Estado"), -- barra de arriba: texto, tiempo, vivos...
	Anuncio = remoto("Anuncio"), -- texto gigante en el centro
	Ruleta = remoto("Ruleta"), -- ruleta para elegir minijuego / modo loco
	Feed = remoto("Feed"), -- mensajes de la derecha ("X se cayó")
	Resultados = remoto("Resultados"), -- tabla de resultados de la ronda
	Campeon = remoto("Campeon"), -- ceremonia final con confeti
	Empujon = remoto("Empujon"), -- lanza a un jugador por los aires
	Efecto = remoto("Efecto"), -- efectos visuales del modo loco (disco, ojo de pez...)
}
