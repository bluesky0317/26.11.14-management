/**
 * 체험 모드: Supabase 환경변수가 없으면 DB 없이 샘플 데이터로 화면을 보여준다.
 * 환경변수를 설정하면 자동으로 실제 모드(로그인 + DB)로 전환된다.
 */
export function isDemoMode(): boolean {
  return !(process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
}

export const demoTeacher = {
  userId: "demo-teacher",
  email: null,
  academyId: "demo-academy",
  role: "teacher" as const,
  displayName: "김선생 (체험)",
};

export const demoStudent = {
  userId: "demo-student",
  email: null,
  academyId: "demo-academy",
  role: "student" as const,
  displayName: "이하늘",
};

export const demoDashboard = {
  attendance: { present: 12, late: 2, absent: 1, total: 15 },
  unsubmitted: [
    { title: "영어 동화 낭독", className: "초5 영어", count: 3, due: "11/16" },
    { title: "My Weekend 스피킹", className: "중1 영어", count: 5, due: "11/18" },
  ],
  reviewPending: [
    { student: "이하늘", title: "영어 동화 낭독" },
    { student: "박도윤", title: "My Weekend 스피킹" },
  ],
  aiUsage: [
    { model: "gemini-3.8-flash", used: 7, limit: 18 },
    { model: "gemini-3.5-flash-lite", used: 23, limit: 450 },
  ],
};

export const demoAssignments = [
  { title: "영어 동화 낭독", due: "11월 16일", status: "제출 전" },
  { title: "영어 자기소개 말하기", due: "11월 12일", status: "검수 대기" },
  { title: "영어 노래 따라 부르기", due: "11월 5일", status: "피드백 공개됨" },
];
