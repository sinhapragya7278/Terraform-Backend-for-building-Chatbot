module "service_resource" {

  source        = "../../b2b-aws-modules/modules/api-gateway/resources/"
  rest_api_id   = aws_api_gateway_rest_api.flintrts_api_gateway.id
  parent_id     = aws_api_gateway_rest_api.flintrts_api_gateway.root_resource_id
  resource_path = "service"

  depends_on = [
    aws_api_gateway_rest_api.flintrts_api_gateway
  ]
}

// POST service/flintrts/download-document-sections

module "service_flintrts_download_document_sections_post_method" {

  source                      = "../../b2b-aws-modules/modules/api-gateway/integration/"
  rest_api_id                 = aws_api_gateway_rest_api.flintrts_api_gateway.id
  resource_id                 = module.service_flintrts_download_document_sections_resource.resource_id
  http_method                 = "POST"
  integration_type            = "HTTP"
  authorization               = var.authorization_type.CUSTOM
  authorizer_id               = module.flintrts_eventbridge_authorizer.authorizer_id
  integration_endpoint_uri    = format("http://%s/${var.alb_context_path}/service/brandfolder/download-document-sections", var.alb_dns_name)
  integration_connection_type = "VPC_LINK"
  integration_connection_id   = var.vpc_link_id
  integration_http_method     = "POST"

  depends_on = [
    aws_api_gateway_rest_api.flintrts_api_gateway,
    module.service_flintrts_download_document_sections_resource,
    module.flintrts_lambda_authorizer
  ]
}

provider "aws" {
  region = "eu-central-1" // Example region, use your own
}

resource "aws_api_gateway_rest_api" "flintrts_api" {
  name        = "flint-rts-chatbot-dev-eu-central-1.api"
  description = "API Gateway for Flint RTS Chatbot"
  // Additional attributes...
}

// ... Repeat the resource block for other APIs as needed ...

// Template for a single resource and method
module "api_resource_template" {
  source        = "../../b2b-aws-modules/modules/api-gateway/resources/"
  rest_api_id   = aws_api_gateway_rest_api.flintrfs_api.id
  parent_id     = aws_api_gateway_rest_api.flintrfs_api.root_resource_id
  resource_path = "your-resource-path" // e.g., "service"

  depends_on = [
    aws_api_gateway_rest_api.flintrfs_api
  ]
}

module "api_method_template" {
  source       = "../../b2b-aws-modules/modules/api-gateway/method/"
  rest_api_id  = aws_api_gateway_rest_api.flintrfs_api.id
  resource_id  = module.api_resource_template.resource_id
  http_method  = "HTTP_METHOD" // Replace with "GET", "POST", etc.
  
  // EventBridge Integration attributes...
  // You will need to define how the method integrates with EventBridge.
  
  depends_on = [
    module.api_resource_template
  ]
}

// CORS configuration for each resource if needed
module "api_cors_template" {
  source      = "../../b2b-aws-modules/modules/api-gateway/cors"
  rest_api_id = aws_api_gateway_rest_api.flintrfs_api.id
  resource_id = module.api_resource_template.resource_id
  
  depends_on = [
    module.api_method_template
  ]
}

// ... Repeat these modules for each path and method ...

// Remember to replace "your-resource-path" and "HTTP_METHOD" with actual values from your environment.
