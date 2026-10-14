--!strict
-- ⚙️ CONFIGURACIÓN DE LOCURA TOTAL
-- Cambia estos números para modificar el juego sin tocar el resto del código.

local Config = {}

Config.NOMBRE_JUEGO = "LOCURA TOTAL"

-- 👥 Jugadores
Config.MAX_JUGADORES = 8 -- el juego está pensado para 8 locos
Config.MIN_JUGADORES = 2 -- mínimo para empezar una ronda normal
Config.ESPERA_SOLO = 20 -- si estás solo este tiempo (segundos), empieza el modo práctica

-- ⏱️ Tiempos (segundos)
Config.RONDAS_POR_PARTIDA = 6
Config.TIEMPO_INTERMEDIO = 15
Config.TIEMPO_INTERMEDIO_STUDIO = 6 -- más corto cuando pruebas en Roblox Studio
Config.TIEMPO_RESULTADOS = 6
Config.TIEMPO_CEREMONIA = 12
Config.TIEMPO_REAPARECER = 2.5

-- 🏆 Puntos según el puesto en cada minijuego (1º, 2º, 3º, ...)
Config.PUNTOS_POR_PUESTO = { 10, 7, 5, 4, 3, 2, 1, 1 }

-- 🗺️ Dónde está todo
Config.LOBBY_CENTRO = Vector3.new(0, 50, 0) -- superficie de la isla principal
Config.ARENA_CENTRO = Vector3.new(0, 120, 420) -- donde se construyen los minijuegos
Config.ALTURA_VACIO_LOBBY = -60 -- si caes por debajo de esto en el lobby, reapareces

-- 🏃 Movimiento normal
Config.VELOCIDAD_BASE = 16
Config.SALTO_BASE = 50
Config.GRAVEDAD_NORMAL = 196.2

-- 🎨 Colores locos
Config.COLORES = {
	Color3.fromRGB(255, 71, 87), -- rojo
	Color3.fromRGB(255, 165, 2), -- naranja
	Color3.fromRGB(255, 221, 89), -- amarillo
	Color3.fromRGB(46, 213, 115), -- verde
	Color3.fromRGB(30, 144, 255), -- azul
	Color3.fromRGB(165, 94, 234), -- morado
	Color3.fromRGB(255, 107, 203), -- rosa
	Color3.fromRGB(0, 210, 211), -- turquesa
}

return Config
