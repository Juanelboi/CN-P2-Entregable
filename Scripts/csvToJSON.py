import pandas as pd

# Cambia el nombre del archivo si es necesario
csv_file = "CSV_Masters+LOL.csv"
json_file = "CSV_Masters+LOL.json"

# Lee el CSV (ajusta el separador si no es coma, por ejemplo sep=';')
df = pd.read_csv(csv_file)  # [file:1]

# Exporta a JSON (orient='records' -> lista de objetos)
df.to_json(json_file, orient="records", force_ascii=False, indent=2)
