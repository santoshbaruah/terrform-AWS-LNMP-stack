terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
 
}

# Create a VPC
resource "aws_vpc" "app_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "app-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "vpc_igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone = "eu-central-1a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "public_rt_asso" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_instance" "web" {
  ami           = "ami-0233214e13e500f77"
  instance_type = var.instance_type
  key_name = var.instance_key
  subnet_id              = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.sg.id]

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing LNMP"
  sudo yum update -y
  sudo yum install nginx -y
  sudo curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
  sudo bash mariadb_repo_setup --os-type=rhel --os-version=7 --mariadb-server-version=10.6
  sudo yum install MariaDB-server MariaDB-client
  sudo systemctl enable --now mariadb
  sudo yum install amazon-linux-extras
  sudo amazon-linux-extras enable php8.0
  yum clean metadata
  sudo yum install php php-cli php-mysqlnd php-pdo php-common php-fpm -y
  sudo yum install php-gd php-mbstring php-xml php-dom php-intl php-simplexml -y
  sudo systemctl start nginx 
  sudo systemctl enable nginx
  sudo systemctl start php-fpm
  sudo systemctl enable php-fpm
  sudo systemctl restart nginx 
  echo "*** Completed Installing "
  EOF

  tags = {
    Name = "web_instance"
  }

  volume_tags = {
    Name = "web_instance"
  } 
}
