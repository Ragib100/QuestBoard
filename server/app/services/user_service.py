from uuid import UUID

from sqlalchemy.orm import Session

from app.models.user import User
from app.schemas.user import UserCreate


class UserService:
    @staticmethod
    def create_user(
        db: Session,
        user_id: UUID,
        user_data: UserCreate,
    ) -> User:

        existing_user = db.query(User).filter(User.id == user_id).first()

        if existing_user:
            raise ValueError("User already exists.")

        username_exists = (
            db.query(User).filter(User.username == user_data.username).first()
        )

        if username_exists:
            raise ValueError("Username is already taken.")

        user = User(
            id=user_id,
            username=user_data.username,
            first_name=user_data.first_name,
            last_name=user_data.last_name,
            phone_number=user_data.phone_number,
            image_url=user_data.image_url,
            codeforces_handle=user_data.codeforces_handle,
        )

        print(f"Creating user: {user}")

        db.add(user)
        db.commit()
        db.refresh(user)

        return user
