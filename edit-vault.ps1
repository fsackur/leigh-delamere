#! /usr/bin/pwsh

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingPlainTextForPassword", "vault-password-file")]
param
(
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

    [string]$Path,

    [string]$Editor
)

$Editor = if ($Editor) {$Editor} elseif ($IsVSCode) {'code'} else {$env:EDITOR}

$Path = $(if ($Path) {$Path} else {${vault-id} -replace '^@'}) | Resolve-Path -ErrorAction Stop

$TmpPath = $Path -replace '(\.\w+$)', '-decrypted$1'
$ShouldWriteDecrypted = $true
$Prompt = "Vault decrypted to '$TmpPath'. Press enter when finished editing."

$Response = ''
if (Test-Path $TmpPath)
{
    while ($Response -inotmatch '^(c|o|a)')
    {
        $Response = Read-Host "File exists at '$TmpPath'. (C)ontinue editing / (O)verwrite / (A)bort?"
    }

    if ($Response -ilike 'a*')
    {
        return
    }

    if ($Response -ilike 'c*')
    {
        $ShouldWriteDecrypted = $false
        $Prompt = "Continuing to edit '$TmpPath'. Press enter when finished editing."
    }
}

Write-Verbose "ansible-vault view $Path --vault-password-file ${vault-password-file}"
$Output = ansible-vault view $Path --vault-password-file ${vault-password-file}
if ($LASTEXITCODE)
{
    throw ($Output -join "`n")
}

if ($ShouldWriteDecrypted)
{
    [IO.File]::WriteAllLines($TmpPath, $Output)  # no BOM
}
$ChecksumBefore = Get-FileHash $TmpPath

try
{
    if ($Editor)
    {
        & $Editor $TmpPath
    }
    else
    {
        Invoke-Item $TmpPath -ErrorAction Continue
    }

    $null = Read-Host $Prompt
}
finally
{
    $ChecksumAfter = Get-FileHash $TmpPath
    if ($ChecksumBefore.Hash -eq $ChecksumAfter.Hash)
    {
        Write-Host "No changes detected. Exiting."
    }
    else
    {
        Write-Verbose "ansible-vault encrypt $TmpPath --vault-password-file ${vault-password-file} --output $Path"
        $Output = ansible-vault encrypt $TmpPath --encrypt-vault-id ${vault-id} --vault-password-file ${vault-password-file} --output $Path
        if ($LASTEXITCODE)
        {
            throw ($Output -join "`n")
        }
    }
    Remove-Item $TmpPath -ErrorAction Stop
}
