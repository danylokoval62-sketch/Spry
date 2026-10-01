import { CalendarDays, Clock3, Users } from "lucide-react";
import type { Meeting } from "../types";

function formatDate(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  }).format(new Date(value));
}

function formatTime(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(value));
}

export function MeetingList({ meetings }: { meetings: Meeting[] }) {
  if (meetings.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-line p-10 text-center text-moss">
        No meetings scheduled yet.
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {meetings.map((meeting) => (
        <article
          key={meeting.id}
          className="grid gap-4 rounded-2xl border border-line bg-white/65 p-5 sm:grid-cols-[1fr_auto] sm:items-center"
        >
          <div>
            <h3 className="font-display text-2xl text-ink">{meeting.title}</h3>
            <div className="mt-3 flex flex-wrap gap-x-5 gap-y-2 text-sm text-moss">
              <span className="inline-flex items-center gap-2">
                <CalendarDays size={16} />
                {formatDate(meeting.starts_at)}
              </span>
              <span className="inline-flex items-center gap-2">
                <Clock3 size={16} />
                {formatTime(meeting.starts_at)} - {formatTime(meeting.ends_at)}
              </span>
              <span className="inline-flex items-center gap-2">
                <Users size={16} />
                {meeting.attendee_count} attendees
              </span>
            </div>
          </div>
          <span className="justify-self-start rounded-full bg-[#e6eadf] px-3 py-1 text-xs font-semibold uppercase tracking-[0.12em] text-moss sm:justify-self-end">
            Confirmed
          </span>
        </article>
      ))}
    </div>
  );
}
