import type { Meeting, MeetingInput } from "./types";

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
