variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "ami_id" {
  description = "Valid AMI ID for the target region"
  type        = string
  default     = "ami-00000000000000000"

  validation {
    condition     = can(regex("^ami-[0-9a-f]{17}$", var.ami_id))
    error_message = "AMI ID must match the expected format."
  }
}
