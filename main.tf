#see MySecretsLocal.txt for access_key and secret_key
provider "aws" {
  region     = "eu-west-3"
  access_key = ""
  secret_key = ""
}


variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip_cidr" {}
variable "instance_type" {}
variable "my_public_key" {}
variable "public_key_location" {}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id            = aws_vpc.myapp-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name = "${var.env_prefix}-subnet-1"
  }
}

resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0" # any address
    gateway_id = aws_internet_gateway.myapp-igw.id
  }

  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id      = aws_subnet.myapp-subnet-1.id
  route_table_id = aws_route_table.myapp-route-table.id
}


resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"

  vpc_id = aws_vpc.myapp-vpc.id

  # incomming rules
  ingress {
    from_port   = 22 # for ssh, can specify range - from 0 to 1000, or just 1 port 
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr] # https://www.whatsmyip.org/ = (192.211.15.183)
  }
  ingress {
    from_port   = 8080 # for ssh, can specify range - from 0 to 1000, or just 1 port 
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # any address
  }

  # outcomming rules
  # when app on EC2 needs install something from integnet, it gets data from sites. 
  # We need to allow otgoing trafic from EC2.
  egress {
    from_port       = 0 # any port
    to_port         = 0
    protocol        = "-1"          # any protocol
    cidr_blocks     = ["0.0.0.0/0"] # any address
    prefix_list_ids = []            # this param not interesting for us
  }

  tags = {
    Name = "${var.env_prefix}-sg"
  }
}

#ami-091b37bfd6e01db4f is Free Tier
data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "image-id"
    values = ["ami-091b37bfd6e01db4f"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image
}

output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}

resource "aws_key_pair" "ssh-key" {
  key_name = "terraformKeyPairGenerated"
  # public_key = var.my_public_key
  public_key = file(var.public_key_location) # you shoul have ~/.ssh/id_rsa.pub (to generate use ssh-keygen)

  # to ssh to ec2 instance
  # ssh -i ~/.ssh/id_rsa ec2-user@15.236.203.239
  # ssh ec2-user@15.236.203.239 #defaul behavior
}

resource "aws_instance" "myapp-server" {
  # ami = "ami-091b37bfd6e01db4f"
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  #optional attrs
  subnet_id              = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone      = var.avail_zone

  associate_public_ip_address = true

  # key_name = "terraformKeyPair"
  key_name = aws_key_pair.ssh-key.key_name

  user_data = file("entry-script.sh")

  tags = {
    Name = "${var.env_prefix}-server"
  }
}

