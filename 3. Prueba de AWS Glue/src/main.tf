provider "aws" {
  region = "us-east-1"
}

# Crear un bucket de S3 donde se cargarán los archivos de entrada
resource "aws_s3_bucket" "input_bucket" {
  bucket = var.s3_bucket_name # Nombre único del bucket
}

# Crear una tabla de DynamoDB para almacenar los datos procesados
resource "aws_dynamodb_table" "data_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Crear un rol de IAM que será usado por la función Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Adjuntar políticas al rol de IAM para permitir a la Lambda interactuar con S3 y DynamoDB
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


# Crear la política personalizada de S3 para permitir a Glue acceder al bucket
resource "aws_iam_policy" "glue_s3_access_policy" {
  name        = "glue-s3-access-policy"
  description = "Policy allowing Glue to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.input_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.input_bucket.bucket}/*"
        ]
      },

    ]
  })
}


# Crear una política personalizada para Glue y adjuntarla al rol de Lambda
resource "aws_iam_policy" "lambda_glue_policy" {
  name        = "LambdaGluePolicy"
  description = "Permite a la función Lambda invocar trabajos de AWS Glue"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_glue_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_glue_policy.arn
}


# Crear la función Lambda que procesará los eventos de S3
resource "aws_lambda_function" "s3_event_processor" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.8"

  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.input_bucket.bucket
      DYNAMODB_TABLE = aws_dynamodb_table.data_table.name
      GLUE_JOB_NAME  = var.glue_job_name
    }
  }
}

# Configurar una notificación de eventos de S3 que invocará la Lambda cada vez que se suba un archivo
resource "aws_s3_bucket_notification" "s3_notification" {
  bucket = aws_s3_bucket.input_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_event_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Permitir que S3 invoque la función Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3InvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_event_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input_bucket.arn
}

# Subir el script de Glue al bucket de S3
resource "aws_s3_bucket_object" "glue_script" {
  bucket = aws_s3_bucket.input_bucket.bucket
  key    = "glue-scripts/${var.glue_job_name}.py"
  source = "./${var.glue_job_name}.py" # Ruta local del script PySpark
}


# Crear un rol de IAM para el job de Glue
resource "aws_iam_role" "glue_role" {
  name = "glue-job-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Adjuntar una política de IAM al rol de Glue para DynamoDB
resource "aws_iam_policy" "glue_dynamodb_policy" {
  name        = "glue-dynamodb-policy"
  description = "Permite a Glue describir y escribir en la tabla de DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem"
        ],
        Resource = "arn:aws:dynamodb:us-east-1:324037310116:table/employees"
      }
    ]
  })
}

# Adjuntar la política al rol de Glue
resource "aws_iam_role_policy_attachment" "glue_s3_policy" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_s3_access_policy.arn
}

# Asociar la política de DynamoDB al rol de Glue
resource "aws_iam_role_policy_attachment" "glue_dynamodb_attachment" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_dynamodb_policy.arn
}

# Crear un job de Glue que procesará los datos y los cargará en DynamoDB
resource "aws_glue_job" "glue_job" {
  name     = var.glue_job_name
  role_arn = aws_iam_role.glue_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.input_bucket.bucket}/glue-scripts/${var.glue_job_name}.py"
    python_version  = "3"
  }

  # Configuración de recursos
  worker_type       = "G.1X" # Tipo de worker
  number_of_workers = 2      # Número de workers

}


