from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class MeetingBase(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    starts_at: datetime
    ends_at: datetime
    attendee_count: int = Field(ge=1)

    @field_validator("title")
    @classmethod
    def title_must_not_be_blank(cls, value: str) -> str:
        title = value.strip()
        if not title:
            raise ValueError("title must not be blank")
        return title

    @field_validator("ends_at")
    @classmethod
    def ends_after_start(cls, value: datetime, info) -> datetime:
        starts_at = info.data.get("starts_at")
        if starts_at is not None and value <= starts_at:
            raise ValueError("ends_at must be after starts_at")
        return value


class MeetingCreate(MeetingBase):
    pass


class MeetingRead(MeetingBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
