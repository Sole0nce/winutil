function Set-WinUtilDNS {
    <#

    .SYNOPSIS
        Sets the DNS of all interfaces that are in the "Up" state. It will lookup the values from the DNS.Json file

    .PARAMETER DNSProvider
        The DNS provider to set the DNS server to

    .EXAMPLE
        Set-WinUtilDNS -DNSProvider "google"

    #>
    param($DNSProvider)

    if($DNSProvider -eq "Default") {
        Write-WinUtilLog -Component "DNS" -Message "DNS provider is Default; no DNS changes applied."
        return $true
    }

    try {
        $Adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
        Write-Host "正在确保 DNS 设置为 $DNSProvider，涉及以下接口："
        Write-Host $($Adapters | Out-String)
        Write-WinUtilLog -Component "DNS" -Message "Setting DNS provider to $DNSProvider for $(@($Adapters).Count) active adapter(s)."

        if($DNSProvider -ne "DHCP") {
            $dns = $sync.configs.dns.$DNSProvider
            if($null -eq $dns) {
                Write-Warning "配置中未找到 DNS 提供商 $DNSProvider。"
                Write-WinUtilLog -Level "ERROR" -Component "DNS" -Message "配置中未找到 DNS 提供商 $DNSProvider。"
                return $false
            }
        }

        $dohSupported = [bool](Get-Command Add-DnsClientDohServerAddress -ErrorAction SilentlyContinue)
        if ($DNSProvider -ne "DHCP" -and $dns.DohOnly -and -not $dohSupported) {
            Write-Warning "DNS 提供商 $DNSProvider 需要 DNS over HTTPS，当前系统不支持。"
            Write-WinUtilLog -Level "ERROR" -Component "DNS" -Message "DNS 提供商 $DNSProvider 需要 DNS over HTTPS，当前系统不支持。"
            return $false
        }

        $dnscacheBase = "HKLM:\System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters"

        Foreach ($Adapter in $Adapters) {
            $interfaceParams = "$dnscacheBase\$($Adapter.InterfaceGuid)"

            if($DNSProvider -eq "DHCP") {
                Write-WinUtilLog -Component "DNS" -Message "Resetting DNS to DHCP on adapter $($Adapter.Name) (ifIndex: $($Adapter.ifIndex))."
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ResetServerAddresses
                netsh interface ip set dnsservers name="$($Adapter.Name)" source=dhcp
                netsh interface ipv6 set dnsservers name="$($Adapter.Name)" source=dhcp

                $dohInterfaceSettings = "$interfaceParams\DohInterfaceSettings"
                if (Test-Path $dohInterfaceSettings) {
                    if ($dohSupported) {
                        $dohServerAddresses = @(
                            Get-ChildItem -Path "$dohInterfaceSettings\Doh" -ErrorAction SilentlyContinue
                            Get-ChildItem -Path "$dohInterfaceSettings\Doh6" -ErrorAction SilentlyContinue
                        ) | Select-Object -ExpandProperty PSChildName -Unique

                        foreach ($ip in $dohServerAddresses) {
                            if (Get-DnsClientDohServerAddress -ServerAddress $ip -ErrorAction SilentlyContinue) {
                                Write-WinUtilLog -Component "DNS" -Message "Removing DoH registration for $ip."
                                Remove-DnsClientDohServerAddress -ServerAddress $ip -Confirm:$false -ErrorAction Stop
                            }
                        }
                    }

                    Remove-Item -Path $dohInterfaceSettings -Recurse -Force -ErrorAction SilentlyContinue
                }
            } else {
                $ipv4Addresses = @(@($dns.Primary, $dns.Secondary) | Where-Object { $_ })
                $ipv6Addresses = @(@($dns.Primary6, $dns.Secondary6) | Where-Object { $_ })

                if ($dohSupported -and $dns.DohTemplate) {
                    try {
                        $ips = @($dns.Primary, $dns.Secondary, $dns.Primary6, $dns.Secondary6) | Where-Object { $_ }
                        foreach ($ip in $ips) {
                            $dohTemplate = if ($dns.SecondaryDohTemplate -and @($dns.Secondary, $dns.Secondary6) -contains $ip) {
                                $dns.SecondaryDohTemplate
                            } else {
                                $dns.DohTemplate
                            }
                            $existing = Get-DnsClientDohServerAddress -ServerAddress $ip -ErrorAction SilentlyContinue
                            if ($existing) {
                                Set-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate $dohTemplate -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop
                            } else {
                                Write-WinUtilLog -Component "DNS" -Message "Registering DoH template for $ip."
                                Add-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate $dohTemplate -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction Stop
                            }

                            $leaf = if ($ip.Contains(':')) { 'Doh6' } else { 'Doh' }
                            $regPath = "$interfaceParams\DohInterfaceSettings\$leaf\$ip"

                            if (-not (Test-Path $regPath)) {
                                New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
                            }
                            New-ItemProperty -Path $regPath -Name "DohFlags" -Value 1 -PropertyType QWord -Force -ErrorAction Stop | Out-Null
                        }
                    } catch {
                        if ($dns.DohOnly) {
                            throw
                        }

                        Write-Warning "提供商 $DNSProvider 的 DNS over HTTPS 配置失败；将继续使用普通 DNS。"
                        Write-WinUtilLog -Level "WARN" -Component "DNS" -Message "DNS over HTTPS setup for provider $DNSProvider failed; continuing with plain DNS: $($psitem.Exception.Message)"
                    }
                }

                Write-WinUtilLog -Component "DNS" -Message "Setting IPv4 DNS on adapter $($Adapter.Name) (ifIndex: $($Adapter.ifIndex)) to $($dns.Primary), $($dns.Secondary)."
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses $ipv4Addresses -ErrorAction Stop
                Write-WinUtilLog -Component "DNS" -Message "Setting IPv6 DNS on adapter $($Adapter.Name) (ifIndex: $($Adapter.ifIndex)) to $($dns.Primary6), $($dns.Secondary6)."
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses $ipv6Addresses -ErrorAction Stop
            }
        }
        if ($DNSProvider -ne "DHCP" -and $dohSupported -and $dns.DohTemplate) {
            Clear-DnsClientCache
        }
        Write-WinUtilLog -Component "DNS" -Message "DNS provider change completed: $DNSProvider"
        return $true
    } catch {
        Write-Warning "由于发生错误，DNS 提供商 $DNSProvider 未能完成。"
        Write-Warning $psitem.Exception.Message
        Write-WinUtilLog -Level "ERROR" -Component "DNS" -Message "DNS provider $DNSProvider was not completed: $($psitem.Exception.Message)"
        return $false
    }
}
