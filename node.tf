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
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCmSFQYDxusXRYEOijwWspaPJpeu+XNmkonOJj1thQOFde/38ld6QkWg7bQfknxa6J9xmKkimqu2q6hcbvvU5Yjfjr2s7VHUFJ9jqWgoujlCkRJdVGRXWdU9MWHMODdBd4gtcEH/J3wH9unW7LOuBigwaGmjysJQyIuwUmlAWa8unJzDC2aR2Ifn0JoOeBwNsabkWi5sItXqywB0KMsJZ5LgE5SA95cBGF9wzUfJvNrcz+u0FeaRiliKDU9mX95pq+YWOSxNECQ4NNKJSG3Y/hF+v1VNIvomsYweILdocKvOkfcCMGbwwXP6qHGQu6Tdw0fx++2jBrvvi/qn56VJnssnOqNXooKBIexj/u9Q21q259CktuLdWVHNwq1og6AJnxeeXjU1ZpUwXXio08JwwDDwU10EMp7A/KTpXT3qrSxrjz0r071PmLBoLJ+v6Z2GZe6x6gnD4PTGLD66Hy+qEcN2HYek9sdggwkmjFwJEyheZFd6+/Vbb72ICNVESaVRjO5H+1BqfDzO+xA04P4tstEQaaAP82Oyegw41OIQXckQQfDsKNov2X8buDZDkn0veqU1KS5sJL0Ig2Jt1YFE+bRBb/slZ/utjkGiNkc0PllXpRqXafF7jctAQ4OLY52O99vYCfNjj0/7M2utOvJ5hGw0Jk677pKuNciH4itHyqMcw==
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
