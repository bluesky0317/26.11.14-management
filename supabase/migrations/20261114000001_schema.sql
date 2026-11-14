-- =====================================================================
-- 공부방 관리 앱: 기본 스키마
-- 모든 업무 테이블은 academy_id 를 가지며, RLS 는 다음 마이그레이션에서 정의한다.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Enum 타입
-- ---------------------------------------------------------------------
create type public.user_role as enum ('teacher', 'student');
create type public.attendance_status as enum ('present', 'late', 'absent');
-- 제출 상태: 업로드됨 → 분석 대기 → 분석 중 → 검수 대기 → 공개됨 / 실패
create type public.submission_status as enum
  ('uploaded', 'queued', 'analyzing', 'review_pending', 'published', 'failed');
create type public.feedback_source as enum ('ai', 'manual');
create type public.ai_model_id as enum ('gemini-3.8-flash', 'gemini-3.5-flash-lite');
create type public.ai_call_kind as enum ('key_validation', 'analysis');
create type public.ai_usage_status as enum ('reserved', 'committed', 'released', 'failed');
-- 분석 작업 단계: 서버리스 시간 제한 때문에 단계별로 끊어서 다음 cron 에서 이어 처리한다.
create type public.analysis_job_status as enum
  ('pending', 'file_processing', 'generating', 'done', 'failed', 'waiting_quota');

-- ---------------------------------------------------------------------
-- 공부방 / 사용자
-- ---------------------------------------------------------------------
create table public.academies (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 100),
  created_at  timestamptz not null default now()
);

-- auth.users 와 1:1. role 과 academy_id 는 서버(서비스 롤)만 바꿀 수 있다.
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  academy_id    uuid not null references public.academies (id) on delete cascade,
  role          public.user_role not null,
  display_name  text not null check (char_length(display_name) between 1 and 50),
  created_at    timestamptz not null default now(),
  unique (id, academy_id)
);
create index profiles_academy_idx on public.profiles (academy_id);

-- ---------------------------------------------------------------------
-- 반 / 학생
-- ---------------------------------------------------------------------
create table public.classes (
  id           uuid primary key default gen_random_uuid(),
  academy_id   uuid not null references public.academies (id) on delete cascade,
  name         text not null check (char_length(name) between 1 and 50),
  description  text check (char_length(description) <= 500),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (academy_id, name),
  unique (id, academy_id)
);

-- 학생 정보. 로그인 계정(profile_id)은 선택: 계정 없이 출결만 관리하는 학생도 허용.
create table public.students (
  id                uuid primary key default gen_random_uuid(),
  academy_id        uuid not null references public.academies (id) on delete cascade,
  profile_id        uuid unique,
  class_id          uuid,
  name              text not null check (char_length(name) between 1 and 50),
  grade             text check (char_length(grade) <= 20),
  guardian_contact  text check (char_length(guardian_contact) <= 100),
  memo              text check (char_length(memo) <= 2000),
  -- AI 영상 분석 동의. false 이면 AI 분석 불가, 선생님 수동 피드백만 허용.
  ai_consent        boolean not null default false,
  ai_consent_at     timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (id, academy_id),
  -- 복합 FK: 다른 공부방의 반/계정과 연결하는 것을 DB 차원에서 차단(테넌트 격리)
  foreign key (class_id, academy_id) references public.classes (id, academy_id)
    on delete set null (class_id),
  foreign key (profile_id, academy_id) references public.profiles (id, academy_id)
    on delete set null (profile_id)
);
create index students_academy_idx on public.students (academy_id);
create index students_class_idx on public.students (class_id);

-- ---------------------------------------------------------------------
-- 출결
-- ---------------------------------------------------------------------
create table public.attendance (
  id          uuid primary key default gen_random_uuid(),
  academy_id  uuid not null references public.academies (id) on delete cascade,
  student_id  uuid not null,
  date        date not null,
  status      public.attendance_status not null,
  note        text check (char_length(note) <= 200),
  updated_at  timestamptz not null default now(),
  unique (student_id, date),
  foreign key (student_id, academy_id) references public.students (id, academy_id) on delete cascade
);
create index attendance_academy_date_idx on public.attendance (academy_id, date);

-- ---------------------------------------------------------------------
-- 과제 / 제출 / 피드백
-- ---------------------------------------------------------------------
create table public.assignments (
  id           uuid primary key default gen_random_uuid(),
  academy_id   uuid not null references public.academies (id) on delete cascade,
  class_id     uuid not null,
  title        text not null check (char_length(title) between 1 and 100),
  description  text not null default '' check (char_length(description) <= 5000),
  rubric       text not null default '' check (char_length(rubric) <= 5000),
  due_at       timestamptz,
  created_by   uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (id, academy_id),
  foreign key (class_id, academy_id) references public.classes (id, academy_id) on delete cascade
);
create index assignments_academy_idx on public.assignments (academy_id);
create index assignments_class_idx on public.assignments (class_id);

-- 과제별 학생당 영상 1개.
create table public.submissions (
  id                uuid primary key default gen_random_uuid(),
  academy_id        uuid not null references public.academies (id) on delete cascade,
  assignment_id     uuid not null,
  student_id        uuid not null,
  storage_path      text,
  mime_type         text check (mime_type in ('video/mp4', 'video/quicktime', 'video/webm')),
  size_bytes        bigint check (size_bytes > 0),
  duration_sec      numeric(8, 2) check (duration_sec > 0),
  status            public.submission_status not null default 'uploaded',
  -- 사용자에게 보여줄 수 있는 실패 사유(내부 상세 로그는 analysis_jobs.last_error_internal)
  status_message    text,
  uploaded_at       timestamptz,
  video_deleted_at  timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (assignment_id, student_id),
  unique (id, academy_id),
  foreign key (assignment_id, academy_id) references public.assignments (id, academy_id) on delete cascade,
  foreign key (student_id, academy_id) references public.students (id, academy_id) on delete cascade
);
create index submissions_academy_status_idx on public.submissions (academy_id, status);
create index submissions_student_idx on public.submissions (student_id);

-- 선생님 전용 작업 공간: AI 원본 + 수정본. 학생은 이 테이블을 절대 볼 수 없다.
create table public.feedback_drafts (
  submission_id    uuid primary key,
  academy_id       uuid not null references public.academies (id) on delete cascade,
  source           public.feedback_source not null,
  ai_original      jsonb,             -- AI 가 생성한 원본(수정 금지, 보관용)
  ai_model         public.ai_model_id,
  edited           jsonb,             -- 선생님이 수정한 본문(AiFeedback 형태)
  teacher_comment  text check (char_length(teacher_comment) <= 5000),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  foreign key (submission_id, academy_id) references public.submissions (id, academy_id) on delete cascade
);

-- 학생에게 공개된 피드백. "공개" 시점에 draft 에서 복사된다.
-- 테이블을 분리한 이유: RLS 는 행 단위라 같은 행의 ai_original 컬럼만 숨기기 어렵다.
create table public.published_feedback (
  submission_id    uuid primary key,
  academy_id       uuid not null references public.academies (id) on delete cascade,
  student_id       uuid not null,
  content          jsonb,
  teacher_comment  text,
  published_by     uuid references public.profiles (id) on delete set null,
  published_at     timestamptz not null default now(),
  foreign key (submission_id, academy_id) references public.submissions (id, academy_id) on delete cascade,
  foreign key (student_id, academy_id) references public.students (id, academy_id) on delete cascade
);
create index published_feedback_student_idx on public.published_feedback (student_id);

-- ---------------------------------------------------------------------
-- 설정
-- ---------------------------------------------------------------------
create table public.academy_settings (
  academy_id             uuid primary key references public.academies (id) on delete cascade,
  max_upload_mb          integer not null default 200 check (max_upload_mb between 1 and 2000),
  max_duration_sec       integer not null default 300 check (max_duration_sec between 10 and 3600),
  video_retention_days   integer not null default 30 check (video_retention_days between 1 and 365),
  -- 실제 한도의 몇 %까지만 쓸지. 0.9 = 90%.
  quota_safety_margin    numeric(3, 2) not null default 0.90 check (quota_safety_margin > 0 and quota_safety_margin <= 1),
  -- 영상 1초당 입력 토큰 추정치 (문서상 low 해상도 기준 약 100 tokens/s)
  tokens_per_video_sec   integer not null default 100 check (tokens_per_video_sec between 1 and 2000),
  always_use_flash_lite  boolean not null default false,
  updated_at             timestamptz not null default now()
);

-- 모델별 무료 한도(선생님이 AI Studio 에서 확인 후 수정).
create table public.ai_model_limits (
  academy_id  uuid not null references public.academies (id) on delete cascade,
  model       public.ai_model_id not null,
  rpm         integer not null check (rpm >= 0),
  tpm         integer not null check (tpm >= 0),
  rpd         integer not null check (rpd >= 0),
  updated_at  timestamptz not null default now(),
  primary key (academy_id, model)
);

-- Gemini API 키(AES-256-GCM 암호문). 어떤 사용자 역할로도 SELECT 불가, 서비스 롤 전용.
create table public.academy_api_keys (
  academy_id   uuid primary key references public.academies (id) on delete cascade,
  ciphertext   text not null,   -- base64
  iv           text not null,   -- base64, 12 bytes
  auth_tag     text not null,   -- base64, 16 bytes
  key_version  smallint not null default 1,
  masked       text not null,   -- 예: AIza••••1234 (화면 표시용)
  updated_by   uuid references public.profiles (id) on delete set null,
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- AI 사용량 / 작업 큐 (QuotaGuard, 워커에서 사용)
-- ---------------------------------------------------------------------
-- 호출 1건 = 1행. 예약(reserved) 시점에 RPM/RPD 를 선점하고, 응답 후 실제 토큰으로 commit.
create table public.ai_usage_events (
  id                      uuid primary key default gen_random_uuid(),
  academy_id              uuid not null references public.academies (id) on delete cascade,
  model                   public.ai_model_id not null,
  kind                    public.ai_call_kind not null,
  status                  public.ai_usage_status not null default 'reserved',
  -- RPD 집계 기준일: America/Los_Angeles 날짜
  la_date                 date not null,
  reserved_at             timestamptz not null default now(),
  finished_at             timestamptz,
  estimated_input_tokens  integer not null check (estimated_input_tokens >= 0),
  actual_input_tokens     integer,
  actual_output_tokens    integer,
  video_duration_sec      numeric(8, 2),
  submission_id           uuid references public.submissions (id) on delete set null,
  error_code              text
);
create index ai_usage_events_window_idx on public.ai_usage_events (academy_id, model, reserved_at);
create index ai_usage_events_day_idx on public.ai_usage_events (academy_id, model, la_date);

-- 429(일일 한도) 를 받은 모델을 해당 LA 날짜 동안 소진 처리.
create table public.ai_model_exhaustion (
  academy_id  uuid not null references public.academies (id) on delete cascade,
  model       public.ai_model_id not null,
  la_date     date not null,
  reason      text,
  created_at  timestamptz not null default now(),
  primary key (academy_id, model, la_date)
);

-- 분석 작업 큐. cron 이 한 번에 몇 건씩 가져가 단계별로 진행한다.
create table public.analysis_jobs (
  id                   uuid primary key default gen_random_uuid(),
  academy_id           uuid not null references public.academies (id) on delete cascade,
  submission_id        uuid not null,
  status               public.analysis_job_status not null default 'pending',
  model                public.ai_model_id,
  usage_event_id       uuid references public.ai_usage_events (id) on delete set null,
  gemini_file_name     text,          -- 예: files/abc123 (finally 에서 삭제)
  gemini_file_uri      text,
  gemini_mime_type     text,
  attempts             integer not null default 0,
  next_run_at          timestamptz not null default now(),
  locked_until         timestamptz,   -- 동시에 두 워커가 같은 작업을 잡지 않도록
  last_error_internal  text,          -- 내부 로그용(사용자에게 노출 금지, 키 포함 금지)
  requested_by         uuid references public.profiles (id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  foreign key (submission_id, academy_id) references public.submissions (id, academy_id) on delete cascade
);
create index analysis_jobs_ready_idx on public.analysis_jobs (status, next_run_at);
-- 한 제출물에 진행 중인 작업은 하나만
create unique index analysis_jobs_one_active_idx on public.analysis_jobs (submission_id)
  where status not in ('done', 'failed');

-- ---------------------------------------------------------------------
-- students.profile_id 는 같은 공부방의 "학생" 프로필만 연결 가능
-- (복합 FK 로 공부방 일치는 보장되고, 여기서는 역할을 검사한다. 선생님 계정을
--  학생 행에 연결하면 auth_student_id() 가 엉뚱한 사람을 가리키게 되므로 차단.)
-- ---------------------------------------------------------------------
create or replace function public.tg_students_profile_role()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.profile_id is not null and not exists (
    select 1 from public.profiles where id = new.profile_id and role = 'student'
  ) then
    raise exception 'students.profile_id must reference a student profile';
  end if;
  return new;
end $$;

create trigger students_profile_role before insert or update of profile_id on public.students
  for each row execute function public.tg_students_profile_role();

-- ---------------------------------------------------------------------
-- updated_at 자동 갱신
-- ---------------------------------------------------------------------
create or replace function public.tg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['classes','students','attendance','assignments','submissions',
                           'feedback_drafts','academy_settings','ai_model_limits',
                           'academy_api_keys','analysis_jobs']
  loop
    execute format('create trigger set_updated_at before update on public.%I
                    for each row execute function public.tg_set_updated_at()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 공부방 생성 시 기본 설정/한도 행 자동 생성
-- ---------------------------------------------------------------------
create or replace function public.tg_academy_defaults()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.academy_settings (academy_id) values (new.id);
  -- 기본값: 2026-11 기준 요구사항 표. 실제 값은 AI Studio Rate limit 화면에서 확인 후 수정.
  insert into public.ai_model_limits (academy_id, model, rpm, tpm, rpd) values
    (new.id, 'gemini-3.8-flash',      5,  250000, 20),
    (new.id, 'gemini-3.5-flash-lite', 10, 250000, 500);
  return new;
end $$;

create trigger academy_defaults after insert on public.academies
  for each row execute function public.tg_academy_defaults();

-- ---------------------------------------------------------------------
-- 선생님 자가 가입: auth.users 생성 시 새 공부방 + 선생님 프로필 생성
-- 왜 트리거인가: 이메일 확인이 켜진 프로젝트에서는 signUp 직후 세션이 없어
--   클라이언트가 프로필을 만들 수 없다. 트리거는 가입과 같은 트랜잭션에서 실행된다.
-- 보안: user_metadata 는 사용자가 임의로 넣을 수 있으므로, 여기서는 "새 공부방의
--   선생님" 만 만들 수 있다(기존 공부방에 끼어들 방법이 없다). 학생 계정은
--   서버가 서비스 롤로 생성하고 이 트리거를 타지 않는다(signup_kind 없음).
-- ---------------------------------------------------------------------
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_academy_id uuid;
  v_kind text := new.raw_user_meta_data ->> 'signup_kind';
  v_academy_name text := nullif(btrim(new.raw_user_meta_data ->> 'academy_name'), '');
  v_display_name text := nullif(btrim(new.raw_user_meta_data ->> 'display_name'), '');
begin
  if v_kind is distinct from 'teacher' then
    return new;
  end if;
  if v_academy_name is null or v_display_name is null then
    raise exception 'academy_name and display_name are required for teacher signup';
  end if;

  insert into public.academies (name) values (left(v_academy_name, 100))
    returning id into v_academy_id;
  insert into public.profiles (id, academy_id, role, display_name)
    values (new.id, v_academy_id, 'teacher', left(v_display_name, 50));
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_auth_user();
