terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.26.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
 }


# VPC Resource
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "avengers VPC"
  }
}



# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "avengers-internet-gateway"
  }
}

//Creating subnets - Public for Webservers, Private for Application and DB

# Public Subnet
resource "aws_subnet" "public_subnet" {
  for_each = var.az_public_subnet

  vpc_id = aws_vpc.main.id

  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "avengers-public-subnet-${each.key}"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  for_each = var.az_private_subnet

  vpc_id = aws_vpc.main.id

  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "avengers-private-subnet-${each.key}"
  }
}

# Database Subnet
resource "aws_subnet" "database_subnet" {
  for_each = var.az_database_subnet

  vpc_id = aws_vpc.main.id

  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "avengers-database-subnet-${each.key}"
  }
}

//Define Route Table entries and Associate them with the Subnets

# Route Table 
resource "aws_route_table" "public_subnet_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public-subnet-route-table"
  }
}

# Public subnet route table association
resource "aws_route_table_association" "public_subnet_route_table_association" {
  for_each = var.az_public_subnet

  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.public_subnet_route_table.id
}

//Create the ALB for Web servers

# Web - Application Load Balancer
resource "aws_lb" "app_lb" {
  name = "app-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_http.id]
  subnets = [for value in aws_subnet.public_subnet: value.id]
}

# Web - ALB Security Group
resource "aws_security_group" "alb_http" {
  name        = "alb-security-group"
  description = "Allowing HTTP requests to the application load balancer"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-security-group"
  }
}


# Web - Listener
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

# Web - Target Group
resource "aws_lb_target_group" "web_target_group" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    port     = 80
    protocol = "HTTP"
  }
}

# Web - EC2 Instance Security Group
resource "aws_security_group" "web_instance_sg" {
  name        = "web-server-security-group"
  description = "Allowing requests to the web servers"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_http.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-security-group"
  }
}

# Web - Launch Template
resource "aws_launch_template" "web_launch_template" {
  name_prefix   = "web-launch-template"
  image_id      = "ami-0e2e44c03b85f58b3"
  instance_type = "t2.micro"
}

# Web - Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity   = 0
  max_size           = 0
  min_size           = 0
  target_group_arns = [aws_lb_target_group.web_target_group.arn]
  vpc_zone_identifier = [for value in aws_subnet.public_subnet: value.id]

  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = "$Latest"
  }
}


//Load Balancer and Security Groups

# App - ALB Security Group
resource "aws_security_group" "alb_app_http" {
  name        = "alb-app-security-group"
  description = "Allowing HTTP requests to the app tier application load balancer"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.web_instance_sg.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-app-security-group"
  }
}

# App - Application Load Balancer
resource "aws_lb" "app_app_lb" {
  name = "app-app-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_app_http.id]
  subnets = [for value in aws_subnet.private_subnet: value.id]
}

# App - Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

# App - Target Group
resource "aws_lb_target_group" "app_target_group" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    port     = 80
    protocol = "HTTP"
  }
}

//Auto scaling and Launch Templates

# App - EC2 Instance Security Group
resource "aws_security_group" "app_instance_sg" {
  name        = "app-server-security-group"
  description = "Allowing requests to the app servers"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_app_http.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-server-security-group"
  }
}

# App - Launch Template
resource "aws_launch_template" "app_launch_template" {
  name_prefix   = "app-launch-template"
  image_id      = "ami-0e2e44c03b85f58b3"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.app_instance_sg.id]
}

# App - Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity   = 0
  max_size           = 0
  min_size           = 0
  target_group_arns = [aws_lb_target_group.app_target_group.arn]
  vpc_zone_identifier = [for value in aws_subnet.private_subnet: value.id]

  launch_template {
    id      = aws_launch_template.app_launch_template.id
    version = "$Latest"
  }
}

# DB - Security Group
resource "aws_security_group" "db_security_group" {
  name = "mydb1"

  description = "RDS postgres server"
  vpc_id = aws_vpc.main.id

  # Only postgres in
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.app_instance_sg.id]
  }

  # Allow all outbound traffic.
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB - Subnet Group
resource "aws_db_subnet_group" "db_subnet" {
  name       = "db-subnet"
  subnet_ids = [for value in aws_subnet.database_subnet: value.id]

  tags = {
    Name = "My DB subnet group"
  }
}

# DB - RDS Instance
resource "aws_db_instance" "db_postgres" {
  allocated_storage        = 256 # gigabytes
  backup_retention_period  = 7   # in days
  db_subnet_group_name     = aws_db_subnet_group.db_subnet.name
  engine                   = "postgres"
  engine_version           = "12.4"
  identifier               = "dbpostgres"
  instance_class           = "db.t3.micro"
  multi_az                 = false
  name                     = "dbpostgres"
  username                 = "dbadmin"
  password                 = "XXXYYYZZZ"
  port                     = 5432
  publicly_accessible      = false
  storage_encrypted        = true
  storage_type             = "gp2"
  vpc_security_group_ids   = [aws_security_group.db_security_group.id]
  skip_final_snapshot      = true
}

