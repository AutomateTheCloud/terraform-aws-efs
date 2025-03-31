variable "encryption" {
  description = "Encryption"
  type        = any
  default     = null
}

variable "lifecycle_transition_to_ia" {
  description = "Lifecycle Policy: Transition files to IA Storage Class (AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS)"
  type        = string
  default     = ""
}

variable "performance_mode" {
  description = "EFS Performance Mode (generalPurpose, maxIO)"
  type        = string
  default     = "generalPurpose"
}

variable "provisioned_throughput" {
  description = "EFS Provisioned Throughput (in MiBPS)"
  type        = number
  default     = null
}

variable "security_group_access" {
  description = "Security Group Access sources"
  type        = list(any)
  default     = []
}

variable "subnets" {
  description = "Subnet IDs for Mount Targets"
  type        = list(any)
  default     = []
  validation {
    condition     = length(var.subnets) > 0
    error_message = "Subnet IDs not Specified."
  }
}

variable "vpc_id" {
  description = "VPC: ID"
  type        = string
  default     = ""
  validation {
    condition     = var.vpc_id != ""
    error_message = "VPC ID not Specified."
  }
}
