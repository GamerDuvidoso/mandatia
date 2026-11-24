Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..'
$contractPath = Join-Path $root 'scripts\sim\macro_ledger_contract.gd'
$mainPath = Join-Path $root 'scripts\main.gd'
$contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8
$main = Get-Content -LiteralPath $mainPath -Raw -Encoding UTF8

function Assert-Contains([string]$value, [string]$needle, [string]$message) {
    if (-not $value.Contains($needle)) { throw "FUND-03 estrutural: $message" }
}

Assert-Contains $contract 'const VERSION := 1' 'versão do contrato ausente.'
Assert-Contains $contract 'const MAX_HISTORY := 240' 'limite de histórico ausente.'
Assert-Contains $contract 'unit_system' 'unidades declaradas ausentes.'
Assert-Contains $contract 'official' 'status official ausente.'
Assert-Contains $contract 'estimated' 'status estimated ausente.'
Assert-Contains $contract 'model' 'status model ausente.'
Assert-Contains $contract 'state.demography.population' 'referência populacional canônica ausente.'
Assert-Contains $contract 'cohort_total' 'reconciliação de coortes ausente.'
Assert-Contains $contract 'last_tick' 'guarda idempotente ausente.'
Assert-Contains $contract 'history.push_front' 'ledger append/prepend mensal ausente.'
Assert-Contains $main 'MacroLedgerContract.ensure(state)' 'integração de criação/migração ausente.'
Assert-Contains $main 'MacroLedgerContract.ensure(result)' 'ensure do save migrado ausente.'
Assert-Contains $main 'MacroLedgerContract.monthly(state)' 'integração do tick mensal ausente.'
Assert-Contains $main 'macro_ledger' 'campo do contrato ausente no estado padrão.'

Write-Output 'FUND-03 estrutural: PASS (sem execução do Godot).'
