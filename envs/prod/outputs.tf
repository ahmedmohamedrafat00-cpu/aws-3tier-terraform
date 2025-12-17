output "alb_dns_name" {
  description = "Public DNS name of the frontend ALB"
  value       = module.compute.alb_dns_name
}

output "db_endpoint" {
  description = "RDS MySQL endpoint"
  value       = module.database.db_endpoint
}
