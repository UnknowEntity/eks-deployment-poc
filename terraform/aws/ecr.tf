module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name = var.ecr_repository_name
  repository_force_delete = true

  repository_read_write_access_arns = [local.account_arn]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = var.tags
}
