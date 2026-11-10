terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Compliance tags applied to every resource that supports tagging.
  # Auto Scaling groups are the exception: they need explicit tag blocks
  # (see compute.tf), and the launch template tags the instances and volumes.
  default_tags {
    tags = local.common_tags
  }
}
