# PowerShell script to create test data for Container Management API

$baseUrl = "http://localhost:5000/api"

Write-Host "Creating test containers..." -ForegroundColor Green

# Create Container 1
$container1 = @{
    statusId = 1
    type = "20ft Standard"
    containerDesc = "Standard shipping container for general cargo"
    currentPortId = 1
} | ConvertTo-Json

try {
    $result1 = Invoke-RestMethod -Uri "$baseUrl/containers" -Method POST -Body $container1 -ContentType "application/json"
    Write-Host "✓ Created container: $($result1.containerNumber)" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to create container 1: $($_.Exception.Message)" -ForegroundColor Red
}

# Create Container 2
$container2 = @{
    statusId = 2
    type = "40ft High Cube"
    containerDesc = "High cube container for oversized cargo"
    currentPortId = 1
} | ConvertTo-Json

try {
    $result2 = Invoke-RestMethod -Uri "$baseUrl/containers" -Method POST -Body $container2 -ContentType "application/json"
    Write-Host "✓ Created container: $($result2.containerNumber)" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to create container 2: $($_.Exception.Message)" -ForegroundColor Red
}

# Create Container 3
$container3 = @{
    statusId = 1
    type = "20ft Refrigerated"
    containerDesc = "Refrigerated container for perishable goods"
    currentPortId = 1
} | ConvertTo-Json

try {
    $result3 = Invoke-RestMethod -Uri "$baseUrl/containers" -Method POST -Body $container3 -ContentType "application/json"
    Write-Host "✓ Created container: $($result3.containerNumber)" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to create container 3: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nGetting containers for Manila Port..." -ForegroundColor Yellow
try {
    $containers = Invoke-RestMethod -Uri "$baseUrl/containers/port/1" -Method GET
    Write-Host "✓ Found $($containers.Count) containers in Manila Port" -ForegroundColor Green
    foreach ($container in $containers) {
        Write-Host "  - $($container.containerNumber): $($container.type) ($($container.status.statusDesc))" -ForegroundColor Cyan
    }
} catch {
    Write-Host "✗ Failed to get containers: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest data creation complete!" -ForegroundColor Green