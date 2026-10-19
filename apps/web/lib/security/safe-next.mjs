/** Validate an auth callback redirect as a same-origin relative path. */
export function safeNext(value, baseUrl) {
  if (!value) return "/account";
  try {
    const base = new URL(baseUrl);
    const destination = new URL(value, base);
    if (
      destination.origin !== base.origin ||
      !destination.pathname.startsWith("/") ||
      destination.pathname.startsWith("/auth")
    ) return "/account";
    return destination.pathname + destination.search + destination.hash;
  } catch {
    return "/account";
  }
}
