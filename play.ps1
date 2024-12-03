#! /usr/bin/pwsh

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingPlainTextForPassword", "vault-password-file")]
param
(
    # outputs a list of matching hosts; does not execute anything else
    [switch]${list-hosts},

    # list all available tags
    [switch]${list-tags},

    # list all tasks that would be executed
    [switch]${list-tasks},

    # only run plays and tasks whose tags do not match these values. This argument may be specified multiple times.
    [ArgumentCompleter({
        param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $wordToComplete = $wordToComplete -replace '^(''|")' -replace '(''|")$'

        $playbook = $($fakeBoundParameters["playbook"])
        if (-not $playbook) {return}
        $inventory = $($fakeBoundParameters["inventory"])
        if (-not $inventory) {$inventory = "$PSScriptRoot/inventory.yml"}

        if (-not $Global:_playbook_tags) {$Global:_playbook_tags = @{}}
        $tags = $Global:_playbook_tags["$playbook"]
        if (-not $tags)
        {
            $completer = "ansible-playbook --list-tags --inventory $inventory $playbook"
            $output = $completer | Invoke-Expression
            $tags = $output |
                % {if ($_ -match 'TAGS: \[(?<tags>.+?)\]') {$matches.tags -split ', '}} |
                Sort-Object -Unique
            $Global:_playbook_tags["$playbook"] = $tags
        }
        $Completions = (@($tags) -like "$wordToComplete*"), (@($tags) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
        $Completions = @($Completions) -ne 'never'
        @($Completions) -replace '.* .*', '''$0'''
    })]
    [string[]]${skip-tags},

    # only run plays and tasks tagged with these values. This argument may be specified multiple times.
    [ArgumentCompleter({
        param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $wordToComplete = $wordToComplete -replace '^(''|")' -replace '(''|")$'

        $playbook = $($fakeBoundParameters["playbook"])
        if (-not $playbook) {return}
        $inventory = $($fakeBoundParameters["inventory"])
        if (-not $inventory) {$inventory = "$PSScriptRoot/inventory.yml"}

        if (-not $Global:_playbook_tags) {$Global:_playbook_tags = @{}}
        $tags = $Global:_playbook_tags["$playbook"]
        if (-not $tags)
        {
            $completer = "ansible-playbook --list-tags --inventory $inventory $playbook"
            $output = $completer | Invoke-Expression
            $tags = $output |
                % {if ($_ -match 'TAGS: \[(?<tags>.+?)\]') {$matches.tags -split ', '}} |
                Sort-Object -Unique
            $Global:_playbook_tags["$playbook"] = $tags
        }
        $Completions = (@($tags) -like "$wordToComplete*"), (@($tags) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
        $Completions = @($Completions) -ne 'always'
        @($Completions) -replace '.* .*', '''$0'''
    })]
    [string[]]${tags},

    [Parameter(Mandatory, Position = 0)]
    [string[]]${playbook},

    # specify inventory host path
    [string[]]${inventory} = "$PSScriptRoot/inventory.yml",

    # ansible-vault decrypt ./vault.yml --vault-password-file ~/.ssh/ansible
    [string]${vault-id} = $(
        $pattern = '^\s*vault_identity\s*=\s*(?<vault_id>\S+)'
        Get-Content $PSScriptRoot/ansible.cfg -ErrorAction Stop |
            Where-Object {$_ -match $pattern} |
            Select-Object -First 1 |
            ForEach-Object {$Matches.vault_id}
    ),

    [string]${vault-password-file} = $(
        $pattern = '^\s*vault_password_file\s*=\s*(?<vault_password_file>\S+)'
        Get-Content $PSScriptRoot/ansible.cfg -ErrorAction Stop |
            Where-Object {$_ -match $pattern} |
            Select-Object -First 1 |
            ForEach-Object {$Matches.vault_password_file}
    ),

    # further limit selected hosts to an additional pattern
    [ArgumentCompleter({
        param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $wordToComplete = $wordToComplete -replace '^(''|")' -replace '(''|")$'

        $playbook = $($fakeBoundParameters["playbook"])
        if (-not $playbook) {return}
        $inventory = $($fakeBoundParameters["inventory"])
        if (-not $inventory) {$inventory = "$PSScriptRoot/inventory.yml"}

        if (-not $Global:_playbook_hosts) {$Global:_playbook_hosts = @{}}
        $hosts = $Global:_playbook_hosts["$playbook"]
        if (-not $hosts)
        {
            $completer = "ansible-playbook --list-hosts --inventory $inventory $playbook"
            $output = $completer | Invoke-Expression
            $hosts = $output.
                Where({$_ -match 'hosts'}, "SkipUntil").
                Where({$_ -notmatch ':'}, "SkipUntil").
                Where({$_ -match ':'}, "Until") -replace '^\s+' -replace '\s+$'
            $hosts = $hosts, "localhost" |
                Write-Output
                Select-Object -Unique
            $Global:_playbook_hosts["$playbook"] = $hosts
        }
        (@($hosts) -like "$wordToComplete*"), (@($hosts) -like "*$wordToComplete*") | Write-Output | Select-Object -Unique
    })]
    [Alias("host")]
    [Alias("filter")]
    [string[]]$limit,

    # connection type to use (default=ssh)
    [switch]${local},

    [string]$user = $env:USER,

    # start the playbook at the task matching this name
    [ArgumentCompleter({
        param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $wordToComplete = $wordToComplete -replace '^(''|")' -replace '(''|")$'

        $playbook = $($fakeBoundParameters["playbook"])
        if (-not $playbook) {return}
        $inventory = $($fakeBoundParameters["inventory"])
        if (-not $inventory) {$inventory = "$PSScriptRoot/inventory.yml"}

        $completer = "ansible-playbook --list-tasks --inventory $inventory $playbook"
        $output = $completer | Invoke-Expression
        $tasks = @($output) -match ' : ' -replace 'TAGS:.*' -replace '.*:' |
            % Trim |
            Sort-Object -Unique

        $Completions = (@($tasks) -like "$wordToComplete*"), (@($tasks) -like "*$wordToComplete*") | Write-Output
        $Completions -replace '.* .*', '''$0'''
    })]
    [string]${start-at-task},

    # one-step-at-a-time: confirm each task before running
    [switch]${step},

    # perform a syntax check on the playbook, but do not execute it
    [switch]${syntax-check},

    # don't make any changes; instead, try to predict some of the changes that may occur
    [alias("dry-run")]
    [switch]${check},

    # when changing (small) files and templates, show the differences in those files; works great with --check
    [switch]${diff},

    [Parameter(ValueFromRemainingArguments)]
    [string[]]${extra-args}
)

# return ${vault-id}

[string[]]$CommonParameters = (
    'Verbose',
    'Debug',
    'ErrorAction',
    'WarningAction',
    'InformationAction',
    'ErrorVariable',
    'WarningVariable',
    'InformationVariable',
    'OutVariable',
    'OutBuffer',
    'PipelineVariable',
    'WhatIf',
    'Confirm'
)
$CommonParameters | ForEach-Object {[void]$PSBoundParameters.Remove($_)}

[void]$PSBoundParameters.Remove("playbook")
[void]$PSBoundParameters.Remove("local")
[void]$PSBoundParameters.Remove("extra-args")
$PSBoundParameters["user"] = $user

$playbook = $playbook | Resolve-Path
$inventory = $inventory | Resolve-Path

if ($local)
{
    $PSBoundParameters["connection"] = "local"
    $PSBoundParameters["limit"] = hostname
}

$exexcargs = '--inventory', "${inventory}"

$exexcargs += $PSBoundParameters.GetEnumerator() |
    ? {$_.Value -isnot [switch]} -PipelineVariable Param |
    % Value |
    % {"--$($Param.Key)", [string]$_} |
    Write-Output

$exexcargs += $PSBoundParameters.GetEnumerator() |
    ? {$_.Value -is [switch] -and $_.Value} |
    % {"--$($_.Key)"}

if (${vault-id} -match '^(?<path>.*?)(@.*|$)' -and (Test-Path $Matches.path))
{
    ${vault-id} = ($Matches.path | Resolve-Path) -replace '^', '@'
# }
# ${vault-id}
# if (${vault-id} -match '^(?<path>.*?)(@.*|$)') # -and (Test-Path $Matches.path))
# {
#     return $Matches
    if (-not (Test-Path ${vault-password-file} -PathType Leaf))
    {
        throw "Ansible vault password not found. Retrieve it from Bitwarden and write it to ${vault-password-file}."
    }

    ${vault-password-file} = Resolve-Path ${vault-password-file}
    $exexcargs += '--extra-vars', ${vault-id}, '--vault-password-file', ${vault-password-file}

    # return $exexcargs
}

$exexcargs += ${extra-args}

$IsReadonly = ${list-hosts} -or ${list-tags} -or ${list-tasks}
if (-not $IsReadonly)
{
    $HostOutput = ansible-playbook --list-hosts $exexcargs $playbook
    $Hosts = $HostOutput.Where({$_ -match '^    hosts \(\d+\):$'}, 'SkipUntil') | Select-Object -Skip 1 | % Trim -Confirm:$false -WhatIf:$false
}

if ($IsReadonly -or $PSCmdlet.ShouldProcess($Hosts, "ansible-playbook $exexcargs $playbook"))
{
    # Write-Verbose "ansible-playbook $exexcargs $playbook"
    ansible-playbook $exexcargs $playbook
}
