import datetime
import json
import base64

def lambda_handler(event, context):
    output = []
    for record in event["records"]:
        # Decodificar el dato original
        payload = base64.b64decode(record["data"]).decode("utf-8")
        data_json = json.loads(payload)

        # Add processing timestamp
        processing_time = datetime.datetime.now(datetime.timezone.utc)
        
        # Create the partition key (YYYY-MM-DD format)
        partition_date = processing_time.strftime('%Y-%m-%d')
        
        # Volver a serializar el JSON (sin modificar el contenido)
        encoded_data = base64.b64encode(
            (json.dumps(data_json) + "\n").encode("utf-8")
        ).decode("utf-8")

        output_record = {
            "recordId": record["recordId"],
            "result": "Ok",
            "data": encoded_data,
            "metadata": {
                "partitionKeys": {
                    "ProcessingDate": partition_date
                }
            }
        }
        output.append(output_record)

    return {"records": output}
