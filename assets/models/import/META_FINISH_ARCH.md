# Arco de meta — lona texturizada

## Archivos fuente
- `META_BANNER.fbx`: malla de la lona exportada desde Blender. Es únicamente la lona; no sustituye la estructura completa del arco.
- `META_BANNER_TEXTURE.png`: textura de la lona con el logotipo BLOXY KARTS y banderas a cuadros.
- Asset de imagen ya cargado en Roblox: `rbxassetid://71542588828532`.

## Acabados acordados
- Estructura y travesaños: gris metálico (`Enum.Material.Metal`).
- Postes: blanco metálico (`Enum.Material.Metal`).
- Lona: textura PNG anterior, sin recolorear el diseño.

## Integración segura en Roblox Studio
1. Importar `META_BANNER.fbx` como modelo/malla nueva; no reemplazar el modelo publicado META (`132205617373322`) completo.
2. Revisar el encaje de la lona en el arco existente. Mantener posición, escala y orientación del arco original.
3. Aplicar `rbxassetid://71542588828532` a la propiedad `TextureID` de la MeshPart de la lona (o usar SurfaceAppearance si el importador la convirtió en otro tipo de malla y corresponde).
4. Mantener la estructura original. Asignar gris metálico a vigas/soportes y blanco metálico a los postes, sin tocar otras piezas del circuito.
5. Probar visualmente en Studio antes de publicar el modelo.

## Importante
El FBX contiene solo la lona. El repositorio no puede publicar por sí solo un modelo dentro de Roblox ni verificar su ajuste visual en la sesión local de Studio. No borrar ni sobrescribir el arco existente hasta comprobar el encaje.
