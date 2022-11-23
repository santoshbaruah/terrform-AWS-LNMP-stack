## Objective of the Amazon linux2 EC2 instance is to have the LNMP stack Using Teeraform

## Source Code File Details
- `main.tf` contains the beginning section of terraform code
- So we have to define `terraform` with `required_providers` and we have mentioned `aws` since we are going to create infra in AWS

```
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
```

# Configure the AWS Provider
$ export AWS_ACCESS_KEY_ID=""
$ export AWS_SECRET_ACCESS_KEY=""
```

- Rest of the `main.tf` should have the resource definition required for creating a `AWS EC2` instance
- We need to have below resources for creating an EC2 instance
  1. VPC
  2. Internet Gateway
  3. Subnet
  4. Route table
  5. Security Group
  6. EC2 instance definition

```
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
```
## Cloud Init and User Data
- Objective of the Amazon linux2 EC2 instance is to have the LNMP stack (Linux, Nginx, MySQL, PHP) installed on it, when the instance is created
- So we are providing a shell script in `user_data` section to install the LNMP
- The script added in `user_data` section will be invoked via `Cloud Init` functionality when the AWS server gets created

resource "aws_instance" "web" {
  ami             = "ami-0233214e13e500f77" 
  instance_type   = var.instance_type
  key_name        = var.instance_key
  subnet_id       = aws_subnet.public_subnet.id
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
```
- `variables.tf` file should have the customised variables, a user wanted to provide before running the infra creation
- User can also define default value for each variable in the file
resource "aws_security_group" "sg" {
  name        = "allow_ssh_http"
  description = "Allow ssh http inbound traffic"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}
```
- We can define `output.tf` file to see expected output values like `ipaddress` of instances and `hostname` etc.

- output.tf
```
output "web_instance_ip" {
    value = aws_instance.web.public_ip
}
```
- Since we have the custom variables defined in our terraform file, we have provide the values for those custom variables
- So we have to create a `tfvars` files and provide the custom variable values
- User has to provide the EC2 instance `pem file` key name in `instance_key` value
- aws.tfvars
```
region =  "eu-central-1"
instance_type = "t2.micro"
instance_key = "aws_ec2_pem_file_name"
creds = "~/.aws/credentials"
vpc_cidr = "178.0.0.0/16"
public_subnet_cidr = "178.0.10.0/24"
```
## Steps to run Terraform
```
terraform init
terraform plan -var-file=aws.tfvars
terraform apply -var-file=aws.tfvars -auto-approve
```
- Once the `terrform apply` completed successfully it will show the `public ipaddress` of the LNMP server as `output`

```