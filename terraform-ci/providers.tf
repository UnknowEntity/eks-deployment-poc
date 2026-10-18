provider "aws" {
  region  = var.region
  assume_role {
    role_arn     = var.provider_assume_role_arn
    session_name = "terraform-session-temporary"
  }
}