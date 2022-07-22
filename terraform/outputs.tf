output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "instance_elastic_ip" {
  description = "Elastic IP address of the EC2 instance"
  value       = aws_eip_association.eip_assoc.public_ip
}
