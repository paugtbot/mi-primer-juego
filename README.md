# 🤪 LOCURA TOTAL

**Un juego de fiesta para Roblox, para 8 jugadores. TODO en un solo script.**
13 minijuegos · 12 modos locos · 0 piedad.

Cada ronda los jugadores **votan** el minijuego pisando una plataforma del
lobby, y después una **ruleta** elige un **MODO LOCO** que lo cambia todo
(gravedad lunar, gigantes, todo de hielo, niebla, gravedad que cambia sola…).
Ganas puntos según tu puesto y, tras 6 rondas (la última vale **el doble**),
el que más tenga sube al podio y se lleva una **👑 corona**. Las coronas, las
victorias y tu **nivel** se guardan para siempre.

---

## 🚀 Cómo ponerlo en Roblox (2 minutos)

1. Abre **Roblox Studio** y crea un lugar nuevo con la plantilla **Baseplate**.
2. En el **Explorer**, pasa el ratón por encima de **ServerScriptService**,
   pulsa el **+** y elige **Script**.
3. Abre el archivo [`LocuraTotal.server.luau`](LocuraTotal.server.luau) aquí en
   GitHub, pulsa el botón de **copiar** (📋 *Copy raw file*) y **pégalo** en el
   Script, borrando lo que traía (`print("Hello world!")`).
4. Pulsa **▶ Play**. ¡Ya está!

En Studio puedes jugar solo para probar (las votaciones duran menos). Todo el
mundo (mar, montañas, islas, lobby, estadio, grada y minijuegos) se construye
solo al darle a Play.

> 💡 Otra opción: descarga [`LocuraTotal.rbxlx`](LocuraTotal.rbxlx) y ábrelo con
> *File → Open from File*. Trae el mismo script ya puesto en su sitio.

### 👥 Probarlo con 8 jugadores en tu ordenador

Pestaña **Test** → *Clients and Servers* → **Local Server** con **8 Players** →
**Start**. Se abre una ventana por jugador (si tu ordenador sufre, prueba con 2 o 3).

### 🌍 Jugar con tus amigos

1. *File* → **Publish to Roblox** (crea una experiencia nueva, por ejemplo "LOCURA TOTAL").
2. **Pon el servidor a 8 jugadores**: en *Game Settings* (o en
   [create.roblox.com](https://create.roblox.com) → tu experiencia → *Places*)
   busca **Server Size / Max Players** y pon **8**.
   (Aunque se te olvide, el juego echa con un mensaje al 9º jugador.)
3. Hazla **pública** en *Game Settings → Permissions* (Roblox puede pedirte antes
   el cuestionario de madurez).
4. *(Opcional)* Para que las coronas y niveles se guarden también al probar en
   Studio: *Game Settings → Security →* **Enable Studio Access to API Services**.
   En el juego publicado se guardan solas.

---

## 🎮 Los 13 minijuegos

| | Minijuego | De qué va |
|---|---|---|
| 🟦 | **Suelo que Cae** | 3 pisos de baldosas sobre lava que desaparecen al pisarlas. A los 40 s… ¡terremoto! |
| ☄️ | **Lluvia de Meteoritos** | Caen meteoritos que rompen el suelo. Huye de los círculos rojos. |
| 👑 | **Rey de la Colina** | Quédate en la cima dorada para sumar puntos… con martillos para echarte. |
| 💣 | **Patata Bomba** | Llevas una bomba en la cabeza: toca a otro para pasársela antes del ¡BOOM! |
| 🌪️ | **La Licuadora** | Dos barras gigantes giran cada vez más rápido. ¡Salta! |
| 🏁 | **Carrera Loca** | Lava, cinta que te empuja, plataformas que desaparecen, trampolines y licuadora. |
| 🧊 | **Sumo en el Hielo** | Pista de hielo que encoge, ráfagas de viento y martillos. |
| 🎳 | **Rampa Rodante** | Sube una rampa mientras bajan bolas gigantes. ¡Tú eres el bolo! |
| 🎨 | **Pinta el Suelo** ✨ | Pinta baldosas de tu color pisándolas. Gana quien pinte más. |
| 🚦 | **Luz Roja, Luz Verde** ✨ | Corre en verde… y si te mueves en rojo, ¡BOOM! |
| 🌋 | **La Lava Sube** ✨ | Escala una torre de plataformas antes de que la lava te alcance. |
| 🧱 | **Muro Loco** ✨ | Vienen muros con agujeros: ponte en el hueco o salta los bajitos. |
| 💎 | **Fiebre de Gemas** ✨ | Coge gemas (las doradas valen 5) y róbaselas a martillazos. |

## 🌀 Los 12 modos locos

😐 Sin locura · 🌙 Gravedad Lunar · ⚡ Modo Turbo · 🦖 Gigantes · 🐜 Mini Locos ·
🦘 Súper Salto · 🪩 Noche Disco · 🌫️ Niebla Total · 👻 Modo Fantasma ·
🧊 Todo es Hielo · 🔄 Gravedad Loca · 🌀 **CAOS TOTAL** (¡2 o 3 a la vez!)

## 🌅 Lo visual

- **Atardecer dorado** con neblina rosa, rayos de sol, brillo (*bloom*), nubes
  de verdad y un **mar turquesa** rodeado de **montañas nevadas**.
- **Islas flotantes** de roca con árboles de chuchería por todo el cielo.
- **Lobby en una isla**: plaza con **fuente**, pista de baile circular con bola
  de discoteca, **arcoíris gigante** sobre las plataformas de votación, cartel
  con bombillas de feria que parpadean, farolas con **guirnaldas de luces**,
  flores, globos, **4 cascadas** que caen al mar y lucecitas mágicas flotando.
- **Estadio de neón** alrededor de los minijuegos: dos anillos arcoíris
  gigantes, 4 torres de luz con focos al cielo y **2 pantallas gigantes** que
  dicen qué se juega y quién gana. ¡Y fuegos artificiales al empezar!
- Cada arena lleva **columnas con luces, banderines y brillitos**; la lava
  suelta **brasas**.
- Durante las rondas dejas una **estela de tu color**, al caer haces **¡puf!**
  y al aparecer sueltas brillitos.
- **Interfaz** con tarjeta de presentación de cada minijuego, **telón** de
  colores entre el lobby y la arena, **barra de tiempo**, panel de votos con
  barras, resultados con colores de podio, cuenta atrás de colores y destellos
  de pantalla (rojo si te eliminan, dorado si ganas).

## ✨ Y además…

- **❓ Cajas sorpresa** en muchos minijuegos: ⚡ turbo, 🦘 súper muelle, 🛡️ escudo,
  💥 onda expansiva y 🎈 globo.
- **🔨 Martillo Loco** para mandar a volar a los demás (y si alguien se cae por tu
  culpa, ¡te llevas el mérito!).
- **🏝️ Lobby** con trampolines, un 🚀 cañón humano que lleva a una **isla
  secreta** y un **🔴 botón rojo "NO PULSAR"** con 6 sorpresas (despegue,
  lluvia de pelotas, todos mini, tornado…).
- **👀 Grada de espectadores**: si te eliminan, ves el resto de la ronda en directo.
- **🏅 Premios al final de cada partida**: Rey del Martillo, Terminator, Piloto
  de Pruebas y Cazacajas.
- **Niveles y títulos** (🐣 Novato → 👑 Leyenda del Caos) encima de la cabeza.
- Interfaz con barra de estado, ruleta, anuncios, marcador, resultados y consejos.

---

## 🛠️ Cómo cambiar cosas (¡para aprender!)

Todo el código está en español y comentado. Arriba del todo del script está la
sección **⚙️ CONFIGURACIÓN**:

- `RONDAS_POR_PARTIDA = 6`, `TIEMPO_VOTACION = 15`, `PUNTOS_POR_PUESTO`…
- `CAJAS_SORPRESA = true` (pon `false` para quitarlas), `ULTIMA_RONDA_DOBLE`…
- Los colores, la velocidad y el salto normales.
- ¿Prefieres jugar de noche? Busca `Lighting.ClockTime = 16.4` (en
  `Paisaje.Luces`) y pon `0`. ¡Con `12` es mediodía!

Más ideas:

- Busca un minijuego (por ejemplo `-- 🟦 SUELO QUE CAE`) y cambia sus números
  de arriba: `PISOS = 3` → ¡pon 5!
- En `Modificadores.Lista` cambia la `Gravedad` de la Gravedad Lunar o el
  `Peso` de un modo (cuanto más peso, más veces sale).
- **Crea tu propio minijuego**: copia uno parecido (desde `do` hasta su `end`),
  cámbiale el `Id`, el nombre y lo que hace. Se añade solo a la votación.
- **Música**: añade un `Sound` en *SoundService* desde la Toolbox → Audio y
  marca *Looped* y *Playing*.

**Si algo no funciona:** abre *View → Output*. Ahí salen los errores en rojo,
con la línea donde están.

---

## 🧪 Para programadores (opcional)

```sh
sh herramientas/construir.sh      # construye LocuraTotal.rbxlx y lo prueba
```

- Es un proyecto de [Rojo](https://rojo.space) (`default.project.json`): puedes
  usar `rojo serve` y editar `LocuraTotal.server.luau` con VS Code.
- Todo funciona desde el servidor (interfaz incluida), por eso cabe en un único
  `Script`. Los empujones usan una `LinearVelocity` corta dentro del personaje.
- `herramientas/simulacion.luau` ejecuta el script **real** con
  [Lune](https://lune-org.github.io/docs): 8 bots con física simplificada y el
  tiempo acelerado juegan una partida entera. Votan, pulsan el botón rojo, cogen
  cajas, usan el martillo, uno se va a mitad y un 9º intenta entrar. Al final
  comprueba que no haya ningún error. (El terreno se simula con cajas
  invisibles, porque Lune no tiene vóxeles.)
- El script pasa el comprobador de tipos de Luau en modo `--!strict` con las
  definiciones oficiales de la API de Roblox (luau-lsp).
