#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$ClearCache,
    [switch]$ResetProfileSettings,
    [switch]$RepairWebView2,
    [switch]$RestartUpdateServices,
    [switch]$Force,

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = "$env:USERPROFILE\Desktop\EdgeRepair"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$warnings = [System.Collections.Generic.List[string]]::new()
$logPath = $null

function Write-RepairLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN')][string]$Level = 'INFO'
    )

    $entry = '[{0}] [{1}] {2}' -f (Get-Date -Format 's'), $Level, $Message
    Write-Host $entry
    if ($logPath) {
        Add-Content -LiteralPath $logPath -Value $entry -Encoding UTF8
    }
}

function Add-RepairWarning {
    param([Parameter(Mandatory)][string]$Message)

    $warnings.Add($Message)
    Write-RepairLog -Level WARN -Message $Message
}

function Find-WebView2Setup {
    $roots = @(
        ${env:ProgramFiles(x86)},
        $env:ProgramFiles
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($root in $roots) {
        $applicationPath = Join-Path $root 'Microsoft\EdgeWebView\Application'
        if (-not (Test-Path -LiteralPath $applicationPath)) {
            continue
        }

        $setup = Get-ChildItem -LiteralPath $applicationPath -Filter 'setup.exe' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -match '[\\/]Installer$' } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($setup) {
            return $setup.FullName
        }
    }

    return $null
}

try {
    if ($env:OS -ne 'Windows_NT') {
        throw 'This repair requires Windows.'
    }

    if (-not ($ClearCache -or $ResetProfileSettings -or $RepairWebView2 -or $RestartUpdateServices)) {
        throw 'Choose at least one repair action.'
    }

    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    $logPath = Join-Path $OutputPath ('repair-{0:yyyyMMdd-HHmmss}.log' -f (Get-Date))

    $edgeProcesses = @(Get-Process -Name 'msedge' -ErrorAction SilentlyContinue)
    if (($ClearCache -or $ResetProfileSettings) -and $edgeProcesses.Count -gt 0 -and -not $Force) {
        throw 'Close Microsoft Edge or use -Force before changing cache or profile files.'
    }

    if (($ClearCache -or $ResetProfileSettings) -and $edgeProcesses.Count -gt 0 -and $Force) {
        if ($PSCmdlet.ShouldProcess('Microsoft Edge processes', 'Stop before file repair')) {
            $edgeProcesses | Stop-Process -Force -ErrorAction Stop
            Write-RepairLog 'Stopped Microsoft Edge processes.'
        }
    }

    $defaultProfile = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default'

    if ($ClearCache) {
        foreach ($relativePath in 'Cache', 'Code Cache', 'GPUCache') {
            $cachePath = Join-Path $defaultProfile $relativePath
            if (-not (Test-Path -LiteralPath $cachePath)) {
                continue
            }

            if ($PSCmdlet.ShouldProcess($cachePath, 'Clear Microsoft Edge cache contents')) {
                Get-ChildItem -LiteralPath $cachePath -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction Stop
                Write-RepairLog "Cleared '$cachePath'."
            }
        }
    }

    if ($ResetProfileSettings) {
        $preferencesPath = Join-Path $defaultProfile 'Preferences'
        if (Test-Path -LiteralPath $preferencesPath -PathType Leaf) {
            $backupPath = Join-Path $OutputPath ('Preferences.{0:yyyyMMdd-HHmmss}.backup' -f (Get-Date))
            Copy-Item -LiteralPath $preferencesPath -Destination $backupPath -Force -ErrorAction Stop

            if ($PSCmdlet.ShouldProcess($preferencesPath, 'Reset Microsoft Edge preference file')) {
                Remove-Item -LiteralPath $preferencesPath -Force -ErrorAction Stop
                Write-RepairLog "Backed up and removed the preference file. Backup: $backupPath"
            }
        }
        else {
            Add-RepairWarning 'The default-profile Preferences file was not found.'
        }
    }

    if ($RepairWebView2) {
        $setupPath = Find-WebView2Setup
        if (-not $setupPath) {
            throw 'Microsoft Edge WebView2 setup.exe was not found in standard installation paths.'
        }

        if ($PSCmdlet.ShouldProcess('Microsoft Edge WebView2 Runtime', 'Run system-level repair')) {
            $process = Start-Process -FilePath $setupPath `
                -ArgumentList @('--repair', '--msedgewebview', '--system-level', '--verbose-logging') `
                -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) {
                throw "WebView2 repair exited with code $($process.ExitCode)."
            }
            Write-RepairLog 'WebView2 repair completed successfully.'
        }
    }

    if ($RestartUpdateServices) {
        foreach ($serviceName in 'edgeupdate', 'edgeupdatem') {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $service) {
                Add-RepairWarning "Service '$serviceName' is not installed."
                continue
            }

            if ($PSCmdlet.ShouldProcess($serviceName, 'Restart Microsoft Edge update service')) {
                try {
                    if ($service.Status -eq 'Running') {
                        Restart-Service -Name $serviceName -Force -ErrorAction Stop
                    }
                    else {
                        Start-Service -Name $serviceName -ErrorAction Stop
                    }
                    Write-RepairLog "Started or restarted '$serviceName'."
                }
                catch {
                    Add-RepairWarning "Could not restart '$serviceName': $($_.Exception.Message)"
                }
            }
        }
    }

    $warnings | Set-Content -LiteralPath (Join-Path $OutputPath 'warnings.txt') -Encoding UTF8
    if ($warnings.Count -gt 0) {
        Write-RepairLog -Level WARN -Message "Completed with $($warnings.Count) warning(s)."
        exit 2
    }

    Write-RepairLog 'Microsoft Edge repair workflow completed.'
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
