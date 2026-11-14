import { Button } from "@/components/ui/button";
import { logoutAction } from "@/app/(auth)/actions";
import { ko } from "@/lib/i18n/ko";

export default function NoProfilePage() {
  return (
    <main className="mx-auto max-w-md px-4 py-16">
      <h1 className="text-xl font-semibold">{ko.auth.noProfileTitle}</h1>
      <p className="mt-3 text-sm text-muted-foreground">{ko.auth.noProfileBody}</p>
      <form action={logoutAction} className="mt-6">
        <Button variant="outline">{ko.common.logout}</Button>
      </form>
    </main>
  );
}
