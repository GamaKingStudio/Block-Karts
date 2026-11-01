# 🏎️ BLOXY KARTS - Project Context

**Última actualización:** Noviembre de 2026  
**Motor:** Roblox Studio (Luau)  
**Género:** Arcade Kart Racing
**Estudio:** GamaKingStudio  
**Repositorio:** https://github.com/GamaKingStudio/Block-Karts  
**Rama de trabajo:** `feature/kart-prototype`  
**Rama protegida:** `main`

---

## 1. Para qué sirve este documento

Este documento transfiere a Gemini el contexto del desarrollo de **BLOXY KARTS** para que pueda colaborar en el análisis técnico, la planificación y la preparación de instrucciones para Manus.

Gemini debe leerlo como contexto del proyecto, no como una orden para modificar código inmediatamente.

### Regla principal de colaboración
- **Gemini:** copiloto técnico cotidiano. Analiza código, propone soluciones, revisa decisiones y redacta instrucciones (o código directo) para el usuario.
- **ChatGPT:** apoyo para mantener la visión global, priorizar el desarrollo, revisar decisiones y resolver problemas complejos.
- **Manus:** desarrollador que modifica el repositorio, implementa cambios y publica commits en GitHub (si aplica).
- **Usuario:** director del proyecto y tester en Roblox Studio. Tiene poca experiencia programando y necesita instrucciones claras, graduales y sin asumir conocimientos técnicos.

---

## 2. Visión del juego

BLOXY KARTS es un juego de carreras arcade para Roblox, con estética blocky/low-poly inspirada en el lenguaje visual de Roblox y Minecraft, pero con identidad y recursos originales.

La intención es crear un producto de estudio, no solamente un prototipo personal. El proyecto pertenece a la futura marca de videojuegos **GamaKingStudio**.

### Pilares de diseño
- Fácil de aprender, difícil de dominar.
- Conducción arcade divertida y accesible.
- Carreras con contacto y colisiones entre jugadores.
- Derrapes y turbo como mecánicas importantes.
- Circuitos coloridos, reconocibles y con personalidad.
- Progresión y desbloqueos sin ventajas de pago injustas.
- Estética blocky, geométrica, atractiva y consistente.

### Modos previstos
- Carreras públicas y privadas.
- Hasta 8 jugadores.
- Carreras de 3 vueltas.
- Contrarreloj.
- Eliminación, Batalla, Campeonato (futuros).

### Karts iniciales previstos
- Starter Kart.
- Mini Buggy, Monster Kart, Rocket Kart.

### Mundos/circuitos previstos
1. **Beach Resort (Actualmente implementado como pista principal)**
2. Blocky Jungle
3. Lava Rush
4. Neon City
5. Frozen Peak
6. Candy World

### Progresión futura
- Monedas y XP.
- Desbloqueo de karts y cosméticos.
- **No implementar monetización ni sistemas de progresión complejos antes de validar que conducir y competir sea divertido.** Evitar pay-to-win.

---

## 3. Principios técnicos y de desarrollo

### Arquitectura deseada
- **Servidor:** valida carreras, checkpoints, vueltas, recompensas, objetos y compras. Construye proceduralmente el circuito.
- **Cliente:** gestiona entrada del jugador, cámara, interfaz, efectos visuales y sonido. Realiza la física local mediante *Network Ownership*.
- Usar predicción del cliente cuando sea apropiado, sin confiar al cliente la validación de recompensas.
- Mantener un único sistema de conducción y evitar duplicar asientos o controladores.
- Priorizar rendimiento y geometría sencilla en Roblox.

### Reglas de trabajo
1. Trabajar sobre el proyecto existente; no reescribirlo desde cero.
2. Todas las implementaciones de Manus deben ir a `feature/kart-prototype`.
3. No modificar `main` salvo autorización explícita.
4. Mantener compatibilidad con Rojo 7.7.1.
5. Evitar tareas exploratorias amplias y prompts repetidos: los créditos de Manus son limitados.

---

## 4. Herramientas y entorno

- **Servicios:** Roblox Studio, VS Code, Git/GitHub, Rojo CLI 7.7.1.
- **Terminal 1 (Rojo):** `rojo serve` en puerto 34872.
- **Terminal 2 (Git):** Descarga/publicación de cambios en `feature/kart-prototype`.
- Se requiere limpiar cualquier `Baseplate` o `SpawnLocation` de Roblox Studio para evitar conflictos de Z-Fighting y físicas.

---

## 5. Estado del prototipo y Funcionalidades Vigentes

El proyecto cuenta con un circuito jugable y karts funcionales. 

### Archivos principales activos
- `src/ServerScriptService/KartService.lua` (Generador de pista, spawn y ensamblaje del kart)
- `src/ServerScriptService/KartBootstrap.server.lua`
- `src/ReplicatedStorage/KartConfig.lua` (Constantes físicas y cámara)
- `src/StarterPlayer/KartControls.client.lua` (Controles de conducción y derrape)

### Sistemas Implementados
- **Ensamblaje del Kart:** Generado por código. El kart no usa ruedas con fricción real; el `Chassis` se desliza usando un `VectorForce`. Ruedas visuales `CanCollide = false`.
- **Controles (Cliente):** Aceleración/Reversa, Giro, Freno y Derrape (Shift).
- **Cámara Scriptable:** Interpolación suave desde atrás del kart (`CameraLookAhead`).
- **Network Ownership:** Servidor delega la física del kart al cliente tan pronto el jugador se sienta, eliminando la latencia de conducción.
- **Derrape (Drift Mode):** Presionando Shift se reduce el agarre lateral al 25% y se incrementa el giro (yaw rate) al 160%. Si el derrape se sostiene más de 0.8s, genera un Mini-Turbo al soltar la tecla.
- **Spawn Robusto:** El jugador es teletransportado 4 studs sobre el asiento en caída limpia para evitar fuerzas extremas de penetración (*physics fling*).
- **Prevención de Errores Críticos:** Filtros en `makePart` evitan crasheos al instanciar partes (`Cylinder` y `Ball` se asocian a la propiedad `Shape`). Exclusión del `Terrain` al limpiar el mapa previo.

---

## 6. Diseño del Circuito "Beach Resort"

El mapa se construye proceduralmente al ejecutar la partida (cero lag de diseño en Studio):
- **Capa Física (Suelo unificado):** Una gran placa plana de arena en `Y = 1.0`. Toda la pista, asfalto y pianos tienen `CanCollide = false` para asegurar una conducción suave, sin escalones ni tropiezos.
- **Trazado de Asfalto (Anti Z-Fighting):** Vértices curvos (Cylinders) unen las rectas para eliminar cortes angulares abruptos y texturas cruzadas ("tijeras"). Las líneas blancas se sitúan milímetros por encima.
- **Infraestructura de Pits:** Una calle paralela a la recta de meta con un muro divisor (blanco/rojo). Cuenta con cajones de estacionamiento, entrada fluida sellada con un `WedgePart`, y una salida diagonal que se reincorpora suavemente al asfalto antes de la línea de meta.
- **Pórtico de Meta:** Estructura de madera con viga transversal libre de recortes geométricos, situada en `X = 0` (tras la salida de pits). Damero blanco y negro integrado en la pista.
- **Atmósfera Tropical:** Iluminación ajustada por código (ClockTime 15.0), océano infinito de dos tonos, dunas perimetrales de arena, pasarelas de madera y antorchas Tiki encendidas.
- **Mobiliario:** Kioskos realistas de playa (madera con toldo inclinado de tela), cabañas con techos de paja, sillas y sombrillas, todos colocados a una distancia segura de la calzada (mínimo 20 studs de margen).

---

## 7. Historial de Problemas Críticos Resueltos

1. **Colisión invisible al reentrar a la pista:** Solucionado convirtiendo todo el asfalto en visual (`CanCollide = false`) sobre una base física continua.
2. **Desaparición del Kart al spawnear (Fling):** Solucionado eliminando `SpawnLocation` conflictivos y sentando al personaje desde el aire, sin anclar permanentemente el chasis.
3. **Z-Fighting (Parpadeo) en Arena y Pista:** Resuelto ajustando minúsculamente el eje Y de las capas superpuestas.
4. **Cannot Destroy() Terrain:** El servidor crasheaba al limpiar el mapa porque intentaba borrar el terreno nativo de Roblox. Añadida excepción explícita.
5. **Crasheo por "Cylinder":** La función constructora fallaba porque `Cylinder` no es una Instance válida; modificado para asignar `Enum.PartType.Cylinder` a un `Part` estándar.
6. **Palmeras invasoras y sombras estrelladas:** Resuelto separando los elementos de vegetación a más de 20 studs de la calzada, y forzando la eliminación de la calcomanía del *SpawnLocation* oficial de Studio.

---

## 8. Próximos Pasos (To-Do)

### Fase Actual (HUD y Sistemas de Carrera)
- [ ] **HUD de Interfaz de Usuario:** Implementar velocímetro, cronómetro y contador de vueltas.
- [ ] **Sistema de Checkpoints:** Lógica invisible en el circuito para registrar tiempos de vuelta válidos, controlar reapariciones y evitar atajos.

### Fase Futura
- [ ] **VFX y Partículas:** Humo de escape, estelas de polvo al pisar la arena, y chispas de colores durante la fase de carga del mini-turbo.
- [ ] **Audio:** Efectos de motor adaptados a la velocidad angular, sonido de derrape y música de fondo.
- [ ] **Progresión:** Lobby, selección de kart, garaje y tienda de desbloqueos.

---

## 9. Cómo debe ayudar Gemini

Gemini debe actuar como copiloto técnico y colaborar con el usuario de manera práctica.

### Al redactar instrucciones o entregar código
- Ser concretos y acotados. Enfocarse en resolver una etapa por vez.
- Entregar bloques de código completos y listos para copiar/pegar si el usuario los va a insertar directamente.
- Exigir trabajar en `feature/kart-prototype` y proteger `main`.
- Evitar jerga sin explicación. No asumir conocimientos de programación avanzados en el usuario.
- Ser transparente sobre lo que no se ha probado.

**Meta general:** Convertir el prototipo actual en un juego de carreras arcade blocky atractivo, divertido y técnicamente estable, construyendo de forma incremental y preservando el trabajo ya logrado.
