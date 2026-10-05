# Convierte cada imagen de plates\ en un PNG de 512x640 (64x40 celdas de 8x16) para el splash de WezTerm.
# Requiere: winget install ImageMagick.ImageMagick
param(
    [string]$Plates = (Join-Path $PSScriptRoot '..\plates'),
    [string]$OutDir = (Join-Path $env:USERPROFILE '.config\athanor\splash'),
    [string]$Dark = '#1C1B19',
    [string]$Light = '#BAA67F',
    # Grabados de línea que quedan mejor con corte duro que con tramado
    [string[]]$Hard = @('dore-satan-despair', 'dore-satan-falls', 'dore-satan-profile'),
    # Imágenes apaisadas de fondo claro que se muestran enteras e invertidas, en vez de recortarse
    [string[]]$Whole = @('michelangelo-adam-hands')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null

$palette = Join-Path $env:TEMP 'athanor-bw.png'
magick xc:black xc:white +append $palette

Get-ChildItem $Plates -File | Where-Object Extension -in '.jpg', '.jpeg', '.png' | ForEach-Object {
    $dst = Join-Path $OutDir ($_.BaseName + '.png')
    # Se trabaja a 256x320 y se duplica con filtro point para que el píxel quede de 2x2
    $fit = '-shave', '2%x2%', '-colorspace', 'gray', '-resize', '256x320^', '-gravity', 'center', '-extent', '256x320'
    # La columna extra de 8 px en color de fondo tapa la celda que WezTerm deja vacía en la esquina
    $tint = '+level-colors', "$Dark,$Light", '-filter', 'point', '-resize', '200%',
        '-background', $Dark, '-gravity', 'west', '-extent', '520x640'
    if ($_.BaseName -in $Whole) {
        # Fondo claro: se invierte para que el fondo se funda con la terminal y quede la figura iluminada
        magick $_.FullName -alpha off -colorspace gray -auto-level -negate -level '25%,85%' -resize 256x320 -dither FloydSteinberg `
            -remap $palette -colorspace gray -background black -gravity center -extent 256x320 @tint $dst
    } elseif ($_.BaseName -in $Hard) {
        magick $_.FullName @fit -sigmoidal-contrast 4x50% -dither FloydSteinberg -monochrome @tint $dst
    } else {
        magick $_.FullName @fit -auto-level -sigmoidal-contrast 3x50% -dither FloydSteinberg -remap $palette -colorspace gray @tint $dst
    }
}
