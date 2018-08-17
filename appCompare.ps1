Write-Host "`nThis script will get a list of installed software that is not included on the base image."
$cred = Get-Credential
$target = Read-Host -Prompt "`nEnter name of computer to check"
#Tests the connection to the target
Write-Host "`nVerifying connectivity..."
if (!(Test-Connection -quiet $target)) {
    throw "`nFailed to connect to target host $target. Please confirm that the hostname is correct and that the remote host has network connectivity."
}

#Starts a remote PowerShell session.
Write-Host "`nCreating session..."
try {
    $session = New-PSSession -ComputerName $target -Credential $cred
}
catch {
    throw "`nThere was an error starting a PowerShell session on the remote host.`n"
}
#Gets list of installed software on the target
Invoke-Command -Session $session -ScriptBlock {Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*  | Where-Object {$_.DisplayName -notmatch ".*KB[0-9]{6,}"} | Select-Object DisplayName, DisplayVersion | Export-Csv -Path C:\Windows\Temp\apps.csv}
Copy-Item -FromSession $session C:\Windows\Temp\apps.csv -Destination C:\Scripts\Temp\apps.csv
#Compares installed software and reference list from base image
Compare-Object -ReferenceObject $(Get-Content C:\Scripts\csv\baseappsver.csv) -DifferenceObject $(Get-Content C:\Scripts\Temp\apps.csv) | Export-Csv C:\Scripts\Temp\appdelta.csv
(Get-Content C:\Scripts\Temp\appdelta.csv).replace('=>', 'Target') | Set-Content C:\Scripts\Temp\appdelta.csv
(Get-Content C:\Scripts\Temp\appdelta.csv).replace('<=', "Base") | Set-Content C:\Scripts\Temp\appdelta.csv
Write-Host "`n64-bit Software:`n"
Import-Csv C:\Scripts\Temp\appdelta.csv | Format-Table -AutoSize
Invoke-Command -Session $session -ScriptBlock {Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -notmatch ".*KB[0-9]{6,}"} | Select-Object DisplayName, DisplayVersion | Export-Csv -Path C:\Windows\Temp\apps32.csv}
Copy-Item -FromSession $session C:\Windows\Temp\apps32.csv -Destination C:\Scripts\Temp\apps32.csv
Compare-Object -ReferenceObject $(Get-Content C:\Scripts\csv\baseapps32ver.csv) -DifferenceObject $(Get-Content C:\Scripts\Temp\apps32.csv) | Export-Csv C:\Scripts\Temp\appdelta32.csv
(Get-Content C:\Scripts\Temp\appdelta32.csv).replace('=>', 'Target') | Set-Content C:\Scripts\Temp\appdelta32.csv
(Get-Content C:\Scripts\Temp\appdelta32.csv).replace('<=', "Base") | Set-Content C:\Scripts\Temp\appdelta32.csv
Write-Host "`n32-bit Software:`n"
Import-Csv C:\Scripts\Temp\appdelta32.csv | where-object {$_.InputObject -notmatch "^.?$"} | Format-Table -AutoSize