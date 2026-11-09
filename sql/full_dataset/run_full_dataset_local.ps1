param(
 [string]$DatasetPath=(Join-Path $PSScriptRoot '..\..\Dataset'),
 [string]$Psql='C:\Program Files\PostgreSQL\18\bin\psql.exe',
 [string]$Database='postgres',
 [string]$User='postgres',
 [string]$DbHost='localhost',
 [int]$Port=5432,
 [string]$EffectiveDate=(Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference='Stop'
$specs=@(
 @{File='olist_customers_dataset.csv';Table='stg_customers';Columns='customer_id,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state';Header='customer_id,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state'},
 @{File='olist_orders_dataset.csv';Table='stg_orders';Columns='order_id,customer_id,order_status,order_purchase_timestamp,order_approved_at,order_delivered_carrier_date,order_delivered_customer_date,order_estimated_delivery_date';Header='order_id,customer_id,order_status,order_purchase_timestamp,order_approved_at,order_delivered_carrier_date,order_delivered_customer_date,order_estimated_delivery_date'},
 @{File='olist_order_items_dataset.csv';Table='stg_order_items';Columns='order_id,order_item_id,product_id,seller_id,shipping_limit_date,price,freight_value';Header='order_id,order_item_id,product_id,seller_id,shipping_limit_date,price,freight_value'},
 @{File='olist_products_dataset.csv';Table='stg_products';Columns='product_id,product_category_name,product_name_lenght,product_description_lenght,product_photos_qty,product_weight_g,product_length_cm,product_height_cm,product_width_cm';Header='product_id,product_category_name,product_name_lenght,product_description_lenght,product_photos_qty,product_weight_g,product_length_cm,product_height_cm,product_width_cm'},
 @{File='olist_sellers_dataset.csv';Table='stg_sellers';Columns='seller_id,seller_zip_code_prefix,seller_city,seller_state';Header='seller_id,seller_zip_code_prefix,seller_city,seller_state'},
 @{File='olist_order_reviews_dataset.csv';Table='stg_reviews';Columns='review_id,order_id,review_score,review_comment_title,review_comment_message,review_creation_date,review_answer_timestamp';Header='review_id,order_id,review_score,review_comment_title,review_comment_message,review_creation_date,review_answer_timestamp'},
 @{File='product_category_name_translation.csv';Table='stg_category_translation';Columns='product_category_name,product_category_name_english';Header='product_category_name,product_category_name_english'}
)

if(-not (Test-Path -LiteralPath $Psql)){throw "psql not found: $Psql"}
$dataset=(Resolve-Path -LiteralPath $DatasetPath -ErrorAction Stop).Path
foreach($spec in $specs){
 $path=Join-Path $dataset $spec.File
 if(-not (Test-Path -LiteralPath $path)){throw "Missing Olist file: $path"}
 $header=(Get-Content -LiteralPath $path -TotalCount 1).TrimStart([char]0xFEFF).Replace('"','')
 if($header -ne $spec.Header){throw "Unexpected header in $($spec.File): $header"}
}

$connectionArgs=@('-X','-v','ON_ERROR_STOP=1','-h',$DbHost,'-p',$Port,'-U',$User,'-d',$Database)
& $Psql @connectionArgs -f (Join-Path $PSScriptRoot '..\create_tables.sql')
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}

$tables=($specs|ForEach-Object {$_.Table}) -join ','
& $Psql @connectionArgs -c "TRUNCATE $tables RESTART IDENTITY;"
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}

foreach($spec in $specs){
 $filePath=(Join-Path $dataset $spec.File).Replace('\','/')
 $copy="\copy $($spec.Table)($($spec.Columns)) FROM '$filePath' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')"
 & $Psql @connectionArgs -c $copy
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
}

& $Psql @connectionArgs -v "effective_date=$EffectiveDate" -f (Join-Path $PSScriptRoot 'run_full.sql')
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
