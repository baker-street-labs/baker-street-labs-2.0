"""
Adapter responsible for communicating with PowerDNS using the
existing baker-street-dns PowerDNS client.
"""

import logging
import os
import sys
from pathlib import Path
from typing import Tuple, Optional

from .config import get_settings

# Ensure the legacy PowerDNS client path is importable.
CURRENT_DIR = Path(__file__).resolve()
POWERDNS_CLIENT_PATH = CURRENT_DIR.parents[2] / "baker-street-dns" / "api"
sys.path.insert(0, str(POWERDNS_CLIENT_PATH))

from integrations.powerdns import PowerDNSClient

logger = logging.getLogger(__name__)


class PowerDNSAdapter:
    """Thin wrapper that exposes Holmes-friendly helper methods."""

    def __init__(self) -> None:
        settings = get_settings()
        self.client = PowerDNSClient(
            api_url=str(settings.powerdns_api_url),
            api_key=settings.powerdns_api_key,
            server_id=settings.powerdns_server_id,
        )

    def ensure_zone(self, zone: str) -> Tuple[bool, Optional[str]]:
        """Ensure the zone exists, creating it if needed."""
        fqdn_zone = f"{zone.rstrip('.')}"
        zones = self.client.list_zones()
        if any(z["name"].rstrip(".") == fqdn_zone for z in zones):
            return True, None

        logger.info("Zone %s not found. Creating via PowerDNS API.", fqdn_zone)
        return self.client.create_zone(zone_name=fqdn_zone)

    def upsert_record(
        self,
        zone: str,
        name: str,
        record_type: str,
        content: str,
        ttl: int,
    ) -> Tuple[bool, Optional[str]]:
        """Create or replace a DNS record."""
        return self.client.add_record(
            zone=zone,
            name=name,
            record_type=record_type,
            content=content,
            ttl=ttl,
        )


pdns_adapter = PowerDNSAdapter()


