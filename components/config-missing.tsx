import { ko } from "@/lib/i18n/ko";

export function isSupabaseConfigured() {
  return Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
}

export function ConfigMissing() {
  return (
    <main className="mx-auto max-w-md px-4 py-16">
      <h1 className="text-xl font-semibold">{ko.config.missingTitle}</h1>
      <p className="mt-3 text-sm text-muted-foreground">{ko.config.missingBody}</p>
    </main>
  );
}
