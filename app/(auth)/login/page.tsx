import Link from "next/link";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { LoginForm } from "@/components/auth/login-form";
import { isTeacherSignupEnabled } from "@/lib/env";
import { ko } from "@/lib/i18n/ko";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; error?: string }>;
}) {
  const { next, error } = await searchParams;
  return (
    <Card>
      <CardHeader>
        <CardTitle>{ko.auth.loginTitle}</CardTitle>
        <CardDescription>{ko.auth.studentHint}</CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {error === "confirm" ? <p className="text-sm text-destructive">{ko.auth.confirmFailed}</p> : null}
        <LoginForm next={next} />
        {isTeacherSignupEnabled() ? (
          <p className="text-center text-sm text-muted-foreground">
            {ko.auth.noAccountTeacher}{" "}
            <Link href="/signup" className="text-primary underline-offset-4 hover:underline">
              {ko.auth.goSignup}
            </Link>
          </p>
        ) : null}
      </CardContent>
    </Card>
  );
}
