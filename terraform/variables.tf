variable "rockserve_binary" {
  description = "rockserve webserver binary file"
  type = string
  nullable = false
}

variable "ssh_private_key" {
  description = "SSH private key file"
  type        = string
  nullable    = false
}

variable "ssh_public_key" {
  description = "SSH public key file"
  type        = string
  nullable    = false
}

variable "prom_user" {
  description = "User name for Prometheus remote_write"
  type        = string
  nullable    = false
}

variable "prom_password" {
  description = "Password for Prometheus remote_write"
  type        = string
  nullable    = false
  sensitive   = true
}

variable "prom_port" {
  description = "Prometheus local port"
  type = number
  default = 9090
}

variable "rockserve_port" {
  description = "rockserve local port"
  type = number
  default = 8080
}

variable "eip_id" {
  description = "Elastic IP Allocation ID to use"
  type = string
}

variable "public_hostname" {
  description = "Optional public DNS hostname"
  type = string
  default = ""
}