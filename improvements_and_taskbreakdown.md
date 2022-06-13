#Code Challenge App Improvements and Task Breakdown

##Improvements ( Suggesions)

* Whitelist IP's from security Group level
* Cloud Front enable for caching (Put infront of ALB)
* WAF for enable more security (Attach with the load balancer)
* Implement proper log monitoring and management stack ( Elasticsearch / Logstash / Kibana )
* Integrate with Performance monitoring platform ( Grafana / Prometheus)
* Implement Service meshes for canary deployments with GitOps tools ( Linkerd / Flagger /Argocd or Flux)
* Enable Cluster AutoScaler
* Using GitOps and Jenkins Master,slave architecture for deployments in CI/CD pipelines.




##Task Breakdown

* Design architecture Diagram
* Implementing Core module with VPC,private subnets and Design natgateway to get internet to private subnets.
* Implementing Database module with auto generated password and usernames also it is designed to deploy inside private subnets
* Designed other modules for security / certificates / Bastion and Configurations
* Creating CI/CD github workflow Script.
* Using Gitflow as the git workflow
* Implement Resilience in EKS and Database ( High available and autoscaling)




