import Link from "next/link";
import ResetPasswordForm from "./ResetPasswordForm";

export default function ResetPasswordPage() {
  return (
    <main className="min-h-screen bg-[#fffaf5] px-5 py-10 sm:py-16">
      <div className="mx-auto max-w-md">
        <Link href="/" className="font-display text-3xl font-extrabold tracking-[-2px]">
          yourtaste<span className="text-[#ff6848]">.</span>
        </Link>
        <section className="mt-8 rounded-[28px] border border-[#eee7df] bg-white p-6 sm:p-9">
          <p className="text-[10px] font-bold uppercase tracking-[2px] text-[#f05f41]">SECURE YOUR ACCOUNT</p>
          <h1 className="mt-2 font-display text-3xl font-extrabold tracking-[-1px]">Choose a new password.</h1>
          <p className="mt-2 text-sm leading-6 text-[#786e65]">Use a strong password you haven’t used elsewhere.</p>
          <ResetPasswordForm />
        </section>
        <p className="mt-5 text-center text-xs text-[#9a8b7d]">
          <Link href="/auth/sign-in" className="underline">Back to sign in</Link> · YourTaste marketplace preview
        </p>
      </div>
    </main>
  );
}
