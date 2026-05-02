from __future__ import annotations

import json
import os
from copy import deepcopy
from datetime import datetime, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

try:
    from fastapi import FastAPI
except ModuleNotFoundError:
    FastAPI = None


CAPITAL_READINESS_PATH = Path(
    os.environ.get(
        "CAPITAL_READINESS_PATH",
        r"C:\temp\capital_readiness.json" if os.name == "nt" else "/tmp/capital_readiness.json",
    )
)

MARKET_TZ = ZoneInfo("America/New_York")
STALE_AFTER = timedelta(minutes=30)

EMPTY_CAPITAL_READINESS = {
    "mode": "advisory_only",
    "generated_at": "",
    "schwab_cash_available": 0,
    "schwab_budget_remaining": 0,
    "merrill_reserve_available": 0,
    "merrill_reserve_configured": False,
    "manual_action_required": False,
    "blocked_symbols": [],
}

app = FastAPI() if FastAPI else None


def load_capital_readiness() -> dict:
    if not CAPITAL_READINESS_PATH.exists():
        return deepcopy(EMPTY_CAPITAL_READINESS)

    try:
        with CAPITAL_READINESS_PATH.open("r", encoding="utf-8") as fh:
            payload = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return deepcopy(EMPTY_CAPITAL_READINESS)

    if not isinstance(payload, dict):
        return deepcopy(EMPTY_CAPITAL_READINESS)

    payload = deepcopy(payload)
    if is_stale(payload.get("generated_at", "")):
        payload["is_stale"] = True

    return payload


def is_stale(generated_at: str) -> bool:
    if not generated_at or not is_market_hours(datetime.now(MARKET_TZ)):
        return False

    try:
        generated = datetime.fromisoformat(generated_at)
    except ValueError:
        return True

    if generated.tzinfo is None:
        generated = generated.replace(tzinfo=MARKET_TZ)

    return datetime.now(MARKET_TZ) - generated.astimezone(MARKET_TZ) > STALE_AFTER


def is_market_hours(now: datetime) -> bool:
    if now.weekday() >= 5:
        return False

    current = now.time()
    return time(9, 30) <= current <= time(16, 0)


def capital_readiness() -> dict:
    return load_capital_readiness()


if app:
    app.get("/api/capital-readiness")(capital_readiness)
