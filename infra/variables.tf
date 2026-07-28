variable "aws_region" {
  description = "AWS region used for regional resources."
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Short name used to identify project resources."
  type        = string
  default     = "cloud-resume"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must contain only lowercase letters, numbers, and hyphens."
  }
}
