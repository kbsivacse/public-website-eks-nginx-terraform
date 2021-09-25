resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "k8s-cluster-sg" {
  name        = "${var.cluster_name}-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${var.virtual_network_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}"
  }
}

resource "aws_security_group_rule" "k8s-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.k8s-cluster-sg.id}"
  source_security_group_id = "${aws_security_group.k8s-node-sg.id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "k8s-cluster-ingress-workstation-https" {
  count             = "${var.workstations_cidr_list != "" ? 1 : 0}"
  cidr_blocks       = ["${var.workstations_cidr_list}"]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.k8s-cluster-sg.id}"
  to_port           = 443
  type              = "ingress"
}

resource "aws_security_group" "k8s-node-sg" {
  name        = "${var.cluster_name}-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${var.virtual_network_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.cluster_name}-node",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
    )
  }"
}

resource "aws_security_group_rule" "k8s-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.k8s-node-sg.id}"
  source_security_group_id = "${aws_security_group.k8s-node-sg.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "k8s-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.k8s-node-sg.id}"
  source_security_group_id = "${aws_security_group.k8s-cluster-sg.id}"
  to_port                  = 65535
  type                     = "ingress"
}