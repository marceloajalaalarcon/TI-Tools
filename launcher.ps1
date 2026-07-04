#Requires -Version 5.1
<#
  Launcher para TI-TOOLS ULTIMATE
  Uso: irm https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/launcher.ps1 | iex
#>

$ScriptUrl    = "https://raw.githubusercontent.com/douraglasssupervisor/canivete/refs/heads/main/avancadoFerramentas.ps1"
$LauncherUrl  = "https://raw.githubusercontent.com/douraglasssupervisor/canivete/refs/heads/main/launcher.ps1"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')

if (-not $isAdmin) {
    # Re-abre o launcher como admin via UAC
    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$LauncherUrl' | iex`"" `
        -Verb RunAs
    exit
}

# Admin confirmado — baixa e executa o script principal
try {
    $code = Invoke-RestMethod -Uri $ScriptUrl -UseBasicParsing
    Invoke-Expression $code
} catch {
    Write-Host "Erro ao baixar o script: $_" -ForegroundColor Red
    Write-Host "Verifique a URL: $ScriptUrl" -ForegroundColor Yellow
    pause
}
