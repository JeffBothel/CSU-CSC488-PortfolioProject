$csvFiles = Get-ChildItem -Path ".\ml-32m" -Filter "*.csv" -Recurse
$totalFiles = $csvFiles.Count
$currentFile = 0

Write-Verbose "Found $totalFiles CSV files in the directory."
$csvFiles | ForEach-Object {
    $currentFile++
    $percentComplete = if ($totalFiles -gt 0) { [int](($currentFile / $totalFiles) * 100) } else { 100 }
    Write-Progress -Activity "Converting CSV files to JSON" -Status "Processing file $currentFile of $($totalFiles): $($_.Name)" -PercentComplete $percentComplete

    Write-Verbose "Processing file: $($_.FullName)"
    $jsonFilePath = [System.IO.Path]::ChangeExtension($_.FullName, ".json")

    try {
        $csvFileStream = [System.IO.File]::OpenRead($_.FullName);
        $csvReader = New-Object System.IO.StreamReader($csvFileStream);
    } catch {
        Write-Error "Failed to process file: $($_.FullName). Error: $_"
    }

    try {
        $headers = $csvReader.ReadLine()
        if (-not [string]::IsNullOrWhiteSpace($headers)) {
            Set-Content -Path $jsonFilePath -Value "["
            $isFirstItem = $true

            $remainingLines = @()
            while (($line = $csvReader.ReadLine()) -ne $null) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    $remainingLines += $line
                }
            }

            $totalLines = $remainingLines.Count
            $currentLine = 0

            foreach ($line in $remainingLines) {
                $currentLine++
                $linePercentComplete = if ($totalLines -gt 0) { [int](($currentLine / $totalLines) * 100) } else { 100 }
                Write-Progress -Id 1 -ParentId 0 -Activity "Converting rows to JSON" -Status "Processing row $currentLine of $totalLines in $($_.Name)" -PercentComplete $linePercentComplete

                $jsonItem = ($headers + [Environment]::NewLine + $line | ConvertFrom-Csv | ConvertTo-Json -Depth 10 -Compress)

                if ($isFirstItem) {
                    Add-Content -Path $jsonFilePath -Value $jsonItem
                    $isFirstItem = $false
                } else {
                    Add-Content -Path $jsonFilePath -Value ("," + $jsonItem)
                }
            }

            Write-Progress -Id 1 -Activity "Converting rows to JSON" -Completed

            Add-Content -Path $jsonFilePath -Value "]"
        }
    } catch {
        Write-Error "Failed to convert file: $($_.FullName) to JSON. Error: $_"
    } finally {
        $csvReader.Close()
        $csvFileStream.Close()
    }
}

Write-Progress -Activity "Converting CSV files to JSON" -Completed