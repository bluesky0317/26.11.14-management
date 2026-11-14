"use server";

import { redirect } from "next/navigation";
import { headers } from "next/headers";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { isTeacherSignupEnabled } from "@/lib/env";
import { isDemoMode } from "@/lib/demo";
import { safeNextPath, type UserRole } from "@/lib/auth/roles";
import { ko } from "@/lib/i18n/ko";

export type FormState = { error?: string; message?: string };

const loginSchema = z.object({
  email: z.email(),
  password: z.string().min(1),
  next: z.string().optional(),
});

export async function loginAction(_prev: FormState, formData: FormData): Promise<FormState> {
  const parsed = loginSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { error: ko.auth.invalidInput };

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email: parsed.data.email,
    password: parsed.data.password,
  });
  if (error || !data.user) {
    // 내부 로그에는 코드만 남기고(이메일 등 개인정보 제외), 사용자에게는 일반 문구
    console.warn("[auth] login failed", error?.code ?? "unknown");
    return { error: ko.auth.loginFailed };
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", data.user.id)
    .maybeSingle();
  redirect(safeNextPath(parsed.data.next, (profile?.role as UserRole | undefined) ?? null));
}

const signupSchema = z.object({
  academyName: z.string().trim().min(1).max(100),
  displayName: z.string().trim().min(1).max(50),
  email: z.email(),
  password: z.string().min(8).max(72),
});

export async function teacherSignupAction(_prev: FormState, formData: FormData): Promise<FormState> {
  if (!isTeacherSignupEnabled()) return { error: ko.auth.signupDisabled };
  const parsed = signupSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { error: ko.auth.invalidInput };

  const h = await headers();
  const origin = h.get("origin") ?? `https://${h.get("host")}`;

  const supabase = await createClient();
  // 공부방/프로필 생성은 DB 트리거(handle_new_auth_user)가 같은 트랜잭션에서 처리한다.
  const { data, error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
    options: {
      emailRedirectTo: `${origin}/auth/confirm`,
      data: {
        signup_kind: "teacher",
        academy_name: parsed.data.academyName,
        display_name: parsed.data.displayName,
      },
    },
  });
  if (error) {
    console.warn("[auth] signup failed", error.code ?? "unknown");
    if (error.code === "user_already_exists") return { error: ko.auth.emailInUse };
    return { error: ko.auth.signupFailed };
  }
  // 이메일 확인이 꺼져 있으면 바로 세션이 생긴다.
  if (data.session) redirect("/teacher/dashboard");
  return { message: ko.auth.signupCheckEmail };
}

export async function logoutAction() {
  if (isDemoMode()) redirect("/");
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
