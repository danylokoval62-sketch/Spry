import csv
import io
import sys
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.database import SessionLocal
from app.models import Meeting


def week_start(week: str) -> datetime:
    """Monday 00:00 UTC of an ISO week like "2026-W40". Raises ValueError on bad input."""
    # ponytail: week bounds in UTC, switch to Europe/Kyiv if meetings near midnight matter
    return datetime.strptime(f"{week}-1", "%G-W%V-%u").replace(tzinfo=timezone.utc)


def previous_week(week: str) -> str:
    year, num, _ = (week_start(week) - timedelta(days=7)).isocalendar()
    return f"{year}-W{num:02d}"


def report_key(week: str) -> str:
    return f"reports/{week}.csv"


def hours(m: Meeting) -> float:
    return (m.ends_at - m.starts_at).total_seconds() / 3600


def meetings_in(db, week: str) -> list[Meeting]:
    start = week_start(week)
    query = select(Meeting).where(
        Meeting.starts_at >= start, Meeting.starts_at < start + timedelta(days=7)
    )
    return list(db.scalars(query))


def build_weekly_report(week: str) -> bytes:
    """Query the meetings of one ISO week (e.g. "2026-W40") and return the CSV."""
    prev = previous_week(week)
    with SessionLocal() as db:
        this, before = meetings_in(db, week), meetings_in(db, prev)

    count, prev_count = len(this), len(before)
    total, prev_total = round(sum(map(hours, this)), 2), round(sum(map(hours, before)), 2)

    out = io.StringIO()
    w = csv.writer(out)
    w.writerow(["metric", week, prev, "change"])
    w.writerow(["meetings", count, prev_count, count - prev_count])
    w.writerow(["hours", total, prev_total, round(total - prev_total, 2)])
    w.writerow([])
    w.writerow(["longest meetings"])
    w.writerow(["title", "start", "duration_hours", "participants"])
    for m in sorted(this, key=hours, reverse=True)[:5]:
        w.writerow([m.title, m.starts_at.isoformat(), round(hours(m), 2), m.attendee_count])
    return out.getvalue().encode()


if __name__ == "__main__":
    assert previous_week("2026-W01") == "2025-W52"
    assert week_start("2026-W40").date().isoformat() == "2026-09-28"
    sys.stdout.write(build_weekly_report(sys.argv[1]).decode())
