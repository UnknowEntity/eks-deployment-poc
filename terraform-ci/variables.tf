# AWS variables

variable "provider_assume_role_arn" {
  type        = string
  description = "The ARN of the role to assume for the AWS provider"
  sensitive   = true
}

variable "region" {
  type        = string
  description = "The AWS region to deploy resources in"
  default     = "ap-southeast-1"
  sensitive   = false
}

variable "aws_profile" {
  type        = string
  description = "The AWS CLI profile to use"
  default     = "default"
  sensitive   = false
}

# GitHub variables
variable "github_username" {
  description = "The GitHub username"
  type        = string
}

variable "github_user_id" {
  description = "The GitHub user ID (use curl -s https://api.github.com/users/<username> | jq .id)"
  type        = string
}

variable "github_repository" {
  description = "The GitHub repository name"
  type        = string
}

variable "github_repository_id" {
  description = "The GitHub repository ID (use curl -s https://api.github.com/repos/<username>/<repository> | jq .id)"
  type        = string
}

variable "environment_name" {
  description = "The GitHub environment name"
  type        = string
}