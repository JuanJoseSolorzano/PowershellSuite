
function Repair-File {
    param([string]$filePath, [hashtable]$config)
    $insertBlank = $false
    try {
        # Small pause so the compiler finishes writing the file
        Start-Sleep -Milliseconds 300

        $lines = [System.IO.File]::ReadAllLines($filePath)
        if ($filePath -like "*ca_data.c") {
            $insertBlank = $true
        }
        $srcLines = $config.SourceLines
        $tgtLines = $config.TargetLines

        if ($lines.Count -lt ($srcLines | Measure-Object -Maximum).Maximum) {
            Write-Host  "SKIP (too short): $(Split-Path $filePath -Leaf)" -ForegroundColor Red
            return - 1
        }
        if ($filePath -like "*ca_data.h" -and $lines[$config.SourceLines[0] - 1].Trim() -eq "") {
            Write-Host "SKIP (already fixed): $(Split-Path $filePath -Leaf)" -ForegroundColor Yellow
            return 0
        }
        if ($filePath -like "*ca_data.c" -and $lines[$config.SourceLines[0] - 1].Trim() -eq "") {
            Write-Host "SKIP (already fixed): $(Split-Path $filePath -Leaf)" -ForegroundColor Yellow
            return 0
        }
        # Extract the lines to move (convert 1-based to 0-based)
        $extracted = $srcLines | ForEach-Object { $lines[$_ - 1] }

        # Build array without those lines
        $srcSet = $srcLines | ForEach-Object { $_ - 1 }
        $reduced = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($i -eq 11 -and $insertBlank) {
                $reduced.Add("") # insert blank line at start if needed
            }
        
            if ($i -notin $srcSet) { $reduced.Add($lines[$i]) }
        }

        # Insert extracted lines at target positions (1-based)
        for ($i = 0; $i -lt $extracted.Count; $i++) {
            $idx = $tgtLines[$i] - 1   # convert to 0-based insert index
        
            if ($idx -ge $reduced.Count) { 
                $reduced.Add($extracted[$i])
            }
            else { 
                if ($insertBlank -and $idx -ge 11) {
                    $idx-- # shift down target if we inserted a blank line at 11
                }
                $reduced.Insert($idx, $extracted[$i]) 
            }
        }

        # Write back and record our write time
        $ourWrite[$filePath] = [DateTime]::Now
        [System.IO.File]::WriteAllLines($filePath, $reduced.ToArray())
        $lastSeen[$filePath] = (Get-Item $filePath).LastWriteTime
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] FIXED: $(Split-Path $filePath -Leaf)" -ForegroundColor Green
        return 1
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR on $(Split-Path $filePath -Leaf): $_" -ForegroundColor Red
        return - 1
    }
}

function Get-FilesPath{
    param([string]$baseDir)
    $ca_data_c_path = (Get-ChildItem -Path $baseDir -Recurse -Filter "ca_data.c" | Where-Object {$_.FullName -like "*\bld\*"})
    $ca_data_h_path = (Get-ChildItem -Path $baseDir -Recurse -Filter "ca_data.h" | Where-Object {$_.FullName -like "*\bld\*"})
    $files_found = $true

    if(-not $ca_data_c_path) {
        $files_found = $false
    }
    if(-not $ca_data_h_path) {
        $files_found = $false
    }else{
        Write-Debug "Found ca_data.c at: $($ca_data_c_path.FullName)"
        Write-Debug "Found ca_data.h at: $($ca_data_h_path.FullName)"
    }
    if(-not $files_found) {
        return @{}
    }
    $watchedFiles = @{
        "$ca_data_c_path" = @{
            SourceLines = @(3, 4)    # 1-based lines to move
            TargetLines = @(12, 13)  # 1-based final positions in output
        }
        "$ca_data_h_path"                            = @{
            SourceLines = @(6, 7)    # 1-based lines to move
            TargetLines = @(21, 22)  # 1-based final positions in output
        }
    }
    return $watchedFiles
}

function Watch-CaData {
    param([string]$baseDir)
    if(-not (Test-Path $baseDir)) {
        $baseDir = Get-Location
    }else{
        $baseDir = Convert-Path $baseDir 
    }

    $watchedFiles = Get-FilesPath -baseDir $baseDir
    $lastSeen = @{}# Tracks the LastWriteTime we last saw for each file (to detect external changes)
    $ourWrite = @{}# Tracks when WE last wrote each file (to skip our own write events)

    foreach ($f in $watchedFiles.Keys) {
        $lastSeen[$f] = [DateTime]::MinValue
        $ourWrite[$f] = [DateTime]::MinValue
    }

    Write-Host "====================================================="              -ForegroundColor Blue
    Write-Host " TD5 - Watcher started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"   -ForegroundColor Blue
    Write-Host " Watching at: $baseDir"                                             -ForegroundColor Blue
    Write-Host " [?] Press Ctrl+C to stop."                                         -ForegroundColor Blue
    Write-Host "====================================================="              -ForegroundColor Blue

    $frames = @('|', '/', '-', '\')
    $_frames = @('⣾','⣽','⣻','⢿','⡿','⣟','⣯','⣷')
    #$frames = @('▏','▎','▍','▌','▋','▊','▉','█','▉','▊','▋','▌','▍','▎')
    $startTime = [datetime]::Now
    $totalFixes = 0
    $totalFails = 0
    $totalSkips = 0
    try {
        [Console]::Write("`e[?25l") #hide cursor
        while ($true) {
            $elapsed = [datetime]::Now - $startTime
            $elapsedShow = "{0:hh\:mm\:ss}" -f $elapsed
            $frame = ($frame + 1) % $frames.Count
            Write-Host "`r $($frames[$frame]) Watching ... < $elapsedShow >  " -NoNewline -ForegroundColor Blue
            if($watchedFiles.Count -eq 0) {
                $watchedFiles = Get-FilesPath -baseDir $baseDir
                continue
            }
            foreach ($filePath in $watchedFiles.Keys) {
                if (-not $ourWrite.ContainsKey($filePath))  { $ourWrite[$filePath]  = [DateTime]::MinValue }
                if (-not $lastSeen.ContainsKey($filePath)) { $lastSeen[$filePath] = [DateTime]::MinValue }
                if (-not (Test-Path $filePath)) { 
                    $watchedFiles = Get-FilesPath -baseDir $baseDir
                    continue
                }

                $current = (Get-Item $filePath).LastWriteTime

                # Skip if unchanged
                if ($current -le $lastSeen[$filePath]) { continue }

                # Skip if this change is ours (within 3 seconds of our own write)
                $secsSinceOurWrite = ([DateTime]::Now - $ourWrite[$filePath]).TotalSeconds
                if ($secsSinceOurWrite -lt 3) {
                    $lastSeen[$filePath] = $current
                    continue
                }
                write-Host "`r[!] Detected change | Processing..." -ForegroundColor Cyan
                $lastSeen[$filePath] = $current
                Start-Sleep -Seconds 2 # wait a bit more to ensure file is fully written
                $status = Repair-File -filePath $filePath -config $watchedFiles[$filePath]
                switch ($status) {
                    1 { $totalFixes++ }
                    0 { $totalSkips++ }
                   -1 { $totalFails++ }
                }
            }
            Start-Sleep -Milliseconds 500
        }
    }
    finally {
        [Console]::Write("`e[?25h") #show cursor
        Write-Host " "
        Write-Host "------------------------------------------------------"              -ForegroundColor Blue
        Write-Host ">> Watcher stopped."                                                 -ForegroundColor Yellow
        Write-Host "   Total elapsed time: $elapsedShow"                                 -ForegroundColor Yellow
        Write-Host "   Total fixes applied: $totalFixes"                                 -ForegroundColor Yellow
        Write-Host "   Total skips: $totalSkips"                                         -ForegroundColor Yellow
        Write-Host "   Total fails: $totalFails"                                         -ForegroundColor Yellow
        Write-Host "   Final file states:"                                               -ForegroundColor Yellow
        foreach ($filePath in $watchedFiles.Keys) {
            $finalTime = (Get-Item $filePath).LastWriteTime
            Write-Host "     - $(Split-Path $filePath -Leaf): LastWriteTime = $finalTime" -ForegroundColor Cyan
        }
        Write-Host "====================================================="               -ForegroundColor Blue
    }
}