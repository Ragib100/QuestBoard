from uuid import UUID

from sqlalchemy.orm import Session

from app.models import PointTransaction, User
from app.schemas.user import UserCreate, UserUpdate


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

        try:
            db.add(user)
            db.commit()
            db.refresh(user)
        except Exception:
            db.rollback()
            raise

        return user

    @staticmethod
    def get(db: Session, user_id: UUID) -> User:
        user = db.get(User, user_id)

        if user is None:
            raise LookupError("That profile does not exist.")

        return user

    @staticmethod
    def update(db: Session, user_id: UUID, user_data: UserUpdate) -> User:
        user = UserService.get(db=db, user_id=user_id)

        updates = user_data.model_dump(exclude_unset=True)

        # Verification is earned by proving handle ownership, never claimed by
        # the client — drop it if a caller tries to set it directly.
        updates.pop("codeforces_verified", None)

        new_username = updates.get("username")
        if new_username and new_username != user.username:
            taken = (
                db.query(User)
                .filter(User.username == new_username, User.id != user_id)
                .first()
            )
            if taken:
                raise ValueError("Username is already taken.")

        # Changing the handle invalidates any previous verification.
        if "codeforces_handle" in updates:
            if updates["codeforces_handle"] != user.codeforces_handle:
                user.codeforces_verified = False

        for field, value in updates.items():
            setattr(user, field, value)

        try:
            db.commit()
            db.refresh(user)
        except Exception:
            db.rollback()
            raise

        return user

    @staticmethod
    def points(db: Session, user_id: UUID, limit: int = 50) -> dict:
        user = UserService.get(db=db, user_id=user_id)

        transactions = (
            db.query(PointTransaction)
            .filter(PointTransaction.user_id == user_id)
            .order_by(PointTransaction.created_at.desc())
            .limit(limit)
            .all()
        )

        return {"balance": user.points, "transactions": transactions}
