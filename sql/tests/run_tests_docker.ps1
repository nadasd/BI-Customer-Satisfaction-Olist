param([string]$Image='postgres:17')
$ErrorActionPreference='Stop'
$container="olist-bi-tests-$PID"
$sqlRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$started=$false
try {
 $id=& docker run --rm -d --name $container -e POSTGRES_PASSWORD=test_only_password $Image
 if($LASTEXITCODE -ne 0){throw 'Unable to start PostgreSQL test container'}
 $started=$true
 $ready=$false
 for($i=0;$i -lt 30;$i++){
  & docker exec $container pg_isready -U postgres *> $null
  if($LASTEXITCODE -eq 0){$ready=$true;break}
  Start-Sleep -Seconds 1
 }
 if(-not $ready){throw 'PostgreSQL test container did not become ready'}
 & docker exec $container mkdir -p /tmp/sql
 if($LASTEXITCODE -ne 0){throw 'Unable to create test directory in container'}
 & docker cp (Join-Path $sqlRoot '.') "${container}:/tmp/sql"
 if($LASTEXITCODE -ne 0){throw 'Unable to copy SQL tests into container'}
 & docker exec -w /tmp/sql/tests $container psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres -f run_all.sql
 if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
} finally {
 if($started){& docker stop $container *> $null}
}