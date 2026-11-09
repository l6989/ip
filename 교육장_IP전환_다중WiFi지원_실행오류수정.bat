@echo off
setlocal
set "EDU_IP_SCRIPT=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $text=[IO.File]::ReadAllText($env:EDU_IP_SCRIPT,[Text.Encoding]::UTF8); $code=($text -split '(?m)^# POWERSHELL_PAYLOAD\r?$')[1]; if (-not $code) { throw 'Missing script payload' }; $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code)); Start-Process -FilePath ($env:SystemRoot+'\System32\WindowsPowerShell\v1.0\powershell.exe') -Verb RunAs -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -Wait } catch { Write-Host $_; exit 1 }"
if errorlevel 1 pause
exit /b
# POWERSHELL_PAYLOAD
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = '교육장 네트워크 설정 (다중 Wi-Fi 지원)'
$form.ClientSize = New-Object System.Drawing.Size(640,500)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$ipLabel = New-Object System.Windows.Forms.Label
$ipLabel.Text = '운영진으로 부터 안내받은 고정 IP를 입력하세요'
$ipLabel.Location = New-Object System.Drawing.Point(20,22)
$ipLabel.Size = New-Object System.Drawing.Size(600,25)
$form.Controls.Add($ipLabel)
$prefixLabel = New-Object System.Windows.Forms.Label
$prefixLabel.Text = '10.60.115.'
$prefixLabel.Location = New-Object System.Drawing.Point(20,55)
$prefixLabel.Size = New-Object System.Drawing.Size(100,25)
$form.Controls.Add($prefixLabel)
$ipInput = New-Object System.Windows.Forms.TextBox
$ipInput.Location = New-Object System.Drawing.Point(125,51)
$ipInput.Size = New-Object System.Drawing.Size(100,28)
# 각 PC에 마지막으로 성공한 고정 IP의 끝자리만 저장합니다 (USB에는 저장하지 않음).
$settingsKey = 'HKLM:\SOFTWARE\EducationRoomIPSwitch'
function Load-SavedSuffix {
    try {
        $saved = (Get-ItemProperty -Path $settingsKey -Name LastSuffix -ErrorAction Stop).LastSuffix
        if ([string]$saved -match '^([0-9]{1,3})$' -and [int]$saved -ge 1 -and [int]$saved -le 254) {
            return ([int]$saved).ToString()
        }
    } catch { }
    return ''
}
function Save-Suffix([string]$Suffix) {
    if (-not (Test-Path -LiteralPath $settingsKey)) { New-Item -Path $settingsKey -Force -ErrorAction Stop | Out-Null }
    New-ItemProperty -Path $settingsKey -Name LastSuffix -Value $Suffix -PropertyType String -Force -ErrorAction Stop | Out-Null
}
$ipInput.Text = Load-SavedSuffix
$ipInput.MaxLength = 16
$form.Controls.Add($ipInput)
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(20,146)
$label.Size = New-Object System.Drawing.Size(600,70)
$label.Text = "마스크: 255.255.240.0    게이트웨이: 10.60.112.1    DNS: 152.99.1.6`r`n`r`n교육중엔 `"교육모드`" 교육 종료 후엔 `"일반모드`"로 설정하여 운영하시기 바랍니다."
$form.Controls.Add($label)
$static = New-Object System.Windows.Forms.Button
$static.Text = "교육 모드 전환`r`n(고정 IP 전환)"
$static.Location = New-Object System.Drawing.Point(20,220)
$static.Size = New-Object System.Drawing.Size(285,50)
$form.Controls.Add($static)
$dhcp = New-Object System.Windows.Forms.Button
$dhcp.Text = "일반 모드 전환`r`n(유동 IP 전환)"
$dhcp.Location = New-Object System.Drawing.Point(320,220)
$dhcp.Size = New-Object System.Drawing.Size(300,50)
$form.Controls.Add($dhcp)
$refresh = New-Object System.Windows.Forms.Button
$refresh.Text = '현재 네트워크 정보 확인'
$refresh.Location = New-Object System.Drawing.Point(20,280)
$refresh.Size = New-Object System.Drawing.Size(600,32)
$form.Controls.Add($refresh)
$box = New-Object System.Windows.Forms.TextBox
$box.Location = New-Object System.Drawing.Point(20,320)
$box.Size = New-Object System.Drawing.Size(600,165)
$box.Multiline = $true
$box.ReadOnly = $true
$box.ScrollBars = 'Vertical'
$form.Controls.Add($box)
# Wi-Fi adapter selection: enumerate all physical wireless devices, allow manual selection.
$adapterLabel = New-Object System.Windows.Forms.Label
$adapterLabel.Text = '설정할 Wi-Fi 어댑터 선택'
$adapterLabel.Location = New-Object System.Drawing.Point(20,90)
$adapterLabel.Size = New-Object System.Drawing.Size(220,22)
$form.Controls.Add($adapterLabel)
$adapterChoice = New-Object System.Windows.Forms.ComboBox
$adapterChoice.DropDownStyle = 'DropDownList'
$adapterChoice.Location = New-Object System.Drawing.Point(20,113)
$adapterChoice.Size = New-Object System.Drawing.Size(490,26)
$adapterChoice.DisplayMember = 'Display'
$form.Controls.Add($adapterChoice)
$adapterChoice.Add_SelectedIndexChanged({ if ($adapterChoice.SelectedItem -and $null -ne $box) { try { Show-Status } catch { $box.Text = $_.Exception.Message } } })
$adapterReload = New-Object System.Windows.Forms.Button
$adapterReload.Text = '새로고침'
$adapterReload.Location = New-Object System.Drawing.Point(520,111)
$adapterReload.Size = New-Object System.Drawing.Size(100,28)
$form.Controls.Add($adapterReload)
function Get-WirelessAdapters {
    return @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object {
        $_.NdisPhysicalMedium -eq 9 -or $_.PhysicalMediaType -eq 'Native 802.11' -or $_.MediaType -eq 'Native 802.11'
    } | Sort-Object -Property Name)
}
function Refresh-Adapters {
    $previous = $null
    if ($adapterChoice.SelectedItem) { $previous = $adapterChoice.SelectedItem.Index }
    $adapters = @(Get-WirelessAdapters)
    $adapterChoice.Items.Clear()
    foreach ($a in $adapters) {
        $display = '{0} [{1}] - {2}' -f $a.Name,$a.Status,$a.InterfaceDescription
        [void]$adapterChoice.Items.Add([pscustomobject]@{Display=$display;Index=[int]$a.ifIndex})
    }
    if ($adapters.Count -eq 0) { throw '물리적 Wi-Fi 어댑터를 찾지 못했습니다. 장치 관리자에서 무선랜 장치를 확인하세요.' }
    $chosen = -1
    if ($null -ne $previous) {
        for ($i=0; $i -lt $adapterChoice.Items.Count; $i++) {
            if ($adapterChoice.Items[$i].Index -eq $previous) { $chosen=$i; break }
        }
    }
    if ($chosen -lt 0) {
        for ($i=0; $i -lt $adapters.Count; $i++) {
            if ($adapters[$i].Status -eq 'Up') { $chosen=$i; break }
        }
    }
    if ($chosen -lt 0) { $chosen=0 }
    $adapterChoice.SelectedIndex = $chosen
}
function Selected-Adapter {
    if (-not $adapterChoice.SelectedItem) { Refresh-Adapters }
    $idx = [int]$adapterChoice.SelectedItem.Index
    $match = @(Get-WirelessAdapters | Where-Object { $_.ifIndex -eq $idx })
    if ($match.Count -ne 1) { throw '선택한 Wi-Fi 어댑터가 변경되었습니다. 새로고침 후 다시 선택하세요.' }
    return $match[0]
}
$adapterReload.Add_Click({ try { Refresh-Adapters; Show-Status } catch { $box.Text=$_.Exception.Message } })
function Validate-IP([string]$Value) {
    $parsed = $null
    if ($Value -notmatch '^([0-9]{1,3}\.){3}[0-9]{1,3}$' -or -not [System.Net.IPAddress]::TryParse($Value, [ref]$parsed)) { throw '올바른 IPv4 주소를 입력해주세요.' }
    $bytes = $parsed.GetAddressBytes()
    if ($bytes[0] -ne 10 -or $bytes[1] -ne 60 -or $bytes[2] -lt 112 -or $bytes[2] -gt 127) {
        throw '입력한 IP(10.60.115.*)와 기존 게이트웨이(10.60.112.1)의 대역이 다릅니다. 운영진에게 새 게이트웨이 정보를 확인해주세요.'
    }
    if ($Value -in @('10.60.112.0','10.60.127.255','10.60.112.1')) { throw '네트워크 주소, 브로드캐스트 주소, 게이트웨이는 사용할 수 없습니다.' }
}
function Show-Status {
    $a = Selected-Adapter
    $ips = @(Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength) [$($_.AddressState)]" })
    $int = Get-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4
    $gw = @(Get-NetRoute -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | ForEach-Object { $_.NextHop })
    $dns = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4).ServerAddresses
    $box.Text = "어댑터: $($a.Name) [$($a.Status)]`r`nDHCP: $($int.Dhcp)`r`nIPv4: $($ips -join ', ')`r`n게이트웨이: $($gw -join ', ')`r`nDNS: $($dns -join ', ')`r`n`r`n설정 확인 화면입니다. 인터넷 접속 성공을 의미하지 않습니다."
}
function Invoke-Netsh([string[]]$NetshArgs) {
    $result = & "$env:SystemRoot\System32\netsh.exe" @NetshArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`r`n") }
}
function Apply-Mode([bool]$Fixed) {
    try {
        $a = Selected-Adapter
        $mode = '자동 IP 및 자동 DNS'
        if ($Fixed) {
            $suffix = $ipInput.Text
            if ($suffix -notmatch '^[0-9]{1,3}$') { throw '고정 IP의 마지막 번호는 숫자만 입력해주세요 (1~254). 빈칸, 공백, 문자, 소수는 사용할 수 없습니다.' }
            if ([int]$suffix -lt 1 -or [int]$suffix -gt 254) { throw '고정 IP의 마지막 번호는 1~254 범위로 입력해주세요.' }
            $selectedIP = '10.60.115.' + ([int]$suffix).ToString()
            Validate-IP $selectedIP
            $mode = "고정 IP $selectedIP / DNS 152.99.1.6"
        }
        $answer = [System.Windows.Forms.MessageBox]::Show("[$($a.Name)]에 $mode 설정을 적용합니다.`r`n연결이 잠시 끊길 수 있습니다. 계속하시겠습니까?",'설정 변경 확인','YesNo','Question')
        if ($answer -ne 'Yes') { return }
        $static.Enabled = $false
        $dhcp.Enabled = $false
        $ipInput.Enabled = $false
        $adapterChoice.Enabled = $false
        $adapterReload.Enabled = $false
        if ($Fixed) {
            Invoke-Netsh @('interface','ipv4','set','address',"name=$($a.Name)",'source=static',"address=$selectedIP",'mask=255.255.240.0','gateway=10.60.112.1','gwmetric=1','store=persistent')
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses @('152.99.1.6') -ErrorAction Stop
        } else {
            Invoke-Netsh @('interface','ipv4','set','address',"name=$($a.Name)",'source=dhcp','store=persistent')
            Invoke-Netsh @('interface','ipv4','set','dnsservers',"name=$($a.Name)",'source=dhcp')
        }
        Show-Status
        if ($Fixed) {
            # 실제 Windows 네트워크 설정이 반영된 경우에만 저장합니다.
            $applied = @(Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.IPAddress -eq $selectedIP -and $_.PrefixLength -eq 20 })
            $gatewayOK = @(Get-NetRoute -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Where-Object { $_.NextHop -eq '10.60.112.1' }).Count -gt 0
            $dnsOK = @((Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction Stop).ServerAddresses) -contains '152.99.1.6'
            if ($applied.Count -gt 0 -and $gatewayOK -and $dnsOK) {
                try {
                    Save-Suffix ([int]$suffix).ToString()
                    $box.AppendText("`r`n이 PC의 마지막 고정 IP($selectedIP)를 저장했습니다. 다음 실행 시 자동 입력됩니다.")
                } catch {
                    $box.AppendText("`r`nIP 설정은 반영되었으나 마지막 IP 저장에 실패했습니다: $($_.Exception.Message)")
                }
            } else {
                $box.AppendText("`r`nIP/게이트웨이/DNS 적용 여부가 확인되지 않아 입력값을 저장하지 않았습니다.")
            }
        }
        $box.AppendText("`r`n`r`n설정 명령 완료. 주소 갱신 후 [현재 네트워크 정보 확인]을 누르세요.")

    } catch {
        [System.Windows.Forms.MessageBox]::Show("설정 변경 중 오류: $($_.Exception.Message)`r`n일부 설정만 변경되었을 수 있습니다. 현재 설정을 확인하세요.",'오류','OK','Error') | Out-Null
    } finally {
        $static.Enabled = $true
        $dhcp.Enabled = $true
        $ipInput.Enabled = $true
        $adapterChoice.Enabled = $true
        $adapterReload.Enabled = $true
    }
}
$static.Add_Click({ Apply-Mode $true })
$dhcp.Add_Click({ Apply-Mode $false })
$refresh.Add_Click({ try { Show-Status } catch { $box.Text = $_.Exception.Message } })
try {
    try { Refresh-Adapters; Show-Status } catch { $box.Text = $_.Exception.Message }
    $ipInput.SelectionStart = $ipInput.Text.Length
    $form.ActiveControl = $ipInput
    [void]$form.ShowDialog()
} catch {
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'실행 오류','OK','Error') | Out-Null
}
