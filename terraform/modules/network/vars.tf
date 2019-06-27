variable "vpc_cidr" {
  description = "CIDR for VPC"
  default = "10.0.0.0/26"
}

variable "environment" {
  description = "environment"
  default = "test"
}

variable "public_sn_cidr" {
  type = "list"
  description = "cider for public subnets"
}

variable "private_sn_cidr" {
  type = "list"
  description = "cider for private subnets"
}

variable "availability_zone" {
  type = "list"
  description = "the availability zone for the resources"
}



