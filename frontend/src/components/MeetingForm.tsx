import { useState, type FormEvent } from "react";
import { Button } from "./ui/button";
import type { MeetingInput } from "../types";

type MeetingFormProps = {
  onSubmit: (meeting: MeetingInput) => Promise<void>;
  isSubmitting: boolean;
};

const initialForm = {
  title: "",
  starts_at: "",
  ends_at: "",
  attendee_count: "1",
};

export function MeetingForm({ onSubmit, isSubmitting }: MeetingFormProps) {
  const [form, setForm] = useState(initialForm);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await onSubmit({
      title: form.title.trim(),
      starts_at: new Date(form.starts_at).toISOString(),
      ends_at: new Date(form.ends_at).toISOString(),
      attendee_count: Number(form.attendee_count),
    });
    setForm(initialForm);
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <label className="block text-sm font-semibold text-ink">
        Meeting title
        <input
          required
          minLength={1}
          value={form.title}
          onChange={(event) => setForm({ ...form, title: event.target.value })}
          className="mt-2 w-full rounded-xl border border-line bg-paper px-4 py-3 font-normal outline-none focus:border-moss"
          placeholder="Architecture sync"
        />
      </label>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="block text-sm font-semibold text-ink">
          Starts
          <input
            required
            type="datetime-local"
            value={form.starts_at}
            onChange={(event) =>
              setForm({ ...form, starts_at: event.target.value })
            }
            className="mt-2 w-full rounded-xl border border-line bg-paper px-4 py-3 font-normal outline-none focus:border-moss"
          />
        </label>
        <label className="block text-sm font-semibold text-ink">
          Ends
          <input
            required
            type="datetime-local"
            value={form.ends_at}
            onChange={(event) =>
              setForm({ ...form, ends_at: event.target.value })
            }
            className="mt-2 w-full rounded-xl border border-line bg-paper px-4 py-3 font-normal outline-none focus:border-moss"
          />
        </label>
      </div>
      <label className="block text-sm font-semibold text-ink">
        Attendees
        <input
          required
          min={1}
          type="number"
          value={form.attendee_count}
          onChange={(event) =>
            setForm({ ...form, attendee_count: event.target.value })
          }
          className="mt-2 w-full rounded-xl border border-line bg-paper px-4 py-3 font-normal outline-none focus:border-moss"
        />
      </label>
      <Button type="submit" disabled={isSubmitting} className="w-full">
        {isSubmitting ? "Adding meeting..." : "Add meeting"}
      </Button>
    </form>
  );
}
