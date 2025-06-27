# Auto_load_versions_modular.ps1 - Modular coordinator script

param (
    [string]$country = 'w1',
    [int]$MaxRetries = 3,
    [int]$RetryDelaySeconds = 30,
    [switch]$WhatIf,
    [switch]$SkipPrerequisites,
    [switch]$ProcessOnly,  # Only run processing, skip reorder and push
    [switch]$ReorderOnly,  # Only run reordering phase
    [switch]$PushOnly      # Only run push phase
)

Import-Module (Join-Path $PSScriptRoot "Common-Utils.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Git-Operations.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Artifact-Management.psm1") -Force

$ErrorActionPreference = "Stop"

# Initialize logging
$script:LogFile = "Auto_load_versions_modular_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Invoke-PipelinePhase {
    param(
        [string]$PhaseName,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )
    
    Write-Log "=== Starting Phase: $PhaseName ==="
    
    try {
        # Build parameter array with proper handling for switch parameters
        $ParamArray = @()
        foreach ($Param in $Parameters.GetEnumerator()) {
            # Debug logging to understand parameter types
            Write-Log "Parameter: $($Param.Key) = $($Param.Value) (Type: $($Param.Value.GetType().FullName))"
            
            # Check if this is a known switch parameter or boolean value
            $KnownSwitchParams = @('WhatIf', 'SkipPrerequisites', 'ProcessOnly', 'ReorderOnly', 'PushOnly', 'Force', 'Verbose', 'Debug')
            
            if ($Param.Key -in $KnownSwitchParams -or $Param.Value -is [bool] -or $Param.Value -is [System.Management.Automation.SwitchParameter]) {
                # Handle switch parameters - only add the parameter name if the value is true
                if ($Param.Value -eq $true -or $Param.Value -eq 1) {
                    $ParamArray += "-$($Param.Key)"
                }
                # If false, don't add the parameter at all
            } else {
                # Handle regular parameters with values
                $ParamArray += "-$($Param.Key)"
                $ParamArray += $Param.Value.ToString()
            }
        }
        
        Write-Log "Executing: $ScriptPath with parameters: $($ParamArray -join ' ')"
        
        $Result = & $ScriptPath @ParamArray
        $ExitCode = $LASTEXITCODE
        
        if ($ExitCode -eq 0) {
            Write-Log "=== Phase $PhaseName Completed Successfully ==="
            return $true
        } else {
            Write-Log "=== Phase $PhaseName Failed (Exit Code: $ExitCode) ===" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "=== Phase $PhaseName Failed with Exception ===" "ERROR"
        Write-Log "Error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-VersionsToProcess {
    param([string]$Country)
    
    Write-Log "Getting versions to process for country: $Country"
    
    try {
        $Versions = Get-BCArtifactVersions -Country $Country
        
        if ($Versions.Count -eq 0) {
            Write-Log "No new versions found to process"
            return @()
        }
        
        # Filter out versions that already exist
        git fetch --all 2>$null
        $NewVersions = @()
        
        foreach ($VersionInfo in $Versions) {
            if (-not (Test-GitCommitExists -Country $VersionInfo.Country -Version $VersionInfo.Version)) {
                $NewVersions += $VersionInfo
            } else {
                Write-Log "Version $($VersionInfo.Country)-$($VersionInfo.Version) already exists - skipping"
            }
        }
        
        Write-Log "Found $($NewVersions.Count) new versions to process"
        return $NewVersions
    }
    catch {
        Write-Log "Failed to get versions: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Show-ExecutionSummary {
    param(
        [array]$ProcessedVersions,
        [hashtable]$Results
    )
    
    Write-Log "=== Execution Summary ==="
    Write-Log "Country: $country"
    Write-Log "Total versions processed: $($ProcessedVersions.Count)"
    Write-Log "WhatIf mode: $WhatIf"
    
    $SuccessCount = ($Results.Values | Where-Object { $_ -eq $true }).Count
    $FailureCount = ($Results.Values | Where-Object { $_ -eq $false }).Count
    
    Write-Log "Successful: $SuccessCount"
    Write-Log "Failed: $FailureCount"
    
    if ($FailureCount -gt 0) {
        Write-Log "Failed versions:" "ERROR"
        foreach ($Version in $ProcessedVersions) {
            $Key = "$($Version.Country)-$($Version.Version)"
            if ($Results[$Key] -eq $false) {
                Write-Log "  - $Key" "ERROR"
            }
        }
    }
    
    Write-Log "========================"
}

# Main execution
try {
    Write-Log "Starting Modular Auto_load_versions script for country: $country"
    
    if ($WhatIf) {
        Write-Log "Running in WhatIf mode - no changes will be made"
    }
    
    # Phase 1: Prerequisites Check (unless skipped)
    if (-not $SkipPrerequisites -and -not $ReorderOnly -and -not $PushOnly) {
        $PrereqParams = @{
            WhatIf = $WhatIf
        }
        
        $PrereqResult = Invoke-PipelinePhase -PhaseName "Prerequisites Check" -ScriptPath "scripts/Phase1-CheckPrerequisites.ps1" -Parameters $PrereqParams
        
        if (-not $PrereqResult) {
            throw "Prerequisites check failed"
        }
    }
    
    # Get versions to process (unless only doing reorder/push phases)
    $VersionsToProcess = @()
    if (-not $ReorderOnly -and -not $PushOnly) {
        $VersionsToProcess = Get-VersionsToProcess -Country $country
        
        if ($VersionsToProcess.Count -eq 0) {
            Write-Log "No versions to process - exiting"
            exit 0
        }
    }
    
    # Process versions based on mode
    $Results = @{}
    
    if ($ReorderOnly -or $PushOnly) {
        # For reorder/push only modes, we need to determine which versions to work with
        # This could be enhanced to accept specific versions as parameters
        Write-Log "Operating in $($ReorderOnly ? 'Reorder' : 'Push') only mode"
        Write-Log "Note: Specific version targeting not implemented - would need version parameters"
    } else {
        # Normal processing mode
        foreach ($VersionInfo in $VersionsToProcess) {
            $VersionKey = "$($VersionInfo.Country)-$($VersionInfo.Version)"
            Write-Log "Processing version: $VersionKey"
            
            try {
                # Phase 2: Process Version (unless skipping)
                if (-not $ProcessOnly) {
                    $ProcessParams = @{
                        Country = $VersionInfo.Country
                        Version = $VersionInfo.Version.ToString()
                        ArtifactUrl = $VersionInfo.URL.ToString()
                        MaxRetries = $MaxRetries
                        RetryDelaySeconds = $RetryDelaySeconds
                        WhatIf = $WhatIf
                    }
                    
                    $ProcessResult = Invoke-PipelinePhase -PhaseName "Process Version $VersionKey" -ScriptPath "scripts/Phase2-ProcessVersion.ps1" -Parameters $ProcessParams
                    
                    if (-not $ProcessResult) {
                        $Results[$VersionKey] = $false
                        continue
                    }
                }
                
                # Phase 3: Reorder Commits (unless in WhatIf mode or ProcessOnly)
                if (-not $WhatIf -and -not $ProcessOnly) {
                    $ReorderParams = @{
                        Country = $VersionInfo.Country
                        Version = $VersionInfo.Version.ToString()
                        MaxRetries = $MaxRetries
                        WhatIf = $WhatIf
                    }
                    
                    $ReorderResult = Invoke-PipelinePhase -PhaseName "Reorder Commits $VersionKey" -ScriptPath "scripts/Phase3-ReorderCommits.ps1" -Parameters $ReorderParams
                    
                    if (-not $ReorderResult) {
                        Write-Log "Reorder failed for $VersionKey - continuing with push" "WARNING"
                    }
                }
                
                # Phase 4: Push Changes (unless in WhatIf mode or ProcessOnly)
                if (-not $WhatIf -and -not $ProcessOnly) {
                    $PushParams = @{
                        Country = $VersionInfo.Country
                        Version = $VersionInfo.Version.ToString()
                        MaxRetries = $MaxRetries
                        WhatIf = $WhatIf
                    }
                    
                    $PushResult = Invoke-PipelinePhase -PhaseName "Push Changes $VersionKey" -ScriptPath "scripts/Phase4-PushChanges.ps1" -Parameters $PushParams
                    
                    if (-not $PushResult) {
                        $Results[$VersionKey] = $false
                        continue
                    }
                }
                
                $Results[$VersionKey] = $true
                Write-Log "Successfully completed processing for $VersionKey"
                
            }
            catch {
                Write-Log "Failed to process $VersionKey`: $($_.Exception.Message)" "ERROR"
                $Results[$VersionKey] = $false
            }
        }
    }
    
    # Show summary
    if ($VersionsToProcess.Count -gt 0) {
        Show-ExecutionSummary -ProcessedVersions $VersionsToProcess -Results $Results
        
        $FailureCount = ($Results.Values | Where-Object { $_ -eq $false }).Count
        if ($FailureCount -gt 0) {
            exit 1
        }
    }
    
    Write-Log "Modular script execution completed successfully"
}
catch {
    Write-Log "Modular script execution failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
finally {
    Write-Log "Script execution completed. Log file: $script:LogFile"
}
