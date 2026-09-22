# Despiértame · alarma por distancia para iOS

App nativa (Swift + SwiftUI) que hace sonar una alarma cuando te acercas a un destino.
Pensada para dormir en el bus o en el carro sin pasarte de tu parada: eliges el lugar,
un radio, y la alarma suena aunque el iPhone esté bloqueado o con el interruptor en silencio.

- Sin servidores ni cuentas: todo se guarda en el iPhone.
- Sin dependencias externas: solo frameworks de Apple (CoreLocation, MapKit, AVFoundation, UserNotifications).
- Se compila en GitHub Actions (runners macOS) y se instala desde Windows con AltStore o SideStore.
  No hace falta Mac ni cuenta Apple Developer de pago.

## Funcionalidades

- Destino por **pulsación larga en el mapa**, **búsqueda de dirección o lugar** (Apple Maps),
  **favoritos** e **historial de recientes**.
- **Radio configurable** por alarma (100 m a 5 km) con presets rápidos.
- **Pre-aviso** opcional al acercarte (1 a 5 km antes) con una notificación suave.
- **Varias alarmas encendidas a la vez** (varios destinos o paradas en un mismo viaje).
- **Suena en silencio y bloqueado**: el tono se reproduce como audio de la app en bucle hasta
  que la detengas, con vibración, y una notificación de respaldo con botón "Detener" que se
  repite cada 45 s. Se apaga sola tras 15 minutos para no agotar la batería.
- **Ahorro de batería adaptativo**: lejos del destino usa GPS de baja precisión; a menos de
  1 km, precisión máxima.
- **Respaldo por geovallado**: cada alarma registra una región en iOS; con el permiso
  "Siempre", el sistema puede relanzar la app si la hubiera cerrado.
- **Aviso de GPS perdido** si pasan más de 2 minutos sin ubicación con alarmas encendidas.
- Aviso si el volumen está bajo y si iOS cierra la app con alarmas encendidas.

## Instalar en tu iPhone

Cada push a `main` publica un `.ipa` sin firmar en
[Releases](../../releases/latest). Guía completa paso a paso, para Windows y sin Mac:
**[docs/INSTALACION.md](docs/INSTALACION.md)**.

Resumen: instalas AltServer en Windows, AltStore en el iPhone, descargas el `.ipa` de la
última release y lo abres con AltStore, que lo firma con tu Apple ID gratuito. La firma caduca
cada 7 días y AltStore la renueva cuando el iPhone y el PC están en la misma red Wi‑Fi.

## Verla sin instalarla

Cada release incluye también capturas, un vídeo del recorrido por la app y una compilación
para el simulador de iOS que puedes ejecutar en el navegador con Appetize.io.
Guía: **[docs/DEMO.md](docs/DEMO.md)**.

## Cómo funciona por dentro

```
Despiertame/
├── App/            Punto de entrada SwiftUI + AppDelegate (relanzamiento por región, cierre)
├── Models/         Alarm, SavedPlace, valores por defecto
├── Core/           AlarmEvaluator (lógica pura de disparo), AlarmEngine (orquestación),
│                   AlarmStore (persistencia JSON), DistanceFormat
├── Services/       LocationService, AlarmSoundPlayer, NotificationService, PlaceSearchService
├── Views/          Home, editor de alarma, búsqueda, favoritos, ajustes, pantalla de alarma
└── Resources/      Assets (icono), Sounds (alarm.wav, silence.wav)
DespiertameTests/   Pruebas unitarias (XCTest) de la lógica de disparo, persistencia y formato
```

Flujo de una alarma encendida:

1. `AlarmEngine.refreshMonitoring()` arranca `CLLocationManager` con
   `allowsBackgroundLocationUpdates` y el perfil de precisión que toque, registra la región
   de respaldo y pone la sesión de audio en modo "viva" (silencio en bucle, mezclado con
   otras apps, para que iOS permita arrancar el sonido en segundo plano).
2. Cada ubicación pasa por `AlarmEvaluator.evaluate`, que calcula una distancia *efectiva*:
   distancia real, menos la imprecisión GPS (acotada a 150 m), menos una anticipación por
   velocidad (5 s de trayecto, máx. 200 m). Es deliberadamente optimista: mejor despertar unos
   metros antes que pasarse.
3. Al entrar en el radio (o si iOS notifica la entrada en la región), la alarma pasa a
   `ringing`: audio en bucle a volumen máximo sin mezcla (pausa tu música), vibración,
   notificación con acción "Detener" y pantalla roja a tamaño completo.
4. Al detenerla, se apaga; si quedan otras alarmas encendidas, se vuelve al modo "viva".

## Desarrollo

El proyecto Xcode no se versiona: se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen)
a partir de `project.yml`.

```bash
# En un Mac (opcional; en CI se hace automáticamente)
brew install xcodegen
xcodegen generate
open Despiertame.xcodeproj

# Regenerar sonidos e icono (solo Python 3, sin dependencias)
python scripts/generate_assets.py
```

CI (`.github/workflows/build.yml`), en cada push y pull request:

- **Pruebas unitarias** en simulador iPhone 17 (`xcodebuild test`).
- **IPA sin firmar** (`xcodebuild build` con `CODE_SIGNING_ALLOWED=NO`), publicado como
  artefacto y, en `main`, como release `build-N` marcada como *latest*.

Ajustes relevantes: iOS 18.0 mínimo, Swift 5 con concurrencia mínima, solo iPhone, orientación
vertical, `UIBackgroundModes = location + audio`.

## Limitaciones conocidas

- **Firma de 7 días** con Apple ID gratuito (limitación de Apple, no de la app). AltStore la
  renueva solo si el PC con AltServer está encendido y en la misma Wi‑Fi; SideStore puede
  renovarla sin PC.
- **No cierres la app** desde el selector de apps con alarmas encendidas: iOS detiene la
  vigilancia. Bloquear la pantalla o usar otras apps es seguro. Con el permiso "Siempre", el
  geovallado puede relanzarla al llegar, pero en ese caso solo llegará la notificación
  (iOS no permite arrancar audio desde una app cerrada).
- **Sin señal GPS** (túneles, bus con vidrios muy tintados en el fondo) la alarma puede
  retrasarse; la app te avisa a los 2 minutos sin ubicación.
- No usa *Critical Alerts* (requiere un permiso especial de Apple): por eso el sonido va por
  la sesión de audio y no por la notificación. Usa el volumen multimedia, no el de timbre.
- El **modo Bajo consumo** de iOS puede reducir la frecuencia de ubicaciones.
- Hasta **20 alarmas** con región de respaldo simultáneas (límite de iOS); las demás funcionan
  solo con las actualizaciones continuas.

## Privacidad

La ubicación se procesa únicamente en el dispositivo. La única salida a internet son las
búsquedas de lugares y la geocodificación inversa, que van a Apple Maps a través de MapKit.
