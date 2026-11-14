import { requireStudent } from "@/lib/auth/session";
import { ko } from "@/lib/i18n/ko";

export default async function StudentHomePage() {
  const session = await requireStudent();
  return (
    <div className="flex flex-col gap-3">
      <h1 className="text-xl font-semibold">{ko.student.homeTitle}</h1>
      <p>{ko.student.greeting(session.displayName)}</p>
      <p className="text-sm text-muted-foreground">{ko.student.comingSoon}</p>
    </div>
  );
}
