# Demo to create Kubernetes cluster on CoreOS in AWS with kubeadm

This code requires you have terraform in your local PATH. It will run one Ubuntu master with many CoreOS workers.

## Deploy it

 You can provide your AWS credentials via environment variables 

```bash
export AWS_ACCESS_KEY_ID="anaccesskey"
export AWS_SECRET_ACCESS_KEY="asecretkey"
export AWS_DEFAULT_REGION="us-west-1"
```

You can provide your public and private ssh keys during the deployment

```bash
var.private_key_path
  Enter a value: /home/adam/.ssh/id_rsa
var.public_key
  Enter a value: ssh-rsa AAAAB3NzaC1yc...itHyqMcw== adam@localhost
```

or edit the sample env variables file

```bash
terraform apply
(snipped)...Creation complete after 2m3s (ID: i-0d96e6ad4f25a4968)

Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:

Sample App = Visit the url http:///54.183.168.204:30001
```

visit the provided url and you should be presented with the sample app

### Scaling

try changing some of the variables, like ${var.node_instance_count}, that controls the number of workers to spin up

Thanks! and enjoy :)
