from langchain.llms.base import LLM
from typing import Optional, List
import requests


class GPTOSSWrapper(LLM):
    endpoint_url: str
    temperature: float = 0.0

    @property
    def _llm_type(self) -> str:
        return "gpt-oss"

    def _call(self, prompt: str, stop: Optional[List[str]] = None) -> str:
        payload = {
            "messages": [{"role": "user", "content": prompt}],
            "temperature": self.temperature,
        }

        response = requests.post(self.endpoint_url, json=payload)
        response.raise_for_status()

        text = response.json().get("content", "")

        if stop:
            for s in stop:
                text = text.split(s)[0]

        return text
