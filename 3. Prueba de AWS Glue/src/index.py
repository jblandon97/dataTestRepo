import json
import boto3
import os

def handler(event, context):
    # Extraer el nombre del archivo del evento de S3
    s3_event = event['Records'][0]['s3']
    bucket_name = s3_event['bucket']['name']
    file_key = s3_event['object']['key']

    print(f"Archivo subido: {file_key} en el bucket: {bucket_name}")

    # Obtener el nombre del job de Glue y el nombre de la tabla de DynamoDB desde las variables de entorno
    glue_job_name = os.environ['GLUE_JOB_NAME']
    dynamodb_table_name = os.environ['DYNAMODB_TABLE']

    # Crear un cliente de Glue
    glue = boto3.client('glue')

    # Ejecutar el job de Glue pasando el nombre del archivo, bucket y tabla DynamoDB como argumentos
    response = glue.start_job_run(
        JobName=glue_job_name,
        Arguments={
            '--file_key': file_key,
            '--bucket_name': bucket_name,
            '--dynamodb_table_name': dynamodb_table_name
        }
    )

    print(f"Job de Glue iniciado: {response['JobRunId']}")

    return {
        'statusCode': 200,
        'body': json.dumps('Proceso iniciado exitosamente!')
    }
