# 🤪 LOCURA TOTAL

**Un juego de Roblox para 8 jugadores. 8 minijuegos. 10 modos locos. 0 piedad.**

Cada ronda, una **ruleta** elige un minijuego al azar… y otra ruleta elige un
**MODO LOCO** que lo cambia todo (gravedad lunar, gigantes, todo de hielo,
noche disco…). Ganas puntos según tu puesto y, tras 6 rondas, el que más
puntos tenga sube al podio, se lleva una **👑 corona** (que se guarda para
siempre) y hay fuegos artificiales.

---

## 🎮 Los 8 minijuegos

| | Minijuego | De qué va |
|---|---|---|
| 🟦 | **Suelo que Cae** | 3 pisos de baldosas sobre lava. Cada baldosa que pisas desaparece. A los 40 s… ¡terremoto! Sé el último en pie. |
| ☄️ | **Lluvia de Meteoritos** | Caen meteoritos que rompen el suelo y te mandan a volar. Huye de los círculos rojos. Cada 25 s, ¡METEORITO GIGANTE! |
| 👑 | **Rey de la Colina** | Sube a la cima dorada y quédate ahí para sumar puntos. Todos tienen un **Martillo Loco** para echarte. |
| 💣 | **Patata Bomba** | Alguien lleva una bomba en la cabeza. Toca a otro para pasársela… antes de que haga ¡BOOM! |
| 🌪️ | **La Licuadora** | Dos barras gigantes giran cada vez más rápido. Salta o saldrás volando. |
| 🏁 | **Carrera Loca** | Carrera de obstáculos: lava, cinta que te empuja hacia atrás, plataformas que desaparecen, trampolines y una licuadora. |
| 🧊 | **Sumo en el Hielo** | Pista de hielo que encoge + ráfagas de viento + martillos. Échalos a todos al agua helada. |
| 🎳 | **Rampa Rodante** | Sube una rampa enorme mientras bajan bolas gigantes rodando. ¡Tú eres el bolo! |

## 🌀 Los 10 modos locos

| | Modo | Qué pasa |
|---|---|---|
| 😐 | Sin locura | Ronda normal… por ahora. |
| 🌙 | Gravedad Lunar | Saltos de astronauta y vuelos eternos. |
| ⚡ | Modo Turbo | Todo el mundo corre el doble. |
| 🦖 | Ataque de Gigantes | Sois ENORMES. |
| 🐜 | Mini Locos | Sois diminutos. |
| 🦘 | Súper Salto | Piernas de canguro. |
| 🪩 | Noche Disco | Se apagan las luces y los colores se vuelven locos. |
| 🐟 | Ojo de Pez | La cámara se deforma. |
| 🧊 | Todo es Hielo | Todo el suelo resbala. |
| 🌀 | **CAOS TOTAL** | ¡2 o 3 modos locos a la vez! |

## 🏝️ El lobby

Una isla flotante con pista de baile que cambia de color, bola de discoteca,
4 **trampolines** rosas, un **🚀 cañón humano** que te lanza a una **isla
secreta**, el podio de campeones y carteles que explican cómo se juega.
Si te eliminan, tienes un botón **👀 ESPECTAR** para ver a los que siguen vivos.

---

## 🚀 Cómo abrirlo en Roblox Studio

1. **Descarga el archivo `LocuraTotal.rbxlx`** de este repositorio
   (ábrelo en GitHub y pulsa el botón de descargar, o *Code → Download ZIP* y descomprime).
2. Abre **Roblox Studio** → *File* (Archivo) → **Open from File…** (Abrir desde archivo)
   → elige `LocuraTotal.rbxlx`.
3. Verás la isla del lobby. Pulsa **▶ Play** (F5).
   En Studio el juego empieza aunque estés solo y las esperas son más cortas, para probar rápido.

> Los minijuegos no se ven en el editor: se construyen solos cuando empieza cada ronda.

### 👥 Probarlo con 8 jugadores en tu ordenador

Pestaña **Test** (Probar) → en *Clients and Servers* elige **Local Server** y
**8 Players** → **Start**. Se abre una ventana por jugador. (Si tu ordenador
sufre, prueba con 2 o 3.)

## 🌍 Publicarlo para jugar con tus amigos

1. *File* → **Publish to Roblox** → crea una experiencia nueva (por ejemplo "LOCURA TOTAL").
2. **Pon el servidor a 8 jugadores**: en *Game Settings* (o en
   [create.roblox.com](https://create.roblox.com) → tu experiencia → *Places* → tu lugar)
   busca **Server Size / Max Players** y pon **8**.
   (Aunque se te olvide, el juego echa con un mensaje al 9º jugador que entre.)
3. Hazlo **público** en *Game Settings → Permissions* (o desde create.roblox.com).
   Roblox puede pedirte rellenar antes el cuestionario de madurez del juego.
4. *(Opcional)* Para que las **👑 coronas** se guarden también al probar en Studio:
   *Game Settings → Security →* **Enable Studio Access to API Services**.
   En el juego publicado se guardan solas.

---

## 🛠️ Cómo cambiar cosas (¡para aprender!)

Todo está en español y comentado. En el **Explorer** de Studio:

```
ReplicatedStorage
├── Compartido
│   ├── Config        ← ⚙️ EMPIEZA AQUÍ: rondas, tiempos, puntos, colores...
│   └── Remotos       (lista de mensajes servidor → jugadores)
└── Remotos           (los RemoteEvents)

ServerScriptService
└── Servidor          ← script principal del servidor
    ├── Juego         (el bucle: ruleta → minijuego → resultados → campeón)
    ├── Ronda         (quién sigue vivo, puntos, eliminaciones)
    ├── Jugadores     (aparecer, puntos, coronas guardadas)
    ├── Lobby         (construye la isla si no está en el archivo)
    ├── Modificadores (los 10 modos locos)
    ├── Herramientas  (el Martillo Loco)
    ├── Efectos       (explosiones, empujones, confeti, fuegos artificiales)
    ├── Constructor   (funciones para crear piezas rápido)
    └── Minijuegos    (un archivo por minijuego)

StarterPlayer → StarterPlayerScripts
└── Cliente           ← lo que ve cada jugador (interfaz, ruleta, efectos)

Workspace
└── Lobby             ← ¡puedes moverlo y decorarlo a mano en Studio!
```

**Ideas fáciles para empezar:**

- En `Config`: cambia `RONDAS_POR_PARTIDA` (6), `TIEMPO_INTERMEDIO` (15) o
  `PUNTOS_POR_PUESTO`.
- En cada minijuego cambia `Duracion`, o los números de arriba del archivo
  (por ejemplo `PISOS = 3` en *SueloQueCae* → ¡pon 5!).
- En `Modificadores` cambia la `Gravedad` de la Gravedad Lunar o el `Peso`
  (cuanto más peso, más veces sale ese modo).
- **Crear tu propio minijuego**: duplica uno de `Minijuegos`, cámbiale el
  nombre y lo que hace, y añádelo a la lista `LISTA` de arriba del todo en `Juego`.
- **Música**: no lleva (los audios de Roblox necesitan un ID). Añade un
  `Sound` en *SoundService* desde la Toolbox → Audio y marca *Looped* y *Playing*.

**Si algo no funciona:** abre *View → Output* (Ver → Salida). Ahí salen los
errores en rojo, con el archivo y la línea.

---

## 🧪 Para programadores (opcional)

El código fuente está en `src/` y es un proyecto de [Rojo](https://rojo.space)
(`default.project.json`), así que puedes usar `rojo serve` y editar con VS Code.

```sh
sh herramientas/construir.sh      # construye LocuraTotal.rbxlx y lo prueba
```

- `herramientas/construir.luau` mete el lobby ya construido dentro del `.rbxlx`
  para que se vea al abrirlo en Studio.
- `herramientas/simulacion.luau` ejecuta el código **real** del juego (servidor
  y cliente) con [Lune](https://lune-org.github.io/docs), 8 bots con física
  simplificada y el tiempo acelerado ×25: juega una partida entera de 8 rondas
  (los 8 minijuegos), expulsa a un 9º jugador, hace que uno se vaya a mitad,
  usa martillos y el botón de espectar, y comprueba que no haya ningún error.
- El código pasa el comprobador de tipos de Luau (`--!strict`) con las
  definiciones de la API de Roblox (luau-lsp).
