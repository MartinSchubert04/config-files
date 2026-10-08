# Splash estilo athanor: grabado al azar, sigilo del host, reloj y hora planetaria.
# Solo ASCII en el fuente para que corra igual en Windows PowerShell 5.1 y en pwsh 7.
param(
    [double]$Lat = -34.60,   # Buenos Aires; se usa para amanecer/atardecer
    [double]$Lon = -58.38,
    [string]$Image = $env:ATHANOR_IMAGE,   # nombre sin extension para fijar una imagen (pruebas)
    # Por SSH: cuanto ensanchar el grabado si las celdas del cliente son mas angostas que 1:2 (1.0 = sin ensanchar)
    [double]$SshWiden = $(if ($env:ATHANOR_SSH_WIDEN) { [double]$env:ATHANOR_SSH_WIDEN } else { 1.25 }),
    [switch]$Force
)

$ImgCols = 64; $ImgRows = 40      # parte visible de la imagen: 512x640 px = 64x40 celdas de 8x16
$PanelCol = 71                    # columna donde arranca el panel derecho
$MinCols = 120; $MinRows = 43

# WezTerm muestra el PNG con el protocolo de iTerm2; Windows Terminal, el .six con Sixel.
# Por SSH (Termius y similares) no hay protocolo de imagenes: chafa dibuja el PNG con caracteres.
$term = if ($env:TERM_PROGRAM -eq 'WezTerm') { 'wezterm' } elseif ($env:WT_SESSION) { 'wt' } elseif ($env:SSH_CONNECTION) { 'ssh' } else { '' }
if (-not $term) { if ($Force) { $term = 'wezterm' } else { return } }
$size = $Host.UI.RawUI.WindowSize
# El grabado de chafa se puede achicar: por SSH alcanza con que entre el panel de texto.
if ($term -eq 'ssh') { $MinRows = 34 }
if ($size.Width -lt $MinCols -or $size.Height -lt $MinRows) { return }
# $shift: columnas que se ensancha el grabado por SSH; los paneles de texto se corren lo mismo.
$shift = 0; $chafaCols = $ImgCols
if ($term -eq 'ssh') {
    $ImgRows = [Math]::Min($ImgRows, $size.Height - 3)
    $chafaCols = [int][Math]::Round($ImgRows * 1.6 * $SshWiden)
    $shift = [Math]::Max(0, [Math]::Min($chafaCols - $ImgCols, $size.Width - $MinCols))
    $chafaCols = [Math]::Min($chafaCols, $ImgCols + $shift)
    $PanelCol += $shift
}

$images = @(Get-ChildItem (Join-Path $PSScriptRoot 'splash') -Filter *.png -ErrorAction SilentlyContinue)
if ($images.Count -eq 0) { return }

# Paleta activa: la elige `theme` y la guarda en el archivo palette; los colores salen de palettes.json
$palName = Get-Content (Join-Path $PSScriptRoot 'palette') -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $palName) { $palName = 'srcery' }
$pal = (Get-Content (Join-Path $PSScriptRoot 'palettes.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json).$palName
if (-not $pal) { return }

$e = [char]27
function Rgb([string]$hex) { $n = [Convert]::ToInt32($hex.TrimStart('#'), 16); ($n -shr 16), (($n -shr 8) -band 255), ($n -band 255) }
function Fg([string]$hex) { "$e[38;2;$((Rgb $hex) -join ';')m" }
$amber = Fg $pal.active; $cream = Fg $pal.fg; $dim = Fg $pal.dim; $sigil = Fg $pal.sigil
$rule = Fg $pal.border; $bold = "$e[1m"; $reset = "$e[0m"
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
At 4 $PanelCol ($sigil + [char]0x250C + ($hz * 12) + [char]0x2510)
for ($y = 0; $y -lt 5; $y++) {
    $line = ''
    foreach ($x in 0, 1, 2, 1, 0) { $line += if ($hash[$y * 3 + $x] -band 1) { $full * 2 } else { '  ' } }
    At (5 + $y) $PanelCol "$sigil$vt $line $vt"
}
At 10 $PanelCol ($sigil + [char]0x2514 + ($hz * 12) + [char]0x2518)
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

for ($r = 1; $r -le $ImgRows; $r++) { At $r ($ImgCols + 4 + $shift) ($rule + $vt) }

# --- Tercera columna (solo si la ventana es ancha): sala, ficha del personaje, elementos, carta ---
$SideCol = 123 + $shift; $SideWidth = 40
if ($size.Width -ge $SideCol + $SideWidth - 1) {
    for ($r = 1; $r -le $ImgRows; $r++) { At $r ($SideCol - 3) ($rule + $vt) }
    $green = Fg $pal.terra; $verdigris = Fg $pal.aqua
    function Wrap([string]$text, [int]$width) {
        $lines = @(); $line = ''
        foreach ($w in $text -split ' ') {
            if ($line -and ($line.Length + 1 + $w.Length) -gt $width) { $lines += $line; $line = $w }
            elseif ($line) { $line += " $w" } else { $line = $w }
        }
        if ($line) { $lines += $line }
        $lines
    }
    function Clip([string]$text, [int]$width) { if ($text.Length -gt $width) { $text.Substring(0, $width - 1) + '.' } else { $text } }

    # Sala estilo MUD: la carpeta donde arranca la sesion, con sus subcarpetas como salidas.
    # La descripcion depende del planeta que rige la hora.
    $where = if ($PWD.Path -eq $HOME) { Join-Path $HOME 'Desktop' } else { $PWD.Path }
    $rooms = @{
        Sun     = 'Gold light slants across the workbench.'
        Moon    = 'Silver light pools on the desk.'
        Mars    = 'The furnace is hot and the bellows are working.'
        Mercury = 'Quicksilver beads roll across open ledgers.'
        Jupiter = 'Tall shelves groan under bound volumes.'
        Venus   = 'Copper vessels gleam among green glass.'
        Saturn  = 'Lead-grey dust lies on the unsorted stock.'
    }
    $row = 4
    At $row $SideCol ($amber + '~ ' + (Clip (Split-Path $where -Leaf) ($SideWidth - 4)) + ' ~'); $row++
    foreach ($l in Wrap ($rooms[$hourPlanet] + ' A terminal hums here.') $SideWidth) { At $row $SideCol ($cream + $l); $row++ }
    $exits = @(Get-ChildItem $where -Directory -Name -ErrorAction SilentlyContinue | Select-Object -First 4)
    if ($exits.Count -gt 0) {
        foreach ($l in @(Wrap ('Obvious exits: ' + ($exits -join ', ')) $SideWidth | Select-Object -First 2)) { At $row $SideCol ($dim + $l); $row++ }
    }

    # Ficha: los datos del equipo con nombres de hoja de personaje.
    # Se lee valor por valor: Get-ItemProperty sobre la clave entera falla si algun valor tiene un tipo raro.
    function Reg([string]$key, [string]$value) { [Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\$key", $value, $null) }
    $ntKey = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [string](Reg $ntKey 'CurrentBuild')
    $os = [string](Reg $ntKey 'ProductName'); if ([int]$build -ge 22000) { $os = $os -replace 'Windows 10', 'Windows 11' }
    $cpu = ([string](Reg 'HARDWARE\DESCRIPTION\System\CentralProcessor\0' 'ProcessorNameString') -replace '\(R\)|\(TM\)|CPU |Processor|\s+@.*$', '' -replace '\s+', ' ').Trim()
    $gpu = [string](Reg 'SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000' 'DriverDesc')
    $pack = 0
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall') {
        $key = Get-Item $k -ErrorAction SilentlyContinue; if ($key) { $pack += $key.SubKeyCount }
    }
    $memTotal = 0; $memUsed = 0
    try { $gc = [GC]::GetGCMemoryInfo(); $memTotal = $gc.TotalAvailableMemoryBytes; $memUsed = $gc.MemoryLoadBytes } catch {}
    $up = [TimeSpan]::FromSeconds([Diagnostics.Stopwatch]::GetTimestamp() / [Diagnostics.Stopwatch]::Frequency)

    $row = 10
    $sheet = [ordered]@{
        Race   = $os
        Kernel = "10.0.$build.$(Reg $ntKey 'UBR')"
        Class  = "pwsh $($PSVersionTable.PSVersion)"
        Vessel = $cpu
        Str    = "$([Environment]::ProcessorCount) threads"
        Sight  = $gpu
        Mind   = if ($memTotal) { '{0:N0} GB' -f ($memTotal / 1GB) } else { $null }
        Pack   = "$pack items"
        Awake  = '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes
    }
    foreach ($k in $sheet.Keys) {
        if (-not $sheet[$k]) { continue }
        At $row $SideCol ($amber + $k.PadRight(8) + $cream + (Clip ([string]$sheet[$k]) ($SideWidth - 8))); $row++
    }

    # Cuatro barras: curso del sol (o de la noche), luz de la luna, disco y memoria
    function Bar([string]$name, [double]$frac, [string]$color, [string]$note) {
        $frac = [Math]::Max(0.0, [Math]::Min(1.0, $frac)); $n = [int][Math]::Round($frac * 16)
        $script:barRow++
        At $script:barRow $SideCol ($amber + $name.PadRight(8) + $color + ($full * $n) + $rule + ([string][char]0x2591 * (16 - $n)) + $dim + ' ' + $note)
    }
    function Pct([double]$x) { [string][int][Math]::Round($x * 100) + '%' }
    $script:barRow = 21
    $course = ($now - $start).TotalHours / ($span * 12)
    Bar $(if ($isDay) { 'Sol' } else { 'Nox' }) $course $amber ($(if ($isDay) { 'day ' } else { 'night ' }) + (Pct $course))
    $lit = (1 - [Math]::Cos(2 * [Math]::PI * $age / $synodic)) / 2
    Bar 'Luna' $lit $cream ('lit ' + (Pct $lit))
    $drive = New-Object IO.DriveInfo $env:SystemDrive
    $diskUsed = 1 - $drive.AvailableFreeSpace / $drive.TotalSize
    Bar 'Terra' $diskUsed $green ('disk ' + (Pct $diskUsed))
    if ($memTotal) { Bar 'Aqua' ($memUsed / $memTotal) $verdigris ('mem ' + (Pct ($memUsed / $memTotal))) }

    # Carta del dia: arcano mayor fijo para la fecha, con su atribucion de la Golden Dawn
    $arcana = @(
        '0|The Fool|Air|beginnings, a leap', 'I|The Magician|Mercury|will, craft', 'II|The High Priestess|Moon|secrets, intuition',
        'III|The Empress|Venus|abundance', 'IV|The Emperor|Aries|order, authority', 'V|The Hierophant|Taurus|tradition, teaching',
        'VI|The Lovers|Gemini|choice, union', 'VII|The Chariot|Cancer|drive, victory', 'VIII|Strength|Leo|courage, patience',
        'IX|The Hermit|Virgo|solitude, search', 'X|Wheel of Fortune|Jupiter|turning luck', 'XI|Justice|Libra|balance, truth',
        'XII|The Hanged Man|Water|surrender, a new view', 'XIII|Death|Scorpio|endings, change', 'XIV|Temperance|Sagittarius|mixing, measure',
        'XV|The Devil|Capricorn|bondage, appetite', 'XVI|The Tower|Mars|upheaval', 'XVII|The Star|Aquarius|hope, renewal',
        'XVIII|The Moon|Pisces|illusion, dreams', 'XIX|The Sun|Sun|joy, clarity', 'XX|Judgement|Fire|awakening', 'XXI|The World|Saturn|completion'
    )
    $seed = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($now.ToString('yyyy-MM-dd')))
    $card = $arcana[$seed[0] % $arcana.Count] -split '\|'
    At 28 $SideCol ($dim + 'The card of the day')
    At 29 $SideCol ($bold + $cream + $card[0] + '  ' + $card[1])
    At 30 $SideCol ($amber + $card[2] + $dim + ' - ' + $card[3])

}

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

# El grabado conserva sus tonos: lo oscuro va en plate[0] y lo claro en plate[1]. En una paleta oscura
# plate[0] es el fondo de la terminal; en una clara lo es plate[1], y el grabado queda como bloque oscuro.
$ink = $pal.plate[0]; $paper = $pal.plate[1]
if ($term -eq 'wt') {
    # Cada .six pinta un solo color y deja el otro transparente; aca se le cambia ese color por el de la paleta
    $six = [IO.Path]::ChangeExtension($pick.FullName, $(if ($pal.light) { '.ink.six' } else { '.six' }))
    if (-not (Test-Path $six)) { return }   # falta correr scripts\make-sixel.ps1
    $pct = Rgb $(if ($pal.light) { $ink } else { $paper }) | ForEach-Object { [int]($_ / 2.55) }
    $image = [IO.File]::ReadAllText($six) -replace '#1;2;\d+;\d+;\d+', "#1;2;$($pct -join ';')"
} else {
    $file = $pick.FullName
    if ($palName -ne 'srcery') {
        # Los PNG traen los dos colores de Srcery; para otra paleta se recolorean una vez y se guardan aparte
        $file = Join-Path $PSScriptRoot "splash\$palName\$($pick.Name)"
        if (-not (Test-Path $file) -or (Get-Item $file).LastWriteTime -lt $pick.LastWriteTime) {
            Add-Type -AssemblyName System.Drawing
            New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null
            $src = New-Object System.Drawing.Bitmap $pick.FullName
            $dst = New-Object System.Drawing.Bitmap $src.Width, $src.Height
            $maps = foreach ($pair in @('#1C1B19', $ink), @('#BAA67F', $paper)) {
                $m = New-Object System.Drawing.Imaging.ColorMap
                $m.OldColor = [System.Drawing.ColorTranslator]::FromHtml($pair[0])
                $m.NewColor = [System.Drawing.ColorTranslator]::FromHtml($pair[1])
                $m
            }
            $attr = New-Object System.Drawing.Imaging.ImageAttributes
            $attr.SetRemapTable([System.Drawing.Imaging.ColorMap[]]$maps)
            $g = [System.Drawing.Graphics]::FromImage($dst)
            $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
            $area = New-Object System.Drawing.Rectangle 0, 0, $src.Width, $src.Height
            $g.DrawImage($src, $area, 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $attr)
            # La columna extra de la derecha va en el fondo de la terminal, que en una paleta clara no es la tinta
            $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($pal.bg))
            $g.FillRectangle($brush, $ImgCols * 8, 0, $src.Width - $ImgCols * 8, $src.Height)
            $g.Dispose(); $src.Dispose()
            $dst.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $dst.Dispose()
        }
    }
    if ($term -eq 'ssh') {
        # Cada fila de chafa se ubica con posicion absoluta, igual que el texto. Sin chafa sale solo el texto.
        $image = ''
        if (Get-Command chafa -ErrorAction SilentlyContinue) {
            $r = 0
            foreach ($l in @(chafa -f symbols --size "${chafaCols}x$ImgRows" --stretch --colors full --animate off --polite on $file)) { $r++; $image += "$e[$r;1H$l" }
            $image += $reset
        }
    } else {
        $b64img = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))
        # WezTerm deja vacia la ultima celda (abajo a la derecha) de una imagen inline; por eso los PNG miden
        # 520x640, con una columna extra de 8 px en el color de fondo, y se declaran de 65 columnas.
        $image = "$e]1337;File=inline=1;width=$($ImgCols + 1);height=$ImgRows;preserveAspectRatio=0;doNotMoveCursor=1:$b64img$([char]7)"
    }
}
Clear-Host
Write-Host ($sb.ToString() + "$e[H" + $image + "$e[$($ImgRows + 2);1H") -NoNewline
