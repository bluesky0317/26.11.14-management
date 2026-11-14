import Link from "next/link";
import { redirect } from "next/navigation";
import { getSessionProfile } from "@/lib/auth/session";
import { homePathForRole } from "@/lib/auth/roles";
import { isDemoMode } from "@/lib/demo";
import { Button } from "@/components/ui/button";
import { ko } from "@/lib/i18n/ko";

export const dynamic = "force-dynamic";

export default async function Home() {
  if (!isDemoMode()) {
    const session = await getSessionProfile();
    redirect(session ? homePathForRole(session.role) : "/login");
  }
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 px-4 py-10 text-center">
      <div>
        <h1 className="text-2xl font-bold">{ko.app.name}</h1>
        <p className="mt-1 text-sm text-muted-foreground">{ko.app.tagline}</p>
      </div>
      <p className="rounded-md bg-accent p-3 text-sm">{ko.demo.notice}</p>
      <div className="flex flex-col gap-3">
        <Button asChild size="lg">
          <Link href="/teacher/dashboard">{ko.demo.asTeacher}</Link>
        </Button>
        <Button asChild size="lg" variant="outline">
          <Link href="/student">{ko.demo.asStudent}</Link>
        </Button>
      </div>
    </main>
  );
}
