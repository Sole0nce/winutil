function Invoke-WPFUpdatesdisable {
    <#

    .SYNOPSIS
        Disables Windows Update

    .NOTES
        Disabling Windows Update is not recommended. This is only for advanced users who know what they are doing.

    #>
    $ErrorActionPreference = 'SilentlyContinue'
    Write-WinUtilLog -Component "Updates" -Message "Disabling Windows Update settings."

    Write-Host "正在配置注册表设置..." -ForegroundColor Yellow
    Write-WinUtilLog -Component "Updates" -Message "Configuring Windows Update registry policy values for disable mode."
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Type DWord -Value 1

    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 0

    Write-Host "正在从设置中隐藏 Windows 更新..."
    Write-WinUtilLog -Component "Updates" -Message "Hiding Windows Update settings page."
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name SettingsPageVisibility -Value hide:windowsupdate

    Write-Host "已禁用 BITS 服务。"
    Write-WinUtilLog -Component "Updates" -Message "Disabling BITS service."
    Set-Service -Name BITS -StartupType Disabled

    Write-Host "已禁用 wuauserv 服务。"
    Write-WinUtilLog -Component "Updates" -Message "Disabling wuauserv service."
    Set-Service -Name wuauserv -StartupType Disabled

    Write-Host "已禁用 UsoSvc 服务。"
    Write-WinUtilLog -Component "Updates" -Message "Stopping and disabling UsoSvc service."
    Stop-Service -Name UsoSvc -Force
    Set-Service -Name UsoSvc -StartupType Disabled

    Remove-Item "C:\Windows\SoftwareDistribution\*" -Recurse -Force
    Write-Host "已清空 SoftwareDistribution 文件夹。"
    Write-WinUtilLog -Component "Updates" -Message "Cleared SoftwareDistribution folder."

    Write-Host "正在禁用更新相关的计划任务..." -ForegroundColor Yellow
    Write-WinUtilLog -Component "Updates" -Message "Disabling update related scheduled tasks."

    $Tasks =
        '\Microsoft\Windows\InstallService\*',
        '\Microsoft\Windows\UpdateOrchestrator\*',
        '\Microsoft\Windows\UpdateAssistant\*',
        '\Microsoft\Windows\WaaSMedic\*',
        '\Microsoft\Windows\WindowsUpdate\*',
        '\Microsoft\WindowsUpdate\*'

    foreach ($Task in $Tasks) {
        Get-ScheduledTask -TaskPath $Task | Disable-ScheduledTask -ErrorAction SilentlyContinue
    }

    Write-Host "=================================" -ForegroundColor Green
    Write-Host "---   更新已禁用    ---" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green

    Write-Host "注意：您必须重新启动系统才能使所有更改生效。" -ForegroundColor Yellow
    Write-WinUtilLog -Component "Updates" -Message "Windows Update disable workflow completed. Restart required."
}
