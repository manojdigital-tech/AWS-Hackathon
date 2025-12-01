resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
  setting { name = "containerInsights", value = "enabled" }
}

resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "patient" {
  name        = "${var.project_name}-tg-patient"
  port        = 3001
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check { path = "/health" }
}

resource "aws_lb_target_group" "appointment" {
  name        = "${var.project_name}-tg-appointment"
  port        = 3002
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check { path = "/health" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response { content_type = "text/plain", message_body = "Route not found", status_code = "404" }
  }
}

resource "aws_lb_listener_rule" "patient_rule" {
  listener_arn = aws_lb_listener.http.arn
  action { type = "forward", target_group_arn = aws_lb_target_group.patient.arn }
  condition { path_pattern { values = ["/patient*", "/health"] } }
}

resource "aws_lb_listener_rule" "appointment_rule" {
  listener_arn = aws_lb_listener.http.arn
  action { type = "forward", target_group_arn = aws_lb_target_group.appointment.arn }
  condition { path_pattern { values = ["/appointment*"] } }
}

resource "aws_cloudwatch_log_group" "patient" {
  name              = "/ecs/${var.project_name}/patient"
  retention_in_days = 14
}
resource "aws_cloudwatch_log_group" "appointment" {
  name              = "/ecs/${var.project_name}/appointment"
  retention_in_days = 14
}

resource "aws_security_group" "svc" {
  name   = "${var.project_name}-svc-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_lb.alb.security_groups[0]]
    description     = "From ALB"
  }
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_ecs_task_definition" "patient" {
  family                   = "${var.project_name}-patient"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_exec_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name      = "patient"
    image     = "${var.ecr_patient_repo_url}:latest"
    essential = true
    portMappings = [{ containerPort = 3001, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.patient.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
    environment = [{ name = "NODE_ENV", value = "production" }]
  }])
}

resource "aws_ecs_task_definition" "appointment" {
  family                   = "${var.project_name}-appointment"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_exec_role_arn
  task_role_arn            = var.task_role_arn
  container_definitions = jsonencode([{
    name      = "appointment"
    image     = "${var.ecr_appointment_repo_url}:latest"
    essential = true
    portMappings = [{ containerPort = 3002, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.appointment.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
    environment = [{ name = "NODE_ENV", value = "production" }]
  }])
}

resource "aws_ecs_service" "patient" {
  name            = "${var.project_name}-patient"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.patient.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.patient.arn
    container_name   = "patient"
    container_port   = 3001
  }
  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "appointment" {
  name            = "${var.project_name}-appointment"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.appointment.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.appointment.arn
    container_name   = "appointment"
    container_port   = 3002
  }
  depends_on = [aws_lb_listener.http]
}

output "alb_dns_name" { value = aws_lb.alb.dns_name }
output "cluster_name" { value = aws_ecs_cluster.this.name }
output "alb_arn"      { value = aws_lb.alb.arn }
