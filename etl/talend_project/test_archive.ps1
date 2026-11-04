param([string]$ArchivePath = (Join-Path $PSScriptRoot 'PROJET_BI_SATISFACTION.zip'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
if(-not (Test-Path -LiteralPath $ArchivePath)){ throw "Talend archive not found: $ArchivePath" }
$zip=[IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ArchivePath))
try {
 $processEntries=@($zip.Entries | Where-Object { $_.FullName -match '[\\/]process[\\/].+\.item$' })
 $connectionEntries=@($zip.Entries | Where-Object { $_.FullName -match '[\\/]metadata[\\/]connections[\\/].+\.item$' })
 $generatedEntries=@($zip.Entries | Where-Object { $_.FullName -match '[\\/](poms|temp)[\\/]' })
 if($processEntries.Count -ne 11){ throw "Expected 11 Talend process files, got $($processEntries.Count)" }
 if($generatedEntries.Count -ne 0){ throw 'Generated Talend poms/temp content must not be committed in the archive' }
 $allText=New-Object Text.StringBuilder
 foreach($entry in @($processEntries)+@($connectionEntries)){
  $reader=New-Object IO.StreamReader($entry.Open())
  try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
  $doc=[xml]::new();$doc.LoadXml($text)
  [void]$allText.AppendLine($text)
 }
 $text=$allText.ToString()
 if($text -match 'tDBRow_7'){throw 'Duplicate seller component tDBRow_7 is still present'}
 if($text -match 'C:/Users/ORIGINAL|C:/bi_olist'){throw 'A local absolute path is still present'}
 if($text -match 'enc:system\.encryption'){throw 'An encrypted embedded credential is still present'}
 if(([regex]::Matches($text,'refresh_warehouse')).Count -ne 1){throw 'Expected exactly one refresh_warehouse call'}
 if(([regex]::Matches($text,'load_d_client')).Count -ne 1){throw 'Expected exactly one load_d_client SCD2 call'}
 if(-not ($zip.Entries | Where-Object { $_.FullName -match 'PROJET_BI_SATISFACTION[\\/]context\.example\.properties$' })){
  throw 'context.example.properties is missing from archive'
 }
 Write-Output 'Talend archive tests passed'
} finally { $zip.Dispose() }
