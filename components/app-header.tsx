import Link from "next/link";
import { Button } from "@/components/ui/button";
import { logoutAction } from "@/app/(auth)/actions";
import { ko } from "@/lib/i18n/ko";

export function AppHeader({
  displayName,
  nav,
}: {
  displayName: string;
  nav?: { href: string; label: string }[];
}) {
  return (
    <header className="sticky top-0 z-10 border-b bg-background/95 backdrop-blur">
      <div className="mx-auto flex max-w-5xl items-center justify-between gap-3 px-4 py-3">
        <Link href="/" className="font-semibold">
          {ko.app.name}
        </Link>
        <div className="flex items-center gap-2 text-sm">
          <span className="hidden text-muted-foreground sm:inline">{displayName}</span>
          <form action={logoutAction}>
            <Button variant="ghost" size="sm">
              {ko.common.logout}
            </Button>
          </form>
        </div>
      </div>
      {nav ? (
        <nav className="mx-auto flex max-w-5xl gap-1 overflow-x-auto px-2 pb-2 text-sm">
          {nav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="shrink-0 rounded-md px-3 py-1.5 text-muted-foreground hover:bg-accent hover:text-foreground"
            >
              {item.label}
            </Link>
          ))}
        </nav>
      ) : null}
    </header>
  );
}
