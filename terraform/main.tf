terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.22.0"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

resource "aws_key_pair" "deployer" {
  key_name   = "pipecyte-aws"
  public_key = file(var.ssh_public_key)
}

resource "aws_security_group" "main" {
  name = "allow_rockblock_ssh_https"
  description = "Allow SSH and HTTP/S to RockBLOCK webhook server"
  egress {
    cidr_blocks      = ["0.0.0.0/0", ]
    protocol         = -1
    from_port        = 0
    to_port          = 0
  }
  ingress {
    cidr_blocks      = ["0.0.0.0/0", ]
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
  }
  ingress {
    cidr_blocks      = ["0.0.0.0/0", ]
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
  }
  ingress {
    cidr_blocks      = ["0.0.0.0/0", ]
    protocol         = "tcp"
    from_port        = 22
    to_port          = 22
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = var.eip_id

  provisioner "file" {
    source = var.rockserve_binary
    destination = "/home/ubuntu/rockserve"
  }

  provisioner "file" {
    source = "setup.sh"
    destination = "/home/ubuntu/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/setup.sh",
      "bash /home/ubuntu/setup.sh ${var.public_hostname  != "" ? var.public_hostname : self.public_ip} ${var.rockserve_port} ${var.prom_port} ${var.prom_user} ${var.prom_password} > setup.sh.log 2>&1"
    ]
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key)
    timeout     = "2m"
  }
}

resource "aws_instance" "web" {
  key_name               = "pipecyte-aws"
  ami                    = "ami-0d70546e43a941d70"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.main.id]

  tags = {
    Name = "RockBLOCK message server"
  }
}
