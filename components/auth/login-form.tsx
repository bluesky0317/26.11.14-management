"use client";

import { useActionState } from "react";
import { loginAction, type FormState } from "@/app/(auth)/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ko } from "@/lib/i18n/ko";

export function LoginForm({ next }: { next?: string }) {
  const [state, formAction, pending] = useActionState<FormState, FormData>(loginAction, {});
  return (
    <form action={formAction} className="flex flex-col gap-4">
      <input type="hidden" name="next" value={next ?? ""} />
      <div className="flex flex-col gap-2">
        <Label htmlFor="email">{ko.common.email}</Label>
        <Input id="email" name="email" type="email" autoComplete="email" required />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="password">{ko.common.password}</Label>
        <Input id="password" name="password" type="password" autoComplete="current-password" required />
      </div>
      {state.error ? (
        <p role="alert" className="text-sm text-destructive">
          {state.error}
        </p>
      ) : null}
      <Button type="submit" disabled={pending}>
        {pending ? ko.common.loading : ko.auth.loginButton}
      </Button>
    </form>
  );
}
