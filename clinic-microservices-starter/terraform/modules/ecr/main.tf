resource "aws_ecr_repository" "patient" {
  name                         = "${var.project_name}-patient"
  image_tag_mutability         = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

resource "aws_ecr_repository" "appointment" {
  name                         = "${var.project_name}-appointment"
  image_tag_mutability         = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

output "patient_repo_url"     { value = aws_ecr_repository.patient.repository_url }
output "appointment_repo_url" { value = aws_ecr_repository.appointment.repository_url }
