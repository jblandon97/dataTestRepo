variable "s3_bucket_name" {
  description = "Nombre del bucket de S3 donde se cargará el archivo plano."
  type        = string
  default     = "bucket-test-240811"
}

variable "dynamodb_table_name" {
  description = "Nombre de la tabla de DynamoDB."
  type        = string
  default     = "employees"
}

variable "glue_job_name" {
  description = "Nombre del job de Glue."
  type        = string
  default     = "load_employees_to_dydb"
}

variable "lambda_function_name" {
  description = "Nombre de la función lambda."
  type        = string
  default     = "s3-event-processor"
}
