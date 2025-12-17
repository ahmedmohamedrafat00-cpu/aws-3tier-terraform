variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}
variable "instance_type" {
  description = "EC2 instance type for frontend"
  type        = string
  default     = "t3.micro"
}
variable "db_host" {
  description = "RDS endpoint"
  type        = string
}
variable "my_ip" {
  description = "My public IP for SSH access"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

