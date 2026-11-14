import { requireTeacher } from "@/lib/auth/session";
import { AppHeader } from "@/components/app-header";
import { ko } from "@/lib/i18n/ko";

export const dynamic = "force-dynamic";

export default async function TeacherLayout({ children }: { children: React.ReactNode }) {
  // 모든 선생님 화면은 서버에서 역할을 다시 확인한다(미들웨어는 로그인 여부만 확인).
  const session = await requireTeacher();
  const nav = [{ href: "/teacher/dashboard", label: ko.teacher.nav.dashboard }];
  return (
    <>
      <AppHeader displayName={session.displayName} nav={nav} />
      <main className="mx-auto max-w-5xl px-4 py-6">{children}</main>
    </>
  );
}
