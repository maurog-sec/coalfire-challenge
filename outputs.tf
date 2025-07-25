output "vpc_id" {
  description = "The VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "List of public subnets"
  value       = module.vpc.public_subnets
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.dns_name
}
