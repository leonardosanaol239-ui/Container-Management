# ============================================================================
# Execute Y4 PORTID2 Setup Script
# ============================================================================
# This script runs the SQL to ensure Y4.png is set for all yards in Port 2
# ============================================================================

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "ENSURING Y4.png FOR PORTID2" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# Database connection parameters
$Server = "localhost"
$Database = "ContainerManagement"
$SqlFile = "database/ensure_y4_portid2.sql"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Server: $Server" -ForegroundColor White
Write-Host "  Database: $Database" -ForegroundColor White
Write-Host "  SQL File: $SqlFile" -ForegroundColor White
Write-Host ""

# Check if SQL file exists
if (-not (Test-Path $SqlFile)) {
    Write-Host "❌ ERROR: SQL file not found: $SqlFile" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure you are running this script from the container_mgmt directory." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ SQL file found" -ForegroundColor Green
Write-Host ""

# Execute the SQL script
Write-Host "Executing SQL script..." -ForegroundColor Yellow
Write-Host ""

try {
    # Using sqlcmd to execute the script
    sqlcmd -S $Server -d $Database -E -i $SqlFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "============================================================================" -ForegroundColor Green
        Write-Host "✅ SUCCESS! Y4.png has been set for all yards in PORTID2" -ForegroundColor Green
        Write-Host "============================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "1. Verify Y4.png exists: assets/Y4.png" -ForegroundColor White
        Write-Host "2. Run: flutter pub get" -ForegroundColor White
        Write-Host "3. Restart your Flutter app" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "❌ ERROR: SQL script execution failed" -ForegroundColor Red
        Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "❌ ERROR: Failed to execute SQL script" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure SQL Server is running" -ForegroundColor White
    Write-Host "2. Verify database name: $Database" -ForegroundColor White
    Write-Host "3. Check if sqlcmd is installed and in PATH" -ForegroundColor White
    Write-Host "4. Verify Windows Authentication is enabled" -ForegroundColor White
    exit 1
}

Write-Host "============================================================================" -ForegroundColor Cyan
