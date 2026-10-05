# Splash estilo athanor: grabado al azar, sigilo del host, reloj y hora planetaria.
# Solo ASCII en el fuente para que corra igual en Windows PowerShell 5.1 y en pwsh 7.
param(
    [double]$Lat = -34.60,   # Buenos Aires; se usa para amanecer/atardecer
    [double]$Lon = -58.38,
    [string]$Image = $env:ATHANOR_IMAGE,   # nombre sin extension para fijar una imagen (pruebas)
    [switch]$Force
)

$ImgCols = 64; $ImgRows = 40      # parte visible de la imagen: 512x640 px = 64x40 celdas de 8x16
$PanelCol = 71                    # columna donde arranca el panel derecho
$MinCols = 120; $MinRows = 43

if (-not $Force -and $env:TERM_PROGRAM -ne 'WezTerm') { return }
$size = $Host.UI.RawUI.WindowSize
if ($size.Width -lt $MinCols -or $size.Height -lt $MinRows) { return }

$images = @(Get-ChildItem (Join-Path $PSScriptRoot 'splash') -Filter *.png -ErrorAction SilentlyContinue)
if ($images.Count -eq 0) { return }

$e = [char]27
$amber = "$e[38;2;251;184;41m"; $cream = "$e[38;2;252;232;195m"; $dim = "$e[38;2;145;129;117m"
$rule = "$e[38;2;60;58;54m"; $bold = "$e[1m"; $reset = "$e[0m"
$full = [string][char]0x2588; $upper = [string][char]0x2580; $lower = [string][char]0x2584
$sb = New-Object System.Text.StringBuilder
function At([int]$row, [int]$col, [string]$text) { [void]$sb.Append("$e[$row;${col}H$text$reset") }

# --- Hora planetaria (orden caldeo, la primera hora del dia la rige el planeta del dia) ---
$Chaldean = 'Saturn', 'Jupiter', 'Mars', 'Sun', 'Venus', 'Mercury', 'Moon'
$DayRuler = 3, 6, 2, 5, 1, 4, 0   # domingo primero

function Get-SunTimes([datetime]$date) {
    $n = $date.DayOfYear
    $decl = -23.44 * [Math]::Cos(2 * [Math]::PI / 365 * ($n + 10)) * [Math]::PI / 180
    $x = -[Math]::Tan($Lat * [Math]::PI / 180) * [Math]::Tan($decl)
    $ha = [Math]::Acos([Math]::Max(-1, [Math]::Min(1, $x))) * 180 / [Math]::PI
    $b = 2 * [Math]::PI * ($n - 81) / 364
    $eq = 9.87 * [Math]::Sin(2 * $b) - 7.53 * [Math]::Cos($b) - 1.5 * [Math]::Sin($b)
    $noon = 12 - $Lon / 15 - $eq / 60
    $utc = New-Object datetime $date.Year, $date.Month, $date.Day, 0, 0, 0, ([DateTimeKind]::Utc)
    @{ Rise = $utc.AddHours($noon - $ha / 15).ToLocalTime(); Set = $utc.AddHours($noon + $ha / 15).ToLocalTime() }
}

$now = Get-Date
$sun = Get-SunTimes $now.Date
if ($now -lt $sun.Rise) { $sun = Get-SunTimes $now.Date.AddDays(-1) }   # antes del amanecer sigue el dia anterior
$isDay = $now -lt $sun.Set
$daylight = ($sun.Set - $sun.Rise).TotalHours
if ($isDay) { $span = $daylight / 12; $start = $sun.Rise } else { $span = (24 - $daylight) / 12; $start = $sun.Set }
$hour = [Math]::Floor(($now - $start).TotalHours / $span)
if (-not $isDay) { $hour += 12 }
$ruler = $DayRuler[[int]$sun.Rise.DayOfWeek]
$dayPlanet = $Chaldean[$ruler]
$hourPlanet = $Chaldean[($ruler + $hour) % 7]

# --- Luna ---
$synodic = 29.530588853
$newMoon = New-Object datetime 2000, 1, 6, 18, 14, 0, ([DateTimeKind]::Utc)
$age = ($now.ToUniversalTime() - $newMoon).TotalDays % $synodic
$phase = if ($age -lt 1 -or $age -gt $synodic - 1) { 'new' }
         elseif ([Math]::Abs($age - $synodic / 2) -lt 1) { 'full' }
         elseif ($age -lt $synodic / 2) { 'waxing' } else { 'waning' }

# --- Sigilo del host: identicon simetrico de 5x5 a partir del SHA256 del nombre ---
$sha = [Security.Cryptography.SHA256]::Create()
$hash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($env:COMPUTERNAME))
$b64 = [Convert]::ToBase64String($hash).TrimEnd('=')
$hz = [string][char]0x2500; $vt = [string][char]0x2502
At 4 $PanelCol ($amber + [char]0x250C + ($hz * 12) + [char]0x2510)
for ($y = 0; $y -lt 5; $y++) {
    $line = ''
    foreach ($x in 0, 1, 2, 1, 0) { $line += if ($hash[$y * 3 + $x] -band 1) { $full * 2 } else { '  ' } }
    At (5 + $y) $PanelCol "$amber$vt $line $vt"
}
At 10 $PanelCol ($amber + [char]0x2514 + ($hz * 12) + [char]0x2518)
At 5 ($PanelCol + 16) ($dim + $env:COMPUTERNAME.ToLower())
At 6 ($PanelCol + 16) ($dim + 'host sigil, from')
At 7 ($PanelCol + 16) ($dim + 'SHA256:' + $b64.Substring(0, 5) + '...' + $b64.Substring($b64.Length - 3))

# --- Reloj: digitos de Jacquard 24 rasterizados, dos filas de pixeles por celda ---
$Digits = @{
    '0' = @('.........','.........','.........','.........','..#####..','..#.###..','.##..##..','.##..##..','.##..##..','.##..##..','.##..##..','.##..##..','.###.#...','.#####...','.........','.........','.........','.........')
    '1' = @('......','......','......','......','.###..','.###..','..##..','..##..','..##..','..##..','..##..','..##..','..#...','......','......','......','......','......')
    '2' = @('.........','.........','.........','.........','..####...','.#..###..','.#...##..','.....##..','.....##..','....##...','...##....','..##.....','.######..','.#####...','.........','.........','.........','.........')
    '3' = @('........','........','........','........','..##....','.#####..','....#...','...#....','...#....','..##....','...###..','....##..','....##..','....##..','....##..','.##.#...','.###....','..#.....')
    '4' = @('..........','..........','..........','..........','......#...','......#...','.....##...','...####...','...#.##...','..#..##...','.#...##...','.#######..','.######...','.....##...','.....##...','.....##...','.....#....','.....#....')
    '5' = @('........','........','........','........','...###..','..###...','.#......','.#......','.####...','.#####..','....##..','....##..','....##..','.##.##..','.##.##..','.####...','.###....','.##.....')
    '6' = @('....#....','....#....','..####...','.##.#....','.##......','.##......','.####....','.##.##...','.##.###..','.##.###..','.##.###..','.##.###..','.#####...','..##.....','.........','.........','.........','.........')
    '7' = @('..........','..........','..........','..........','..######..','.######...','....##....','....#.....','...##.....','..##......','..##......','..##......','..##......','..##......','..##......','..##......','..##......','..#.......')
    '8' = @('....#....','...###...','..#.###..','.##..##..','.###.....','.#####...','..####...','.######..','.#..###..','.##..##..','.##..##..','.###.##..','..####...','...##....','.........','.........','.........','.........')
    '9' = @('.........','.........','.........','.........','...###...','..#####..','.##.###..','.##.###..','.##.###..','.##.###..','.##.###..','..#####..','....###..','....###..','....##...','..#.##...','.####....','..##.....')
    ':' = @('.....','.....','.....','.##..','.##..','.....','.....','.....','.....','.....','.....','.....','.##..','.##..','.....','.....','.....','.....')
}
$clock = $now.ToString('H:mm')
for ($r = 0; $r -lt 9; $r++) {
    $line = ''
    foreach ($ch in $clock.ToCharArray()) {
        $top = $Digits[[string]$ch][$r * 2]; $bot = $Digits[[string]$ch][$r * 2 + 1]
        for ($x = 0; $x -lt $top.Length; $x++) {
            $t = $top[$x] -eq '#'; $u = $bot[$x] -eq '#'
            $line += if ($t -and $u) { $full } elseif ($t) { $upper } elseif ($u) { $lower } else { ' ' }
        }
    }
    At (14 + $r) $PanelCol ($cream + $line)
}

# --- Fecha ---
$inv = [Globalization.CultureInfo]::InvariantCulture
$d = $now.Day
$suffix = if ($d % 100 -ge 11 -and $d % 100 -le 13) { 'th' } else { switch ($d % 10) { 1 { 'st' } 2 { 'nd' } 3 { 'rd' } default { 'th' } } }
At 25 $PanelCol ($bold + $cream + $now.ToString('dddd', $inv) + ", the $d$suffix of " + $now.ToString('MMMM', $inv))
At 26 $PanelCol ($amber + "Day of the $dayPlanet, hour of $hourPlanet")
$moonLine = if ($phase -in 'new', 'full') { "Moon $phase" } else { "Moon $phase, $([int][Math]::Floor($age)) days old" }
At 27 $PanelCol ($dim + $moonLine)

for ($r = 1; $r -le $ImgRows; $r++) { At $r ($ImgCols + 4) ($rule + $vt) }

# --- Salida: primero la imagen, despues el texto con posiciones absolutas ---
# Se emite la secuencia de imagen a mano con doNotMoveCursor: `wezterm imgcat` mueve el cursor por su
# cuenta y bajo ConPTY eso borraba la ultima celda de la imagen y dejaba un caracter suelto.
# Aleatorio tipo lista de reproduccion: no repite una imagen hasta haber mostrado todas, y al
# arrancar una vuelta nueva no empieza por la ultima que se vio.
$seenFile = Join-Path $PSScriptRoot 'splash-seen.txt'
$seen = @(Get-Content $seenFile -ErrorAction SilentlyContinue)
$pool = @($images | Where-Object { $seen -notcontains $_.Name })
if ($pool.Count -eq 0) {
    $last = $seen | Select-Object -Last 1
    $seen = @()
    $pool = @($images | Where-Object { $_.Name -ne $last })
    if ($pool.Count -eq 0) { $pool = $images }
}
$pick = $pool | Get-Random
$fixed = if ($Image) { $images | Where-Object BaseName -eq $Image | Select-Object -First 1 }
if ($fixed) { $pick = $fixed } else { Set-Content $seenFile ($seen + $pick.Name) }

$b64img = [Convert]::ToBase64String([IO.File]::ReadAllBytes($pick.FullName))
# WezTerm deja vacia la ultima celda (abajo a la derecha) de una imagen inline; por eso los PNG miden
# 520x640, con una columna extra de 8 px en el color de fondo, y se declaran de 65 columnas.
$image = "$e]1337;File=inline=1;width=$($ImgCols + 1);height=$ImgRows;preserveAspectRatio=0;doNotMoveCursor=1:$b64img$([char]7)"
Clear-Host
Write-Host ($sb.ToString() + "$e[H" + $image + "$e[$($ImgRows + 2);1H") -NoNewline
