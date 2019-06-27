
variable "docker_image" {
  description = "the name of the application docker image"
  default = "decipher-image"
}

variable "environment" {
  description = "environment"
  default = "test"
}

variable "app_port" {
  description = "the port of the app"
  default = "5000"
}

variable "vpc_id" {
  description = "vpc id"
}

variable "public_sn_ids" {
  type = "list"
  description = "public subnet ids"
}

variable "security_groups_ids" {
  type = "list"
  description = "security groups id"
}

variable "subnets_id" {
  type = "list"
  description = "subnet ids"
}


