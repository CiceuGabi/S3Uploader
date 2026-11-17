$ErrorActionPreference = "Stop"

$InfrastructureDir = Split-Path -Parent $PSScriptRoot
$TerraformDir = Join-Path $InfrastructureDir "terraform"
$ComposeFile = Join-Path $InfrastructureDir "docker-compose.yml"
$KubeconfigPath = Join-Path $env:USERPROFILE ".kube\floci-k3s.yaml"

Write-Host "Starting S3Uploader infrastructure cleanup..." -ForegroundColor Cyan
Write-Host "Infrastructure: $InfrastructureDir"
Write-Host "Terraform: $TerraformDir"
Write-Host "Kubeconfig: $KubeconfigPath"

# Step 1: Delete Kubernetes application
Write-Host "`n[1] Deleting S3Uploader from Kubernetes..." -ForegroundColor Cyan

kubectl --kubeconfig $KubeconfigPath delete deployment s3uploader --ignore-not-found=true

if ($LASTEXITCODE -ne 0) {
    throw "Failed to delete S3Uploader Deployment."
}

kubectl --kubeconfig $KubeconfigPath delete service s3uploader --ignore-not-found=true

if ($LASTEXITCODE -ne 0) {
    throw "Failed to delete S3Uploader Service."
}

Write-Host "S3Uploader Kubernetes resources deleted successfully." -ForegroundColor Green

# Step 2: Destroy Terraform infrastructure
Write-Host "`n[2] Destroying Terraform infrastructure..." -ForegroundColor Cyan

terraform -chdir="$TerraformDir" destroy -auto-approve -input=false

if ($LASTEXITCODE -ne 0) {
    throw "Terraform infrastructure destruction failed."
}

Write-Host "Terraform infrastructure destroyed successfully." -ForegroundColor Green

# Step 3: Stop Floci
Write-Host "`n[3] Stopping Floci..." -ForegroundColor Cyan

docker compose -f $ComposeFile down

if ($LASTEXITCODE -ne 0) {
    throw "Failed to stop Floci."
}

Write-Host "Floci stopped successfully." -ForegroundColor Green

# Step 4: Remove leftover Floci AWS VPC network
Write-Host "`n[4] Cleaning up Floci AWS VPC network..." -ForegroundColor Cyan

$VpcNetwork = "floci-aws-vpc-4566-us-east-1-vpc-default-us-east-1"

$ExistingNetwork = docker network ls --filter "name=^${VpcNetwork}$" --format "{{.Name}}"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to check Docker networks."
}

if ($ExistingNetwork -eq $VpcNetwork) {
    docker network rm $VpcNetwork

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to remove Floci AWS VPC network."
    }

    Write-Host "Floci AWS VPC network removed." -ForegroundColor Green
}
else {
    Write-Host "Floci AWS VPC network already removed." -ForegroundColor Green
}

Write-Host "`nInfrastructure cleanup completed successfully!" -ForegroundColor Green