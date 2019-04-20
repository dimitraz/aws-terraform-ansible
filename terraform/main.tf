provider "aws" {
  region = "${var.aws_region}"
}

// Use your own HAProxy AMI
data "aws_ami" "haproxy_aws_amis" {
  most_recent = true

  # filter {
  #   name   = "product-code"
  #   values = ["483gxnuft87jy44d3q8n4kvt1"]
  # }

  filter {
    name   = "name"
    values = ["HAProxy image"]
  }
  owners = ["155290810877"]
}

# // Lookup latest Ubuntu Xenial 16.04 AMI
# data "aws_ami" "ubuntu_aws_amis" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
#   }

#   owners = ["099720109477"]
# }

// Default VPC definition
resource "aws_vpc" "default" {
  cidr_block           = "20.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "haproxy_test_vpc"
  }
}

// Default subnet definition; in real world this sould span over at least two AZ
resource "aws_subnet" "tf_private_subnet" {
  vpc_id     = "${aws_vpc.default.id}"
  cidr_block = "20.0.2.0/24"

  tags {
    Name = "haproxy_private_subnet"
  }
}

resource "aws_subnet" "tf_public_subnet" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "20.0.1.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "haproxy_public_subnet"
  }
}

// Define our IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name = "haproxy_test_ig"
  }
}

// Define our standard routing table
resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.default.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "haproxy_test_route_table"
  }
}

// Routing table association for default subnet
resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.tf_public_subnet.id}"
  route_table_id = "${aws_route_table.r.id}"
}

// Security group for Web backends
resource "aws_security_group" "web_node_sg" {
  name        = "web_node_sg"
  description = "Instance Web SG: pass SSH, permit HTTP only from HAProxy"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.haproxy_node_sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags {
    Name = "haproxy_web_node_sg"
  }
}

// Security group for HAProxy LB nodes
resource "aws_security_group" "haproxy_node_sg" {
  name        = "haproxy_node_sg"
  description = "Instance HAProxy SG: pass SSH, HTTP, HTTPS and Dashboard traffic by default"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 3
    to_port     = 4
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port = 694
    to_port   = 694
    protocol  = "udp"
    self      = true
  }

  ingress {
    from_port   = 9022
    to_port     = 9022
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port   = 9023
    to_port     = 9023
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags {
    Name = "haproxy_node_sg"
  }
}

// IAM policy document - Assume role policy
data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

// IAM policy document - EIP permissions policy
data "aws_iam_policy_document" "eip_policy" {
  statement {
    sid = "1"

    actions = [
      "ec2:DescribeAddresses",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:DescribeInstances",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:DescribeNetworkInterfaces",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
    ]

    resources = ["*"]
  }
}

// IAM role - EIP role
resource "aws_iam_role" "eip_role" {
  name               = "haproxy_eip_role"
  assume_role_policy = "${data.aws_iam_policy_document.instance_assume_role_policy.json}"
}

// IAM role policy - EIP role policy
resource "aws_iam_role_policy" "eip_role_policy" {
  name   = "haproxy_eip_role_policy"
  role   = "${aws_iam_role.eip_role.id}"
  policy = "${data.aws_iam_policy_document.eip_policy.json}"
}

// IAM instance profile - EIP instance profile
resource "aws_iam_instance_profile" "eip_instance_profile" {
  name = "haproxy_instance_profile"
  role = "${aws_iam_role.eip_role.id}"
}

// Instance definition for Web backends
// Variable instance count
resource "aws_instance" "web_node" {
  count = "${var.web_cluster_size}"

  instance_type = "${var.aws_web_instance_type}"
  ami           = "${var.ami}"
  key_name      = "${var.key_name}"

  vpc_security_group_ids = ["${aws_security_group.web_node_sg.id}"]
  subnet_id              = "${aws_subnet.tf_private_subnet.id}"

  user_data = <<EOF
  #cloud-config
  runcmd:
    - systemctl stop apt-daily.service
    - systemctl kill --kill-who=all apt-daily.service
    - systemctl stop apt-daily.timer
  EOF

  tags {
    Name = "haproxy_web_node"
  }
}

// Instance definition for HAProxy LB nodes
resource "aws_instance" "haproxy_node" {
  count = "${var.haproxy_cluster_size}"

  instance_type        = "${var.aws_haproxy_instance_type}"
  ami                  = "${data.aws_ami.haproxy_aws_amis.id}"
  key_name             = "${var.key_name}"
  iam_instance_profile = "${aws_iam_instance_profile.eip_instance_profile.id}"

  vpc_security_group_ids = ["${aws_security_group.haproxy_node_sg.id}"]
  subnet_id              = "${aws_subnet.tf_public_subnet.id}"

  user_data = <<EOF
  #cloud-config
  runcmd:
    - systemctl stop apt-daily.service
    - systemctl kill --kill-who=all apt-daily.service
    - systemctl stop apt-daily.timer
  EOF

  tags {
    Name = "haproxy_lb_node"
  }
}

// EIP allocation for primary static address for each HAProxy LB instance
resource "aws_eip" "haproxy_node_eip1" {
  count             = "${var.haproxy_cluster_size}"
  network_interface = "${element(aws_instance.haproxy_node.*.primary_network_interface_id, count.index)}"
  vpc               = true
}
