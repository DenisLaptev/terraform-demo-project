#see MySecretsLocal.txt for access_key and secret_key
provider "aws" {
  region     = "eu-west-3"
  access_key = var.env_access_key
  secret_key = var.env_secret_key
}

# best practive is to use export for env vars
# export AWS_ACCESS_KEY_ID=
# export AWS_SECRET_ACCESS_KEY=

variable "env_access_key" {}
variable "env_secret_key" {}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip_cidr" {}
variable "instance_type" {}
variable "my_public_key" {}
variable "public_key_location" {}
variable "private_key_location" {}

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

  #   user_data = file("entry-script.sh")
  user_data_replace_on_change = true

  # "remote-exec" provisioner invokes script on a remote resource after it is created
  # inline - list of commands
  # script - path-to-file with commands
  # this provisioner needs connection {} block

  # we need to connect to launched EC2 instance and then execute cmd commands in it.
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_location)
  }


  # provisioners are not recommended by Terraform. use user_data, CHEF, Puppet, Ansigle instead

  provisioner "remote-exec" {
    # inline = [
    #   "rmdir newdir",
    #   "export ENV=dev",
    #   "mkdir newdir",
    #   "touch newFile.txt"
    # ]
    script = "entry-script.sh"
    # script = file("entry-script-on-ec2.sh")
  }

  # "local-exec" provisioner invokes a local executable after a resource is created
  # locally, NOT on the created resource!
  provisioner "local-exec" {
    command = "echo ${self.public_ip} > output.txt"
  }

  # "file" provisioner - to copy files or dirs from local to newly created resource. 
  # this provisioner needs connection {} block
  provisioner "file" {
    source = "entry-script.sh"
    destination = "/home/ec2-user/entry-script-on-ec2.sh"
  }

  tags = {
    Name = "${var.env_prefix}-server"
  }
}

