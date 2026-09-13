function Invoke-WPFOOSU {
    try {
        $ProgressPreference = 'SilentlyContinue'

        Invoke-WebRequest -Uri https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe -OutFile "$winutildir\ooshutup10.exe"
        Start-Process -FilePath "$winutildir\ooshutup10.exe"

        $ProgressPreference = 'Continue'
    } catch {
        Write-Error "无法下载 O&O ShutUp10。请确保你有可用的网络连接。"
    }
}
