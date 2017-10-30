provider "aws" {
  region = "${var.region}"
}

resource "aws_key_pair" "demo" {
  key_name   = "${var.key_name}"
  public_key = "${var.public_key}"
}

# Variables
variable "region" {
  default = "us-west-1"
}

variable "vpc_cidr" {
  default = "10.5.0.0/16"
}

variable "public_subnets" {
  default = ["10.5.1.0/24"]
}

variable "instance_ips" {
  default = ["10.5.1.11"]
}

variable "key_name" {
  default = "demo"
}

variable "cluster_token" {
  default = "3e27fd.643841af7cc669ad"
}

variable "ami" {
  default = "ami-1c1d217c"
}

variable "master_instance_type" {
  default = "t2.micro"
}

variable "node_ami" {
  default = "ami-23566a43"
}

variable "node_instance_type" {
  default = "t2.medium"
}

variable "node_instance_count" {
  description = "The number of worker nodes to deploy"
  default     = 2
}

variable "private_key_path" {
  description = "The full path to your SSH key to provision resources"
}

variable "public_key" {
  description = "Copy and paste in your public SSH key (i.e.: ssh-rsa AAAA....)"
}

# Outputs

output "Sample App" {
  value = "Visit the url http:///${aws_instance.master.public_ip}:30001"
}

# Resources

resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags {
    Name = "demo vpc"
  }
}

resource "aws_subnet" "subnet" {
  availability_zone       = "${var.region}a"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.public_subnets[0]}"
  map_public_ip_on_launch = true

  tags {
    Name = "demo default subnet"
  }
}

resource "aws_internet_gateway" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "demo public gateway"
  }
}

resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "demo route table"
  }
}

resource "aws_main_route_table_association" "main" {
  vpc_id         = "${aws_vpc.vpc.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_route" "public" {
  route_table_id         = "${aws_route_table.main.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.public.id}"
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.subnet.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_security_group" "cluster" {
  name        = "demo-cluster-sg"
  description = "Allow App and SSH traffic to cluster hosts"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30001
    to_port     = 30001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "demo security group"
  }
}

resource "aws_instance" "master" {
  ami                         = "${var.ami}"
  instance_type               = "${var.master_instance_type}"
  key_name                    = "${var.key_name}"
  subnet_id                   = "${aws_subnet.subnet.id}"
  private_ip                  = "${var.instance_ips[0]}"
  associate_public_ip_address = true

  user_data = <<-EOF0
              #!/bin/bash
              sudo apt install -y ebtables ethtool curl
              sudo apt-get update
              sudo apt-get install -y docker.io
              sudo apt-get update && sudo apt-get install -y apt-transport-https
              curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
              sudo cat <<EOF1 | sudo tee /etc/apt/sources.list.d/kubernetes.list
              deb http://apt.kubernetes.io/ kubernetes-xenial main
              EOF1
              sudo apt-get update
              sudo apt-get install -y kubelet kubeadm=1.6.11-01 kubectl
              sudo kubeadm init --kubernetes-version stable-1.6 \
                                --apiserver-advertise-address ${var.instance_ips[0]} \
                                --apiserver-bind-port 6443 \
                                --cert-dir /etc/kubernetes/pki \
                                --service-dns-domain cluster.local \
                                --service-cidr 10.96.0.0/12 \
                                --pod-network-cidr=10.244.0.0/16 \
                                --token ${var.cluster_token} \
                                --token-ttl 0 \
                                --skip-preflight-checks
              sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/coreos/flannel/v0.8.0/Documentation/kube-flannel-rbac.yml
              sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/coreos/flannel/v0.8.0/Documentation/kube-flannel.yml
              EOF0

  vpc_security_group_ids = [
    "${aws_security_group.cluster.id}",
  ]

  connection {
    user        = "ubuntu"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "echo -n 'cluster is coming online... This can take just a little while'",
      "while [ $(sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o=jsonpath=\"{.items[*].metadata.name}\"|wc -w) -lt 2 ] ; do sleep 2; done",
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes",
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf create namespace sock-shop",
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -n sock-shop -f 'https://github.com/microservices-demo/microservices-demo/blob/master/deploy/kubernetes/complete-demo.yaml?raw=true'",
    ]
  }

  tags {
    Name = "demo master instance"
  }
}
