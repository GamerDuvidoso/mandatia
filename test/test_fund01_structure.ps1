Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$mainPath = Join-Path $PSScriptRoot '..\scripts\main.gd'
$text = Get-Content -LiteralPath $mainPath -Raw -Encoding UTF8

function Assert-Contains([string]$value, [string]$needle, [string]$message) {
    if (-not $value.Contains($needle)) {
        throw "FUND-01 estrutural: $message"
    }
}

function Assert-Order([string]$value, [string]$first, [string]$second, [string]$message) {
    $a = $value.IndexOf($first, [StringComparison]::Ordinal)
    $b = $value.IndexOf($second, [StringComparison]::Ordinal)
    if ($a -lt 0 -or $b -lt 0 -or $a -ge $b) {
        throw "FUND-01 estrutural: $message"
    }
}

Assert-Contains $text 'func _save_game() -> bool:' 'save observável ausente.'
Assert-Contains $text 'return false' 'caminho explícito de falha do save ausente.'
Assert-Contains $text 'month_completed' 'marcador mensal ausente.'
Assert-Contains $text 'Conflict.monthly' 'tick global de conflitos ausente.'
Assert-Contains $text 'E2GeopoliticsContract.monthly' 'tick geopolítico E2 ausente.'
Assert-Contains $text 'E2ForcedFlowsContract.monthly' 'tick de fluxos E2 ausente.'
Assert-Contains $text 'GlobalShock.monthly' 'tick de choque global ausente.'

# O relatório deve ser construído depois das etapas produtoras do fechamento.
$completeMatch = [regex]::Match($text, '(?s)func _complete_month\(.*?(?=\r?\nfunc )')
if (-not $completeMatch.Success) { throw 'FUND-01 estrutural: _complete_month não encontrado.' }
$complete = $completeMatch.Value
Assert-Order $complete 'Demography.monthly' '_build_month_report' 'relatório aparece antes da demografia mensal.'
Assert-Order $complete 'PhaseGContract.monthly' '_build_month_report' 'relatório aparece antes da Fase G.'
Assert-Order $complete 'PhaseFInformation.monthly' '_build_month_report' 'relatório aparece antes da Fase F.'

# O commit do marcador precisa ocorrer depois da construção do relatório.
Assert-Order $complete '_build_month_report' 'state["month_completed"] = stamp' 'month_completed aparece antes do relatório.'

Write-Output 'FUND-01 estrutural: PASS (sem execução do Godot).'
