function Show-WPFInstallAppBusy {
    <#
    .SYNOPSIS
        Displays a busy overlay in the install app area of the WPF form.
        This is used to indicate that an install or uninstall is in progress.
        Dynamically updates the size of the overlay based on the app area on each invocation.
    .PARAMETER text
        The text to display in the busy overlay. Defaults to "正在安装应用...".
    #>
    param (
        $text = "正在安装应用..."
    )
    $overlayText = $text

    Invoke-WPFUIThread -ScriptBlock {
        $sync.InstallAppAreaOverlay.Visibility = [Windows.Visibility]::Visible
        $sync.InstallAppAreaOverlay.Width = $($sync.InstallAppAreaScrollViewer.ActualWidth * 0.4)
        $sync.InstallAppAreaOverlay.Height = $($sync.InstallAppAreaScrollViewer.ActualWidth * 0.4)
        $sync.InstallAppAreaOverlayText.Text = $overlayText
        $sync.InstallAppAreaBorder.IsEnabled = $false
        $sync.InstallAppAreaScrollViewer.Effect.Radius = 5
    }
}
