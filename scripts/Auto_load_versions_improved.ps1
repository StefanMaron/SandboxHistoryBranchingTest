param (
    [string]$country = 'w1',
    [int]$MaxRetries = 3,
    [int]$RetryDelaySeconds = 30,
    [switch]$WhatIf
)

# Strict error handling
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Initialize logging
$LogFile = "Auto_load_versions_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

function Initialize-BcContainerHelper {
    Write-Log "Initializing BC Container Helper environment..."
    
    try {
        # Import module
        Import-Module BcContainerHelper -Force
        
        # Initialize configuration
        $Global:bcContainerHelperConfig = Get-BcContainerHelperConfig
        
        # Initialize app manifest if not exists
        if (-not (Get-Variable -Name 'appManifest' -Scope Global -ErrorAction SilentlyContinue)) {
            $Global:appManifest = @{}
        }
        
        # Set up telemetry correlation ID if needed
        if (-not (Get-Variable -Name 'telemetryCorrelationId' -Scope Global -ErrorAction SilentlyContinue)) {
            $Global:telemetryCorrelationId = [System.Guid]::NewGuid().ToString()
        }
        
        Write-Log "BC Container Helper environment initialized successfully"
    }
    catch {
        Write-Log "Failed to initialize BC Container Helper: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Test-GitRepository {
    try {
        git status | Out-Null
        return $true
    }
    catch {
        Write-Log "Not in a git repository or git is not available" "ERROR"
        return $false
    }
}

function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = $script:MaxRetries,
        [int]$DelaySeconds = $script:RetryDelaySeconds,
        [string]$OperationName = "Operation"
    )
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            Write-Log "Attempting $OperationName (attempt $attempt/$MaxRetries)"
            $result = & $ScriptBlock
            Write-Log "$OperationName completed successfully"
            return $result
        }
        catch {
            Write-Log "$OperationName failed on attempt $attempt`: $($_.Exception.Message)" "WARNING"
            if ($attempt -eq $MaxRetries) {
                Write-Log "$OperationName failed after $MaxRetries attempts" "ERROR"
                throw
            }
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check if we're in a git repository
    if (-not (Test-GitRepository)) {
        throw "Must be run from within a git repository"
    }
    
    # Check required PowerShell modules
    $RequiredModules = @('BcContainerHelper')
    foreach ($Module in $RequiredModules) {
        if (-not (Get-Module -ListAvailable -Name $Module)) {
            throw "Required PowerShell module '$Module' is not installed"
        }
    }
    
    # Check external dependencies
    $RequiredCommands = @('git')
    foreach ($Command in $RequiredCommands) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required command '$Command' is not available in PATH"
        }
    }
    
    Write-Log "Prerequisites check completed successfully"
}

function Get-ArtifactVersions {
    param([string]$Country)
    
    Write-Log "Fetching artifact versions for country: $Country"
    
    try {
        $Versions = [System.Collections.ArrayList]@()
        $Yesterday = [DateTime]::Today.AddDays(-1)
        
        $Artifacts = Invoke-WithRetry -OperationName "Get-BCArtifactUrl" -ScriptBlock {
            Get-BCArtifactUrl -select All -Type Sandbox -country $Country -after $Yesterday
        }
        
        foreach ($ArtifactUrl in $Artifacts) {
            try {
                [System.Uri]$Url = $ArtifactUrl
                $PathParts = $Url.AbsolutePath.Split('/')
                
                if ($PathParts.Length -ge 4) {
                    [version]$Version = $PathParts[2]
                    $CountryCode = $PathParts[3]
                    
                    if ($Version -ge [version]::Parse('23.5.0.0')) {
                        $VersionObject = [PSCustomObject]@{
                            Version = $Version
                            Country = $CountryCode
                            URL = $Url
                        }
                        $Versions.Add($VersionObject) | Out-Null
                    }
                }
            }
            catch {
                Write-Log "Failed to parse artifact URL: $ArtifactUrl - $($_.Exception.Message)" "WARNING"
            }
        }
        
        Write-Log "Found $($Versions.Count) valid versions for processing"
        return $Versions | Sort-Object -Property Country, Version
    }
    catch {
        Write-Log "Failed to fetch artifact versions: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Test-CommitExists {
    param(
        [string]$Country,
        [version]$Version
    )
    
    $CommitMessage = "$Country-$($Version.ToString())"
    try {
        # Use the same pattern as the original script
        $ExistingCommit = git log --all --grep="^$CommitMessage$" 2>$null
        return $ExistingCommit.Length -gt 0
    }
    catch {
        return $false
    }
}

function Backup-CurrentState {
    param([string]$BranchName)
    
    $BackupBranch = "$BranchName-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    try {
        git branch $BackupBranch 2>$null
        Write-Log "Created backup branch: $BackupBranch"
        return $BackupBranch
    }
    catch {
        Write-Log "Failed to create backup branch: $($_.Exception.Message)" "WARNING"
        return $null
    }
}

function Restore-FromBackup {
    param(
        [string]$BackupBranch,
        [string]$TargetBranch
    )
    
    if ([string]::IsNullOrEmpty($BackupBranch)) {
        return
    }
    
    try {
        Write-Log "Restoring from backup branch: $BackupBranch"
        git switch $TargetBranch 2>$null
        git reset --hard $BackupBranch 2>$null
        git branch -D $BackupBranch 2>$null
        Write-Log "Successfully restored from backup"
    }
    catch {
        Write-Log "Failed to restore from backup: $($_.Exception.Message)" "ERROR"
    }
}

function Reorder-CommitsByVersion {
    param (
        [string]$BranchName,
        [string]$Country,
        [version]$NewVersion
    )
    
    Write-Log "Checking if commit reordering is needed for $Country-$NewVersion on branch $BranchName"
    
    try {
        # Get all commits for this country on this branch with their versions
        $CommitLines = git log --pretty=format:"%h|%s" --grep="^$Country-" $BranchName 2>$null
        if (-not $CommitLines) {
            Write-Log "No existing commits found for reordering"
            return
        }
        
        $Commits = @()
        foreach ($Line in $CommitLines) {
            $Parts = $Line.Split('|', 2)
            if ($Parts.Length -ge 2) {
                $Hash = $Parts[0]
                $Message = $Parts[1]
                
                if ($Message -match "^$Country-(.+)$") {
                    $VersionString = $matches[1]
                    try {
                        $Version = [version]::Parse($VersionString)
                        $Commits += [PSCustomObject]@{
                            Hash = $Hash
                            Message = $Message
                            Version = $Version
                            VersionString = $VersionString
                        }
                    }
                    catch {
                        Write-Log "Could not parse version from commit: $Message" "WARNING"
                    }
                }
            }
        }
        
        if ($Commits.Count -le 1) {
            Write-Log "Only one or no version commits found, no reordering needed"
            return
        }
        
        # Find the newly added commit (should be HEAD)
        $NewCommit = $Commits | Where-Object { $_.Version -eq $NewVersion } | Select-Object -First 1
        if (-not $NewCommit) {
            Write-Log "New commit not found, skipping reordering"
            return
        }
        
        # Check if the new commit is in the wrong position
        $CommitsBeforeNew = $Commits | Where-Object { $_.Version -gt $NewVersion }
        if ($CommitsBeforeNew.Count -eq 0) {
            Write-Log "New commit is already in correct position"
            return
        }
        
        Write-Log "New commit needs to be moved earlier in history"
        Write-Log "Commits that should come after: $($CommitsBeforeNew.Count)"
        
        # Find all commits that need to be reordered (new commit + those that should come after it)
        $CommitsToReorder = @($NewCommit) + $CommitsBeforeNew | Sort-Object Version
        $OtherCommits = $Commits | Where-Object { $_.Version -lt $NewVersion } | Sort-Object Version
        
        # Create backup branch
        $BackupBranch = "$BranchName-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        git branch $BackupBranch 2>$null
        Write-Log "Created backup branch: $BackupBranch"
        
        try {
            # Find the base commit (before the commits we need to reorder)
            $BaseCommit = if ($OtherCommits.Count -gt 0) {
                git log --pretty=format:"%h" -n 1 $OtherCommits[-1].Hash 2>$null
            } else {
                # If no older commits, find the branch point
                git merge-base HEAD~$($Commits.Count) HEAD 2>$null
            }
            
            # Reset to base commit
            git reset --hard $BaseCommit 2>$null
            
            # First, cherry-pick all commits that should stay in order (older versions)
            foreach ($Commit in $OtherCommits) {
                Write-Log "Re-applying older commit: $($Commit.Message)"
                $Result = git cherry-pick $Commit.Hash 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to cherry-pick $($Commit.Hash): $Result"
                }
            }
            
            # Then cherry-pick commits in correct version order
            foreach ($Commit in $CommitsToReorder) {
                Write-Log "Cherry-picking in correct order: $($Commit.Message)"
                $Result = git cherry-pick $Commit.Hash 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to cherry-pick $($Commit.Hash): $Result"
                }
            }
            
            Write-Log "Successfully reordered commits by version"
            Write-Log "Backup branch $BackupBranch can be deleted if everything looks good"
        }
        catch {
            Write-Log "Commit reordering failed: $($_.Exception.Message)" "ERROR"
            Write-Log "Restoring from backup branch"
            git reset --hard $BackupBranch 2>$null
            git branch -D $BackupBranch 2>$null
            throw
        }
    }
    catch {
        Write-Log "Error during commit reordering: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Process-Version {
    param(
        [PSCustomObject]$VersionInfo
    )
    
    $Version = $VersionInfo.Version
    $Country = $VersionInfo.Country.Trim()
    $ArtifactUrl = $VersionInfo.URL
    
    Write-Log "Starting processing of $Country-$($Version.ToString())"
    
    try {
        # Determine branch strategy
        $BranchName = "$Country-$($Version.Major)"
        $BranchAlreadyExists = ((git branch --list -r "origin/$BranchName" 2>$null) -ne $null) -or ((git branch --list "$BranchName" 2>$null) -ne $null)
        
        if ($BranchAlreadyExists) {
            git switch $BranchName 2>$null
        } else {
            # Create new branch from appropriate base
            $BaseCommit = Get-BaseCommitForNewBranch -Country $Country -Version $Version
            git switch -c $BranchName $BaseCommit 2>$null
        }
        
        # Download artifacts
        $ExtractedPaths = Download-ArtifactsCustom -ArtifactUrl $ArtifactUrl -Country $Country
        
        if (-not $ExtractedPaths) {
            throw "Failed to download artifacts"
        }
        
        Write-Log "Downloaded paths: $($ExtractedPaths -join ', ')"

        # Update repository with new version (this will handle extraction and camelCase conversion)
        Update-RepositoryWithVersion -ExtractedPaths $ExtractedPaths -Version $Version -Country $Country
        
        # Create commit
        Create-VersionCommit -Country $Country -Version $Version
        
        # Reorder commits if necessary
        if (-not $WhatIf) {
            Reorder-CommitsByVersion -BranchName $BranchName -Country $Country -NewVersion $Version
        }
        
        # Push changes
        if (-not $WhatIf) {
            Push-Changes -BranchName $BranchName
        }
        
        # # Cleanup - make this optional and non-blocking (same as original script)
        # Write-Log "Attempting container cache cleanup"
        # $OriginalErrorPreference = $ErrorActionPreference
        # $ErrorActionPreference = "SilentlyContinue"
        # try {
        #     Flush-ContainerHelperCache -keepDays 0
        # }
        # finally {
        #     $ErrorActionPreference = $OriginalErrorPreference
        # }
        
        Write-Log "Successfully processed $Country-$($Version.ToString())"
        return $true
    }
    catch {
        Write-Log "Failed to process $Country-$($Version.ToString()): $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-BaseCommitForNewBranch {
    param(
        [string]$Country,
        [version]$Version
    )
    
    # Logic to determine the appropriate base commit for a new branch (same as original script)
    $LatestCommitIDOfBranchEmpty = git log -n 1 --pretty=format:"%h" "main" 2>$null
    if ($LatestCommitIDOfBranchEmpty -eq $null) {
        $LatestCommitIDOfBranchEmpty = git log -n 1 --pretty=format:"%h" "origin/main" 2>$null
    }

    if ($Version.Major -gt 15 -and $Version.Build -gt 5) {
        $CommitIDLastCUFromPreviousMajor = git log --all -n 1 --grep="^$Country-$($Version.Major - 1).5" --pretty=format:"%h" 2>$null
        if ($CommitIDLastCUFromPreviousMajor -ne $null) {
            return $CommitIDLastCUFromPreviousMajor
        }
    }
    
    return $LatestCommitIDOfBranchEmpty
}

function Download-ArtifactsCustom {
    param(
        [System.Uri]$ArtifactUrl,
        [string]$Country
    )
    
    try {
        Write-Log "Downloading artifacts from: $ArtifactUrl"
        Write-Log "Country: $Country"

        # Ensure BC Container Helper variables are properly initialized
        if (-not (Get-Variable -Name 'appManifest' -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Log "Initializing missing appManifest variable"
            $Global:appManifest = @{}
        }
        
        # Set additional variables that might be expected by Download-Artifacts
        if (-not (Get-Variable -Name 'bcContainerHelperConfig' -Scope Global -ErrorAction SilentlyContinue)) {
            Write-Log "Initializing missing bcContainerHelperConfig variable"
            $Global:bcContainerHelperConfig = Get-BcContainerHelperConfig
        }

        # Log current module state for debugging
        $Module = Get-Module BcContainerHelper
        if ($Module) {
            Write-Log "BC Container Helper module version: $($Module.Version)"
        } else {
            Write-Log "BC Container Helper module not loaded" "WARNING"
        }

        $DownloadResult = Invoke-WithRetry -OperationName "Download artifacts" -ScriptBlock {
            Download-Artifacts -artifactUrl $ArtifactUrl
        }
        
        Write-Log "Artifacts downloaded successfully"
        return $DownloadResult
    }
    catch {
        Write-Log "Failed to download artifacts: $($_.Exception.Message)" "ERROR"
        Write-Log "Full exception details: $($_.Exception | Format-List -Force | Out-String)" "ERROR"
        throw
    }
}

function Update-RepositoryWithVersion {
    param(
        $ExtractedPaths,
        [version]$Version,
        [string]$Country
    )
    
    try {
        if ($Country -eq 'w1') {
            $LocalizationPath = $ExtractedPaths[0]
            $PlatformPath = $ExtractedPaths[1]
        } else {
            $LocalizationPath = $ExtractedPaths
            $PlatformPath = ''
        }
        
        # Find target path
        $TargetPath = $null
        $LocalizationTarget = Join-Path $LocalizationPath extensions
        $LocalizationDir = Get-ChildItem -Path $LocalizationPath -Filter extensions -Directory | Select-Object -First 1

        Write-Log "Localization Target: $LocalizationTarget"

        if ($LocalizationDir) {
            $TargetPath = $LocalizationDir.FullName
        } elseif ($PlatformPath) {
            $PlatformDir = Get-ChildItem -Path $PlatformPath -Filter "applications" -Directory | Select-Object -First 1
            if ($PlatformDir) {
                $TargetPath = $PlatformDir.FullName
            }
        }
        
        if (-not $TargetPath -or -not (Test-Path $TargetPath)) {
            throw "Could not find valid target path for extensions"
        }
        
        Write-Log "Using target path: $TargetPath"
        
        # Update repository
        $RepoPath = Split-Path $PSScriptRoot -Parent
        & "scripts/UpdateALRepo_improved.ps1" -SourcePath $TargetPath -RepoPath $RepoPath -Version $Version -Localization $Country
        & "scripts/BuildTestsWorkSpace_improved.ps1"
        
        # Remove translation files to save space
        Get-ChildItem -Recurse -Filter "*.xlf" | Remove-Item -Force -ErrorAction SilentlyContinue
        
        Write-Log "Repository updated successfully with version $($Version.ToString())"
    }
    catch {
        Write-Log "Failed to update repository: $($_.Exception.Message)" "ERROR"
        Write-Log "Error details - Country: $Country, Version: $($Version.ToString())" "ERROR"
        Write-Log "Target path used: $TargetPath" "ERROR"
        Write-Log "Repository path: $RepoPath" "ERROR"
        Write-Log "Localization path: $LocalizationPath" "ERROR"
        if ($PlatformPath) {
            Write-Log "Platform path: $PlatformPath" "ERROR"
        }
        Write-Log "Full error stack trace: $($_.ScriptStackTrace)" "ERROR"
        throw
    }
}

function Create-VersionCommit {
    param(
        [string]$Country,
        [version]$Version
    )
    
    try {
        # Create version file
        "$Country-$($Version.ToString())" | Out-File "version.txt" -Encoding utf8
        
        # Configure git user
        git config user.email "stefanmaron@outlook.de" 2>$null
        git config user.name "Stefan Maron" 2>$null
        
        # Stage and commit changes
        git add -A 2>$null
        $CommitMessage = "$Country-$($Version.ToString())"
        git commit -m $CommitMessage 2>$null
        
        # Garbage collection to keep repository clean
        git gc --quiet 2>$null
        
        Write-Log "Created commit: $CommitMessage"
    }
    catch {
        Write-Log "Failed to create commit: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Push-Changes {
    param([string]$BranchName)
    
    try {
        # Pull latest changes first
        git pull origin $BranchName --ff-only 2>$null
        
        # Push with lease to prevent accidental overwrites
        git push --set-upstream origin $BranchName --force-with-lease 2>$null
        
        Write-Log "Successfully pushed changes to branch: $BranchName"
    }
    catch {
        Write-Log "Failed to push changes: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Main execution
try {
    Write-Log "Starting Auto_load_versions script for country: $country"
    
    if ($WhatIf) {
        Write-Log "Running in WhatIf mode - no changes will be made"
    }
    
    # Initialize BC Container Helper environment
    Initialize-BcContainerHelper
    
    # Check prerequisites
    Test-Prerequisites
    
    # Get versions to process
    $Versions = Get-ArtifactVersions -Country $country
    
    if ($Versions.Count -eq 0) {
        Write-Log "No new versions found to process"
        exit 0
    }
    
    Write-Log "Found $($Versions.Count) versions to process"
    
    # Process each version
    $SuccessCount = 0
    $FailureCount = 0
    $SkippedCount = 0
    
    foreach ($VersionInfo in $Versions) {
        $Version = $VersionInfo.Version
        $Country = $VersionInfo.Country.Trim()
        
        # Check if version already exists (same logic as original script)
        git fetch --all 2>$null
        $LastCommit = git log --all --grep="^$Country-$($Version.ToString())$" 2>$null
        
        if ($LastCommit.Length -eq 0) {
            Write-Log "Processing $Country - $($Version.ToString())"
            
            try {
                if (Process-Version -VersionInfo $VersionInfo) {
                    $SuccessCount++
                } else {
                    $FailureCount++
                }
            }
            catch {
                Write-Log "Unexpected error processing version: $($_.Exception.Message)" "ERROR"
                $FailureCount++
            }
        }
        else {
            Write-Log "Skipped version $Country - $($Version.ToString())"
            $SkippedCount++
        }
    }
    
    Write-Log "Processing completed. Success: $SuccessCount, Failures: $FailureCount, Skipped: $SkippedCount"
    
    if ($FailureCount -gt 0) {
        exit 1
    }
}
catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
finally {
    Write-Log "Script execution completed. Log file: $LogFile"
}
