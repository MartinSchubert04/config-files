# Cambia el tema de las terminales. Sin argumentos lista las opciones y pregunta.
# Devuelve $true si cambio el tema.
#   theme            -> lista y pregunta
#   theme illusi0n   -> cambia directo
#   theme umber      -> athanor con la paleta umber (las paletas salen de palettes.json)
#   theme athanor    -> athanor con la ultima paleta usada
param([string]$Name)

$palettes = Get-Content (Join-Path $PSScriptRoot 'palettes.json') -Raw | ConvertFrom-Json
$stateFile = Join-Path $PSScriptRoot 'theme'
$paletteFile = Join-Path $PSScriptRoot 'palette'
$current = Get-Content $stateFile -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $current) { $current = 'athanor' }
$currentPalette = Get-Content $paletteFile -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $currentPalette -or -not $palettes.PSObject.Properties[$currentPalette]) { $currentPalette = 'srcery' }

# Una opcion por paleta de athanor, mas illusi0n
$Options = [ordered]@{}
foreach ($p in $palettes.PSObject.Properties) { $Options[$p.Name] = "athanor, $($p.Value.desc)" }
$Options['illusi0n'] = 'Dark+, Hack Nerd Font, anifetch'
$active = if ($current -eq 'athanor') { $currentPalette } else { $current }

if (-not $Name) {
    $i = 0
    foreach ($t in $Options.Keys) {
        $i++
        $mark = if ($t -eq $active) { '*' } else { ' ' }
        Write-Host (" $mark $i) {0,-9} {1}" -f $t, $Options[$t])
    }
    $answer = Read-Host 'Tema (numero o nombre, Enter para cancelar)'
    if (-not $answer) { return $false }
    $Name = if ($answer -match '^\d+$' -and [int]$answer -ge 1 -and [int]$answer -le $Options.Count) { @($Options.Keys)[[int]$answer - 1] } else { $answer }
}

$Name = $Name.ToLower()
if ($Name -eq 'athanor') { $Name = $currentPalette }
if (-not $Options.Contains($Name)) {
    Write-Host "Tema desconocido: $Name. Opciones: $($Options.Keys -join ', ')"
    return $false
}
if ($Name -eq $active) {
    Write-Host "Ya estas en $Name."
    return $false
}
$theme = if ($Name -eq 'illusi0n') { 'illusi0n' } else { 'athanor' }
$palette = if ($theme -eq 'athanor') { $Name } else { $currentPalette }

function Set-Prop($obj, [string]$name, $value) { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force }
function Remove-Prop($obj, [string]$name) { if ($obj.PSObject.Properties[$name]) { $obj.PSObject.Properties.Remove($name) } }

# --- Windows Terminal: se reescribe settings.json y la terminal lo recarga sola ---
$wt = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal*\LocalState\settings.json') -ErrorAction SilentlyContinue | Select-Object -First 1
if ($wt) {
    $json = Get-Content $wt.FullName -Raw | ConvertFrom-Json
    $d = $json.profiles.defaults
    if ($theme -eq 'athanor') {
        # El esquema de colores y el tema de pestañas de la paleta se agregan o se pisan por nombre
        $p = $palettes.$palette
        $scheme = [ordered]@{ name = $p.label; background = $p.bg; foreground = $p.fg; cursorColor = $p.active; selectionBackground = $p.dim }
        $i = 0
        foreach ($c in 'black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white') {
            $scheme[$c] = $p.ansi[$i]
            $scheme['bright' + $c.Substring(0, 1).ToUpper() + $c.Substring(1)] = $p.ansi[$i + 8]
            $i++
        }
        Set-Prop $json 'schemes' (@(@($json.schemes) | Where-Object { $_ -and $_.name -ne $p.label }) + [pscustomobject]$scheme)
        $tab = $p.bg + 'FF'
        $tabTheme = [pscustomobject][ordered]@{
            name   = 'Athanor'
            tab    = [ordered]@{ background = $tab; showCloseButton = 'hover'; unfocusedBackground = $tab }
            tabRow = [ordered]@{ background = $tab; unfocusedBackground = $tab }
            window = [ordered]@{ applicationTheme = $(if ($p.light) { 'light' } else { 'dark' }); useMica = $false }
        }
        Set-Prop $json 'themes' (@(@($json.themes) | Where-Object { $_ -and $_.name -ne 'Athanor' }) + $tabTheme)

        Set-Prop $d 'antialiasingMode' 'aliased'
        Set-Prop $d 'colorScheme' $p.label
        Set-Prop $d 'cursorShape' 'filledBox'
        Set-Prop $d 'font' ([pscustomobject]@{ face = 'PxPlus IBM VGA 8x16, Hack Nerd Font Mono'; size = 12 })
        Set-Prop $d 'opacity' 100
        Set-Prop $d 'padding' '8'
        Set-Prop $d 'useAcrylic' $false
        Set-Prop $json 'theme' 'Athanor'
        Set-Prop $json 'useAcrylicInTabRow' $false
        # Mismo tamaño en pixeles que illusi0n (130x39 celdas de 10x19 = 164x46 celdas de 8x16), para que
        # al cambiar de tema con la ventana abierta no se recorte ni anifetch ni el splash.
        Set-Prop $json 'initialCols' 164
        Set-Prop $json 'initialRows' 46
    } else {
        Set-Prop $json 'initialCols' 130
        Set-Prop $json 'initialRows' 39
        Set-Prop $d 'colorScheme' 'Dark+'
        Set-Prop $d 'font' ([pscustomobject]@{ face = 'Hack Nerd Font Mono' })
        foreach ($p in 'antialiasingMode', 'cursorShape', 'opacity', 'padding', 'useAcrylic') { Remove-Prop $d $p }
        Remove-Prop $json 'theme'
        Set-Prop $json 'useAcrylicInTabRow' $true
    }
    [IO.File]::WriteAllText($wt.FullName, ($json | ConvertTo-Json -Depth 32))
}

# --- WezTerm lee estos archivos desde .wezterm.lua y el perfil de PowerShell tambien ---
[IO.File]::WriteAllText($paletteFile, $palette)
[IO.File]::WriteAllText($stateFile, $theme)
Write-Host "Tema: $Name"
return $true
