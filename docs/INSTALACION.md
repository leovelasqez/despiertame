# Instalar Despiértame en tu iPhone desde Windows (sin Mac)

Esta guía está pensada para la primera vez. Después, actualizar es solo repetir el paso 5.

## Qué necesitas

- PC con **Windows 10 u 11** y cable USB para el iPhone.
- **iPhone** con iOS 16 o superior (tú tienes iOS 26.7).
- Tu **Apple ID** (el mismo que usas en el iPhone). Sirve el gratuito; no hace falta cuenta de
  desarrollador de pago.
- Conexión **Wi‑Fi** compartida entre el PC y el iPhone (para renovar la firma sin cable).

Límites que impone Apple con cuentas gratuitas:

- Las apps instaladas así **caducan cada 7 días**. AltStore las renueva automáticamente si el
  PC con AltServer está encendido en la misma Wi‑Fi. Si caduca, no se borra: solo deja de abrir
  hasta que la renueves.
- Máximo **3 apps** instaladas por este método a la vez (AltStore cuenta como una).
- Máximo **10 identificadores de app** por semana (cada app o extensión nueva consume uno;
  Despiértame consume uno).

## Paso 1 · iTunes e iCloud de Apple (no los de la Microsoft Store)

AltServer se comunica con el iPhone a través de estos programas, y **solo funciona con las
versiones descargadas de la web de Apple**, no con las de la Microsoft Store.

1. Si tienes iTunes o iCloud de la Microsoft Store, desinstálalos primero
   (Configuración → Aplicaciones → Aplicaciones instaladas).
2. Descarga e instala **iTunes para Windows (64 bits)** desde el enlace "Windows" al final de
   la página de Apple: <https://support.apple.com/es-es/HT210384> (elige la opción que dice
   *"¿Buscas otras versiones?"* → *Windows*).
3. Descarga e instala **iCloud para Windows** desde <https://support.apple.com/es-es/HT204283>
   usando también el instalador directo de Apple (no el de la Store).
4. Reinicia el PC.

## Paso 2 · Instalar AltServer en Windows

1. Entra en <https://altstore.io> y descarga **AltServer para Windows** (`AltInstaller.msi`).
2. Ejecútalo. Al terminar, AltServer aparece como un icono de rombo en la bandeja del sistema
   (junto al reloj; si no lo ves, pulsa la flecha "mostrar iconos ocultos").
3. Conecta el iPhone por USB. En el iPhone toca **"Confiar"** y escribe tu código si te lo pide.
4. Abre iTunes, selecciona el iPhone (icono arriba a la izquierda) y en *Resumen* → *Opciones*
   marca **"Sincronizar con este iPhone vía Wi‑Fi"**. Pulsa *Aplicar*. Esto permite que AltStore
   renueve la firma sin cable.

## Paso 3 · Activar el modo de desarrollador en el iPhone

Desde iOS 16 las apps instaladas fuera de la App Store lo exigen.

1. En el iPhone: **Ajustes → Privacidad y seguridad → Modo de desarrollador** → activar.
   Si la opción no aparece, conéctalo por USB con AltServer/iTunes abiertos y vuelve a mirar.
2. Reinicia el iPhone cuando te lo pida y confirma la activación al encenderlo.

## Paso 4 · Instalar AltStore en el iPhone

1. En el PC, clic en el icono de AltServer de la bandeja → **Install AltStore** → elige tu iPhone.
2. Escribe tu **Apple ID y contraseña**. Se usan solo para pedirle a Apple el certificado de
   firma; AltStore no los envía a terceros. Si tienes verificación en dos pasos, te llegará un
   código al iPhone: escríbelo cuando se pida.
3. Espera a que aparezca AltStore en la pantalla de inicio del iPhone.
4. En el iPhone: **Ajustes → General → VPN y gestión de dispositivos** (o *Gestión de
   dispositivos*) → toca tu Apple ID → **Confiar**.
5. Abre AltStore. Si pide permiso de ubicación o notificaciones, acéptalo: lo usa para poder
   renovar las firmas en segundo plano.

## Paso 5 · Descargar e instalar Despiértame

Opción A, todo desde el iPhone (la más cómoda):

1. En Safari del iPhone abre la última release:
   `https://github.com/leovelasqez/despiertame/releases/latest`
2. Toca **`Despiertame.ipa`** para descargarlo. Se guarda en la app *Archivos* → *Descargas*.
3. Abre **AltStore → Mis apps** → toca **+** (arriba a la izquierda) → elige `Despiertame.ipa`.
4. Espera a que termine la instalación (verás el progreso en la pestaña *Mis apps*).

Opción B, desde el PC:

1. Descarga `Despiertame.ipa` de la misma página de releases en el PC.
2. Con el iPhone conectado por USB o en la misma Wi‑Fi, clic en el icono de AltServer →
   **Sideload .ipa** → elige tu iPhone → selecciona el archivo.

Al terminar, **Despiértame** aparece en la pantalla de inicio. Si al abrirla dice "desarrollador
no confiable", repite el paso 4.4.

## Paso 6 · Primer arranque y permisos

Al crear la primera alarma, la app pide:

1. **Ubicación** → elige **"Permitir mientras se usa la app"** y deja activada **"Ubicación
   precisa"**. Poco después iOS preguntará si quieres cambiar a **"Siempre"**: acéptalo. Es el
   respaldo que permite relanzar la app si el sistema la cerrara.
2. **Notificaciones** → **Permitir**. Son el respaldo visible en la pantalla bloqueada y traen
   el botón "Detener alarma".

Puedes revisar todo en la pestaña **Ajustes** de la app o en Ajustes de iOS → Despiértame.

## Cómo usarla en un viaje

1. Sube el **volumen multimedia** (el de música; el interruptor lateral en silencio no afecta).
2. Crea la alarma: mantén pulsado el mapa sobre tu parada, o búscala por nombre.
   Elige un radio (500 m a 1 km va bien en bus) y deja activo "Encender ahora".
3. Bloquea el iPhone y duerme. **No cierres la app desde el selector de apps.** Verás el
   indicador azul de ubicación arriba: es normal.
4. Cuando suene: desbloquea y toca **Detener alarma**, o usa el botón "Detener alarma" de la
   notificación.

Puedes probar el sonido en la app: Ajustes → *Probar sonido de alarma*.

## Renovar la firma (cada 7 días)

- **Automático**: deja AltServer abierto en el PC (arranca con Windows) y el iPhone en la misma
  Wi‑Fi de vez en cuando. AltStore renueva solo.
- **Manual**: abre AltStore → *Mis apps* → **Refresh All** con el PC (AltServer) en la misma red.
- La fecha de caducidad aparece bajo cada app en *Mis apps*.
- Si prefieres renovar **sin PC**, existe **SideStore** (<https://sidestore.io>), una variante
  de AltStore que se renueva sola desde el propio iPhone. Se instala una única vez con el PC.

## Actualizar Despiértame

Cada cambio publicado genera una release nueva. Repite el **paso 5**: AltStore sustituye la app
manteniendo tus alarmas, favoritos e historial.

## Problemas frecuentes

| Síntoma | Solución |
| --- | --- |
| "Could not find AltServer" en el iPhone | PC y iPhone en la misma Wi‑Fi; AltServer abierto; permite AltServer en el Firewall de Windows (redes privadas). Prueba con cable USB. |
| AltServer no ve el iPhone | Instala iTunes/iCloud desde la web de Apple, no desde la Store. Desbloquea el iPhone y toca "Confiar". |
| "Desarrollador empresarial no confiable" al abrir | Ajustes → General → VPN y gestión de dispositivos → tu Apple ID → Confiar. |
| No aparece "Modo de desarrollador" | Conecta por USB con AltServer/iTunes abiertos y vuelve a Ajustes → Privacidad y seguridad. |
| Error de Apple ID al instalar AltStore | Comprueba que la contraseña es correcta y espera el código de dos pasos. Si usas una *contraseña específica de app*, no sirve: usa la normal. |
| La app dejó de abrir | Caducó la firma. Abre AltStore y pulsa *Refresh All* con el PC en la misma red. |
| La alarma no sonó | Comprueba: app no cerrada desde el selector, ubicación "Siempre" + precisa, volumen multimedia alto, notificaciones permitidas. Revisa en la app la tarjeta de estado (precisión GPS). |
| iOS pregunta cada poco por la ubicación "Siempre" | Es normal la primera vez. Acepta "Cambiar a Permitir siempre". |
