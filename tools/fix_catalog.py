#!/usr/bin/env python3
"""Correcoes pontuais do catalogo apontadas por tools/audit_countries.py.

Idempotente: rodar de novo nao muda nada. Cada correcao registra a fonte e o
motivo em `notes`, sem inventar numeros.

Uso: python3 tools/fix_catalog.py && python3 tools/audit_countries.py
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "config" / "countries.json"


def country(payload: dict, cid: str) -> dict:
    for item in payload["countries"]:
        if item.get("id") == cid:
            return item
    raise SystemExit(f"pais ausente: {cid}")


def add_note(target: dict, text: str) -> None:
    notes = target.setdefault("notes", [])
    if text not in notes:
        notes.append(text)


def fix_ar(item: dict) -> None:
    # O bloco do Senado repetia a mesma sigla UCR ja publicada com as duas camaras
    # no bloco da Camara; manter os dois duplicava senate_seats na soma.
    parties = item["official_parties"]
    before = len(parties)
    item["official_parties"] = [p for p in parties if p.get("id") != "block-sen-ucr"]
    if len(item["official_parties"]) != before:
        add_note(
            item,
            "Correcao 2026-11-16: bloco senatorial UCR (id block-sen-ucr) removido por duplicar a sigla e as 10 cadeiras do Senado ja registradas no bloco block-hcdn-ucr.",
        )


def fix_co(item: dict) -> None:
    for chamber in item["chambers"]:
        if chamber.get("id") == "CO-HOR":
            if chamber.get("statutory_seats") != 183:
                chamber["statutory_seats"] = 183
                chamber["source_url"] = "https://www.senado.gov.co/index.php/el-senado/noticias/7175-ojo-al-dato-cuantos-senadores-y-representantes-se-eligen-este-8-de-marzo"
                add_note(
                    item,
                    "Correcao 2026-11-16: Camara de Representantes 2026-2030 fixada em 183 curules (161 territoriais + 16 CITREP + 2 afrodescendentes + 1 indigena + 1 raizal + 1 exterior + 1 oposicao), conforme Senado da Republica e Caracol Radio; antes o total estava nulo.",
                )
        if chamber.get("id") == "CO-SEN":
            if chamber.get("statutory_seats") != 103:
                chamber["statutory_seats"] = 103
                chamber["source_url"] = "https://caracol.com.co/2026/03/09/asi-quedaron-conformadas-las-curules-de-senado-y-camara-resultados-elecciones-congreso-2026"
                add_note(
                    item,
                    "Correcao 2026-11-16: Senado 2026-2030 fixado em 103 curules (100 nacionais + 2 indigenas + 1 oposicao), conforme Caracol Radio; o valor anterior (108) era da composicao 2022-2026.",
                )


def fix_pa(item: dict) -> None:
    # A lista VAMOS e alianca eleitoral: suas 19 cadeiras ja aparecem nos partidos
    # membros, entao soma-las dobrava a bancada (90 em uma Asamblea de 71).
    for party in item["official_parties"]:
        if party.get("abbr") == "VAMOS" and party.get("lower_house_seats") is not None:
            party["lower_house_seats"] = None
            add_note(
                item,
                "Correcao 2026-11-16: a lista VAMOS e alianca eleitoral; as 19 cadeiras ja estao contadas nos partidos membros. lower_house_seats passou a null para nao duplicar a bancada (90 -> 71).",
            )


def main() -> None:
    payload = json.loads(DATA.read_text(encoding="utf-8"))
    fix_ar(country(payload, "AR"))
    fix_co(country(payload, "CO"))
    fix_pa(country(payload, "PA"))
    DATA.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print("catalogo corrigido")


if __name__ == "__main__":
    main()
