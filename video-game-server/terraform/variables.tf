# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1" # Change as needed
}

variable "name_prefix" {
  description = "Prefix used in resource names"
  type        = string
  default     = "minecraft"
}

# ---------------------------------------------------------------------------
# Compliance tags
# ---------------------------------------------------------------------------

variable "service" {
  description = "Value of the Service tag"
  type        = string
  default     = "minecraft-game-server"

  validation {
    condition     = length(trimspace(var.service)) > 0
    error_message = "The Service tag must not be empty."
  }
}

variable "environment" {
  description = "Value of the Environment tag (dev, staging or prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "team" {
  description = "Value of the Team tag"
  type        = string
  default     = "cloud-platform-team"

  validation {
    condition     = length(trimspace(var.team)) > 0
    error_message = "The Team tag must not be empty."
  }
}

variable "owner" {
  description = "Value of the Owner tag (person or email accountable for the resources)"
  type        = string
  default     = "ana.torres@example.com"

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "The Owner tag must not be empty."
  }
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet per Availability Zone (at least 2)"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "Provide at least two subnets so the servers span two Availability Zones."
  }
}

variable "allowed_player_cidrs" {
  description = "CIDR blocks allowed to connect to the game port. Restrict this to your friends' IPs if you can."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# Minecraft server
# ---------------------------------------------------------------------------

variable "accept_minecraft_eula" {
  description = "You must accept the Minecraft EULA (https://aka.ms/MinecraftEULA) to run the server"
  type        = bool
  default     = false

  validation {
    condition     = var.accept_minecraft_eula
    error_message = "Set accept_minecraft_eula = true to confirm you accept the Minecraft EULA (https://aka.ms/MinecraftEULA)."
  }
}

variable "minecraft_version" {
  description = "Minecraft Java Edition server version, for example \"1.21.4\", or \"latest\" for the newest release"
  type        = string
  default     = "latest"
}

variable "server_port" {
  description = "TCP port the Minecraft server listens on"
  type        = number
  default     = 25565
}

variable "max_players_per_server" {
  description = "max-players value in server.properties"
  type        = number
  default     = 20
}

variable "motd" {
  description = "Message shown in the Minecraft server list"
  type        = string
  default     = "AWS Mini Projects Minecraft Server"
}

variable "difficulty" {
  description = "Game difficulty: peaceful, easy, normal or hard"
  type        = string
  default     = "normal"

  validation {
    condition     = contains(["peaceful", "easy", "normal", "hard"], var.difficulty)
    error_message = "Difficulty must be one of: peaceful, easy, normal, hard."
  }
}

variable "instance_type" {
  description = "EC2 instance type for each game server"
  type        = string
  default     = "t3.medium"
}

variable "java_heap_mb" {
  description = "Java heap size in MB. Leave about 1 GB of the instance's memory for the OS."
  type        = number
  default     = 3072
}

variable "root_volume_size_gb" {
  description = "Size of the root EBS volume, which also holds the world"
  type        = number
  default     = 20
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Days to keep logs in CloudWatch Logs (0 keeps them forever)"
  type        = number
  default     = 30

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days
    )
    error_message = "log_retention_days must be a value CloudWatch Logs supports, for example 7, 30, 90 or 365."
  }
}

variable "enable_vpc_flow_logs" {
  description = "Record network traffic in the VPC to CloudWatch Logs"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Auto scaling
# ---------------------------------------------------------------------------

variable "min_servers" {
  description = "Minimum number of game servers"
  type        = number
  default     = 1
}

variable "max_servers" {
  description = "Maximum number of game servers"
  type        = number
  default     = 4
}

variable "desired_servers" {
  description = "Number of game servers at launch"
  type        = number
  default     = 1
}

variable "target_players_per_server" {
  description = "Scale out when the average number of players per server goes above this value"
  type        = number
  default     = 10
}

variable "target_cpu_percent" {
  description = "Scale out when the average CPU utilization goes above this value"
  type        = number
  default     = 70
}
