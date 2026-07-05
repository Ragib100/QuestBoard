import pytest
from fastapi.testclient import TestClient

import os


@pytest.fixture
def client():
    if not os.getenv("DATABASE_URL") and not os.path.exists(".env"):
        pytest.skip("DATABASE_URL is not configured; skipping integration-style API test.")

    from app.main import app

    with TestClient(app) as test_client:
        yield test_client
