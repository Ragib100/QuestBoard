def test_temp_endpoint(client):

    response = client.post("/api/temp_test", json={"name": "Hello CI"})

    assert response.status_code == 200

    body = response.json()
    row_id = body["id"]

    assert row_id > 0
    assert body["name"] == "Hello CI"

    # Cleanup so repeated runs don't accumulate rows in the DB
    from sqlalchemy import delete
    from app.db.database import SessionLocal
    from app.db.models import TempTest

    with SessionLocal() as db:
        db.execute(delete(TempTest).where(TempTest.id == row_id))
        db.commit()
