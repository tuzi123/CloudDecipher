output "vpd_id" {
  value = "${aws_vpc.vpc.id}"
}

output "public_sn_id" {
  value = ["${aws_subnet.public_sn.*.id}"]
}

output "private_sn_id" {
  value = ["${aws_subnet.private_sn.*.id}"]
}

output "default_sg_id" {
  value = "${aws_security_group.default-sg.id}"
}

output "security_groups_ids" {
  value = ["${aws_security_group.default-sg.id}"]
}
