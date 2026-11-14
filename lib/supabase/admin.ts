import "server-only";
import { createClient } from "@supabase/supabase-js";
import { publicEnv } from "@/lib/env";
import { serverEnv } from "@/lib/env.server";

/**
 * 서비스 롤 클라이언트: RLS 를 우회한다.
 * 반드시 서버에서 권한 검사를 끝낸 뒤에만 사용하고, 결과를 그대로 클라이언트로 넘기지 않는다.
 */
export function createAdminClient() {
  return createClient(publicEnv().NEXT_PUBLIC_SUPABASE_URL, serverEnv().SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
