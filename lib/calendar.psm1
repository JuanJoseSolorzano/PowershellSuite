<#
.SYNOPSIS
    A small calendar CLI for PowerShell: month view, events and to-do management.
.DESCRIPTION
    Provides a khal-like experience from the terminal. Display any month (by name
    or number), create and list events, and manage a simple to-do list. Events and
    to-dos are persisted to lib/utils/calendar_data.json.
.NOTES
    File Name : calendar.psm1
    Author    : Solorzano, Juan Jose
#>

# region ------------------------------------------------------------ internals

# Path to the JSON file that stores events and to-dos.
function Get-CalendarDataPath {
    $dir = Join-Path $PSScriptRoot 'utils'
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return Join-Path $dir 'calendar_data.json'
}

# Load the calendar store, always returning an object with events/todos arrays.
function Get-CalendarData {
    $path = Get-CalendarDataPath
    if (-not (Test-Path $path)) {
        return [pscustomobject]@{ events = @(); todos = @() }
    }
    try {
        $data = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Host "[!] calendar_data.json is corrupted, starting fresh." -ForegroundColor Red
        return [pscustomobject]@{ events = @(); todos = @() }
    }
    if ($null -eq $data) { $data = [pscustomobject]@{} }
    if (-not ($data.PSObject.Properties.Name -contains 'events')) {
        $data | Add-Member -NotePropertyName events -NotePropertyValue @() -Force
    }
    if (-not ($data.PSObject.Properties.Name -contains 'todos')) {
        $data | Add-Member -NotePropertyName todos -NotePropertyValue @() -Force
    }
    return $data
}

# Persist the calendar store to disk.
function Save-CalendarData {
    param([Parameter(Mandatory)]$Data)
    $Data.events = @($Data.events)
    $Data.todos = @($Data.todos)
    $Data | ConvertTo-Json -Depth 10 | Set-Content -Path (Get-CalendarDataPath) -Encoding UTF8
}

# Short, human-friendly identifier used to reference events/to-dos on the CLI.
function New-CalendarId {
    return [guid]::NewGuid().ToString('N').Substring(0, 6)
}

<#
.SYNOPSIS
    Convert a month given as a word, abbreviation or number into 1-12.
.EXAMPLE
    ConvertTo-MonthNumber August   # 8
    ConvertTo-MonthNumber Aug      # 8
    ConvertTo-MonthNumber 8        # 8
#>
function ConvertTo-MonthNumber {
    param([Parameter(Mandatory)]$Month)

    if ($Month -is [int] -or "$Month".Trim() -match '^\d+$') {
        $n = [int]$Month
        if ($n -ge 1 -and $n -le 12) { return $n }
        throw "Month number '$Month' is out of range (1-12)."
    }

    $name = "$Month".Trim()
    $ci = [System.Globalization.CultureInfo]::InvariantCulture
    $names = $ci.DateTimeFormat.MonthNames
    $abbr = $ci.DateTimeFormat.AbbreviatedMonthNames
    for ($i = 0; $i -lt 12; $i++) {
        if ($names[$i] -ieq $name -or $abbr[$i] -ieq $name) { return $i + 1 }
    }
    for ($i = 0; $i -lt 12; $i++) {
        if ($names[$i] -and $names[$i].StartsWith($name, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            return $i + 1
        }
    }
    throw "Unknown month '$Month'. Use a name (August), abbreviation (Aug) or number (8)."
}

<#
.SYNOPSIS
    Convert a friendly date string into a DateTime.
.DESCRIPTION
    Accepts 'today', 'tomorrow', 'yesterday', ISO 'yyyy-MM-dd', or any date that
    the current culture can parse.
#>
function ConvertTo-CalendarDate {
    param([Parameter(Mandatory)][string]$Date)

    $d = $Date.Trim()
    switch -Regex ($d.ToLower()) {
        '^today$' { return (Get-Date).Date }
        '^tomorrow$' { return (Get-Date).Date.AddDays(1) }
        '^yesterday$' { return (Get-Date).Date.AddDays(-1) }
    }

    $iso = [datetime]::MinValue
    $ci = [System.Globalization.CultureInfo]::InvariantCulture
    if ([datetime]::TryParseExact($d, 'yyyy-MM-dd', $ci, [System.Globalization.DateTimeStyles]::None, [ref]$iso)) {
        return $iso.Date
    }

    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($d, [ref]$parsed)) {
        return $parsed.Date
    }
    throw "Unable to understand date '$Date'. Try 'today', 'tomorrow' or 'yyyy-MM-dd'."
}

# Parse a stored 'yyyy-MM-dd' date safely, culture independent.
function ConvertFrom-StoredDate {
    param([Parameter(Mandatory)][string]$Date)
    return [datetime]::ParseExact($Date, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
}
# endregion

# region ------------------------------------------------------------ month view

<#
.SYNOPSIS
    Display a month calendar. The month may be a word or a number.
.PARAMETER Month
    Month to display, as a name (August), abbreviation (Aug) or number (8).
    Defaults to the current month.
.PARAMETER Year
    Year to display. Defaults to the current year.
.PARAMETER MondayFirst
    Start the week on Monday instead of Sunday.
.EXAMPLE
    Cal August
.EXAMPLE
    Cal 8 2026 -MondayFirst
#>
function Cal {
    param(
        [Parameter(Position = 0)]
        [string]$Month = (Get-Date).Month,
        [Parameter(Position = 1)]
        [int]$Year = (Get-Date).Year,
        [switch]$MondayFirst
    )

    $monthNum = ConvertTo-MonthNumber $Month
    $today = Get-Date
    $firstDay = Get-Date -Year $Year -Month $monthNum -Day 1
    $daysInMonth = [DateTime]::DaysInMonth($Year, $monthNum)

    # Collect the days in this month that hold events or pending to-dos.
    $data = Get-CalendarData
    $eventDays = @{}
    foreach ($e in @($data.events)) {
        $ed = ConvertFrom-StoredDate $e.Date
        if ($ed.Year -eq $Year -and $ed.Month -eq $monthNum) { $eventDays[$ed.Day] = $true }
    }
    $todoDays = @{}
    foreach ($t in @($data.todos)) {
        if ($t.Due -and -not $t.Done) {
            $td = ConvertFrom-StoredDate $t.Due
            if ($td.Year -eq $Year -and $td.Month -eq $monthNum) { $todoDays[$td.Day] = $true }
        }
    }

    if ($MondayFirst) {
        $headers = @("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")
        $startColumn = (([int]$firstDay.DayOfWeek + 6) % 7)
    }
    else {
        $headers = @("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
        $startColumn = [int]$firstDay.DayOfWeek
    }

    $title = $firstDay.ToString("MMMM yyyy")
    $width = 21
    $padding = [Math]::Max(0, [Math]::Floor(($width - $title.Length) / 2))

    Write-Host ""
    Write-Host (" " * $padding + $title) -ForegroundColor Cyan
    Write-Host ($headers -join " ") -ForegroundColor DarkGray

    $currentColumn = 0

    for ($i = 0; $i -lt $startColumn; $i++) {
        Write-Host "   " -NoNewline
        $currentColumn++
    }

    for ($day = 1; $day -le $daysInMonth; $day++) {
        $isToday =
        $day -eq $today.Day -and
        $monthNum -eq $today.Month -and
        $Year -eq $today.Year

        $hasEvent = $eventDays.ContainsKey($day)
        $hasTodo = $todoDays.ContainsKey($day)
        $text = "{0,2} " -f $day

        if ($isToday) {
            Write-Host $text -NoNewline -ForegroundColor Black -BackgroundColor Green
        }
        elseif ($hasEvent -and $hasTodo) {
            Write-Host $text -NoNewline -ForegroundColor Magenta
        }
        elseif ($hasEvent) {
            Write-Host $text -NoNewline -ForegroundColor Cyan
        }
        elseif ($hasTodo) {
            Write-Host $text -NoNewline -ForegroundColor Yellow
        }
        else {
            Write-Host $text -NoNewline
        }

        $currentColumn++

        if ($currentColumn -eq 7) {
            Write-Host ""
            $currentColumn = 0
        }
    }

    if ($currentColumn -ne 0) {
        Write-Host ""
    }

    Write-Host ""
    Write-Host "today " -NoNewline -ForegroundColor Black -BackgroundColor Green
    Write-Host " event " -NoNewline -ForegroundColor Cyan
    Write-Host " to-do " -NoNewline -ForegroundColor Yellow
    Write-Host " both" -ForegroundColor Magenta
    Write-Host ""
}
# endregion

# region ------------------------------------------------------------ events

<#
.SYNOPSIS
    Create a calendar event.
.PARAMETER Title
    Short description of the event.
.PARAMETER Date
    Event date: 'today', 'tomorrow', 'yyyy-MM-dd' or any parseable date.
.PARAMETER Time
    Optional start time, e.g. '14:00'.
.PARAMETER EndTime
    Optional end time, e.g. '15:30'.
.PARAMETER Location
    Optional location.
.PARAMETER Description
    Optional longer note.
.EXAMPLE
    Add-CalendarEvent "Team sync" tomorrow 14:00 15:00 -Location "Room 1"
#>
function Add-CalendarEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Title,
        [Parameter(Position = 1)][string]$Date = 'today',
        [Parameter(Position = 2)][string]$Time,
        [Parameter(Position = 3)][string]$EndTime,
        [string]$Location,
        [string]$Description
    )

    $d = ConvertTo-CalendarDate $Date
    $data = Get-CalendarData
    $event = [pscustomobject]@{
        Id          = New-CalendarId
        Title       = $Title
        Date        = $d.ToString('yyyy-MM-dd')
        StartTime   = $Time
        EndTime     = $EndTime
        Location    = $Location
        Description = $Description
        Created     = (Get-Date).ToString('s')
    }
    $data.events = @($data.events) + $event
    Save-CalendarData $data

    Write-Host "[+] Event added " -NoNewline -ForegroundColor Green
    Write-Host "($($event.Id)) " -NoNewline -ForegroundColor DarkGray
    Write-Host $Title -NoNewline
    Write-Host "  $($d.ToString('ddd yyyy-MM-dd'))" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    List calendar events.
.DESCRIPTION
    By default lists upcoming events (today onward). Use -All for every event,
    -Month to filter a month, or -Date for a single day.
#>
function Show-CalendarEvents {
    [CmdletBinding()]
    param(
        [string]$Month,
        [int]$Year = (Get-Date).Year,
        [string]$Date,
        [switch]$All
    )

    $events = @((Get-CalendarData).events) | Sort-Object Date, StartTime
    if (-not $events -or $events.Count -eq 0) {
        Write-Host "No events." -ForegroundColor DarkGray
        return
    }

    if ($Date) {
        $target = (ConvertTo-CalendarDate $Date).ToString('yyyy-MM-dd')
        $events = @($events | Where-Object { $_.Date -eq $target })
    }
    elseif ($Month) {
        $monthNum = ConvertTo-MonthNumber $Month
        $events = @($events | Where-Object {
                $ed = ConvertFrom-StoredDate $_.Date
                $ed.Year -eq $Year -and $ed.Month -eq $monthNum
            })
    }
    elseif (-not $All) {
        $todayStr = (Get-Date).ToString('yyyy-MM-dd')
        $events = @($events | Where-Object { $_.Date -ge $todayStr })
    }

    if (-not $events -or $events.Count -eq 0) {
        Write-Host "No events for the requested range." -ForegroundColor DarkGray
        return
    }

    Write-Host ""
    $lastDate = $null
    foreach ($e in $events) {
        if ($e.Date -ne $lastDate) {
            $d = ConvertFrom-StoredDate $e.Date
            Write-Host ("{0}" -f $d.ToString('dddd, dd MMMM yyyy')) -ForegroundColor Cyan
            $lastDate = $e.Date
        }
        $when = if ($e.StartTime) {
            if ($e.EndTime) { "{0,-12}" -f "$($e.StartTime)-$($e.EndTime)" } else { "{0,-12}" -f $e.StartTime }
        }
        else { "{0,-12}" -f "all-day" }

        Write-Host "  $when" -NoNewline -ForegroundColor Yellow
        Write-Host $e.Title -NoNewline
        if ($e.Location) { Write-Host " @ $($e.Location)" -NoNewline -ForegroundColor DarkGray }
        Write-Host "  ($($e.Id))" -ForegroundColor DarkGray
    }
    Write-Host ""
}

<#
.SYNOPSIS
    Remove a calendar event by its id.
#>
function Remove-CalendarEvent {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Id)

    $data = Get-CalendarData
    $match = @($data.events) | Where-Object { $_.Id -eq $Id }
    if (-not $match) {
        Write-Host "[!] No event with id '$Id'." -ForegroundColor Red
        return
    }
    $data.events = @(@($data.events) | Where-Object { $_.Id -ne $Id })
    Save-CalendarData $data
    Write-Host "[-] Removed event ($Id) $($match.Title)" -ForegroundColor Yellow
}
# endregion

# region ------------------------------------------------------------ to-dos

<#
.SYNOPSIS
    Add a to-do item.
.PARAMETER Title
    What needs to be done.
.PARAMETER Due
    Optional due date: 'today', 'tomorrow', 'yyyy-MM-dd' or any parseable date.
.PARAMETER Priority
    Low, Medium (default) or High.
.EXAMPLE
    Add-CalendarTodo "Finish report" tomorrow -Priority High
#>
function Add-CalendarTodo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Title,
        [Parameter(Position = 1)][string]$Due,
        [ValidateSet('Low', 'Medium', 'High')][string]$Priority = 'Medium'
    )

    $dueStr = $null
    if ($Due) { $dueStr = (ConvertTo-CalendarDate $Due).ToString('yyyy-MM-dd') }

    $data = Get-CalendarData
    $todo = [pscustomobject]@{
        Id        = New-CalendarId
        Title     = $Title
        Due       = $dueStr
        Priority  = $Priority
        Done      = $false
        Created   = (Get-Date).ToString('s')
        Completed = $null
    }
    $data.todos = @($data.todos) + $todo
    Save-CalendarData $data

    Write-Host "[+] To-do added " -NoNewline -ForegroundColor Green
    Write-Host "($($todo.Id)) " -NoNewline -ForegroundColor DarkGray
    Write-Host $Title -NoNewline
    if ($dueStr) { Write-Host "  due $dueStr" -NoNewline -ForegroundColor Yellow }
    Write-Host ""
}

<#
.SYNOPSIS
    List to-do items.
.DESCRIPTION
    By default lists pending items sorted by priority then due date. Use -All to
    include completed items, or -Done to list only completed items.
#>
function Show-CalendarTodos {
    [CmdletBinding()]
    param(
        [switch]$All,
        [switch]$Done
    )

    $todos = @((Get-CalendarData).todos)
    if (-not $todos -or $todos.Count -eq 0) {
        Write-Host "No to-dos." -ForegroundColor DarkGray
        return
    }

    if ($Done) { $todos = @($todos | Where-Object { $_.Done }) }
    elseif (-not $All) { $todos = @($todos | Where-Object { -not $_.Done }) }

    if (-not $todos -or $todos.Count -eq 0) {
        Write-Host "Nothing to show." -ForegroundColor DarkGray
        return
    }

    $rank = @{ High = 0; Medium = 1; Low = 2 }
    $todos = @($todos | Sort-Object @{ Expression = { $rank[$_.Priority] } }, @{ Expression = { if ($_.Due) { $_.Due } else { '9999' } } })

    Write-Host ""
    foreach ($t in $todos) {
        $box = if ($t.Done) { "[x]" } else { "[ ]" }
        $pColor = switch ($t.Priority) {
            'High' { 'Red' }
            'Medium' { 'Yellow' }
            default { 'DarkGray' }
        }
        Write-Host "$box " -NoNewline -ForegroundColor Green
        Write-Host ("{0,-9}" -f "($($t.Priority))") -NoNewline -ForegroundColor $pColor
        Write-Host "$($t.Id)  " -NoNewline -ForegroundColor DarkGray
        if ($t.Done) {
            Write-Host $t.Title -NoNewline -ForegroundColor DarkGray
        }
        else {
            Write-Host $t.Title -NoNewline
        }
        if ($t.Due) { Write-Host "  due $($t.Due)" -NoNewline -ForegroundColor Cyan }
        Write-Host ""
    }
    Write-Host ""
}

<#
.SYNOPSIS
    Mark a to-do item as completed by its id.
#>
function Complete-CalendarTodo {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Id)

    $data = Get-CalendarData
    $match = @($data.todos) | Where-Object { $_.Id -eq $Id }
    if (-not $match) {
        Write-Host "[!] No to-do with id '$Id'." -ForegroundColor Red
        return
    }
    $match.Done = $true
    $match.Completed = (Get-Date).ToString('s')
    Save-CalendarData $data
    Write-Host "[x] Completed ($Id) $($match.Title)" -ForegroundColor Green
}

<#
.SYNOPSIS
    Remove a to-do item by its id.
#>
function Remove-CalendarTodo {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Id)

    $data = Get-CalendarData
    $match = @($data.todos) | Where-Object { $_.Id -eq $Id }
    if (-not $match) {
        Write-Host "[!] No to-do with id '$Id'." -ForegroundColor Red
        return
    }
    $data.todos = @(@($data.todos) | Where-Object { $_.Id -ne $Id })
    Save-CalendarData $data
    Write-Host "[-] Removed to-do ($Id) $($match.Title)" -ForegroundColor Yellow
}
# endregion

# region ------------------------------------------------------------ agenda

<#
.SYNOPSIS
    Overview screen: current month, upcoming events and pending to-dos.
.PARAMETER Month
    Optional month (word or number) to render instead of the current one.
#>
function Show-Agenda {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Month = (Get-Date).Month,
        [int]$Year = (Get-Date).Year,
        [switch]$MondayFirst
    )

    Cal -Month $Month -Year $Year -MondayFirst:$MondayFirst
    Write-Host "Upcoming events" -ForegroundColor Green
    Show-CalendarEvents
    Write-Host "Pending to-dos" -ForegroundColor Green
    Show-CalendarTodos
}
# endregion

# region ------------------------------------------------------------ aliases
# Note: 'Cal' is already short and case-insensitive; no 'cal' alias is created
# because an alias with the same name would shadow the function.
Set-Alias -Name agenda -Value Show-Agenda
Set-Alias -Name event-add -Value Add-CalendarEvent
Set-Alias -Name events -Value Show-CalendarEvents
Set-Alias -Name event-del -Value Remove-CalendarEvent
Set-Alias -Name todo-add -Value Add-CalendarTodo
Set-Alias -Name todos -Value Show-CalendarTodos
Set-Alias -Name todo-done -Value Complete-CalendarTodo
Set-Alias -Name todo-del -Value Remove-CalendarTodo
# endregion
