resource "aws_ecr_repository" "main" {
  name = var.application_name

  image_tag_mutability = "MUTABLE"
  force_delete         = true
}