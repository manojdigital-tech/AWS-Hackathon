data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service", identifiers = ["ecs-tasks.amazonaws.com"] }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attachment" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-ecsTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

output "task_exec_role_arn" { value = aws_iam_role.ecs_task_execution.arn }
output "task_role_arn"      { value = aws_iam_role.ecs_task_role.arn }
