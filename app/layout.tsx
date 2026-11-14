import type { Metadata, Viewport } from "next";
import "./globals.css";
import { ko } from "@/lib/i18n/ko";

export const metadata: Metadata = {
  title: ko.app.name,
  description: ko.app.tagline,
};

export const viewport: Viewport = { width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body className="min-h-dvh antialiased">{children}</body>
    </html>
  );
}
