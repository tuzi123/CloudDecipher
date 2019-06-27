
// repo for app docker image
resource "aws_ecr_repository" "decipher" {
  name = "${var.docker_image}"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.environment}-ecs-cluster"
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = "log_group"

  tags {
    Application = "log_group"
  }
}

data "template_file" "app" {
  template = "${file("${path.module}/template/app_task.json")}"

  vars {
    image = "${aws_ecr_repository.decipher.repository_url}"
    app_port = "${var.app_port}"
    log_group = "${aws_cloudwatch_log_group.log_group.name}"
  }
}

resource "aws_ecs_task_definition" "app" {
  container_definitions = "${data.template_file.app.rendered}"
  family = "${var.environment}-app-task"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "512"
  memory = "1024"
  execution_role_arn = "${aws_iam_role.ecs_execution_role.arn}"
  task_role_arn = "${aws_iam_role.ecs_execution_role.arn}"
}


resource "aws_ecs_service" "app" {
  name = "${var.environment}-app"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count = 2
  cluster = "${aws_ecs_cluster.ecs_cluster.id}"
  launch_type = "FARGATE"
  depends_on = ["aws_iam_role_policy.ecs_service_role_policy", "aws_alb_target_group.alb_target_group"]


  network_configuration {
    security_groups = ["${var.security_groups_ids}", "${aws_security_group.ecs_service.id}"]
    subnets         = ["${var.subnets_id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    container_name   = "app"
    container_port   = "${var.app_port}"
  }
}

/* ECS iam roles */
data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_role" {
  name               = "ecs_role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_role.json}"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress"
    ]
  }
}

/* ecs service scheduler role */
resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "ecs_service_role_policy"
  policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
  role   = "${aws_iam_role.ecs_role.id}"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-role"
  assume_role_policy = "${file("${path.module}/policies/ecs-task-execution-role.json")}"
}

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name   = "ecs_execution_role_policy"
  policy = "${file("${path.module}/policies/ecs-execution-role-policy.json")}"
  role   = "${aws_iam_role.ecs_execution_role.id}"
}


//-------------------------------------
//ALB
//-------------------------------------

resource "aws_alb" "alb" {
  name = "${var.environment}-alb"
  subnets = ["${var.public_sn_ids}"]
  security_groups = ["${var.security_groups_ids}", "${aws_security_group.lb.id}"]
}

// lb on public subnet
resource "random_id" "target_group_sufix" {
  byte_length = 2
}

resource "aws_alb_target_group" "alb_target_group" {
  name = "${var.environment}-alb-target-group-${random_id.target_group_sufix.hex}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${var.vpc_id}"
  target_type = "ip"
  depends_on = ["aws_alb.alb"]

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path = "/"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
    timeout = "3"
    interval = "30"
    matcher = "200,301,302"
  }
}

// redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "alb_frontend" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port = "80"//"${var.app_port}"
  protocol = "HTTP"
  depends_on = ["aws_alb_target_group.alb_target_group"]
  default_action {
    target_group_arn = "${aws_alb_target_group.alb_target_group.arn}"
    type = "forward"
  }
}

//-----------------------------------------------------
//Security Group
//--------------------------------------------------------

// security group for lb
resource "aws_security_group" "lb" {
  name = "${var.environment}-lb-sequrity-group"
  description = "access control to ALB"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "ecs_service" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.environment}-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "${var.app_port}"
    to_port     = "${var.app_port}"
    protocol    = "tcp"
    security_groups = ["${aws_security_group.lb.id}"]
    cidr_blocks = ["0.0.0.0/0"]
  }

}


//-----------------------------------------------------
//Auto Scale and CloudWatch
//--------------------------------------------------------

// auto scaling policy
resource "aws_iam_role" "ecs_autoscale_role" {
  name               = "${var.environment}_ecs_autoscale_role"
  assume_role_policy = "${file("${path.module}/policies/ecs-autoscale-role.json")}"
}

resource "aws_iam_role_policy" "ecs_autoscale_role_policy" {
  name   = "ecs_autoscale_role_policy"
  policy = "${file("${path.module}/policies/ecs-autoscale-role-policy.json")}"
  role   = "${aws_iam_role.ecs_autoscale_role.id}"
}

resource "aws_appautoscaling_target" "target" {
  max_capacity = 4
  min_capacity = 2
  resource_id = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
  role_arn = "${aws_iam_role.ecs_autoscale_role.arn}"
}

// automatically scale capacity up by one
resource "aws_appautoscaling_policy" "up" {
  name                    = "${var.environment}_scale_up"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.app.name}"
  scalable_dimension      = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.target"]
}

// automatically scale capacity down by one
resource "aws_appautoscaling_policy" "down" {
  name                    = "${var.environment}_scale_down"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.app.name}"
  scalable_dimension      = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.target"]
}

// cloudWatch alarm that triggers the autoscaling up
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "app_cpu_utilization_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "85"

  dimensions = {
    ClusterName = "${aws_ecs_cluster.ecs_cluster.name}"
    ServiceName = "${aws_ecs_service.app.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.up.arn}"]
}

// cloudWatch alarm that triggers the autoscaling down
resource "aws_cloudwatch_metric_alarm" "service_cpu_low" {
  alarm_name          = "app_cpu_utilization_low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "10"

  dimensions = {
    ClusterName = "${aws_ecs_cluster.ecs_cluster.name}"
    ServiceName = "${aws_ecs_service.app.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.down.arn}"]
}


