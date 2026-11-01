BLOXY KARTS - Project Context

Última actualización: Noviembre de 2026

Motor: Roblox Studio (Luau)

Género: Arcade Kart Racing

Estudio: GamaKingStudio

Repositorio: https://github.com/GamaKingStudio/Block-Karts

Rama de trabajo: feature/kart-prototype

Rama protegida: main

1. Para qué sirve este documento

Este documento transfiere a Gemini el contexto del desarrollo de BLOXY KARTS para que pueda colaborar en el análisis técnico, la planificación y la preparación de instrucciones para Manus.

Gemini debe leerlo como contexto del proyecto, no como una orden para modificar código inmediatamente.

Regla principal de colaboración

Gemini: Copiloto técnico cotidiano. Analiza código, propone soluciones, revisa decisiones y redacta instrucciones (o código directo) para el usuario.

ChatGPT: Apoyo para mantener la visión global, priorizar el desarrollo, revisar decisiones y resolver problemas complejos.

Manus: Desarrollador que modifica el repositorio, implementa cambios y publica commits en GitHub (si aplica).

Usuario: Director del proyecto y tester en Roblox Studio. Requiere instrucciones claras y graduales para la implementación de código en el entorno de desarrollo local.

2. Visión del juego

BLOXY KARTS es un juego de carreras arcade para Roblox, con estética low-poly inspirada en el lenguaje visual de Roblox y Minecraft, con identidad y recursos originales. El proyecto busca establecerse como un producto comercial del estudio GamaKingStudio.

Pilares de diseño

Conducción arcade accesible pero con curva de aprendizaje técnica.

Carreras con contacto y colisiones físicas entre jugadores.

Mecánicas de derrape (drifting) y turbo integradas en el core loop.

Circuitos con identidad visual y legibilidad geométrica.

Progresión basada en juego (evitar mecánicas pay-to-win).

Estética low-poly geométrica y consistente.

Modos previstos

Carreras públicas y privadas (hasta 8 jugadores, 3 vueltas).

Contrarreloj.

Modos en evaluación (Eliminación, Batalla, Campeonato).

Karts iniciales previstos

Starter Kart.

Mini Buggy.

Monster Kart.

Rocket Kart.

Mundos/circuitos previstos

Beach Resort (Implementado en rama de prototipo).

Blocky Jungle.

Lava Rush.

Neon City.

Frozen Peak.

Candy World.

Progresión futura

Monedas y experiencia (XP).

Desbloqueo de chasis y cosméticos.

Restricción: No implementar monetización ni sistemas de progresión antes de validar las mecánicas de conducción.

3. Principios técnicos y de desarrollo

Arquitectura deseada

Servidor: Validaciones de lógica de juego (carreras, checkpoints, vueltas, recompensas). Construcción procedural de geometría (circuitos).

Cliente: Gestión de input local, cámara, interfaz de usuario (HUD), efectos visuales (VFX) y sonido (SFX). Cálculo de físicas locales mediante asignación de Network Ownership.

Control: Unificar la lógica de conducción en un único sistema. Evitar instanciación de controladores redundantes.

Rendimiento: Priorizar un recuento poligonal bajo y el uso eficiente de primitivas en Roblox.

Reglas de trabajo

Extender el proyecto existente; evitar reescrituras completas de módulos funcionales.

Todo nuevo desarrollo debe integrarse en la rama feature/kart-prototype.

No realizar merges ni modificaciones en la rama main sin autorización explícita.

Mantener estricta compatibilidad con la herramienta Rojo (versión 7.7.1).

Limitar las tareas exploratorias autónomas para optimizar el consumo de créditos de la API de Manus.

4. Herramientas y entorno

Servicios: Roblox Studio, VS Code, Git/GitHub, Rojo CLI 7.7.1.

Terminal 1 (Rojo): Ejecución de rojo serve en localhost (puerto 34872) para sincronización en tiempo real.

Terminal 2 (Git): Gestión de control de versiones (pull/push) en la rama feature/kart-prototype.

Regla de Entorno: Limpiar instancias como Baseplate o SpawnLocation genéricos de Roblox Studio antes de la generación del mapa para prevenir conflictos de físicas y superposición de mallas (Z-Fighting).

5. Estado del prototipo y Funcionalidades Vigentes

El proyecto se encuentra en fase de prototipo jugable, con un circuito base y un sistema de físicas de karts funcional.

Archivos principales en uso

src/ServerScriptService/KartService.lua: Controlador del servidor. Gestiona la generación del entorno, spawn de jugadores y ensamblaje de los karts.

src/ServerScriptService/KartBootstrap.server.lua: Punto de entrada del servidor.

src/ReplicatedStorage/KartConfig.lua: Módulo de datos (parámetros físicos, multiplicadores, configuración de cámara).

src/StarterPlayer/KartControls.client.lua: Lógica del cliente. Captura de inputs y aplicación de fuerzas físicas.

Sistemas Implementados

Ensamblaje del Kart: Generación por código a través de KartService. Utiliza un bloque central (Chassis) para los cálculos de colisión y física. Las mallas decorativas (incluyendo las ruedas) tienen la propiedad CanCollide = false.

Física Custom: El desplazamiento se logra aplicando un VectorForce sobre el Chassis.

Controles (Cliente): Input digital para Aceleración/Reversa (W/S), Dirección (A/D), Freno (Espacio) y Derrape (Shift).

Cámara Scriptable: Sistema de interpolación de cámara posicionado detrás del kart, con look-ahead calculado en base a la velocidad lineal.

Network Ownership: El servidor delega la autoridad de cálculo físico del kart al cliente respectivo en el instante en que el Humanoid ocupa el VehicleSeat.

Sistema de Derrape (Drift Mode):

Condición de activación: Tecla Shift presionada y velocidad mayor a 8 studs/seg.

Comportamiento: El parámetro de agarre lateral se reduce a un factor de 0.25. El límite angular (yaw rate) aumenta a 1.6x.

Mini-Turbo: Tras 0.8 segundos de derrape continuo, al liberar el input se aplica un impulso longitudinal temporal (duración: 0.75s, multiplicador de aceleración: 1.45x, aumento de velocidad máxima: 1.25x).

Manejo de Spawn: Prevención de physics fling teletransportando al personaje a un offset vertical relativo al asiento (Y = +4 studs) y forzando el estado Sit.

Control de Errores de Instanciación: Lógica de abstracción en la función makePart para traducir literales de forma (ej. "Cylinder", "Ball") al enumerador Enum.PartType correspondiente, evitando llamadas inválidas a Instance.new().

6. Diseño del Circuito (Beach Resort)

El circuito se compila proceduralmente en tiempo de ejecución (RunTime) a través del servidor.

Arquitectura de Geometría

Capa Física Unificada: Terreno definido por un bloque estático (IslandSand) con coordenada Y fijada en 1.0. Las partes visuales de la pista carecen de propiedades de colisión geométrica.

Trazado de Asfalto: Nodos de trayectoria conectados mediante partes rectangulares, utilizando partes cilíndricas sin colisión en los vértices para redondear las esquinas y evitar superposición de texturas y geometría intersecante.

Mitigación de Z-Fighting: Escalado micrométrico en el eje Y (Deltas de ~0.02 studs) para separar arena, asfalto, marcas viales y límites de pista.

Elementos Estructurales

Pit Lane (Calle de Boxes): Carril paralelo al sur de la recta principal. Incluye muro divisor físico, cajones de detención, un WedgePart para sellar la geometría en la entrada, y un carril de incorporación fluida a la vía principal.

Arco de Meta (Gantry): Estructura en voladizo soportada por pilares exteriores (X=0), ubicada inmediatamente después de la reincorporación de la calle de boxes, impidiendo bloqueos del carril.

Atrezo (Props): Generación procedural de Kioskos (madera, tela, iluminación Neon/PointLight), graderías, pasarelas, barreras de neumáticos y antorchas Tiki.

Vegetación: Modelos de palmeras compuestos por primitivas, ubicados a un radio mínimo de exclusión de 20 studs respecto a la pista para evitar interferencias de oclusión visual con la cámara de seguimiento.

7. Historial de Problemas Críticos Resueltos

Colisión invisible al reentrar a la pista: Solucionado al separar la lógica visual de la física. El asfalto se configuró como CanCollide = false sobre el plano de arena continuo.

Desaparición del Kart por Race Conditions (Fling): Mitigado mediante la eliminación de SpawnLocation de Roblox y la implementación de un bucle de confirmación para el evento de sentar al Humanoid.

Z-Fighting en Superficies: Resuelto con deltas verticales controlados.

Crash del Servidor (Cannot Destroy() Terrain): Controlado al introducir una condicional explícita que impide llamadas de recolección de basura sobre el objeto Workspace.Terrain.

Crash por Instanciación Inválida (Instance.new("Cylinder")): Corregido mediante el mapeo del string al Enum.PartType en el bloque de utilidades.

Invasión del Carril por Props: Las palmeras, tablas de surf y antorchas Tiki fueron reasignadas a coordenadas perimetrales absolutas. La calcomanía del SpawnLocation base se eliminó sistemáticamente.

8. Próximos Pasos (Roadmap Técnico)

Fase Actual (HUD y Sistemas de Lógica de Carrera)

Implementación de la Interfaz de Usuario (HUD): Desarrollo de cronómetro, contador de vueltas y telemetría local (velocímetro).

Sistema de Checkpoints (Backend): Zonas de validación vectoriales (invisibles) para certificar vueltas válidas, control de sentido de giro y puntos de reaparición (respawn).

Fase Futura

VFX (Sistemas de Partículas): Emisores de partículas para desgaste de neumáticos, colisiones, estelas de arena y efectos de carga/liberación del Mini-Turbo.

Audio (SFX/BGM): Implementación de modulación de Pitch/Volume del motor vinculada a la AssemblyLinearVelocity y triggers de audio para eventos (derrape, meta, choque).

Metajuego y Sesión: Sistema de Lobby de espera, persistencia de datos de usuario (selección de karts, inventario) y lógica de emparejamiento (Matchmaking).

9. Directrices de Respuesta (LLM / Gemini)

Al redactar instrucciones o entregar bloques de código al usuario, se deben aplicar los siguientes criterios:

Precisión: Instrucciones acotadas, modulares y limitadas al requerimiento en curso.

Código Formateado: Los bloques de código deben ser provistos de forma íntegra y listos para sustituir archivos existentes. No utilizar fragmentos inconexos.

Gestión de Entorno: Exigir siempre la verificación de la rama activa (feature/kart-prototype). Proteger la integridad del branch main.

Accesibilidad: Documentar los cambios en el código sin abusar de tecnicismos innecesarios; mantener un tono directo.

Transparencia: Si una implementación conlleva riesgos o requiere QA manual intensivo en Studio, debe ser advertido explícitamente antes de proceder.