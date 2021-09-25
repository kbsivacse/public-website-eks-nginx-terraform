# Load templates

data "template_file" "cluster-retrieve-data" {
  template = "${file("${path.module}/policy/eks-cluster-access.json")}"
}

data "template_file" "worker-retrieve-data" {
  template = "${file("${path.module}/policy/eks-ec2-access.json")}"
}

data "template_file" "alb-ingress-policy" {
  template = "${file("${path.module}/policy/alb-ingress-access.json")}"
}
