"""
Configuration utilities for the Holmes DNS Agent.
"""

from functools import lru_cache
from pathlib import Path

from pydantic import AnyHttpUrl, Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # DNS Backend Selection
    dns_backend: str = Field(
        "technitium",
        description="DNS backend to use: 'technitium' or 'powerdns'",
    )

    # Technitium DNS Server API configuration
    technitium_api_url: AnyHttpUrl = Field(
        "http://192.168.0.53:5380",
        description="Base URL for the Technitium DNS Server HTTP API",
    )
    technitium_api_token: str = Field(
        ...,
        env="TECHNITIUM_API_TOKEN",
        description="API token for Technitium DNS Server",
    )

    # PowerDNS HTTP API configuration (legacy)
    powerdns_api_url: AnyHttpUrl = Field(
        "http://192.168.0.28:30280",
        description="Base URL for the PowerDNS HTTP API",
    )
    powerdns_api_key: str = Field(
        default="",
        env="POWERDNS_API_KEY",
        description="API key for PowerDNS HTTP API (X-API-Key header)",
    )
    powerdns_server_id: str = Field(
        "localhost",
        description="PowerDNS server identifier used in API paths",
    )

    # Holmes DNS Agent security
    holmes_api_token: str = Field(
        ...,
        env="HOLMES_API_TOKEN",
        description="Token required in X-Holmes-Token header",
    )

    # Operational settings
    job_retention_minutes: int = Field(
        60,
        description="How long to retain completed job metadata in memory",
    )
    job_cache_dir: str = Field(
        default=str(Path.home() / ".holmes-dns-agent" / "jobs"),
        description="Directory used to persist job metadata for retrieval",
    )

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Return cached settings instance."""
    return Settings()


