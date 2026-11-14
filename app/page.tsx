import { redirect } from "next/navigation";
import { getSessionProfile } from "@/lib/auth/session";
import { homePathForRole } from "@/lib/auth/roles";
import { ConfigMissing, isSupabaseConfigured } from "@/components/config-missing";

export const dynamic = "force-dynamic";

export default async function Home() {
  if (!isSupabaseConfigured()) return <ConfigMissing />;
  const session = await getSessionProfile();
  redirect(session ? homePathForRole(session.role) : "/login");
}
