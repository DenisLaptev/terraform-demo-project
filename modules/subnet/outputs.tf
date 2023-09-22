# this way we expose output values from child module to parent model, 
# and can use this output in parent module
output "subnet" {
    value = aws_subnet.myapp-subnet-1
}