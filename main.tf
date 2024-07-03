# Terraform-Backend-for-building-Chatbot
#This particular code is for building chatbot using pdf documents, it has 2 parts - Data ingestion and Chatbot
# RTS Data ingestion
locals {
  rts_tsg_s3_bucket_name = "${var.rts_domain}-${var.environment}-${var.aws_region}-${var.business_scope.ts_guides}-${var.resource_suffix.bucket_suffix}"
  rts_ptsg_s3_bucket_name = "${var.rts_domain}-${var.environment}-${var.aws_region}-${var.business_scope.processed_ts_guides}-${var.resource_suffix.bucket_suffix}"
  rts_ingestion_lambda_name = "${var.rts_domain}-${var.lambda_name.ingestion}-${var.environment}-${var.aws_region}-${var.business_scope.ts_guides}-${var.resource_suffix.lambda_suffix}"
}

data "aws_iam_policy_document" "rts_tsg_bucket_policy" {
  statement {
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.rts_tsg_s3_bucket_name}",
      "arn:aws:s3:::${local.rts_tsg_s3_bucket_name}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.caller_identity.account_id}:root"]
    }
  }
}

module "s3_rts_tsg_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.6.0"

  bucket        = local.rts_tsg_s3_bucket_name
  force_destroy = var.force_destroy

  versioning = {
    enabled = false
  }


  # Bucket policies
  attach_policy = true
  policy        = data.aws_iam_policy_document.rts_tsg_bucket_policy.json

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false

  # S3 Bucket Ownership Controls
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls
  control_object_ownership = true

  tags = merge(local.common_tags,
    {
      Name = local.rts_tsg_s3_bucket_name
  })
}

data "aws_iam_policy_document" "rts_ptsg_bucket_policy" {
  statement {
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.rts_ptsg_s3_bucket_name}",
      "arn:aws:s3:::${local.rts_ptsg_s3_bucket_name}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.caller_identity.account_id}:root"]
    }
  }
}

module "s3_rts_ptsg_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.6.0"

  bucket        = local.rts_ptsg_s3_bucket_name
  force_destroy = var.force_destroy

  versioning = {
    enabled = false
  }


  # Bucket policies
  attach_policy = true
  policy        = data.aws_iam_policy_document.rts_ptsg_bucket_policy.json

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false

  # S3 Bucket Ownership Controls
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls
  control_object_ownership = true

  tags = merge(local.common_tags,
    {
      Name = local.rts_ptsg_s3_bucket_name
  })
}

## Bucket Notification 
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.s3_rts_tsg_bucket.s3_bucket_id
  eventbridge = true
  # lambda_function {
  #   lambda_function_arn = module.rts_ingestion_lambda.lambda_function_arn
  #   events              = ["s3:ObjectCreated:*"]
  #   filter_suffix       = ".pdf"
  # }

  # depends_on = [module.rts_ingestion_lambda]
}


// IAM Role and policy for ecs task
data "aws_iam_policy_document" "rts_event_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "rts_ecs_events_role" {
  name               = "${var.rts_domain}-${var.app_name.ingestion}-${var.environment}-${var.aws_region}-${var.business_scope.event}-${var.config_rule_scope.iam_role}"
  assume_role_policy = data.aws_iam_policy_document.rts_event_assume_role.json
}

data "aws_iam_policy_document" "rts_ecs_events_run_task_with_any_role" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = [replace(module.flintrts_ingestion_task_defintion.ecs_task_definition_arn, "/:\\d+$/", "")]
  }
}
resource "aws_iam_role_policy" "rts_ecs_events_run_task_with_any_role" {
  name   = "${var.rts_domain}-${var.app_name.ingestion}-${var.environment}-${var.aws_region}-${var.business_scope.event}-${var.config_rule_scope.iam_role_policy}"
  role   = aws_iam_role.rts_ecs_events_role.id
  policy = data.aws_iam_policy_document.rts_ecs_events_run_task_with_any_role.json
}

resource "aws_iam_role_policy_attachment" "rts_ecs_events_ecs_policy" {
  role       = aws_iam_role.rts_ecs_events_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}

// EventBridge Rule
resource "aws_cloudwatch_event_rule" "rts_ingestion_rule" {
  name        = "${var.rts_domain}-ingestion-rule"
  description = ""

  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type": ["Object Created"],
    "detail": {
      "bucket": {
        "name": ["${module.s3_rts_tsg_bucket.s3_bucket_id}"]
      }
    }
  })
}

module "vpc_rts_ingestion_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "4.16.2"
  name        = "${var.rts_domain}-${var.environment}-${var.aws_region}-${var.app_name.ingestion}-${var.resource_suffix.sg_suffix}"
  description = "Security group for RTS Data Ingestion task"
  vpc_id      = module.vpc.vpc_id

  # Inbound rules for security groups
  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "http-80-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  # Outbound rules for security groups
  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = merge(local.common_tags,
    {
      Name = "${var.rts_domain}-${var.environment}-${var.aws_region}-${var.app_name.ingestion}-${var.resource_suffix.sg_suffix}"
  })
}

// Eventbridge Target
resource "aws_cloudwatch_event_target" "rts_ecs_event_target" {
  target_id = "${var.rts_domain}-ingestion-event-target"
  arn       = module.b2b_cluster.cluster_id
  rule      = aws_cloudwatch_event_rule.rts_ingestion_rule.name
  role_arn  = aws_iam_role.rts_ecs_events_role.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = module.flintrts_ingestion_task_defintion.ecs_task_definition_arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets = module.vpc.private_subnets
      security_groups = [module.vpc_rts_ingestion_sg.security_group_id]
    }
  }

  input_transformer {
    input_paths = {
      bucketname = "$.detail.bucket.name",
      objectkey   = "$.detail.object.key"
    }
    input_template = <<EOF
{
  "containerOverrides": [
    {
      "name": "${var.rts_domain}-${var.app_name.ingestion}-${var.environment}-${var.ecs_scope_sapc4c}-container",
      "environment" : [
        {
          "name" : "S3_BUCKET_NAME",
          "value" : <bucketname>
        },
        {
          "name" : "S3_OBJECT_KEY",
          "value" : <objectkey>
        }
      ]
    }
  ]
}
EOF
  }
}

data "aws_iam_policy_document" "rts_ecs_task_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${module.s3_rts_tsg_bucket.s3_bucket_arn}/*","${module.s3_rts_ptsg_bucket.s3_bucket_arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["textract:DetectDocumentText"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["bedrock:ListFoundationModels", "bedrock:InvokeModel"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["es:*"]
    resources = ["*"]
  }
}
resource "aws_iam_role_policy" "rts_ecs_task_policy" {
  name   = "${var.rts_domain}-${var.app_name.ingestion}-${var.environment}-${var.business_scope.task}-${var.config_rule_scope.iam_role_policy}"
  role   = split("/",module.flintrts_ingestion_task_defintion.ecs_task_role_arn)[1]
  policy = data.aws_iam_policy_document.rts_ecs_task_policy.json
}



# module "rts_ingestion_lambda" {
#   source        = "terraform-aws-modules/lambda/aws"
#   version       = "4.7.1"
#   function_name = local.rts_ingestion_lambda_name
#   description   = "This is lambda function for ${local.rts_ingestion_lambda_name}"
#   handler       = "lambda_function.lambda_handler"
#   runtime       = "python3.12"
#   environment_variables = {
#     NODE_ENV = var.environment
#   }
#   timeout      = 90
#   memory_size  = 512
#   tracing_mode = "Active"

#   publish = true

#   local_existing_package = "${path.module}/config/lambda-functions/rts-ingestion.zip"

#   create_package = false

#   vpc_subnet_ids         = module.vpc.private_subnets
#   vpc_security_group_ids = [module.main_sg.security_group_id]
#   attach_network_policy  = true

#   allowed_triggers = {
#     LambdaTriggerRule = {
#       principal  = "s3.amazonaws.com"
#       source_arn = "${module.s3_rts_tsg_bucket.s3_bucket_arn}"
#     }
#   }

#   tags = merge(local.common_tags,
#     {
#       Name = local.rts_ingestion_lambda_name
#   })
#   policies = [
#     "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess",
#     "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
#   ]
#   number_of_policies = 2
#   attach_policies    = true

#   create_current_version_allowed_triggers = false
#   attach_cloudwatch_logs_policy           = true
#   ignore_source_code_hash = true

#   attach_policy_statements = true
#   policy_statements = {
#     s3 = {
#       effect = "Allow",
#       actions = [
#         "s3:GetObject", 
#         "s3:PutObject"
#       ],
#       resources = ["${module.s3_rts_tsg_bucket.s3_bucket_arn}/*","${module.s3_rts_ptsg_bucket.s3_bucket_arn}/*"]
#     },
#     textract = {
#       effect = "Allow",
#       actions = [
#         "textract:DetectDocumentText"
#       ],
#       resources = ["*"]
#     },
#     bedrock = {
#       effect = "Allow",
#       actions = [
#         "bedrock:ListFoundationModels",
#         "bedrock:InvokeModel"
#       ],
#       resources = ["*"]
#     }
#   }
# }
