# this way we expose output values from child module to parent model, 
# and can use this output in parent module
output "instance" {
  value = aws_instance.myapp-server
}