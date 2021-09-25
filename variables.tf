variable "nginx_replicas" {
  type = "string"
  default = "2"
  description = "Number of Nginx replicas to run in the cluster."
}

variable "nginx_image" {
  type = "string"
  default = "nginx:1.9.1"
  description = "Defines the specific Nginx docker image to be deployed."
}

variable "cluster_endpoint" {
  type = "string"
  description = ""
}

variable "cluster_name" {
  type = "string"
  description = "AWS EKS cluster name"
}

variable "virtual_network_id" {
  type = "string"
  description = "Virtual Network identification where the cluster will be deployed."
}

variable "subnets_ids" {
  type = "list"
  description = "List of subnets to deploy cluster resources"
}

# Other
variable "workstations_cidr_list" {
  default = ""
  description = "List of workstations that will have access to k8s cluster. This is optional and is usually used for test purposes."
}