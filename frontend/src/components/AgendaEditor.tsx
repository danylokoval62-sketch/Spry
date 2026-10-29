import { useRef, useState } from "react";
import { useAuth } from "react-oidc-context";
import { parseAgenda, saveAgenda } from "../api";
import { Button } from "./ui/button";
import type { AiSuggestion, Meeting } from "../types";

// A row of text inputs. `suggested` lists the fields the model filled and the user has not touched.
type Row = Record<string, string> & { suggested: string };

const input =
  "w-full rounded-lg border border-line bg-paper px-3 py-2 text-sm font-normal outline-none focus:border-moss";

const itemRow = (r: Partial<Record<string, string | number | null>>, s: boolean): Row => ({
  topic: r.topic?.toString() ?? "",
  owner: r.owner?.toString() ?? "",
  minutes: r.minutes?.toString() ?? "",
  suggested: s ? "topic owner minutes" : "",
});
const actionRow = (r: Partial<Record<string, string | null>>, s: boolean): Row => ({
  task: r.task ?? "",
  owner: r.owner ?? "",
  due: r.due ?? "",
  suggested: s ? "task owner due" : "",
});

function Field({
  row,
  name,
  onChange,
  ...props
}: {
  row: Row;
  name: string;
  onChange: (value: string) => void;
} & Omit<React.InputHTMLAttributes<HTMLInputElement>, "onChange" | "name">) {
  const filled = row.suggested.split(" ").includes(name) && row[name] !== "";
  return (
    <label className="relative block">
      {filled && (
        <span className="absolute -top-2 right-2 rounded-full bg-coral px-2 text-[10px] font-semibold text-paper">
          suggested
        </span>
      )}
      <input
        {...props}
        value={row[name]}
        onChange={(e) => onChange(e.target.value)}
        className={input}
      />
    </label>
  );
}

export function AgendaEditor({
  meeting,
  onSaved,
}: {
  meeting: Meeting;
  onSaved: (m: Meeting) => void;
}) {
  const auth = useAuth();
  const abort = useRef<AbortController | null>(null);
  const [text, setText] = useState("");
  const [parsing, setParsing] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [suggestion, setSuggestion] = useState<AiSuggestion | null>(meeting.ai_suggestion);
  const [items, setItems] = useState<Row[]>(
    meeting.agenda?.items.map((i) => itemRow(i, false)) ?? [itemRow({}, false)],
  );
  const [actions, setActions] = useState<Row[]>(
    meeting.agenda?.action_items.map((a) => actionRow(a, false)) ?? [],
  );

  async function parse() {
    const token = auth.user?.id_token;
    if (!token) return setMessage("Sign in to parse an agenda.");
    abort.current = new AbortController();
    setParsing(true);
    setMessage(null);
    try {
      const s = await parseAgenda(text, token, abort.current.signal);
      setSuggestion(s);
      setItems(s.agenda.items.map((i) => itemRow(i, true)));
      setActions(s.agenda.action_items.map((a) => actionRow(a, true)));
      if (s.agenda.items.length === 0) setMessage("No agenda found in this text.");
    } catch (e) {
      if (!abort.current.signal.aborted) {
        setMessage(e instanceof Error ? e.message : "The text could not be parsed.");
      }
    } finally {
      setParsing(false);
    }
  }

  const edit = (rows: Row[], set: (r: Row[]) => void, i: number, name: string) => (v: string) =>
    set(
      rows.map((r, j) =>
        j !== i ? r : { ...r, [name]: v, suggested: r.suggested.replace(name, "").trim() },
      ),
    );

  async function save(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    setMessage(null);
    try {
      const saved = await saveAgenda(
        meeting.id,
        {
          items: items.map((r) => ({
            topic: r.topic.trim(),
            owner: r.owner.trim() || null,
            minutes: r.minutes ? Number(r.minutes) : null,
          })),
          action_items: actions.map((r) => ({
            task: r.task.trim(),
            owner: r.owner.trim() || null,
            due: r.due || null,
          })),
        },
        suggestion,
      );
      onSaved(saved);
      setMessage("Agenda saved.");
    } catch {
      setMessage("The agenda could not be saved. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="mt-4 space-y-4 border-t border-line pt-4">
      <div>
        <label className="block text-sm font-semibold">
          Paste an agenda
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            rows={4}
            maxLength={10000}
            placeholder="Пн 10:00, синк по прайсингу, 45 хв. 1) нові тарифи Pro — Олена, 15 хв ..."
            className={`${input} mt-2`}
          />
        </label>
        <div className="mt-2 flex items-center gap-3">
          <Button type="button" onClick={() => void parse()} disabled={parsing || !text.trim()}>
            {parsing ? "Reading the text (2-8 s)..." : "Parse"}
          </Button>
          {parsing && (
            <Button type="button" onClick={() => abort.current?.abort()} className="bg-moss">
              Cancel
            </Button>
          )}
        </div>
      </div>

      <form onSubmit={save} className="space-y-3">
        <p className="text-sm font-semibold">Agenda</p>
        {items.map((r, i) => (
          <div key={i} className="grid gap-2 sm:grid-cols-[1fr_9rem_5rem_auto]">
            <Field
              row={r}
              name="topic"
              required
              placeholder="Topic"
              onChange={edit(items, setItems, i, "topic")}
            />
            <Field
              row={r}
              name="owner"
              placeholder="Owner"
              onChange={edit(items, setItems, i, "owner")}
            />
            <Field
              row={r}
              name="minutes"
              type="number"
              min={1}
              max={480}
              placeholder="min"
              onChange={edit(items, setItems, i, "minutes")}
            />
            <button
              type="button"
              aria-label="Remove item"
              className="text-moss"
              onClick={() => setItems(items.filter((_, j) => j !== i))}
            >
              ✕
            </button>
          </div>
        ))}
        <button
          type="button"
          className="text-sm text-moss underline"
          onClick={() => setItems([...items, itemRow({}, false)])}
        >
          + item
        </button>

        <p className="pt-2 text-sm font-semibold">Action items</p>
        {actions.map((r, i) => (
          <div key={i} className="grid gap-2 sm:grid-cols-[1fr_9rem_9rem_auto]">
            <Field
              row={r}
              name="task"
              required
              placeholder="Task"
              onChange={edit(actions, setActions, i, "task")}
            />
            <Field
              row={r}
              name="owner"
              placeholder="Owner"
              onChange={edit(actions, setActions, i, "owner")}
            />
            <Field row={r} name="due" type="date" onChange={edit(actions, setActions, i, "due")} />
            <button
              type="button"
              aria-label="Remove action"
              className="text-moss"
              onClick={() => setActions(actions.filter((_, j) => j !== i))}
            >
              ✕
            </button>
          </div>
        ))}
        <button
          type="button"
          className="block text-sm text-moss underline"
          onClick={() => setActions([...actions, actionRow({}, false)])}
        >
          + action item
        </button>

        <div className="flex items-center gap-3 pt-2">
          <Button type="submit" disabled={saving || items.length === 0}>
            {saving ? "Saving..." : "Save agenda"}
          </Button>
          {message && <span className="text-sm text-moss">{message}</span>}
        </div>
      </form>
    </div>
  );
}
