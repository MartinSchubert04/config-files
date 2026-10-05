# config-files

Mis configuraciones de Windows. Cada carpeta es una herramienta; la tabla dice dónde va cada archivo.

| Carpeta | Archivo | Destino |
|---|---|---|
| `powershell/` | `Microsoft.PowerShell_profile.ps1` | `$PROFILE` |
| `oh-my-posh/` | `illusi0n.omp.json`, `athanor.omp.json` | `~\.posh\themes\` |
| `fastfetch/` | `config.jsonc`, `ascii.txt`, `blackhole.mp4` | `~\.config\fastfetch\` |
| `windows-terminal/` | `settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\` |
| `wezterm/` | `.wezterm.lua` | `~\.wezterm.lua` (usa el splash de `athanor/`) |
| `athanor/` | Tema retro opcional (Srcery + IBM VGA + grabados) | Ver [athanor/README.md](athanor/README.md) |

## PowerShell

```pwsh
New-Item -Path $PROFILE -Type File -Force
Copy-Item powershell\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

Cambiar en el perfil la ruta del theme y la del video según corresponda.

### PSReadLine

\*\* PredictionView solo para PowerShell 7

```pwsh
Install-Module PSReadLine -Force -AllowClobber
```

### Iconos

```pwsh
Install-Module -Name Terminal-Icons -Repository PSGallery
```

## Oh My Posh

```pwsh
New-Item -ItemType Directory -Force ~\.posh\themes
Copy-Item oh-my-posh\*.omp.json ~\.posh\themes\
```

El perfil usa `athanor` (paleta Srcery) en WezTerm y Windows Terminal, e `illusi0n` en VS Code y SSH.
`athanor` suma versión de Python y Node, código de error, duración del comando y hora a la derecha.

## Fastfetch + Anifetch

Source [here](https://github.com/Notenlish/anifetch)

```
winget install chafa ffmpeg fastfetch
```

```
pip install anifetch-cli
```

```pwsh
New-Item -ItemType Directory -Force ~\.config\fastfetch
Copy-Item fastfetch\* ~\.config\fastfetch\
```

La animacion no se ejecuta en la terminal integrada de VS Code ni en sesiones de OpenSSH.

## Windows Terminal

Copiar `windows-terminal/settings.json` a:

```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

## Fonts

```pwsh
oh-my-posh font install Hack
```

Recomendadas:

- Hack mono
- Fira code mono
- Meslo
- Jetbrains

[more](https://www.nerdfonts.com/)

## VS Code

```json
{
  "terminal.integrated.fontFamily": "Hack Nerd Font",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.lineHeight": 1.2
}
```
