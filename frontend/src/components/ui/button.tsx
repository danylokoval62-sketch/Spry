import type { ButtonHTMLAttributes } from "react";

export function Button({
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      className={`inline-flex items-center justify-center rounded-full bg-ink px-5 py-3 text-sm font-semibold text-paper transition hover:bg-moss disabled:cursor-not-allowed disabled:opacity-50 ${className}`}
      {...props}
    />
  );
}
