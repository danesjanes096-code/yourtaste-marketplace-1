import { Suspense } from "react";
import Link from "next/link";
import SignInForm from "./SignInForm";
export default function SignInPage() {
  return <main className="min-h-screen bg-[#fffaf5] px-5 py-10 sm:py-16"><div className="mx-auto max-w-md"><Link href="/" className="font-display text-3xl font-extrabold tracking-[-2px]">yourtaste<span className="text-[#ff6848]">.</span></Link><div className="mt-8 rounded-[28px] border border-[#eee7df] bg-white p-6 sm:p-9"><p className="text-[10px] font-bold uppercase tracking-[2px] text-[#f05f41]">WELCOME BACK</p><h1 className="mt-2 font-display text-3xl font-extrabold tracking-[-1px]">Good to see you.</h1><p className="mt-2 text-sm leading-6 text-[#786e65]">Sign in to continue to your YourTaste account.</p><Suspense fallback={<p className="mt-7 text-sm text-[#786e65]">Loading sign-in…</p>}><SignInForm /></Suspense></div><p className="mt-5 text-center text-xs text-[#9a8b7d]"><Link href="/" className="underline">Back to shopping</Link> · YourTaste marketplace preview</p></div></main>;
}
