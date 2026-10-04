terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.0.0"
    }

    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.0.0"
    }
  }

  required_version = ">= 1.2"
}