# --- Encoding UTF-8 ---
try {
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 > $null
} catch {}

Clear-Host

# --- Oh My Posh ---
# WezTerm y Windows Terminal usan la paleta Srcery; el resto (VS Code, SSH) sigue con illusi0n.
$athanor = $env:TERM_PROGRAM -ne 'vscode' -and ($env:TERM_PROGRAM -eq 'WezTerm' -or $env:WT_SESSION)
$poshTheme = if ($athanor) { 'athanor' } else { 'illusi0n' }
oh-my-posh init pwsh --config "C:\Users\Martin\.posh\themes\$poshTheme.omp.json" | Invoke-Expression

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

# --- Colores PSReadLine ---
Set-PSReadLineOption -Colors @{
    Default       = "#ffffe3"
    Command       = "#ffffe3"
    Parameter     = "#c0caf5"
    String        = "#9ece6a"
    Operator      = "#89ddff"
    Variable      = "#bb9af7"
    Number        = "#ff9e64"
    Comment       = "#565f89"
    Error         = "#f7768e"
}
if ($athanor) {
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

# --- Fastfetch con config explícita (path corregido) ---
# En la terminal integrada de VS Code o en una sesión de OpenSSH no se muestra la animación.
# En WezTerm va el splash de athanor en lugar de anifetch.
if ($env:TERM_PROGRAM -eq 'WezTerm') {
    & "$HOME\.config\athanor\splash.ps1"
} elseif ($env:TERM_PROGRAM -ne 'vscode' -and -not $env:SSH_CONNECTION) {
    anifetch "C:\Users\Martin\.config\fastfetch\blackhole.mp4" -W 55 -H 50 -ca "--symbols braille --fg-only" --loop 0 --center
}

# --- Ir al escritorio si arrancamos en $HOME ---
if ($pwd.path -eq $HOME -and $env:TERM_PROGRAM -ne 'vscode') { cd desktop }