#see MySecretsLocal.txt for access_key and secret_key
provider "aws" {
  region     = "eu-west-3"
  access_key = ""
  secret_key = ""
}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

module "myapp-subnet" {
  source = "./modules/subnet"

  #setting variables
  subnet_cidr_block      = var.subnet_cidr_block
  avail_zone             = var.avail_zone
  env_prefix             = var.env_prefix
  vpc_id                 = aws_vpc.myapp-vpc.id
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
}

module "myapp-server" {
  source = "./modules/webserver"

  #setting variables
  vpc_id              = aws_vpc.myapp-vpc.id
  my_ip_cidr          = var.my_ip_cidr
  env_prefix          = var.env_prefix
  image_id            = var.image_id
  public_key_location = var.public_key_location
  instance_type       = var.instance_type
  subnet_id           = module.myapp-subnet.subnet.id
  avail_zone          = var.avail_zone
}
