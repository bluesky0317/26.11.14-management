import { z } from "zod";

/**
 * 환경변수 검증. 빌드 시점에 값이 없어도 import 만으로 실패하지 않도록 지연 평가한다.
 * NEXT_PUBLIC_ 값은 브라우저 번들에 인라인되므로 process.env.X 형태로 직접 참조해야 한다.
 */
const publicSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
});

export function publicEnv() {
  return publicSchema.parse({
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  });
}

export function isTeacherSignupEnabled(): boolean {
  return (process.env.TEACHER_SIGNUP_ENABLED ?? "true").toLowerCase() === "true";
}
