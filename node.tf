resource "aws_instance" "node" {
  ami                         = "${var.node_ami}"
  instance_type               = "${var.node_instance_type}"
  key_name                    = "${var.key_name}"
  subnet_id                   = "${aws_subnet.subnet.id}"
  associate_public_ip_address = true

  user_data = <<-EOF
#cloud-config

coreos:
    units:
      - name: fleet.service
        command: stop
    fleet:
        public-ip: "$public_ipv4"
        metadata: "region=${var.region}"
    locksmith:
        reboot_strategy: "off"

users:
  - name: core
    ssh-authorized-keys:
      - ${var.public_key}
    groups:
      - sudo
      - docker
-EOF

  vpc_security_group_ids = [
    "${aws_security_group.cluster.id}",
  ]

  connection {
    user        = "core"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo docker run -it -v /etc:/rootfs/etc -v /opt:/rootfs/opt -v /usr/bin:/rootfs/usr/bin xakra/kubeadm-installer:latest coreos",
      "while [ ! -f /opt/bin/kubeadm ]; do sleep 5; done",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable docker kubelet",
      "sudo systemctl restart docker kubelet",
      "echo 'waiting on the apiserver to come up..'",
      "while ! ncat -4 -z -w 1 ${var.instance_ips[0]} 6443; do sleep 2; done",
      "sudo kubeadm join --token ${var.cluster_token} ${var.instance_ips[0]}:6443",
      "sudo ln -s /opt/cni /opt/cni/bin",
    ]
  }

  tags {
    Name = "demo node instance"
  }

  count = "${var.node_instance_count}"
}
