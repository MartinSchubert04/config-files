# --- Encoding UTF-8 ---
try {
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 > $null
} catch {}

Clear-Host

# --- Oh My Posh ---
# El tema elegido con `theme` se guarda en ~\.config\athanor\theme (athanor o illusi0n).
# athanor solo aplica en WezTerm y Windows Terminal; VS Code y SSH siguen siempre con illusi0n.
# Set-ShellTheme aplica prompt y colores de PSReadLine segun el tema guardado y devuelve si es athanor.
function Set-ShellTheme {
    $name = Get-Content "$HOME\.config\athanor\theme" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $name) { $name = 'athanor' }
    $isAthanor = $name -eq 'athanor' -and $env:TERM_PROGRAM -ne 'vscode' -and ($env:TERM_PROGRAM -eq 'WezTerm' -or $env:WT_SESSION)

    $poshTheme = if ($isAthanor) { 'athanor' } else { 'illusi0n' }
    oh-my-posh init pwsh --config "C:\Users\Martin\.posh\themes\$poshTheme.omp.json" | Invoke-Expression | Out-Null

    if ($isAthanor) {
        Set-PSReadLineOption -Colors @{
            Default          = "#FCE8C3"
            Command          = "#FCE8C3"
            Parameter        = "#BAA67F"
            String           = "#98BC37"
            Operator         = "#0AAEB3"
            Variable         = "#FED06E"
            Number           = "#FF5F00"
            Comment          = "#918175"
            Error            = "#EF2F27"
            InlinePrediction = "#918175"
        }
    } else {
        Set-PSReadLineOption -Colors @{
            Default          = "#ffffe3"
            Command          = "#ffffe3"
            Parameter        = "#c0caf5"
            String           = "#9ece6a"
            Operator         = "#89ddff"
            Variable         = "#bb9af7"
            Number           = "#ff9e64"
            Comment          = "#565f89"
            Error            = "#f7768e"
            InlinePrediction = "#565f89"
        }
    }
    $isAthanor
}
$athanor = Set-ShellTheme

# Con athanor va el splash de grabados; con illusi0n, anifetch.
# En la terminal integrada de VS Code o en una sesión de OpenSSH no se muestra ninguno.
function Show-Greeting {
    if ($global:athanor) {
        & "$HOME\.config\athanor\splash.ps1"
    } elseif ($env:TERM_PROGRAM -ne 'vscode' -and -not $env:SSH_CONNECTION) {
        anifetch "C:\Users\Martin\.config\fastfetch\blackhole.mp4" -W 55 -H 50 -ca "--symbols braille --fg-only" --loop 0 --center
    }
}

# `theme` lista los temas y cambia entre ellos. Al cambiar rehace prompt, colores y saludo en esta misma
# sesion. No recarga el perfil entero: volver a fijar el encoding de la consola dejaba el teclado muerto.
function theme {
    if (& "$HOME\.config\athanor\theme.ps1" @args) {
        Start-Sleep -Milliseconds 800   # la terminal tarda un momento en aplicar fuente y tamaño nuevos
        $global:athanor = Set-ShellTheme
        Clear-Host
        Show-Greeting
    }
}

# --- Terminal Icons (carga diferida) ---
# Import-Module normal tarda ~440ms y bloquea el arranque.
# Get-ChildItem ya existe como comando, así que el autoload de PowerShell
# NO dispara la carga del módulo solo. En cambio, difiere la carga al
# evento OnIdle: se importa justo después de que el prompt ya está
# dibujado y esperando input, así el arranque se siente instantáneo.
$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Import-Module Terminal-Icons
    Unregister-Event -SourceIdentifier PowerShell.OnIdle -ErrorAction SilentlyContinue
}

# --- Keybinding para alternar vista de predicciones ---
Set-PSReadLineKeyHandler -Key "Ctrl+f" `
                         -BriefDescription "AlternarVistaPrediccion" `
                         -LongDescription "Cambia entre vista en línea y lista para las predicciones de PSReadLine" `
                         -ScriptBlock {
    $options = Get-PSReadLineOption
    if ($options.PredictionViewStyle -eq "InlineView") {
        Set-PSReadLineOption -PredictionViewStyle ListView
    } else {
        Set-PSReadLineOption -PredictionViewStyle InlineView
    }
}

# --- Saludo inicial ---
Show-Greeting

# --- Ir al escritorio si arrancamos en $HOME ---
if ($pwd.path -eq $HOME -and $env:TERM_PROGRAM -ne 'vscode') { cd desktop }