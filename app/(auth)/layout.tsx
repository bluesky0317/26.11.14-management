import { redirect } from "next/navigation";
import { ko } from "@/lib/i18n/ko";
import { isDemoMode } from "@/lib/demo";

export const dynamic = "force-dynamic";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  // 체험 모드에는 로그인이 없으므로 첫 화면으로 보낸다.
  if (isDemoMode()) redirect("/");
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center px-4 py-10">
      <div className="mb-6 text-center">
        <h1 className="text-2xl font-bold">{ko.app.name}</h1>
        <p className="mt-1 text-sm text-muted-foreground">{ko.app.tagline}</p>
      </div>
      {children}
    </main>
  );
}
