# Servians-Code-Challenge

Code Challenge for DevOps consultant

## Introduction

This infrastructure designed for build and deploy TechAppChallenge on AWS Cloud platform for demo purposes.

## Prerequisites

* AWS Account with EKS, VPC, EC2, ELB, S3, SSM, RDS, IAM, Cloud Watch Logs Administrator Access
* AWS CLI, Terraform installed 
* Network reachability to "http://ipv4.icanhazip.com" (in evaluating public IP of Terraform core Workstation)

## Architecture

### Architecture Diagram.
![Architecture Diagram](https://github.com/codereposumudu/servians-coding-challenge/blob/356a5020640ed93740e4ba4e444f92f62eb5d9f6/infrastructure/Diagrams/application.png)

```
Note : If you dont see image in the documentation please be kind enough to find the image from below path in the git repository


servians-code-challenge/infrastructure/Diagrams/servians-architecture-diagram.png
```
## Directory Details

* Environments : Directory Contains different environment directories. Backend and terraform configuration files are located under those environment folder. As for Demo purpose added one environment directory call preprod

* Infrastructure : This directory contains all the source code need to provision environment. Subdirectories module contains
all modules related to infrastructure. Inside diagram folder you can see diagrams related to this work.
  
* .github/workflows : Contains CI/CD pipeline

* .kube : Contains Deployment yaml relate to pipeline script.


## CI / CD workflows

* We can use jenkins / github workflows as a push based deployments.
* Also we can use gitops (Argocd, Flux) for CD part to deploy configurations as pull based deployments.
* For Demo purpose added github workflow yaml, into .github/workflows folder

## Let's provision the infrastructure


* To configure infrastructure, you need to declare below environment variables

  ```bash
  export AWS_ACCESS_KEY_ID=
  export AWS_SECRET_ACCESS_KEY=
  export AWS_DEFAULT_REGION=ap-southeast-1
  export ENVIRONMENT=preprod
  export BACKEND_S3_BUCKET=
  ```

* Create S3 Bucket using AWS CLI or console to store state files. Please put created bucket name inside the "Servians-code-challenge/environments/preprod/backend.conf" under the bucket.
  ```
  aws s3 mb s3://${AWS_S3_BUCKET}
  aws s3api put-public-access-block \
  --bucket ${BACKEND_S3_BUCKET} \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  ```

* Download dependencies for the terraform execution

  ```
  cd servians-code-challenge/infartructure
  terraform init -backend=true -backend-config=../environments/preprod/backend.conf
  ```
* Deploy the infrastructure

  ```
  cd terraform/infrastructure
  terraform plan -var-file="../environments/preprod/servians_preprod.tfvars" -out=.terraform/terraform.tfplan
  terraform apply .terraform/terraform.tfplan
  ```
  
* Destroy the infarstructure

  ```
  cd servians-code-challenge/infrastructure
  terraform destroy -var-file="../environments/preprod/servians_preprod.tfvars"
  ```
  
## CI / CD Configurations
* To configure CI / CD need to go to github repository and create github secrets with below variables to declare pipeline variables.

  ```
  WORKFLOW_TOKEN (github token)
  AWS_ACCESS_KEY_ID ( AWS programmetic access)
  AWS_SECRET_ACCESS_KEY ( AWS programmetic access)
  KUBE_CONFIG_SERVIANS_DEV ( Kube config for authentication)
  
  ```










