output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "frontend_sg_id" {
  value = aws_security_group.frontend_sg.id
}

output "backend_sg_id" {
  value = aws_security_group.backend_sg.id
}
output "alb_dns_name" {
  value = aws_lb.frontend_alb.dns_name
}

output "frontend_tg_arn" {
  value = aws_lb_target_group.frontend_tg.arn
}
