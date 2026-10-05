# Cambia el tema de las terminales. Sin argumentos lista las opciones y pregunta.
# Devuelve $true si cambio el tema.
#   theme            -> lista y pregunta
#   theme illusi0n   -> cambia directo
param([string]$Name)

$Themes = [ordered]@{
    athanor  = 'Srcery, fuente IBM VGA 8x16, splash con grabados'
    illusi0n = 'Dark+, Hack Nerd Font, anifetch'
}
$stateFile = Join-Path $PSScriptRoot 'theme'
$current = Get-Content $stateFile -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $current) { $current = 'athanor' }

if (-not $Name) {
    $i = 0
    foreach ($t in $Themes.Keys) {
        $i++
        $mark = if ($t -eq $current) { '*' } else { ' ' }
        Write-Host (" $mark $i) {0,-9} {1}" -f $t, $Themes[$t])
    }
    $answer = Read-Host 'Tema (numero o nombre, Enter para cancelar)'
    if (-not $answer) { return $false }
    $Name = if ($answer -match '^\d+$' -and [int]$answer -ge 1 -and [int]$answer -le $Themes.Count) { @($Themes.Keys)[[int]$answer - 1] } else { $answer }
}

$Name = $Name.ToLower()
if (-not $Themes.Contains($Name)) {
    Write-Host "Tema desconocido: $Name. Opciones: $($Themes.Keys -join ', ')"
    return $false
}
if ($Name -eq $current) {
    Write-Host "Ya estas en $Name."
    return $false
}

function Set-Prop($obj, [string]$name, $value) { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force }
function Remove-Prop($obj, [string]$name) { if ($obj.PSObject.Properties[$name]) { $obj.PSObject.Properties.Remove($name) } }

# --- Windows Terminal: se reescribe settings.json y la terminal lo recarga sola ---
$wt = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal*\LocalState\settings.json') -ErrorAction SilentlyContinue | Select-Object -First 1
if ($wt) {
    $json = Get-Content $wt.FullName -Raw | ConvertFrom-Json
    $d = $json.profiles.defaults
    if ($Name -eq 'athanor') {
        Set-Prop $d 'antialiasingMode' 'aliased'
        Set-Prop $d 'colorScheme' 'Srcery'
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

# --- WezTerm lee este archivo desde .wezterm.lua y el perfil de PowerShell tambien ---
[IO.File]::WriteAllText($stateFile, $Name)
Write-Host "Tema: $Name"
return $true
