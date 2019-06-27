variable "repository_url" {
  description = "ECR repository url"
}

variable "region" {
  description = "vpc region"
}

variable "ecs_cluster_name" {
  description = "ecs cluster name"
}

variable "task_subnet_id" {
  description = "task subnet id"
}

variable "task_security_group_ids" {
  type = "list"
  description = "security group id of task"
}

variable "ecs_service_name" {
  description = "ecr service name"
}