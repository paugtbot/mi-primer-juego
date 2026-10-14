# 🚀 Publicar LOCURA TOTAL en Roblox

## Título

**🤪 LOCURA TOTAL [17 MINIJUEGOS]**

(Otras opciones: `LOCURA TOTAL 🎉 Minijuegos con Amigos` · `🤪 Locura Total: Party de Minijuegos`)

## Descripción (cópiala tal cual)

```
🤪 ¡La fiesta de minijuegos más loca de Roblox! Hasta 8 jugadores votan el minijuego, una ruleta elige un MODO LOCO… ¡y a sobrevivir!

🎮 17 MINIJUEGOS: Parkour Extremo, Sillas Musicales, Invasión Zombi, Guerra de Bolas de Nieve, Color Loco, Patata Bomba, Suelo que Cae, Lluvia de Meteoritos ¡y muchos más!
🛒 MERCADO: ¡elige TÚ el próximo minijuego, consigue estelas y hazte VIP!
🌀 12 MODOS LOCOS: gravedad lunar, gigantes, todo de hielo, noche disco, gravedad que cambia sola… ¡o CAOS TOTAL!
🔨 Martillo Loco, cajas sorpresa ❓ con poderes y un botón rojo que NO debes pulsar 🔴
👑 Gana rondas, sube al podio y consigue coronas. Tus coronas, victorias y nivel se guardan.
🎁 Recompensa diaria y monedas en cada ronda.

👥 ¡Mejor con amigos! Invítalos y que gane el más loco.
```

## 💰 Activar la tienda con Robux

El juego ya trae la tienda hecha (isla del **Mercado**). Solo tienes que crear los
productos en Roblox y copiar sus números en el script:

1. Publica el juego (*File → Publish to Roblox*).
2. Ve a [create.roblox.com](https://create.roblox.com) → **Creations** → tu experiencia →
   **Monetization**.
3. En **Passes** crea un pase llamado **VIP** (precio recomendado: **199 R$**) y ponlo
   **a la venta** (*On Sale*). Copia su **ID**.
4. En **Developer Products** crea estos 3 productos y copia el **ID** de cada uno:

   | Producto | Precio recomendado | Dónde va el ID |
   |---|---|---|
   | 🎟️ Elegir el próximo minijuego | 25 R$ | `PRODUCTO_ELEGIR` |
   | 🎉 Fiesta para todos | 10 R$ | `PRODUCTO_FIESTA` |
   | 🪙 Bolsa de 1000 monedas | 49 R$ | `PRODUCTO_MONEDAS` |

5. En el script, arriba del todo (sección **⚙️ CONFIGURACIÓN → 💰 TIENDA CON ROBUX**),
   cambia los `0` por tus IDs. Por ejemplo:

   ```lua
   PASE_VIP = 123456789,
   PRODUCTO_ELEGIR = 987654321,
   ```

6. Si pones otros precios, cámbialos también en `PRECIOS` (solo sirve para que los
   carteles digan el precio correcto).
7. **Game Settings → Security → Enable Studio Access to API Services** (para que se
   guarden las monedas, las estelas y el ranking).

> 💡 Mientras un ID sea `0`, en Studio esa compra es **de prueba y gratis**, y en el
> juego publicado sale "¡muy pronto!" (nadie paga nada por error).

## Imágenes

| | Archivo | Dónde va |
|---|---|---|
| 🖼️ | [`imagenes/portada.jpg`](imagenes/portada.jpg) (1920×1080) | Miniatura (*Thumbnail*) |
| 🟨 | [`imagenes/icono.png`](imagenes/icono.png) (512×512) | Icono del juego |

![Portada](imagenes/portada.jpg)

## Dónde se pone todo

1. En Roblox Studio: *File → Publish to Roblox* (si aún no lo has publicado).
2. Ve a [create.roblox.com](https://create.roblox.com) → **Creations** → tu experiencia.
3. **Configure → Basic Info**: pega el **título** y la **descripción**. Género: *Party & Casual*.
4. **Configure → Places → (tu lugar) → Server Size**: pon **8**.
5. **Icon and Thumbnails** (en *Basic Info*): sube `icono.png` como icono y `portada.jpg` como miniatura.
6. Guarda y ponlo **público** (*Permissions / Privacy*).
