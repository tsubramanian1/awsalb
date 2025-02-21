terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.87.0"
    }
  }

  required_version = ">= 1.2.0"
}
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

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
}

resource "aws_security_group" "instance_sg" {
  name        = "instance_sg"
  description = "Security group for instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

resource "aws_internet_gateway" "my_internet_gateway" {
    vpc_id = aws_vpc.main.id
      tags = {
            Name = "My-Internet-Gateway"
              }
            }
resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.main.id
      tags = {
            Name = "Public Route Table"
              }
            }

resource "aws_route" "internet_route" {
    route_table_id = aws_route_table.public_route_table.id
      destination_cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_internet_gateway.id
      }

resource "aws_lb" "main" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_instance" "web1" {
  ami           = "ami-053a45fff0a704a47" # Use a valid AMI for your region
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance_sg.id]
  subnet_id     = aws_subnet.subnet_a.id
  tags = {
    Name = "web1"
  }
  user_data = <<-EOF
        #cloud-boothook
        #!/bin/bash
        if ! sudo yum update -y; then
          echo "YUM update failed"
          exit 1
        fi
        sudo yum install -y httpd
        sudo systemctl start httpd
        if ! sudo systemctl is-active --quiet httpd; then
          echo "Apache failed to start"
          exit 1
        fi
        sudo systemctl enable httpd
        echo "<h1>Hello friend! This is $(hostname -f)</h1>" | sudo tee /var/www/html/index.html > /dev/null
    EOF
}


resource "aws_instance" "web2" {
  ami           = "ami-053a45fff0a704a47" # Use a valid AMI for your region
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance_sg.id]
  subnet_id     = aws_subnet.subnet_b.id
  tags = {
    Name = "web2"
  }
  user_data = <<-EOT
          #cloud-boothook
          #!/bin/bash
          if ! sudo yum update -y; then
             echo "YUM update failed"
             exit 1
          fi
          sudo yum install -y httpd
          sudo systemctl start httpd
          if ! sudo systemctl is-active --quiet httpd; then
             echo "Apache failed to start"
             exit 1
          fi
          sudo systemctl enable httpd
          echo "<h1>Hello friend! This is $(hostname -f)</h1>" | sudo tee /var/www/html/index.html > /dev/null
      EOT
}

resource "aws_lb_target_group_attachment" "web1_attachment" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web2_attachment" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}
