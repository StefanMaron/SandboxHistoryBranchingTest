param(
    [string]$ArtifactType = "Sandbox",
    [string]$StorageAccount = "",
    [switch]$AcceptInsiderEula = $false,
    [string]$OutputFormat = "GitHub", # GitHub, Console, Json
    [switch]$IncludeVersionDetails = $false
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message"
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check if BcContainerHelper module is available
    if (-not (Get-Module -ListAvailable -Name "BcContainerHelper")) {
        throw "BcContainerHelper PowerShell module is not installed. Please install it first."
    }
    
    # Import the module if not already loaded
    if (-not (Get-Module -Name "BcContainerHelper")) {
        try {
            Import-Module BcContainerHelper -Force
            Write-Log "BcContainerHelper module imported successfully"
        }
        catch {
            throw "Failed to import BcContainerHelper module: $($_.Exception.Message)"
        }
    }
    
    Write-Log "Prerequisites check passed"
}

function Get-BCArtifactCountries {
    param(
        [string]$Type,
        [string]$StorageAccount,
        [bool]$AcceptInsiderEula
    )
    
    try {
        Write-Log "Fetching BC artifact URLs..."
        Write-Log "  - Type: $Type"
        Write-Log "  - Storage Account: $StorageAccount"
        Write-Log "  - Accept Insider EULA: $AcceptInsiderEula"
        
        # Build parameters for Get-BCArtifactUrl
        $ArtifactParams = @{
            'select' = 'All'
            'Type' = $Type
        }
        
        if ($AcceptInsiderEula) {
            $ArtifactParams['accept_insiderEula'] = $true
        }
        
        if (-not [string]::IsNullOrEmpty($StorageAccount)) {
            $ArtifactParams['storageAccount'] = $StorageAccount
        }
        
        # Get artifact URLs
        $ArtifactUrls = Get-BCArtifactUrl @ArtifactParams
        
        if (-not $ArtifactUrls -or $ArtifactUrls.Count -eq 0) {
            throw "No artifact URLs were returned"
        }
        
        Write-Log "Retrieved $($ArtifactUrls.Count) artifact URLs"
        
        return $ArtifactUrls
    }
    catch {
        Write-Log "Error fetching artifact URLs: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Parse-ArtifactUrls {
    param([array]$ArtifactUrls)
    
    try {
        Write-Log "Parsing artifact URLs to extract countries and versions..."
        
        $Countries = [System.Collections.Generic.HashSet[string]]::new()
        $CountryVersions = @{}
        $ParseErrors = 0
        
        foreach ($ArtifactUrl in $ArtifactUrls) {
            try {
                [System.Uri]$Uri = $ArtifactUrl
                $PathParts = $Uri.AbsolutePath.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
                
                if ($PathParts.Length -ge 3) {
                    $VersionString = $PathParts[1]  # Version is typically the second part
                    $CountryCode = $PathParts[2]    # Country is typically the third part
                    
                    # Try to parse version to validate
                    try {
                        [version]$Version = $VersionString
                        
                        # Only include versions >= 23.5.0.0 as per original logic
                        if ($Version -ge [version]::Parse('23.5.0.0')) {
                            $Countries.Add($CountryCode.ToLowerInvariant()) | Out-Null
                            
                            if ($IncludeVersionDetails) {
                                if (-not $CountryVersions.ContainsKey($CountryCode)) {
                                    $CountryVersions[$CountryCode] = @()
                                }
                                $CountryVersions[$CountryCode] += $Version
                            }
                        }
                    }
                    catch {
                        # Skip if version cannot be parsed
                        Write-Log "Could not parse version '$VersionString' from URL: $ArtifactUrl" "DEBUG"
                    }
                }
            }
            catch {
                $ParseErrors++
                Write-Log "Error parsing URL: $ArtifactUrl - $($_.Exception.Message)" "DEBUG"
            }
        }
        
        if ($ParseErrors -gt 0) {
            Write-Log "Encountered $ParseErrors parse errors (this is normal)" "DEBUG"
        }
        
        # Convert HashSet to sorted array
        $SortedCountries = $Countries | Sort-Object
        
        Write-Log "Successfully parsed countries: $($SortedCountries.Count)"
        foreach ($Country in $SortedCountries) {
            $VersionCount = if ($CountryVersions.ContainsKey($Country)) { $CountryVersions[$Country].Count } else { "N/A" }
            Write-Log "  - $Country $(if ($IncludeVersionDetails) { "($VersionCount versions)" })"
        }
        
        return @{
            Countries = $SortedCountries
            CountryVersions = $CountryVersions
        }
    }
    catch {
        Write-Log "Error parsing artifact URLs: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Format-Output {
    param(
        [array]$Countries,
        [hashtable]$CountryVersions,
        [string]$Format
    )
    
    try {
        Write-Log "Formatting output in $Format format..."
        
        switch ($Format.ToLower()) {
            "github" {
                # GitHub Actions output format
                $CountriesJson = $Countries | ConvertTo-Json -Compress
                $Output = "countries={""countries"":$CountriesJson}"
                
                # Write to GitHub output if running in GitHub Actions
                if ($env:GITHUB_OUTPUT) {
                    Add-Content -Path $env:GITHUB_OUTPUT -Value $Output
                    Write-Log "Output written to GitHub Actions output file"
                } else {
                    Write-Host $Output
                }
            }
            "json" {
                # Pure JSON output
                $OutputObject = @{
                    countries = $Countries
                }
                
                if ($IncludeVersionDetails) {
                    $OutputObject.countryVersions = $CountryVersions
                }
                
                $JsonOutput = $OutputObject | ConvertTo-Json -Depth 10
                Write-Host $JsonOutput
            }
            "console" {
                # Human-readable console output
                Write-Host "`nAvailable Countries:"
                Write-Host "==================="
                foreach ($Country in $Countries) {
                    if ($IncludeVersionDetails -and $CountryVersions.ContainsKey($Country)) {
                        $VersionCount = $CountryVersions[$Country].Count
                        $LatestVersion = ($CountryVersions[$Country] | Sort-Object -Descending)[0]
                        Write-Host "$Country ($VersionCount versions, latest: $LatestVersion)"
                    } else {
                        Write-Host $Country
                    }
                }
                Write-Host "`nTotal: $($Countries.Count) countries"
            }
            default {
                throw "Unsupported output format: $Format. Supported formats: GitHub, Json, Console"
            }
        }
        
        Write-Log "Output formatting completed"
    }
    catch {
        Write-Log "Error formatting output: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Show-Summary {
    param([array]$Countries)
    
    Write-Log "=== Get All Countries Summary ==="
    Write-Log "Artifact Type: $ArtifactType"
    Write-Log "Storage Account: $(if ($StorageAccount) { $StorageAccount } else { 'Default' })"
    Write-Log "Accept Insider EULA: $AcceptInsiderEula"
    Write-Log "Countries found: $($Countries.Count)"
    Write-Log "Output format: $OutputFormat"
    Write-Log "Include version details: $IncludeVersionDetails"
    Write-Log "================================"
}

# Main execution
try {
    Write-Log "Starting GetAllCountries script"
    
    # Check prerequisites
    Test-Prerequisites
    
    # Get artifact URLs
    $ArtifactUrls = Get-BCArtifactCountries -Type $ArtifactType -StorageAccount $StorageAccount -AcceptInsiderEula $AcceptInsiderEula
    
    # Parse URLs to extract countries
    $ParseResult = Parse-ArtifactUrls -ArtifactUrls $ArtifactUrls
    
    # Format and output results
    Format-Output -Countries $ParseResult.Countries -CountryVersions $ParseResult.CountryVersions -Format $OutputFormat
    
    # Show summary
    Show-Summary -Countries $ParseResult.Countries
    
    Write-Log "GetAllCountries completed successfully"
}
catch {
    Write-Log "GetAllCountries script failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
