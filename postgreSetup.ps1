param (
    [Parameter(Mandatory = $true)]
    [string]$jsonFilePath
)

# Check if the JSON file exists
if (-Not (Test-Path -Path $jsonFilePath)) {
    Write-Host "Error: JSON file not found at $jsonFilePath"
    exit 1
}

# Read and parse JSON content
$jsonContent = Get-Content -Path $jsonFilePath | ConvertFrom-Json

function Setup-PostgreSQL-ODBC {
    param (
        [Object]$jsonContent
    )
    
    # Get the list of existing DSNs
    $existingDSNs = Get-OdbcDsn -DsnType System
    
    # Track DSNs that should exist after execution
    $newDSNNames = @()
    
    # Loop through each DSN entry in the JSON
    foreach ($dsn in $jsonContent.DSNs) {
        $dsnName = $dsn.Name
        $server = $dsn.Server
        $port = $dsn.Port
        $database = $dsn.Database
        $driver = $dsn.Driver
        $platform = $dsn.Platform  # Read Platform from JSON
        
        # Determine platform if not specified
        if (-not $platform) {
            $installedDrivers32 = Get-OdbcDriver -Platform 32-bit | Select-Object -ExpandProperty Name
            $installedDrivers64 = Get-OdbcDriver -Platform 64-bit | Select-Object -ExpandProperty Name

            if ($installedDrivers32 -contains $driver -and $installedDrivers64 -contains $driver) {
                Write-Host "Driver $driver exists for both 32-bit and 64-bit. Skipping automatic platform selection."
                Write-Host "Please specify the platform in the JSON file."
                continue
            }
            elseif ($installedDrivers32 -contains $driver) {
                $platform = "32-bit"
            }
            elseif ($installedDrivers64 -contains $driver) {
                $platform = "64-bit"
            } else {
                Write-Host "Error: Driver $driver not found on this system. Skipping DSN creation."
                continue
            }
        }
        
        # Add to tracking list
        $newDSNNames += $dsnName
        
        # Check if DSN already exists
        $existingDSN = $existingDSNs | Where-Object { $_.Name -eq $dsnName -and $_.Platform -eq $platform }
        
        if ($existingDSN) {
            Write-Host "DSN '$dsnName' exists. Checking for updates..."
            
            # Check if the configuration has changed
            $dsnProperties = @("Server=$server", "Port=$port", "Database=$database")
            $configChanged = $false
            
            foreach ($property in $dsnProperties) {
                if ($existingDSN.SetPropertyValue -notcontains $property) {
                    $configChanged = $true
                    break
                }
            }
            
            if ($configChanged) {
                Write-Host "Updating DSN: $dsnName with new settings."
                try {
                    Remove-OdbcDsn -Name $dsnName -DsnType System -Platform $platform
                    Add-OdbcDsn -Name $dsnName -DriverName $driver -DsnType System -Platform $platform -SetPropertyValue $dsnProperties
                    Write-Host "Successfully updated DSN: $dsnName"
                } catch {
                    Write-Host "Failed to update DSN: $dsnName. Error: $_"
                }
            } else {
                Write-Host "No changes detected for DSN: $dsnName. Skipping update."
            }
        } else {
            Write-Host "Creating new DSN: $dsnName with Driver: $driver on $platform"
            try {
                Add-OdbcDsn -Name $dsnName -DriverName $driver -DsnType System -Platform $platform -SetPropertyValue @(
                    "Server=$server",
                    "Port=$port",
                    "Database=$database"
                )
                Write-Host "Successfully created DSN: $dsnName"
            } catch {
                Write-Host "Failed to create DSN: $dsnName. Error: $_"
            }
        }
    }
    
    # Remove DSNs that exist but are no longer in the JSON
    foreach ($existingDSN in $existingDSNs) {
        if ($existingDSN.DsnType -eq "System" -and $newDSNNames -notcontains $existingDSN.Name) {
            Write-Host "Removing obsolete DSN: $($existingDSN.Name)"
            try {
                Remove-OdbcDsn -Name $existingDSN.Name -DsnType System -Platform $existingDSN.Platform
                Write-Host "Successfully removed DSN: $($existingDSN.Name)"
            } catch {
                Write-Host "Failed to remove DSN: $($existingDSN.Name). Error: $_"
            }
        }
    }
    
    Write-Host "ODBC DSN setup complete."
}

# Call the function with the JSON content
Setup-PostgreSQL-ODBC -jsonContent $jsonContent
