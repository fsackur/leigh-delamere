#! /usr/bin/pwsh

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
[Diagnostics.CodeAnalysis.SuppressMessage("PSAvoidUsingPlainTextForPassword", "vault-password-file")]
param
(
    [string]${vault-id} = "@$PSScriptRoot/vault.yml",

    [string]${vault-password-file} = "$PSScriptRoot/vault-passwd",

    [string]$Path,

    [string]$Editor
)

$Editor = if ($Editor) {$Editor} elseif ($IsVSCode) {'code'} else {$env:EDITOR}

$Path = $(if ($Path) {$Path} else {${vault-id} -replace '^@'}) | Resolve-Path -ErrorAction Stop

$TmpPath = $Path -replace '(\.\w+$)', '-decrypted$1'

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

    if ($Response -ilike 'o*')
    {

    }
}

$Output = ansible-vault view $Path --vault-password-file ${vault-password-file}
if ($LASTEXITCODE)
{
    throw ($Output -join "`n")
}
[IO.File]::WriteAllLines($TmpPath, $Output)  # no BOM
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

    $null = Read-Host "Vault decrypted to '$TmpPath'. Press enter when finished editing."
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
        $Output = ansible-vault encrypt $TmpPath --vault-password-file ${vault-password-file} --output $Path
        if ($LASTEXITCODE)
        {
            throw ($Output -join "`n")
        }
    }
    Remove-Item $TmpPath -ErrorAction Stop
}
