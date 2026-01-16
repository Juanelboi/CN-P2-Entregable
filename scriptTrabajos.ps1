$env:ACCOUNT_ID = $(aws sts get-caller-identity --query Account --output text)
$env:BUCKET_NAME = "datalake-jugadores-master-$($env:ACCOUNT_ID)"
$env:DATABASEPROCESSED = "players_lol_db_processed"
$env:ACCOUNT_ID = $(aws sts get-caller-identity --query Account --output text)
$env:BUCKET_NAME = "datalake-jugadores-master-$($env:ACCOUNT_ID)"
$env:DATABASEPROCESSED = "players_lol_db_processed"

Write-Output "--- Crawler & Jobs Execution"

aws glue start-crawler --name "playersLol-raw-crawler"
Write-Output "--- Crawler raw started"
Start-Sleep -Seconds 120
Write-Output "--- Crawler raw finished"

aws glue start-job-run --job-name "lol_ranks_partitioned_region_queue"
Write-Output "--- job region_queue started"
Start-Sleep -Seconds 120
Write-Output "--- job region_queue finished"

aws glue start-job-run --job-name "lol_ranks_partitioned_region_tier"
Write-Output "--- job region_tier started"
Start-Sleep -Seconds 120
Write-Output "--- job region_tier finished"

aws glue start-crawler --name "playersLol-processed-crawler"
Write-Output "--- Crawler processed started"
Start-Sleep -Seconds 120
Write-Output "--- Crawler processed finished"

Write-Output "Athenna Querys Execution"
aws athena start-query-execution `
  --query-string "SELECT * FROM regions_rank Limit 5" `
  --query-execution-context Database=$env:DATABASEPROCESSED `
  --result-configuration "OutputLocation=s3://$($env:BUCKET_NAME)/queries/"
Start-Sleep -Seconds 5
  aws athena start-query-execution `
  --query-string "SELECT * FROM regions_queue Limit 5" `
  --query-execution-context Database=$env:DATABASEPROCESSED `
  --result-configuration "OutputLocation=s3://$($env:BUCKET_NAME)/queries/"