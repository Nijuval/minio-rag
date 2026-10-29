
import httpx

OLLAMA_EMBED_URL = "http://localhost:11434/api/embed"


def embed_texts(texts: list[str]) -> list[list[float]]:
    if not texts:
        return []

    response = httpx.post(
        OLLAMA_EMBED_URL,
        json={
            "model": "all-minilm",
            "input": texts,
        },
        timeout=120.0,
    )
    response.raise_for_status()
    return response.json()["embeddings"]


def embedding_dimension() -> int:
    return len(embed_texts(["dimension check"])[0])
