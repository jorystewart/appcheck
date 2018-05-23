function Remove-Connection {
    Remove-PSSession -ComputerName $target
    Invoke-Command -ComputerName $target -Credential $cred -ScriptBlock { Unregister-PSSessionConfiguration -Name appcheck -Force}
}
Write-Host "`nThis script will get a list of installed software that is not included on the base image."
$user = Read-Host -Prompt "`nPlease enter your username:"
$cred = Get-Credential $user
$target = Read-Host -Prompt "`nEnter name of computer to check:"
#Tests the connection to the target
Write-Host "`nVerifying connectivity..."
if (!(Test-Connection -quiet $target)) {
    throw "`nFailed to connect to target host $target. Please confirm that the hostname is correct and that the remote host has network connectivity."
}
#Removes any existing session configuration that may conflict with the script
Write-Host "`nChecking for pre-existing session configuration..."
Remove-PSSession -ComputerName $target -ErrorAction Ignore
Invoke-Command -ComputerName $target -Credential $cred -ScriptBlock { Unregister-PSSessionConfiguration -Name appcheck -Force } -ErrorAction Ignore
#Registers session configuration on $target. Needed to bypass second hop problem
Write-Host "`nRegistering session configuration on remote host..."
try {
    Invoke-Command -ComputerName $target -Credential $cred -ScriptBlock { Register-PSSessionConfiguration -Name appcheck -RunAsCredential $using:cred -Force -WarningAction SilentlyContinue} -ErrorAction stop | out-null
}
catch {
    throw "`n$target is reachable, but is not accepting remote commands. Is PowerShell remoting configured on the target?`n"
}
#Starts a remote PowerShell session after 3 seconds. Script fails without a delay.
Write-Host "`nCreating session..."
try {
    Start-Sleep -s 3
    $session = New-PSSession -ComputerName $target -Credential $cred -ConfigurationName appcheck -ErrorAction Stop
}
catch {
    Remove-Connection
    throw "`nThere was an error starting a PowerShell session on the remote host.`n"
}
#Gets list of installed software on the target
Invoke-Command -Session $session -ScriptBlock {Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion | Export-Csv -Path C:\Windows\Temp\apps.csv}
Copy-Item -FromSession $session C:\Windows\Temp\apps.csv -Destination C:\Scripts\Temp\apps.csv
#Compares installed software and reference list from base image
Compare-Object -ReferenceObject $(Get-Content C:\Scripts\baseapps.csv) -DifferenceObject $(Get-Content C:\Scripts\Temp\apps.csv) | Export-Csv C:\Scripts\Temp\appdelta.csv
(Get-Content C:\Scripts\Temp\appdelta.csv).replace('=>', 'Target') | Set-Content C:\Scripts\Temp\appdelta.csv
(Get-Content C:\Scripts\Temp\appdelta.csv).replace('<=', "Base") | Set-Content C:\Scripts\Temp\appdelta.csv
Write-Host "`n64-bit Software:`n"
Import-Csv C:\Scripts\Temp\appdelta.csv | Format-Table -AutoSize
Invoke-Command -Session $session -ScriptBlock {Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion | Export-Csv -Path C:\Windows\Temp\apps32.csv}
Copy-Item -FromSession $session C:\Windows\Temp\apps32.csv -Destination C:\Scripts\Temp\apps32.csv
Compare-Object -ReferenceObject $(Get-Content C:\Scripts\baseapps32.csv) -DifferenceObject $(Get-Content C:\Scripts\Temp\apps32.csv) | Export-Csv C:\Scripts\Temp\appdelta32.csv
(Get-Content C:\Scripts\Temp\appdelta32.csv).replace('=>', 'Target') | Set-Content C:\Scripts\Temp\appdelta32.csv
(Get-Content C:\Scripts\Temp\appdelta32.csv).replace('<=', "Base") | Set-Content C:\Scripts\Temp\appdelta32.csv
Write-Host "`n32-bit Software`n"
Import-Csv C:\Scripts\Temp\appdelta32.csv | Format-Table -AutoSize
Remove-Connection
