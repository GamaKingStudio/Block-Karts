# BLOXY KARTS - Project Context

Última actualización: 3 de noviembre de 2026

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

**ChatGPT:** Apoyo estratégico y técnico, incluida la implementación directa cuando se solicite. Antes de proponer o ejecutar cualquier cambio debe leer PROJECT_CONTEXT.md completo y revisar el código actual relacionado. Debe comprobar si la funcionalidad o corrección ya existe para evitar duplicar trabajo o revertir decisiones aprobadas. No debe afirmar pruebas en Studio que no haya realizado.

**Usuario:** Director del proyecto y tester en Roblox Studio. Define prioridades y realiza las pruebas manuales. El acuerdo de trabajo vigente es que ChatGPT implemente directamente las tareas ya acordadas, publique los cambios en la rama autorizada y entregue el comando `git pull`; no debe pedir aprobación para cada paso técnico. Solo debe detenerse y consultar si aparece un riesgo grave, una decisión de producto no acordada o un bloqueo que requiera una acción del usuario en Studio.

### Fuente oficial de información

El repositorio de GitHub es la fuente oficial del proyecto. Este documento debe mantenerse sincronizado con el estado real del código y las decisiones vigentes.

Cuando exista una diferencia entre lo documentado y el código, Gemini Desarrollador debe revisar el repositorio y confirmar el estado real antes de proponer una actualización.

Este documento no debe convertirse en un registro de conversaciones. Debe representar una fotografía clara y actualizada del proyecto.

## Fuente única de verdad y flujo seguro GitHub → Rojo → Studio (acuerdo vigente: 3 de noviembre de 2026)

**GitHub es la fuente oficial y el punto de recuperación del proyecto.** La rama de trabajo autorizada para esta etapa es `recovery/stable-handling`; `main` permanece protegida y no se modifica sin autorización expresa.

### Reglas obligatorias

1. Antes de cada tarea, revisar este documento completo, confirmar la rama remota y revisar los archivos afectados.
2. Todo cambio de código o configuración se realiza primero en los archivos versionados del repositorio y se publica mediante un commit identificable en `recovery/stable-handling`.
3. No considerar un cambio parte de la versión oficial hasta que el commit esté publicado en GitHub.
4. Roblox Studio se utiliza para abrir, ejecutar y validar visualmente el proyecto. No se debe asumir que una modificación manual hecha en Studio se guarda automáticamente en GitHub.
5. Si se realiza una modificación manual en Studio, debe trasladarse a los archivos fuente correspondientes o guardarse como un respaldo de proyecto versionado antes de considerarla parte oficial. No dejar cambios únicos importantes únicamente en una sesión local de Studio.
6. Rojo 7.7.1 sincroniza los directorios declarados en `default.project.json` desde el árbol local hacia Studio. No es un mecanismo de publicación Studio → GitHub ni un sistema de respaldo. No iniciar una sincronización sin comprobar primero rama, estado de Git y archivos que se van a sincronizar.
7. Antes de conectar Rojo o aplicar una sincronización: confirmar que la copia local está en `recovery/stable-handling`, traer los commits remotos previstos, revisar cualquier cambio local y guardar un respaldo `.rbxl` cuando el hito visual lo amerite. Nunca sobrescribir cambios locales sin revisarlos.
8. Después de validar una modificación en Studio, registrar el resultado en `PROJECT_CONTEXT.md` y publicar esa actualización en el mismo flujo de commits.
9. Cada tarea debe terminar indicando rama, commit publicado, archivos modificados, estado de validación (estática / Studio) y el comando exacto para actualizar la copia local.
10. No declarar que el mapa completo está respaldado en GitHub solo porque el código fuente esté publicado. Confirmar que los archivos y assets necesarios están versionados o que existe un respaldo `.rbxl` publicado por separado.

### Alcance de Rojo en este proyecto

El archivo `default.project.json` mapea `src/ReplicatedFirst`, `src/ReplicatedStorage`, `src/ServerScriptService` y `src/StarterPlayer` a sus servicios correspondientes de Roblox. Los objetos que se creen manualmente en Studio fuera de esos archivos/mapeos no quedan versionados automáticamente por ese mecanismo.

**Principio operativo:** GitHub → copia local Git → Rojo → Roblox Studio. Para incorporar cambios originados en Studio, primero se deben convertir en archivos fuente o en un respaldo versionado; nunca asumir una sincronización inversa automática.

---

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

**Terminal 2 (Git):** Gestión de control de versiones. La rama de trabajo vigente para esta iteración es `recovery/stable-handling`; no asumir que la rama local coincide sin verificarla.

### Regla de entorno

- Verificar siempre la rama activa antes de realizar modificaciones. Para las tareas actuales, utilizar `recovery/stable-handling`, salvo que el usuario autorice otra rama.
- No trabajar accidentalmente sobre `main`.
- Mantener Rojo en la versión 7.7.1.
- Limpiar instancias como Baseplate o SpawnLocation genéricos de Roblox Studio antes de la generación del mapa para prevenir conflictos de físicas y superposición de mallas (Z-Fighting).
- No iniciar múltiples servidores Rojo sobre el mismo puerto.
- Mantener abierta la terminal de Rojo mientras Roblox Studio necesite sincronización.

## 5. Estado del prototipo y funcionalidades vigentes

El proyecto se encuentra en fase de prototipo jugable, con un circuito base y un sistema de físicas de karts funcional, según el estado técnico documentado.

### Tipografía e identidad visual del HUD

- `src/ReplicatedStorage/BloxyTypography.lua`: módulo central de tipografía. Expone los roles `Title` (Highway, alternativa condensada tipo Impact), `Bold` y `Light` para mantener una jerarquía consistente en la interfaz.
- **Jerarquía vigente:** Title (Highway) para títulos principales de panel y avisos destacados; Bold para cronómetro, velocidad y datos con énfasis; Light para unidades, checkpoints, mejor tiempo y filas informativas.
- **Estado actual:** `Title` utiliza la fuente nativa `Highway` como alternativa condensada y pesada al estilo Impact; `Bold` utiliza GothamBold y `Light` utiliza GothamMedium. Los archivos BLOXY `.ttf` del usuario aún no están incorporados como assets de Roblox; la tipografía BLOXY propia sigue pendiente de publicación/obtención de IDs. No se han inventado IDs ni se afirma que BLOXY esté aplicada.

### Archivos principales en uso

- `src/ServerScriptService/KartService.lua`: Controlador del servidor. Gestiona la generación del entorno, spawn de jugadores y ensamblaje de los karts; carga el modelo original de palmera publicado en Roblox y conserva un respaldo procedural.
- `src/ServerScriptService/KartBootstrap.server.lua`: Punto de entrada del servidor.
- `src/ReplicatedStorage/KartConfig.lua`: Módulo de datos (parámetros físicos, multiplicadores, configuración de cámara).
- `src/ReplicatedStorage/BloxyTypography.lua`: Roles tipográficos centralizados para el HUD: `Title` (Highway), `Bold` (GothamBold) y `Light` (GothamMedium).
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

**Arco de Meta (Gantry):** Se reemplazó la estructura procedural completa (ambos postes, viga y panel/banner) por el modelo importado del usuario, asset Roblox `132205617373322`. El modelo se rota 90° sobre el eje Y para orientar su vano transversalmente sobre la pista, se escala proporcionalmente para cubrir el ancho, se centra en la recta de meta y se apoya por su bounding box sobre el nivel del circuito. Sus piezas quedan ancladas y sin colisión, contacto ni consulta para no interferir con los karts. No se genera una línea de meta decorativa en el suelo con este asset; la lógica de carrera/checkpoints permanece separada.

**Atrezo (Props):** Generación procedural de kioskos (madera, tela, iluminación Neon/PointLight), graderías, pasarelas, barreras de neumáticos y antorchas Tiki. Los puestos de playa contienen únicamente reposeras instanciadas desde el asset Roblox `110854388215298`; las antiguas sombrillas, toallas y pelotas procedurales fueron retiradas.

**Vegetación:** `KartService.lua` carga el modelo original `palmera.fbx`, publicado en Roblox Studio como asset `135644677713727`, mediante `InsertService:LoadAsset`. Cada instancia se clona y normaliza según su altura real para quedar aproximadamente entre 14 y 17 studs, se posiciona usando el bounding box y se mantiene anclada, sin colisión/contacto/consulta y como masa nula. El clon aplica color y material de forma explícita a tronco y hojas. La clasificación de respaldo por altura utiliza el eje vertical local de la palmera (`finalBoxCFrame:PointToObjectSpace`) para que la inclinación de cada instancia no confunda tronco y follaje. Si la carga o el escalado falla, se genera la palmera procedural de respaldo y se emite una advertencia en Output. La integración requiere validación visual en Roblox Studio para confirmar apariencia, permisos de carga, orientación, escala y apoyo sobre el suelo. Las ubicaciones perimetrales se conservan.

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

- **Palmeras del Beach Resort:** el asset completo `135644677713727` se carga dinámicamente y se normaliza por altura real (objetivo aproximado 14–17 studs), con ajuste por bounding box y respaldo procedural. El clon aplica marrón + `Wood` al tronco y verde + `Grass` a las hojas. La clasificación por altura se calcula en el eje local de la palmera para evitar errores cuando una instancia está inclinada. Pendiente probar en Roblox Studio para confirmar que todas las instancias, incluida la que presentó el tronco verde, se vean correctamente.

- Diseñar e implementar un relleno de arena localizado entre el borde real del asfalto y los pianos, sin discos circulares completos.
- Validar visualmente en Roblox Studio que las uniones de curvas no presenten huecos, círculos ni interferencias.

**Interfaz de Usuario (HUD):**
- Cronómetro, contador de vueltas, telemetría local, clasificación y minimapa implementados en `RaceHUD.client.lua`.
- El velocímetro está ubicado en el sector inferior derecho, sin tarjeta, fondo, borde ni esquinas. Muestra el número de velocidad grande y `/KMH` más pequeño, en la misma línea. La velocidad se calcula desde la componente longitudinal de la velocidad del chasis y utiliza el factor de conversión existente `1.008`.
- Los paneles de carrera, clasificación y minimapa también son transparentes; el HUD mantiene texto con contorno para legibilidad.
- Tipografía centralizada: `Title` = Highway para títulos principales; `Bold` = GothamBold; `Light` = GothamMedium.
- Pendiente: validar visualmente el HUD actualizado en Roblox Studio. La tipografía BLOXY propia sigue pendiente de incorporar cuando estén disponibles sus assets/IDs.

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

- Leer el documento completo antes de proponer cambios o implementar tareas. Revisar el estado actual del código y del contexto para no repetir cambios ya realizados ni deshacer decisiones aprobadas.
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

**Gestión de entorno:** Verificar la rama autorizada vigente (`recovery/stable-handling`) antes de modificar. Proteger la integridad de `main`.

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

- El usuario confirmó que la palmera que debe utilizar el juego es el asset `135644677713727`, que actualmente se ve completamente verde dentro de la experiencia.
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
### Actualización de apariencia de palmera por piezas (2 de noviembre de 2026)

- Se mantiene el asset Roblox `139237715567825`, cuyo modelo contiene dos piezas independientes confirmadas por el usuario: `Palm_Trunk` y `Palm_Leaves`.
- Se modificó `src/ServerScriptService/KartService.lua` dentro de `spawnImportedPalm` para asignar al tronco color marrón (`Color3.fromRGB(126, 82, 48)`) y material `Wood`; a las hojas, verde (`Color3.fromRGB(48, 150, 58)`) y material `Grass`.
- La asignación se aplica al clon creado en tiempo de ejecución, no al asset original publicado. Se mantienen las propiedades físicas anteriores.
- Se añadieron contadores y una advertencia en Output si no se encuentran piezas con alguno de los nombres esperados.
- Estado: cambio implementado y publicado en `recovery/stable-handling`. Pendiente validar en Roblox Studio que los nombres se preservan al cargar con `InsertService:LoadAsset` y que los colores/materiales se ven correctamente.
- Archivos modificados: `src/ServerScriptService/KartService.lua` y `PROJECT_CONTEXT.md`.
- Pruebas realizadas: inspección estática del bloque actualizado y comprobación de que el cambio apunta a los nombres confirmados por el usuario. No se ejecutó Roblox Studio ni pruebas de runtime.
### Corrección de detección de piezas de palmera (2 de noviembre de 2026)

- La prueba del usuario en Roblox Studio mostró que `LoadAsset` devuelve piezas, pero ninguna conserva los nombres `Palm_Trunk` y `Palm_Leaves`: el Output reportó 0 coincidencias de ambos nombres en 11 palmeras.
- Se corrigió `spawnImportedPalm`: ahora identifica primero nombres que contengan `trunk`/`stem` o `leaf`/`leaves`/`foliage`; si el importador cambió los nombres, clasifica las piezas por su altura respecto al centro del bounding box (parte inferior como tronco y superior como hojas).
- Se añadieron mensajes de Output para informar cuántas piezas se colorearon o advertir si el modelo no contiene `BasePart`.
- Estado: corrección implementada y publicada en `recovery/stable-handling`; requiere una nueva prueba Play del usuario. La clasificación por altura es una alternativa para el FBX con nombres alterados, no una validación visual ya confirmada.
- Archivos modificados en esta corrección: `src/ServerScriptService/KartService.lua` y `PROJECT_CONTEXT.md`.
- Pruebas realizadas: revisión estática del bloque de clasificación y publicación/verificación del archivo. No se ejecutó Roblox Studio desde este entorno.


### Actualización de antorchas y HUD (3 de noviembre de 2026)

- Antorchas Tiki: el usuario aceptó el reemplazo procedural construido con piezas nativas en lugar del asset gris/blanco anterior `139155803475453`. Solicitó adelgazar el poste/atril. Se reduce el diámetro del poste principal de 0.62 a 0.42 studs y el listón longitudinal de realce de 0.16 a 0.10 studs; se mantienen altura, brasero, fuego, ubicaciones y resto de decoración.
- HUD de velocidad: el usuario reportó que volvió a aparecer un velocímetro en el centro de la pantalla y pidió retirarlo, manteniendo/restaurando el indicador numérico con unidad KM/H en el lado derecho. La versión actual de `RaceHUD.client.lua` no contiene el panel ni el cálculo de velocidad; se identificó en el historial del propio archivo la implementación anterior del indicador en la esquina inferior derecha. Se restaura ese indicador lateral, calculado desde la velocidad longitudinal del chasis y convertido con el factor previamente utilizado (1.008).
- Alcance de esta actualización: solo `KartService.lua`, `RaceHUD.client.lua` y este documento. No se modifican conducción, cámara, pista, barreras, checkpoints, minimapa ni leaderboard.
- Estado: cambios de código publicados en la rama `recovery/stable-handling`; pendiente validación visual y funcional del usuario en Roblox Studio. No se declara probado en Play.


### Corrección visual del HUD (3 de noviembre de 2026)

- El usuario indicó que el velocímetro lateral había recuperado indebidamente el recuadro/fondo que ya se había eliminado.
- Se deja `SpeedPanel` completamente transparente y sin esquinas ni borde. La lectura vuelve al formato horizontal `número /KMH`: valor numérico grande, unidad más pequeña a su derecha.
- Se incorpora el rol tipográfico `Title` en `BloxyTypography.lua`, usando la fuente nativa `Highway` como alternativa condensada y pesada al estilo Impact. Se aplica a los títulos principales del HUD (vuelta, clasificación, mapa y aviso de sentido contrario).
- Se mantienen intactos los paneles de carrera, clasificación y minimapa que ya eran transparentes; no se modifican conducción, cámara, circuito ni mecánicas.
- Estado: código publicado; pendiente de validación visual en Roblox Studio. No se declara probado en Play.


### Consolidación del estado vigente de HUD y antorchas (3 de noviembre de 2026)

Esta sección resume el estado actual para evitar que futuras iteraciones repitan o reviertan correcciones recientes.

- **Antorchas Tiki:** se utiliza el modelo procedural de piezas nativas aceptado por el usuario, no el asset anterior `139155803475453`. El poste fue adelgazado a 0.42 studs y su realce a 0.10 studs. Se conservan altura, brasero, fuego, decoración y ubicaciones.
- **Velocímetro:** se mantiene exclusivamente el diseño lateral inferior derecho: sin recuadro/fondo/borde, número grande y `/KMH` pequeño a la derecha. No reintroducir un velocímetro central ni una tarjeta opaca.
- **Títulos del HUD:** usar el rol `Title` (Highway) para títulos principales y avisos destacados; no reemplazarlo por Gotham Bold sin una solicitud expresa. Mantener `Bold` y `Light` para los demás niveles de información.
- **Alcance protegido:** estas correcciones no autorizan cambios en conducción, cámara, trazado, pianos, guardarraíles, checkpoints, minimapa, leaderboard ni ubicación de props.
- **Commits recientes en `recovery/stable-handling`:** HUD y velocímetro `408c94a`; rol tipográfico `96b830e`; documentación de corrección previa `2be93b5`. La corrección de antorchas y el primer retorno del velocímetro lateral se encuentran registrados en los commits anteriores de esta misma rama.
- **Validación:** se verificó que los archivos publicados contienen el panel transparente, el formato horizontal de velocidad y el rol `Title`. No se ejecutó Roblox Studio después de estos commits; la apariencia final queda pendiente de la prueba manual del usuario.

### Actualización de nueva palmera (3 de noviembre de 2026)

- El usuario proporcionó el nuevo asset de palmera de Roblox: `135644677713727`.
- Se actualizó `PALM_ASSET_ID` en `src/ServerScriptService/KartService.lua` para que el circuito cargue este nuevo modelo.
- Se conserva la lógica existente de carga mediante `InsertService:LoadAsset`, normalización de altura, posicionamiento por bounding box, inclinación, tratamiento visual por piezas y respaldo procedural. No se modificaron ubicaciones ni cantidades de palmeras.
- Estado: ID actualizado en el código y documentado. La estructura, apariencia, escala y carga del nuevo asset deben comprobarse en Roblox Studio; no se ha ejecutado una prueba de runtime desde este entorno.
- Archivos modificados: `src/ServerScriptService/KartService.lua` y `PROJECT_CONTEXT.md`.


### Actualización de validación de palmera y regresión del velocímetro (3 de noviembre de 2026)

- **Palmera:** el usuario confirmó en Roblox Studio que la corrección del tronco verde quedó resuelta. La apariencia del tronco y las hojas se considera probada visualmente por el usuario; no requiere más cambios por ahora.
- **Velocímetro central:** el usuario reportó que volvió a aparecer un velocímetro en el centro de la pantalla. Esto contradice el diseño aprobado, que mantiene únicamente el indicador inferior derecho, transparente y sin tarjeta ni fondo.
- **Inspección realizada en `recovery/stable-handling`:** `RaceHUD.client.lua` contiene un solo indicador de velocidad (`SpeedPanel`), posicionado en la esquina inferior derecha mediante `UDim2.new(1, -202, 1, -88)`, y lo vuelve transparente con `makeTextOnly`. `KartControls.client.lua` no crea un velocímetro; sus referencias a velocidad corresponden a físicas/cámara y a la indicación de entrada al kart. La búsqueda del árbol completo de `src` no mostró otro LocalScript de HUD o velocímetro.
- **Estado del problema:** regresión reportada por el usuario, origen todavía no identificado. La inspección del código versionado no explica por sí sola el elemento central que aparece en Studio. No se debe mover, duplicar ni recrear el velocímetro lateral a ciegas. Antes de otro cambio, revisar la sincronización Rojo/instancias de Studio y localizar la instancia o script que realmente dibuja el indicador central.
- **Pruebas:** el usuario confirmó visualmente la corrección de la palmera. El velocímetro central sigue pendiente de diagnóstico en Studio; no se declara resuelto ni se afirma que el código actual haya sido probado en Play tras esta inspección.
- **Archivos de código revisados sin modificarlos:** `src/StarterPlayer/RaceHUD.client.lua`, `src/StarterPlayer/KartControls.client.lua`, `src/ReplicatedFirst/LoadingScreen.client.lua`, `src/ServerScriptService/KartBootstrap.server.lua` y `src/ServerScriptService/KartService.lua`.

### Investigación histórica del velocímetro central (3 de noviembre de 2026)

- Se revisó el historial Git específico de `src/StarterPlayer/RaceHUD.client.lua`, en la rama `recovery/stable-handling`.
- **Commit `9c0482c` — “Remove speedometer from race HUD”:** eliminó el panel, los labels y el cálculo de velocidad del HUD.
- **Commit `25399ea` — “Restore right-side kart speed HUD”:** volvió a incorporar un indicador de velocidad, explícitamente ubicado en la esquina inferior derecha. No restaura el diseño central.
- **Commit `408c94a` — “Fix transparent speed HUD and compact KMH layout”:** conserva la posición inferior derecha y ajusta el formato a número grande + `/KMH` pequeño en una misma línea.
- El código actual de `RaceHUD.client.lua` mantiene esa posición inferior derecha mediante `UDim2.new(1, -202, 1, -88)`; el único `SpeedPanel` del archivo se vuelve transparente con `makeTextOnly`.
- Se volvió a inspeccionar `KartControls.client.lua`: contiene un `BillboardGui` asociado al aviso/interacción para entrar al kart, además de cálculos físicos de velocidad, pero no crea un velocímetro ni muestra KM/H.
- El árbol versionado de `src` solo contiene los dos scripts cliente relevantes (`RaceHUD.client.lua` y `KartControls.client.lua`); no se encontró un segundo script de velocímetro en el repositorio.
- **Conclusión técnica:** el historial confirma que el indicador lateral actual es una restauración intencional y distinta del velocímetro central que el usuario reporta. No hay evidencia en el código versionado actual que permita identificar o eliminar con seguridad ese elemento central. No se elimina el indicador lateral ni se realizan cambios especulativos en scripts ajenos al problema.
- **Siguiente diagnóstico necesario en Studio:** localizar el objeto central en Explorer mientras está visible (por ejemplo, bajo `PlayerGui`) y revisar su nombre/jerarquía/propiedades para identificar qué instancia lo crea. Hasta localizarlo, el origen del elemento central sigue sin confirmarse.
- **Archivos de código revisados:** `RaceHUD.client.lua` y `KartControls.client.lua`. No se modificó código de juego en esta investigación.


### Supresión preventiva del velocímetro central (3 de noviembre de 2026)

- Se implementó en `src/StarterPlayer/RaceHUD.client.lua` una limpieza preventiva de interfaces de velocidad heredadas dentro de `PlayerGui`.
- La limpieza identifica interfaces ajenas a `BLOXYRaceHUD` por nombres explícitos de velocímetro (`Speedometer`, `SpeedHUD`, `VehicleSpeed`) o por etiquetas que muestran unidades de velocidad (`KMH`, `KPH`, `MPH`). También vigila interfaces y cambios de texto que aparezcan después de iniciar el HUD.
- La limpieza excluye expresamente `BLOXYRaceHUD`, por lo que conserva el velocímetro oficial inferior derecho (sin fondo ni tarjeta, número grande y `/KMH` pequeño), además del cronómetro, clasificación y minimapa.
- No se modificaron los controles, la cámara, la física, el circuito ni el resto del HUD.
- Estado: corrección publicada en `recovery/stable-handling`. Validación estática realizada: el filtro excluye el HUD oficial y elimina únicamente interfaces de velocidad ajenas identificables por nombre o unidad. Falta la prueba en Roblox Studio para confirmar que el elemento central reportado corresponde a una interfaz dentro de `PlayerGui` que cumpla esos criterios.
- Límite conocido: una interfaz central que no tenga nombre identificable ni etiqueta con unidad de velocidad, o que sea creada fuera de `PlayerGui`, no puede identificarse de forma segura desde este script. No se declara todavía probado en Studio.
- Commit de código: `9b2803d`. Archivo modificado: `src/StarterPlayer/RaceHUD.client.lua`. Este documento se actualiza en el commit siguiente.


### Identificación visual y eliminación del velocímetro central "Velocidad" (3 de noviembre de 2026)

- El usuario compartió una captura del elemento que persistía en el centro: un HUD con el título literal **"Velocidad"**, un valor numérico y una barra horizontal segmentada naranja; no muestra unidad KMH/KPH/MPH.
- Causa del fallo de la limpieza preventiva anterior: el detector buscaba nombres de GUI o unidades de velocidad, por lo que no reconocía este diseño concreto.
- Corrección aplicada en `src/StarterPlayer/RaceHUD.client.lua`: ahora también detecta etiquetas cuyo texto normalizado sea exactamente `VELOCIDAD` o `SPEED` en cualquier ScreenGui ajeno a `BLOXYRaceHUD` y elimina ese ScreenGui. Se mantiene la limpieza previa por nombres y unidades, así como la vigilancia de nuevas instancias y cambios de texto.
- El HUD oficial `BLOXYRaceHUD` está expresamente excluido de la eliminación, por lo que se conserva el velocímetro lateral inferior derecho y el resto de sus elementos.
- Alcance: solo se modificó el detector de interfaces heredadas en `RaceHUD.client.lua`; no se tocaron controles, física, cámara, circuito ni diseño del HUD oficial.
- Estado: cambio publicado y verificado estáticamente en `recovery/stable-handling`. Falta la nueva prueba del usuario en Roblox Studio. Si el elemento se crea fuera de `PlayerGui` o no contiene el título mostrado en la captura, habría que localizar su origen por separado.
- Commit de código: `760a6c3`.


### Causa raíz del velocímetro central y corrección (3 de noviembre de 2026)

- Causa identificada: el velocímetro central con título "Velocidad" y barra segmentada no era un ScreenGui creado por nuestros scripts. Era la interfaz nativa que Roblox muestra para un `VehicleSeat` cuando su propiedad `HeadsUpDisplay` está habilitada. Por eso no aparecía en `PlayerGui` como una GUI del proyecto y los detectores anteriores no podían eliminarlo de forma fiable.
- Corrección definitiva aplicada en `src/ServerScriptService/KartService.lua`: al crear cada `DriverSeat`, establecer explícitamente `seat.HeadsUpDisplay = false`. Así se desactiva el velocímetro nativo de Roblox en el origen.
- Se conserva el velocímetro propio de BLOXY, creado por `RaceHUD.client.lua` en la esquina inferior derecha. No se modificaron las físicas, los controles, la cámara ni la posición del HUD propio.
- Las limpiezas preventivas de `RaceHUD.client.lua` quedan como defensa adicional para GUIs externas identificables; ya no son la solución principal al velocímetro central.
- Estado: cambio publicado en `recovery/stable-handling` y verificado estáticamente en la creación de `DriverSeat`. Pendiente confirmar visualmente en Roblox Studio que el HUD nativo desapareció al ocupar el kart.
- Commit de código: `a295c41`.


### Actualización de tablas de surf decorativas (3 de noviembre de 2026)

- Se reemplazó el grupo anterior de tres tablas procedurales por clones del modelo publicado por el usuario, asset Roblox `109207384771697`.
- La plantilla se carga una sola vez mediante `InsertService:LoadAsset`; cada tabla se clona, se escala proporcionalmente a una longitud objetivo cercana a 8 studs y se posiciona usando su bounding box.
- Se amplió el grupo de tres a cinco tablas, manteniéndolas en la zona de arena sur/oriental ya utilizada para este atrezo. Se conservan ancladas y sin colisión, contacto ni consulta para que no interfieran con los karts.
- Si el asset no está disponible o no contiene un modelo utilizable, se emite una advertencia en Output y se omiten las tablas importadas; no se afirma que el asset haya sido validado en runtime.
- Archivo modificado: `src/ServerScriptService/KartService.lua`.
- Estado: implementación publicada en `recovery/stable-handling`; pendiente comprobar en Roblox Studio permisos de carga, orientación, escala y apariencia del asset.


### Color y redistribución de tablas de surf (3 de noviembre de 2026)

- El usuario indicó que las tablas importadas se veían blancas y pidió aplicar colores aleatorios y aumentar su presencia visual alrededor del circuito.
- En `src/ServerScriptService/KartService.lua`, cada tabla clonada recibe ahora un tinte aleatorio elegido de una paleta tropical de ocho colores. El color se aplica a todas las piezas `BasePart` del clon; el asset publicado no se modifica.
- La distribución se amplió a 15 ubicaciones en claros perimetrales alrededor del Beach Resort, con posiciones calculadas como offsets respecto del centro de referencia del trazado (`TRACK_CENTER = Vector3.new(5, yGround, -15)`). Las ubicaciones se reparten entre sectores oriental, norte, noroeste y sur para que las tablas puedan verse desde distintos tramos de la pista.
- Se mantienen escala aproximada de 8 studs, variaciones de inclinación/orientación y propiedades ancladas/sin colisión, contacto ni consulta.
- Estado: implementación publicada en `recovery/stable-handling`; pendiente validar en Roblox Studio la visibilidad desde la pista, los colores y que ninguna tabla se superponga con otros props o invada el trazado. No se ha ejecutado Play desde este entorno.
- Archivo modificado: `src/ServerScriptService/KartService.lua`.


### Actualización de reposeras de playa (3 de noviembre de 2026)

- El usuario proporcionó el asset Roblox `110854388215298` para reemplazar las reposeras procedurales del Beach Resort.
- `KartService.lua` carga una plantilla mediante `InsertService:LoadAsset` y la clona para las 14 reposeras distribuidas en los siete puestos de playa. Tras la revisión visual del usuario, la escala objetivo se aumentó de 5.8 a 6.5 studs.
- Se conservan los colores, materiales y texturas publicados en el asset. Las piezas quedan ancladas y sin colisión, contacto ni consulta, para que los karts no se enganchen.
- Sombrillas, postes, toallas, pelotas y ubicaciones de los puestos permanecen sin cambios. Si Roblox no permite cargar el asset, se mantiene un respaldo procedural para evitar que desaparezcan las reposeras.
- Estado: integración implementada y publicada en `recovery/stable-handling`. Se verificó estáticamente el ID, el clonado, la escala y las propiedades físicas. No se ejecutó Roblox Studio; la apariencia, orientación y escala finales requieren validación visual en Play.
- Archivos modificados: `src/ServerScriptService/KartService.lua` y `PROJECT_CONTEXT.md`.


### Ajuste de tamaño y eliminación del respaldo antiguo de reposeras (3 de noviembre de 2026)

- Tras revisar la captura del usuario, se identificó que el código conservaba un respaldo procedural (Lounger_Fallback) que generaba una pieza blanca antigua en la misma ubicación cuando el asset importado no estaba disponible. Esto podía producir la superposición observada.
- Se eliminó por completo ese respaldo. Si el asset 110854388215298 no puede cargarse, no se crea una reposera alternativa ni se superpone geometría antigua.
- Se aumentó la escala objetivo del modelo importado de 5.8 a 6.5 studs, aproximadamente un 12 % más grande, manteniendo la proporción original del asset.
- Se mantienen las 14 instancias, las ubicaciones de los puestos y las propiedades sin colisión/contacto/consulta. No se modifican sombrillas ni accesorios.
- Estado: cambio implementado y publicado en recovery/stable-handling; verificación estática pendiente de nueva prueba visual del usuario en Roblox Studio. No se ejecutó Play desde este entorno.
- Archivos modificados: src/ServerScriptService/KartService.lua y PROJECT_CONTEXT.md.


### Retirada de accesorios antiguos de playa (3 de noviembre de 2026)

- Aclaración del alcance solicitado por el usuario: al sustituir el conjunto antiguo de playa, debían desaparecer también las sombrillas, toallas y pelotas procedurales, no solo las reposeras antiguas.
- Se eliminó de `spawnBeachCluster` toda la generación de `UmbrellaPole`, `UmbrellaCanopy`, `BeachTowel` y `BeachBall`. Cada uno de los siete puestos conserva exclusivamente sus dos reposeras importadas desde el asset `110854388215298`.
- Se mantienen las posiciones y rotaciones de los puestos y la escala actual de las reposeras (6.5 studs). No se modificaron tablas de surf, palmeras, pista ni otros elementos del mapa.
- Estado: cambio implementado y publicado en `recovery/stable-handling`. La revisión estática confirma que las cuatro piezas procedurales antiguas ya no se generan. Pendiente comprobar visualmente en Roblox Studio.
- Archivos modificados: `src/ServerScriptService/KartService.lua` y `PROJECT_CONTEXT.md`.


### Colores de reposeras (3 de noviembre de 2026)

- Estructura metalica: gris medio. Mástil/soporte de sombrilla: gris claro.
- Cojines y sombrillas: colores tropicales aleatorios por instancia, elegidos de una paleta de ocho tonos.
- La asignación de color se basa en nombres de partes/modelos del asset. Las piezas no reconocidas conservan el color original para evitar teñir componentes incorrectos.
- Código publicado en recovery/stable-handling. Pendiente validar en Roblox Studio que la jerarquía/nomenclatura del asset permita clasificar todas las piezas correctamente. No se modificaron ubicaciones, escala ni geometría.


### Beach asset color mapping correction (2026-11-03)
- Exact part names supplied by user: Reposera_B_Colchon, Reposera_A_Colchon, Reposera_A_Estructura, Reposera_B_Estructura, Sombrilla_Palo, Sombrilla_Toldo.
- Replaced fuzzy name/parent classification with exact part-name matching to avoid recoloring unrelated model parts.
- Both Reposera structure parts use medium gray. Sombrilla_Palo uses light gray. Each cushion receives an independent random tropical color. Sombrilla_Toldo receives a separate random tropical color.
- All other parts preserve original appearance. Scale, placement and geometry unchanged. Published to recovery/stable-handling; visual Studio validation remains pending.


### Starting grandstand reposition (2026-11-03)
- Moved all three rows of the starting grandstand 8 studs backward along Z to create clearance from the barrier beside the start straight.
- Preserved width, tier spacing, height, seats, colors and X coordinates. Only the Z reference changed from 52 to 44; rows remain spaced 3.5 studs apart.
- Published to recovery/stable-handling. Static code check complete; visual validation in Roblox Studio remains pending.


### Sustitución completa del arco de meta (3 de noviembre de 2026)

- Se retiró la estructura procedural anterior del inicio de la pista: los dos postes, la viga roja superior y el panel/banner.
- El asset Roblox `132205617373322`, proporcionado por el usuario, ahora se carga como modelo completo y se utiliza en su lugar con el nombre interno `ImportedFinishStructure`.
- El modelo se escala proporcionalmente para abarcar el ancho definido para el arco, se centra en X=0/Z=70 y se posiciona con la base de su bounding box en el nivel del circuito. Las piezas importadas quedan ancladas y sin colisión, contacto ni consulta.
- El cambio no crea una franja ni una línea decorativa en el suelo y no modifica la lógica de vueltas, checkpoints ni el resto del circuito.
- Estado: implementación publicada en `recovery/stable-handling`; revisión estática del bloque realizada. La carga del asset, su orientación, escala y apoyo visual deben confirmarse en Roblox Studio. No se ha ejecutado Play desde este entorno.
- Commit de código: `ee3bba8022557340311cfe1c143728296436e6fe`.
- Archivo de código modificado: `src/ServerScriptService/KartService.lua`.


### Orientación del modelo de meta (3 de noviembre de 2026)

- Tras la primera prueba visual, el usuario detectó que el modelo importado había quedado tendido sobre el asfalto. Se corrigió su orientación aplicando un giro de 90° sobre el eje Y antes del cálculo de escala.
- Se ajustó el posicionamiento para trasladar el bounding box sin perder la rotación: el modelo queda centrado en la recta (X=0, Z=70) y apoyado por su base en el nivel del circuito.
- No se reintroducen postes ni banner procedurales y no se modifica la lógica de carrera ni otras piezas del mapa.
- Estado: corrección publicada en `recovery/stable-handling`; pendiente de comprobar en Roblox Studio que el vano quede efectivamente sobre la pista. No se ha ejecutado Play desde este entorno.
- Commit de código: `755872bb77515310c9ce62dbb2a681567a38a81d`.


### Validación del arco de meta importado (3 de noviembre de 2026)

- El usuario confirmó que la corrección de orientación del modelo de meta quedó perfecta en Roblox Studio.
- Se considera visualmente validado por el usuario el reemplazo completo de la estructura procedural por el asset Roblox `132205617373322`, con giro de 90° sobre el eje Y, escala proporcional al ancho de pista y posicionamiento elevado sobre el trazado.
- Se mantiene la retirada de ambos postes, la viga roja y el panel/banner antiguos. No se modifica la lógica de carrera, checkpoints ni otras piezas del circuito.
- No se requieren más ajustes al arco de meta por ahora. Mantener esta implementación como aprobada y no modificarla salvo solicitud expresa.
- Código asociado: `src/ServerScriptService/KartService.lua`. Commit de implementación: `755872bb77515310c9ce62dbb2a681567a38a81d`.


### Prueba experimental de cámara isométrica (3 de noviembre de 2026)

- Se sustituyó temporalmente la cámara de seguimiento baja desde atrás por una perspectiva elevada de tres cuartos para evaluar una lectura más isométrica del circuito.
- La cámara sigue al kart desde una posición elevada y ligeramente desplazada hacia un costado, mirando hacia el kart y el tramo de pista que tiene por delante. Se conserva la interpolación suave, el ajuste leve del campo de visión según velocidad y la restauración de la cámara normal al salir del asiento.
- Parámetros de prueba en `KartConfig.lua`: `CameraOffset = Vector3.new(16, 27, 21)` y `CameraLookAhead = 9`.
- El cambio se limita a la cámara cliente y sus parámetros; no altera físicas, controles, derrape, HUD, geometría ni lógica de carrera.
- Estado: implementación experimental publicada en `recovery/stable-handling`. No se ha ejecutado Roblox Studio desde este entorno; el usuario debe evaluar encuadre, visibilidad de la pista en curvas y sensación de conducción. Ajustar o revertir según su prueba.
- Archivos modificados: `src/StarterPlayer/KartControls.client.lua`, `src/ReplicatedStorage/KartConfig.lua` y `PROJECT_CONTEXT.md`.


## Selección de cámara previa a la carrera (3 de noviembre de 2026)

- Al sentarse en su kart, cada jugador elige cámara clásica (trasera) o isométrica (elevada en diagonal) mediante dos botones de texto grandes; se eliminó la previsualización 3D ViewportFrame porque podía mostrarse negra y bloquear la selección.
- El servidor valida la selección y espera a que todos los jugadores conectados estén sentados y hayan elegido. Después envía una cuenta regresiva global de cinco segundos y habilita RaceStarted de forma sincronizada.
- Cada cámara se aplica localmente; físicas y controles son iguales. La selección no altera el circuito ni los elementos aprobados.
- Si un jugador sale durante la cuenta regresiva, se invalida esa cuenta y se vuelve a evaluar a los participantes restantes.
- Corrección del 3 de noviembre: se eliminó ViewportFrame y se sustituyó por botones TextButton visibles, con iconos, descripciones y confirmación de selección. La interfaz se adapta al ancho disponible y conserva el flujo de selección sincronizada.
- Estado: corrección publicada; validación estática realizada. Pendiente de prueba manual en Roblox Studio.
- Corrección adicional: al abrir la selección se eliminan todas las ScreenGui antiguas llamadas `BLOXYCameraSelection` que hayan quedado en PlayerGui tras reinicios/reconexiones de LocalScript. Se redujo la opacidad de la capa de fondo y se aumentó el contraste del panel y los botones para evitar la apariencia de pantalla negra.
- Archivos: src/ServerScriptService/KartService.lua, src/StarterPlayer/KartControls.client.lua y PROJECT_CONTEXT.md.


### Corrección del panel vacío de selección de cámara (3 de noviembre de 2026)

- El usuario compartió una captura donde se veía el panel central oscuro, pero no aparecían el título ni las opciones de cámara.
- Causa identificada en `KartControls.client.lua`: `BloxyTypography.getFont()` devuelve objetos `Font` (creados mediante `Font.fromEnum`), pero el panel asignaba esos objetos a la propiedad `.Font`, que espera un `Enum.Font`. La asignación incorrecta podía detener la ejecución del LocalScript después de crear el panel y antes de construir los botones.
- Corrección: se cambiaron las cuatro asignaciones tipográficas del panel de selección (`heading`, `status`, `name` y `detail`) de `.Font` a `.FontFace`, que acepta los objetos `Font` devueltos por el módulo central. No se modificaron el sombreado, las dimensiones, los botones, la lógica de selección ni la cámara.
- Estado: corrección publicada en `recovery/stable-handling` y verificada estáticamente contra el tipo devuelto por `BloxyTypography.lua`. No se ejecutó Roblox Studio; falta la prueba manual del usuario.
- Commit de código: `12973126a9e1c9a10a8550373eae2dfd3811bb7f`.
- Archivo de código modificado: `src/StarterPlayer/KartControls.client.lua`.
