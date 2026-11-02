# BLOXY KARTS - Project Context

Última actualización: 2 de noviembre de 2026

Motor: Roblox Studio (Luau)

Género: Arcade Kart Racing

Estudio: GamaKingStudio

Repositorio: https://github.com/GamaKingStudio/Block-Karts

Rama de trabajo actual: `recovery/stable-handling` (rama aislada para correcciones y validación del manejo y circuito).

Rama protegida: `main`

## 1. Para qué sirve este documento

Este documento transfiere el contexto técnico y de diseño de BLOXY KARTS entre los asistentes de IA que colaboran en el desarrollo del proyecto. Su objetivo es mantener una referencia centralizada sobre la visión del juego, su arquitectura, las funcionalidades implementadas, los problemas conocidos y las próximas prioridades.

Debe utilizarse como contexto del proyecto y no como una orden para modificar código inmediatamente.

### Regla principal de colaboración

**Gemini Director:** Copiloto de planificación y análisis. Evalúa ideas, analiza decisiones, propone soluciones, prioriza el desarrollo y prepara instrucciones técnicas concretas para Gemini Desarrollador. No debe afirmar que una funcionalidad está implementada o probada sin confirmación técnica.

**Gemini Desarrollador:** Responsable de la implementación técnica. Revisa el código existente, modifica los archivos necesarios, ejecuta validaciones, prueba los cambios que estén a su alcance y publica commits en GitHub. Debe actualizar `PROJECT_CONTEXT.md` cuando existan cambios relevantes en el estado del proyecto.

**ChatGPT:** Apoyo estratégico y segunda opinión. Ayuda a mantener la visión global, revisar decisiones de diseño y arquitectura, priorizar el desarrollo y resolver problemas complejos. No sustituye las responsabilidades de implementación y validación de Gemini Desarrollador.

**Usuario:** Director del proyecto y tester en Roblox Studio. Define las prioridades, aprueba las decisiones importantes y realiza las pruebas manuales necesarias. Requiere instrucciones claras y graduales para las tareas que impliquen acciones en su entorno local.

### Fuente oficial de información

El repositorio de GitHub es la fuente oficial del proyecto. Este documento debe mantenerse sincronizado con el estado real del código y las decisiones vigentes.

Cuando exista una diferencia entre lo documentado y el código, Gemini Desarrollador debe revisar el repositorio y confirmar el estado real antes de proponer una actualización.

Este documento no debe convertirse en un registro de conversaciones. Debe representar una fotografía clara y actualizada del proyecto.

## 2. Visión del juego

BLOXY KARTS es un juego de carreras arcade para Roblox, con estética low-poly inspirada en el lenguaje visual de Roblox y Minecraft, con identidad y recursos originales. El proyecto busca establecerse como un producto comercial del estudio GamaKingStudio.

### Pilares de diseño

- Conducción arcade accesible pero con curva de aprendizaje técnica.
- Carreras con contacto y colisiones físicas entre jugadores.
- Mecánicas de derrape (drifting) y turbo integradas en el core loop.
- Circuitos con identidad visual y legibilidad geométrica.
- Progresión basada en juego (evitar mecánicas pay-to-win).
- Estética low-poly geométrica y consistente.

### Modos previstos

- Carreras públicas y privadas (hasta 8 jugadores, 3 vueltas).
- Contrarreloj.
- Modos en evaluación (Eliminación, Batalla, Campeonato).

### Karts iniciales previstos

- Starter Kart.
- Mini Buggy.
- Monster Kart.
- Rocket Kart.

### Mundos/circuitos previstos

- Beach Resort (implementado en la rama de prototipo).
- Blocky Jungle.
- Lava Rush.
- Neon City.
- Frozen Peak.
- Candy World.

### Progresión futura

- Monedas y experiencia (XP).
- Desbloqueo de chasis y cosméticos.

**Restricción:** No implementar monetización ni sistemas de progresión antes de validar las mecánicas de conducción.

## 3. Principios técnicos y de desarrollo

### Arquitectura deseada

**Servidor:** Validaciones de lógica de juego (carreras, checkpoints, vueltas, recompensas). Construcción procedural de geometría (circuitos).

**Cliente:** Gestión de input local, cámara, interfaz de usuario (HUD), efectos visuales (VFX) y sonido (SFX). Cálculo de físicas locales mediante asignación de Network Ownership.

**Control:** Unificar la lógica de conducción en un único sistema. Evitar instanciación de controladores redundantes.

**Rendimiento:** Priorizar un recuento poligonal bajo y el uso eficiente de primitivas en Roblox.

### Reglas de trabajo

- Extender el proyecto existente; evitar reescrituras completas de módulos funcionales.
- Todo nuevo desarrollo debe integrarse en la rama de trabajo autorizada para la tarea. Para la iteración actual de recuperación y estabilidad se utiliza `recovery/stable-handling`.
- No realizar merges ni modificaciones en la rama `main` sin autorización explícita. Mantener los cambios de esta iteración exclusivamente en `recovery/stable-handling`.
- Mantener estricta compatibilidad con Rojo (versión 7.7.1).
- Limitar las tareas exploratorias autónomas para optimizar el consumo de recursos y tiempo de desarrollo.
- Antes de modificar código, revisar la implementación existente y sus dependencias.
- No reemplazar sistemas funcionales sin justificar técnicamente la necesidad.
- Mantener los cambios acotados a la tarea aprobada.

### Criterios para informar el estado técnico

Toda funcionalidad debe distinguirse según su estado:

- **Implementada:** existe una implementación en el código.
- **Validada:** se ejecutaron las comprobaciones técnicas correspondientes.
- **Probada en Studio:** se verificó manualmente su comportamiento dentro de Roblox Studio.
- **Pendiente:** todavía no está implementada.
- **Parcial:** existe una implementación, pero faltan componentes o validaciones.

No considerar una funcionalidad completamente validada solo porque el código se haya creado o porque no presente errores de sintaxis.

## 4. Herramientas y entorno

Servicios: Roblox Studio, VS Code, Git/GitHub, Rojo CLI 7.7.1.

**Terminal 1 (Rojo):** Ejecución de `rojo serve` en localhost (puerto 34872) para sincronización en tiempo real.

**Terminal 2 (Git):** Gestión de control de versiones (pull/push) en la rama `feature/kart-prototype`.

### Regla de entorno

- Verificar siempre la rama activa antes de realizar modificaciones.
- No trabajar accidentalmente sobre `main`.
- Mantener Rojo en la versión 7.7.1.
- Limpiar instancias como Baseplate o SpawnLocation genéricos de Roblox Studio antes de la generación del mapa para prevenir conflictos de físicas y superposición de mallas (Z-Fighting).
- No iniciar múltiples servidores Rojo sobre el mismo puerto.
- Mantener abierta la terminal de Rojo mientras Roblox Studio necesite sincronización.

## 5. Estado del prototipo y funcionalidades vigentes

El proyecto se encuentra en fase de prototipo jugable, con un circuito base y un sistema de físicas de karts funcional, según el estado técnico documentado.

### Tipografía e identidad visual del HUD

- `src/ReplicatedStorage/BloxyTypography.lua`: módulo central de tipografía. Expone los roles `Bold` y `Light` para mantener una jerarquía consistente en la interfaz.
- **Jerarquía prevista:** Bold para cuenta regresiva, vuelta actual, cronómetro, velocidad, avisos y títulos de panel; Light para etiquetas, unidades, checkpoints, mejor tiempo y filas informativas.
- **Estado actual:** la integración del HUD utiliza temporalmente la familia nativa Gotham SSm con pesos Bold y Light mediante `FontFace`. Los archivos BLOXY `.ttf` del usuario aún no están incorporados como assets de Roblox; por tanto, la tipografía BLOXY real está pendiente de publicación/obtención de IDs y sustitución de la familia de respaldo. No se han inventado IDs ni se afirma que BLOXY esté aplicada.

### Archivos principales en uso

- `src/ServerScriptService/KartService.lua`: Controlador del servidor. Gestiona la generación del entorno, spawn de jugadores y ensamblaje de los karts; carga el modelo original de palmera publicado en Roblox y conserva un respaldo procedural.
- `src/ServerScriptService/KartBootstrap.server.lua`: Punto de entrada del servidor.
- `src/ReplicatedStorage/KartConfig.lua`: Módulo de datos (parámetros físicos, multiplicadores, configuración de cámara).
- `src/ReplicatedStorage/BloxyTypography.lua`: Roles tipográficos centralizados para el HUD (respaldo Gotham SSm hasta disponer de los assets BLOXY publicados).
- `src/StarterPlayer/KartControls.client.lua`: Lógica del cliente. Captura de inputs y aplicación de fuerzas físicas.

### Sistemas implementados según el estado documentado

**Ensamblaje del Kart:** Generación por código a través de KartService. Utiliza un bloque central (Chassis) para los cálculos de colisión y física. Las mallas decorativas (incluyendo las ruedas) tienen la propiedad `CanCollide = false`.

**Física Custom:** El desplazamiento se logra aplicando un `VectorForce` sobre el Chassis.

**Controles (Cliente):** Input digital para Aceleración/Reversa (W/S), Dirección (A/D), Freno (Espacio) y Derrape (Shift).

**Cámara Scriptable:** Sistema de interpolación de cámara posicionado detrás del kart, con look-ahead calculado en base a la velocidad lineal.

**Network Ownership:** El servidor delega la autoridad de cálculo físico del kart al cliente respectivo en el instante en que el Humanoid ocupa el VehicleSeat.

### Sistema de Derrape (Drift Mode)

**Condición de activación:** Tecla Shift presionada y velocidad mayor a 8 studs/seg.

**Comportamiento:** El parámetro de agarre lateral se reduce a un factor de 0.25. El límite angular (yaw rate) aumenta a 1.6x.

**Mini-Turbo:** Tras 0.8 segundos de derrape continuo, al liberar el input se aplica un impulso longitudinal temporal (duración: 0.75s, multiplicador de aceleración: 1.45x, aumento de velocidad máxima: 1.25x).

### Manejo de Spawn

Prevención de physics fling teletransportando al personaje a un offset vertical relativo al asiento (Y = +4 studs) y forzando el estado Sit.

### Control de errores de instanciación

Lógica de abstracción en la función `makePart` para traducir literales de forma (ej. "Cylinder", "Ball") al enumerador `Enum.PartType` correspondiente, evitando llamadas inválidas a `Instance.new()`.

**Nota de validación:** Los sistemas descritos corresponden al estado técnico registrado en este documento. Su funcionamiento debe considerarse confirmado únicamente hasta el nivel de pruebas que haya sido efectivamente realizado. Las pruebas manuales pendientes deben registrarse como tales.

## 6. Diseño del circuito (Beach Resort)

El circuito se compila proceduralmente en tiempo de ejecución (RunTime) a través del servidor.

### Arquitectura de geometría

**Capa Física Unificada:** Terreno definido por un bloque estático (IslandSand) con coordenada Y fijada en 1.0. Las partes visuales de la pista carecen de propiedades de colisión geométrica.

**Trazado de Asfalto:** Nodos de trayectoria conectados mediante partes rectangulares, utilizando partes cilíndricas sin colisión en los vértices para redondear las esquinas y evitar superposición de texturas y geometría intersecante.

**Mitigación de Z-Fighting:** Escalado micrométrico en el eje Y (deltas de ~0.02 studs) para separar arena, asfalto, marcas viales y límites de pista.

**Pianos y guardarraíles (estado de la rama `recovery/stable-handling`):** Pianos alternados rojo/blanco de 1.6 studs de ancho, con recorrido redondeado mediante curvas Bézier y muestreo de 12 pasos; el usuario confirmó que su apariencia quedó correcta. Guardarraíles metálicos continuos con postes y dos perfiles horizontales; el usuario confirmó que quedaron perfectos. No modificar estos elementos aprobados sin una solicitud expresa.

**Relleno de arena en uniones (pendiente):** Se probaron discos cilíndricos de arena centrados en los waypoints para cubrir huecos entre el asfalto y los pianos. La primera versión quedó oculta bajo `IslandSand`; al elevarla, produjo grandes círculos de arena e interferencia visual en las curvas, según la prueba del usuario. Se retiró por completo ese bloque de discos en el commit actual. El relleno correcto sigue pendiente y debe ajustarse a la geometría real del borde de pista, sin círculos completos ni solapamientos. No modificar los pianos ni guardarraíles aprobados.

### Elementos estructurales

**Pit Lane (Calle de Boxes):** Carril paralelo al sur de la recta principal. Incluye muro divisor físico, cajones de detención, un WedgePart para sellar la geometría en la entrada y un carril de incorporación fluida a la vía principal.

**Arco de Meta (Gantry):** Estructura en voladizo soportada por pilares exteriores (X=0), ubicada inmediatamente después de la reincorporación de la calle de boxes, impidiendo bloqueos del carril.

**Atrezo (Props):** Generación procedural de kioskos (madera, tela, iluminación Neon/PointLight), graderías, pasarelas, barreras de neumáticos y antorchas Tiki.

**Vegetación:** `KartService.lua` carga el modelo original `palmera.fbx`, publicado en Roblox Studio como asset `139237715567825`, mediante `InsertService:LoadAsset`. Cada instancia se clona y normaliza según su altura real para quedar aproximadamente entre 14 y 17 studs, se posiciona usando el bounding box y se mantiene anclada, sin colisión/contacto/consulta y como masa nula. El código conserva los colores, materiales y texturas del modelo importado; no aplica recoloración automática. Si la carga o el escalado falla, se genera la palmera procedural de respaldo y se emite una advertencia en Output. La integración requiere validación visual en Roblox Studio para confirmar apariencia, permisos de carga, orientación, escala y apoyo sobre el suelo. Las ubicaciones perimetrales se conservan.

### Registro de integración de palmera (2 de noviembre de 2026)

- El usuario publicó desde Blender/Roblox Studio una versión completa del modelo de palmera (no solamente el Mesh), con asset ID `139237715567825`. El usuario confirmó que la importación completa corrigió el problema de geometría/apariencia del modelo.
- `KartService.lua` utiliza ese asset ID y conserva la normalización de altura, el ajuste por bounding box, el pivote y el respaldo procedural.
- En la prueba posterior, el usuario detectó que toda la palmera aparecía verde. La causa identificada en el código era la recoloración automática de cada `BasePart`, junto con la asignación forzada de `SmoothPlastic`.
- Cambio de esta actualización: se eliminó la recoloración y la sustitución forzada de materiales del modelo importado. El script ahora conserva los colores, materiales y texturas configurados en el asset y solo ajusta propiedades físicas (anclaje, colisión, contacto, consulta y masa).
- No se ha ejecutado Roblox Studio después de este cambio. La conservación de la apariencia original está implementada en código, pero queda pendiente la comprobación visual en Play.
- Archivos modificados: `src/ServerScriptService/KartService.lua` y `PROJECT_CONTEXT.md`.

## 7. Historial de problemas críticos resueltos

Los siguientes problemas figuran como resueltos en el historial técnico del proyecto. Si una modificación posterior los reproduce, deben investigarse sin asumir que la solución anterior sigue siendo suficiente.

- **Colisión invisible al reentrar a la pista:** Solucionado al separar la lógica visual de la física. El asfalto se configuró como `CanCollide = false` sobre el plano de arena continuo.
- **Desaparición del Kart por Race Conditions (Fling):** Mitigado mediante la eliminación de SpawnLocation de Roblox y la implementación de un bucle de confirmación para el evento de sentar al Humanoid.
- **Z-Fighting en superficies:** Resuelto con deltas verticales controlados.
- **Crash del servidor (Cannot Destroy() Terrain):** Controlado al introducir una condicional explícita que impide llamadas de recolección de basura sobre el objeto Workspace.Terrain.
- **Crash por instanciación inválida (Instance.new("Cylinder")):** Corregido mediante el mapeo del string al Enum.PartType en el bloque de utilidades.
- **Invasión del carril por Props:** Las palmeras, tablas de surf y antorchas Tiki fueron reasignadas a coordenadas perimetrales absolutas. La calcomanía del SpawnLocation base se eliminó sistemáticamente.

## 8. Próximos pasos (Roadmap técnico)

### Fase actual: validación visual del circuito y sistemas de lógica de carrera

- **Palmeras del Beach Resort:** el asset completo `139237715567825` se carga dinámicamente y se normaliza por altura real (objetivo aproximado 14–17 studs), con ajuste por bounding box y respaldo procedural. El código conserva los colores, materiales y texturas del modelo importado; se eliminó la recoloración automática que dejaba toda la palmera verde. Pendiente probar en Roblox Studio para confirmar colores, materiales, tamaño, orientación y apoyo en el suelo.

- Diseñar e implementar un relleno de arena localizado entre el borde real del asfalto y los pianos, sin discos circulares completos.
- Validar visualmente en Roblox Studio que las uniones de curvas no presenten huecos, círculos ni interferencias.

**Interfaz de Usuario (HUD):**
- Cronómetro, contador de vueltas, telemetría local, clasificación y minimapa implementados en `RaceHUD.client.lua` según el código actual.
- Jerarquía tipográfica Bold/Light centralizada e integrada con `FontFace`, usando Gotham SSm como respaldo temporal.
- Pendiente: publicar/obtener los IDs de BLOXY Bold y BLOXY Light e incorporarlos en `BloxyTypography.lua`; validar visualmente el resultado en Roblox Studio.

**Sistema de Checkpoints (Backend):**
- Zonas de validación vectoriales (invisibles) para certificar vueltas válidas.
- Control de sentido de giro.
- Puntos de reaparición (respawn).

### Fase futura

**VFX (Sistemas de partículas):**
- Emisores de partículas para desgaste de neumáticos.
- Efectos de colisiones.
- Estelas de arena.
- Efectos de carga y liberación del Mini-Turbo.

**Audio (SFX/BGM):**
- Implementación de modulación de Pitch/Volume del motor vinculada a la AssemblyLinearVelocity.
- Triggers de audio para eventos (derrape, meta, choque).

**Metajuego y sesión:**
- Sistema de Lobby de espera.
- Persistencia de datos de usuario (selección de karts, inventario).
- Lógica de emparejamiento (Matchmaking).

### Criterio de prioridad

La prioridad es consolidar primero la experiencia de conducción y el ciclo principal de carrera. No avanzar hacia progresión, monetización o sistemas secundarios hasta contar con una base de conducción y competición satisfactoria.

## 9. Directrices de colaboración para los asistentes de IA

### Gemini Director

- Leer el documento completo antes de proponer cambios.
- Mantener la visión global del proyecto y sus prioridades.
- Analizar las solicitudes del usuario y convertirlas en tareas técnicas concretas.
- Preparar instrucciones acotadas para Gemini Desarrollador.
- No modificar ni inventar el estado técnico del proyecto.
- No afirmar que una funcionalidad está implementada o probada sin confirmación.
- Mantener separados los objetivos de diseño, las propuestas y las decisiones aprobadas.
- No solicitar reescrituras completas si es posible extender los sistemas existentes.

### Gemini Desarrollador

- Revisar el estado real del repositorio antes de implementar una tarea.
- Confirmar la rama activa autorizada para la tarea; en la iteración actual es `recovery/stable-handling`.
- No modificar `main` ni realizar merges sin autorización explícita. Para la iteración actual, trabajar solo en `recovery/stable-handling`.
- Revisar los archivos y dependencias involucrados antes de realizar cambios.
- Implementar únicamente el alcance aprobado.
- Mantener compatibilidad con Rojo 7.7.1.
- Ejecutar las validaciones técnicas disponibles y reportar sus resultados.
- No declarar pruebas manuales en Roblox Studio si no se realizaron.
- No eliminar información o funcionalidades existentes sin justificarlo.
- Documentar los cambios relevantes en `PROJECT_CONTEXT.md`.

### ChatGPT

- Actuar como apoyo estratégico y segunda opinión.
- Revisar decisiones de arquitectura, diseño y priorización.
- Ayudar a detectar riesgos, contradicciones y problemas de planificación.
- Mantener coherencia entre la visión del juego y las decisiones técnicas.
- No asumir que una propuesta fue implementada hasta contar con confirmación.

### Actualización de PROJECT_CONTEXT.md

Este documento es la referencia central del proyecto y debe mantenerse actualizado sin alterar innecesariamente su estructura.

Cuando una tarea produzca cambios relevantes, Gemini Desarrollador debe:

1. Actualizar el documento original, no crear otro documento con una estructura diferente.
2. Conservar los títulos, la organización y el propósito de las secciones existentes.
3. Mantener la información técnica que siga siendo válida.
4. Incorporar las funcionalidades nuevas y los cambios confirmados.
5. Actualizar los problemas resueltos, pendientes y decisiones vigentes.
6. Diferenciar claramente entre implementado, validado y probado en Roblox Studio.
7. No inventar resultados de pruebas ni asumir que un cambio funciona por el mero hecho de estar implementado.
8. Evitar duplicaciones y eliminar información únicamente cuando haya quedado obsoleta o sea incorrecta.
9. Mantener un estilo técnico sobrio, sin emojis, iconos decorativos ni elementos innecesarios.
10. Entregar el documento completo en formato Markdown, listo para reemplazar el archivo existente.

La actualización debe incluir la fecha correspondiente y reflejar el estado real del repositorio.

### Directrices de respuesta

Al redactar instrucciones o entregar bloques de código al usuario:

**Precisión:** Instrucciones acotadas, modulares y limitadas al requerimiento en curso.

**Código formateado:** Los bloques de código deben ser provistos de forma íntegra y listos para sustituir archivos existentes cuando corresponda. No utilizar fragmentos inconexos que dificulten su implementación.

**Gestión de entorno:** Exigir siempre la verificación de la rama activa (`feature/kart-prototype`). Proteger la integridad de la rama `main`.

**Accesibilidad:** Documentar los cambios en el código sin abusar de tecnicismos innecesarios; mantener un tono directo.

**Transparencia:** Si una implementación conlleva riesgos o requiere QA manual intensivo en Studio, debe ser advertido explícitamente antes de proceder.


### Actualización de integración de palmera (2 de noviembre de 2026)

- El usuario publicó una nueva versión unificada de la palmera desde Blender/Roblox Studio con asset ID `139237715567825`. El modelo se ve correctamente en Studio según confirmación del usuario.
- Se detectó que `KartService.lua` todavía apuntaba al asset anterior `91776332943612`; por tanto, el juego no estaba cargando el modelo nuevo.
- Cambio aplicado en esta actualización: `PALM_ASSET_ID` debe apuntar a `139237715567825`. Se conserva sin cambios la lógica actual de normalización de altura, pivote, posicionamiento y respaldo procedural para aislar la causa antes de ajustar escala o bounds.
- No se ha probado todavía la carga del nuevo asset dentro de la experiencia ni su apariencia en Play de Roblox Studio. El reporte de menor lag del usuario es preliminar; la apariencia anómala debe reevaluarse una vez que el juego cargue el ID correcto.
- Archivos de esta actualización: `src/ServerScriptService/KartService.lua` y `PROJECT_CONTEXT.md`.


### Actualización de preservación visual de palmera (2 de noviembre de 2026)

- Se eliminó de `spawnImportedPalm` el bloque que asignaba colores según nombre/altura y forzaba `Enum.Material.SmoothPlastic` en todas las piezas.
- El modelo importado conserva ahora los atributos visuales definidos en el asset. El script solo modifica propiedades físicas necesarias para el entorno.
- Pruebas realizadas: revisión del código fuente y comprobación de que el bloque anterior de recoloración fue sustituido. No se ejecutó Roblox Studio ni una prueba de runtime.
- Estado: cambio preparado para validación visual en Studio; no afirmar todavía que el resultado visual quedó confirmado.


### Actualización de ID de palmera y sincronización (2 de noviembre de 2026)

- El usuario confirmó que la palmera que debe utilizar el juego es el asset `139237715567825`, que actualmente se ve completamente verde dentro de la experiencia.
- Se actualizó `src/ServerScriptService/KartService.lua` para cargar ese ID, manteniendo la corrección anterior que preserva los colores, materiales y texturas originales del modelo importado.
- Se conserva la configuración física de las piezas, la normalización de escala, el posicionamiento por bounding box y el respaldo procedural.
- El cambio de ID y la preservación visual están implementados en el código del repositorio. Todavía no se ha probado la carga ni la apariencia en Roblox Studio; esa validación queda pendiente.
- Se registra que la carpeta local del usuario tenía este cambio de ID sin commit, lo que impidió ejecutar `git pull`. La solución se publica directamente en `recovery/stable-handling` para que, al actualizar localmente, ambas correcciones queden integradas.
- Archivos modificados: `src/ServerScriptService/KartService.lua` y `PROJECT_CONTEXT.md`.
- Pruebas realizadas: inspección del diff y comprobación del ID configurado y de que el bloque de recoloración/forzado de material no está presente. No se ejecutó Roblox Studio ni pruebas de runtime.


### Actualización de palmera separada en tronco y hojas (2 de noviembre de 2026)

- El usuario importó desde Blender a Roblox Studio una nueva versión del modelo y confirmó que el asset publicado tiene ID `139237715567825`.
- El modelo ahora contiene dos piezas independientes confirmadas por el usuario: `Palm_Trunk` (tronco) y `Palm_Leaves` (hojas).
- Se actualizó `src/ServerScriptService/KartService.lua` para cargar el nuevo ID. La lógica existente clona el modelo y configura las propiedades físicas de cada descendiente `BasePart`, por lo que ambas piezas quedan incluidas sin requerir una reconstrucción del modelo.
- Se conserva la apariencia importada: el código no recolorea las piezas ni fuerza un material visual.
- Estado: ID y estructura del asset confirmados por el usuario en Roblox Studio; integración de código publicada pendiente de prueba dentro de la experiencia. No se ha confirmado todavía que las dos piezas conserven sus materiales/texturas al cargar mediante `InsertService:LoadAsset`.
- Archivos modificados: `src/ServerScriptService/KartService.lua` y `PROJECT_CONTEXT.md`.
- Pruebas realizadas: inspección del código y confirmación del usuario sobre los nombres de las dos piezas en el modelo importado. No se ejecutó Roblox Studio ni una prueba de runtime.
