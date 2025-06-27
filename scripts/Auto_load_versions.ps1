param (
    [string]$country = 'w1'
)

$ErrorActionPreference = "SilentlyContinue"

function Reorder-CommitsByVersion {
    param (
        [string]$BranchName,
        [string]$Country,
        [version]$NewVersion
    )
    
    Write-Host "Checking if reordering is needed for $Country-$NewVersion on branch $BranchName"
    
    # Get all commits for this country on this branch with their versions
    $commits = git log --pretty=format:"%h|%s" --grep="^$Country-" $BranchName | ForEach-Object {
        $parts = $_.Split('|')
        $hash = $parts[0]
        $message = $parts[1]
        
        # Extract version from commit message
        if ($message -match "^$Country-(.+)$") {
            $versionString = $matches[1]
            try {
                $version = [version]::Parse($versionString)
                return [PSCustomObject]@{
                    Hash = $hash
                    Message = $message
                    Version = $version
                    VersionString = $versionString
                }
            }
            catch {
                Write-Warning "Could not parse version from: $message"
            }
        }
    }
    
    if ($commits.Count -le 1) {
        Write-Host "Only one or no version commits found, no reordering needed"
        return
    }
    
    # Find the newly added commit (should be HEAD)
    $newCommit = $commits | Where-Object { $_.Version -eq $NewVersion } | Select-Object -First 1
    if (-not $newCommit) {
        Write-Host "New commit not found, skipping reordering"
        return
    }
    
    # Check if the new commit is in the wrong position
    $commitsBeforeNew = $commits | Where-Object { $_.Version -gt $NewVersion }
    if ($commitsBeforeNew.Count -eq 0) {
        Write-Host "New commit is already in correct position"
        return
    }
    
    Write-Host "New commit needs to be moved earlier in history"
    Write-Host "Commits that should come after: $($commitsBeforeNew.Count)"
    
    # Find all commits that need to be reordered (new commit + those that should come after it)
    $commitsToReorder = @($newCommit) + $commitsBeforeNew | Sort-Object Version
    $otherCommits = $commits | Where-Object { $_.Version -lt $NewVersion } | Sort-Object Version
    
    # Create backup branch
    $backupBranch = "$BranchName-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git branch $backupBranch
    Write-Host "Created backup branch: $backupBranch"
    
    # Find the base commit (before the commits we need to reorder)
    $baseCommit = if ($otherCommits.Count -gt 0) {
        git log --pretty=format:"%h" -n 1 $otherCommits[-1].Hash
    } else {
        # If no older commits, find the branch point
        git merge-base HEAD~$($commits.Count) HEAD
    }
    
    # Reset to base commit
    git reset --hard $baseCommit
    
    # First, cherry-pick all commits that should stay in order (older versions)
    foreach ($commit in $otherCommits) {
        Write-Host "Re-applying older commit: $($commit.Message)"
        $result = git cherry-pick $commit.Hash 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to cherry-pick $($commit.Hash): $result"
            Write-Host "Restoring from backup branch"
            git reset --hard $backupBranch
            git branch -D $backupBranch
            return
        }
    }
    
    # Then cherry-pick commits in correct version order
    foreach ($commit in $commitsToReorder) {
        Write-Host "Cherry-picking in correct order: $($commit.Message)"
        $result = git cherry-pick $commit.Hash 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to cherry-pick $($commit.Hash): $result"
            Write-Host "Restoring from backup branch"
            git reset --hard $backupBranch
            git branch -D $backupBranch
            return
        }
    }
    
    Write-Host "Successfully reordered commits by version"
    Write-Host "Backup branch $backupBranch can be deleted if everything looks good"
}

[System.Collections.ArrayList]$Versions = @()
Get-BCArtifactUrl -select All -Type Sandbox -country $country -after ([DateTime]::Today.AddDays(-1)) | % {
    [System.Uri]$Url = $_
    $TempString = $Url.AbsolutePath
    [version]$Version = $TempString.Split('/')[2]
    $country = $TempString.Split('/')[3]

    [hashtable]$objectProperty = @{}
    $objectProperty.Add('Version', $Version)
    $objectProperty.Add('Country', $country)
    $objectProperty.Add('URL', $Url)
    $ourObject = New-Object -TypeName psobject -Property $objectProperty

    if ($Version -ge [version]::Parse('23.5.0.0')) {
        $Versions.Add($ourObject)
    }
}

$Versions | Sort-Object -Property Country, Version | % {
    [version]$Version = $_.Version
    $country = $_.Country.Trim()
    Write-Host ($($country)-$($version.ToString()))
    
    git fetch --all

    $LastCommit = git log --all --grep="^$($country)-$($version.ToString())$"

    if ($LastCommit.Length -eq 0) {
        Write-Host "###############################################"
        Write-Host "Processing $($country) - $($Version.ToString())"
        Write-Host "###############################################"
        
        $LatestCommitIDOfBranchEmpty = git log -n 1 --pretty=format:"%h" "main"
        if ($LatestCommitIDOfBranchEmpty -eq $null) {
            $LatestCommitIDOfBranchEmpty = git log -n 1 --pretty=format:"%h" "origin/main"
        }

        if ($Version.Major -gt 15 -and $Version.Build -gt 5) {
            $CommitIDLastCUFromPreviousMajor = git log --all -n 1 --grep="^$($country)-$($version.Major - 1).5" --pretty=format:"%h"
        }
        else {
            $CommitIDLastCUFromPreviousMajor = $null
        }

        $BranchAlreadyExists = ((git branch --list -r "origin/$($country)-$($Version.Major)") -ne $null) -or ((git branch --list "$($country)-$($Version.Major)") -ne $null)

        if ($BranchAlreadyExists) {
            git switch "$($country)-$($Version.Major)"
        }
        else {
            if ($CommitIDLastCUFromPreviousMajor -ne $null) {
                git switch -c "$($country)-$($Version.Major)" $CommitIDLastCUFromPreviousMajor
            }
            else {
                git switch -c "$($country)-$($Version.Major)" $LatestCommitIDOfBranchEmpty                
            }
        }
        
        if ($country -eq 'w1'){
            $Paths = Download-Artifacts -artifactUrl $_.URL -includePlatform
            $LocalizationPath = $Paths[0]
            $PlatformPath = $Paths[1]
        }
        else {
            $Paths = Download-Artifacts -artifactUrl $_.URL
            $LocalizationPath = $Paths
            $PlatformPath = ''
        }

        #Localization folder
        
        $TargetPathOfVersion = (Join-Path $LocalizationPath (Get-ChildItem -Path $LocalizationPath -filter "Applications.$($country.ToUpper())")[0].Name)

        if (-not (Test-Path $TargetPathOfVersion)) {
            #Platform Folder
            $TargetPathOfVersion = (Join-Path $PlatformPath (Get-ChildItem -Path $PlatformPath -filter "Applications")[0].Name)
        }
        
        & "scripts/UpdateALRepo.ps1" -SourcePath $TargetPathOfVersion -RepoPath (Split-Path $PSScriptRoot -Parent) -Version $version -Localization $country
        & "scripts/BuildTestsWorkSpace.ps1"
        
        Get-ChildItem -Recurse -Filter "*.xlf" | Remove-Item

        "$($country)-$($version.ToString())" > version.txt

        git config user.email "stefanmaron@outlook.de"
        git config user.name "Stefan Maron"
        git add -A | out-null
        git commit -a -m "$($country)-$($version.ToString())" | out-null
        git gc | out-null
        
        # Reorder commits by version after each commit
        Reorder-CommitsByVersion -BranchName "$($country)-$($Version.Major)" -Country $country -NewVersion $Version
        
        git pull origin "$($country)-$($Version.Major)"
        git push --set-upstream origin "$($country)-$($Version.Major)" --force-with-lease
        
        Flush-ContainerHelperCache -keepDays 0 -ErrorAction SilentlyContinue

        Write-Host "$($country)-$($version.ToString())"
    }
    else {
        Write-Host "###############################################"
        Write-Host "Skipped version $($country) - $($version.ToString())"
        Write-Host "###############################################"
    }
}


