import type { Agenda, AiSuggestion, Meeting, MeetingInput } from "./types";

const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000";

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const response = await fetch(`${API_URL}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });

  if (!response.ok) {
    throw new Error(`Request failed with status ${response.status}`);
  }

  return response.json() as Promise<T>;
}

export function getMeetings(): Promise<Meeting[]> {
  return request<Meeting[]>("/api/meetings");
}

export function createMeeting(meeting: MeetingInput): Promise<Meeting> {
  return request<Meeting>("/api/meetings", {
    method: "POST",
    body: JSON.stringify(meeting),
  });
}

export function saveAgenda(
  meetingId: number,
  agenda: Agenda,
  suggestion: AiSuggestion | null,
): Promise<Meeting> {
  return request<Meeting>(`/api/meetings/${meetingId}/agenda`, {
    method: "PUT",
    body: JSON.stringify({ ...agenda, ai_suggestion: suggestion }),
  });
}

const PARSER_URL = import.meta.env.VITE_PARSER_URL;

export class ParseError extends Error {}

const PARSE_ERRORS: Record<number, string> = {
  401: "Sign in to parse an agenda.",
  413: "The text is too long (10,000 characters at most).",
  422: "The model could not find an agenda in this text. Type it by hand below.",
  429: "The service is busy. Try again in a moment.",
  502: "The parser is unavailable. Type the agenda by hand below.",
};

// The parser only suggests. Saving goes through saveAgenda, i.e. the main API.
export async function parseAgenda(
  text: string,
  idToken: string,
  signal: AbortSignal,
): Promise<AiSuggestion> {
  let response: Response;
  try {
    response = await fetch(PARSER_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${idToken}` },
      body: JSON.stringify({
        text,
        today: new Date().toLocaleDateString("sv"), // YYYY-MM-DD in the user's time zone
        tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
      }),
      signal,
    });
  } catch (e) {
    if (signal.aborted) throw e;
    throw new ParseError("The network failed. Type the agenda by hand below.");
  }
  if (!response.ok) {
    throw new ParseError(PARSE_ERRORS[response.status] ?? "The text could not be parsed.");
  }
  const body = await response.json();
  return { agenda: body.agenda, model: body.model, prompt_version: body.prompt_version };
}
