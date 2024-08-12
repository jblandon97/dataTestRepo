import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from pyspark.context import SparkContext
from awsglue.dynamicframe import DynamicFrame

# Parámetros del script
args = getResolvedOptions(sys.argv, ['dynamodb_table_name', 'bucket_name', 'file_key'])

# Inicializar el contexto de Glue
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

# Leer datos del bucket de S3
s3_path = f's3://{args["bucket_name"]}/{args["file_key"]}'
print(f"Ruta del archivo en S3: {s3_path}")

# Leer el archivo CSV
df = spark.read.format('csv') \
    .option('header', 'true') \
    .option('inferSchema', 'true') \
    .load(s3_path)

# Verificar el esquema de los datos leídos
df.printSchema()

# Convertir DataFrame a DynamicFrame
dynamic_frame = DynamicFrame.fromDF(df, glueContext, "dynamic_frame")

# Escribir los datos en DynamoDB
glueContext.write_dynamic_frame.from_options(
    frame = dynamic_frame,
    connection_type = "dynamodb",
    connection_options = {
        "dynamodb.output.tableName": args['dynamodb_table_name']
    }
)
