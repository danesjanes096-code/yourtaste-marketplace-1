'use client';

import { FormEvent, useState } from "react";
import Link from "next/link";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";

export default function ForgotPasswordForm() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    const supabase = createSupabaseBrowserClient();
    if (!supabase) {
      setMessage("Password recovery is not configured yet. Please try again later.");
      return;
    }
    setBusy(true);
    try {
      const redirectTo = new URL("/auth/callback?next=%2Freset-password", window.location.origin).toString();
      const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo });
      if (error) throw error;
      setSent(true);
      setMessage("If an account exists for that email, a password reset link has been sent. Check your inbox.");
    } catch {
      setMessage("We couldn’t send a reset link right now. Please wait a moment and try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="mt-7 space-y-4">
      <label className="block text-sm font-semibold">
        Email address
        <input className="mt-2 w-full rounded-xl border border-[#e8dfd6] bg-white px-4 py-3 font-normal outline-none focus:border-[#ff6848]" type="email" autoComplete="email" required maxLength={254} value={email} onChange={(event) => setEmail(event.target.value)} />
      </label>
      {message && <p role="status" className="rounded-xl bg-[#f7f1eb] p-3 text-sm leading-6 text-[#786e65]">{message}</p>}
      {sent ? (
        <Link href="/auth/sign-in" className="btn-primary flex w-full justify-center">Return to sign in</Link>
      ) : (
        <button disabled={busy} className="btn-primary w-full justify-center disabled:opacity-60" type="submit">{busy ? "Sending link…" : "Send reset link"}</button>
      )}
    </form>
  );
}
