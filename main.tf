provider "aws" {
  region = "us-east-1"  # Specify your AWS region
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


resource "aws_instance" "web_server" {
  ami           = "ami-053a45fff0a704a47"  # Specify the AMI ID (e.g., Amazon Linux 2 or Ubuntu)
  instance_type = "t2.micro"      # Choose the desired instance type
  key_name      = "mymachinekeypair" # Specify your SSH key for access
  security_groups = [aws_security_group.instance_sg.id]
  subnet_id     = aws_subnet.subnet_a.id
  # User data to install NGINX and configure a custom index page
  user_data = <<-EOF
              #!/bin/bash
              # Log start of user data execution
              echo "Starting user data script" > /tmp/user_data.log
              
              # Update the instance
              yum update -y >> /tmp/user_data.log 2>&1

              # Install NGINX
              amazon-linux-extras enable nginx1 >> /tmp/user_data.log 2>&1
              yum install -y nginx >> /tmp/user_data.log 2>&1

              # Start NGINX service
              systemctl start nginx >> /tmp/user_data.log 2>&1
              systemctl enable nginx >> /tmp/user_data.log 2>&1

              # Create a custom index.html page
              echo "<html><body><h1>Welcome to My Custom NGINX Server</h1></body></html>" > /usr/share/nginx/html/index.html

              # Log end of user data execution
              echo "User data script finished" >> /tmp/user_data.log
            EOF

  # Optional: Add tags to the instance
  tags = {
    Name = "nginx-web-server"
  }

  # If using a VPC, you might need to provide subnet_id, etc.
  # subnet_id = "subnet-xxxxxxxx"
}
