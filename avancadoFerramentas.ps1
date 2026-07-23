<#
.SYNOPSIS
    TI-TOOLS ULTIMATE v6.0 - Suite Profissional de Manutencao Windows
.DESCRIPTION
    Ferramenta completa com 40+ funcoes para equipes de suporte tecnico.
    Interface profissional com box-drawing, dashboard, progress e logging.
.NOTES
    Autor : Marcelo A. Alarcon
    Versao: 6.0
    Data  : 2026-03-12
#>

[CmdletBinding()]
param([Switch]$ScheduledClean)

# ===================== CONFIGURACAO GLOBAL =====================
$Script:Version    = "6.0"
$Script:AppName    = "TI-TOOLS ULTIMATE"
$Script:LogDir     = "C:\Logs"
$Script:LogFile    = "$Script:LogDir\TI-Tools_$(Get-Date -Format 'yyyyMMdd').log"
$Script:ReportDir  = "$env:USERPROFILE\Desktop\TI-Reports"

# Garante diretorios
foreach ($d in @($Script:LogDir, $Script:ReportDir)) {
    if (!(Test-Path $d)) { New-Item $d -ItemType Directory -Force | Out-Null }
}

# ===================== ELEVACAO DE PRIVILEGIOS =====================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    if ($PSCommandPath) {
        # Executado via arquivo: reabre como admin
        Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    # Executado via irm|iex sem arquivo: avisa e continua (launcher deve garantir admin)
    Write-Host "  [AVISO] Execute como Administrador para funcionalidade completa." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

# ===================== CONFIGURACAO DE JANELA =====================
try {
    $Host.UI.RawUI.WindowTitle = "$Script:AppName v$Script:Version"
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Gray"
    $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(130, 9000)
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(130, 42)
} catch {}
Clear-Host

# ===================== FUNCOES DE UI =====================

function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] [$Level] $Msg"
    try { Add-Content -Path $Script:LogFile -Value $entry -ErrorAction SilentlyContinue } catch {}
}

function Write-S {
    # Status com badge colorido
    param([string]$Msg, [ValidateSet("OK","FAIL","WARN","INFO","RUN")]$Type = "INFO")
    $badge = switch ($Type) {
        "OK"   { @{ Text = "  OK  "; Color = "Green"  } }
        "FAIL" { @{ Text = " ERRO "; Color = "Red"    } }
        "WARN" { @{ Text = "AVISO "; Color = "Yellow" } }
        "RUN"  { @{ Text = " >>>  "; Color = "Cyan"   } }
        default{ @{ Text = " INFO "; Color = "DarkCyan"} }
    }
    Write-Host " [" -NoNewline -ForegroundColor DarkGray
    Write-Host $badge.Text -NoNewline -ForegroundColor $badge.Color
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host $Msg
    Write-Log $Msg $Type
}

function Write-Box {
    # Desenha um box com titulo
    param([string]$Title, [string]$Color = "Cyan")
    $w = 70
    $pad = $w - $Title.Length - 4
    if ($pad -lt 0) { $pad = 0 }
    $line = "+" + ("-" * ($w - 2)) + "+"
    Write-Host ""
    Write-Host "  $line" -ForegroundColor $Color
    Write-Host "  | $Title$(' ' * $pad) |" -ForegroundColor $Color
    Write-Host "  $line" -ForegroundColor $Color
}

function Write-MenuItem {
    param([string]$Key, [string]$Label, [string]$Desc = "", [string]$KeyColor = "Yellow")
    Write-Host "   [" -NoNewline -ForegroundColor DarkGray
    Write-Host $Key -NoNewline -ForegroundColor $KeyColor
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host $Label -NoNewline -ForegroundColor White
    if ($Desc) { Write-Host " - $Desc" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Write-Sep {
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
}

function Write-Dashboard {
    try {
        $comp   = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $os     = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cpu    = Get-CimInstance Win32_Processor -ErrorAction Stop
        $uptime = (Get-Date) - $os.LastBootUpTime
        $ramGB  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $ramFree= [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $ramPct = [math]::Round(($ramGB - $ramFree) / $ramGB * 100)
        $disk   = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop
        $diskGB = [math]::Round($disk.Size / 1GB, 1)
        $diskFr = [math]::Round($disk.FreeSpace / 1GB, 1)
        $diskPct= [math]::Round(($diskGB - $diskFr) / $diskGB * 100)

        # IP e MAC
        $netAdapter = Get-NetAdapter | Where-Object {$_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Virtual|Loopback'} | Select-Object -First 1
        $ipAddr = "N/A"
        $macAddr = "N/A"
        if ($netAdapter) {
            $macAddr = $netAdapter.MacAddress
            $ipObj = Get-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ipObj) { $ipAddr = $ipObj.IPAddress }
        }

        # Barra de uso
        function Get-Bar($pct, $width = 20) {
            $filled = [math]::Round($pct / 100 * $width)
            $empty  = $width - $filled
            $color  = if ($pct -gt 85) { "Red" } elseif ($pct -gt 60) { "Yellow" } else { "Green" }
            Write-Host "[" -NoNewline -ForegroundColor DarkGray
            Write-Host ("#" * $filled) -NoNewline -ForegroundColor $color
            Write-Host ("-" * $empty) -NoNewline -ForegroundColor DarkGray
            Write-Host "] ${pct}%" -NoNewline -ForegroundColor $color
        }

        Write-Host ""
        Write-Host "  +----------------------------------------------------------------------+" -ForegroundColor DarkCyan
        Write-Host "  |" -NoNewline -ForegroundColor DarkCyan
        Write-Host "  $Script:AppName v$Script:Version" -NoNewline -ForegroundColor White
        Write-Host "                                               |" -ForegroundColor DarkCyan
        Write-Host "  +----------------------------------------------------------------------+" -ForegroundColor DarkCyan

        # Linha 1: Host + User + Uptime
        Write-Host "  |" -NoNewline -ForegroundColor DarkCyan
        Write-Host "  PC: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($comp.Name)" -NoNewline -ForegroundColor White
        Write-Host " | User: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$env:USERNAME" -NoNewline -ForegroundColor Green
        Write-Host " | Uptime: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($uptime.Days)d $($uptime.Hours)h" -NoNewline -ForegroundColor Cyan
        $spaces1 = 70 - 8 - $comp.Name.Length - 9 - $env:USERNAME.Length - 11 - "$($uptime.Days)d $($uptime.Hours)h".Length
        if ($spaces1 -lt 1) { $spaces1 = 1 }
        Write-Host "$(' ' * $spaces1)|" -ForegroundColor DarkCyan

        # Linha 2: IP + MAC
        Write-Host "  |" -NoNewline -ForegroundColor DarkCyan
        Write-Host "  IP: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$ipAddr" -NoNewline -ForegroundColor Yellow
        Write-Host " | MAC: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$macAddr" -NoNewline -ForegroundColor Yellow
        $netLine = "  IP: $ipAddr | MAC: $macAddr"
        $spaces1b = 70 - $netLine.Length
        if ($spaces1b -lt 1) { $spaces1b = 1 }
        Write-Host "$(' ' * $spaces1b)|" -ForegroundColor DarkCyan

        # Linha 3: CPU
        $cpuShort = if ($cpu.Name.Length -gt 50) { $cpu.Name.Substring(0, 50) + "..." } else { $cpu.Name }
        Write-Host "  |" -NoNewline -ForegroundColor DarkCyan
        Write-Host "  CPU: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$cpuShort" -NoNewline -ForegroundColor White
        $spaces2 = 70 - 7 - $cpuShort.Length
        if ($spaces2 -lt 1) { $spaces2 = 1 }
        Write-Host "$(' ' * $spaces2)|" -ForegroundColor DarkCyan

        # Linha 4: RAM bar
        Write-Host "  |" -NoNewline -ForegroundColor DarkCyan
        Write-Host "  RAM: " -NoNewline -ForegroundColor DarkGray
        Get-Bar $ramPct 25
        Write-Host " ($ramFree GB livres de $ramGB GB)" -NoNewline -ForegroundColor DarkGray
        $ramStr = " ($ramFree GB livres de $ramGB GB)"
        $spaces3 = 70 - 7 - 30 - $ramStr.Length
        if ($spaces3 -lt 1) { $spaces3 = 1 }
        Write-Host "$(' ' * $spaces3)|" -ForegroundColor DarkCyan

        # Linha 5: Disco bar
        Write-Host "  |" -NoNewline -ForegroundColor DarkCyan
        Write-Host "  DSK: " -NoNewline -ForegroundColor DarkGray
        Get-Bar $diskPct 25
        Write-Host " ($diskFr GB livres de $diskGB GB)" -NoNewline -ForegroundColor DarkGray
        $dskStr = " ($diskFr GB livres de $diskGB GB)"
        $spaces4 = 70 - 7 - 30 - $dskStr.Length
        if ($spaces4 -lt 1) { $spaces4 = 1 }
        Write-Host "$(' ' * $spaces4)|" -ForegroundColor DarkCyan

        Write-Host "  +----------------------------------------------------------------------+" -ForegroundColor DarkCyan
    } catch {
        Write-Host "  [Dashboard indisponivel]" -ForegroundColor DarkGray
    }
}

function Pause-Menu {
    Write-Host ""
    Write-Host "  Pressione qualquer tecla para continuar..." -ForegroundColor DarkGray -NoNewline
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

function Confirm-Action {
    param([string]$Msg)
    Write-Host ""
    Write-Host "  [!] $Msg" -ForegroundColor Red
    $r = Read-Host "  Confirma? (S/N)"
    return ($r -imatch "^s")
}

# ===================== MENU PRINCIPAL =====================

function Show-MainMenu {
    Clear-Host
    Write-Dashboard
    Write-Host ""
    Write-MenuItem "1" "DIAGNOSTICO E HARDWARE"  "SFC, DISM, CHKDSK, SMART, RAM, Bateria"
    Write-MenuItem "2" "REDE E CONECTIVIDADE"    "Wi-Fi, Ping, DNS, Portas, Shares, NTP"
    Write-MenuItem "3" "LIMPEZA E SISTEMA"        "Temp, BSOD, Drivers, Startup, VSS"
    Write-MenuItem "4" "SEGURANCA E AUDITORIA"    "USB, BitLocker, Backup, Telemetria"
    Write-MenuItem "5" "CORRECOES E REPAROS"      "Store, .NET, WMI, Cache, Search"
    Write-MenuItem "6" "ZONA DE PERIGO (ADMIN)"   "Reset, WinSxS, RDP, MAS, Perfis" "Red"
    Write-Host ""
    Write-MenuItem "0" "SAIR" "" "DarkGray"
    Write-Host ""
}

# ===================== 1. DIAGNOSTICO E HARDWARE =====================

function Menu-Diagnostico {
    do {
        Clear-Host
        Write-Box "DIAGNOSTICO E HARDWARE"
        Write-Host ""
        Write-MenuItem "1" "SFC Scannow"          "Verifica e corrige arquivos corrompidos do Windows"
        Write-MenuItem "2" "DISM RestoreHealth"    "Repara a imagem do sistema via Windows Update"
        Write-MenuItem "3" "Agendar CHKDSK"        "Verifica integridade do disco no proximo boot"
        Write-MenuItem "4" "Status SMART"          "Verificacao rapida de saude dos HDs/SSDs"
        Write-MenuItem "5" "Relatorio Hardware"    "Gera HTML com CPU, RAM, Disco, Serial na Area de Trabalho"
        Write-MenuItem "6" "Serial do Monitor"     "Le o serial via EDID/WMI (inventario)"
        Write-MenuItem "7" "Teste de Memoria RAM"  "Agenda o Windows Memory Diagnostic (reboot)"
        Write-MenuItem "8" "Relatorio de Bateria"  "Saude da bateria para notebooks (HTML)"
        Write-MenuItem "9" "Top Processos"         "Os 10 que mais consomem CPU e RAM agora"
        Write-Host ""
        Write-MenuItem "0" "Voltar" "" "DarkGray"
        Write-Host ""
        $op = Read-Host "  Opcao"
        switch ($op) {
            "1" { Run-SFC }
            "2" { Run-DISM }
            "3" { Run-CHKDSK }
            "4" { Run-SMART }
            "5" { Run-HWReport }
            "6" { Run-MonitorSerial }
            "7" { Run-MemTest }
            "8" { Run-BatteryReport }
            "9" { Run-TopProc }
            "0" { return }
        }
    } while ($true)
}

function Run-SFC {
    Write-S "Iniciando System File Checker (sfc /scannow)..." "RUN"
    Write-S "Isso pode levar de 5 a 15 minutos..." "WARN"
    try {
        Start-Process sfc.exe -ArgumentList "/scannow" -Wait -NoNewWindow
        Write-S "SFC concluido. Verifique o resultado acima." "OK"
    } catch { Write-S "Erro ao executar SFC: $_" "FAIL" }
    Pause-Menu
}

function Run-DISM {
    Write-S "Iniciando DISM /RestoreHealth..." "RUN"
    Write-S "Requer internet. Pode levar 10-30 min..." "WARN"
    try {
        Start-Process DISM.exe -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow
        Write-S "DISM concluido." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-CHKDSK {
    Write-S "Agendando Check Disk para $env:SystemDrive..." "RUN"
    try {
        $proc = Start-Process chkdsk.exe -ArgumentList "$env:SystemDrive /f /r" -PassThru -NoNewWindow
        Write-S "CHKDSK sera executado no proximo reinicio." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-SMART {
    Write-S "Consultando WMI (Win32_DiskDrive)..." "RUN"
    try {
        $disks = Get-CimInstance Win32_DiskDrive
        Write-Host ""
        foreach ($d in $disks) {
            $color = if ($d.Status -eq "OK") { "Green" } else { "Red" }
            Write-Host "   Modelo: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($d.Model)" -NoNewline -ForegroundColor White
            Write-Host "  Status: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($d.Status)" -ForegroundColor $color
        }
    } catch { Write-S "Erro ao ler SMART: $_" "FAIL" }
    Pause-Menu
}

function Run-HWReport {
    Write-S "Coletando dados do sistema..." "RUN"
    try {
        $comp = Get-CimInstance Win32_ComputerSystem
        $cpu  = Get-CimInstance Win32_Processor
        $bios = Get-CimInstance Win32_BIOS
        $os   = Get-CimInstance Win32_OperatingSystem
        $ram  = Get-CimInstance Win32_PhysicalMemory
        $disk = Get-CimInstance Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}
        $net  = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notmatch 'Loopback' -and $_.AddressState -eq 'Preferred'}
        $ramTotal = [math]::Round(($ram | Measure-Object Capacity -Sum).Sum / 1GB, 2)

        $css = "body{font-family:'Segoe UI',sans-serif;background:#1a1a2e;color:#e0e0e0;padding:30px;max-width:900px;margin:auto}"
        $css += "h1{color:#00d4ff;border-bottom:2px solid #00d4ff;padding-bottom:10px}"
        $css += "h2{color:#0abde3;margin-top:25px}"
        $css += "table{width:100%;border-collapse:collapse;margin:10px 0}"
        $css += "th{background:#0abde3;color:#1a1a2e;padding:8px;text-align:left}"
        $css += "td{padding:8px;border-bottom:1px solid #333}"
        $css += "tr:hover{background:#2d2d4a}"
        $css += ".badge{display:inline-block;padding:3px 10px;border-radius:12px;font-size:12px;background:#00d4ff;color:#1a1a2e}"

        $html = "<html><head><style>$css</style><title>Relatorio - $($comp.Name)</title></head><body>"
        $html += "<h1>Relatorio de Hardware - $($comp.Name)</h1>"
        $html += "<p>Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm') | <span class='badge'>TI-TOOLS v$Script:Version</span></p>"
        
        $html += "<h2>Sistema</h2><table><tr><th>Item</th><th>Valor</th></tr>"
        $html += "<tr><td>Hostname</td><td>$($comp.Name)</td></tr>"
        $html += "<tr><td>Fabricante</td><td>$($comp.Manufacturer)</td></tr>"
        $html += "<tr><td>Modelo</td><td>$($comp.Model)</td></tr>"
        $html += "<tr><td>BIOS Serial</td><td>$($bios.SerialNumber)</td></tr>"
        $html += "<tr><td>SO</td><td>$($os.Caption) Build $($os.BuildNumber)</td></tr>"
        $html += "</table>"

        $html += "<h2>Processador</h2><table><tr><th>Item</th><th>Valor</th></tr>"
        $html += "<tr><td>Modelo</td><td>$($cpu.Name)</td></tr>"
        $html += "<tr><td>Nucleos</td><td>$($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads</td></tr>"
        $html += "<tr><td>Clock</td><td>$($cpu.MaxClockSpeed) MHz</td></tr>"
        $html += "</table>"

        $html += "<h2>Memoria RAM ($ramTotal GB)</h2><table><tr><th>Slot</th><th>Capacidade</th><th>Velocidade</th><th>Fabricante</th></tr>"
        foreach ($r in $ram) {
            $html += "<tr><td>$($r.DeviceLocator)</td><td>$([math]::Round($r.Capacity/1GB,0)) GB</td><td>$($r.Speed) MHz</td><td>$($r.Manufacturer)</td></tr>"
        }
        $html += "</table>"

        $html += "<h2>Discos</h2><table><tr><th>Unidade</th><th>Total</th><th>Livre</th><th>Uso</th></tr>"
        foreach ($d in $disk) {
            $total = [math]::Round($d.Size / 1GB, 1)
            $free  = [math]::Round($d.FreeSpace / 1GB, 1)
            $pct   = [math]::Round(($total - $free) / $total * 100)
            $html += "<tr><td>$($d.DeviceID)</td><td>$total GB</td><td>$free GB</td><td>$pct%</td></tr>"
        }
        $html += "</table>"

        $html += "<h2>Rede</h2><table><tr><th>Interface</th><th>IP</th></tr>"
        foreach ($n in $net) { $html += "<tr><td>$($n.InterfaceAlias)</td><td>$($n.IPAddress)</td></tr>" }
        $html += "</table></body></html>"

        $outFile = "$Script:ReportDir\Hardware_$($comp.Name)_$(Get-Date -Format 'yyyyMMdd').html"
        Set-Content -Path $outFile -Value $html -Encoding UTF8
        Invoke-Item $outFile
        Write-S "Relatorio salvo em: $outFile" "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-MonitorSerial {
    Write-S "Lendo WmiMonitorID..." "RUN"
    try {
        $monitors = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -ErrorAction Stop
        foreach ($m in $monitors) {
            $name   = ($m.UserFriendlyName -ne 0 | foreach {[char]$_}) -join ""
            $serial = ($m.SerialNumberID -ne 0 | foreach {[char]$_}) -join ""
            Write-Host "   Monitor: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$name" -NoNewline -ForegroundColor White
            Write-Host " | Serial: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$serial" -ForegroundColor Green
        }
    } catch { Write-S "Nenhum monitor detectado via WMI ou erro: $_" "WARN" }
    Pause-Menu
}

function Run-MemTest {
    Write-S "Abrindo Windows Memory Diagnostic..." "RUN"
    Write-S "O teste requer reinicializacao do PC." "WARN"
    mdsched.exe
    Pause-Menu
}

function Run-BatteryReport {
    Write-S "Gerando relatorio de bateria..." "RUN"
    try {
        $out = "$Script:ReportDir\Battery_$(Get-Date -Format 'yyyyMMdd').html"
        powercfg /batteryreport /output $out | Out-Null
        Invoke-Item $out
        Write-S "Salvo em: $out" "OK"
    } catch { Write-S "Erro (PC sem bateria?): $_" "WARN" }
    Pause-Menu
}

function Run-TopProc {
    Write-Box "TOP PROCESSOS"
    Write-Host ""
    Write-Host "   --- TOP 10 CPU ---" -ForegroundColor Cyan
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, @{N='CPU(s)';E={[math]::Round($_.CPU,1)}}, Id | Format-Table -AutoSize
    Write-Host "   --- TOP 10 RAM ---" -ForegroundColor Cyan
    Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 Name, @{N='RAM(MB)';E={[math]::Round($_.WorkingSet/1MB,1)}}, Id | Format-Table -AutoSize
    Pause-Menu
}

# ===================== 2. REDE E CONECTIVIDADE =====================

function Menu-Rede {
    do {
        Clear-Host
        Write-Box "REDE E CONECTIVIDADE"
        Write-Host ""
        Write-MenuItem "1" "Revelar Senhas Wi-Fi"  "Mostra senhas de todas as redes salvas"
        Write-MenuItem "2" "Teste de Conectividade" "Ping no Gateway, Google e Cloudflare"
        Write-MenuItem "3" "Meu IP Externo"         "Descobre o IP publico da rede"
        Write-MenuItem "4" "Scanner de Portas"       "Lista portas TCP abertas (LISTENING)"
        Write-MenuItem "5" "Benchmark DNS"           "Compara latencia Google vs Cloudflare vs OpenDNS"
        Write-MenuItem "6" "Auditoria de Shares"     "Pastas compartilhadas nesta maquina"
        Write-MenuItem "7" "Forcar Sincronia NTP"    "Ressincronizar relogio com servidor de hora"
        Write-Host ""
        Write-MenuItem "0" "Voltar" "" "DarkGray"
        Write-Host ""
        $op = Read-Host "  Opcao"
        switch ($op) {
            "1" { Run-WifiPass }
            "2" { Run-PingTest }
            "3" { Run-ExternalIP }
            "4" { Run-PortScan }
            "5" { Run-DNSBench }
            "6" { Run-AuditShares }
            "7" { Run-NTPSync }
            "0" { return }
        }
    } while ($true)
}

function Run-WifiPass {
    Write-S "Buscando perfis de Wi-Fi salvos..." "RUN"
    Write-Host ""
    $profiles = netsh wlan show profiles | Select-String "All User Profile"
    if (!$profiles) { Write-S "Nenhum perfil Wi-Fi encontrado." "WARN"; Pause-Menu; return }
    foreach ($line in $profiles) {
        $ssid = $line.ToString().Split(":")[1].Trim()
        $detail = netsh wlan show profile name="$ssid" key=clear
        $passLine = $detail | Select-String "Key Content"
        $pass = if ($passLine) { $passLine.ToString().Split(":")[1].Trim() } else { "(aberta/sem senha)" }
        Write-Host "   SSID: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$ssid" -NoNewline -ForegroundColor White
        Write-Host "  |  Senha: " -NoNewline -ForegroundColor DarkGray
        Write-Host "$pass" -ForegroundColor Yellow
    }
    Pause-Menu
}

function Run-PingTest {
    Write-S "Testando conectividade..." "RUN"
    Write-Host ""
    # Gateway
    $gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
    if ($gw) {
        Write-Host "   Gateway ($gw): " -NoNewline -ForegroundColor DarkGray
        if (Test-Connection $gw -Count 2 -Quiet) { Write-Host "OK" -ForegroundColor Green } else { Write-Host "FALHA" -ForegroundColor Red }
    }
    # Google
    Write-Host "   Google  (8.8.8.8): " -NoNewline -ForegroundColor DarkGray
    if (Test-Connection 8.8.8.8 -Count 2 -Quiet) { Write-Host "OK" -ForegroundColor Green } else { Write-Host "FALHA" -ForegroundColor Red }
    # Cloudflare
    Write-Host "   CloudFL (1.1.1.1): " -NoNewline -ForegroundColor DarkGray
    if (Test-Connection 1.1.1.1 -Count 2 -Quiet) { Write-Host "OK" -ForegroundColor Green } else { Write-Host "FALHA" -ForegroundColor Red }
    Pause-Menu
}

function Run-ExternalIP {
    Write-S "Consultando API externa..." "RUN"
    try {
        $ip = (Invoke-RestMethod "http://ifconfig.me/ip" -TimeoutSec 5).Trim()
        Write-S "IP Publico: $ip" "OK"
    } catch { Write-S "Sem conexao ou API indisponivel." "FAIL" }
    Pause-Menu
}

function Run-PortScan {
    Write-S "Listando portas TCP em LISTENING..." "RUN"
    Write-Host ""
    Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Select-Object @{N='Porta';E={$_.LocalPort}}, @{N='PID';E={$_.OwningProcess}}, @{N='Processo';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
        Sort-Object Porta | Format-Table -AutoSize
    Pause-Menu
}

function Run-DNSBench {
    Write-S "Testando latencia DNS (3 pings cada)..." "RUN"
    Write-Host ""
    try {
        $g = [math]::Round((Test-Connection 8.8.8.8 -Count 3 | Measure-Object ResponseTime -Average).Average, 1)
        $c = [math]::Round((Test-Connection 1.1.1.1 -Count 3 | Measure-Object ResponseTime -Average).Average, 1)
        $o = [math]::Round((Test-Connection 208.67.222.222 -Count 3 | Measure-Object ResponseTime -Average).Average, 1)
        
        Write-Host "   Google    (8.8.8.8):       $g ms" -ForegroundColor $(if($g -le $c -and $g -le $o){"Green"}else{"White"})
        Write-Host "   Cloudflare(1.1.1.1):       $c ms" -ForegroundColor $(if($c -le $g -and $c -le $o){"Green"}else{"White"})
        Write-Host "   OpenDNS   (208.67.222.222):$o ms" -ForegroundColor $(if($o -le $g -and $o -le $c){"Green"}else{"White"})
        Write-Host ""
        $best = @{Google=$g; Cloudflare=$c; OpenDNS=$o}.GetEnumerator() | Sort-Object Value | Select-Object -First 1
        Write-S "Mais rapido: $($best.Name) ($($best.Value) ms)" "OK"
    } catch { Write-S "Erro no teste: $_" "FAIL" }
    Pause-Menu
}

function Run-AuditShares {
    Write-S "Listando compartilhamentos..." "RUN"
    Write-Host ""
    Get-SmbShare | Where-Object {$_.Name -notmatch '^\$'} | Format-Table Name, Path, Description -AutoSize
    Write-Host "   Compartilhamentos ocultos (admin):" -ForegroundColor DarkGray
    Get-SmbShare | Where-Object {$_.Name -match '\$$'} | Format-Table Name, Path -AutoSize
    Pause-Menu
}

function Run-NTPSync {
    Write-S "Ressincronizando relogio..." "RUN"
    try {
        Stop-Service w32time -ErrorAction SilentlyContinue
        w32tm /unregister 2>$null
        w32tm /register 2>$null
        Start-Service w32time
        w32tm /resync 2>$null
        Write-S "Relogio sincronizado." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

# ===================== 3. LIMPEZA E SISTEMA =====================

function Menu-Limpeza {
    do {
        Clear-Host
        Write-Box "LIMPEZA E SISTEMA"
        Write-Host ""
        Write-MenuItem "1"  "Limpeza Completa"       "Temp do usuario, Temp do Windows, Spooler"
        Write-MenuItem "2"  "Exportar Logs de Erro"   "Ultimos 100 erros do EventViewer para TXT"
        Write-MenuItem "3"  "Historico de BSOD"       "Lista ultimas Telas Azuis (BugCheck)"
        Write-MenuItem "4"  "Drivers com Problema"    "Dispositivos com erro no Gerenciador"
        Write-MenuItem "5"  "Analisar Startup"        "O que inicia junto com o Windows?"
        Write-MenuItem "6"  "Listar Bloatware"        "Apps UWP removiveis instalados"
        Write-MenuItem "7"  "Gerenciar Shadow Copies" "Listar/Deletar copias de sombra (VSS)"
        Write-MenuItem "8"  "Dispositivos Fantasmas"  "Dispositivos desconectados/orfaos"
        Write-MenuItem "9"  "Agendar Limpeza Diaria"  "Task Scheduler as 04:00 AM"
        Write-Host ""
        Write-MenuItem "0" "Voltar" "" "DarkGray"
        Write-Host ""
        $op = Read-Host "  Opcao"
        switch ($op) {
            "1" { Run-CleanAll }
            "2" { Run-ExportLogs }
            "3" { Run-BSODHistory }
            "4" { Run-BadDrivers }
            "5" { Run-Startup }
            "6" { Run-Bloatware }
            "7" { Run-ShadowCopies }
            "8" { Run-GhostDevices }
            "9" { Run-ScheduleClean }
            "0" { return }
        }
    } while ($true)
}

function Run-CleanAll {
    Write-S "Limpando Temp do usuario..." "RUN"
    $before = (Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-S "Limpando Temp do Windows..." "RUN"
    Remove-Item "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-S "Reiniciando Spooler de Impressao..." "RUN"
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:WINDIR\System32\spool\PRINTERS\*" -Force -Recurse -ErrorAction SilentlyContinue
    Start-Service Spooler -ErrorAction SilentlyContinue
    
    $freed = [math]::Round($before / 1MB, 1)
    Write-S "Limpeza concluida. (~$freed MB processados)" "OK"
    Pause-Menu
}

function Run-ExportLogs {
    Write-S "Exportando erros do EventViewer..." "RUN"
    $f = "$Script:ReportDir\Erros_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
    try {
        Get-EventLog System -EntryType Error -Newest 100 -ErrorAction SilentlyContinue | Out-File $f
        Get-EventLog Application -EntryType Error -Newest 100 -ErrorAction SilentlyContinue | Out-File $f -Append
        Write-S "Salvo em: $f" "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-BSODHistory {
    Write-S "Buscando eventos BugCheck (BSOD)..." "RUN"
    Write-Host ""
    try {
        $bsods = Get-EventLog System -ErrorAction SilentlyContinue | Where-Object {$_.Source -eq "BugCheck"}
        if ($bsods) {
            $bsods | Select-Object TimeGenerated, EventID, Message | Format-List
        } else { Write-S "Nenhum BSOD encontrado nos logs. Bom sinal!" "OK" }
    } catch { Write-S "Erro ao ler logs: $_" "FAIL" }
    Pause-Menu
}

function Run-BadDrivers {
    Write-S "Analisando drivers..." "RUN"
    Write-Host ""
    try {
        $bad = Get-WmiObject Win32_PnPEntity | Where-Object {$_.ConfigManagerErrorCode -ne 0}
        if ($bad) {
            $bad | Select-Object Name, @{N='Codigo';E={$_.ConfigManagerErrorCode}} | Format-Table -AutoSize
        } else { Write-S "Todos os drivers estao OK!" "OK" }
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-Startup {
    Write-S "Listando itens de inicializacao..." "RUN"
    Write-Host ""
    Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, User | Format-Table -AutoSize
    Pause-Menu
}

function Run-Bloatware {
    Write-S "Listando Apps UWP removiveis..." "RUN"
    Get-AppxPackage | Where-Object {$_.NonRemovable -eq $false} | Select-Object Name, Version | Out-GridView -Title "Bloatware - Apps Removiveis"
}

function Run-ShadowCopies {
    Write-S "Listando Shadow Copies (VSS)..." "RUN"
    vssadmin list shadows
    Write-Host ""
    if (Confirm-Action "Deletar TODAS as shadow copies antigas?") {
        Write-S "Deletando..." "RUN"
        vssadmin delete shadows /all /quiet
        Write-S "Shadow copies removidas." "OK"
    }
    Pause-Menu
}

function Run-GhostDevices {
    Write-S "Listando dispositivos desconectados..." "RUN"
    Write-Host ""
    try {
        $ghosts = Get-PnpDevice -Status Unknown -ErrorAction SilentlyContinue
        if ($ghosts) { $ghosts | Select-Object FriendlyName, Class, Status | Format-Table -AutoSize }
        else { Write-S "Nenhum dispositivo fantasma encontrado." "OK" }
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-ScheduleClean {
    Write-S "Criando tarefa agendada (diaria 04:00)..." "RUN"
    try {
        $act = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -Command `"Remove-Item '$env:TEMP\*' -Recurse -Force -ErrorAction SilentlyContinue`""
        $trg = New-ScheduledTaskTrigger -Daily -At 4:00AM
        Register-ScheduledTask -TaskName "TI-Tools_LimpezaDiaria" -Action $act -Trigger $trg -User "SYSTEM" -RunLevel Highest -Force | Out-Null
        Write-S "Tarefa 'TI-Tools_LimpezaDiaria' criada com sucesso." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

# ===================== 4. SEGURANCA E AUDITORIA =====================

function Menu-Seguranca {
    do {
        Clear-Host
        Write-Box "SEGURANCA E AUDITORIA"
        Write-Host ""
        Write-MenuItem "1" "Historico de USB"       "Dispositivos USB ja conectados (Registry)"
        Write-MenuItem "2" "Indice Confiabilidade"  "Reliability Monitor (eventos de instabilidade)"
        Write-MenuItem "3" "Backup de Drivers"      "Exporta todos os drivers para C:\DriversBackup"
        Write-MenuItem "4" "Status BitLocker"       "Criptografia de disco esta ativa?"
        Write-MenuItem "5" "Ativacao do Windows"    "Licenca ativa ou expirada?"
        Write-MenuItem "6" "Desativar Telemetria"   "Bloqueia envio de dados para Microsoft"
        Write-Host ""
        Write-MenuItem "0" "Voltar" "" "DarkGray"
        Write-Host ""
        $op = Read-Host "  Opcao"
        switch ($op) {
            "1" { Run-USBHistory }
            "2" { Run-Reliability }
            "3" { Run-BackupDrivers }
            "4" { Run-BitLocker }
            "5" { Run-Activation }
            "6" { Run-Telemetry }
            "0" { return }
        }
    } while ($true)
}

function Run-USBHistory {
    Write-S "Lendo registro USBSTOR..." "RUN"
    Write-Host ""
    try {
        Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*\*\ -ErrorAction SilentlyContinue |
            Select-Object FriendlyName, PSChildName | Format-Table -AutoSize
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-Reliability {
    Write-S "Carregando Reliability Records..." "RUN"
    try {
        Get-CimInstance Win32_ReliabilityRecords -ErrorAction Stop |
            Select-Object TimeGenerated, ProductName, Message | Out-GridView -Title "Indice de Confiabilidade"
    } catch { Write-S "Erro: $_" "FAIL" }
}

function Run-BackupDrivers {
    Write-S "Exportando drivers de terceiros..." "RUN"
    $dest = "C:\DriversBackup"
    try {
        if (!(Test-Path $dest)) { New-Item $dest -ItemType Directory -Force | Out-Null }
        Export-WindowsDriver -Online -Destination $dest -ErrorAction Stop
        Write-S "Drivers salvos em: $dest" "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-BitLocker {
    Write-S "Verificando BitLocker..." "RUN"
    Write-Host ""
    manage-bde -status
    Pause-Menu
}

function Run-Activation {
    Write-S "Verificando licenciamento..." "RUN"
    Write-Host ""
    try {
        Get-CimInstance SoftwareLicensingProduct -ErrorAction Stop |
            Where-Object {$_.PartialProductKey} |
            Select-Object Name, @{N='Status';E={
                switch($_.LicenseStatus) {
                    0{"Nao Licenciado"} 1{"Ativado"} 2{"OOBE"} 3{"Periodo de Graca"} 4{"Suspenso"} 5{"Notificacao"} default{"Desconhecido"}
                }
            }} | Format-Table -AutoSize
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-Telemetry {
    Write-S "Desativando telemetria..." "RUN"
    try {
        $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        if (!(Test-Path $path)) { New-Item $path -Force | Out-Null }
        Set-ItemProperty $path "AllowTelemetry" 0
        Write-S "Telemetria desativada via registro." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

# ===================== 5. CORRECOES E REPAROS =====================

function Menu-Correcoes {
    do {
        Clear-Host
        Write-Box "CORRECOES E REPAROS"
        Write-Host ""
        Write-MenuItem "1"  "Reset Windows Store"     "Limpa cache e reinicia a Microsoft Store"
        Write-MenuItem "2"  "Reparar .NET Framework"  "Reinstala componentes .NET via DISM"
        Write-MenuItem "3"  "Rebuild WMI Repository"  "Corrige erros de consultas WMI/WMIC"
        Write-MenuItem "4"  "Rebuild Cache de Icones"  "Corrige icones brancos ou quebrados"
        Write-MenuItem "5"  "Rebuild Cache de Fontes"  "Corrige fontes que nao aparecem"
        Write-MenuItem "6"  "Reparar Windows Search"   "Reconstroi o indice de pesquisa"
        Write-MenuItem "7"  "Rebuild Perf Counters"    "Corrige contadores de performance (Monitor)"
        Write-MenuItem "8"  "Reinstalar Apps Sistema"  "Reinstala apps nativos corrompidos"
        Write-MenuItem "9"  "Reparar Windows Defender" "Reinicia servicos de seguranca"
        Write-Host ""
        Write-MenuItem "0" "Voltar" "" "DarkGray"
        Write-Host ""
        $op = Read-Host "  Opcao"
        switch ($op) {
            "1" { Run-ResetStore }
            "2" { Run-RepairDotNet }
            "3" { Run-RebuildWMI }
            "4" { Run-RebuildIconCache }
            "5" { Run-RebuildFontCache }
            "6" { Run-RepairSearch }
            "7" { Run-RebuildPerfCounters }
            "8" { Run-ReinstallApps }
            "9" { Run-RepairDefender }
            "0" { return }
        }
    } while ($true)
}

function Run-ResetStore {
    Write-S "Limpando cache da Microsoft Store..." "RUN"
    try {
        Start-Process wsreset.exe -Wait
        Write-S "Store resetada. A loja deve abrir automaticamente." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-RepairDotNet {
    Write-S "Reparando .NET Framework via DISM..." "RUN"
    Write-S "Isso pode levar alguns minutos..." "WARN"
    try {
        # Habilita .NET 3.5 (caso esteja faltando)
        Dism /online /Enable-Feature /FeatureName:NetFx3 /All 2>$null
        # Repara .NET 4.x
        Dism /online /Enable-Feature /FeatureName:WCF-HTTP-Activation45 /All 2>$null
        Dism /online /Enable-Feature /FeatureName:WCF-TCP-Activation45 /All 2>$null
        Write-S ".NET Framework reparado." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-RebuildWMI {
    Write-S "Reconstruindo repositorio WMI..." "RUN"
    Write-S "Isso corrige erros tipo 'Invalid class' em scripts e WMIC." "INFO"
    try {
        Stop-Service winmgmt -Force -ErrorAction SilentlyContinue
        winmgmt /salvagerepository
        Start-Service winmgmt
        Write-S "Repositorio WMI reconstruido." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-RebuildIconCache {
    Write-S "Limpando cache de icones..." "RUN"
    try {
        # Mata o Explorer temporariamente
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        # Limpa cache de icones
        $iconCachePath = "$env:LOCALAPPDATA\IconCache.db"
        Remove-Item $iconCachePath -Force -ErrorAction SilentlyContinue
        
        # Limpa thumbcache
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force -ErrorAction SilentlyContinue
        
        # Reinicia Explorer
        Start-Process explorer.exe
        Write-S "Cache de icones limpo. Icones serao recriados." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-RebuildFontCache {
    Write-S "Reconstruindo cache de fontes..." "RUN"
    try {
        Stop-Service FontCache -Force -ErrorAction SilentlyContinue
        Stop-Service FontCache3.0.0.0 -Force -ErrorAction SilentlyContinue
        
        Remove-Item "$env:windir\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item "$env:windir\System32\FNTCACHE.DAT" -Force -ErrorAction SilentlyContinue
        
        Start-Service FontCache -ErrorAction SilentlyContinue
        Write-S "Cache de fontes limpo. Reinicie o PC para aplicar." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-RepairSearch {
    Write-S "Reparando Windows Search..." "RUN"
    try {
        # Para o servico
        Stop-Service WSearch -Force -ErrorAction SilentlyContinue
        
        # Apaga o indice antigo
        Remove-Item "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb" -Force -ErrorAction SilentlyContinue
        
        # Reinicia o servico para reconstruir
        Start-Service WSearch -ErrorAction SilentlyContinue
        Write-S "Indice de pesquisa sera reconstruido em background." "OK"
        Write-S "A pesquisa pode ficar lenta ate o indice ser recriado." "WARN"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-RebuildPerfCounters {
    Write-S "Reconstruindo contadores de performance..." "RUN"
    try {
        lodctr /R 2>$null
        winmgmt /resyncperf 2>$null
        Write-S "Contadores reconstruidos." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-ReinstallApps {
    Write-S "Reinstalando apps nativos do Windows..." "RUN"
    Write-S "Isso reinstala apps corrompidos (Calculadora, Fotos, etc)." "INFO"
    try {
        Get-AppxPackage -AllUsers | ForEach-Object {
            Add-AppxPackage -Register "$($_.InstallLocation)\AppXManifest.xml" -DisableDevelopmentMode -ErrorAction SilentlyContinue
        }
        Write-S "Apps reinstalados." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

function Run-RepairDefender {
    Write-S "Reparando Windows Defender..." "RUN"
    try {
        # Reinicia servicos de seguranca
        "SecurityHealthService","WinDefend","WdNisSvc" | ForEach-Object {
            Set-Service $_ -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service $_ -ErrorAction SilentlyContinue
        }
        
        # Atualiza definicoes
        Write-S "Atualizando definicoes de virus..." "RUN"
        Start-Process "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ArgumentList "-SignatureUpdate" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        
        Write-S "Defender reparado e atualizado." "OK"
    } catch { Write-S "Erro: $_" "FAIL" }
    Pause-Menu
}

# ===================== 6. ZONA DE PERIGO =====================

function Menu-Danger {
    Clear-Host
    Write-Box "ZONA DE PERIGO (ADMIN)" "Red"
    Write-Host "  |  Estas acoes alteram configuracoes criticas do sistema.          |" -ForegroundColor Red
    Write-Host "  |  Todas exigem confirmacao antes de executar.                     |" -ForegroundColor Red
    Write-Sep
    Write-Host ""
    Write-MenuItem "1"  "Reset Firewall"         "Restaura regras de fabrica" "Red"
    Write-MenuItem "2"  "Reset Hosts File"       "Limpa bloqueios do arquivo hosts" "Red"
    Write-MenuItem "3"  "Reset Rede Completo"    "Winsock + TCP/IP (REQUER REBOOT)" "Red"
    Write-MenuItem "4"  "Reset Windows Update"   "Limpa SoftwareDistribution" "Red"
    Write-MenuItem "5"  "Limpar Perfis Antigos"  "Remove usuarios inativos >30 dias" "Red"
    Write-MenuItem "6"  "Limpeza WinSxS"         "Component Store Cleanup (demorado)" "Red"
    Write-MenuItem "7"  "Bloquear/Liberar USB"   "Torna pen drives somente leitura" "Red"
    Write-MenuItem "8"  "Tomar Posse (Contexto)" "Adiciona opcao no clique direito" "Red"
    Write-MenuItem "9"  "TRIM no SSD"            "Forca otimizacao de disco" "Red"
    Write-MenuItem "10" "Toggle RDP"             "Ativa ou desativa Acesso Remoto" "Red"
    Write-MenuItem "11" "MAS - Ativacao Microsoft" "Microsoft Activation Scripts (get.activated.win)" "Red"
    Write-Host ""
    Write-MenuItem "0" "Voltar" "" "DarkGray"
    Write-Host ""

    $op = Read-Host "  Opcao"
    switch ($op) {
        "1"  {
            if (Confirm-Action "Resetar TODAS as regras do Firewall para o padrao?") {
                netsh advfirewall reset
                Write-S "Firewall resetado." "OK"
                Pause-Menu
            }
        }
        "2"  {
            if (Confirm-Action "Limpar o arquivo hosts? (backup sera criado)") {
                $h = "$env:WINDIR\System32\drivers\etc\hosts"
                Copy-Item $h "$h.bak" -Force
                Set-Content $h "# Hosts file resetado por TI-Tools em $(Get-Date)"
                Write-S "Hosts limpo. Backup: hosts.bak" "OK"
                Pause-Menu
            }
        }
        "3"  {
            if (Confirm-Action "Resetar Winsock e TCP/IP? (REQUER REINICIAR)") {
                netsh winsock reset
                netsh int ip reset
                Write-S "Rede resetada. REINICIE O PC AGORA!" "WARN"
                Pause-Menu
            }
        }
        "4"  {
            if (Confirm-Action "Resetar componentes do Windows Update?") {
                "wuauserv","cryptSvc","bits","msiserver" | ForEach-Object { Stop-Service $_ -Force -ErrorAction SilentlyContinue }
                Remove-Item "$env:windir\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "$env:windir\System32\catroot2" -Recurse -Force -ErrorAction SilentlyContinue
                "wuauserv","cryptSvc","bits","msiserver" | ForEach-Object { Start-Service $_ -ErrorAction SilentlyContinue }
                Write-S "Windows Update resetado." "OK"
                Pause-Menu
            }
        }
        "5"  {
            if (Confirm-Action "Remover perfis de usuarios inativos ha mais de 30 dias?") {
                try {
                    $profiles = Get-CimInstance Win32_UserProfile | Where-Object {!$_.Special -and !$_.Loaded -and $_.LastUseTime -lt (Get-Date).AddDays(-30)}
                    if ($profiles) { $profiles | Remove-CimInstance -Verbose; Write-S "Perfis removidos." "OK" }
                    else { Write-S "Nenhum perfil inativo encontrado." "INFO" }
                } catch { Write-S "Erro: $_" "FAIL" }
                Pause-Menu
            }
        }
        "6"  {
            if (Confirm-Action "Executar limpeza do WinSxS? (pode demorar bastante)") {
                Write-S "Iniciando DISM StartComponentCleanup..." "RUN"
                Dism /online /Cleanup-Image /StartComponentCleanup
                Pause-Menu
            }
        }
        "7"  {
            $p = "HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies"
            if (!(Test-Path $p)) { New-Item $p -Force | Out-Null }
            $current = (Get-ItemProperty $p -ErrorAction SilentlyContinue).WriteProtect
            $statusNow = if ($current -eq 1) { "BLOQUEADO (Read-Only)" } else { "LIBERADO (Leitura/Escrita)" }
            Write-S "Status atual: $statusNow" "INFO"
            $v = Read-Host "  1=Bloquear, 0=Liberar"
            Set-ItemProperty $p "WriteProtect" $v
            Write-S "Configurado." "OK"
            Pause-Menu
        }
        "8"  {
            if (Confirm-Action "Adicionar 'Tomar Posse' no menu de contexto?") {
                try {
                    $regPath = "Registry::HKEY_CLASSES_ROOT\*\shell\TakeOwnership"
                    New-Item "$regPath\command" -Force | Out-Null
                    Set-ItemProperty $regPath "(default)" "Tomar Posse (Admin)"
                    Set-ItemProperty $regPath "HasLUAShield" ""
                    Set-ItemProperty $regPath "NoWorkingDirectory" ""
                    Set-ItemProperty "$regPath\command" "(default)" 'cmd.exe /c takeown /f "%1" && icacls "%1" /grant administrators:F'
                    Set-ItemProperty "$regPath\command" "IsolatedCommand" 'cmd.exe /c takeown /f "%1" && icacls "%1" /grant administrators:F'
                    Write-S "Menu de contexto adicionado." "OK"
                } catch { Write-S "Erro: $_" "FAIL" }
                Pause-Menu
            }
        }
        "9"  {
            if (Confirm-Action "Forcar TRIM no SSD (unidade C)?") {
                try { Optimize-Volume -DriveLetter C -ReTrim -Verbose; Write-S "TRIM concluido." "OK" }
                catch { Write-S "Erro: $_" "FAIL" }
                Pause-Menu
            }
        }
        "10" {
            $k = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
            $v = (Get-ItemProperty $k).fDenyTSConnections
            $statusNow = if ($v -eq 0) { "ATIVO" } else { "DESATIVADO" }
            Write-S "RDP esta: $statusNow" "INFO"
            if (Confirm-Action "Alternar RDP?") {
                $nv = if ($v -eq 0) { 1 } else { 0 }
                Set-ItemProperty $k "fDenyTSConnections" $nv
                if ($nv -eq 0) {
                    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
                }
                $newStatus = if ($nv -eq 0) { "ATIVO" } else { "DESATIVADO" }
                Write-S "RDP agora esta: $newStatus" "OK"
            }
            Pause-Menu
        }
        "11" {
            Write-S "Microsoft Activation Scripts (MAS)" "INFO"
            Write-S "Fonte: https://get.activated.win" "INFO"
            Write-Host ""
            if (Confirm-Action "Executar MAS (Microsoft Activation Scripts)?") {
                Write-S "Baixando e executando MAS..." "RUN"
                Write-S "Uma nova janela sera aberta com as opcoes." "WARN"
                try {
                    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://get.activated.win | iex`"" -Verb RunAs
                    Write-S "MAS iniciado em nova janela." "OK"
                } catch { Write-S "Erro: $_" "FAIL" }
                Pause-Menu
            }
        }
        "0" { return }
    }
}

# ===================== LOOP PRINCIPAL =====================

if ($ScheduledClean) {
    Run-CleanAll | Out-Null
    exit
}

do {
    Show-MainMenu
    $m = Read-Host "  Menu"
    switch ($m) {
        "1" { Menu-Diagnostico }
        "2" { Menu-Rede }
        "3" { Menu-Limpeza }
        "4" { Menu-Seguranca }
        "5" { Menu-Correcoes }
        "6" { Menu-Danger }
        "0" { Clear-Host; Write-Host "  Ate logo!" -ForegroundColor Cyan; Start-Sleep -Seconds 1; exit }
    }
} while ($true)

