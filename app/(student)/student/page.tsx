import { requireStudent } from "@/lib/auth/session";
import { Card, CardContent } from "@/components/ui/card";
import { demoAssignments, isDemoMode } from "@/lib/demo";
import { ko } from "@/lib/i18n/ko";

export default async function StudentHomePage() {
  const session = await requireStudent();
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold">{ko.student.homeTitle}</h1>
      <p>{ko.student.greeting(session.displayName)}</p>
      {isDemoMode() ? (
        <div className="flex flex-col gap-3">
          {demoAssignments.map((a) => (
            <Card key={a.title}>
              <CardContent className="flex items-center justify-between p-4">
                <div>
                  <div className="font-medium">{a.title}</div>
                  <div className="text-xs text-muted-foreground">{ko.student.dueOn(a.due)}</div>
                </div>
                <span className="rounded-full bg-accent px-3 py-1 text-xs">{a.status}</span>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : (
        <p className="text-sm text-muted-foreground">{ko.student.comingSoon}</p>
      )}
    </div>
  );
}
