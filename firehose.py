import json
import base64

def lambda_handler(event, context):
    output = []
    for record in event["records"]:
        # Decodificar el dato original
        payload = base64.b64decode(record["data"]).decode("utf-8")
        data_json = json.loads(payload)

        region = data_json.get("Region", "unknown_region")

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
                    "Region": region,
                }
            }
        }
        output.append(output_record)

    return {"records": output}
