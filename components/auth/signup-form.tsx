"use client";

import { useActionState } from "react";
import { teacherSignupAction, type FormState } from "@/app/(auth)/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ko } from "@/lib/i18n/ko";

export function SignupForm() {
  const [state, formAction, pending] = useActionState<FormState, FormData>(teacherSignupAction, {});
  if (state.message) {
    return <p className="rounded-md bg-accent p-4 text-sm">{state.message}</p>;
  }
  return (
    <form action={formAction} className="flex flex-col gap-4">
      <div className="flex flex-col gap-2">
        <Label htmlFor="academyName">{ko.auth.academyName}</Label>
        <Input id="academyName" name="academyName" maxLength={100} required />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="displayName">{ko.auth.displayName}</Label>
        <Input id="displayName" name="displayName" maxLength={50} required />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="email">{ko.common.email}</Label>
        <Input id="email" name="email" type="email" autoComplete="email" required />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="password">{ko.common.password}</Label>
        <Input id="password" name="password" type="password" autoComplete="new-password" minLength={8} required />
        <p className="text-xs text-muted-foreground">{ko.auth.passwordRule}</p>
      </div>
      {state.error ? (
        <p role="alert" className="text-sm text-destructive">
          {state.error}
        </p>
      ) : null}
      <Button type="submit" disabled={pending}>
        {pending ? ko.common.loading : ko.auth.signupButton}
      </Button>
    </form>
  );
}
