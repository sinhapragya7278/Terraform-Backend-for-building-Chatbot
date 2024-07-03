output "api_gateway_id" {
  value       = aws_api_gateway_rest_api.flintrts_chatbot_api_gateway.id
  description = "The ID of the Flint RTS Chatbot API Gateway."
}

output "api_gateway_name" {
  value       = aws_api_gateway_rest_api.flintrts_chatbot_api_gateway.name
  description = "The name of the Flint RTS Chatbot API Gateway."
}

output "api_gateway_endpoint" {
  value       = aws_api_gateway_rest_api.flintrts_chatbot_api_gateway.execution_arn
  description = "The execution ARN of the Flint RTS Chatbot API Gateway, which can be used to invoke the API."
}

output "custom_domain_name" {
  value       = module.flint_rts_chatbot_custom_domain_name.domain_name
  description = "The custom domain name associated with the Flint RTS Chatbot API Gateway."
}

output "api_gateway_deployment_id" {
  value       = aws_api_gateway_deployment.flintrts_chatbot_api_deployment.id
  description = "The deployment ID of the Flint RTS Chatbot API Gateway."
}

output "api_base_url" {
  value       = local.api_base_url
  description = "The base URL for the API, constructed from the ALB DNS name and the environment configuration."
}

output "flintrts_custom_domain_full_url" {
  value       = "https://${local.updated_domain_name}"
  description = "The full URL for the custom domain associated with the Flint RTS Chatbot API Gateway."
}
