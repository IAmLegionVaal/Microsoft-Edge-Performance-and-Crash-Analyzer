#requires -Version 5.1
<# Created by Dewald Pretorius #>
param([string]$OutputPath)
if(-not $OutputPath){$OutputPath="$([Environment]::GetFolderPath('Desktop'))\Edge_Performance_Reports"};New-Item $OutputPath -ItemType Directory -Force|Out-Null
$p=Get-Process msedge -ErrorAction SilentlyContinue
$gpu=Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue|Select-Object Name,DriverVersion,Status
$events=Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue|Where-Object Message -match 'msedge|Microsoft Edge'|Select-Object -First 50 TimeCreated,Id,ProviderName,Message
@('MICROSOFT EDGE PERFORMANCE DIAGNOSTICS','Created by Dewald Pretorius',"Generated: $(Get-Date)","Processes: $($p.Count)","WorkingSetMB: $([math]::Round((($p|Measure-Object WorkingSet -Sum).Sum/1MB),1))",($gpu|Format-Table -AutoSize|Out-String -Width 220),($events|Format-List|Out-String -Width 220),'Guidance: compare a clean profile, review extensions, clear browser cache, test graphics acceleration, and update Edge and display drivers.')|Set-Content (Join-Path $OutputPath 'Report.txt') -Encoding UTF8