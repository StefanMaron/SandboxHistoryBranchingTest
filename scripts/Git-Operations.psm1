# Git-Operations PowerShell Module
# Provides Git operations for BC Sandbox Code History automation

function Test-GitWorkingDirectoryClean {
    <#
    .SYNOPSIS
    Tests if the Git working directory is clean (no uncommitted changes).
    
    .PARAMETER Path
    The path to the Git repository.
    
    .RETURNS
    $true if the working directory is clean, $false otherwise.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        Push-Location $Path
        
        # Check if we're in a Git repository
        $gitStatus = git status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Not a Git repository or Git not available: $Path"
            return $true  # Assume clean if not a Git repo
        }
        
        # If git status --porcelain returns empty, working directory is clean
        return [string]::IsNullOrWhiteSpace($gitStatus)
    }
    catch {
        Write-Warning "Error checking Git status: $($_.Exception.Message)"
        return $true  # Assume clean on error
    }
    finally {
        Pop-Location
    }
}

function Reset-GitWorkingDirectory {
    <#
    .SYNOPSIS
    Resets the Git working directory to a clean state.
    
    .PARAMETER Path
    The path to the Git repository.
    
    .PARAMETER Hard
    Perform a hard reset (discard all changes).
    
    .RETURNS
    $true if successful, $false otherwise.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$Hard
    )
    
    try {
        Push-Location $Path
        
        # Check if we're in a Git repository
        git status >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Not a Git repository: $Path"
            return $false
        }
        
        if ($Hard) {
            # Hard reset to HEAD
            Write-Host "Performing hard reset to HEAD..."
            git reset --hard HEAD
            if ($LASTEXITCODE -eq 0) {
                # Clean untracked files and directories
                git clean -fd
                return $LASTEXITCODE -eq 0
            }
        } else {
            # Soft reset - just unstage changes
            git reset HEAD
            return $LASTEXITCODE -eq 0
        }
        
        return $false
    }
    catch {
        Write-Warning "Error resetting Git working directory: $($_.Exception.Message)"
        return $false
    }
    finally {
        Pop-Location
    }
}

function Resolve-AppFileConflicts {
    <#
    .SYNOPSIS
    Resolves Git conflicts using the specified strategy.
    
    .PARAMETER Strategy
    The merge strategy to use ("ours" or "theirs").
    
    .RETURNS
    $true if conflicts were resolved, $false otherwise.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("ours", "theirs")]
        [string]$Strategy
    )
    
    try {
        # Check if there are any merge conflicts
        $conflictFiles = git diff --name-only --diff-filter=U 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($conflictFiles)) {
            # No conflicts to resolve
            return $true
        }
        
        Write-Host "Resolving Git conflicts using '$Strategy' strategy..."
        
        # Resolve conflicts using the specified strategy
        if ($Strategy -eq "ours") {
            git checkout --ours . 2>$null
        } else {
            git checkout --theirs . 2>$null
        }
        
        if ($LASTEXITCODE -eq 0) {
            # Add resolved files
            git add . 2>$null
            return $LASTEXITCODE -eq 0
        }
        
        return $false
    }
    catch {
        Write-Warning "Error resolving Git conflicts: $($_.Exception.Message)"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Test-GitWorkingDirectoryClean, Reset-GitWorkingDirectory, Resolve-AppFileConflicts
