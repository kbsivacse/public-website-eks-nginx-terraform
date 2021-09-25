# Public website hosted on AWS EKS using Terraform  
This project details out the instructions to host a web site on AWS EKS using Terraform scripts

## Architecture
AWS EKS as the managed containers orchestration solution as it simplifies the Kubernetes cluster management. AWS manages the EKS infrastructure across multiple availability zones and any unhealthy node is automatically replaced. Worker nodes implementation use AWS Auto Scaling functionality to benefit from cloud elasticity, maintaining the performance according to demand and optmising costs. The autscaling group deploys workers nodes across multiple availability zones to increase availability and recoverability.

From the Kubernetes Ingress perspective, 'ALB + Nginx' will be implemented as ingress approach. It uses a AWS ALB as internet facing load balancer, automatically managed by ALB Ingress Controller and the nginx will be responsible for the final routing.

## Prerequisites
1. AWS Credentials (Access key and secret access key)
2. kubectl
3. aws-iam-authenticator
4. aws-cli
5. terraform

### Deployment
1. Intialize the working directory
```
terraform init
```

2. Create the execution plan
```
terraform plan
```
After executing the above command, it should have created AWS EKS cluster, worker nodes, nginx and ALB ingress controller deployed to Kubernetes, AWS ALB configured along with necessary VPC, security groups and rules.

3. Configure the DNS
Add the alias record if there is a domain registered already or else add the cluster hostname in /etc/hosts file 