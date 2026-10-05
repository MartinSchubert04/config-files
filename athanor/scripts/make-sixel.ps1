# Genera un .six por cada PNG del splash, para terminales con Sixel (Windows Terminal 1.22+).
# Windows Terminal dibuja Sixel sobre una grilla virtual de 10x20 px por celda, así que el dibujo de
# 256x320 puntos se emite a 640x800 (64x40 celdas): con celdas de 8x16 cada punto queda de 2x2 px.
# Solo se pinta el color claro; el fondo queda transparente y toma el de la terminal.
param(
    [string]$Dir = (Join-Path $env:USERPROFILE '.config\athanor\splash'),
    [string]$Light = '#BAA67F'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$c = [System.Drawing.ColorTranslator]::FromHtml($Light)
$rgb = '{0};{1};{2}' -f [int]($c.R / 2.55), [int]($c.G / 2.55), [int]($c.B / 2.55)
$W = 256; $H = 320; $OutW = 640; $OutH = 800
$esc = [char]27

Get-ChildItem $Dir -Filter *.png | ForEach-Object {
    $bmp = New-Object System.Drawing.Bitmap $_.FullName
    # Punto lógico (x, y) = píxel (2x, 2y) del PNG; claro si se parece más al color claro que al fondo
    $lit = New-Object 'bool[,]' $W, $H
    for ($y = 0; $y -lt $H; $y++) {
        for ($x = 0; $x -lt $W; $x++) { $lit[$x, $y] = $bmp.GetPixel($x * 2, $y * 2).R -gt 100 }
    }
    $bmp.Dispose()

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("${esc}P0;1;0q`"1;1;$OutW;$OutH#1;2;$rgb")
    for ($band = 0; $band * 6 -lt $OutH; $band++) {
        [void]$sb.Append('#1')
        $prev = -1; $run = 0
        for ($ox = 0; $ox -le $OutW; $ox++) {
            $v = -1
            if ($ox -lt $OutW) {
                $v = 0; $lx = [int][Math]::Floor($ox / 2.5)
                for ($bit = 0; $bit -lt 6; $bit++) {
                    $oy = $band * 6 + $bit
                    if ($oy -lt $OutH -and $lit[$lx, [int][Math]::Floor($oy / 2.5)]) { $v = $v -bor (1 -shl $bit) }
                }
            }
            if ($v -eq $prev) { $run++; continue }
            if ($run -gt 0) {
                $ch = [char](63 + $prev)
                if ($run -gt 3) { [void]$sb.Append("!$run$ch") } else { [void]$sb.Append([string]$ch * $run) }
            }
            $prev = $v; $run = 1
        }
        [void]$sb.Append('-')
    }
    [void]$sb.Append("$esc\")
    [IO.File]::WriteAllText([IO.Path]::ChangeExtension($_.FullName, '.six'), $sb.ToString(), [Text.Encoding]::ASCII)
}
