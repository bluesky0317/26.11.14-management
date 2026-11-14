import { requireStudent } from "@/lib/auth/session";
import { AppHeader } from "@/components/app-header";

export const dynamic = "force-dynamic";

export default async function StudentLayout({ children }: { children: React.ReactNode }) {
  const session = await requireStudent();
  return (
    <>
      <AppHeader displayName={session.displayName} />
      <main className="mx-auto max-w-2xl px-4 py-6">{children}</main>
    </>
  );
}
