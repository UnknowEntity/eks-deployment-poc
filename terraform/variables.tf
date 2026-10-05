variable "admin_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access the EKS API for the cluster"
  sensitive   = true
}

variable "provider_assume_role_arn" {
  type = string
  description = "The ARN of the role to assume for the AWS provider"
  sensitive = true
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