from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Meeting
from app.schemas import AgendaSave, MeetingCreate, MeetingRead

router = APIRouter(prefix="/api/meetings", tags=["meetings"])


@router.get("", response_model=list[MeetingRead])
def list_meetings(db: Session = Depends(get_db)) -> list[Meeting]:
    return list(db.scalars(select(Meeting).order_by(Meeting.starts_at)).all())


@router.post("", response_model=MeetingRead, status_code=status.HTTP_201_CREATED)
def create_meeting(payload: MeetingCreate, db: Session = Depends(get_db)) -> Meeting:
    meeting = Meeting(**payload.model_dump())
    db.add(meeting)
    db.commit()
    db.refresh(meeting)
    return meeting


@router.put("/{meeting_id}/agenda", response_model=MeetingRead)
def save_agenda(meeting_id: int, payload: AgendaSave, db: Session = Depends(get_db)) -> Meeting:
    meeting = db.get(Meeting, meeting_id)
    if meeting is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "meeting not found")
    meeting.agenda = payload.model_dump(mode="json", exclude={"ai_suggestion"})
    meeting.ai_suggestion = payload.ai_suggestion
    db.commit()
    db.refresh(meeting)
    return meeting
