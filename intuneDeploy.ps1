# Define script and JSON file paths in the Intune package
$scriptPath = "$PSScriptRoot\postgreSetup.ps1"
$jsonPath = "$PSScriptRoot\dataSources.json"

# Set execution policy to allow the script to run
Set-ExecutionPolicy Bypass -Scope Process -Force

# Run the ODBC setup script
Write-Host "Running ODBC setup script from Intune package..."
powershell -ExecutionPolicy Bypass -File $scriptPath -jsonFilePath $jsonPath

# Check for success
if ($?) {
    Write-Host "ODBC setup completed successfully."
    exit 0
} else {
    Write-Host "ODBC setup failed."
    exit 1
}