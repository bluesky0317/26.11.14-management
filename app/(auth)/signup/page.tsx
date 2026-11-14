import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SignupForm } from "@/components/auth/signup-form";
import { isTeacherSignupEnabled } from "@/lib/env";
import { ko } from "@/lib/i18n/ko";

export default function SignupPage() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{ko.auth.signupTitle}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {isTeacherSignupEnabled() ? <SignupForm /> : <p className="text-sm">{ko.auth.signupDisabled}</p>}
        <Link href="/login" className="text-center text-sm text-primary underline-offset-4 hover:underline">
          {ko.auth.goLogin}
        </Link>
      </CardContent>
    </Card>
  );
}
