# BLOXY KARTS --- Debrief de proyecto para Gemini

**Documento de contexto maestro**\
**Fecha de actualización:** 30 de octubre de 2026\
**Estudio:** GamaKingStudio\
**Repositorio:** https://github.com/GamaKingStudio/Block-Karts\
**Rama de trabajo:** `feature/kart-prototype`\
**Rama protegida:** `main`

------------------------------------------------------------------------

## 1. Para qué sirve este documento

Este documento transfiere a Gemini el contexto del desarrollo de **BLOXY
KARTS** para que pueda colaborar en el análisis técnico, la
planificación y la preparación de instrucciones para Manus.

Gemini debe leerlo como contexto del proyecto, no como una orden para
modificar código inmediatamente.

### Regla principal de colaboración

-   **Gemini:** copiloto técnico cotidiano. Analiza código, propone
    soluciones, revisa decisiones y redacta instrucciones precisas para
    Manus.
-   **ChatGPT:** apoyo para mantener la visión global, priorizar el
    desarrollo, revisar decisiones y resolver problemas complejos.
-   **Manus:** desarrollador que modifica el repositorio, implementa
    cambios y publica commits en GitHub.
-   **Usuario:** director del proyecto y tester en Roblox Studio. Tiene
    poca experiencia programando y necesita instrucciones claras,
    graduales y sin asumir conocimientos técnicos.

No deben generarse instrucciones contradictorias. Antes de pedir un
cambio a Manus, hay que revisar el estado actual del repositorio y el
historial de tareas.

------------------------------------------------------------------------

## 2. Visión del juego

BLOXY KARTS es un juego de carreras arcade para Roblox, con estética
blocky/low-poly inspirada en el lenguaje visual de Roblox y Minecraft,
pero con identidad y recursos originales.

La intención es crear un producto de estudio, no solamente un prototipo
personal. El proyecto pertenece a la futura marca de videojuegos
**GamaKingStudio**.

### Pilares de diseño

-   Fácil de aprender, difícil de dominar.
-   Conducción arcade divertida y accesible.
-   Carreras con contacto y colisiones entre jugadores.
-   Derrapes y turbo como mecánicas importantes.
-   Circuitos coloridos, reconocibles y con personalidad.
-   Progresión y desbloqueos sin ventajas de pago injustas.
-   Estética blocky, geométrica, atractiva y consistente.

### Modos previstos

-   Carreras públicas y privadas.
-   Hasta 8 jugadores.
-   Carreras de 3 vueltas.
-   Contrarreloj.
-   Eliminación.
-   Batalla.
-   Campeonato.

Estos modos son parte de la visión futura; no todos están implementados.

### Karts iniciales previstos

-   Starter Kart.
-   Mini Buggy.
-   Monster Kart.
-   Rocket Kart.

### Mundos/circuitos previstos

1.  Blocky Jungle --- primer circuito.
2.  Lava Rush.
3.  Neon City.
4.  Frozen Peak.
5.  Candy World.

### Progresión futura

-   Monedas y XP.
-   Desbloqueo de karts.
-   Cosméticos.
-   Desafíos.
-   Garaje y tienda.
-   Resultados de carrera.

**No implementar monetización ni sistemas de progresión complejos antes
de validar que conducir y competir sea divertido.** Evitar pay-to-win.

------------------------------------------------------------------------

## 3. Principios técnicos y de desarrollo

### Arquitectura deseada

-   El servidor valida carreras, checkpoints, vueltas, recompensas,
    objetos y compras.
-   El cliente gestiona entrada del jugador, cámara, interfaz, efectos
    visuales y sonido.
-   Usar predicción del cliente cuando sea apropiado, sin confiar al
    cliente la validación de recompensas o resultados.
-   Mantener un único sistema de conducción y evitar duplicar asientos,
    fuerzas o controladores.
-   Priorizar rendimiento y geometría sencilla en Roblox.

### Reglas de trabajo

1.  Trabajar sobre el proyecto existente; no reescribirlo desde cero.
2.  Todas las implementaciones de Manus deben ir a
    `feature/kart-prototype`.
3.  No modificar `main` salvo autorización explícita.
4.  Mantener compatibilidad con Rojo 7.7.1.
5.  Antes de modificar, inspeccionar los scripts y entender las
    dependencias.
6.  Cambiar el menor número de archivos posible.
7.  No cambiar física, cámara o controles cuando la tarea no lo
    requiera.
8.  No declarar un problema solucionado si no se ha probado en Roblox
    Studio.
9.  Diferenciar claramente entre validación estática y prueba funcional
    real.
10. Evitar tareas exploratorias amplias y prompts repetidos: los
    créditos de Manus son limitados.

### Situación del usuario

El usuario tiene poca experiencia programando y quiere que Manus haga
prácticamente todo el trabajo de código. No pedirle que edite Lua
manualmente. Guiarlo paso a paso y explicar exactamente qué terminal
usar cuando corresponda.

------------------------------------------------------------------------

## 4. Herramientas y entorno

### Servicios y herramientas

-   Roblox Studio.
-   VS Code.
-   Git y GitHub.
-   Rojo CLI 7.7.1.
-   Plugin de Rojo instalado en Roblox Studio.
-   Manus con conector de GitHub.
-   Gemini Pro disponible para el usuario por su trabajo.
-   ChatGPT como apoyo de planificación y revisión.

### Rutas y repositorio

-   Repositorio GitHub: `https://github.com/GamaKingStudio/Block-Karts`
-   Carpeta local: `C:\Users\l_kan\Block Karts`
-   Rama principal: `main`
-   Rama activa: `feature/kart-prototype`

### Mapeo Rojo

El archivo `default.project.json` mapea:

-   `src/ReplicatedStorage` → `ReplicatedStorage`
-   `src/ServerScriptService` → `ServerScriptService`
-   `src/StarterPlayer` → `StarterPlayerScripts`

`rokit.toml` fija Rojo 7.7.1.

`.gitignore` ignora `prueba.rbxl` y `*.rbxlx`.

Existe una copia del Baseplate original llamada
`BLOXY_KARTS_Baseplate.rbxl`; debe preservarse.

### Flujo de trabajo local

Hay dos terminales y no deben confundirse:

**Terminal 1 --- Rojo** - Se ejecuta `rojo serve` desde la carpeta del
proyecto. - Usa localhost, puerto `34872`. - Debe permanecer abierta
mientras se prueba en Studio. - No iniciar otro servidor Rojo en el
mismo puerto. - Si se cambia de rama, detener Rojo con `Ctrl+C` y volver
a ejecutar `rojo serve`.

**Terminal 2 --- Git** - Se usa para descargar cambios publicados por
Manus. - Desde la carpeta del proyecto:
`bash   git pull origin feature/kart-prototype`

Rojo sincroniza los archivos locales con Roblox Studio. Git
descarga/publica los cambios entre la carpeta local y GitHub. Son
herramientas distintas.

------------------------------------------------------------------------

## 5. Estado del prototipo

El proyecto ya tiene un prototipo de kart funcional, con conducción y
cámara implementadas. No es todavía una experiencia completa de
carreras.

### Archivos principales conocidos

-   `src/ServerScriptService/KartService.lua`
-   `src/ServerScriptService/KartBootstrap.server.lua`
-   `src/ReplicatedStorage/KartConfig.lua`
-   `src/StarterPlayer/KartControls.client.lua`
-   `Readme.md`
-   `default.project.json`
-   `rokit.toml`

También se mencionó `Prueba.server.lua`, que únicamente imprime un
mensaje.

### Sistemas existentes

-   Creación del kart en el servidor.
-   Un `VehicleSeat` de conducción.
-   Controles del cliente mediante `ContextActionService`.
-   Controles: W acelera, S frena/reversa, A/D giran, espacio frena.
-   Cámara de seguimiento en tercera persona.
-   Prompt personalizado para entrar al kart: `E · Conducir`.
-   Detección de asiento/ocupante.
-   Sistema de fuerza y movimiento del kart.
-   Asignación de network ownership al conductor.
-   Pista de pruebas básica.
-   Diagnósticos de avatar y cámara.

El usuario confirmó que el kart se mueve, la cámara funciona desde atrás
y el prompt personalizado aparece correctamente.

### Problema de sensación de conducción

El usuario evaluó la conducción como **muy rígida**. Sin embargo, la
prioridad inmediata pasó a ser el diseño de la pista y del vehículo. No
modificar la física hasta tener una tarea específica y poder comparar el
comportamiento en una pista adecuada.

------------------------------------------------------------------------

## 6. Historial técnico relevante

Los siguientes commits fueron publicados en `feature/kart-prototype`
según las respuestas de Manus y las pruebas del usuario:

  -----------------------------------------------------------------------
  Commit                              Cambio reportado
  ----------------------------------- -----------------------------------
  `b342586`                           Prototipo inicial de kart.

  `527d870`                           Captura de W/S/A/D/espacio mediante
                                      ContextActionService y detección
                                      del asiento.

  `6201552`                           Ajustes físicos, intento de network
                                      ownership, límite de giro y
                                      velocidad angular.

  `2d3ad6b`                           Diagnósticos de cliente y servidor.

  `c18ce45`                           Cambio de enfoque de network
                                      ownership: servidor asigna al
                                      conductor y cliente aplica
                                      movimiento.

  `03fef7b`                           Restauración del `require` de
                                      `KartConfig` que faltaba y que
                                      impedía crear el kart.

  `3245485`                           Corrección de fricción y manejo
                                      seguro del network ownership.

  `cdf3017`                           Corrección de cámara: offset de
                                      seguimiento y restauración de
                                      cámara al salir.

  `4d71e23`                           Inversión del sentido de giro A/D y
                                      ajuste del panel de carrocería para
                                      despejar el asiento.

  `4390589`                           Ajuste menor de indentación.

  `7ebf8fc`                           Prompt personalizado `E · Conducir`
                                      y diagnóstico ampliado del avatar.

  `1b59b86`                           Diagnóstico `[AVATAR-RENDER]` de
                                      posición, viewport, jerarquía y
                                      mallas del avatar.

  `ea4402a`                           Rediseño visual del kart y
                                      corrección geométrica de
                                      pista/terreno.
  -----------------------------------------------------------------------

El estado actual de la rama debe verificarse en GitHub antes de
trabajar; no asumir que la lista está completa o que no hay commits
posteriores.

------------------------------------------------------------------------

## 7. Problema del avatar invisible: resuelto por una causa externa

Durante varias iteraciones el avatar parecía invisible al sentarse en el
kart.

Se hicieron diagnósticos: - `humanoidSit=true`. - `seatWeld=true`. -
Partes del avatar con transparencia cero. - Cabeza y torso dentro del
viewport. - Personaje en `Workspace`. - Cámara en modo `Scriptable`.

El registro mostró que las mallas de cabeza y torso daban HTTP 403: -
Cabeza: asset `123480233606534`. - Torso: asset `7430071038`.

Finalmente el usuario descubrió que **Roblox había restringido/bloqueado
su cuenta por "actividad sospechosa"**. Tras recuperar el acceso, el
avatar volvió a funcionar correctamente.

Conclusión importante: no volver a investigar o modificar cámara,
asiento, transparencia o mallas sin comprobar primero si
Roblox/cuenta/servicios están funcionando. Los diagnósticos anteriores
consumieron créditos de Manus por un problema externo.

------------------------------------------------------------------------

## 8. Diseño visual del kart: referencia del usuario

El usuario compartió un script Lua llamado `LowPolyKart_Medio`, que
define una estética concreta. Este script fue compartido en el chat, no
necesariamente guardado como archivo del repositorio.

### Características del diseño de referencia

-   Chasis oscuro.
-   Carrocería roja.
-   Laterales azules.
-   Detalles amarillos.
-   Nariz frontal inclinada tipo WedgePart.
-   Parachoques delantero.
-   Faros cúbicos luminosos.
-   Motor trasero compacto.
-   Alerón posterior rojo con soportes azules.
-   Asiento oscuro con respaldo.
-   Cuatro ruedas cilíndricas negras.
-   Rines amarillos.
-   Geometría low-poly, blocky, arcade.

El usuario quiere que el personaje parezca estar conduciendo y no
simplemente sentado encima de unos cubos. El script original no tenía
volante, por lo que se pidió añadir: - Volante visible frente al
avatar. - Columna de dirección. - Tablero. - Asiento definido e
integrado.

### Adaptación de Manus en `ea4402a`

Manus reportó haber implementado: - Carrocería roja. - Laterales
azules. - Detalles amarillos. - Chasis oscuro. - Ruedas cilíndricas
negras con rines amarillos. - Nariz inclinada. - Parachoques. - Faros. -
Motor trasero. - Alerón. - Volante octogonal. - Columna. - Tablero. -
Respaldo.

Las piezas decorativas están soldadas al chasis, sin colisión ni eventos
de contacto y con masa despreciable. Se conserva el único `VehicleSeat`,
la fuerza de conducción y el sistema de controles. El asiento no se
movió.

**Feedback del usuario:** "me gusta más pero no es lo que busco. no se
parece a lo que tengo pensado". Por lo tanto, el modelo actual es solo
una referencia temporal; no se debe seguir rediseñando a ciegas. Hay que
pedir referencias visuales o aclarar la silueta deseada antes de otro
rediseño importante.

------------------------------------------------------------------------

## 9. Problema de pista y terreno

En una iteración anterior, el usuario observó que la pista se superponía
visualmente al terreno al desplazarse, como si hubiera superficies
atravesadas o capas solapadas.

Manus reportó en `ea4402a`: - Piezas estáticas del mapa sin `Anchored`
asignado explícitamente. - La cara superior del asfalto estaba en
`Y=0.5`, coincidiendo con el plano superior de una Baseplate estándar si
permanecía presente. - Ancló las piezas del mapa. - Dividió el suelo
verde alrededor del asfalto para evitar solapamiento de superficies. -
Alineó suelo y pista en `Y=0.6`. - Elevó ligeramente las marcas sobre la
superficie. - Ajustó barreras, obstáculos y aparición para mantener
alturas relativas al piso.

No se pudo hacer prueba visual en Studio desde Manus. El usuario todavía
debe validar el resultado en Roblox Studio.

------------------------------------------------------------------------

## 10. Problemas más recientes reportados por el usuario

Después de descargar y probar el commit `ea4402a`, el usuario indicó:

1.  El diseño del kart le gusta más que el anterior, pero sigue sin
    parecerse a lo que tiene pensado.
2.  Al intentar doblar, el kart "choca" con algo invisible.
3.  Se ve una pequeña cosa a lo lejos, descrita como una "mosquita".

Todavía no se tienen capturas ni datos de posición/colisión porque el
usuario está temporalmente sin acceso a su PC.

### Hipótesis a investigar, no asumir como hechos

Para el choque invisible: - Barreras laterales mal ubicadas. -
Obstáculos con colisión. - Piezas antiguas de pista. - Partes
duplicadas. - Geometría del terreno invadiendo el recorrido. - Piezas
invisibles con `CanCollide=true`. - Barreras que quedaron fuera del
trazado esperado.

Para la "mosquita": - Pieza residual del prototipo. - Marcador/punto de
referencia. - Objeto decorativo mal ubicado. - Pieza duplicada o
minúscula. - Objeto relacionado con spawn.

No borrar piezas legítimas por conjeturas. Identificar nombre, posición,
tamaño, parent y propiedades antes de cambiar.

### Última tarea propuesta al usuario

Se preparó una instrucción para Manus que pide: - Investigar el choque
invisible. - Identificar el objeto lejano. - No hacer todavía otro
rediseño del kart. - Documentar dimensiones, asiento, volante,
carrocería y ruedas. - No cambiar física, dirección, controles o
cámara. - No reescribir `KartService`. - Corregir solo lo que tenga
causa técnica justificada. - Publicar en `feature/kart-prototype`. -
Informar qué no pudo probarse en Studio.

**No está confirmado si el usuario ya envió esta tarea a Manus ni si
Manus ya respondió.** Antes de avanzar, preguntarle o revisar el estado
actual del repositorio y conversación.

------------------------------------------------------------------------

## 11. Limitación importante: créditos de Manus

El usuario indicó que le quedaban aproximadamente **1.000 créditos de
Manus**, con una recarga diaria de 300 cuando se agoten (según la
información que compartió en ese momento).

Por lo tanto: - Evitar prompts exploratorios y auditorías amplias
innecesarias. - No dividir una tarea sencilla en muchas llamadas. -
Recopilar evidencia con pruebas del usuario antes de pedir otro
cambio. - Agrupar correcciones relacionadas cuando estén justificadas. -
No pedir a Manus que implemente sistemas nuevos mientras haya errores
básicos sin resolver. - El usuario quiere conservar créditos y recibir
instrucciones concretas.

El saldo actual debe confirmarse; el dato de 1.000 créditos puede estar
desactualizado.

------------------------------------------------------------------------

## 12. Estrategia de desarrollo recomendada

Orden de trabajo propuesto:

### Fase A --- Estabilizar el prototipo

1.  Resolver colisiones invisibles.
2.  Identificar/eliminar la "mosquita" si es un objeto residual.
3.  Confirmar que la pista y el terreno no se superponen.
4.  Verificar que el kart se puede conducir por todo el circuito.

### Fase B --- Definir y cerrar el diseño del kart

1.  Conseguir una referencia visual clara del usuario.
2.  Acordar silueta, proporciones, ruedas, asiento, volante y
    carrocería.
3.  Adaptar el modelo sin tocar el sistema de conducción.
4.  Probar que el avatar queda correctamente integrado.

### Fase C --- Validar conducción arcade

1.  Probar aceleración y velocidad.
2.  Probar frenado y reversa.
3.  Probar giros y respuesta.
4.  Evaluar derrape y sensación de velocidad.
5.  Ajustar física en una tarea separada y controlada.

El usuario describió la conducción actual como "muy rígida", pero no
debe modificarse a la vez que se cambia geometría de pista o vehículo.

### Fase D --- Circuito Blocky Jungle

Después de estabilizar la geometría: - Circuito cerrado. - Curvas
amplias y cerradas. - Variaciones moderadas de altura. - Puente y
túnel. - Vegetación, rocas, agua y ambientación. - Barreras colocadas de
forma coherente. - Espacio suficiente para adelantar y colisionar.

No desarrollar la pista definitiva hasta tener una referencia de estilo
y una base funcional estable.

### Fase E --- Sistema de carreras

Solo cuando la conducción y la pista sean divertidas: - Salida y cuenta
regresiva. - Checkpoints. - 3 vueltas. - Posiciones. - Cronómetro. -
Meta. - Resultados.

### Fase F --- Lobby, garaje y progresión

-   Lobby.
-   Selección de kart.
-   Garaje y tienda.
-   Monedas, XP y desbloqueos.
-   Matchmaking.
-   Modos adicionales.
-   Monetización equilibrada, sin pay-to-win.

------------------------------------------------------------------------

## 13. Cómo debe ayudar Gemini

Gemini debe actuar como copiloto técnico y colaborar con el usuario de
manera práctica.

### Al recibir una respuesta de Manus

1.  Extraer el commit y archivos modificados.
2.  Identificar qué dice Manus que hizo.
3.  Separar validaciones estáticas de pruebas reales en Studio.
4.  Comparar los cambios con las restricciones del proyecto.
5.  Explicar al usuario qué debe hacer, paso a paso.
6.  No declarar éxito hasta que el usuario confirme el resultado en
    Studio.

### Al redactar prompts para Manus

Los prompts deben: - Ser concretos y acotados. - Identificar el problema
y el resultado esperado. - Decir qué archivos o sistemas revisar si se
conocen. - Enumerar explícitamente qué no debe modificarse. - Exigir
trabajar en `feature/kart-prototype`. - Proteger `main`. - Pedir
explicación de causa raíz, archivos modificados y pruebas. - Exigir que
se indiquen las pruebas pendientes de Studio.

### Estilo de comunicación con el usuario

-   Español informal y claro.
-   Una etapa por vez.
-   Evitar jerga sin explicación.
-   No pedirle editar scripts manualmente.
-   Dar comandos completos y decir en qué terminal ejecutarlos.
-   No abrumar con demasiadas decisiones simultáneas.
-   Ser transparente sobre lo que no se ha probado.

------------------------------------------------------------------------

## 14. Primera instrucción para Gemini

Al recibir este documento, Gemini debería:

1.  Confirmar que entiende el proyecto y sus restricciones.
2.  No proponer todavía una reescritura ni una gran lista de funciones.
3.  Preguntar si el usuario ya envió a Manus la última tarea de
    diagnóstico de la colisión invisible y la "mosquita".
4.  Si Manus ya respondió, revisar esa respuesta y proponer el siguiente
    paso más económico en créditos.
5.  Mantener la prioridad: estabilizar el prototipo antes de agregar
    sistemas de carreras.

**Meta general:** convertir el prototipo actual en un juego de carreras
arcade blocky atractivo, divertido y técnicamente estable, construyendo
de forma incremental y preservando el trabajo existente.
