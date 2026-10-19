import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createSupabaseServerClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anonKey) return null;
  const cookieStore = cookies();
  return createServerClient(url, anonKey, {
    cookies: {
      get(name: string) { return cookieStore.get(name)?.value; },
      set(name, value, options) {
        try { cookieStore.set({ name, value, ...(options as object) }); }
        catch { /* Server components cannot always write cookies. Middleware refreshes sessions. */ }
      },
      remove(name, options) {
        try { cookieStore.set({ name, value: "", ...(options as object), maxAge: 0 }); }
        catch { /* Server components cannot always write cookies. Middleware refreshes sessions. */ }
      },
    },
  });
}
