variable "aws_region" {
  description = "aws region to launch server"
  default = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  default = "10.0.0.0/16"
}

