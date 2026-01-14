import boto3
import json
import time
from loguru import logger
import datetime

# CONFIGURACIÓN
STREAM_NAME = 'LOLRanks-stream'
REGION = 'us-east-1' # Cambia si usas otra región
INPUT_FILE = 'playerslol.json' # Archivo JSON de entrada

kinesis = boto3.client('kinesis', region_name=REGION)

def load_data(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def run_producer():
    data_list = load_data("playerslol.json")
    records_sent = 0
    
    # El JSON tiene una estructura 'included' donde están los arrays de valores    
    logger.info(f"Iniciando transmisión al stream: {STREAM_NAME}...")
    
    for data in data_list:
        Nombre_invocador = data['SUMMONERNAME']
        Rango = data['TIER']
        Division = data['RANK']
        Wins = data['WINS']
        Losses = data['LOSSES']
        Cola = data['QUEUE']
        Region = data['REQUEST_REGION']

        # Estructura del mensaje a enviar
        payload = {
            'SummonerName': Nombre_invocador,
            'Tier': Rango,
            'Rank': Division,
            'Wins': Wins,
            'Losses': Losses,
            'Queue': Cola,
            'Region': Region
        }
        
        # Enviar a Kinesis
        response = kinesis.put_record(
            StreamName=STREAM_NAME,
            Data=json.dumps(payload),
            PartitionKey=Region # Usamos el tipo como clave de partición
        )
        
        records_sent += 1
        logger.info(f"Registro enviado al shard {response['ShardId']} con SequenceNumber {response['SequenceNumber']}")
        logger.info(f"Enviado [{Nombre_invocador}]: {Rango} {Division} - Wins: {Wins}, Losses: {Losses}, Queue: {Cola}, Region: {Region}")
        
        # Pequeña pausa para simular streaming y no saturar de golpe
        time.sleep(0.01) 

    logger.info(f"Fin de la transmisión. Total registros enviados: {records_sent}")

if __name__ == '__main__':
    run_producer()