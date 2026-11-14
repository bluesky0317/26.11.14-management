export type UserRole = "teacher" | "student";

/** 역할별 첫 화면. 프로필이 없으면(가입 처리 전 등) 안내 페이지로. */
export function homePathForRole(role: UserRole | null | undefined): string {
  switch (role) {
    case "teacher":
      return "/teacher/dashboard";
    case "student":
      return "/student";
    default:
      return "/no-profile";
  }
}

/** 로그인 후 이동할 경로를 안전하게 결정(오픈 리다이렉트 방지: 같은 사이트 상대경로만). */
export function safeNextPath(next: string | null | undefined, role: UserRole | null | undefined): string {
  const home = homePathForRole(role);
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.includes("\\")) return home;
  // 역할에 맞지 않는 영역으로는 보내지 않는다.
  if (role === "teacher" && next.startsWith("/student")) return home;
  if (role === "student" && next.startsWith("/teacher")) return home;
  return next;
}
