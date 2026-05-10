import pytest
from main import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index_returns_200(client):
    response = client.get("/")
    assert response.status_code == 200


def test_index_json_structure(client):
    response = client.get("/")
    data = response.get_json()
    assert "service" in data
    assert "status" in data
    assert data["status"] == "running"
    assert data["service"] == "devops-challenge-api"


def test_health_returns_200(client):
    response = client.get("/health")
    assert response.status_code == 200


def test_health_json_structure(client):
    response = client.get("/health")
    data = response.get_json()
    assert data["status"] == "healthy"
    assert "uptime_seconds" in data
    assert "hostname" in data


def test_metrics_returns_200(client):
    response = client.get("/metrics")
    assert response.status_code == 200


def test_metrics_json_structure(client):
    response = client.get("/metrics")
    data = response.get_json()
    assert "uptime_seconds" in data
    assert "version" in data


def test_404_handler(client):
    response = client.get("/nonexistent-route")
    assert response.status_code == 404
    data = response.get_json()
    assert "error" in data
