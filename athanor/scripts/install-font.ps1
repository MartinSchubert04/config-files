# Descarga el pack de int10h e instala PxPlus IBM VGA 8x16 para el usuario actual (sin admin).
$ErrorActionPreference = 'Stop'

$tmp = Join-Path $env:TEMP 'oldschool-pc-fonts'
$zip = "$tmp.zip"
$url = 'https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v2.2_win.zip'

# int10h rechaza clientes sin User-Agent de navegador
curl.exe -sL -o $zip -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0' `
    -e 'https://int10h.org/oldschool-pc-fonts/download/' $url
Expand-Archive $zip $tmp -Force

$src = Join-Path $tmp 'ttf - Px (pixel outline)\PxPlus_IBM_VGA_8x16.ttf'
$dstDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
New-Item -ItemType Directory -Force $dstDir | Out-Null
$dst = Join-Path $dstDir 'PxPlus_IBM_VGA_8x16.ttf'
Copy-Item $src $dst -Force

New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' `
    -Name 'PxPlus IBM VGA 8x16 (TrueType)' -Value $dst -PropertyType String -Force | Out-Null

Write-Host "Fuente instalada en $dst. Reiniciá Windows Terminal."
