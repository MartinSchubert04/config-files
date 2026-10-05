# Genera wall.png, lock.png y term-bg.png a partir de images\plate.jpg con ImageMagick.
# Requiere: winget install ImageMagick.ImageMagick
param(
    [string]$Plate = (Join-Path $PSScriptRoot '..\images\plate.jpg'),
    [string]$OutDir = (Join-Path $PSScriptRoot '..\images'),
    [int]$Width = 2560,
    [int]$Height = 1440,
    [string]$Dark = '#1C1B19',
    [string]$Dim = '#5c4c39',
    [string]$Light = '#BAA67F'
)
$ErrorActionPreference = 'Stop'

# Se trabaja a mitad de resolución y se duplica con filtro point para que el píxel quede de 2x2
$w = [int]($Width / 2); $h = [int]($Height / 2)
$dither = '-colorspace', 'gray', '-sigmoidal-contrast', '4x50%', '-dither', 'FloydSteinberg', '-monochrome'
$upscale = '-filter', 'point', '-resize', '200%'

# Fondo de escritorio: recorta el grabado para llenar la pantalla, en tono apagado
magick $Plate -shave 30x30 -resize "${w}x${h}^" -gravity center -extent "${w}x${h}" @dither `
    +level-colors "$Dark,$Dim" @upscale (Join-Path $OutDir 'wall.png')

# Pantalla de bloqueo: grabado entero a la izquierda, resto en negro
magick $Plate -shave 30x30 -resize "x$h" @dither -background black -gravity west -extent "${w}x${h}" `
    +level-colors "$Dark,$Light" @upscale (Join-Path $OutDir 'lock.png')

# Fondo opcional para la terminal (backgroundImage, stretchMode none, bottomRight)
magick $Plate -shave 30x30 -resize x500 @dither +level-colors "$Dark,$Dim" @upscale (Join-Path $OutDir 'term-bg.png')
