param(
    $Localization = '',
    $Version = '',
    $BuildFolder = '',
    $SourcePath,
    $RepoPath = '',
    [switch]$WhatIf,
    [int]$MaxRetries = 3
)

# Load required assemblies
Add-Type -AssemblyName System.Web

$ErrorActionPreference = "Stop"

function Write-Log {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message"
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites for UpdateALRepo..."
    
    # Check if 7z is available for extraction
    if (-not (Get-Command "7z" -ErrorAction SilentlyContinue)) {
        throw "7z command is not available. Please install 7-Zip."
    }
    
    # Validate parameters
    if ([string]::IsNullOrEmpty($SourcePath)) {
        throw "SourcePath parameter is required"
    }
    
    if ([string]::IsNullOrEmpty($RepoPath)) {
        throw "RepoPath parameter is required"
    }
    
    if (-not (Test-Path $SourcePath)) {
        throw "Source path does not exist: $SourcePath"
    }
    
    if (-not (Test-Path $RepoPath)) {
        throw "Repository path does not exist: $RepoPath"
    }
    
    Write-Log "Prerequisites check passed"
}

function Get-SourceAppFiles {
    param([string]$Path)
    
    try {
        Write-Log "Searching for APP files in: $Path"
        $AppFiles = Get-ChildItem -Path $Path -Filter "*.app" -Recurse
        Write-Log "Found $($AppFiles.Count) APP files to process"
        return $AppFiles
    }
    catch {
        Write-Log "Error searching for APP files: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Copy-AppFiles {
    param(
        [array]$AppFiles,
        [string]$SourcePath,
        [string]$RepoPath
    )
    
    try {
        Write-Log "Copying $($AppFiles.Count) APP files to repository..."
        $CopiedFiles = @()
        
        foreach ($AppFile in $AppFiles) {
            # Calculate relative path from source to determine target structure
            $RelativePath = $AppFile.FullName.Replace($SourcePath, '').TrimStart('\', '/')
            $TargetPath = Join-Path $RepoPath $RelativePath
            $TargetDir = Split-Path $TargetPath -Parent
            
            # Ensure target directory exists
            if (-not (Test-Path $TargetDir)) {
                if (-not $WhatIf) {
                    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
                }
            }
            
            if (-not $WhatIf) {
                Copy-Item -Path $AppFile.FullName -Destination $TargetPath -Force
                
                # Verify copy
                if (-not (Test-Path $TargetPath)) {
                    throw "Copy target file was not created: $TargetPath"
                }
                
                $CopiedFiles += $TargetPath
            }
        }
        
        Write-Log "Successfully copied $($CopiedFiles.Count) APP files"
        return $CopiedFiles
    }
    catch {
        Write-Log "Error copying APP files: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Extract-AppFiles {
    param([array]$AppFilePaths)
    
    try {
        Write-Log "Extracting $($AppFilePaths.Count) APP files..."
        $ExtractedDirs = @()
        
        foreach ($AppFilePath in $AppFilePaths) {
            if (-not (Test-Path $AppFilePath)) {
                Write-Log "APP file not found: $AppFilePath" "WARNING"
                continue
            }
            
            # Create extraction directory (same location as APP file, without .app extension and version)
            $AppFileName = Split-Path $AppFilePath -Leaf
            $CleanAppName = Remove-VersionFromAppName -AppName $AppFileName
            $AppDir = Split-Path $AppFilePath -Parent
            $ExtractionDir = Join-Path $AppDir $CleanAppName
            
            if (-not $WhatIf) {
                # Extract using 7z
                $ExtractionResult = & 7z x $AppFilePath -o"$ExtractionDir" -y 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    throw "7z extraction failed for $AppFileName with exit code $LASTEXITCODE. Output: $ExtractionResult"
                }
                
                # Verify extraction
                if (-not (Test-Path $ExtractionDir)) {
                    throw "Extraction directory was not created: $ExtractionDir"
                }
                
                # Remove the original APP file after successful extraction
                Remove-Item -Path $AppFilePath -Force
                
                $ExtractedDirs += $ExtractionDir
            }
        }
        
        Write-Log "Successfully extracted $($ExtractedDirs.Count) APP files"
        return $ExtractedDirs
    }
    catch {
        Write-Log "Error extracting APP files: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Convert-FoldersToCamelCase {
    param([string]$RootPath)
    
    try {
        Write-Log "Converting folder names to camelCase in: $RootPath"
        
        # Get all directories recursively, process from deepest to shallowest
        $Directories = Get-ChildItem -Path $RootPath -Directory -Recurse | 
            Sort-Object { $_.FullName.Length } -Descending
        
        Write-Log "Found $($Directories.Count) directories to process"
        
        $RenamedCount = 0
        foreach ($Directory in $Directories) {
            $OriginalName = $Directory.Name
            $CamelCaseName = Convert-ToCamelCase -Text $OriginalName
            
            if ($OriginalName -ne $CamelCaseName) {
                $NewPath = Join-Path $Directory.Parent.FullName $CamelCaseName
                
                # Check if target already exists (case-insensitive check)
                if ((Test-Path $NewPath) -and ($Directory.FullName -ne $NewPath)) {
                    Write-Log "Target path already exists, skipping: $NewPath" "WARNING"
                    continue
                }
                
                try {
                    if (-not $WhatIf) {
                        Rename-Item -Path $Directory.FullName -NewName $CamelCaseName -Force
                        $RenamedCount++
                    }
                }
                catch {
                    Write-Log "Failed to rename folder '$OriginalName': $($_.Exception.Message)" "WARNING"
                }
            }
        }
        
        Write-Log "Folder camelCase conversion completed - renamed $RenamedCount folders"
    }
    catch {
        Write-Log "Error converting folders to camelCase: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Convert-ToCamelCase {
    param([string]$Text)
    
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }
    
    # First, URL decode the text to handle cases like "Table%2520Extensions"
    $DecodedText = $Text
    try {
        # Handle double-encoded URLs (e.g., %2520 -> %20 -> space)
        while ($DecodedText -match '%[0-9A-Fa-f]{2}') {
            $PreviousText = $DecodedText
            $DecodedText = [System.Web.HttpUtility]::UrlDecode($DecodedText)
            # Prevent infinite loop if decoding doesn't change the string
            if ($DecodedText -eq $PreviousText) {
                break
            }
        }
    }
    catch {
        Write-Log "Failed to URL decode '$Text', using original: $($_.Exception.Message)" "WARNING"
        $DecodedText = $Text
    }
    
    # Split on common separators and convert to camelCase
    $Words = $DecodedText -split '[_\-\s\.]' | Where-Object { $_ -ne '' }
    
    if ($Words.Count -eq 0) {
        return $DecodedText
    }
    
    # First word is lowercase, subsequent words have first letter uppercase
    $Result = $Words[0].ToString().ToLower()
    
    for ($i = 1; $i -lt $Words.Count; $i++) {
        $Word = $Words[$i]
        if ($Word.Length -gt 0) {
            $Result += $Word.Substring(0, 1).ToString().ToUpper() + $Word.Substring(1).ToLower()
        }
    }
    
    # Handle special cases where the original text is already in a good format
    if ($DecodedText -match '^[a-zA-Z][a-zA-Z0-9]*$') {
        # If it's already a single word with no separators, make it completely lowercase for folder names
        return $DecodedText.ToLower()
    }
    
    return $Result
}

function Clear-TargetDirectories {
    param([string]$RepoPath)
    
    try {
        Write-Log "Clearing existing directories in repository (excluding scripts and .git)"
        
        # Import Git-Operations module if not already loaded
        $GitOpsPath = Join-Path $PSScriptRoot "Git-Operations.psm1"
        if (Test-Path $GitOpsPath) {
            Import-Module $GitOpsPath -Force -Global
        }
        
        # Ensure we're in a clean Git state before clearing directories
        if (-not (Test-GitWorkingDirectoryClean -Path $RepoPath)) {
            Write-Log "Git working directory is not clean, resetting..." "WARNING"
            if (-not $WhatIf) {
                Reset-GitWorkingDirectory -Path $RepoPath -Hard
            }
        }
        
        $DirectoriesToRemove = Get-ChildItem -Path $RepoPath -Directory | 
            Where-Object { $_.Name -notin @('scripts', '.git', '.github') }
        
        foreach ($Dir in $DirectoriesToRemove) {
            if (-not $WhatIf) {
                Remove-Item -Path $Dir.FullName -Recurse -Force
            }
        }
        
        Write-Log "Successfully cleared $($DirectoriesToRemove.Count) directories"
    }
    catch {
        Write-Log "Error clearing target directories: $($_.Exception.Message)" "ERROR"
        throw
    }
}



function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = $script:MaxRetries,
        [string]$OperationName = "Operation"
    )
    
    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            Write-Log "Attempting $OperationName (attempt $attempt/$MaxRetries)"
            $result = & $ScriptBlock
            return $result
        }
        catch {
            Write-Log "$OperationName failed on attempt $attempt`: $($_.Exception.Message)" "WARNING"
            if ($attempt -eq $MaxRetries) {
                Write-Log "$OperationName failed after $MaxRetries attempts" "ERROR"
                throw
            }
            Start-Sleep -Seconds 5
            $attempt++
        }
    }
}

function Get-ProcessingStatistics {
    param([string]$RepoPath)
    
    try {
        $ProcessedDirs = Get-ChildItem -Path $RepoPath -Directory | 
            Where-Object { $_.Name -notin @('scripts', '.git', '.github') }
        
        $TotalFiles = 0
        $TotalSize = 0
        
        foreach ($Dir in $ProcessedDirs) {
            $Files = Get-ChildItem -Path $Dir.FullName -Recurse -File
            $TotalFiles += $Files.Count
            $TotalSize += ($Files | Measure-Object -Property Length -Sum).Sum
        }
        
        Write-Log "Processing statistics:"
        Write-Log "  - Directories created: $($ProcessedDirs.Count)"
        Write-Log "  - Total files processed: $TotalFiles"
        Write-Log "  - Total processed size: $([math]::Round($TotalSize / 1MB, 2)) MB"
    }
    catch {
        Write-Log "Could not calculate processing statistics: $($_.Exception.Message)" "WARNING"
    }
}

function Remove-VersionFromAppName {
    param([string]$AppName)
    
    try {
        # Remove .app extension first
        $NameWithoutExtension = $AppName -replace '\.app$', ''
        
        # Pattern to match version strings like _1.0.0.0, _23.5.16831.17009, etc.
        # This matches underscore followed by version pattern (digits.digits.digits.digits)
        $CleanName = $NameWithoutExtension -replace '_\d+\.\d+\.\d+\.\d+$', ''
        
        # Remove Microsoft_ prefix as it's redundant
        $CleanName = $CleanName -replace '^Microsoft_', ''
        
        return $CleanName
    }
    catch {
        Write-Log "Error cleaning APP name '$AppName': $($_.Exception.Message)" "WARNING"
        # Return original name without extension if cleaning fails
        $CleanedFallback = $AppName -replace '\.app$', '' -replace '^Microsoft_', ''
        return $CleanedFallback
    }
}

# Main execution
try {
    Write-Log "Starting UpdateALRepo script"
    Write-Log "Parameters:"
    Write-Log "  - Localization: $Localization"
    Write-Log "  - Version: $Version"
    Write-Log "  - SourcePath: $SourcePath"
    Write-Log "  - RepoPath: $RepoPath"
    Write-Log "  - WhatIf: $WhatIf"
    
    # Set default source path if not provided
    if ([string]::IsNullOrEmpty($SourcePath)) {
        $SourcePath = "~/.bcartifacts.cache/sandbox/$Version/$Localization/Applications.$($Localization.ToUpper())/"
        Write-Log "Using default source path: $SourcePath"
    }
    
    # Check prerequisites
    Test-Prerequisites
    
    # Import Git-Operations module
    $GitOpsPath = Join-Path $PSScriptRoot "Git-Operations.psm1"
    if (Test-Path $GitOpsPath) {
        Import-Module $GitOpsPath -Force -Global
    } else {
        Write-Log "Git-Operations module not found, some Git features may be limited" "WARNING"
    }
    
    # Verify Git repository state and resolve any conflicts
    if (Get-Command "Test-GitWorkingDirectoryClean" -ErrorAction SilentlyContinue) {
        if (-not (Test-GitWorkingDirectoryClean -Path $RepoPath)) {
            Write-Log "Git repository is not in a clean state, attempting to resolve..." "WARNING"
            if (Get-Command "Resolve-AppFileConflicts" -ErrorAction SilentlyContinue) {
                if (-not (Resolve-AppFileConflicts -Strategy "ours")) {
                    if (-not $WhatIf) {
                        Reset-GitWorkingDirectory -Path $RepoPath -Hard
                    }
                }
            } else {
                Write-Log "Git conflict resolution functions not available, manual intervention may be required" "WARNING"
            }
        }
    }
    
    # Get APP files to process
    $AppFiles = Get-SourceAppFiles -Path $SourcePath
    
    if ($AppFiles.Count -eq 0) {
        Write-Log "No APP files found to process" "WARNING"
        return
    }
    
    # Clear existing directories (with improved conflict handling)
    Clear-TargetDirectories -RepoPath $RepoPath
    
    # Step 1: Copy APP files to repository
    $CopiedAppFiles = Invoke-WithRetry -OperationName "Copy APP files" -ScriptBlock {
        Copy-AppFiles -AppFiles $AppFiles -SourcePath $SourcePath -RepoPath $RepoPath
    }
    
    # Step 2: Extract APP files in place
    if ($CopiedAppFiles.Count -gt 0) {
        $ExtractedDirs = Invoke-WithRetry -OperationName "Extract APP files" -ScriptBlock {
            Extract-AppFiles -AppFilePaths $CopiedAppFiles
        }
        
        # Step 3: Convert folder names to camelCase
        Invoke-WithRetry -OperationName "Convert folders to camelCase" -ScriptBlock {
            Convert-FoldersToCamelCase -RootPath $RepoPath
            return $true
        }
        
        # Final Git state verification
        if (Get-Command "Test-GitWorkingDirectoryClean" -ErrorAction SilentlyContinue) {
            if (-not (Test-GitWorkingDirectoryClean -Path $RepoPath)) {
                Write-Log "Git repository conflicts detected after processing, attempting resolution..." "WARNING"
                if (Get-Command "Resolve-AppFileConflicts" -ErrorAction SilentlyContinue) {
                    if (Resolve-AppFileConflicts -Strategy "ours") {
                        Write-Log "Git conflicts resolved successfully"
                    } else {
                        Write-Log "Warning: Git conflicts remain unresolved. Manual intervention may be required." "WARNING"
                    }
                } else {
                    Write-Log "Warning: Git conflict resolution functions not available. Manual intervention may be required." "WARNING"
                }
            }
        }
    }
    
    Write-Log "Repository update completed successfully"
    
    # Show processing statistics
    if (-not $WhatIf) {
        Get-ProcessingStatistics -RepoPath $RepoPath
    }
}
catch {
    Write-Log "UpdateALRepo script failed: $($_.Exception.Message)" "ERROR"
    throw
}
