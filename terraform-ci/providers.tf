provider "aws" {
  region = var.region
  default_tags {
    tags = {
      GithubRepo = var.github_repository
      GithubOrg  = var.github_username
    }
  }
  assume_role {
    role_arn     = var.provider_assume_role_arn
    session_name = "terraform-session-temporary"
  }
}