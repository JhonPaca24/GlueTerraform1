variable "bucket_name" {
  type        = string
  description = "Nombre del bucket S3"
}

variable "csv_file_name" {
  type        = string
  description = "Nombre del archivo CSV local"
}

variable "csv_s3_key" {
  type        = string
  description = "Ruta en S3 donde se sube el CSV"
}

variable "glue_database" {
  type        = string
  description = "Nombre de la base de datos Glue"
}

variable "glue_crawler" {
  type        = string
  description = "Nombre del crawler Glue"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
}
