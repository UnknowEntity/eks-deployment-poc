output "aws_config" {
  description = "AWS configuration for GitHub Actions"

  value = {
    role_arn = aws_iam_role.github_actions.arn
    region   = var.region
  }
}