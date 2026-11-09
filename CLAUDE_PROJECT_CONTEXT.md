# BLOCK KARTS — Contexto de proyecto para Claude

Última actualización: 2026-11-08

## Proyecto y flujo
- Repositorio: https://github.com/GamaKingStudio/Block-Karts
- Rama de trabajo: `recovery/stable-handling`
- Proyecto Roblox Studio / Luau; sincronización con Rojo 7.7.1.
- Carpeta local del usuario: `C:\\Users\\l_kan\\Block Karts`
- Flujo del usuario: `git pull origin recovery/stable-handling` → sincronizar con Rojo → Play en Studio.
- El usuario ya confirmó que Rojo conecta y los scripts arrancan. No atribuir estos defectos a Rojo sin evidencia.
- El usuario no programa; Claude debe inspeccionar y editar el repositorio directamente, con instrucciones simples. No pedirle que modifique Luau manualmente.

## Archivos clave
- `src/ServerScriptService/KartService.lua`: genera Beach Resort, waypoints, pista, pianos, barreras visibles y barreras invisibles de colisión, meta y checkpoints.
- `src/StarterPlayer/RaceHUD.client.lua`: HUD y dibujo del minimapa.

## Estado del circuito
- Pista activa: Beach Resort.
- `trackWidth = 30`.
- 28 waypoints contando el punto de cierre repetido (27 puntos únicos).
- 26 checkpoints más FinishLine.
- El usuario aprobó la expansión reciente del circuito; conservar el trazado y no reducirlo.
- Objetivo de juego: carreras de hasta 4 jugadores; dejar espacio para futuros ítems como bananas y bombas.

## Último error observado — captura del usuario (2026-11-08, 1623×542)
### 1. Barreras dentro de la pista
En la curva mostrada, la barrera metálica interior se mete sobre el asfalto y ocupa parte de la superficie de conducción. El usuario confirma que sigue ocurriendo tras el último cambio.

Diagnóstico de código conocido:
- Las barreras se calculan desde waypoints desplazados por un offset y se conectan mediante tramos rectos.
- Los pianos ya usan un recorrido redondeado con Bézier, pero las barreras no seguían esa misma trayectoria suavizada.
- Cada tramo también crea una barrera invisible de colisión; corregir solo los perfiles visuales no basta.

Cambio previo que NO solucionó el bug:
- Se corrigió el índice del waypoint anterior para el circuito cerrado, se aplicó el signo lateral a las normales y se limitó el miter.
- El usuario probó y mostró que la barrera continúa invadiendo el asfalto. No presentar ese cambio como solución.

Próximo trabajo:
- Inspeccionar el sentido real de las curvas y el lado interior/exterior.
- Generar una curva paralela suavizada para cada lado, no unir vértices miter con cuerdas rectas.
- Usar la misma trayectoria correcta para postes, perfiles y colisión invisible.
- Revisar ejes locales de CFrame, dimensiones y orientación de cada pieza.
- Comprobar todo el circuito por picos, cruces, huecos e invasiones. No aumentar el offset global a ciegas.

### 2. Unión gris sin borde negro en minimapa
En el minimapa de la captura, dos zonas grises se fusionan en una masa gris en una unión/curva cercana; el contorno negro esperado desaparece o queda visualmente oculto. El usuario confirma que sigue mal.

Implementación conocida:
- `RaceHUD.client.lua` dibuja tramos individuales de borde oscuro y asfalto gris a partir de `mapPoints`.
- También dibuja círculos de unión en los waypoints.
- El borde se dibuja antes que el asfalto.

Cambios previos que NO solucionaron el bug:
- Cambiar el orden de dibujo para pintar todos los bordes antes del asfalto y añadir círculos de unión.
- Aumentar grosores (borde 26, asfalto 16) y diámetros de unión.
- La captura posterior sigue mostrando la unión defectuosa. No repetir ajustes de grosor/orden como si fueran solución.

Próximo trabajo:
- Comparar todos los `mapPoints` con los waypoints reales de `KartService.lua`, en mismo orden y sin omisiones.
- Identificar segmentos no adyacentes que se acercan o solapan en el mapa.
- Distinguir si el solapamiento viene del trazado real, de los strokes, de los círculos de unión o de puntos mal ordenados.
- Preferir una silueta continua de carretera (polígono exterior oscuro + relleno gris interior) o una solución geométrica que preserve el borde en cruces cercanos.
- No agrandar más los círculos: pueden agrandar la mancha gris.

## Otros requisitos que deben preservarse
- El usuario confirmó que el drift con Shift funciona; se había definido activación sobre 8 studs/s y mantener mientras se sostiene Shift.
- No cambiar las cámaras: el usuario indicó que le gustan como están.
- HUD: velocidad a la derecha; no restaurar velocímetro inferior/central; número grande y KM/H pequeño; textos sin cajas opacas; minimapa opaco al 100%; tabla de posiciones baja para no chocar con iconos.
- Fuentes elegidas: Londrina Solid asset `113086061264643` para títulos/importantes; Rajdhani asset `12187375422` para secundarios.
- Evitar cambios no relacionados y regresiones en piloto, kart, handling, HUD o cámaras.
- Otros bugs históricos no necesariamente activos: reinicio del cronómetro tras vuelta 2; countdown visible desde 3 aunque cuente desde 5; humo de ruedas continuo; colisión lateral que lanzó el kart hacia el borde; modelo del piloto desapareció en una actualización anterior.

## Reglas para Claude
1. Inspeccionar el código actual antes de editar.
2. No afirmar que algo está corregido solo porque se modificó el código.
3. No repetir los cambios fallidos descritos arriba.
4. No pedir otra captura de inmediato: ya existe evidencia visual del 2026-11-08.
5. No culpar a Rojo sin evidencia.
6. Limitar el trabajo a geometría de barreras y geometría/dibujo del minimapa.
7. Entregar resumen, commit y pasos de prueba sencillos.
8. Decir claramente si falta validar en Roblox Studio.

## Tarea inmediata
Resolver exclusivamente:
- Barreras y colisión invisible siguiendo un offset suavizado correcto, sin invadir el asfalto.
- Unión del minimapa con borde negro continuo, tras validar la correspondencia de los puntos y los solapamientos.

La aceptación depende de que el usuario pruebe la versión en Roblox Studio. No declarar resuelto hasta entonces.

## Estado técnico al actualizar este documento
Los blobs verificados en la rama `recovery/stable-handling`:
- `KartService.lua`: `d0b33ea9851b96fbeb6b4d25b9ffae432da16845`
- `RaceHUD.client.lua`: `6812bcb23834c30f789ccb9a5ab9131201e597ed`

Son SHA de contenido de archivo, no el SHA del commit de la rama.
