import { describe, expect, it } from "vitest";
import { homePathForRole, safeNextPath } from "@/lib/auth/roles";

describe("homePathForRole", () => {
  it("역할별 첫 화면", () => {
    expect(homePathForRole("teacher")).toBe("/teacher/dashboard");
    expect(homePathForRole("student")).toBe("/student");
    expect(homePathForRole(null)).toBe("/no-profile");
  });
});

describe("safeNextPath", () => {
  it("외부/프로토콜 상대 URL 은 거부", () => {
    expect(safeNextPath("https://evil.example", "teacher")).toBe("/teacher/dashboard");
    expect(safeNextPath("//evil.example", "teacher")).toBe("/teacher/dashboard");
    expect(safeNextPath("/\\evil.example", "student")).toBe("/student");
  });
  it("역할에 맞지 않는 영역은 홈으로", () => {
    expect(safeNextPath("/teacher/settings", "student")).toBe("/student");
    expect(safeNextPath("/student", "teacher")).toBe("/teacher/dashboard");
  });
  it("정상 경로는 유지", () => {
    expect(safeNextPath("/teacher/classes", "teacher")).toBe("/teacher/classes");
  });
});
