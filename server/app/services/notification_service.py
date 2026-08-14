from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.models import Notification


class NotificationService:
    """In-app notifications.

    Deliberately quiet: only events the recipient would want to act on get a
    row. Votes are excluded — they arrive constantly and would bury the
    notifications that matter. The `vote_received` type exists in the schema for
    a future digest, not for one row per vote.

    Like PointService, `create` does not commit; it joins whatever transaction
    the caller already has open so a notification can never outlive the event
    that caused it.
    """

    @staticmethod
    def create(
        db: Session,
        user_id: UUID,
        notification_type: str,
        message: str,
        reference_id: UUID | None = None,
    ) -> Notification:
        notification = Notification(
            user_id=user_id,
            type=notification_type,
            message=message,
            reference_id=reference_id,
        )
        db.add(notification)
        return notification

    @staticmethod
    def list_for(
        db: Session, user_id: UUID, page: int = 1, limit: int = 30
    ) -> tuple[list[Notification], int]:
        stmt = (
            select(Notification)
            .where(Notification.user_id == user_id)
            .order_by(Notification.created_at.desc())
            .offset((page - 1) * limit)
            .limit(limit)
        )
        items = list(db.scalars(stmt).all())
        unread = db.scalar(
            select(Notification.id)
            .where(Notification.user_id == user_id, Notification.is_read.is_(False))
            .with_only_columns(Notification.id)
        )
        return items, unread

    @staticmethod
    def unread_count(db: Session, user_id: UUID) -> int:
        from sqlalchemy import func

        return int(
            db.scalar(
                select(func.count(Notification.id)).where(
                    Notification.user_id == user_id,
                    Notification.is_read.is_(False),
                )
            )
            or 0
        )

    @staticmethod
    def mark_read(db: Session, notification_id: UUID, user_id: UUID) -> Notification:
        notification = db.get(Notification, notification_id)

        if notification is None:
            raise LookupError("That notification does not exist.")

        if notification.user_id != user_id:
            raise PermissionError("That notification is not yours.")

        notification.is_read = True
        db.commit()
        db.refresh(notification)
        return notification

    @staticmethod
    def mark_all_read(db: Session, user_id: UUID) -> int:
        result = db.execute(
            update(Notification)
            .where(Notification.user_id == user_id, Notification.is_read.is_(False))
            .values(is_read=True)
        )
        db.commit()
        return int(result.rowcount or 0)
