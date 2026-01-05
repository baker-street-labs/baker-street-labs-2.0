"""
Configuration utilities for the Holmes AWX Agent.
"""

from functools import lru_cache
from pathlib import Path
from typing import Optional

from pydantic import AnyHttpUrl, Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # AWX API configuration
    awx_api_url: AnyHttpUrl = Field(
        "https://rangeawx.bakerstreetlabs.io",
        description="Base URL for the AWX API",
    )
    awx_username: str = Field(
        ...,
        env="AWX_USERNAME",
        description="AWX username for authentication",
    )
    awx_password: str = Field(
        ...,
        env="AWX_PASSWORD",
        description="AWX password for authentication",
    )
    awx_verify_ssl: bool = Field(
        True,
        description="Verify SSL certificates for AWX API",
    )

    # Holmes AWX Agent security
    holmes_awx_token: str = Field(
        ...,
        env="HOLMES_AWX_TOKEN",
        description="Token required in X-Holmes-AWX-Token header",
    )

    # LLM configuration
    llm_provider: str = Field(
        "ollama",
        description="LLM provider: ollama, openai, anthropic, or groq",
    )
    ollama_base_url: str = Field(
        "http://macmini.bakerstreetlabs.io:11434",
        description="Base URL for Ollama API",
    )
    ollama_model: str = Field(
        "llama3.1:70b",
        description="Ollama model name",
    )
    openai_api_key: Optional[str] = Field(
        None,
        env="OPENAI_API_KEY",
        description="OpenAI API key (if using OpenAI)",
    )
    openai_model: str = Field(
        "gpt-4-turbo-preview",
        description="OpenAI model name",
    )
    anthropic_api_key: Optional[str] = Field(
        None,
        env="ANTHROPIC_API_KEY",
        description="Anthropic API key (if using Anthropic)",
    )
    anthropic_model: str = Field(
        "claude-3-opus-20240229",
        description="Anthropic model name",
    )

    # Operational settings
    job_retention_minutes: int = Field(
        60,
        description="How long to retain completed job metadata in memory",
    )
    job_cache_dir: str = Field(
        default=str(Path.home() / ".holmes-awx-agent" / "jobs"),
        description="Directory used to persist job metadata for retrieval",
    )
    job_poll_interval: int = Field(
        5,
        description="Seconds between job status polls",
    )
    job_timeout: int = Field(
        3600,
        description="Maximum job execution time in seconds",
    )

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Return cached settings instance."""
    return Settings()

