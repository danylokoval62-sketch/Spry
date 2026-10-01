import { useEffect, useState } from "react";
import { CalendarPlus, Sparkles } from "lucide-react";
import { createMeeting, getMeetings } from "./api";
import { MeetingForm } from "./components/MeetingForm";
import { MeetingList } from "./components/MeetingList";
import type { Meeting, MeetingInput } from "./types";

export default function App() {
  const [meetings, setMeetings] = useState<Meeting[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getMeetings()
      .then(setMeetings)
      .catch(() => setError("The meeting list could not be loaded."))
      .finally(() => setIsLoading(false));
  }, []);

  async function handleCreateMeeting(meeting: MeetingInput) {
    setIsSubmitting(true);
    setError(null);
    try {
      const created = await createMeeting(meeting);
      setMeetings((current) =>
        [...current, created].sort((a, b) => a.starts_at.localeCompare(b.starts_at)),
      );
    } catch {
      setError("The meeting could not be added. Please try again.");
      throw new Error("Meeting creation failed");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="min-h-screen bg-paper text-ink">
      <div className="mx-auto max-w-6xl px-5 py-8 sm:px-8 lg:py-14">
        <header className="flex items-center justify-between border-b border-line pb-6">
          <div className="flex items-center gap-3">
            <span className="grid h-10 w-10 place-items-center rounded-full bg-coral text-paper">
              <Sparkles size={18} />
            </span>
            <span className="font-display text-2xl">spry</span>
          </div>
          <span className="text-sm text-moss">Meeting rhythm, made simple</span>
        </header>
        <section className="grid gap-12 py-14 lg:grid-cols-[1.2fr_0.8fr] lg:items-start">
          <div>
            <p className="mb-4 text-sm font-semibold uppercase tracking-[0.2em] text-coral">
              Your calendar, clarified
            </p>
            <h1 className="max-w-xl font-display text-5xl leading-[0.95] sm:text-7xl">
              Make room for good work.
            </h1>
            <p className="mt-6 max-w-lg text-lg leading-relaxed text-moss">
              Keep the team aligned with a calm, clear view of what is happening next.
            </p>
          </div>
          <div className="rounded-3xl bg-[#e6eadf] p-6 shadow-[8px_8px_0_#d8d0c2] sm:p-8">
            <div className="mb-6 flex items-center gap-3">
              <CalendarPlus className="text-coral" size={22} />
              <h2 className="font-display text-2xl">Add a meeting</h2>
            </div>
            <MeetingForm onSubmit={handleCreateMeeting} isSubmitting={isSubmitting} />
          </div>
        </section>
        <section className="border-t border-line pt-8">
          <div className="mb-5 flex items-end justify-between">
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.2em] text-coral">
                Coming up
              </p>
              <h2 className="mt-1 font-display text-3xl">The next conversations</h2>
            </div>
            <span className="text-sm text-moss">
              {meetings.length} {meetings.length === 1 ? "meeting" : "meetings"}
            </span>
          </div>
          {error && (
            <p className="mb-4 rounded-xl bg-[#f5d8d0] px-4 py-3 text-sm text-[#8b3d2b]">{error}</p>
          )}
          {isLoading ? (
            <p className="text-moss">Loading meetings...</p>
          ) : (
            <MeetingList meetings={meetings} />
          )}
        </section>
      </div>
    </main>
  );
}
