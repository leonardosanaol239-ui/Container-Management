# Switch to Local Database
Write-Host "Switching to LOCAL database..." -ForegroundColor Green

# Update appsettings.json to use local database
$appsettings = Get-Content "con_mgmt_api/appsettings.json" | ConvertFrom-Json
$appsettings.DatabaseSettings.UseLocalDatabase = $true
$appsettings.DatabaseSettings.ConnectionName = "Local"
$appsettings | ConvertTo-Json -Depth 10 | Set-Content "con_mgmt_api/appsettings.json"

Write-Host "✓ Configuration updated to use LOCAL database" -ForegroundColor Green
Write-Host "✓ Using: (localdb)\MSSQLLocalDB" -ForegroundColor Cyan
Write-Host "✓ Database: ContainerManagement" -ForegroundColor Cyan
Write-Host "" 
Write-Host "Restart your API to apply changes:" -ForegroundColor Yellow
Write-Host "  cd con_mgmt_api" -ForegroundColor Gray
Write-Host "  dotnet run" -ForegroundColor Gray