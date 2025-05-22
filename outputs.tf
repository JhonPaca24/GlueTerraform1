output "s3_bucket_url" {
  value = "s3://${aws_s3_bucket.datos_csv.bucket}/clientes/"
}

output "crawler_name" {
  value = aws_glue_crawler.clientes_crawler.name
}
