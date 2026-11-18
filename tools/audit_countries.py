#!/usr/bin/env python3
"""Auditoria do catalogo politico (config/countries.json).

Verifica o que o jogo realmente consome: tamanho da camara baixa, bancadas
publicadas, ideologia, lideres e consistencia das somas.

Cada lacuna e classificada como:
  resolvida    - partido/camara com dado oficial fechado;
  documentada  - lacuna registrada em notes/seats_note/seat_gap_note, sem
                 numero estimado;
  pendente     - lacuna sem dado e sem documentacao.

Uso: python3 tools/audit_countries.py [--strict]
Sai com codigo 1 se houver erro estrutural (soma maior que a camara,
sem total de camara, abbr duplicada) ou, com --strict, qualquer pendencia.
"""

from __future__ import annotations

import json
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "config" / "countries.json"
MIN_SCHEMA = 5


def fold(text: str) -> str:
    return "".join(
        char
        for char in unicodedata.normalize("NFD", text.lower())
        if unicodedata.category(char) != "Mn"
    )


def stat_seats(chamber: dict) -> int:
    return int(chamber.get("statutory_seats") or chamber.get("occupied_seats") or 0)


def is_upper(chamber: dict) -> bool:
    text = fold(str(chamber.get("name", "")) + " " + str(chamber.get("id", "")))
    return "senad" in text or "senate" in text or "camara alta" in text or text.endswith("-uc01")


def lower_chamber(country: dict) -> dict:
    """Mesma regra de scripts/sim/election.gd: primeira camara que nao e alta."""
    chambers = country.get("chambers") or []
    for chamber in chambers:
        if not is_upper(chamber):
            return chamber
    if not chambers:
        return {}
    return max(chambers, key=stat_seats)


def has_text(value) -> bool:
    return isinstance(value, str) and value.strip() != ""


def audit() -> tuple[list[str], list[str], list[str], dict]:
    payload = json.loads(DATA.read_text(encoding="utf-8"))
    errors: list[str] = []
    pending: list[str] = []
    documented: list[str] = []
    summary = {
        "countries": 0,
        "parties": 0,
        "no_leader": 0,
        "no_ideology": 0,
        "unassigned": 0,
        "resolved": 0,
        "documented": 0,
        "pending": 0,
    }

    schema = int(payload.get("schema_version", 0))
    if schema < MIN_SCHEMA:
        errors.append(f"schema_version {schema} < {MIN_SCHEMA}")

    countries = payload.get("countries", [])
    summary["countries"] = len(countries)

    for country in countries:
        cid = str(country.get("id", "??"))
        chamber = lower_chamber(country)
        total = stat_seats(chamber)
        parties = country.get("official_parties") or []
        summary["parties"] += len(parties)
        gap_note = country.get("seat_gap_note")

        if not chamber:
            errors.append(f"{cid}: sem camara cadastrada")
            continue
        if total <= 0:
            errors.append(f"{cid}: camara baixa ({chamber.get('name', '?')}) sem total de cadeiras")

        seen: set[str] = set()
        assigned = 0
        nulls: list[str] = []
        undocumented_nulls: list[str] = []
        for party in parties:
            abbr = str(party.get("abbr", "")).strip()
            if not abbr:
                errors.append(f"{cid}: partido sem sigla ({party.get('name', '?')})")
                continue
            if abbr in seen:
                errors.append(f"{cid}: sigla duplicada {abbr}")
            seen.add(abbr)
            if not str(party.get("ideology", "")).strip():
                summary["no_ideology"] += 1
                errors.append(f"{cid}: {abbr} sem ideologia")
            if not str(party.get("leader", "")).strip():
                summary["no_leader"] += 1
                errors.append(f"{cid}: {abbr} sem lider publicado")
            seats = party.get("lower_house_seats")
            if seats is None:
                nulls.append(abbr)
                if not has_text(party.get("seats_note")):
                    undocumented_nulls.append(abbr)
            else:
                assigned += int(seats)
                summary["resolved"] += 1

        if not parties:
            if has_text(gap_note):
                summary["documented"] += 1
                documented.append(f"{cid}: sem partidos oficiais - {gap_note}")
            else:
                summary["pending"] += 1
                pending.append(f"{cid}: sem partidos oficiais e sem documentacao")

        if nulls:
            if has_text(gap_note) or not undocumented_nulls:
                summary["documented"] += 1
                documented.append(
                    f"{cid}: {len(nulls)} partidos sem cadeira na camara baixa "
                    f"({', '.join(nulls[:6])}) - documentado"
                )
            else:
                summary["pending"] += 1
                pending.append(
                    f"{cid}: {len(undocumented_nulls)} partidos sem cadeira e sem notes "
                    f"({', '.join(undocumented_nulls[:6])})"
                )

        if total > 0:
            if assigned > total:
                errors.append(f"{cid}: bancadas somam {assigned} > camara de {total}")
            elif assigned < total:
                gap = total - assigned
                summary["unassigned"] += gap
                if has_text(gap_note):
                    summary["documented"] += 1
                    documented.append(f"{cid}: {gap} cadeiras nao atribuidas - documentado em notes")
                else:
                    summary["pending"] += 1
                    pending.append(f"{cid}: {gap} cadeiras nao atribuidas ({assigned}/{total})")

    return errors, pending, documented, summary


def main() -> int:
    errors, pending, documented, summary = audit()
    print("== MANDATIA / auditoria do catalogo ==")
    print(
        f"paises: {summary['countries']}  partidos: {summary['parties']}  "
        f"sem lider: {summary['no_leader']}  sem ideologia: {summary['no_ideology']}  "
        f"cadeiras nao atribuidas: {summary['unassigned']}"
    )
    print(
        f"lacunas: resolvidas(partidos)={summary['resolved']}  "
        f"documentadas={summary['documented']}  pendentes={summary['pending']}"
    )
    if documented:
        print(f"\n-- documentadas ({len(documented)}) --")
        for item in documented:
            print("  ·", item)
    if pending:
        print(f"\n-- pendentes ({len(pending)}) --")
        for item in pending:
            print("  !", item)
    if errors:
        print(f"\n-- erros ({len(errors)}) --")
        for item in errors:
            print("  x", item)
    strict = "--strict" in sys.argv[1:]
    ok = not errors and summary["pending"] == 0 and (not strict or summary["documented"] == 0)
    print(
        "\nRESULTADO:",
        f"OK (pendencias={summary['pending']}, documentadas={summary['documented']})" if ok else "FALHOU",
    )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
