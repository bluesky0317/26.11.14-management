import { requireTeacher } from "@/lib/auth/session";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { demoDashboard, isDemoMode } from "@/lib/demo";
import { ko } from "@/lib/i18n/ko";

export default async function TeacherDashboardPage() {
  await requireTeacher();
  // 실제 데이터 연동은 Phase 2. 지금은 체험 모드 샘플만 보여준다.
  if (!isDemoMode()) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>{ko.teacher.dashboardTitle}</CardTitle>
          <CardDescription>{ko.teacher.comingSoon}</CardDescription>
        </CardHeader>
      </Card>
    );
  }
  const d = demoDashboard;
  const t = ko.teacher;
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold">{t.dashboardTitle}</h1>
      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>{t.todayAttendance}</CardTitle>
          </CardHeader>
          <CardContent className="grid grid-cols-3 gap-2 text-center">
            {[
              [t.present, d.attendance.present],
              [t.late, d.attendance.late],
              [t.absent, d.attendance.absent],
            ].map(([label, value]) => (
              <div key={label} className="rounded-md bg-accent p-3">
                <div className="text-2xl font-semibold">{value}</div>
                <div className="text-xs text-muted-foreground">{label}</div>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t.aiUsageToday}</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            {d.aiUsage.map((u) => (
              <div key={u.model}>
                <div className="flex justify-between text-sm">
                  <span>{u.model}</span>
                  <span className="text-muted-foreground">
                    {u.used} / {u.limit}
                  </span>
                </div>
                <div className="mt-1 h-2 rounded-full bg-accent">
                  <div
                    className="h-2 rounded-full bg-primary"
                    style={{ width: `${Math.min(100, (u.used / u.limit) * 100)}%` }}
                  />
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t.unsubmitted}</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="flex flex-col divide-y text-sm">
              {d.unsubmitted.map((a) => (
                <li key={a.title} className="flex justify-between py-2">
                  <span>
                    {a.title} <span className="text-muted-foreground">· {a.className}</span>
                  </span>
                  <span className="text-muted-foreground">
                    {t.unsubmittedCount(a.count)} · {t.dueOn(a.due)}
                  </span>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{t.reviewPending}</CardTitle>
          </CardHeader>
          <CardContent>
            <ul className="flex flex-col divide-y text-sm">
              {d.reviewPending.map((r) => (
                <li key={r.student + r.title} className="py-2">
                  {r.student} <span className="text-muted-foreground">· {r.title}</span>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
