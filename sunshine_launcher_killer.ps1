param(
    [switch]$AutoStart,
    [string]$SunshinePath
    )
    

$AutoKillOnExit = $true

$defaultSunshinePath = "C:\\sunshineportable"
if ($false){
    $defaultSunshinePath = Split-Path -Parent $MyInvocation.MyCommand.Definition  -ErrorAction SilentlyContinue # only for .ps1 file
    if (-not $defaultSunshinePath) {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $defaultSunshinePath = Split-Path -Parent $exePath # only for compilation
    }
}

if ([string]::IsNullOrWhiteSpace($SunshinePath)) {
    $SunshinePath = $defaultSunshinePath
}

if (-not $AutoStart.IsPresent) {
    $AutoStart = $true
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Variablen
$procName = "sunshine"
$ramThresholdMB = 65
$killTimeout = 300
$lastNotIdleTimestamp = Get-Date

# GUI Elemente
$form = New-Object System.Windows.Forms.Form
$form.Text = "Sunshine Launcher"
$form.Size = New-Object System.Drawing.Size(400,340)
$form.StartPosition = "CenterScreen"
$form.KeyPreview = $true # Damit das Formular Tastenereignisse bekommt

$panelStatus = New-Object System.Windows.Forms.Panel
$panelStatus.Size = New-Object System.Drawing.Size(100,100)
$panelStatus.Location = New-Object System.Drawing.Point(20,20)
$panelStatus.BackColor = [System.Drawing.Color]::Gray
$form.Controls.Add($panelStatus)

$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Status: -"
$labelStatus.AutoSize = $true
$labelStatus.Location = New-Object System.Drawing.Point(130, 30)
$form.Controls.Add($labelStatus)

$labelRAM = New-Object System.Windows.Forms.Label
$labelRAM.Text = "RAM: - MB"
$labelRAM.AutoSize = $true
$labelRAM.Location = New-Object System.Drawing.Point(130, 60)
$form.Controls.Add($labelRAM)

$labelCountdown = New-Object System.Windows.Forms.Label
$labelCountdown.Text = ""
$labelCountdown.AutoSize = $true
$labelCountdown.Location = New-Object System.Drawing.Point(130, 90)
$form.Controls.Add($labelCountdown)

$chkAutoKill = New-Object System.Windows.Forms.CheckBox
$chkAutoKill.Text = "Autokill idle"
$chkAutoKill.Location = New-Object System.Drawing.Point(20,140)
$chkAutoKill.AutoSize = $true
$form.Controls.Add($chkAutoKill)

$labelThreshold = New-Object System.Windows.Forms.Label
$labelThreshold.Text = "RAM-Schwellwert (MB):"
$labelThreshold.Location = New-Object System.Drawing.Point(20,170)
$labelThreshold.AutoSize = $true
$form.Controls.Add($labelThreshold)

$numThreshold = New-Object System.Windows.Forms.NumericUpDown
$numThreshold.Minimum = 10
$numThreshold.Maximum = 1000
$numThreshold.Value = $ramThresholdMB
$numThreshold.Location = New-Object System.Drawing.Point(180,165)
$numThreshold.Width = 60
$form.Controls.Add($numThreshold)

$labelTimeout = New-Object System.Windows.Forms.Label
$labelTimeout.Text = "Kill Timeout (Sek.):"
$labelTimeout.Location = New-Object System.Drawing.Point(20,200)
$labelTimeout.AutoSize = $true
$form.Controls.Add($labelTimeout)

$numTimeout = New-Object System.Windows.Forms.NumericUpDown
$numTimeout.Minimum = 5
$numTimeout.Maximum = 300
$numTimeout.Value = $killTimeout
$numTimeout.Location = New-Object System.Drawing.Point(180,195)
$numTimeout.Width = 60
$form.Controls.Add($numTimeout)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Sunshine starten"
$btnStart.Location = New-Object System.Drawing.Point(20,230)
$btnStart.Width = 150
$form.Controls.Add($btnStart)

$btnKill = New-Object System.Windows.Forms.Button
$btnKill.Text = "Sunshine killen"
$btnKill.Location = New-Object System.Drawing.Point(200,230)
$btnKill.Width = 150
$form.Controls.Add($btnKill)

# Neue Checkbox "Kill Sunshine beim Beenden"
$chkKillOnExit = New-Object System.Windows.Forms.CheckBox
$chkKillOnExit.Text = "Sunshine beim Beenden killen"
$chkKillOnExit.Location = New-Object System.Drawing.Point(20, 270)
$chkKillOnExit.AutoSize = $true
$form.Controls.Add($chkKillOnExit)

# Statusprüfung
function Update-Status {
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($proc) { # running
        $procId = $proc.Id
        $ramMB = [math]::Round($proc.PrivateMemorySize64 / 1MB, 2)
        $labelRAM.Text = "RAM: $ramMB MB"

        # TCP-Aktivität prüfen
        $tcpPorts = @(47984, 47989, 48010)
        $tcpActive = Get-NetTCPConnection | Where-Object {
            $tcpPorts -contains $_.LocalPort -and
            $_.State -eq 'Established' -and
            $_.OwningProcess -eq $procId
        }

        if ($tcpActive -or $ramMB -gt $numThreshold.Value) { # running AND streaming
                    
            if ($chkAutoKill.Checked) {
                $panelStatus.BackColor = [System.Drawing.Color]::Green
                $labelStatus.Text = "Stream: Aktiv; Autokill: Aktiv"
            } else {
                $panelStatus.BackColor = [System.Drawing.Color]::Red
                $labelStatus.Text = "Stream: Aktiv; Autokill: AUS"
            }            
            $global:lastNotIdleTimestamp = Get-Date
            $labelCountdown.Text = ""
        }
        else { # running NOT streaming
            $panelStatus.BackColor = [System.Drawing.Color]::Yellow
            $labelStatus.Text = "Status: Idle"

            $idleSeconds = (New-TimeSpan -Start $lastNotIdleTimestamp -End (Get-Date)).TotalSeconds
            $remaining = [math]::Max(0, [math]::Round($numTimeout.Value - $idleSeconds))
            if ($chkAutoKill.Checked) {
                $labelCountdown.Text = "After $remaining Sek. TERMINATE Sunshine"
            } else {
                $labelCountdown.Text = "After $remaining Sek. do nothing"
            }

            if ($chkAutoKill.Checked -and $remaining -le 0) {
                try {
                    Stop-Process -Id $procId -Force
                    $labelStatus.Text = "Sunshine gekillt"
                    $labelCountdown.Text = ""
                    $panelStatus.BackColor = [System.Drawing.Color]::Gray
                } catch {
                    Write-Host "Fehler beim Kill: $_"
                }
                $global:lastNotIdleTimestamp = Get-Date
            }
        }
    }
    else { # not running
        $panelStatus.BackColor = [System.Drawing.Color]::Gray
        $labelStatus.Text = "Status: Nicht gestartet"
        $labelRAM.Text = "RAM: - MB"
        $labelCountdown.Text = ""
        $global:lastNotIdleTimestamp = Get-Date
    }
}

# Start & Kill Funktionen
function Start-Sunshine {
    $global:lastNotIdleTimestamp = Get-Date
    Write-Host "SunshinePath: $SunshinePath"
    $exePath = Join-Path $SunshinePath "sunshine.exe"
    if (-not (Test-Path $exePath)) {
        [System.Windows.Forms.MessageBox]::Show("sunshine.exe nicht gefunden:`n$exePath", "Fehler")
        return
    }
    if (-not (Get-Process -Name $procName -ErrorAction SilentlyContinue)) {
        Write-Host "Starting: $exePath"
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c start `"$procName`" `"$exePath`"" -WorkingDirectory $SunshinePath
        $global:lastNotIdleTimestamp = Get-Date
    }
}

function Kill-Sunshine {
    Write-Host "Killing: $procName"
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "Killing: $proc"
        Stop-Process -Id $proc.Id -Force
        $labelCountdown.Text = ""
        $labelStatus.Text = "Sunshine gekillt"
        $panelStatus.BackColor = [System.Drawing.Color]::Gray
        $global:lastNotIdleTimestamp = Get-Date
    }
}

# Events
$btnStart.Add_Click({ Start-Sunshine })
$btnKill.Add_Click({ Kill-Sunshine })
$chkAutoKill.Checked = $AutoStart
$chkKillOnExit.Checked = $AutoKillOnExit
# ESC Taste zum Schließen
$form.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
        $form.Close()
    }
})

# Kill Sunshine beim Schließen (wenn aktiviert)
$form.Add_FormClosing({
    if ($chkKillOnExit.Checked) {
        Kill-Sunshine
    }
})

# Autostart
if ($AutoStart -and -not (Get-Process -Name $procName -ErrorAction SilentlyContinue)) {
    Start-Sunshine
}

# === Main Loop ===
$form.Show()
while ($form.Visible) {
    Update-Status
    Start-Sleep -Seconds 1
    [System.Windows.Forms.Application]::DoEvents()
}
