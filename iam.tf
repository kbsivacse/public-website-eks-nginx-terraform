# IAM Role to allow EKS service to manage other AWS services
resource "aws_iam_role" "k8s-cluster-role" {
  name = "${var.cluster_name}-cluster"

  assume_role_policy = "${data.template_file.cluster-retrieve-data.rendered}"
}

resource "aws_iam_role_policy_attachment" "k8s-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.k8s-cluster-role.name}"
}

resource "aws_iam_role_policy_attachment" "k8s-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.k8s-cluster-role.name}"
}