# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used in resource names"
  type        = string
  default     = "macos"
}

variable "tags" {
  description = "Extra tags applied to every resource"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

variable "availability_zone" {
  description = "AZ for the dedicated host. It must offer mac2.metal (see README). Null uses the region's second AZ (us-east-1b in us-east-1)."
  type        = string
  default     = null
}

variable "host_id" {
  description = "ID of an existing mac2 dedicated host (h-...). Null makes Terraform allocate one. When set, the host's AZ is used and availability_zone is ignored."
  type        = string
  default     = null

  validation {
    condition     = var.host_id == null || can(regex("^h-[0-9a-f]+$", var.host_id))
    error_message = "host_id must look like h-0123456789abcdef0."
  }
}

variable "subnet_id" {
  description = "Subnet for the instance, in availability_zone. Null uses the default VPC's default subnet for that AZ."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Instance
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "Mac instance type (the host is allocated for the same type)"
  type        = string
  default     = "mac2.metal"
}

variable "mac_ami_ssm_parameter" {
  description = "Public SSM parameter holding the macOS AMI ID (arm64 for Apple silicon types)"
  type        = string
  default     = "/aws/service/ec2-macos/sequoia/arm64_mac/latest/image_id"
}

# ---------------------------------------------------------------------------
# Remote access
# ---------------------------------------------------------------------------

variable "allowed_vnc_cidr" {
  description = "Optional CIDR allowed to reach VNC on port 5900. Null opens no port; connect through the SSM tunnel."
  type        = string
  default     = null

  validation {
    condition     = var.allowed_vnc_cidr == null || can(cidrhost(var.allowed_vnc_cidr, 0))
    error_message = "allowed_vnc_cidr must be null or a CIDR such as 203.0.113.10/32."
  }
}

variable "remote_username" {
  description = "Username for remote desktop (Screen Sharing) access"
  type        = string
  default     = "remoteuser"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]{0,30}$", var.remote_username))
    error_message = "Lowercase letters, digits and underscores, starting with a letter or underscore."
  }
}

variable "remote_user_password" {
  description = "Password for the remote desktop user"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-zA-Z0-9@#%^&*]{8,64}$", var.remote_user_password))
    error_message = "8-64 characters: letters, digits and @#%^&* only (no accents or spaces)."
  }
}
