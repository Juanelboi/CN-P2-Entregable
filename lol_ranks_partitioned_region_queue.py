#Group By Region and Queue
import sys
import logging
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from pyspark.sql.functions import col, sum as spark_sum, avg
from awsglue.dynamicframe import DynamicFrame

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def main():
    args = getResolvedOptions(sys.argv, ['database', 'table', 'output_path'])
    database = args['database']
    table = args['table']
    output_path = args['output_path']

    logger.info(f"Database: {database}, Table: {table}, Output: {output_path}")

    sc = SparkContext()
    glueContext = GlueContext(sc)

    # Leer desde Glue Catalog
    dynamic_frame = glueContext.create_dynamic_frame.from_catalog(
        database=database,
        table_name=table
    )

    df = dynamic_frame.toDF()
    df.printSchema()
    logger.info(f"Registros leídos: {df.count()}")

    # Ajusta los nombres de columnas según cómo estén en tu tabla
    agg_df = df.groupBy("Region", "Queue","SummonerName","Tier","Rank") \
        .agg(  spark_sum("Wins").alias("Total_Wins"),
               spark_sum("Losses").alias("Total_Losses"),
            ) \
            .orderBy("Region", "Queue")

    output_dynamic_frame = DynamicFrame.fromDF(agg_df, glueContext, "output")

    logger.info(f"Registros agregados: {output_dynamic_frame.count()}")

    # Escribir particionando por Region
    glueContext.write_dynamic_frame.from_options(
        frame=output_dynamic_frame,
        connection_type="s3",
        connection_options={
            "path": output_path,
            "partitionKeys": ["Region","Queue"]
        },
        format="parquet",
        format_options={"compression": "snappy"}
    )

    logger.info(f"Completado. Registros: {agg_df.count()}")

if __name__ == "__main__":
    main()
