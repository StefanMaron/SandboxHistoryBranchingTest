# Modular Script Architecture

This document describes the new modular architecture for the BC Code History repository scripts.

## Overview

The scripts have been refactored into a modular, pipeline-based architecture that provides:

- **Better maintainability** through separation of concerns
- **Improved error handling** with dedicated retry and backup mechanisms  
- **Enhanced testability** with individual phase testing
- **Greater flexibility** with configurable execution modes
- **Cleaner CI/CD integration** with separate pipeline steps

## Architecture Components

### Core Modules

#### 1. Common-Utils.psm1
Shared utility functions used across all scripts:
- `Write-Log`: Centralized logging with timestamps
- `Invoke-WithRetry`: Configurable retry mechanism
- `Test-GitRepository`: Git repository validation
- `Test-PowerShellModule`: Module availability checking
- `Test-ExternalCommand`: External command validation
- `Convert-ToCamelCase`: Text formatting utilities

#### 2. Git-Operations.psm1
Git-specific operations:
- `New-GitBranch` / `Switch-GitBranch`: Branch management
- `Test-GitBranchExists` / `Test-GitCommitExists`: Existence checks
- `New-GitCommit` / `Push-GitChanges`: Commit operations
- `New-GitBackup` / `Restore-GitBackup`: Backup management
- `Get-BaseCommitForNewBranch`: BC-specific branching logic

#### 3. Artifact-Management.psm1
BC artifact operations:
- `Get-BCArtifactVersions`: Fetch versions for processing
- `Get-BCArtifactCountries`: Get available countries
- `Invoke-ArtifactDownload`: Download artifact packages
- `Get-ArtifactTargetPath`: Determine processing paths

### Pipeline Phases

#### Phase 1: Prerequisites Check (`Phase1-CheckPrerequisites.ps1`)
Validates environment before processing:
- Git repository status
- Required PowerShell modules
- External dependencies (7z, git)
- Disk space requirements
- Git configuration

#### Phase 2: Version Processing (`Phase2-ProcessVersion.ps1`)
Processes individual BC versions:
- Downloads artifacts
- Extracts and processes files
- Updates repository structure
- Creates commits
- Handles branching logic

#### Phase 3: Commit Reordering (`Phase3-ReorderCommits.ps1`)
Ensures chronological commit order:
- Analyzes commit history
- Identifies ordering issues
- Creates backup branches
- Reorders commits by version
- Validates final order

#### Phase 4: Push Changes (`Phase4-PushChanges.ps1`)
Finalizes changes:
- Pushes to remote repository
- Verifies synchronization
- Handles push conflicts
- Reports final status

### Coordination Scripts

#### Auto_load_versions_modular.ps1
Master coordinator script with modes:
- **Normal mode**: Full pipeline execution
- **ProcessOnly**: Skip reorder and push phases
- **ReorderOnly**: Only reorder existing commits
- **PushOnly**: Only push pending changes
- **WhatIf**: Dry-run mode for testing

#### Config-Management.ps1
Configuration management:
- Show current configuration
- Validate settings
- Reset to defaults
- Update configuration

## Usage Examples

### Basic Usage
```powershell
# Process all new versions for w1
./scripts/Auto_load_versions_modular.ps1 -country w1

# Test run without making changes
./scripts/Auto_load_versions_modular.ps1 -country de -WhatIf

# Process only, skip git operations
./scripts/Auto_load_versions_modular.ps1 -country us -ProcessOnly
```

### Individual Phase Execution
```powershell
# Check prerequisites only
./scripts/Phase1-CheckPrerequisites.ps1

# Process specific version
./scripts/Phase2-ProcessVersion.ps1 -Country w1 -Version "24.1.1234.5678" -ArtifactUrl "https://..."

# Reorder commits for a country
./scripts/Phase3-ReorderCommits.ps1 -Country de -Version "24.1.1234.5678"

# Push changes
./scripts/Phase4-PushChanges.ps1 -Country fr -Version "24.1.1234.5678"
```

### Configuration Management
```powershell
# Show current configuration
./scripts/Config-Management.ps1 -Action Show

# Validate configuration
./scripts/Config-Management.ps1 -Action Validate

# Reset to defaults
./scripts/Config-Management.ps1 -Action Reset
```

## CI/CD Integration

### GitHub Actions Workflow
The new `BuildNewCommits-Modular.yml` workflow provides:

- **Matrix-based processing** for parallel country handling
- **Phase-based execution** with proper error handling
- **Artifact collection** for logs and debugging
- **WhatIf mode support** for testing
- **Individual country processing** option
- **Comprehensive summary reporting**

### Manual Workflow Triggers
```yaml
# Process specific country
workflow_dispatch:
  inputs:
    country: 'de'
    whatif: false

# Test mode
workflow_dispatch:
  inputs:
    whatif: true
```

## Configuration

### Default Configuration Structure
```json
{
  "General": {
    "MaxRetries": 3,
    "RetryDelaySeconds": 30,
    "LogLevel": "INFO",
    "DefaultCountry": "w1"
  },
  "Git": {
    "AuthorEmail": "stefanmaron@outlook.de",
    "AuthorName": "Stefan Maron",
    "DefaultBranch": "main",
    "EnableGarbageCollection": true
  },
  "Artifacts": {
    "ArtifactType": "Sandbox",
    "StorageAccount": "",
    "AcceptInsiderEula": false,
    "MinVersion": "23.5.0.0",
    "IncludePlatformCountries": ["w1", "base", "core", "ph"]
  },
  "Processing": {
    "RemoveTranslationFiles": true,
    "EnableCamelCaseConversion": true,
    "MaxParallelJobs": 3,
    "RequiredDiskSpaceGB": 10
  }
}
```

## Migration from Original Scripts

### Gradual Migration Strategy
1. **Test in parallel**: Run both old and new scripts in test environment
2. **Phase-by-phase**: Migrate one phase at a time
3. **Validation**: Compare outputs between old and new implementations
4. **Configuration**: Set up configuration management
5. **Monitoring**: Implement enhanced logging and monitoring

### Compatibility
- All original functionality is preserved
- Enhanced error handling and logging
- Improved performance through modular design
- Better testability and maintainability

## Benefits

### For Development
- **Easier debugging**: Individual phases can be tested separately
- **Better error isolation**: Failures are contained to specific phases
- **Enhanced logging**: Detailed phase-by-phase logging
- **Improved testing**: WhatIf mode and individual phase testing

### For Operations
- **Better monitoring**: Phase-specific success/failure tracking
- **Improved reliability**: Backup and recovery mechanisms
- **Enhanced flexibility**: Multiple execution modes
- **Easier troubleshooting**: Detailed logs and error reporting

### For Maintenance
- **Modular updates**: Individual components can be updated independently
- **Better code reuse**: Shared modules reduce duplication
- **Improved documentation**: Clear separation of concerns
- **Enhanced extensibility**: New phases can be added easily

## Future Enhancements

### Planned Improvements
- **Parallel processing**: Enhanced parallel execution within phases
- **Caching**: Artifact and processing result caching
- **Monitoring**: Integration with monitoring systems
- **Database support**: Optional database backend for state tracking
- **API integration**: REST API for external integration

### Extension Points
- **Custom phases**: Add custom processing phases
- **Plugin architecture**: Pluggable processing components
- **External integrations**: Integration with external systems
- **Advanced notifications**: Email, Slack, Teams notifications
