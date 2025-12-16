resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}
resource "aws_security_group" "frontend_sg" {
  name   = "frontend-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "frontend-sg"
  }
}
resource "aws_security_group" "backend_sg" {
  name   = "backend-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}
resource "aws_lb" "frontend_alb" {
  name               = "frontend-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.alb_sg.id]
  subnets         = var.public_subnets

  tags = {
    Name = "frontend-alb"
  }
}
resource "aws_lb_target_group" "frontend_tg" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id  = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "frontend-tg"
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}
