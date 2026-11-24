[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceAcrName,
    [Parameter(Mandatory)][string]$SourceAcrUsername,
    [Parameter(Mandatory)][string]$SourceAcrPassword,
    [Parameter(Mandatory)][string]$DestinationAcrName,
    [Parameter(Mandatory)][string]$ImageTag,
    [string[]]$ImageNames = @('sandbox-api', 'sandbox-worker', 'sandbox-ui'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Docker {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
    $result = & docker @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed: $($Arguments -join ' ')`n$result"
    }
    return $result
}

function Invoke-Azure {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
    $result = & az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Azure command failed: $($Arguments -join ' ')`n$result"
    }
    return $result
}

Write-Host "=== Container Image Import Script ===" -ForegroundColor Cyan
Write-Host "Source ACR: $SourceAcrName" -ForegroundColor Gray
Write-Host "Destination ACR: $DestinationAcrName" -ForegroundColor Gray
Write-Host "Image Tag: $ImageTag" -ForegroundColor Gray
Write-Host "Images: $($ImageNames -join ', ')" -ForegroundColor Gray

# Login to source ACR
Write-Host "`nLogging in to source ACR: $SourceAcrName..." -ForegroundColor Cyan
$SourceAcrPassword | Invoke-Docker login --username $SourceAcrUsername --password-stdin "$SourceAcrName.azurecr.io"

# Get destination ACR credentials
Write-Host "Retrieving destination ACR credentials..." -ForegroundColor Cyan
$DestAcrCreds = Invoke-Azure acr credential show --name $DestinationAcrName --query '{username: username, password: passwords[0].value}' --output json | ConvertFrom-Json

if (-not $DestAcrCreds.password) {
    throw "Unable to retrieve destination ACR credentials"
}

# Login to destination ACR
Write-Host "Logging in to destination ACR: $DestinationAcrName..." -ForegroundColor Cyan
$DestAcrCreds.password | Invoke-Docker login --username $DestAcrCreds.username --password-stdin "$DestinationAcrName.azurecr.io"

# Pull, tag, and push images
foreach ($imageName in $ImageNames) {
    $sourceImage = "$SourceAcrName.azurecr.io/$imageName`:$ImageTag"
    $destImage = "$DestinationAcrName.azurecr.io/$imageName`:$ImageTag"
    
    Write-Host "`nProcessing image: $imageName" -ForegroundColor Cyan
    
    # Pull from source
    Write-Host "  Pulling: $sourceImage" -ForegroundColor Yellow
    try {
        Invoke-Docker pull $sourceImage
        Write-Host "  ✓ Pull successful" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to pull $sourceImage" -ForegroundColor Red
        if (-not $Force) {
            throw $_
        }
        continue
    }
    
    # Tag for destination
    Write-Host "  Tagging: $destImage" -ForegroundColor Yellow
    Invoke-Docker tag $sourceImage $destImage
    
    # Push to destination
    Write-Host "  Pushing: $destImage" -ForegroundColor Yellow
    try {
        Invoke-Docker push $destImage
        Write-Host "  ✓ Push successful" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to push $destImage" -ForegroundColor Red
        if (-not $Force) {
            throw $_
        }
        continue
    }
}

Write-Host "`n✓ Image import completed!" -ForegroundColor Green
Write-Host "Images are now available in $DestinationAcrName" -ForegroundColor Yellow
