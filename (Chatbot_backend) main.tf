// Defining local variables and common naming patterns
locals {
  flintrts_api_gateway_prefix = "${var.domain}-${var.business_context.flintrts}-${var.environment}-${var.region}"
  updated_domain_name         = var.environment == "prod" ? "${var.domain}-${var.business_context.flintrts}-${var.region}-${var.resource_suffix.api_suffix}.${var.domain_name_search}" : "${local.flintrts_api_gateway_prefix}-${var.resource_suffix.api_suffix}.${var.domain_name_search}"

  retrigger = [
    "${var.environment}",
    "${var.region}",
    "${var.domain}",
    "${sha1(file("${path.module}/main.tf"))}",
    "${sha1(file("${path.module}/flintrts.tf"))}"
  ]
}

// API Gateway for Flint RTS Chatbot
resource "aws_api_gateway_rest_api" "flintrts_chatbot_api_gateway" {
  name        = "${local.flintrts_api_gateway_prefix}-${var.resource_suffix.api_suffix}"
  description = "Flint RTS Chatbot API Gateway for ${var.environment}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.common_tags,
    {
      Name = "${local.flintrts_api_gateway_prefix}-${var.resource_suffix.api_suffix}"
  })
}


#Authorizer
module "flintrts_lambda_authorizer" {

  source          = "../../b2b-aws-modules/modules/api-gateway/authorizer/"
  authorizer_name = "${local.flintrts_api_gateway_prefix}-${var.resource_suffix.authorizer_suffix}"
  rest_api_id     = aws_api_gateway_rest_api.flintrts_api_gateway.id
  authorizer_type = "TOKEN"
  header_name     = var.flintrts_authorization_header
  authorizer_uri  = var.lambda_authorizer_uri

  depends_on = [
    aws_api_gateway_rest_api.flintrts_api_gateway
  ]
}

resource "aws_lambda_permission" "flintcms_permissions" {
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_authorizer_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.aws_account_id}:${aws_api_gateway_rest_api.flintcms_api_gateway.id}/*/authorizers/*"
}

// Modules for different API resources and methods as defined
module "flint_rts_chatbot_api_resource" {
  source        = "../../b2b-aws-modules/modules/api-gateway/resources/"
  rest_api_id   = aws_api_gateway_rest_api.flintrts_chatbot_api_gateway.id
  parent_id     = module.flint_rts_chatbot_service_resource.resource_id
  resource_path = "api"
}

module "flint_rts_chatbot_chatsessions_resource" {
  source        = "../../b2b-aws-modules/modules/api-gateway/resources/"
  rest_api_id   = aws_api_gateway_rest_api.flintrts_chatbot_api_gateway.id
  parent_id     = module.flint_rts_chatbot_api_resource.resource_id
  resource_path = "chatsessions"
}

module "flint_rts_chatbot_chatsessions_post_method" {
  source                      = "../../b2b-aws-modules/modules/api-gateway/integration/"
  rest_api_id                 = aws_api_gateway_rest_api.flintrts_chatbot_api_gateway.id
  resource_id                 = module.flint_rts_chatbot_chatsessions_resource.resource_id
  http_method                 = "POST"
  integration_type            = "HTTP"
  authorization               = "NONE"
  integration_endpoint_uri    = "${local.api_base_url}/chatsessions"
  integration_connection_type = "VPC_LINK"
  integration_connection_id   = var.vpc_link_id
  integration_http_method     = "POST"
}

module "flint_rts_chatbot_chatsessions_cors_enable" {
  source      = "../../b2b-aws-modules/modules/api-gateway/cors"
  rest_api_id = aws_api_gateway_rest_api.flintrts_chatbot_api_gateway.id
  resource_id = module.flint_rts_chatbot_chatsessions_resource.resource_id
}

module "flint_rts_chatbot_custom_domain_name" {
  source                      = "../../b2b-aws-modules/modules/api-gateway/custom-domain/"
  domain_name                 = local.updated_domain_name
  common_tags                 = var.common_tags
  domain_name_search          = "*.${var.domain_name_search}"
  domain_name_security_policy = var.flintrts_domain_name_security_policy
}

// Deployment of the API Gateway
resource "aws_api_gateway_deployment" "flintrts_chatbot_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.flintrts_chatbot_api_gateway.id
  stage_name  = var.environment

  deployment_trigger = sha1(jsonencode(local.retrigger))

  depends_on = [
    module.flint_rts_chatbot_chatsessions_post_method,
    module.flint_rts_chatbot_chatsessions_cors_enable,
    // Add other method modules as needed
  ]
}
