variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "redhat_ami" {
  description = "AMI ID for Red Hat Linux"
  type        = string
}

variable "images_bucket_name" {
  description = "Name of the S3 bucket for images"
  type        = string
}

variable "logs_bucket_name" {
  description = "Name of the S3 bucket for logs"
  type        = string
}

variable "allowed_ips" {
  description = "Public IP allowed"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID for simulation"
  type        = string
  default     = "123456789012"
}

variable "availability_zones" {
  description = "AZs list for testing purpose"
  type        = list(string)
  default     = ["us-east-1a","us-east-1b"]
}