###########################
# Data sources
###########################
data "aws_caller_identity" "current" {}


###########################
# IAM Role for Lambda
###########################
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_datetime_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

###########################
# Lambda Function
###########################
data "archive_file" "lambda_zip" {
  type = "zip"
  source_content = <<EOF
import datetime
import json

def lambda_handler(event, context):
    now = datetime.datetime.now()

    response = {"date": now.strftime("%Y-%m-%d"), "time": now.strftime("%H:%M:%S")}

    response_body = {"application/json": {"body": json.dumps(response)}}

    action_response = {
        "actionGroup": event["actionGroup"],
        "apiPath": event["apiPath"],
        "httpMethod": event["httpMethod"],
        "httpStatusCode": 200,
        "responseBody": response_body,
    }

    session_attributes = event["sessionAttributes"]
    prompt_session_attributes = event["promptSessionAttributes"]

    return {
        "messageVersion": "1.0",
        "response": action_response,
        "sessionAttributes": session_attributes,
        "promptSessionAttributes": prompt_session_attributes,
    }
EOF
  source_content_filename = "index.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "datetime_function" {
  function_name    = "DateTimeFunction"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

###########################
# Resource-based Policy (Bedrock)
###########################
resource "aws_lambda_permission" "allow_bedrock" {
  statement_id  = "AllowBedrockInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.datetime_function.function_name
  principal     = "bedrock.amazonaws.com"

  source_arn = "arn:aws:bedrock:${var.aws_region_bedrock}:${data.aws_caller_identity.current.account_id}:agent/*"
}

# --------------------------------------------------------
# IAM Role for the Agent
# --------------------------------------------------------
resource "aws_iam_role" "bedrock_agent_role" {
  name = "bedrock-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "bedrock.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# --------------------------------------------------------
# IAM Policy for Bedrock + Lambda Invoke
# --------------------------------------------------------
resource "aws_iam_role_policy" "bedrock_agent_policy" {
  name = "bedrock-agent-policy"
  role = aws_iam_role.bedrock_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AmazonBedrockAgentBedrockFoundationModelPolicyProd"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region_bedrock}::foundation-model/${var.agent_llm}"
        ]
      }
    ]
  })
}

# Inline policy to allow invoking the Lambda function
resource "aws_iam_role_policy" "lambda_invoke_policy" {
  name = "BedrockAgentLambdaInvoke"
  role = aws_iam_role.bedrock_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = aws_lambda_function.datetime_function.arn
      }
    ]
  })
}

# --------------------------------------------------------
# Bedrock Agent
# --------------------------------------------------------
resource "aws_bedrockagent_agent" "my_agent" {
  agent_name              = "agent-bedrock-datetime"
  description             = "A friendly chatbot agent"
  foundation_model        = "${var.agent_llm}"
  instruction             = <<EOT
You are a friendly chat bot. You have access to a function called that returns
information about the current date and time. When responding with date or time,
please make sure to add the timezone UTC.
EOT
  agent_resource_role_arn = aws_iam_role.bedrock_agent_role.arn

  idle_session_ttl_in_seconds = 300

  # Important: after apply, you may need to "prepare-agent" manually
  #   aws bedrock-agent prepare-agent --agent-id <id>
}

# --------------------------------------------------------
# Bedrock Agent Action Group
# --------------------------------------------------------
resource "aws_bedrockagent_agent_action_group" "time_actions" {
  agent_id           = aws_bedrockagent_agent.my_agent.id
  agent_version      = "DRAFT"
  action_group_name  = "TimeActions"
  description        = "Action group for date/time operations"
  action_group_state = "DISABLED"

  action_group_executor {
    lambda = aws_lambda_function.datetime_function.arn
  }

  api_schema {
    payload = <<YAML
openapi: 3.0.0
info:
  title: Time API
  version: 1.0.0
  description: API to get the current date and time.
paths:
  /get-current-date-and-time:
    get:
      summary: Gets the current date and time.
      description: Gets the current date and time.
      operationId: getDateAndTime
      responses:
        '200':
          description: Gets the current date and time.
          content:
            'application/json':
              schema:
                type: object
                properties:
                  date:
                    type: string
                    description: The current date
                  time:
                    type: string
                    description: The current time
YAML
  }
}


