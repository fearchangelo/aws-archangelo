variable "aws_region_bedrock" {
  description = "Region where Bedrock is available"
  type        = string
  default     = "ca-central-1"
}

variable "aws_region_lambda" {
  description = "Region where Lambda is available"
  type        = string
  default     = "ca-central-1"
}

variable "agent_llm" {
  description = "LLM to be used in the agent"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

