
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.20"
  subnets         = module.vpc.private_subnets

  tags = {
    Environment = "training"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  vpc_id = module.vpc.vpc_id

  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t2.small"
      additional_userdata           = "echo worker-group-1"
      asg_desired_capacity          = 2
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
    {
      name                          = "worker-group-2"
      instance_type                 = "t2.small"
      additional_userdata           = "echo worker-group-2"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_two.id]
      asg_desired_capacity          = 1
    },
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

resource "aws_eks_cluster" "k8s-cluster" {
  name     = local.cluster_name
  role_arn = "${aws_iam_role.k8s-cluster-role.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.k8s-cluster-sg.id}"]
    subnet_ids         = ["${var.subnets_ids}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.k8s-cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.k8s-cluster-AmazonEKSServicePolicy",
  ]
}

resource "aws_iam_role" "worker-node" {
  name = "${var.cluster_name}-node"

  assume_role_policy = "${data.template_file.worker-retrieve-data.rendered}"
}

resource "aws_iam_role_policy_attachment" "k8s-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.worker-node.name}"
}

resource "aws_iam_role_policy_attachment" "k8s-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.worker-node.name}"
}

resource "aws_iam_role_policy_attachment" "k8s-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.worker-node.name}"
}

resource "aws_iam_role_policy" "CustomAlbIngress" {
  name   = "CustomAlbIngress"
  policy = "${data.template_file.alb-ingress-policy.rendered}"
  role   = "${aws_iam_role.worker-node.name}"
}

resource "aws_iam_instance_profile" "worker-node" {
  name = "${var.cluster_name}"
  role = "${aws_iam_role.worker-node.name}"
}

data "aws_ami" "k8s-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.k8s-cluster.version}-v*"]
  }

  most_recent = true
  owners      = ["xxxxxxxxxxx"] 
}

locals {
  worker-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.k8s-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.k8s-cluster.certificate_authority.0.data}' '${var.cluster_name}'
USERDATA
}

# Write k8s cluster config files locally

data "template_file" "template_kubeconfig" {
  template = "${file("${path.module}/config/kubeconfig.yaml")}"
  vars {
    cluster_endpoint = "${aws_eks_cluster.k8s-cluster.endpoint}"
    cluster_cert = "${aws_eks_cluster.k8s-cluster.certificate_authority.0.data}"
    cluster_name = "${aws_eks_cluster.k8s-cluster.name}"
  }
}

resource "local_file" "kubeconfig_file" {
  content = "${data.template_file.template_kubeconfig.rendered}"
  filename = "${pathexpand("~/.kube/config")}"
  provisioner "local-exec" {
    command = "chmod 644 ${pathexpand("~/.kube/config")}"
  }
}

# AutoScaling Launch Configuration to configure worker instances
resource "aws_launch_configuration" "k8s-workers-config" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.worker-node.name}"
  image_id                    = "${data.aws_ami.k8s-worker.id}"
  instance_type               = "m4.large"
  name_prefix                 = "${var.cluster_name}"
  security_groups             = ["${aws_security_group.k8s-node-sg.id}"]
  user_data_base64            = "${base64encode(local.worker-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

# AutoScaling Group to launch worker instances
resource "aws_autoscaling_group" "k8s-workers-autoscaling" {
  desired_capacity     = 2
  launch_configuration = "${aws_launch_configuration.k8s-workers-config.id}"
  max_size             = 2
  min_size             = 1
  name                 = "${var.cluster_name}"
  vpc_zone_identifier  = ["${var.subnets_ids}"]

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

# Join worker nodes to cluster

data "aws_eks_cluster_auth" "k8s_cluster_auth" {
  name = "${var.cluster_name}"
}

provider "kubernetes" {
  host                   = "${aws_eks_cluster.k8s-cluster.endpoint}"
  cluster_ca_certificate = "${base64decode(aws_eks_cluster.k8s-cluster.certificate_authority.0.data)}"
  token                  = "${data.aws_eks_cluster_auth.k8s_cluster_auth.token}"
  load_config_file       = false
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data {
    mapRoles = <<YAML
- rolearn: ${aws_iam_role.worker-node.arn}
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
YAML
  }
}


module "k8s_ingress_controller" {
  source = "../../../../kubernetes/ingress_controller/alb_nginx_ingress"

  cluster_endpoint = "${aws_eks_cluster.k8s-cluster.endpoint}"
  cluster_name     = "${aws_eks_cluster.k8s-cluster.name}"
}