variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "network_cidr" {
  description = "VPC CIDR"
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "AZs"
  default     = ["us-east-1a", "us-east-1b"]
}
