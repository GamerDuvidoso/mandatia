#!/usr/bin/env python3
"""Auditoria dos perfis econômicos (config/economy.json).

Verifica o contrato que o jogo consome:
  · todos os 35 países do catálogo político têm perfil;
  · os quatro indicadores simulados existem com value/unit/year/status/source;
  · official exige source, source_code, source_url e ano de referência;
  · estimated exige methodology não vazia;
  · value respeita sane_range e simulation_value respeita simulation_bounds;
  · calibração só existe quando simulation_value difere de value;
  · nenhum país ficou com os quatro indicadores idênticos a outro.

Uso: python3 tools/audit_economy.py [--strict]
Sai com código 1 se houver erro. --strict também falha se houver estimativa.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COUNTRIES = ROOT / "config" / "countries.json"
ECONOMY = ROOT / "config" / "economy.json"
SIMULATED = ["gdp_growth", "inflation", "unemployment", "debt"]
REQUIRED = ["value", "unit", "year", "status", "source"]


def main() -> int:
    countries_doc = json.loads(COUNTRIES.read_text(encoding="utf-8"))
    economy = json.loads(ECONOMY.read_text(encoding="utf-8"))
    errors: list[str] = []
    warnings: list[str] = []
    official = 0
    estimated = 0

    if int(economy.get("schema_version", 0)) < 1:
        errors.append("schema_version ausente ou inválido")

    catalog = {str(country["id"]): country for country in countries_doc["countries"]}
    profiles = economy.get("countries", {})
    if set(profiles) != set(catalog):
        missing = sorted(set(catalog) - set(profiles))
        extra = sorted(set(profiles) - set(catalog))
        if missing:
            errors.append(f"perfis ausentes: {', '.join(missing)}")
        if extra:
            errors.append(f"perfis fora do catálogo: {', '.join(extra)}")

    indicators = economy.get("indicators", {})
    for key in SIMULATED:
        spec = indicators.get(key, {})
        if not spec:
            errors.append(f"indicador {key} não declarado em indicators")
            continue
        if not spec.get("simulated"):
            errors.append(f"indicador {key} deveria ser simulado")
        if not spec.get("sane_range"):
            errors.append(f"indicador {key} sem sane_range")

    signatures: dict[str, str] = {}
    for cid, profile in sorted(profiles.items()):
        name = catalog.get(cid, {}).get("name", cid)
        if not profile.get("name"):
            errors.append(f"{cid}: perfil sem nome")
        if not profile.get("region"):
            errors.append(f"{cid}: perfil sem região")
        for key in SIMULATED:
            entry = profile.get(key)
            if not isinstance(entry, dict):
                errors.append(f"{cid}/{key}: indicador ausente")
                continue
            for field in REQUIRED:
                if field not in entry:
                    errors.append(f"{cid}/{key}: campo obrigatório {field} ausente")
            if not isinstance(entry.get("value"), (int, float)):
                errors.append(f"{cid}/{key}: value não numérico")
                continue
            year = entry.get("year")
            if not isinstance(year, int) or not (2000 <= year <= 2024):
                errors.append(f"{cid}/{key}: ano de referência inválido ({year})")
            status = entry.get("status")
            if status == "official":
                official += 1
                for field in ("source", "source_code", "source_url"):
                    if not str(entry.get(field, "")).strip():
                        errors.append(f"{cid}/{key}: official sem {field}")
            elif status == "estimated":
                estimated += 1
                if not str(entry.get("methodology", "")).strip():
                    errors.append(f"{cid}/{key}: estimativa sem metodologia")
            else:
                errors.append(f"{cid}/{key}: status inválido ({status})")
            sane = indicators.get(key, {}).get("sane_range") or []
            if len(sane) == 2 and not (float(sane[0]) <= float(entry["value"]) <= float(sane[1])):
                errors.append(
                    f"{cid}/{key}: value {entry['value']} fora da faixa plausível {sane}"
                )
            sim = entry.get("simulation_value")
            bounds = indicators.get(key, {}).get("simulation_bounds") or []
            if sim is None:
                errors.append(f"{cid}/{key}: simulation_value ausente")
            elif len(bounds) == 2 and not (float(bounds[0]) <= float(sim) <= float(bounds[1])):
                errors.append(
                    f"{cid}/{key}: simulation_value {sim} fora dos limites {bounds}"
                )
            if sim is not None and abs(float(sim) - float(entry["value"])) > 1e-9:
                if not str(entry.get("calibration", "")).strip():
                    errors.append(
                        f"{cid}/{key}: simulation_value difere de value sem nota de calibração"
                    )
            elif entry.get("calibration"):
                warnings.append(f"{cid}/{key}: calibração registrada sem diferença de valor")
            if name and key == "debt" and float(entry["value"]) > 200.0:
                warnings.append(f"{cid}/debt: dívida observada muito alta ({entry['value']})")

        signature = "|".join(str(profile[key].get("simulation_value")) for key in SIMULATED)
        if signature in signatures:
            errors.append(
                f"{cid}: perfil econômico idêntico a {signatures[signature]} "
                "(os países precisam começar diferentes)"
            )
        else:
            signatures[signature] = cid

    print("== MANDATIA / auditoria econômica ==")
    print(
        f"países: {len(profiles)}  indicadores simulados: {len(SIMULATED)}  "
        f"observações oficiais: {official}  estimativas: {estimated}"
    )
    if warnings:
        print(f"\n-- avisos ({len(warnings)}) --")
        for item in warnings:
            print("  ·", item)
    if errors:
        print(f"\n-- erros ({len(errors)}) --")
        for item in errors:
            print("  x", item)
    strict = "--strict" in sys.argv[1:]
    failed = bool(errors) or (strict and estimated > 0)
    print("\nRESULTADO:", "FALHOU" if failed else "OK")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
