#!/usr/bin/env python3
"""Print a normalized SOLIX snapshot JSON for SolixBar.

Requirements:
  - Python 3.12+
  - thomluther/anker-solix-api installed in the active environment
  - ANKER_SOLIX_USER, ANKER_SOLIX_PASSWORD and ANKER_SOLIX_COUNTRY env vars
"""

import asyncio
import json
import os
from datetime import datetime, timezone

from aiohttp import ClientSession
from anker_solix_api import api


def _first_number(*values):
    for value in values:
        if isinstance(value, (int, float)):
            return value
        if isinstance(value, str):
            try:
                return float(value)
            except ValueError:
                pass
    return None


async def main():
    user = os.environ["ANKER_SOLIX_USER"]
    password = os.environ["ANKER_SOLIX_PASSWORD"]
    country = os.environ.get("ANKER_SOLIX_COUNTRY", "DE")

    async with ClientSession() as session:
        client = api.AnkerSolixApi(user, password, country, session)
        await client.update_sites()
        await client.update_device_details()

        site = next(iter(client.sites.values()), {})
        devices = list(client.devices.values())
        battery = next((device for device in devices if "battery" in str(device.get("type", "")).lower()), {})

        snapshot = {
            "siteName": site.get("site_name") or site.get("siteName") or "Anker SOLIX",
            "batteryPercent": _first_number(
                battery.get("battery_soc"),
                battery.get("battery_percentage"),
                site.get("battery_soc"),
                site.get("soc"),
            ),
            "solarWatts": _first_number(site.get("solar_power"), site.get("photovoltaic_power"), site.get("pv_power")),
            "homeWatts": _first_number(site.get("home_load"), site.get("load_power"), site.get("home_power")),
            "gridWatts": _first_number(site.get("grid_power"), site.get("to_grid_power")),
            "batteryWatts": _first_number(site.get("battery_power"), battery.get("power")),
            "todayKWh": _first_number(site.get("today_energy"), site.get("energy_today")),
            "totalKWh": _first_number(site.get("total_energy"), site.get("energy_total")),
            "status": site.get("status") or battery.get("status") or "Online",
            "updatedAt": datetime.now(timezone.utc).isoformat(),
        }

        print(json.dumps(snapshot, separators=(",", ":")))


if __name__ == "__main__":
    asyncio.run(main())
