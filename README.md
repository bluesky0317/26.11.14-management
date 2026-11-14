# 공부방 매니저

소규모 공부방용 관리 웹앱. 출결·과제 관리 + 학생 과제 영상에 대한 Gemini AI 1차 피드백(선생님 검수 후 공개).

> 현재 진행 상태: **Phase 1** (프로젝트 셋업, DB 스키마/RLS, 인증, 역할 분기). 나머지 기능은 Phase 2~5에서 추가됩니다.

## 기술 스택
Next.js 15 (App Router) · TypeScript strict · Tailwind CSS v4 + shadcn/ui · Supabase (Auth/Postgres/Storage/RLS) · zod · Vitest · Playwright

## 1. Supabase 준비
1. [supabase.com](https://supabase.com)에서 프로젝트 생성
2. **SQL Editor**에서 `supabase/migrations/` 의 파일을 **이름 순서대로** 실행
   - `…0001_schema.sql` → `…0002_rls.sql` → `…0003_storage.sql`
   - (Supabase CLI 사용 시: `supabase link` 후 `supabase db push`)
3. **Authentication → URL Configuration**
   - Site URL: 배포 주소 (예: `https://your-site.netlify.app`)
   - Redirect URLs: `https://your-site.netlify.app/auth/confirm`
4. **Authentication → Email Templates → Confirm signup** 의 링크를 다음으로 변경
   ```
   {{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=email
   ```
5. 선생님 가입을 마친 뒤 외부 가입을 막으려면 **Authentication → Sign In / Providers → Allow new users to sign up** 를 끄고 `TEACHER_SIGNUP_ENABLED=false` 로 설정 (학생 계정은 서버가 관리자 API로 생성하므로 영향 없음)

## 2. 환경변수
`.env.example` 참고. 로컬은 `.env.local`, Netlify는 **Site configuration → Environment variables** 에 입력.

| 이름 | 설명 |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase Project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | anon public 키 |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role 키 (**서버 전용, 절대 공개 금지**) |
| `ENCRYPTION_KEY` | `openssl rand -base64 32` 결과 (Gemini 키 암호화용, Phase 3) |
| `TEACHER_SIGNUP_ENABLED` | `true`/`false` |
| `CRON_SECRET` | `openssl rand -hex 32` (분석 워커 보호용, Phase 4) |

`NEXT_PUBLIC_*` 값은 **빌드 시점에** 번들에 들어가므로, 값을 바꾸면 재배포(Clear cache and deploy)해야 합니다.
Gemini API 키는 환경변수에 두지 않습니다. 선생님이 앱 설정 화면에서 입력합니다(Phase 3).

## 3. Netlify 배포
1. Netlify → **Add new site → Import an existing project → GitHub** 에서 이 저장소 선택
2. Branch: 배포할 브랜치 선택, Build command `npm run build`, Publish directory `.next` (`netlify.toml` 에 설정되어 있음)
3. 위 환경변수 입력 후 **Deploy**
4. 배포 주소를 Supabase의 Site URL / Redirect URLs 에 등록 (1-3 단계)

Next.js 런타임은 Netlify가 자동으로 적용합니다(별도 플러그인 설치 불필요).

## 4. 로컬 개발
```bash
npm install
cp .env.example .env.local   # 값 채우기
npm run dev
```

## 테스트
```bash
npm test          # 단위 테스트 (Vitest)
npm run test:db   # 로컬 임시 Postgres에 마이그레이션 적용 + RLS/테넌트 격리 테스트 (PostgreSQL 16 서버 바이너리 필요)
npm run typecheck
```

## 구조
```
app/(auth)/        로그인, 선생님 가입
app/(teacher)/     선생님 화면 (/teacher/...)
app/(student)/     학생 화면 (/student/...)
lib/supabase/      브라우저/서버/서비스 롤 클라이언트, 세션 미들웨어
lib/auth/          역할 판별, 접근 가드
lib/i18n/ko.ts     모든 UI 문구
supabase/migrations/  스키마, RLS, Storage
docs/gemini-api-notes.md  Gemini API 공식 문서 확인 결과 (Phase 3~4 구현 근거)
```
