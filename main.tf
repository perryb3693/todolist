#initiate Terraform infratructure build
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ca-central-1"
  shared_credentials_file = "~/.aws/credentials"
  profile = "default"
}

#####################################################
#create VPC and configure routing for public access to subnets
resource "aws_vpc" "test-env" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
        Name = "test-env"
    }
}
resource "aws_internet_gateway" "test-env-gw" {
    vpc_id = aws_vpc.test-env.id
}

#create subnets for each node
resource "aws_subnet" "master_subnet" {
    cidr_block = "10.0.1.0/24"
    vpc_id = aws_vpc.test-env.id
    availability_zone = "ca-central-1a"
    map_public_ip_on_launch = true
    tags = {
        Name = "master-subnet"
  }
}
resource "aws_subnet" "node_subnet1" {
    cidr_block = "10.0.2.0/24"
    vpc_id = aws_vpc.test-env.id
    map_public_ip_on_launch = true 
    availability_zone = "ca-central-1a"
    tags = {
        Name = "node-subnet1"
  }
}
resource "aws_subnet" "node_subnet2" {
    cidr_block = "10.0.3.0/24"
    vpc_id = aws_vpc.test-env.id
    map_public_ip_on_launch = true 
    availability_zone = "ca-central-1a"
    tags = {
        Name = "node-subnet2"
  }
}
#configure route tables from the subnets to the igw
resource "aws_route_table" "route-table-test-env" {
    vpc_id = aws_vpc.test-env.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.test-env-gw.id
    }
    tags = {
        Name = "test-env-route-table"
    }
}
resource "aws_route_table_association" "subnet-association1" {
    subnet_id = aws_subnet.node_subnet1.id
    route_table_id = aws_route_table.route-table-test-env.id
}
resource "aws_route_table_association" "subnet-association2" {
    subnet_id = aws_subnet.node_subnet2.id
    route_table_id = aws_route_table.route-table-test-env.id
}
resource "aws_route_table_association" "subnet-association3" {
    subnet_id = aws_subnet.master_subnet.id
    route_table_id = aws_route_table.route-table-test-env.id
}
###########################################################################

#Create security group for the master node allowing management traffic
resource "aws_security_group" "masternode_sg" {
  name        = "masternode-sg"
  description = "Allow ssh http inbound traffic"
  vpc_id = aws_vpc.test-env.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "masternode_sg"
  }
}

#Create security group for target nodes allowing web traffic and management
resource "aws_security_group" "ansiblenode_sg" {
  name        = "ansiblenode-sg"
  description = "Allow ssh http inbound traffic"
  vpc_id = aws_vpc.test-env.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ansiblenode_sg"
  }
}
#############################################################################

#Provision one master node and two target nodes
resource "aws_instance" "master_node" {
  ami           = "ami-0abc4c35ba4c005ca"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.masternode_sg.id]
  key_name = "master_key"
  subnet_id = aws_subnet.master_subnet.id
  tags = {
    Name = "master_node"
  }
}
resource "aws_instance" "target_node1" {
  ami           = "ami-0abc4c35ba4c005ca"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.ansiblenode_sg.id]
  key_name = "master_key"
  subnet_id = aws_subnet.node_subnet1.id
  tags = {
    Name = "target_node1"
  }
}
resource "aws_instance" "target_node2" {
  ami           = "ami-0abc4c35ba4c005ca"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.ansiblenode_sg.id]
  key_name = "master_key"
  
  subnet_id = aws_subnet.node_subnet2.id
  tags = {
    Name = "target_node2"
  }
}

###########################################################################