def test_temp_endpoint(client):

    response = client.post("/api/temp_test", json={"name": "Hello CI"})

    assert response.status_code == 200

    body = response.json()

    assert body["id"] > 0
    assert body["name"] == "Hello CI"
