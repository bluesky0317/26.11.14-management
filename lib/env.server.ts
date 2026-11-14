import "server-only";
import { z } from "zod";

const serverSchema = z.object({
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  // 32바이트 키를 base64 로 인코딩한 값 (lib/crypto 에서 길이 재검증)
  ENCRYPTION_KEY: z.string().min(1),
  CRON_SECRET: z.string().min(16).optional(),
});

export function serverEnv() {
  const parsed = serverSchema.safeParse(process.env);
  if (!parsed.success) {
    // 어떤 변수가 문제인지만 알리고 값은 절대 출력하지 않는다.
    const names = parsed.error.issues.map((i) => i.path.join(".")).join(", ");
    throw new Error(`서버 환경변수 설정 오류: ${names}`);
  }
  return parsed.data;
}
