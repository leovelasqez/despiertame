# Ver Despiértame sin instalarla en el iPhone

Dos formas de ver la app funcionando sin AltStore, sin cable y sin Mac.

## 1. Capturas y vídeo generados automáticamente

Cada compilación en `main` ejecuta un recorrido automático por la app en un simulador de
iPhone 17 y publica el resultado en la release:

- `Despiertame-capturas.zip`: capturas de las pantallas principales (inicio con alarmas
  vigilando, editor de alarma, búsqueda de destino, ajustes, favoritos y la pantalla roja de
  alarma sonando).
- `despiertame-demo.mp4`: vídeo del recorrido completo.

Descarga: <https://github.com/leovelasqez/despiertame/releases/latest>

## 2. Probarla de forma interactiva en el navegador (Appetize.io)

[Appetize.io](https://appetize.io) ejecuta apps iOS en un simulador dentro del navegador.
El plan gratuito da unos 30 minutos al mes en sesiones de hasta 3 minutos, suficiente para
recorrer la app. Necesitas crear una cuenta gratuita (correo y contraseña, sin tarjeta).

1. Descarga `Despiertame-simulador.zip` de la [última release](https://github.com/leovelasqez/despiertame/releases/latest).
   Es la app compilada para el simulador de iOS, no el `.ipa` del iPhone.
2. Entra en <https://appetize.io>, crea una cuenta gratuita y pulsa **Upload**.
3. Arrastra `Despiertame-simulador.zip`. Cuando termine, elige un dispositivo iPhone y la
   versión de iOS más reciente y pulsa **Tap to play**.
4. La app arranca como en un iPhone real: toca **+** para crear una alarma, busca un lugar o
   usa "Usar el centro del mapa", ajusta el radio y guarda.

Detalles para la demo en Appetize:

- **Ubicación**: en el panel lateral de Appetize puedes fijar unas coordenadas GPS. Ponlas a
  menos de 1 km del destino de tu alarma y verás cómo pasa a "Sonando".
- **Modo demostración con datos de ejemplo**: en la configuración de la sesión, añade el
  argumento de lanzamiento `--demo` para arrancar con tres alarmas, favoritos e historial ya
  cargados, sin pedir permisos. Con `--demo --demo-ringing` arranca directamente en la pantalla
  de alarma sonando.
- El sonido de alarma se oye en el navegador si Appetize tiene el audio activado.
- Lo que **no** se puede probar en un simulador: el comportamiento real en segundo plano con la
  pantalla bloqueada, el consumo de batería y el geovallado de iOS. Eso solo se ve en un iPhone.
