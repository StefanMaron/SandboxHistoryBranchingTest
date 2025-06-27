param(
    [string]$OutputPath = "test-apps.code-workspace",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message"
}

function Find-TestDirectories {
    param([string]$RootPath = ".")
    
    try {
        Write-Log "Searching for test directories..."
        
        # Find all directories with 'test' in the name (case-insensitive)
        $TestDirectories = Get-ChildItem -Directory -Filter "*test*" -Recurse -ErrorAction SilentlyContinue
        
        Write-Log "Found $($TestDirectories.Count) potential test directories"
        
        # Filter to only include leaf test directories (no test subdirectories)
        $LeafTestDirectories = @()
        
        foreach ($TestDir in $TestDirectories) {
            try {
                # Check if this directory has any test subdirectories
                $TestSubDirs = Get-ChildItem -Path $TestDir.FullName -Directory -Filter "*test*" -ErrorAction SilentlyContinue
                
                if ($TestSubDirs.Count -eq 0) {
                    # This is a leaf test directory
                    $RelativePath = Get-Item $TestDir.FullName | Resolve-Path -Relative -ErrorAction SilentlyContinue
                    if ($RelativePath) {
                        $LeafTestDirectories += $RelativePath
                        Write-Log "Added test directory: $RelativePath"
                    }
                }
            }
            catch {
                Write-Log "Error processing directory $($TestDir.FullName): $($_.Exception.Message)" "WARNING"
            }
        }
        
        Write-Log "Identified $($LeafTestDirectories.Count) leaf test directories"
        return $LeafTestDirectories
    }
    catch {
        Write-Log "Error finding test directories: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Build-WorkspaceConfiguration {
    param([array]$TestDirectories)
    
    try {
        Write-Log "Building VS Code workspace configuration..."
        
        # Create workspace folders array
        $WorkspaceFolders = @()
        foreach ($DirPath in $TestDirectories) {
            $WorkspaceFolders += @{
                "path" = $DirPath
            }
        }
        
        # Create workspace configuration
        $WorkspaceConfig = @{
            "folders" = $WorkspaceFolders
            "settings" = @{
                "al.enableCodeActions" = $false
                "al.enableCodeAnalysis" = $false
                "search.exclude" = @{
                    "**/*.xlf" = $true
                }
            }
        }
        
        # Add AL-specific settings if available
        try {
            # Check if allint extension settings should be included
            $WorkspaceConfig.settings["al.enableCodeCop"] = $false
            $WorkspaceConfig.settings["al.enableUICop"] = $false
            $WorkspaceConfig.settings["al.ruleSetPath"] = ""
            
            # Performance optimizations
            $WorkspaceConfig.settings["files.watcherExclude"] = @{
                "**/.git/**" = $true
                "**/node_modules/**" = $true
                "**/*.xlf" = $true
            }
            
            $WorkspaceConfig.settings["search.useIgnoreFiles"] = $true
            $WorkspaceConfig.settings["search.useGlobalIgnoreFiles"] = $true
            
        }
        catch {
            Write-Log "Could not add extended AL settings: $($_.Exception.Message)" "WARNING"
        }
        
        Write-Log "Workspace configuration built successfully"
        Write-Log "  - Folders: $($WorkspaceFolders.Count)"
        Write-Log "  - Settings: $($WorkspaceConfig.settings.Count)"
        
        return $WorkspaceConfig
    }
    catch {
        Write-Log "Error building workspace configuration: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Save-WorkspaceFile {
    param(
        [hashtable]$WorkspaceConfig,
        [string]$OutputPath
    )
    
    try {
        Write-Log "Saving workspace file to: $OutputPath"
        
        if ($WhatIf) {
            Write-Log "WhatIf mode: Would save workspace configuration with $($WorkspaceConfig.folders.Count) folders"
            return
        }
        
        # Convert to JSON with proper formatting
        $JsonContent = $WorkspaceConfig | ConvertTo-Json -Depth 10
        
        # Ensure output directory exists
        $OutputDir = Split-Path $OutputPath -Parent
        if ($OutputDir -and -not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }
        
        # Save to file with UTF-8 encoding
        $JsonContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        
        # Verify file was created
        if (Test-Path $OutputPath) {
            $FileSize = (Get-Item $OutputPath).Length
            Write-Log "Workspace file saved successfully (Size: $FileSize bytes)"
        } else {
            throw "Workspace file was not created"
        }
    }
    catch {
        Write-Log "Error saving workspace file: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Validate-WorkspaceFile {
    param([string]$FilePath)
    
    try {
        Write-Log "Validating workspace file..."
        
        if (-not (Test-Path $FilePath)) {
            throw "Workspace file does not exist: $FilePath"
        }
        
        # Try to parse the JSON
        $Content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $ParsedConfig = $Content | ConvertFrom-Json
        
        # Basic validation
        if (-not $ParsedConfig.folders) {
            throw "Workspace file is missing 'folders' property"
        }
        
        if (-not $ParsedConfig.settings) {
            throw "Workspace file is missing 'settings' property"
        }
        
        Write-Log "Workspace file validation passed"
        Write-Log "  - Folders configured: $($ParsedConfig.folders.Count)"
        Write-Log "  - Settings configured: $($ParsedConfig.settings | Get-Member -MemberType NoteProperty | Measure-Object).Count"
        
        return $true
    }
    catch {
        Write-Log "Workspace file validation failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Show-Summary {
    param(
        [array]$TestDirectories,
        [string]$OutputPath
    )
    
    Write-Log "=== Build Tests Workspace Summary ==="
    Write-Log "Test directories found: $($TestDirectories.Count)"
    
    if ($TestDirectories.Count -gt 0) {
        Write-Log "Test directories included:"
        foreach ($Dir in $TestDirectories | Sort-Object) {
            Write-Log "  - $Dir"
        }
    }
    
    Write-Log "Output file: $OutputPath"
    Write-Log "WhatIf mode: $WhatIf"
    Write-Log "=================================="
}

# Main execution
try {
    Write-Log "Starting BuildTestsWorkSpace script"
    Write-Log "Output path: $OutputPath"
    
    if ($WhatIf) {
        Write-Log "Running in WhatIf mode - no files will be created"
    }
    
    # Find test directories
    $TestDirectories = Find-TestDirectories
    
    if ($TestDirectories.Count -eq 0) {
        Write-Log "No test directories found. Creating empty workspace configuration." "WARNING"
        $TestDirectories = @()
    }
    
    # Build workspace configuration
    $WorkspaceConfig = Build-WorkspaceConfiguration -TestDirectories $TestDirectories
    
    # Save workspace file
    Save-WorkspaceFile -WorkspaceConfig $WorkspaceConfig -OutputPath $OutputPath
    
    # Validate the created file
    if (-not $WhatIf) {
        $ValidationResult = Validate-WorkspaceFile -FilePath $OutputPath
        if (-not $ValidationResult) {
            throw "Workspace file validation failed"
        }
    }
    
    # Show summary
    Show-Summary -TestDirectories $TestDirectories -OutputPath $OutputPath
    
    Write-Log "BuildTestsWorkSpace completed successfully"
}
catch {
    Write-Log "BuildTestsWorkSpace script failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
