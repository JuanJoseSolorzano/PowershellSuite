$credentials = "$env:JIRA_USERNAME`:$env:JIRA_PASSWORD"
$credentialsBytes = [System.Text.Encoding]::ASCII.GetBytes($credentials)
$auth = [Convert]::ToBase64String($credentialsBytes)

$headers = @{
    Accept        = "application/json"
    Authorization = "Basic $auth"
}

function Move-JiraTicket {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TicketID,
        [switch]$InProgress,
        [switch]$Resolved,
        [switch]$OnHold,
        [switch]$Planned,
        [switch]$Backlog,
        [switch]$SprintBacklog
    )

    $transitionId = switch ($true) {
        $InProgress    { "31"; break }
        $Resolved      { "51"; break }
        $OnHold        { "61"; break }
        $Planned       { "81"; break }
        $Backlog       { "91"; break }
        $SprintBacklog { "101"; break }
        default {
            Write-Host "Please specify a valid status to move the ticket to." -ForegroundColor Red
            Write-Host "Usage: Move-JiraTicket -TicketID <ID> -InProgress| -Resolved| -OnHold| -Planned| -Backlog| -SprintBacklog" -ForegroundColor Yellow
            return
        }
    }

    if(-not $TicketID.ToUpper().Contains("SETV-")) {
        $ticketKey = "SETV-$TicketID".ToUpper()
    }
    else {
        $ticketKey = $TicketID.ToUpper()
    }
    
    $url = "https://$env:JIRA_SERVER/rest/api/2/issue/$ticketKey/transitions"

    $body = @{
        transition = @{
            id = $transitionId
        }
    } | ConvertTo-Json -Depth 10

    Write-Host "[*] Moving ticket $ticketKey to transition ID $transitionId..." -ForegroundColor Yellow

    try {
        $null = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -ContentType "application/json" -Body $body
        Write-Host "Ticket $ticketKey moved successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to move ticket $ticketKey." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}


function Get-JiraBoardSprints {
    [CmdletBinding()]
    param(
        [int]$BoardId = 8857,
        [switch]$Active,
        [switch]$future,
        [switch]$closed,
        [switch]$all
    )

    $State = switch ($true) {
        $Active { "active"; break }
        $future { "future"; break }
        $closed { "closed"; break }
        $all    { "all"; break }
        default {
            Write-Host "Please specify a valid state." -ForegroundColor Red
            Write-Host "Usage: Get-JiraBoardSprints -BoardId <ID> -Active | -future | -closed | -all" -ForegroundColor Yellow
            return
        }
    }

    $url = "https://$env:JIRA_SERVER/rest/agile/1.0/board/$BoardId/sprint?state=$State"

    try {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers

        Write-Host "Total sprints found: $($response.total)" -ForegroundColor Green
        Write-Host ("{0,-8} | {1,-35} | {2,-10} | {3,-20} | {4,-20}" -f "ID", "Name", "State", "Start Date", "End Date")
        Write-Host ("-" * 110)

        foreach ($sprint in $response.values) {
            $start = if ($sprint.startDate) { $sprint.startDate } else { "N/A" }
            $end   = if ($sprint.endDate) { $sprint.endDate } else { "N/A" }

            Write-Host ("{0,-8} | {1,-35} | {2,-10} | {3,-20} | {4,-20}" -f $sprint.id, $sprint.name, $sprint.state, $start, $end)
        }
    }
    catch {
        Write-Host "Failed to retrieve sprints." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}