$ErrorActionPreference = "Stop"

$InfrastructureDir = Split-Path -Parent $PSScriptRoot
$TerraformDir = Join-Path $InfrastructureDir "terraform"
$ComposeFile = Join-Path $InfrastructureDir "docker-compose.yml"
$ProjectRoot = Split-Path -Parent $InfrastructureDir
$ApplicationDir = Join-Path $ProjectRoot "S3Uploader"

Write-Host "Starting S3Uploader deployment..." -ForegroundColor Cyan
Write-Host "Infrastructure: $InfrastructureDir"
Write-Host "Terraform: $TerraformDir"

# Step 1: Check Docker
Write-Host "`n[1] Checking Docker..." -ForegroundColor Cyan

docker info --format '{{.ServerVersion}}'

if ($LASTEXITCODE -ne 0) {
    throw "Docker is not running or is not accessible."
}

# Step 2: Start Floci
Write-Host "`n[2] Starting Floci..." -ForegroundColor Cyan

docker compose -f $ComposeFile up -d --pull never

if ($LASTEXITCODE -ne 0) {
    throw "Failed to start Floci using Docker Compose."
}

# Step 3: Wait for Floci's API
Write-Host "`n[3] Waiting for Floci API..." -ForegroundColor Cyan

$HealthUrl = "http://localhost:4566/_localstack/health"
$MaxAttempts = 30
$Ready = $false

for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
    try {
        $Response = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 5

        if (
            $Response.services.s3 -eq "running" -and
            $Response.services.ecr -eq "running" -and
            $Response.services.eks -eq "running"
        ) {
            $Ready = $true
            break
        }
    }
    catch {
        # Floci may still be starting.
    }

    Write-Host "Floci not ready yet ($Attempt/$MaxAttempts)..."
    Start-Sleep -Seconds 2
}

if (-not $Ready) {
    throw "Floci API did not become ready."
}

Write-Host "`nFloci is ready!" -ForegroundColor Green

# Step 4: Initialize Terraform
Write-Host "`n[4] Initializing Terraform..." -ForegroundColor Cyan

terraform -chdir="$TerraformDir" init -input=false

if ($LASTEXITCODE -ne 0) {
    throw "Terraform initialization failed."
}

Write-Host "Terraform initialized successfully." -ForegroundColor Green

# Step 5: Apply Terraform configuration
Write-Host "`n[5] Applying Terraform configuration..." -ForegroundColor Cyan

terraform -chdir="$TerraformDir" apply -auto-approve -input=false

if ($LASTEXITCODE -ne 0) {
    throw "Terraform apply failed."
}

Write-Host "Terraform infrastructure deployed successfully." -ForegroundColor Green

# Step 6: Build application Docker image
Write-Host "`n[6] Building S3Uploader Docker image..." -ForegroundColor Cyan

docker build -t s3uploader:dev $ApplicationDir

if ($LASTEXITCODE -ne 0) {
    throw "Docker image build failed."
}

Write-Host "S3Uploader Docker image built successfully." -ForegroundColor Green

# Step 7: Tag Docker image for Floci ECR
Write-Host "`n[7] Tagging image for Floci ECR..." -ForegroundColor Cyan

$LocalImage = "s3uploader:dev"
$EcrImage = "localhost:4566/000000000000/us-east-1/s3uploader:dev"

docker tag $LocalImage $EcrImage

if ($LASTEXITCODE -ne 0) {
    throw "Failed to tag Docker image for ECR."
}

Write-Host "Docker image tagged successfully: $EcrImage" -ForegroundColor Green

# Step 8: Push Docker image to Floci ECR
Write-Host "`n[8] Pushing image to Floci ECR..." -ForegroundColor Cyan

docker push $EcrImage

if ($LASTEXITCODE -ne 0) {
    throw "Failed to push Docker image to Floci ECR."
}

Write-Host "Docker image pushed successfully to Floci ECR." -ForegroundColor Green

# Step 9: Retrieve Kubernetes configuration
Write-Host "`n[9] Configuring Kubernetes access..." -ForegroundColor Cyan

$KubeconfigDir = Join-Path $env:USERPROFILE ".kube"
$KubeconfigPath = Join-Path $KubeconfigDir "floci-k3s.yaml"

New-Item -ItemType Directory -Path $KubeconfigDir -Force | Out-Null

docker cp floci-aws-eks-dev-cluster:/etc/rancher/k3s/k3s.yaml $KubeconfigPath

if ($LASTEXITCODE -ne 0) {
    throw "Failed to retrieve Kubernetes configuration."
}

Write-Host "Kubernetes configuration saved to: $KubeconfigPath" -ForegroundColor Green

# Step 10: Configure Kubernetes API endpoint
Write-Host "`n[10] Configuring Kubernetes API endpoint..." -ForegroundColor Cyan

kubectl --kubeconfig $KubeconfigPath config set-cluster default --server=https://localhost:6500

if ($LASTEXITCODE -ne 0) {
    throw "Failed to configure Kubernetes API endpoint."
}

kubectl --kubeconfig $KubeconfigPath config rename-context default floci-dev-cluster

if ($LASTEXITCODE -ne 0) {
    throw "Failed to rename Kubernetes context."
}

Write-Host "Kubernetes API endpoint configured successfully." -ForegroundColor Green

# Step 11: Verify Kubernetes connection
Write-Host "`n[11] Verifying Kubernetes connection..." -ForegroundColor Cyan

kubectl --kubeconfig $KubeconfigPath get nodes

if ($LASTEXITCODE -ne 0) {
    throw "Failed to connect to the Kubernetes cluster."
}

Write-Host "Kubernetes connection verified successfully." -ForegroundColor Green

# Step 12: Deploy application to Kubernetes
Write-Host "`n[12] Deploying S3Uploader to Kubernetes..." -ForegroundColor Cyan

$ManifestPath = Join-Path $ApplicationDir "deployment.yaml"

kubectl --kubeconfig $KubeconfigPath apply -f $ManifestPath

if ($LASTEXITCODE -ne 0) {
    throw "Failed to deploy S3Uploader to Kubernetes."
}

Write-Host "Kubernetes manifest applied successfully." -ForegroundColor Green

# Step 13: Restart application and wait for rollout
Write-Host "`n[13] Restarting S3Uploader deployment..." -ForegroundColor Cyan

kubectl --kubeconfig $KubeconfigPath rollout restart deployment/s3uploader

if ($LASTEXITCODE -ne 0) {
    throw "Failed to restart S3Uploader deployment."
}

Write-Host "Waiting for S3Uploader pods to become ready..."

kubectl --kubeconfig $KubeconfigPath rollout status deployment/s3uploader --timeout=180s

if ($LASTEXITCODE -ne 0) {
    throw "S3Uploader deployment did not become ready within 180 seconds."
}

Write-Host "S3Uploader deployment is ready!" -ForegroundColor Green

# Step 14: Verify application pods
Write-Host "`n[14] Verifying S3Uploader pods..." -ForegroundColor Cyan

kubectl --kubeconfig $KubeconfigPath get pods -l app=s3uploader

if ($LASTEXITCODE -ne 0) {
    throw "Failed to retrieve S3Uploader pods."
}

Write-Host "S3Uploader pod verification completed." -ForegroundColor Green

# Step 15: Wait for application health
Write-Host "`n[15] Waiting for application health..." -ForegroundColor Cyan

$HealthUrl = "http://s3uploader.example.test/health"
$MaxAttempts = 36
$RetryIntervalSeconds = 5
$Healthy = $false

for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
    try {
        $Response = Invoke-WebRequest `
            -Uri $HealthUrl `
            -TimeoutSec 10 `
            -UseBasicParsing

        if (
            $Response.StatusCode -eq 200 -and
            $Response.Content.Trim() -eq "Healthy"
        ) {
            $Healthy = $true
            break
        }
    }
    catch {
        # The ALB or application may not be ready yet.
    }

    Write-Host "Application not healthy yet ($Attempt/$MaxAttempts)..."

    if ($Attempt -lt $MaxAttempts) {
        Start-Sleep -Seconds $RetryIntervalSeconds
    }
}

if (-not $Healthy) {
    throw "Application did not become healthy after $MaxAttempts attempts."
}

Write-Host "Application is healthy!" -ForegroundColor Green
Write-Host "Deployment completed successfully!" -ForegroundColor Green