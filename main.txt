# Provider Configuration
provider "aws" {
  region = "us-east-1"  # Update the region as per your requirement
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create Subnet
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

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Create Security Group for EC2 Instances
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow SSH and HTTP traffic"
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
}

# Create Security Group for alb
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EC2 Instances
resource "aws_instance" "web1" {
  ami           = "ami-053a45fff0a704a47" # Example: Amazon Linux 2 AMI ID (update this as per your region)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_a.id
  #SecurityGroupIds = [ws_security_group.ec2_sg.id]
  security_groups = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "WebServer-1"
  }

  user_data = <<-EOF
              #cloud-boothook
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Hello friend! This is $(hostname -f)</h1>" | sudo tee /var/www/html/index.html > /dev/null
              EOF
}

resource "aws_instance" "web2" {
  ami           = "ami-053a45fff0a704a47" # Example: Amazon Linux 2 AMI ID (update this as per your region)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_b.id
  #SecurityGroupIds = [ws_security_group.ec2_sg.id]
  security_groups = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "WebServer-2"
  }

  user_data = <<-EOF
              #cloud-boothook
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Hello friend! This is $(hostname -f)</h1>" | sudo tee /var/www/html/index.html > /dev/null
              EOF
}

# Create Application Load Balancer
resource "aws_lb" "alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups   = [aws_security_group.alb_sg.id]
  subnets           = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  enable_deletion_protection = false

  enable_http2 = true
}

# Create Target Group for ALB
resource "aws_lb_target_group" "target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Create Listener for ALB
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# Register EC2 Instances to the Target Group
resource "aws_lb_target_group_attachment" "web_target1" {
  target_group_arn   = aws_lb_target_group.target_group.arn
  target_id          = aws_instance.web1.id
  port               = 80
}

resource "aws_lb_target_group_attachment" "web_target2" {
  target_group_arn   = aws_lb_target_group.target_group.arn
  target_id          = aws_instance.web2.id
  port               = 80
}