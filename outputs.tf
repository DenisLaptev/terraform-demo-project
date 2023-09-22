# we see these outputs when we terraform apply from root module
output "aws_ami_id" {
  value = module.myapp-server.instance.ami
}

output "ec2_public_ip" {
  value = module.myapp-server.instance.public_ip
}