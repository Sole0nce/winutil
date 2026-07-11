function Invoke-WPFUpdatesdefault {
    <#

    .SYNOPSIS
        Resets Windows Update settings to default

    #>
    $ErrorActionPreference = 'SilentlyContinue'
    Write-WinUtilLog -Component "Updates" -Message "Resetting Windows Update settings to default."

    Write-Host "正在移除 Windows 更新策略设置..." -ForegroundColor Green
    Write-WinUtilLog -Component "Updates" -Message "Removing Windows Update policy registry paths."

    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Recurse -Force
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization" -Recurse -Force
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Recurse -Force
    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Recurse -Force
    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Recurse -Force
    Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Recurse -Force

    Write-Host "正在在设置中显示 Windows 更新..."
    Write-WinUtilLog -Component "Updates" -Message "Showing Windows Update settings page."
    Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name SettingsPageVisibility

    Write-Host "正在重新启用 Windows 更新服务..." -ForegroundColor Green
    Write-WinUtilLog -Component "Updates" -Message "Restoring Windows Update service startup types."

    Write-Host "已将 BITS 恢复为手动。"
    Write-WinUtilLog -Component "Updates" -Message "Restoring BITS service to Manual."
    Set-Service -Name BITS -StartupType Manual

    Write-Host "已将 wuauserv 恢复为手动。"
    Write-WinUtilLog -Component "Updates" -Message "Restoring wuauserv service to Manual."
    Set-Service -Name wuauserv -StartupType Manual

    Write-Host "已将 UsoSvc 恢复为自动。"
    Write-WinUtilLog -Component "Updates" -Message "Starting UsoSvc service and restoring startup type to Automatic."
    Start-Service -Name UsoSvc
    Set-Service -Name UsoSvc -StartupType Automatic

    Write-Host "已将 WaaSMedicSvc 恢复为手动。"
    Write-WinUtilLog -Component "Updates" -Message "Restoring WaaSMedicSvc service to Manual."
    Set-Service -Name WaaSMedicSvc -StartupType Manual

    Write-Host "正在启用更新相关的计划任务..." -ForegroundColor Green
    Write-WinUtilLog -Component "Updates" -Message "Enabling update related scheduled tasks."

    $Tasks =
        '\Microsoft\Windows\InstallService\*',
        '\Microsoft\Windows\UpdateOrchestrator\*',
        '\Microsoft\Windows\UpdateAssistant\*',
        '\Microsoft\Windows\WaaSMedic\*',
        '\Microsoft\Windows\WindowsUpdate\*',
        '\Microsoft\WindowsUpdate\*'

    foreach ($Task in $Tasks) {
        Get-ScheduledTask -TaskPath $Task | Enable-ScheduledTask -ErrorAction SilentlyContinue
    }

    Write-Host "Windows 本地策略已重置为默认。"
    Write-WinUtilLog -Component "Updates" -Message "Resetting local security policy to defaults with secedit."
    secedit /configure /cfg "$Env:SystemRoot\inf\defltbase.inf" /db defltbase.sdb

    Write-Host "===================================================" -ForegroundColor Green
    Write-Host "---  Windows 更新设置已重置为默认   ---" -ForegroundColor Green
    Write-Host "===================================================" -ForegroundColor Green

    Write-Host "注意：您必须重新启动系统才能使所有更改生效。" -ForegroundColor Yellow
    Write-WinUtilLog -Component "Updates" -Message "Windows Update default workflow completed. Restart required."
}
