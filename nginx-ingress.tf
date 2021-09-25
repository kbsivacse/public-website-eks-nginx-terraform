module "alb_ingress_controller" {
  source = "../alb_ingress_controller"

  cluster_name = "${var.cluster_name}"
}

resource "kubernetes_deployment" "nginx_deployment" {
  metadata {
    name = "nginx-deployment"

    labels {
      app = "nginx"
    }
  }

  spec {
    replicas = "${var.nginx_replicas}"

    selector {
      match_labels {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "${var.nginx_image}"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx_nodeport" {
  metadata {
    name = "nginxservice"
  }

  spec {
    type = "NodePort"

    selector {
      app = "nginx"
    }

    port {
      port        = 80
      protocol    = "TCP"
      target_port = "80"
    }
  }
}

data "template_file" "nginx_ingress" {
  template = "${file("${path.module}/config/nginx-ingress.yaml")}"

  vars {
    cluster_endpoint = "${replace(lower(var.cluster_endpoint),"https://","")}"
  }
}

resource "local_file" "nginx_ingress_file" {
  content  = "${data.template_file.nginx_ingress.rendered}"
  filename = "config_output/nginx-ingress.yaml"

  provisioner "local-exec" {
    command = "kubectl apply -f config_output/nginx-ingress.yaml"
  }
}


data "template_file" "rbac_role" {
  template = "${file("${path.module}/templates/rbac-role.yaml")}"
  vars {
    cluster_name = "${var.cluster_name}"
  }

}

resource "local_file" "rbac_role_file" {
  content  = "${data.template_file.rbac_role.rendered}"
  filename = "config_output/rbac-role.yaml"

  provisioner "local-exec" {
    command = "kubectl apply -f config_output/rbac-role.yaml"
  }
}


# Deploy ALB Ingress Controller
data "template_file" "alb_ingress_deployment" {
  template = "${file("${path.module}/templates/alb-ingress-controller.yaml")}"
  vars {
    cluster_name = "${var.cluster_name}"
  }

}

resource "local_file" "alb_ingress_deploymentfile" {
  depends_on = ["local_file.rbac_role_file"]
  content  = "${data.template_file.alb_ingress_deployment.rendered}"
  filename = "config_output/alb-ingress-controller.yaml"

  provisioner "local-exec" {
    command = "kubectl apply -f config_output/alb-ingress-controller.yaml"
  }
}