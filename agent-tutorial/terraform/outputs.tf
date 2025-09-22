output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.datetime_function.arn
}

output "execution_role_arn" {
  description = "Execution role ARN for the Lambda function"
  value       = aws_iam_role.lambda_exec_role.arn
}
