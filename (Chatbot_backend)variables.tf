variable "domain" {
  type        = string
  description = "The primary domain associated with the API gateway."
}

variable "business_context" {
  type = map(string)
  description = "A map containing contextual names for business units, used to construct resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g., 'prod', 'dev', 'staging')."
}

variable "region" {
  type        = string
  description = "AWS region where the resources will be deployed."
}

variable "resource_suffix" {
  type = map(string)
  description = "Suffixes for various resources to create unique names."
}

variable "domain_name_search" {
  type        = string
  description = "Domain name search pattern used for DNS configuration."
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to be applied to all AWS resources."
  default     = {}
}

variable "alb_dns_name" {
  type        = string
  description = "DNS name of the Application Load Balancer used for HTTP integrations."
}

variable "vpc_link_id" {
  type        = string
  description = "The ID of the VPC link used for integrating the API Gateway with internal network resources."
}

variable "flintrts_domain_name_security_policy" {
  type        = string
  description = "Security policy for the domain name associated with the API Gateway."
}

variable "flint_rts_chatbot_api_gateway_id" {
  type        = string
  description = "The API Gateway ID for the Flint RTS Chatbot."
}

variable "flint_rts_chatbot_service_resource" {
  type        = map(string)
  description = "Resource configuration for the root service of the Flint RTS Chatbot API."
}
