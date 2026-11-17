variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_endpoint" {
  description = "Local Floci endpoint"
  type        = string
  default     = "http://localhost:4566"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "application_name" {
  description = "Application name"
  type        = string
  default     = "s3uploader"
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "awesome-bucket"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "dev-cluster"
}