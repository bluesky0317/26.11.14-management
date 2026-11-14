import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { homePathForRole, type UserRole } from "@/lib/auth/roles";
import { demoStudent, demoTeacher, isDemoMode } from "@/lib/demo";

export type SessionProfile = {
  userId: string;
  email: string | null;
  academyId: string;
  role: UserRole;
  displayName: string;
};

/** 현재 사용자 + 프로필. 요청 단위로 캐시된다. */
export const getSessionProfile = cache(async (): Promise<SessionProfile | null> => {
  if (isDemoMode()) return null;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: profile } = await supabase
    .from("profiles")
    .select("academy_id, role, display_name")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile) return null;

  return {
    userId: user.id,
    email: user.email ?? null,
    academyId: profile.academy_id as string,
    role: profile.role as UserRole,
    displayName: profile.display_name as string,
  };
});

async function requireRole(role: UserRole): Promise<SessionProfile> {
  // 체험 모드: 로그인 없이 샘플 사용자로 화면을 보여준다.
  if (isDemoMode()) return role === "teacher" ? demoTeacher : demoStudent;
  const session = await getSessionProfile();
  if (!session) {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    redirect(user ? "/no-profile" : "/login");
  }
  if (session.role !== role) redirect(homePathForRole(session.role));
  return session;
}

export const requireTeacher = () => requireRole("teacher");
export const requireStudent = () => requireRole("student");
