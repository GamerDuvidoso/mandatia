#!/usr/bin/env python3
"""Gera config/economy.json a partir de dados oficiais do World Bank (WDI).

Cada indicador guarda valor, unidade, ano de referência, classificação
(``official`` ou ``estimated``), fonte e metodologia. Dados ausentes nunca são
inventados: quando um indicador não existe para o país, ele é marcado como
``estimated`` e a metodologia descreve exatamente a regra usada (mediana
regional de observações oficiais do mesmo indicador).

Uso:
    python3 tools/build_economy_profiles.py            # baixa e grava
    python3 tools/build_economy_profiles.py --offline  # revalida o arquivo atual
"""

from __future__ import annotations

import argparse
import json
import statistics
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COUNTRIES = ROOT / "config" / "countries.json"
OUTPUT = ROOT / "config" / "economy.json"

API = "https://api.worldbank.org/v2/country/{codes}/indicator/{indicator}"
CACHE = Path("/tmp/mandatia_economy_cache")
YEARS = "2019:2024"
DEBT_YEARS = "2000:2024"
# Indicadores usados na simulação (os quatro indicadores macro) e contexto.
INDICATORS = {
    "gdp_growth": {
        "code": "NY.GDP.MKTP.KD.ZG",
        "label": "Crescimento do PIB",
        "unit": "% ao ano",
        "simulated": True,
    },
    "inflation": {
        "code": "FP.CPI.TOTL.ZG",
        "label": "Inflação (IPC)",
        "unit": "% ao ano",
        "simulated": True,
    },
    "unemployment": {
        "code": "SL.UEM.TOTL.ZS",
        "label": "Desemprego",
        "unit": "% da força de trabalho",
        "simulated": True,
    },
    "debt": {
        "code": "GC.DOD.TOTL.GD.ZS",
        "label": "Dívida do governo central",
        "unit": "% do PIB",
        "simulated": True,
    },
    "gdp": {
        "code": "NY.GDP.MKTP.CD",
        "label": "PIB nominal",
        "unit": "US$ correntes",
        "simulated": False,
    },
    "gdp_per_capita": {
        "code": "NY.GDP.PCAP.CD",
        "label": "PIB per capita",
        "unit": "US$ correntes",
        "simulated": False,
    },
    "population": {
        "code": "SP.POP.TOTL",
        "label": "População",
        "unit": "habitantes",
        "simulated": False,
    },
    "revenue": {
        "code": "GC.REV.XGRT.GD.ZS",
        "label": "Receita do governo central",
        "unit": "% do PIB",
        "simulated": False,
    },
    "expense": {
        "code": "GC.XPN.TOTL.GD.ZS",
        "label": "Despesa do governo central",
        "unit": "% do PIB",
        "simulated": False,
    },
}

# Faixa que a simulação consegue representar sem perder sentido de jogo.
# Quando o dado real está fora dela, o valor observado é preservado em ``value``
# e o valor inicial do jogo vai em ``simulation_value`` com nota de calibração.
SIM_BOUNDS = {
    "gdp_growth": (-6.0, 8.0),
    "inflation": (1.5, 15.0),
    "unemployment": (3.5, 18.0),
    "debt": (20.0, 120.0),
}

REGIONS = {
    "AR": "América do Sul", "BO": "América do Sul", "BR": "América do Sul",
    "CL": "América do Sul", "CO": "América do Sul", "EC": "América do Sul",
    "GY": "América do Sul", "PY": "América do Sul", "PE": "América do Sul",
    "SR": "América do Sul", "UY": "América do Sul", "VE": "América do Sul",
    "CA": "América do Norte", "US": "América do Norte", "MX": "América do Norte",
    "BZ": "América Central", "CR": "América Central", "SV": "América Central",
    "GT": "América Central", "HN": "América Central", "NI": "América Central",
    "PA": "América Central",
    "AG": "Caribe", "BS": "Caribe", "BB": "Caribe", "CU": "Caribe",
    "DM": "Caribe", "DO": "Caribe", "GD": "Caribe", "HT": "Caribe",
    "JM": "Caribe", "KN": "Caribe", "LC": "Caribe", "VC": "Caribe",
    "TT": "Caribe",
}

SANE_RANGES = {
    "gdp_growth": (-15.0, 15.0),
    "inflation": (-5.0, 300.0),
    "unemployment": (0.5, 45.0),
    # 0% e valores de três dígitos altos aparecem em revisões antigas do WDI
    # (ex.: dívida em moeda local); são rejeitados como observação utilizável.
    "debt": (5.0, 300.0),
}


def fetch_indicator(
    code: str, iso2_codes: list[str], years: str = YEARS
) -> dict[str, list[tuple[int, float]]]:
    """Retorna {ISO2: [(ano, valor), ...]} para um indicador."""
    result: dict[str, list[tuple[int, float]]] = {}
    CACHE.mkdir(parents=True, exist_ok=True)
    for start in range(0, len(iso2_codes), 10):
        chunk = iso2_codes[start:start + 10]
        query = urllib.parse.urlencode({"format": "json", "date": years, "per_page": 1000})
        url = API.format(codes=";".join(chunk), indicator=code) + "?" + query
        cache_file = CACHE / (f"{code}-{years}-{start}.json".replace(":", "_"))
        if cache_file.exists():
            payload = json.loads(cache_file.read_text(encoding="utf-8"))
        else:
            payload = None
            for attempt in range(4):
                try:
                    with urllib.request.urlopen(url, timeout=90) as response:
                        payload = json.load(response)
                    break
                except Exception as error:  # noqa: BLE001 - retry rede
                    if attempt == 3:
                        raise
                    print(f"[economy] retry {attempt + 1} {code} chunk {start}: {error}")
                    time.sleep(2 + attempt * 3)
            cache_file.write_text(
                json.dumps(payload, ensure_ascii=False), encoding="utf-8"
            )
        rows = payload[1] if len(payload) > 1 and payload[1] else []
        for row in rows:
            value = row.get("value")
            if value is None:
                continue
            # country.id é o ISO2; fatiar countryiso3code daria CH/ME/PR/UR/BR
            # para Chile, México, Paraguai, Uruguai e Barbados.
            iso2 = str(row.get("country", {}).get("id", ""))
            if iso2 not in chunk:
                continue
            result.setdefault(iso2, []).append((int(row["date"]), float(value)))
    for series in result.values():
        series.sort(reverse=True)
    return result


def latest(series: list[tuple[int, float]] | None) -> tuple[int, float] | None:
    return series[0] if series else None


def latest_sane(key: str, series: list[tuple[int, float]] | None) -> tuple[int, float] | None:
    """Primeira observação dentro da faixa plausível para o indicador."""
    low, high = SANE_RANGES.get(key, (float("-inf"), float("inf")))
    for year, value in series or []:
        if low <= value <= high:
            return year, value
    return None


def round_value(key: str, value: float) -> float:
    if key in ("gdp", "population"):
        return round(value)
    if key == "gdp_per_capita":
        return round(value, 1)
    return round(value, 2)


def build(offline: bool) -> dict:
    countries = json.loads(COUNTRIES.read_text(encoding="utf-8"))["countries"]
    ids = [str(country["id"]) for country in countries]
    if offline:
        return json.loads(OUTPUT.read_text(encoding="utf-8"))

    data = {key: fetch_indicator(spec["code"], ids) for key, spec in INDICATORS.items()}
    debt_history = fetch_indicator(
        INDICATORS["debt"]["code"], ids, years=DEBT_YEARS
    )

    def official(profile: dict, key: str, cid: str, year: int, value: float) -> None:
        spec = INDICATORS[key]
        profile[key] = {
            "value": round_value(key, value),
            "unit": spec["unit"],
            "year": year,
            "status": "official",
            "source": "World Bank, World Development Indicators (WDI)",
            "source_code": spec["code"],
            "source_url": (
                "https://data.worldbank.org/indicator/"
                f"{spec['code']}?locations={cid}"
            ),
        }

    def peer_median(key: str, cid: str, region: str) -> tuple[float, int, int] | None:
        peers = [
            latest_sane(key, data[key].get(peer))
            for peer in ids
            if peer != cid and REGIONS.get(peer) == region
        ]
        peers = [entry for entry in peers if entry is not None]
        if not peers:
            peers = [
                entry
                for peer in ids
                if peer != cid
                for entry in [latest_sane(key, data[key].get(peer))]
                if entry is not None
            ]
        if not peers:
            return None
        years = [year for year, _ in peers]
        values = [value for _, value in peers]
        return statistics.median(values), max(years), len(values)

    profiles: dict[str, dict] = {}
    for country in countries:
        cid = str(country["id"])
        region = REGIONS.get(cid, "América")
        profile: dict = {"name": str(country.get("name", cid)), "region": region}
        for key, spec in INDICATORS.items():
            if key == "debt":
                continue
            point = latest_sane(key, data[key].get(cid))
            if point is not None:
                official(profile, key, cid, point[0], point[1])
                continue
            medians = peer_median(key, cid, region)
            if medians is not None:
                estimate, year, count = medians
                profile[key] = {
                    "value": round_value(key, estimate),
                    "unit": spec["unit"],
                    "year": year,
                    "status": "estimated",
                    "source": "Estimativa do projeto (sem observação no World Bank WDI)",
                    "source_code": spec["code"],
                    "methodology": (
                        f"Mediana de {count} observações oficiais do mesmo indicador "
                        f"em países da região {region}; usada porque o país não tem "
                        "observação publicada na janela 2019-2024."
                    ),
                }
            else:
                profile[key] = {
                    "value": 0.0,
                    "unit": spec["unit"],
                    "year": 0,
                    "status": "estimated",
                    "source": "Estimativa do projeto (sem observação no World Bank WDI)",
                    "source_code": spec["code"],
                    "methodology": "Sem observação oficial e sem pares regionais; valor neutro.",
                }

        # Dívida: o WDI só publica a série para parte dos países. Usa-se a
            # observação oficial mais recente disponível (o ano vai no registro);
        # sem nenhuma observação, estima-se pela mediana regional.
        recent = latest_sane("debt", data["debt"].get(cid))
        if recent is not None:
            official(profile, "debt", cid, recent[0], recent[1])
        else:
            old = latest_sane("debt", debt_history.get(cid))
            if old is not None:
                official(profile, "debt", cid, old[0], old[1])
                profile["debt"]["note"] = (
                    "Observação oficial mais recente publicada no WDI para o país; "
                    "não há valor na janela 2019-2024 e o dado não foi projetado."
                )
            else:
                medians = peer_median("debt", cid, region)
                if medians is not None:
                    estimate, year, count = medians
                    profile["debt"] = {
                        "value": round_value("debt", estimate),
                        "unit": INDICATORS["debt"]["unit"],
                        "year": year,
                        "status": "estimated",
                        "source": "Estimativa do projeto (sem observação no World Bank WDI)",
                        "source_code": INDICATORS["debt"]["code"],
                        "methodology": (
                            f"Mediana de {count} observações oficiais de dívida na "
                            f"região {region} (ano de referência {year}); o país não "
                            "tem nenhuma observação publicada no WDI na janela "
                            "2000-2024."
                        ),
                    }
                else:
                    profile["debt"] = {
                        "value": 60.0,
                        "unit": INDICATORS["debt"]["unit"],
                        "year": 2024,
                        "status": "estimated",
                        "source": "Estimativa do projeto",
                        "source_code": INDICATORS["debt"]["code"],
                        "methodology": "Sem observação e sem pares; premissa neutra de 60% do PIB.",
                    }

        # Calibração de jogo: preserva o dado real, mas limita o valor inicial.
        for key, (low, high) in SIM_BOUNDS.items():
            entry = profile[key]
            value = float(entry["value"])
            clamped = min(high, max(low, value))
            if abs(clamped - value) > 1e-9:
                entry["simulation_value"] = round_value(key, clamped)
                entry["calibration"] = (
                    f"Valor inicial limitado a [{low:g}, {high:g}] porque a simulação "
                    "não representa a magnitude observada; o dado original é mantido em value."
                )
            else:
                entry["simulation_value"] = round_value(key, value)

        profiles[cid] = profile

    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source_policy": (
            "Observações oficiais do World Bank WDI (2019-2024, ano mais recente "
            "disponível por indicador). Ausências são estimadas por mediana regional "
            "e marcadas como estimated, com metodologia e ano de referência."
        ),
        "indicators": {
            key: {
                "label": spec["label"],
                "unit": spec["unit"],
                "source_code": spec["code"],
                "simulated": spec["simulated"],
                "sane_range": list(SANE_RANGES.get(key, ())),
                "simulation_bounds": list(SIM_BOUNDS.get(key, ())),
            }
            for key, spec in INDICATORS.items()
        },
        "countries": profiles,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true", help="não baixa; revalida o arquivo")
    args = parser.parse_args()
    payload = build(args.offline)
    if not args.offline:
        OUTPUT.write_text(
            json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
    official = sum(
        1
        for profile in payload["countries"].values()
        for key in INDICATORS
        if profile.get(key, {}).get("status") == "official"
    )
    estimated = sum(
        1
        for profile in payload["countries"].values()
        for key in INDICATORS
        if profile.get(key, {}).get("status") == "estimated"
    )
    print(
        f"[economy] {len(payload['countries'])} países · "
        f"{official} observações oficiais · {estimated} estimativas"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
