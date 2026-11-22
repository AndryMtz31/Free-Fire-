# FFAimbot — esqueleto

Aimbot mínimo para Free Fire iOS sobre Unity/IL2CPP: lee posiciones por memoria,
calcula yaw/pitch y los escribe. Botón flotante para encender y apagar.
Todo lo que pasa se registra en `Documents/ffaimbot.log`.

## Lo que NO trae (a propósito)

- Offsets reales. Todos los `#define` valen `0x0`. Hay que sacarlos.
- ESP, sliders, chams. Solo on/off y constantes en el código.

## Compilar sin PC

1. Forkea este repo.
2. Actions → **build** → *Run workflow*.
3. Espera el artifact `FFAimbot-dylib` y descárgalo desde Safari.
4. Filza: descomprime el zip.
5. iGameGod → *App Manager* → IPA de Free Fire → *Inject* el `.dylib` → instalar.
6. Abre el juego. El botón **AIM** aparece arriba a la izquierda.

## Offsets

| Define | Qué hay que buscar |
|---|---|
| `OFF_UPDATE` | función por frame del jugador local (o usa el tick por timer) |
| `OFF_LOCAL_PLAYER` | puntero al jugador local |
| `OFF_ENTITY_LIST` | puntero al array de jugadores |
| `OFF_ENTITY_COUNT` | `int` con el número de entradas |
| `OFF_POS` | `float x,y,z` de la posición (3 seguidos) |
| `OFF_YAW` / `OFF_PITCH` | `float` de rotación de la cámara |

Los saca el dump de `global-metadata.dat` con `tien0246/Il2CppDumper-Free-Fire`
y el posterior trabajo en Ghidra/IDA. Cambian en cada OB: mantén una tabla por
versión y no reutilices offsets viejos a ciegas.

## Log

`Documents/ffaimbot.log` se escribe al arrancar y cada vez que pulsas el botón.
Si no aparece el archivo, el dylib no cargó.

## Aviso

No es seguro para cuenta principal.
