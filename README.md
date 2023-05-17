# todolist
Launch a To-Do-List Django Application using Ansible and Terraform

The objective of this project is to deploy the "To-Do-List" Django web application through the utilization of Ansible and Terraform. Resources will be configured on an ansible master node and deployed to two target-nodes for public access. 

***"To-Do-List" Architecture Diagram***

![SAVETHS drawio](https://github.com/perryb3693/todolist/assets/129805541/c04177e3-1d14-4de5-8b2c-8b83123f2fb2)


***Configure Terraform to Provision Infrastructure (IaC)***

Create a directory for your terraform files and place a file for your configurations
```
$ mkdir terraform_files
$ cd terraform_files
$ vim main.tf
```

Initiate Terraform infratructure build for AWS resources
```
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
  region  = "ca-central-1" #insert your region 
  shared_credentials_file = "~/.aws/credentials" #link to your credentials or configure passwords
  profile = "default"
}
```
Create VPC and configure routing for web traffic to webservers
```
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
```
Create subnets for each node
```
resource "aws_subnet" "master_subnet" {
    cidr_block = "10.0.1.0/24"
    vpc_id = aws_vpc.test-env.id
    availability_zone = "ca-central-1a"  #change to your availability zone
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
```
Configure route tables from the subnets to the igw
```
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
```
Create security group for the master node allowing management ssh traffic
```
resource "aws_security_group" "masternode_sg" {
  name        = "masternode-sg"
  description = "Allow ssh inbound traffic for management"
  vpc_id = aws_vpc.test-env.id

  ingress {
    from_port        = 22
    to_port          = 22
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
```
Create security group for target nodes allowing web traffic and management
```
resource "aws_security_group" "ansiblenode_sg" {
  name        = "ansiblenode-sg"
  description = "Allow ssh http database inbound traffic"
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

  ingress {
    from_port        = 9876
    to_port          = 9876
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
```
Provision one master node and two target nodes as ec2 instances
```
resource "aws_instance" "master_node" {
  ami           = "ami-0abc4c35ba4c005ca"  #insert your amazon machine image ID
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.masternode_sg.id]
  key_name = "master_key" #generate keypair on AWS and reference key name here
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
```
Once configurations have been made within the "main.tf" file, initiate and deploy your aws infrastructure build
```
$ terraform init
$ terraform plan
$ terraform apply
```
***Configure Ansible to Prepare Environment on Target Nodes for Application Deployment***

Write Ansible inventory and playbook configurations to install and configure the necessary dependencies for the "To-Do-List" Django application in both of the target nodes.

First, create a private key pem file on your master node. This will allow the master node to access webservers specified within the "inventory.ini" file later.
```
$ cd ~/.ssh
$ vi master_key.pem                #copy and paste private key file saved on localhost
$ chmod 400 master_key.pem
```
Install Ansible and dependencies on your master node
```
$ sudo add-apt-repository --yes --update ppa:ansible/ansible
$ sudo apt update
$ sudo apt install software-properties-common
$ sudo apt install ansible
$ sudo apt install python3-pip python3-pip
$ sudo pip install passlib
```
Configure the Ansible inventory file and add webservers with variables for reference within the playbook files
```
[webservers]
node1 ansible_host=10.0.2.245
node2 ansible_host=10.0.3.248

[all:vars]
ansible_ssh_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/master_key.pem
repo_url=https://github.com/chandradeoarya/         #insert the url of the repository of your application files
repo=todo-list
home_dir=/home/ubuntu
repo_dir={{ home_dir }}/{{ repo }}
django_project=to_do_proj

```
Verify ansible connectivity between master and target nodes
```
$ ansible webservers -m ping
```
Create a systems update playbook and deploy to target nodes
```
---
- hosts: all
  become: yes
  become_user: root
  gather_facts: no
  tasks:
    - name: Running system update
      apt: update_cache=yes
        upgrade=safe
      register: result
    - debug: var=result.stdout_lines
```
```
$ ansible-playbook -i inventory.ini updates.yml
```
Install Python, pip, and nginx packages on target nodes

```
---
- hosts: all
  become: yes
  become_user: root
  gather_facts: no
  tasks:
    - name: Running apt update
      apt: update_cache=yes
    - name: Installing required packages
      apt: name={{item}} state=present
      with_items:
       - python3.10-venv
       - python-pip
       - nginx
```
```
$ ansible-playbook -i inventory.ini packages.yml
```
Download application files from Github and create a python virtual environment for Django app deployment
```
- hosts: all
  become: yes
  become_user: ubuntu
  gather_facts: no

  tasks:
    - name: pull branch master
      git:
        repo: "{{ repo_url }}/{{ repo }}.git"
        dest: "{{ repo_dir }}"
        accept_hostkey: yes

- hosts: all
  gather_facts: no
  tasks:
    - name: Create virtual environment
      command: python3 -m venv venv
      args:
        chdir: "{{ repo_dir }}"

    - name: install python requirements
      pip:
        requirements: "{{ repo_dir }}/requirements.txt"
        state: present
        executable: "{{ repo_dir }}/venv/bin/pip"
```
```
$ ansible-playbook -i inventory.ini code.yml
```
***Configure the Postgres Database***

Configure the database "env" file
```
echo '
DB_NAME=todolist
DB_USER=postgres
DB_PASSWORD=WSs9yTSHghMi6Sp
DB_HOST=db1.chzveui56egk.us-east-1.rds.amazonaws.com
DB_PORT=5432
SECRET_KEY=vf^b#k_@6td43!4+uw&g^zpkbntdn+!v1hm$yu$x4m%=d)isc3' > env
```
Use Ansible playbook to copy env file from master to target nodes
```
---
- name: Set environment variables on hosts
  hosts: all
  become: true
  become_user: ubuntu
  tasks:
    - name: Copy env file to hosts
      copy:
        src: /home/ubuntu/todolist/env
        dest: /home/ubuntu/todo-list/.env
        mode: 0644
```
```
$ ansible-playbook -i inventory.ini copyenv.yml
```
***Configure Gunicorn in Target Nodes**

Configure "to-do-list" daemon service file to automatically start Gunicorn
```
---
- hosts: all
  become: yes
  become_user: root
  gather_facts: no
  tasks:
    - name: Copy Gunicorn systemd service file
      template:
        src: /home/ubuntu/todolist/todolist.service
        dest: /etc/systemd/system/todolist.service
      register: gunicorn_service

    - name: Enable and start Gunicorn service
      systemd:
        name: todolist
        state: started
        enabled: yes
      when: gunicorn_service.changed
      notify:
        - Restart Gunicorn

    - name: Restart Gunicorn
      systemd:
        name: todolist
        state: restarted
      when: gunicorn_service.changed

  handlers:
    - name: Restart Gunicorn
      systemd:
        name: todolist
        state: restarted
```
```
ansible-playbook -i inventory.ini gunicorn.yml
```
***Configure Nginx to Proxy Pass to Gunicorn***

With Gunicorn configured, create an Nginx configuration file to pass HTTP traffic over port 80 to the Gunicorn service
```
$ echo '
server {
    listen 80;

    server_name public_ip;

    location / {
        proxy_pass http://localhost:9876;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}' > todolist
```
Deploy the nginx configuration file to target nodes using an ansible playbook
```
--
- name: Configure Nginx port forwarding
  hosts: all
  become: true
  become_user: root
  gather_facts: no
  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: present

    - name: Configure Nginx
      template:
        src: ~/nginx/todolist
        dest: /etc/nginx/sites-available
        owner: root
        group: root
        mode: 0644
      notify: Restart Nginx

    - name: Change public_ip in Nginx configuration
      replace:
        path: /etc/nginx/sites-available/todolist
        regexp: 'server_name public_ip;'
        replace: 'server_name {{ ansible_host }};'

    - name: Enable Nginx site
      file:
        src: /etc/nginx/sites-available/todolist
        dest: /etc/nginx/sites-enabled/todolist
        state: link
      notify: Restart Nginx

  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
```
```
$ ansible-playbook -i inventory.ini nginx.yml
```
Once the playbook has been deployed, verify Django application functionality by accessing your webserver through its public IP address on port 80. 
