
locals {
  availability_zones = ["us-west-2a", "us-west-2b"]
}
provider "aws" {
  region = "${var.aws_region}"
}

module "network" {
  source = "./modules/network"
  availability_zone = "${local.availability_zones}"
  vpc_cidr = "${var.vpc_cidr}"
  public_sn_cidr = ["10.0.1.0/24", "10.0.2.0/24"]
  private_sn_cidr = ["10.0.10.0/24", "10.0.20.0/24"]
}

module "ecs" {
  source = "./modules/ecs"
  vpc_id = "${module.network.vpd_id}"
  public_sn_ids = ["${module.network.public_sn_id}"]
  security_groups_ids = "${module.network.security_groups_ids}"
  subnets_id = ["${module.network.private_sn_id}"]
}

module "pipeline" {
  source = "./modules/pipeline"
  repository_url = "${module.ecs.repository_url}"
  region = "${var.aws_region}"
  ecs_service_name = "${module.ecs.service_name}"
  ecs_cluster_name = "${module.ecs.cluster_name}"
  task_subnet_id = "${module.network.private_sn_id[0]}"
  task_security_group_ids = ["${module.network.security_groups_ids}", "${module.ecs.security_group_id}"]
}




