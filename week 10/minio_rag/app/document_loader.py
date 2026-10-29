
import csv
import io
import json
from pathlib import PurePosixPath

import pymupdf

SUPPORTED_EXTENSIONS = {".txt", ".md", ".pdf", ".csv", ".json"}


def is_supported(object_name: str) -> bool:
    return PurePosixPath(object_name).suffix.lower() in SUPPORTED_EXTENSIONS


def load_document(object_name: str, data: bytes) -> list[dict]:
    """Extract text and source metadata from supported document formats."""
    suffix = PurePosixPath(object_name).suffix.lower()
    records = []

    if suffix == ".pdf":
        with pymupdf.open(stream=data, filetype="pdf") as pdf:
            for page_index, page in enumerate(pdf):
                text = page.get_text("text").strip()
                if text:
                    records.append({
                        "text": text,
                        "metadata": {
                            "source": object_name,
                            "file_type": "pdf",
                            "page": page_index + 1,
                        },
                    })

    elif suffix in {".txt", ".md"}:
        text = data.decode("utf-8", errors="replace").strip()
        if text:
            records.append({
                "text": text,
                "metadata": {
                    "source": object_name,
                    "file_type": suffix.lstrip("."),
                    "page": None,
                },
            })

    elif suffix == ".csv":
        csv_text = data.decode("utf-8-sig", errors="replace")
        rows = list(csv.reader(io.StringIO(csv_text)))
        text = "\n".join(" | ".join(row) for row in rows).strip()
        if text:
            records.append({
                "text": text,
                "metadata": {
                    "source": object_name,
                    "file_type": "csv",
                    "page": None,
                },
            })

    elif suffix == ".json":
        json_text = data.decode("utf-8-sig", errors="replace")
        parsed = json.loads(json_text)
        text = json.dumps(parsed, ensure_ascii=False, indent=2)
        records.append({
            "text": text,
            "metadata": {
                "source": object_name,
                "file_type": "json",
                "page": None,
            },
        })

    else:
        raise ValueError(f"Unsupported file type: {suffix}")

    return records
