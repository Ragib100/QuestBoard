from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.supabase import supabase

security = HTTPBearer()
optional_security = HTTPBearer(auto_error=False)


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> UUID:
    token = credentials.credentials

    try:
        response = supabase.auth.get_user(token)

        if response.user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token.",
            )

        return UUID(response.user.id)

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
        )


def get_optional_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_security),
) -> UUID | None:
    """Identify the caller when a token is present, but never reject them.

    Browsing quests is public; we only need the id to show whether the viewer
    has already voted, so a missing or stale token means "anonymous", not 401.
    """
    if credentials is None:
        return None

    try:
        response = supabase.auth.get_user(credentials.credentials)
    except Exception:
        return None

    if response is None or response.user is None:
        return None

    return UUID(response.user.id)
