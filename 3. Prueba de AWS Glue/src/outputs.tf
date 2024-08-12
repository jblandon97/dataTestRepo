output "s3_bucket_name" {
  value = aws_s3_bucket.input_bucket.bucket  
}

output "lambda_function_arn" {
  value = aws_lambda_function.s3_event_processor.arn  
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.data_table.name  
}

output "glue_job_name" {
  value = aws_glue_job.glue_job.name  
}
