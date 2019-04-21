// Set default AWS region. Pay attention to inventory/ec2.ini which should also use the same region.
variable "aws_region" {
  description = "Home AWS region"
  default     = "eu-west-1"
}

// Default instance type for HAPEE LB instances. Obviously, something along m5.xlarge or c5.xlarge should be a perfect fit.
variable "aws_haproxy_instance_type" {
  description = "Default AWS instance type for HAProxy nodes"
  default     = "t2.micro"
}

// Default instance type for Web backends. Typically m5.4xlarge and similar, depending on use case.
variable "aws_web_instance_type" {
  description = "Default AWS instance type for Web nodes"
  default     = "t2.micro"
}

variable "ami" {
  description = "Amazon Linux AMI"
  default     = "ami-07683a44e80cd32c5"
}

// SSH pub key pair located on Amazon. Also set/used in ansible.cfg.
variable "key_name" {
  description = "SSH key pair to use in AWS"
  default     = "ec2_ubuntu"
}

// Typical size of Web cluster backends. It's reasonable to have more than 2.
variable "web_cluster_size" {
  description = "Size of Web nodes cluster"
  default     = 3
}

// Size of the HAProxy cluster 
variable "haproxy_cluster_size" {
  description = "Size of HAProxy Nodes cluster"
  default     = 1
}

// Allocation ID of elastic IP 
variable "allocation_id" {
  description = "Elastic IP address for NAT gateway"
  default     = "eipalloc-0a5e8d6aff398d172"
}
