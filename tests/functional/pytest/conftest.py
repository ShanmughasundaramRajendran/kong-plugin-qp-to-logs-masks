import os
import time

import pytest
import requests


@pytest.fixture(scope="session")
def base_url() -> str:
    return os.getenv("BASE_URL", "http://localhost:8000")


@pytest.fixture(scope="session")
def admin_url() -> str:
    return os.getenv("ADMIN_URL", "http://localhost:8001")


@pytest.fixture(scope="session")
def api_key() -> str:
    return os.getenv("APIKEY_C1", "demo-consumer-apikey")


@pytest.fixture(scope="session")
def default_headers(api_key: str) -> dict:
    return {
        "Accept": "application/json",
        "apikey": api_key,
    }


@pytest.fixture(scope="session", autouse=True)
def wait_for_kong(base_url: str):
    last_err = None
    for _ in range(30):
        try:
            res = requests.get(base_url, timeout=2)
            if res.status_code < 500:
                return
        except requests.RequestException as exc:
            last_err = exc
        time.sleep(1)

    raise RuntimeError(f"Kong did not become ready at {base_url}. Last error: {last_err}")
