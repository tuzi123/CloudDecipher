output "repository_url" {
  value = "${aws_ecr_repository.decipher.repository_url}"
}

output "security_group_id" {
  value = "${aws_security_group.ecs_service.id}"
}

output "cluster_name" {
  value = "${aws_ecs_cluster.ecs_cluster.name}"
}

output "service_name" {
  value = "${aws_ecs_service.app.name}"
}

output "alb_dns_name" {
  value = "${aws_alb.alb.dns_name}"
}