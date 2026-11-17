# S3Uploader

A .NET 10 Web API that uploads text files to Amazon S3 using **Floci**, a local AWS simulator.

The project demonstrates how to provision and run an AWS-like application locally using **Terraform, Docker, Kubernetes, ECR, EKS, Application Load Balancer, Route 53, and S3**, without deploying resources to a real AWS account.

## Architecture

The application runs in a Kubernetes cluster simulated by Floci and uses an S3 bucket for object storage.

```text
Client / Postman
       |
       v
s3uploader.example.test
       |
       v
Route 53 / Application Load Balancer
       |
       v
Kubernetes Service
       |
       v
S3Uploader (.NET 10)
       |
       v
Floci S3
       |
       v
awesome-bucket
```

Terraform provisions the simulated AWS resources, while Docker builds the application image and pushes it to the local ECR registry.

## Prerequisites

The following tools are required on a Windows development machine:

| Tool | Purpose |
|---|---|
| Docker Desktop | Runs Floci and its supporting containers |
| Docker Compose | Starts the Floci environment |
| Terraform | Provisions simulated AWS resources |
| AWS CLI v2 | Inspects S3 and other AWS resources |
| kubectl | Manages the Kubernetes deployment |
| PowerShell | Executes deployment and cleanup scripts |
| Git | Clones the repository |
| .NET 10 SDK (optional) | Runs or develops the application outside Docker |

Make sure Docker Desktop is running and configured to use Linux containers.

Verify the installed tools:

```powershell
docker --version
docker compose version
terraform version
aws --version
kubectl version --client
dotnet --version
```

The .NET SDK is optional for the containerized deployment because the application is built inside Docker.

### Floci Docker image

The deployment script starts Floci with:

```powershell
docker compose up -d --pull never
```

Therefore, the Floci Docker image referenced in `infrastructure/docker-compose.yml` must already exist locally.

Check the Compose configuration for the required image and make sure it is available before deploying.

## Getting started

### 1. Clone the repository

```powershell
git clone https://github.com/CiceuGabi/S3Uploader.git
cd S3Uploader
```

All subsequent commands assume that you are running PowerShell from the repository root.

### 2. Configure the local hostname

The application is accessed through:

```text
http://s3uploader.example.test
```

Add the following entry to the Windows hosts file:

```text
127.0.0.1 s3uploader.example.test
```

The hosts file is located at:

```text
C:\Windows\System32\drivers\etc\hosts
```

Editing it requires administrator privileges.

This entry is needed because the deployment script checks the application using the custom hostname.

### 3. Deploy the infrastructure and application

Run:

```powershell
.\infrastructure\scripts\deploy.ps1
```

The deployment script automatically:

1. Verifies that Docker is running.
2. Starts Floci using Docker Compose.
3. Waits for the simulated AWS services to become ready.
4. Initializes Terraform.
5. Provisions the AWS-like infrastructure.
6. Builds the .NET application Docker image.
7. Tags and pushes the image to the local ECR registry.
8. Retrieves the Kubernetes configuration.
9. Configures access to the local Kubernetes API.
10. Deploys the application to Kubernetes.
11. Restarts the deployment and waits for the pods.
12. Verifies that the application health endpoint responds successfully.

A successful deployment ends with:

```text
Application is healthy!
Deployment completed successfully!
```

The deployment script uses `terraform apply -auto-approve`, so infrastructure changes are applied without an interactive confirmation.

## Testing

### 1. Check application health

Open the following URL in a browser:

```text
http://s3uploader.example.test/health
```

Expected result:

```text
Healthy
```

### 2. Upload a text object to S3

The API exposes the following endpoint:

```http
POST /api/objects
Content-Type: application/json
```

Example request body:

```json
{
  "name": "hello.txt",
  "text": "Hello from S3Uploader!"
}
```

A successful upload returns HTTP **201 Created**, with details of the uploaded object.

The `name` property becomes the S3 object key. The `text` property contains the object content.

Object names are limited to 1,024 UTF-8 bytes.

### 3. Verify the object in S3

Floci exposes its AWS-compatible API at:

```text
http://localhost:4566
```

List the available S3 buckets:

```powershell
aws --endpoint-url=http://localhost:4566 s3 ls
```

Expected bucket:

```text
awesome-bucket
```

List the objects:

```powershell
aws --endpoint-url=http://localhost:4566 s3 ls s3://awesome-bucket/ --recursive
```

You should see `hello.txt` after uploading it through the API.

You can also read the object content:

```powershell
aws --endpoint-url=http://localhost:4566 s3 cp s3://awesome-bucket/hello.txt -
```

Expected content:

```text
Hello from S3Uploader!
```

The AWS CLI may require a configured region and credentials. For this local simulator, use `us-east-1` and dummy credentials such as `test` / `test`. Do not use production AWS credentials.

### Explore AWS resources using the Floci UI

Floci provides a web interface for exploring the simulated AWS environment.

**Floci UI:** [http://localhost:8080](http://localhost:8080)

After starting Floci, open the UI to inspect the local AWS services and resources, including S3 buckets, ECR repositories, and other provisioned infrastructure.

The UI is optional and is not required to deploy or test the application using PowerShell and the AWS CLI.

### 4. Verify Kubernetes

The deployment script saves a dedicated kubeconfig at:

```text
%USERPROFILE%\.kube\floci-k3s.yaml
```

List Kubernetes nodes:

```powershell
kubectl --kubeconfig "$env:USERPROFILE\.kube\floci-k3s.yaml" get nodes
```

List the application pods:

```powershell
kubectl --kubeconfig "$env:USERPROFILE\.kube\floci-k3s.yaml" get pods -l app=s3uploader
```

Check deployment status:

```powershell
kubectl --kubeconfig "$env:USERPROFILE\.kube\floci-k3s.yaml" rollout status deployment/s3uploader
```

The application pods should be running and ready.

### 5. Test with Postman

Create a new HTTP request with the following configuration:

**Method:** `POST`

**URL:**

```text
http://s3uploader.example.test/api/objects
```

**Header:**

```text
Content-Type: application/json
```

**Body → raw → JSON:**

```json
{
  "name": "postman-test.txt",
  "text": "Uploaded using Postman"
}
```

Click **Send**.

Expected status: **201 Created**.

Then verify the object:

```powershell
aws --endpoint-url=http://localhost:4566 s3 ls s3://awesome-bucket/
```

## Local configuration

The development configuration is stored in:

```text
S3Uploader/appsettings.Development.json
```

Example S3 settings:

```json
{
  "S3": {
    "Endpoint": "http://127.0.0.1:4566",
    "BucketName": "awesome-bucket",
    "Region": "us-east-1",
    "AccessKeyId": "test",
    "SecretAccessKey": "test"
  }
}
```

These are local simulation settings, not production AWS credentials.

The containerized deployment uses the configuration defined in the Kubernetes manifest.

## Cleanup

To remove the deployed application and infrastructure, run:

```powershell
.\infrastructure\scripts\destroy.ps1
```

The script:

1. Deletes the S3Uploader Kubernetes Deployment and Service.
2. Destroys Terraform-managed resources.
3. Stops the Floci Docker Compose environment.
4. Removes the leftover Floci AWS VPC Docker network, if present.

**Warning:** Cleanup destroys the simulated infrastructure and can permanently remove uploaded S3 objects. Back up any data you want to keep before running it.

## Project structure

```text
S3Uploader/
├── S3Uploader/
│   ├── Contracts/
│   ├── Endpoints/
│   ├── Options/
│   ├── Services/
│   ├── Properties/
│   ├── Program.cs
│   ├── S3Uploader.csproj
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   ├── Dockerfile
│   ├── .dockerignore
│   └── deployment.yaml
├── infrastructure/
│   ├── docker-compose.yml
│   ├── terraform/
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── network.tf
│   │   ├── s3.tf
│   │   ├── iam.tf
│   │   ├── ecr.tf
│   │   ├── eks.tf
│   │   ├── alb.tf
│   │   ├── route53.tf
│   │   └── outputs.tf
│   └── scripts/
│       ├── deploy.ps1
│       └── destroy.ps1
├── .gitignore
└── README.md
```

## Notes

- This project is intended for **local development and experimentation**, not production deployment.
- The simulated AWS environment runs in Docker; it does not require a real AWS account.
- Terraform state files are intentionally excluded from Git.
- The deployment currently uses fixed local endpoints and container networking assumptions, so adjustments may be required on another machine.
- Docker Desktop must have sufficient resources available for Floci and the Kubernetes cluster.

## License

No license has been specified for this repository.
