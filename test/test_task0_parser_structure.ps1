Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..'
$mainPath = Join-Path $root 'scripts\main.gd'
$main = Get-Content -LiteralPath $mainPath -Raw -Encoding UTF8
$lines = $main -split "`r?`n"

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw "Tarefa 0 estrutural: $message" }
}

$preloads = [regex]::Matches($main, 'preload\("([^"]+)"\)')
Assert-True ($preloads.Count -gt 0) 'nenhum preload encontrado.'
foreach ($match in $preloads) {
    $relative = $match.Groups[1].Value -replace '^res://', ''
    Assert-True (Test-Path (Join-Path $root $relative)) "preload ausente: $relative"
}

# Verifica indentação dos blocos que foram alterados recentemente.
$checks = @{
    291 = 0; 292 = 1; 314 = 1; 315 = 2;
	4391 = 0; 4392 = 1; 4393 = 2; 4418 = 1; 4419 = 1;
    5126 = 1; 5148 = 1; 5149 = 1
}
foreach ($entry in $checks.GetEnumerator()) {
    $line = $lines[$entry.Key - 1]
    $match = [regex]::Match($line, '^([\t ]*)')
    $indent = $match.Groups[1].Value.Length
    Assert-True ($indent -eq $entry.Value) "indentação inesperada na linha $($entry.Key): $indent, esperado $($entry.Value)."
}

# O teste registra a indisponibilidade sem fingir que o parser Godot foi executado.
$godot = Get-Command godot -ErrorAction SilentlyContinue
$godot4 = Get-Command godot4 -ErrorAction SilentlyContinue
if ($null -eq $godot -and $null -eq $godot4) {
    Write-Output 'Tarefa 0 estrutural: PASS; Godot/headless indisponível, parser não validado.'
} else {
    Write-Output 'Tarefa 0 estrutural: PASS; Godot encontrado, mas execução não realizada por este teste.'
}
