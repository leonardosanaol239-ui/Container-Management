# Switch to Remote Database
Write-Host "Switching to REMOTE database..." -ForegroundColor Green

# Update appsettings.json to use remote database
$appsettings = Get-Content "con_mgmt_api/appsettings.json" | ConvertFrom-Json
$appsettings.DatabaseSettings.UseLocalDatabase = $false
$appsettings.DatabaseSettings.ConnectionName = "Remote"
$appsettings | ConvertTo-Json -Depth 10 | Set-Content "con_mgmt_api/appsettings.json"

Write-Host "✓ Configuration updated to use REMOTE database" -ForegroundColor Green
Write-Host "✓ Using: 192.168.76.119" -ForegroundColor Cyan
Write-Host "✓ Database: ojt_2026_01_1" -ForegroundColor Cyan
Write-Host "" 
Write-Host "Setup remote database (when server is online):" -ForegroundColor Yellow
Write-Host "  sqlcmd -S 192.168.76.119 -U jasper -P Default@123 -i database/setup_remote.sql" -ForegroundColor Gray
Write-Host ""
Write-Host "Restart your API to apply changes:" -ForegroundColor Yellow
Write-Host "  cd con_mgmt_api" -ForegroundColor Gray
Write-Host "  dotnet run" -ForegroundColor Gray