export type Meeting = {
  id: number;
  title: string;
  starts_at: string;
  ends_at: string;
  attendee_count: number;
  agenda: Agenda | null;
  ai_suggestion: AiSuggestion | null;
};

export type MeetingInput = Omit<Meeting, "id" | "agenda" | "ai_suggestion">;

export type AgendaItem = { topic: string; owner: string | null; minutes: number | null };
export type ActionItem = { task: string; owner: string | null; due: string | null };
export type Agenda = { items: AgendaItem[]; action_items: ActionItem[] };

export type ParsedAgenda = Agenda & {
  title: string | null;
  starts_at: string | null;
  duration_minutes: number | null;
  language: string;
};
export type AiSuggestion = { agenda: ParsedAgenda; model: string; prompt_version: string };
