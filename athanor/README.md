# athanor

Tema opcional que adapta a Windows el look de [script-wizards/athanor](https://github.com/script-wizards/athanor):
paleta [Srcery](https://srcery.sh/), fuente IBM VGA 8x16 y grabados de Doré pasados a dos colores.
Se aplica encima de `windows-terminal/settings.json`.

## Qué incluye

| Ruta | Qué es |
|---|---|
| `windows-terminal.json` | Esquema Srcery, tema de pestañas, valores por defecto de perfil y atajo de focus mode |
| `scripts/install-font.ps1` | Instala `PxPlus IBM VGA 8x16` para el usuario actual |
| `scripts/make-images.ps1` | Genera las imágenes a partir de `images/plate.jpg` |
| `images/plate.jpg` | Grabado original (Gustave Doré, *Paradise Lost*, dominio público, vía Wikimedia Commons) |
| `images/wall.png` | Fondo de escritorio 2560x1440 |
| `images/lock.png` | Imagen para la pantalla de bloqueo 2560x1440 |
| `images/term-bg.png` | Fondo opcional para dentro de la terminal |
| `splash.ps1` | Splash de WezTerm: grabado al azar, sigilo del host, reloj, hora planetaria y luna |
| `splash/` | Grabados ya procesados (512x640, dos colores) entre los que elige el splash |
| `plates/` | Originales en dominio público, vía Wikimedia Commons: Doré, Miguel Ángel, Caravaggio, Cabanel, Bouguereau, Bruegel, Botticelli, Friedrich, Fuseli, Blake, Martin, Rafael, Reni |
| `scripts/make-splash.ps1` | Regenera `splash/` a partir de `plates/` |

## Instalación

### 1. Fuente

```powershell
.\scripts\install-font.ps1
```

### 2. Windows Terminal

Hacé una copia de tu `settings.json` y fusioná a mano las claves de `windows-terminal.json`:

- `schemes` y `themes`: agregar los elementos a las listas existentes.
- `profiles.defaults`: agregar las claves. Los perfiles con colores o fuente propios no cambian.
- `actions` y `keybindings`: agregar el elemento a cada lista.
- `theme` y `useAcrylicInTabRow`: van en la raíz.

`Alt+Shift+F` oculta o muestra la barra de título y las pestañas.

La fuente se ve nítida a 12 pt o 24 pt (con escala de pantalla al 100 %); los tamaños intermedios deforman los píxeles.
`Hack Nerd Font Mono` queda como respaldo para los íconos del prompt, que la fuente VGA no trae.

### 3. WezTerm con splash

```powershell
Copy-Item ..\wezterm\.wezterm.lua ~\.wezterm.lua
New-Item -ItemType Directory -Force ~\.config\athanor\splash
Copy-Item splash.ps1 ~\.config\athanor\
Copy-Item splash\*.png ~\.config\athanor\splash\
```

Al abrir WezTerm se imprime, como anifetch, un grabado elegido al azar y a su derecha el sigilo del host,
el reloj, la fecha, la hora planetaria y la fase de la luna. Después queda el prompt normal.

- Lo lanza el perfil de pwsh (`powershell/Microsoft.PowerShell_profile.ps1`) en lugar de anifetch.
- La ventana no tiene borde: se arrastra desde la barra de pestañas o con Ctrl+Shift+clic izquierdo.
- Solo se muestra en WezTerm y si la ventana tiene al menos 120x43 celdas (en splits chicos se saltea).
- El reloj es la hora de apertura; no se actualiza.
- Amanecer y atardecer se calculan para Buenos Aires; cambiar `-Lat` y `-Lon` en `splash.ps1`.
- Para sumar imágenes: dejar el archivo en `plates/` y correr `scripts\make-splash.ps1`.
- Las imágenes miden 520x640 px: 512x640 de dibujo (64x40 celdas de 8x16) más una columna de 8 px en el
  color de fondo, que tapa la celda que WezTerm deja vacía en la esquina inferior derecha.

### 4. Imágenes de escritorio y bloqueo

Las de `images/` están hechas para 2560x1440. Para otra resolución u otro grabado:

```powershell
winget install ImageMagick.ImageMagick
.\scripts\make-images.ps1 -Width 1920 -Height 1080
```

- **Escritorio:** clic derecho en `wall.png` > Establecer como fondo de escritorio.
- **Pantalla de bloqueo:** Configuración > Personalización > Pantalla de bloqueo > Imagen > `lock.png`,
  con "Mostrar la imagen de fondo de la pantalla de bloqueo en la pantalla de inicio de sesión" activado
  y el estado en "Ninguno".
- **Sin desenfoque en el inicio de sesión** (requiere administrador):

  ```powershell
  reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v DisableAcrylicBackgroundOnLogon /t REG_DWORD /d 1 /f
  ```

- **Fondo dentro de la terminal** (opcional), en `profiles.defaults`:

  ```json
  "backgroundImage": "C:\\ruta\\a\\term-bg.png",
  "backgroundImageAlignment": "bottomRight",
  "backgroundImageOpacity": 1.0,
  "backgroundImageStretchMode": "none"
  ```

## Límites en Windows

- La pantalla de inicio de sesión solo admite cambiar la imagen; el reloj y la caja de contraseña no se pueden reubicar ni restilizar.
- Termius (10.1.3) no admite temas ni fuentes propias; lo más cercano es el tema Flexoki Dark o Gruvbox Dark.
- Falta el tiling con bordes y las barras (GlazeWM o komorebi, más Zebar o YASB).

## Créditos

- [athanor](https://github.com/script-wizards/athanor), de script-wizards
- [Srcery](https://srcery.sh/)
- [The Ultimate Oldschool PC Font Pack](https://int10h.org/oldschool-pc-fonts/), de VileR (CC BY-SA 4.0)
- Dígitos del reloj rasterizados de [Jacquard 24](https://fonts.google.com/specimen/Jacquard+24) (OFL)
- Estética inspirada en [MEK.txt](https://www.mek.gallery/); no se incluye obra suya
