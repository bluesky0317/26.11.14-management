import { requireTeacher } from "@/lib/auth/session";
import { Card, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ko } from "@/lib/i18n/ko";

export default async function TeacherDashboardPage() {
  await requireTeacher();
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold">{ko.teacher.dashboardTitle}</h1>
      <Card>
        <CardHeader>
          <CardTitle>{ko.teacher.dashboardTitle}</CardTitle>
          <CardDescription>{ko.teacher.comingSoon}</CardDescription>
        </CardHeader>
      </Card>
    </div>
  );
}
