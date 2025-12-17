#####################################
# Data Source – AMI
#####################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

#####################################
# Security Groups
#####################################

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

#####################################
# Application Load Balancer
#####################################

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
  vpc_id   = var.vpc_id

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

#####################################
# User Data
#####################################

locals {

  frontend_user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx

    cat << 'HTML' > /usr/share/nginx/html/index.html
    <!DOCTYPE html>
    <html>
    <head>
      <title>3-Tier App</title>
    </head>
    <body>
      <h1>Messages</h1>

      <form id="msgForm">
        <input type="text" id="message" required />
        <button type="submit">Send</button>
      </form>

      <ul id="messages"></ul>

      <script>
        const backendUrl = "http://BACKEND_PRIVATE_IP:8080";

        async function loadMessages() {
          const res = await fetch(backendUrl + "/api/all");
          const data = await res.json();
          const list = document.getElementById("messages");
          list.innerHTML = "";
          data.forEach(m => {
            const li = document.createElement("li");
            li.innerText = m[1];
            list.appendChild(li);
          });
        }

        document.getElementById("msgForm").addEventListener("submit", async e => {
          e.preventDefault();
          const msg = document.getElementById("message").value;

          await fetch(backendUrl + "/api/add", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ message: msg })
          });

          loadMessages();
        });

        loadMessages();
      </script>
    </body>
    </html>
    HTML
    EOF

  backend_user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y python3 pip
    pip3 install flask flask-cors mysql-connector-python

    cat << 'APP' > /home/ec2-user/app.py
    from flask import Flask, request, jsonify
    from flask_cors import CORS
    import mysql.connector
    import os

    app = Flask(__name__)
    CORS(app)

    db_config = {
        "host": os.environ.get("DB_HOST"),
        "user": os.environ.get("DB_USER"),
        "password": os.environ.get("DB_PASS"),
        "database": os.environ.get("DB_NAME")
    }

    @app.route("/health")
    def health():
        return "OK", 200

    @app.route("/api/add", methods=["POST"])
    def add_message():
        data = request.json
        message = data.get("message")

        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute(
            "CREATE TABLE IF NOT EXISTS messages (id INT AUTO_INCREMENT PRIMARY KEY, message TEXT)"
        )
        cursor.execute("INSERT INTO messages (message) VALUES (%s)", (message,))
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({"status": "message added"})

    @app.route("/api/all", methods=["GET"])
    def get_messages():
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute("SELECT id, message FROM messages")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        return jsonify(rows)

    if __name__ == "__main__":
        app.run(host="0.0.0.0", port=8080)
    APP

    export DB_HOST="${var.db_host}"
    export DB_USER="admin"
    export DB_PASS="password123"
    export DB_NAME="appdb"

    python3 /home/ec2-user/app.py &
    EOF
}

#####################################
# Launch Templates
#####################################

resource "aws_launch_template" "frontend_lt" {
  name_prefix   = "frontend-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  user_data              = base64encode(local.frontend_user_data)
}

resource "aws_launch_template" "backend_lt" {
  name_prefix   = "backend-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  user_data              = base64encode(local.backend_user_data)
}

#####################################
# EC2 Instances
#####################################

resource "aws_instance" "frontend" {
  count     = length(var.private_subnets)
  subnet_id = var.private_subnets[count.index]

  launch_template {
    id      = aws_launch_template.frontend_lt.id
    version = "$Latest"
  }

  tags = {
    Name = "frontend-${count.index}"
  }
}

resource "aws_instance" "backend" {
  count     = length(var.private_subnets)
  subnet_id = var.private_subnets[count.index]

  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  tags = {
    Name = "backend-${count.index}"
  }
}

#####################################
# ALB Attachments
#####################################

resource "aws_lb_target_group_attachment" "frontend_attach" {
  count            = length(aws_instance.frontend)
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = aws_instance.frontend[count.index].id
  port             = 80
}
