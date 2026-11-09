param([string]$Psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe',[string]$Database='postgres',[string]$User='postgres')
$ErrorActionPreference='Stop'
if(-not (Test-Path -LiteralPath $Psql)){ throw "psql not found: $Psql" }
& $Psql -X -v ON_ERROR_STOP=1 -U $User -d $Database -f (Join-Path $PSScriptRoot 'run_all.sql')
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
