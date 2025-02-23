variable "vpc_id" {
  description = "ID of the existing VPC where resources will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of existing subnet IDs for ALB and Auto Scaling Group"
  type        = list(string)
}

variable "key_name" {
  description = "Name of an existing EC2 Key Pair for SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "desired_capacity" {
  description = "Initial number of instances in Auto Scaling Group"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances in Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in Auto Scaling Group"
  type        = number
  default     = 5
}

variable "account_number" {
  description = "AWS account number (without dashes) for S3 bucket policy"
  type        = string
}

variable "images_bucket_name" {
  description = "Name for the S3 bucket to store images"
  type        = string
  default     = "employee-directory-web-app"
}