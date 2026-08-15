from uuid import UUID

from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.dependencies.auth import get_current_user_id
from app.models import User


def require_admin(
    db: Session = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
) -> User:
    """The caller, if they are an admin. 403 otherwise.

    `is_admin` lives in our `users` table, not in the Supabase token, so this
    costs one lookup — which is also what makes revoking admin take effect on
    the next request rather than on the next login.
    """
    user = db.get(User, user_id)
    if user is None or not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admins only.",
        )
    return user
