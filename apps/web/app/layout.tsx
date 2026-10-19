import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = { title: 'YourTaste — Discover your next favourite', description: 'Discover independent sellers and products on YourTaste.' };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en-IN"><body>{children}</body></html>;
}
