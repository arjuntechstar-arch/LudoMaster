from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.dependencies import get_current_user
from app.db.session import get_db
from app.models.social import Report
from app.models.user import User
from app.schemas.social import ReportCreate, ReportResponse

router = APIRouter(prefix="/reports", tags=["Safety & Moderation"])

VALID_CATEGORIES = {"HARASSMENT", "CHEATING", "INAPPROPRIATE_NAME", "SPAM", "OTHER"}

@router.post("", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
async def submit_report(
    payload: ReportCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if payload.reported_user_id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot report yourself.")

    cat = payload.category.upper()
    if cat not in VALID_CATEGORIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid report category. Must be one of: {', '.join(sorted(VALID_CATEGORIES))}",
        )

    report = Report(
        reporter_id=current_user.id,
        reported_user_id=payload.reported_user_id,
        category=cat,
        description=payload.description,
        match_id=payload.match_id,
        status="OPEN",
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)

    return ReportResponse(
        id=report.id,
        reported_user_id=report.reported_user_id,
        category=report.category,
        status=report.status,
        created_at=report.created_at,
    )
