# Microsoft Edge Performance and Crash Analyzer

Created by **Dewald Pretorius**.

The repository includes the original diagnostics and a guarded `Repair.ps1` helper.

Supported actions:

- `Diagnose`
- `ResetPerformanceCaches`
- `FlushDns`

```powershell
.\Repair.ps1 -Action Diagnose
.\Repair.ps1 -Action ResetPerformanceCaches -WhatIf
.\Repair.ps1 -Action ResetPerformanceCaches -Confirm
```

Close Edge before cache repair. Existing cache data is preserved as timestamped backups. Source-reviewed for PowerShell 5.1; not runtime-tested against every Edge build.
