import Link from "next/link";
import ForgotPasswordForm from "./ForgotPasswordForm";

export default function ForgotPasswordPage() {
  return (
    <main className="min-h-screen bg-[#fffaf5] px-5 py-10 sm:py-16">
      <div className="mx-auto max-w-md">
        <Link href="/" className="font-display text-3xl font-extrabold tracking-[-2px]">
          yourtaste<span className="text-[#ff6848]">.</span>
        </Link>
        <section className="mt-8 rounded-[28px] border border-[#eee7df] bg-white p-6 sm:p-9">
          <p className="text-[10px] font-bold uppercase tracking-[2px] text-[#f05f41]">ACCOUNT RECOVERY</p>
          <h1 className="mt-2 font-display text-3xl font-extrabold tracking-[-1px]">Let’s get you back in.</h1>
          <p className="mt-2 text-sm leading-6 text-[#786e65]">Enter the email address for your YourTaste account. If an account exists, we’ll send a reset link.</p>
          <ForgotPasswordForm />
        </section>
        <p className="mt-5 text-center text-xs text-[#9a8b7d]">
          <Link href="/auth/sign-in" className="underline">Back to sign in</Link> · YourTaste marketplace preview
        </p>
      </div>
    </main>
  );
}
