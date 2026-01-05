"""
LLM provider abstraction for Holmes AWX Agent.

Supports multiple LLM providers:
- Ollama (local 70b model)
- OpenAI (GPT-4, etc.)
- Anthropic (Claude)
"""

import logging
from typing import Optional

from typing import Union
from langchain_core.language_models import BaseLanguageModel
from langchain_ollama import Ollama
from langchain_openai import ChatOpenAI
from langchain_anthropic import ChatAnthropic

from .config import get_settings

logger = logging.getLogger(__name__)


def get_llm() -> BaseLanguageModel:
    """Get configured LLM instance based on settings."""
    settings = get_settings()
    
    if settings.llm_provider.lower() == "ollama":
        logger.info(f"Initializing Ollama LLM: {settings.ollama_model} at {settings.ollama_base_url}")
        return Ollama(
            base_url=settings.ollama_base_url,
            model=settings.ollama_model,
            temperature=0.7,
        )
    
    elif settings.llm_provider.lower() == "openai":
        if not settings.openai_api_key:
            raise ValueError("OPENAI_API_KEY not set but OpenAI provider selected")
        logger.info(f"Initializing OpenAI LLM: {settings.openai_model}")
        return ChatOpenAI(
            model=settings.openai_model,
            temperature=0.7,
            api_key=settings.openai_api_key,
        )
    
    elif settings.llm_provider.lower() == "anthropic":
        if not settings.anthropic_api_key:
            raise ValueError("ANTHROPIC_API_KEY not set but Anthropic provider selected")
        logger.info(f"Initializing Anthropic LLM: {settings.anthropic_model}")
        return ChatAnthropic(
            model=settings.anthropic_model,
            temperature=0.7,
            api_key=settings.anthropic_api_key,
        )
    
    else:
        raise ValueError(f"Unknown LLM provider: {settings.llm_provider}")


def get_llm_provider_name() -> str:
    """Get the name of the configured LLM provider."""
    settings = get_settings()
    return settings.llm_provider.lower()

