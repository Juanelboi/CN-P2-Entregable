$env:AWS_REGION = "us-east-1"
$env:ACCOUNT_ID = $(aws sts get-caller-identity --query Account --output text)
$env:BUCKET_NAME = "datalake-jugadores-master-$($env:ACCOUNT_ID)"
$env:ROLE_ARN = $(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

Write-Output "--- Kinesis & S3"

# Crear el bucket (ignora error si ya existe)
aws s3 mb "s3://$($env:BUCKET_NAME)"

# Crear carpetas
aws s3api put-object --bucket $env:BUCKET_NAME --key "raw/"
aws s3api put-object --bucket $env:BUCKET_NAME --key "raw/players_master_or_higher/"
aws s3api put-object --bucket $env:BUCKET_NAME --key "processed/"
aws s3api put-object --bucket $env:BUCKET_NAME --key "queries/"
aws s3api put-object --bucket $env:BUCKET_NAME --key "scripts/"
aws s3api put-object --bucket $env:BUCKET_NAME --key "errors/"

aws kinesis create-stream `
  --stream-name LOLRanks-stream `
  --shard-count 1

Start-Sleep -Milliseconds 500
Write-Output "--- FIREHOSE"

# Empaquetar Lambda
Compress-Archive firehose.py firehose.zip -Force

# Crear/actualizar Lambda
aws lambda create-function `
  --function-name playersLol-firehose-lambda `
  --runtime python3.12 `
  --role $env:ROLE_ARN `
  --handler "firehose.lambda_handler" `
  --zip-file "fileb://firehose.zip" `
  --timeout 60 `
  --memory-size 128

aws lambda update-function-code `
  --function-name playersLol-firehose-lambda `
  --zip-file "fileb://firehose.zip"


$env:DATABASERAW = "players_lol_db_raw"
$env:DATABASEPROCESSED = "players_lol_db_processed"
$env:TABLE = "players_master_or_higher"
$env:DAILY_OUTPUT = "s3://$($env:BUCKET_NAME)/processed/regions_queue/"
$env:MONTHLY_OUTPUT = "s3://$($env:BUCKET_NAME)/processed/regions_rank/"
$env:LAMBDA_ARN = $(aws lambda get-function --function-name playersLol-firehose-lambda --query 'Configuration.FunctionArn' --output text)

# JSON ExtendedS3DestinationConfiguration como here-string
$extendedS3 = @"
{
  ""BucketARN"": ""arn:aws:s3:::$($env:BUCKET_NAME)"",
  ""RoleARN"": ""$($env:ROLE_ARN)"",
  ""Prefix"": ""raw/players_master_or_higher/ProcessingDate=!{partitionKeyFromLambda:ProcessingDate}/"",
  ""ErrorOutputPrefix"": ""errors/!{firehose:error-output-type}/"",
  ""BufferingHints"": {
    ""SizeInMBs"": 64,
    ""IntervalInSeconds"": 60
  },
  ""DynamicPartitioningConfiguration"": {
    ""Enabled"": true,
    ""RetryOptions"": {
      ""DurationInSeconds"": 300
    }
  },
  ""ProcessingConfiguration"": {
    ""Enabled"": true,
    ""Processors"": [
      {
        ""Type"": ""Lambda"",
        ""Parameters"": [
          {
            ""ParameterName"": ""LambdaArn"",
            ""ParameterValue"": ""$($env:LAMBDA_ARN)""
          },
          {
            ""ParameterName"": ""BufferSizeInMBs"",
            ""ParameterValue"": ""1""
          },
          {
            ""ParameterName"": ""BufferIntervalInSeconds"",
            ""ParameterValue"": ""60""
          }
        ]
      }
    ]
  }
}
"@

aws firehose create-delivery-stream `
  --delivery-stream-name "playersLol-delivery-stream" `
  --delivery-stream-type "KinesisStreamAsSource" `
  --kinesis-stream-source-configuration "KinesisStreamARN=arn:aws:kinesis:$($env:AWS_REGION):$($env:ACCOUNT_ID):stream/LOLRanks-stream,RoleARN=$($env:ROLE_ARN)" `
  --extended-s3-destination-configuration "$extendedS3"
  
  Start-Sleep -Milliseconds 500
  Write-Output "--- GLUE"
  
  # Database

$databaseInputRaw = @"
{
  ""Name"": ""$($env:DATABASERAW)""
}
"@

aws glue create-database `
  --database-input "$databaseInputRaw"

$targetsglue = @"
{
  ""S3Targets"": [
    {
      ""Path"": ""s3://$($env:BUCKET_NAME)/raw/players_master_or_higher""
    }
  ]
}
"@

aws glue create-crawler `
  --name "playersLol-raw-crawler" `
  --role $env:ROLE_ARN `
  --database-name $env:DATABASERAW `
  --targets "$targetsglue"
  
$env:DATABASEPROCESSED = "players_lol_db_processed"
$databaseInputProcessed = @"
{
  ""Name"": ""$($env:DATABASEPROCESSED)""
}
"@

aws glue create-database `
  --database-input "$databaseInputProcessed"

$targetsglue = @"
{
  ""S3Targets"": [
    {
      ""Path"": ""s3://$($env:BUCKET_NAME)/processed/""
    }
  ]
}
"@

aws glue create-crawler `
  --name "playersLol-processed-crawler" `
  --role $env:ROLE_ARN `
  --database-name $env:DATABASEPROCESSED `
  --targets "$targetsglue"


  
  
  Start-Sleep -Milliseconds 500
  
  
  Write-Output "--- GLUE ETL Uploading"
  aws s3 cp "lol_ranks_partitioned_region_queue.py" "s3://$($env:BUCKET_NAME)/scripts/"
  aws s3 cp "lol_ranks_partitioned_region_tier.py" "s3://$($env:BUCKET_NAME)/scripts/"


  
Write-Output "--- GLUE ETL Creating Jobs"
Start-Sleep -Milliseconds 500

# Command JSON para Glue jobs

$RanksCommand = @"
{
  ""Name"": ""glueetl"",
  ""ScriptLocation"": ""s3://$($env:BUCKET_NAME)/scripts/lol_ranks_partitioned_region_tier.py"",
  ""PythonVersion"": ""3""
}
"@
$RanksArgs = @"
{
  ""--database"": ""$($env:DATABASERAW)"",
  ""--table"": ""$($env:TABLE)"",
  ""--output_path"": ""s3://$($env:BUCKET_NAME)/processed/regions_rank/"",
  ""--enable-continuous-cloudwatch-log"": ""true"",
  ""--spark-event-logs-path"": ""s3://$($env:BUCKET_NAME)/logs/""
}
"@

$QueueCommand = @"
{
  ""Name"": ""glueetl"",
  ""ScriptLocation"": ""s3://$($env:BUCKET_NAME)/scripts/lol_ranks_partitioned_region_queue.py"",
  ""PythonVersion"": ""3""
}
"@

# Default arguments para Glue jobs

$QueueArgs = @"
{
  ""--database"": ""$($env:DATABASERAW)"",
  ""--table"": ""$($env:TABLE)"",
  ""--output_path"": ""s3://$($env:BUCKET_NAME)/processed/regions_queue/"",
  ""--enable-continuous-cloudwatch-log"": ""true"",
  ""--spark-event-logs-path"": ""s3://$($env:BUCKET_NAME)/logs/""
}
"@

aws glue create-job `
  --name "lol_ranks_partitioned_region_tier" `
  --role $env:ROLE_ARN `
  --command "$RanksCommand" `
  --default-arguments "$RanksArgs" `
  --glue-version "4.0" `
  --number-of-workers 2 `
  --worker-type "G.1X"

aws glue create-job `
  --name "lol_ranks_partitioned_region_queue" `
  --role $env:ROLE_ARN `
  --command "$QueueCommand" `
  --default-arguments "$QueueArgs" `
  --glue-version "4.0" `
  --number-of-workers 2 `
  --worker-type "G.1X"