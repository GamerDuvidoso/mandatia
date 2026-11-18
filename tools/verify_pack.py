#!/usr/bin/env python3
"""Confere o conteudo do pack exportado (builds/Mandatia.pck).

O build exportado nao consegue rodar `--script res://tools/...` (tools/* fica
fora do pack), entao a conferencia do pack e feita lendo os bytes do proprio
.pck: procura o conteudo que precisa estar embarcado (catalogo, exemplos da IA,
fontes, cena principal) e o que nao pode ter vazado (suites e instrumentos de
desenvolvimento).

Uso:
    python tools/verify_pack.py [caminho.pck]
Sai com codigo 1 se faltar algo obrigatorio ou se houver vazamento.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PACK = ROOT / "builds" / "Mandatia.pck"

# Conteudo que so existe dentro do recurso exportado correspondente.
REQUIRED = [
    (b'"party_data_status"', "config/countries.json (catalogo dos 35 paises)"),
    (b'"completion"', "config/ai_examples.json (exemplos dos contratos de IA)"),
    (b"Figtree", "assets/template/fonts (fonte do tema)"),
    (b"scenes/main.tscn", "cena principal"),
    (b"res://scripts/ai/ollama_client.gd", "cliente de IA"),
]

# Rotulos que existem apenas nos fontes de teste/instrumentos; se aparecerem no
# pack, um arquivo de desenvolvimento vazou para o build.
FORBIDDEN = [
    (b"[walk] %s: %d checks", "tools/walkthrough.gd"),
    (b"estado deve preservar oito", "test/test_suite.gd"),
    (b"[exported-pack]", "tools/verify_exported_pack.gd"),
    (b"[soak]", "tools/soak_harness.gd"),
]


def main() -> int:
    pack = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PACK
    if not pack.exists():
        print(f"[pack] FALHOU: {pack} nao existe")
        return 1
    data = pack.read_bytes()
    if data[:4] != b"GDPC":
        print(f"[pack] FALHOU: {pack.name} nao e um pack Godot")
        return 1
    print(f"[pack] {pack.name}: {len(data)} bytes")
    failures = [f"faltando: {label}" for token, label in REQUIRED if data.count(token) == 0]
    for token, label in FORBIDDEN:
        if data.count(token) > 0:
            failures.append(f"vazou para o pack: {label}")
    if failures:
        for failure in failures:
            print("[pack] ERRO:", failure)
        return 1
    print("[pack] PASS: catalogo, exemplos, fonte e cena no pack; nada de test/tools")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
