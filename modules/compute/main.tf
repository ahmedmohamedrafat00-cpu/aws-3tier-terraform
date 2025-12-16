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
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
locals {
  frontend_user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y nginx
              systemctl enable nginx
              systemctl start nginx

              echo "<h1>Frontend Tier - AWS 3 Tier Architecture</h1>" > /usr/share/nginx/html/index.html
              EOF
}
locals {
  backend_user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y python3

              cat << 'APP' > /home/ec2-user/app.py
              from http.server import BaseHTTPRequestHandler, HTTPServer

              class Handler(BaseHTTPRequestHandler):
                  def do_GET(self):
                      self.send_response(200)
                      self.send_header("Content-type", "text/plain")
                      self.end_headers()
                      self.wfile.write(b"Hello from Backend Tier")

              HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
              APP

              python3 /home/ec2-user/app.py &
              EOF
}
resource "aws_launch_template" "backend_lt" {
  name_prefix   = "backend-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [
    aws_security_group.backend_sg.id
  ]

  user_data = base64encode(local.backend_user_data)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "backend-instance"
    }
  }
}
resource "aws_instance" "backend" {
  count = length(var.private_subnets)

  subnet_id = var.private_subnets[count.index]

  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  tags = {
    Name = "backend-${count.index}"
  }
}

resource "aws_launch_template" "frontend_lt" {
  name_prefix   = "frontend-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [
    aws_security_group.frontend_sg.id
  ]

  user_data = base64encode(local.frontend_user_data)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "frontend-instance"
    }
  }
}
resource "aws_instance" "frontend" {
  count = length(var.private_subnets)

  subnet_id = var.private_subnets[count.index]

  launch_template {
    id      = aws_launch_template.frontend_lt.id
    version = "$Latest"
  }

  tags = {
    Name = "frontend-${count.index}"
  }
}
resource "aws_lb_target_group_attachment" "frontend_attach" {
  count            = length(aws_instance.frontend)
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = aws_instance.frontend[count.index].id
  port             = 80
}
