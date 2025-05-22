provider "aws" {
  region = var.aws_region
}

###############################
# 1. Crear Bucket en S3
###############################

resource "aws_s3_bucket" "datos_csv" {
  bucket = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block_access" {
  bucket = aws_s3_bucket.datos_csv.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################
# 2. Glue Database
###############################

resource "aws_glue_catalog_database" "clientes_db" {
  name = var.glue_database
}

###############################
# 3. Rol IAM para Glue
###############################

resource "aws_iam_role" "glue_crawler_role" {
  name = "glue_crawler_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
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

resource "aws_iam_role_policy" "glue_crawler_policy" {
  name = "glue_crawler_policy"
  role = aws_iam_role.glue_crawler_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.datos_csv.arn}",
          "${aws_s3_bucket.datos_csv.arn}/*"
        ]
      },
      {
        Action = [
          "glue:*"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "glue_service_role" {
  name = "glue_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "glue_service_policy" {
  name = "glue_service_policy"
  role = aws_iam_role.glue_service_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:*",
          "glue:*",
          "logs:*"
        ],
        Resource = "*"
      }
    ]
  })
}

###############################
# 4. Crawler
###############################

resource "aws_glue_crawler" "clientes_crawler" {
  name          = var.glue_crawler
  role          = aws_iam_role.glue_crawler_role.arn
  database_name = aws_glue_catalog_database.clientes_db.name
  description   = "Crawler para leer archivos CSV de clientes en S3"

  s3_target {
    path = "s3://${aws_s3_bucket.datos_csv.bucket}/${dirname(var.csv_s3_key)}/"
  }

  schema_change_policy {
    delete_behavior = "DEPRECATE_IN_DATABASE"
    update_behavior = "UPDATE_IN_DATABASE"
  }
}

###############################
# 5. Subir CSV a S3 con Terraform
###############################

resource "aws_s3_object" "clientes_csv" {
  bucket = aws_s3_bucket.datos_csv.id
  key    = var.csv_s3_key
  source = "${path.module}/${var.csv_file_name}"
  etag   = filemd5("${path.module}/${var.csv_file_name}")
  content_type = "text/csv"
}

###############################
# 6. glue job 
###############################

resource "aws_glue_job" "transformar_clientes" {
  name     = "job-transformar-clientes"
  role_arn = aws_iam_role.glue_service_role.arn
  glue_version = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"
  max_retries       = 0

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.datos_csv.bucket}/scripts/transform_clientes.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"           = "python"
    "--TempDir"                = "s3://${aws_s3_bucket.datos_csv.bucket}/tmp/"
    "--class"                  = "GlueApp"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"         = "true"
    "--source_path"            = "s3://${aws_s3_bucket.datos_csv.bucket}/clientes/"
    "--destination_path"       = "s3://${aws_s3_bucket.datos_csv.bucket}/salida_clientes/"
  }
}

################################
# 7. crear el bucket destino
################################

resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.datos_csv.id
  key    = "scripts/transform_clientes.py"
  source = "${path.module}/transform_clientes.py"
  etag   = filemd5("${path.module}/transform_clientes.py")
}


