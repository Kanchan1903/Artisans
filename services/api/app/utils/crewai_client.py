"""CrewAI AMP client for the deployed product-image-processing crew.

Documented contract (CrewAI AMP):
  GET  {base}/inputs
  POST {base}/kickoff          body: {"inputs": {<string values>}}
  GET  {base}/status/{kickoff_id}
"""
from __future__ import annotations

import logging
from typing import Any

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

DEFAULT_CREWAI_BASE = (
    "https://karigarai-product-image-processing-agent-v1-4812b293.crewai.com"
)

REQUIRED_INPUT_FIELDS = (
    "job_id",
    "artisan_id",
    "photo_url",
    "product_name",
    "product_category",
    "background_colors",
    "generate_variations",
    "product_id",
)


class CrewAIError(Exception):
    def __init__(self, message: str, status_code: int | None = None):
        super().__init__(message)
        self.status_code = status_code


class CrewAIClient:
    def __init__(
        self,
        base_url: str | None = None,
        bearer_token: str | None = None,
        transport: httpx.AsyncBaseTransport | None = None,
    ):
        self.base_url = (base_url or settings.CREWAI_API_BASE_URL or DEFAULT_CREWAI_BASE).rstrip("/")
        self.bearer_token = bearer_token if bearer_token is not None else settings.CREWAI_BEARER_TOKEN
        self._transport = transport

    def is_configured(self) -> bool:
        token = (self.bearer_token or "").strip()
        return bool(
            self.base_url
            and token
            and token.lower() not in {"your_crewai_bearer_token_here", "change_me", "placeholder"}
            and not token.lower().startswith("your_")
        )

    def _headers(self) -> dict[str, str]:
        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        if self.bearer_token:
            headers["Authorization"] = f"Bearer {self.bearer_token}"
        return headers

    def _client(self, timeout: float = 30.0) -> httpx.AsyncClient:
        return httpx.AsyncClient(timeout=timeout, transport=self._transport)

    async def get_inputs(self) -> list[str]:
        """Discover required kickoff fields from the deployed crew."""
        try:
            async with self._client(timeout=15.0) as client:
                res = await client.get(f"{self.base_url}/inputs", headers=self._headers())
        except httpx.TimeoutException as exc:
            raise CrewAIError("CrewAI input discovery timed out") from exc
        except httpx.HTTPError as exc:
            raise CrewAIError("CrewAI input discovery request failed") from exc
        if res.status_code != 200:
            raise CrewAIError(f"CrewAI /inputs failed ({res.status_code})", status_code=res.status_code)
        try:
            payload = res.json()
        except ValueError as exc:
            raise CrewAIError("CrewAI /inputs returned malformed JSON") from exc
        if isinstance(payload, list):
            return [str(x.get("name")) if isinstance(x, dict) and x.get("name") else str(x) for x in payload]
        if isinstance(payload, dict) and isinstance(payload.get("inputs"), list):
            return [str(x.get("name")) if isinstance(x, dict) and x.get("name") else str(x) for x in payload["inputs"]]
        return []

    async def kickoff(self, inputs: dict[str, Any]) -> str:
        """Start a crew execution. Returns kickoff_id. Does not imply processing succeeded."""
        if not self.is_configured():
            raise CrewAIError("CrewAI is not configured (missing CREWAI_BEARER_TOKEN)")

        string_inputs = {k: "" if v is None else str(v) for k, v in inputs.items()}
        try:
            async with self._client(timeout=45.0) as client:
                res = await client.post(
                    f"{self.base_url}/kickoff",
                    headers=self._headers(),
                    json={"inputs": string_inputs},
                )
        except httpx.TimeoutException as exc:
            raise CrewAIError("CrewAI kickoff timed out") from exc
        except httpx.HTTPError as exc:
            raise CrewAIError("CrewAI kickoff request failed") from exc
        if res.status_code >= 400:
            raise CrewAIError(f"CrewAI /kickoff failed ({res.status_code})", status_code=res.status_code)
        try:
            data = res.json()
        except ValueError as exc:
            raise CrewAIError("CrewAI /kickoff returned malformed JSON") from exc
        if not isinstance(data, dict):
            raise CrewAIError("CrewAI /kickoff returned a non-object payload")
        kickoff_id = data.get("kickoff_id") or data.get("id")
        if not kickoff_id:
            raise CrewAIError("CrewAI /kickoff did not return a kickoff_id")
        return str(kickoff_id)

    async def get_status(self, kickoff_id: str) -> dict[str, Any]:
        if not self.is_configured():
            raise CrewAIError("CrewAI is not configured (missing CREWAI_BEARER_TOKEN)")
        try:
            async with self._client(timeout=30.0) as client:
                res = await client.get(
                    f"{self.base_url}/status/{kickoff_id}",
                    headers=self._headers(),
                )
        except httpx.TimeoutException as exc:
            raise CrewAIError("CrewAI status request timed out") from exc
        except httpx.HTTPError as exc:
            raise CrewAIError("CrewAI status request failed") from exc
        if res.status_code >= 400:
            raise CrewAIError(f"CrewAI /status failed ({res.status_code})", status_code=res.status_code)
        try:
            data = res.json()
        except ValueError as exc:
            raise CrewAIError("CrewAI /status returned malformed JSON") from exc
        if not isinstance(data, dict):
            raise CrewAIError("CrewAI /status returned a non-object payload")
        return data


crewai_client = CrewAIClient()
