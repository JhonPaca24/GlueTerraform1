import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import expr 

args = getResolvedOptions(sys.argv,
                          ['JOB_NAME', 'source_path', 'destination_path'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Leer CSV desde S3
df = spark.read.format("csv").option("header", "true").load(args['source_path'])

# Transformaciones
df_transformed = (
    df.select("id", "nombre", "email")  # Filtrar columnas
      .withColumnRenamed("nombre", "nombre_completo")  # Renombrar columna
      .withColumn("nombre_completo", expr("trim(nombre_completo)"))  # Limpiar espacios
)

# Guardar resultado transformado
df_transformed.write.mode("overwrite").format("csv").option("header", "true").save(args['destination_path'])

job.commit()
