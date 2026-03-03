param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScript = Join-Path $scriptDir "ptak-ca.sh"

if (-not (Test-Path -LiteralPath $bashScript)) {
  throw "Missing $bashScript"
}

$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash) {
  throw "bash is required to run ptak-ca.sh"
}

& $bash.Source $bashScript @Arguments
exit $LASTEXITCODE
