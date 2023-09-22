#see MySecretsLocal.txt for access_key and secret_key
provider "aws" {
  region     = "eu-west-3"
  access_key = ""
  secret_key = ""
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = var.vpc_cidr_block

  azs                = [var.avail_zone]
  public_subnets     = [var.subnet_cidr_block]
  public_subnet_tags = { Name = "${var.env_prefix}-subnet-1" }

  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

module "myapp-server" {
  source = "./modules/webserver"

  #setting variables
  vpc_id              = module.vpc.vpc_id
  my_ip_cidr          = var.my_ip_cidr
  env_prefix          = var.env_prefix
  image_id            = var.image_id
  public_key_location = var.public_key_location
  instance_type       = var.instance_type
  subnet_id           = module.vpc.public_subnets[0]
  avail_zone          = var.avail_zone
}
