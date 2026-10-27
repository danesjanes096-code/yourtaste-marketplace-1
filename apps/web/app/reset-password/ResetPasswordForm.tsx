'use client';

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";

export default function ResetPasswordForm() {
  const router = useRouter();
  const configured = Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
  const [ready, setReady] = useState(false);
  const [hasSession, setHasSession] = useState(false);
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState("");
  const [complete, setComplete] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const supabase = createSupabaseBrowserClient();
    if (!supabase) return;
    let active = true;
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (active) {
        setHasSession(Boolean(session));
        setReady(true);
      }
    });
    void supabase.auth.getSession().then(({ data, error }) => {
      if (!active) return;
      setHasSession(Boolean(data.session));
      if (error) setMessage("This reset link may have expired. Request a new one to continue.");
      setReady(true);
    }).catch(() => {
      if (active) {
        setMessage("This reset link may have expired. Request a new one to continue.");
        setReady(true);
      }
    });
    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    if (password !== confirmPassword) {
      setMessage("The passwords do not match.");
      return;
    }
    const supabase = createSupabaseBrowserClient();
    if (!supabase || !hasSession) {
      setMessage("This reset link is invalid or expired. Request a new one to continue.");
      return;
    }
    setBusy(true);
    try {
      const { error } = await supabase.auth.updateUser({ password });
      if (error) throw error;
      setComplete(true);
      setMessage("Your password has been updated.");
      router.replace("/account");
      router.refresh();
    } catch {
      setMessage("We couldn’t update your password. The reset link may have expired; request a new one and try again.");
    } finally {
      setBusy(false);
    }
  }

  if (!configured) return <p className="mt-7 text-sm text-[#786e65]" role="status">Password recovery is not configured yet. Please try again later.</p>;
  if (!ready) return <p className="mt-7 text-sm text-[#786e65]" role="status">Checking your reset link…</p>;
  if (!hasSession || complete) {
    return (
      <div className="mt-7 space-y-4">
        {message && <p className="rounded-xl bg-[#f7f1eb] p-3 text-sm leading-6 text-[#786e65]" role="status">{message}</p>}
        {!hasSession && <Link href="/auth/forgot-password" className="btn-primary flex w-full justify-center">Request another reset link</Link>}
        {complete && <Link href="/account" className="btn-primary flex w-full justify-center">Continue to account</Link>}
      </div>
    );
  }
  return (
    <form onSubmit={submit} className="mt-7 space-y-4">
      <label className="block text-sm font-semibold">
        New password
        <input className="mt-2 w-full rounded-xl border border-[#e8dfd6] bg-white px-4 py-3 font-normal outline-none focus:border-[#ff6848]" type="password" autoComplete="new-password" required minLength={10} maxLength={128} value={password} onChange={(event) => setPassword(event.target.value)} />
        <span className="mt-1 block text-xs font-normal text-[#9a8b7d]">Use at least 10 characters.</span>
      </label>
      <label className="block text-sm font-semibold">
        Confirm new password
        <input className="mt-2 w-full rounded-xl border border-[#e8dfd6] bg-white px-4 py-3 font-normal outline-none focus:border-[#ff6848]" type="password" autoComplete="new-password" required minLength={10} maxLength={128} value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} />
      </label>
      {message && <p className="rounded-xl bg-[#fff0eb] p-3 text-sm leading-6 text-[#9c3c25]" role="alert">{message}</p>}
      <button disabled={busy} className="btn-primary w-full justify-center disabled:opacity-60" type="submit">{busy ? "Updating password…" : "Update password"}</button>
    </form>
  );
}
