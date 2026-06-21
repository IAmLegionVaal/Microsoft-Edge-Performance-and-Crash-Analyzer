#requires -Version 5.1
<# Created by Dewald Pretorius. #>
[CmdletBinding(SupportsShouldProcess=$true)]
param([ValidateSet('Diagnose','ResetPerformanceCaches','FlushDns')][string]$Action='Diagnose',[string]$OutputPath=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'Edge_Performance_Repair'))
$ErrorActionPreference='Stop';$cachePaths=@("$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache","$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache","$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache")
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null;$stamp=Get-Date -Format yyyyMMdd_HHmmss;$log=Join-Path $OutputPath "Repair_$stamp.log";function Log($m){$l='{0:u} {1}'-f(Get-Date),$m;Write-Host $l;Add-Content $log $l}
[ordered]@{Action=$Action;EdgeProcesses=@(Get-Process msedge -ErrorAction SilentlyContinue|Select-Object Name,Id,WorkingSet,CPU);Caches=@($cachePaths|ForEach-Object{[pscustomobject]@{Path=$_;Exists=Test-Path $_}})}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutputPath "PreRepair_$stamp.json")
if($Action -eq 'Diagnose'){Log '[COMPLETE] Snapshot saved.';exit 0}
try{if($Action -eq 'ResetPerformanceCaches' -and $PSCmdlet.ShouldProcess('Microsoft Edge performance caches','Back up and reset')){if(Get-Process msedge -ErrorAction SilentlyContinue){throw 'Close Microsoft Edge before resetting caches.'};foreach($path in $cachePaths){if(Test-Path $path){$backup="$path.backup-$stamp";Move-Item $path $backup -Force;New-Item -ItemType Directory $path -Force|Out-Null;Log "[BACKUP] $backup"}}}
elseif($Action -eq 'FlushDns' -and $PSCmdlet.ShouldProcess('Windows DNS client cache','Clear')){Clear-DnsClientCache}}catch{Log "[FAILED] $($_.Exception.Message)";exit 5};Log '[COMPLETE] Repair completed.';exit 0
