output "alb_dns_name"         { value = module.ecs.alb_dns_name }
output "ecr_patient_repo"     { value = module.ecr.patient_repo_url }
output "ecr_appointment_repo" { value = module.ecr.appointment_repo_url }
