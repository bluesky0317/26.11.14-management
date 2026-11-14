-- =====================================================================
-- Row Level Security
-- 원칙
--   * 선생님: 자기 공부방(academy_id) 데이터만.
--   * 학생: 자기 데이터만(자기 students 행, 자기 반 과제, 자기 제출물, 공개된 피드백).
--   * API 키 / 사용량 기록 쓰기 / 작업 큐 쓰기: 서비스 롤 전용(정책 없음 = 거부).
--   * 서비스 롤 키는 RLS 를 우회하므로 서버 코드에서만 사용한다.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 헬퍼 함수
-- security definer 인 이유: profiles 에도 RLS 가 걸려 있어, 정책 안에서 profiles 를
-- 조회하면 재귀가 생긴다. stable 이라 한 쿼리 안에서는 한 번만 평가된다.
-- ---------------------------------------------------------------------
create or replace function public.auth_academy_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select academy_id from public.profiles where id = auth.uid()
$$;

create or replace function public.auth_role()
returns public.user_role language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_teacher_of(p_academy_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'teacher' and academy_id = p_academy_id
  )
$$;

-- 로그인한 학생의 students.id (학생이 아니면 null)
create or replace function public.auth_student_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select s.id from public.students s
  join public.profiles p on p.id = s.profile_id
  where p.id = auth.uid() and p.role = 'student'
$$;

create or replace function public.auth_student_class_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select s.class_id from public.students s
  join public.profiles p on p.id = s.profile_id
  where p.id = auth.uid() and p.role = 'student'
$$;

revoke all on function public.auth_academy_id() from public;
revoke all on function public.auth_role() from public;
revoke all on function public.is_teacher_of(uuid) from public;
revoke all on function public.auth_student_id() from public;
revoke all on function public.auth_student_class_id() from public;
grant execute on function public.auth_academy_id(), public.auth_role(),
  public.is_teacher_of(uuid), public.auth_student_id(), public.auth_student_class_id()
  to authenticated;

-- 트리거 함수는 직접 호출할 일이 없다.
revoke all on function public.handle_new_auth_user() from public, anon, authenticated;
revoke all on function public.tg_academy_defaults() from public, anon, authenticated;
revoke all on function public.tg_students_profile_role() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- RLS 활성화 (모든 public 테이블)
-- ---------------------------------------------------------------------
alter table public.academies           enable row level security;
alter table public.profiles            enable row level security;
alter table public.classes             enable row level security;
alter table public.students            enable row level security;
alter table public.attendance          enable row level security;
alter table public.assignments         enable row level security;
alter table public.submissions         enable row level security;
alter table public.feedback_drafts     enable row level security;
alter table public.published_feedback  enable row level security;
alter table public.academy_settings    enable row level security;
alter table public.ai_model_limits     enable row level security;
alter table public.academy_api_keys    enable row level security;
alter table public.ai_usage_events     enable row level security;
alter table public.ai_model_exhaustion enable row level security;
alter table public.analysis_jobs       enable row level security;

-- 익명 사용자는 어떤 테이블에도 접근할 일이 없다.
revoke all on all tables in schema public from anon;

-- API 키는 RLS 정책이 없어 이미 거부되지만, 실수로 정책이 추가돼도 막히도록 권한 자체를 회수.
revoke all on public.academy_api_keys from anon, authenticated;

-- ---------------------------------------------------------------------
-- academies / profiles
-- ---------------------------------------------------------------------
create policy academies_select_member on public.academies
  for select to authenticated using (id = public.auth_academy_id());
create policy academies_update_teacher on public.academies
  for update to authenticated
  using (public.is_teacher_of(id)) with check (public.is_teacher_of(id));

-- 본인 프로필 + (선생님이면) 같은 공부방 프로필 조회. 생성/수정은 서버(서비스 롤)만.
create policy profiles_select_self on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_select_teacher on public.profiles
  for select to authenticated using (public.is_teacher_of(academy_id));

-- ---------------------------------------------------------------------
-- 선생님: 공부방 데이터 전체 CRUD
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['classes','students','attendance','assignments',
                           'submissions','feedback_drafts','published_feedback']
  loop
    execute format($f$
      create policy %1$s_teacher_all on public.%1$I
        for all to authenticated
        using (public.is_teacher_of(academy_id))
        with check (public.is_teacher_of(academy_id))
    $f$, t);
  end loop;
end $$;

-- 설정/한도: 선생님 조회·수정 (행 생성/삭제는 트리거·서버 담당)
create policy academy_settings_teacher_select on public.academy_settings
  for select to authenticated using (public.is_teacher_of(academy_id));
create policy academy_settings_teacher_update on public.academy_settings
  for update to authenticated
  using (public.is_teacher_of(academy_id)) with check (public.is_teacher_of(academy_id));
create policy ai_model_limits_teacher_select on public.ai_model_limits
  for select to authenticated using (public.is_teacher_of(academy_id));
create policy ai_model_limits_teacher_update on public.ai_model_limits
  for update to authenticated
  using (public.is_teacher_of(academy_id)) with check (public.is_teacher_of(academy_id));

-- 사용량/작업 큐: 선생님은 조회만. 쓰기는 QuotaGuard/워커(서비스 롤) 전용 →
-- 클라이언트가 카운터를 조작해 한도를 우회할 수 없다.
create policy ai_usage_events_teacher_select on public.ai_usage_events
  for select to authenticated using (public.is_teacher_of(academy_id));
create policy ai_model_exhaustion_teacher_select on public.ai_model_exhaustion
  for select to authenticated using (public.is_teacher_of(academy_id));
create policy analysis_jobs_teacher_select on public.analysis_jobs
  for select to authenticated using (public.is_teacher_of(academy_id));

-- ---------------------------------------------------------------------
-- 학생: 자기 데이터만 조회
-- ---------------------------------------------------------------------
create policy students_select_self on public.students
  for select to authenticated using (id = public.auth_student_id());

create policy classes_select_own_student on public.classes
  for select to authenticated using (id = public.auth_student_class_id());

create policy attendance_select_own_student on public.attendance
  for select to authenticated using (student_id = public.auth_student_id());

create policy assignments_select_own_student on public.assignments
  for select to authenticated using (class_id = public.auth_student_class_id());

create policy submissions_select_own_student on public.submissions
  for select to authenticated using (student_id = public.auth_student_id());

-- 공개된 피드백만. feedback_drafts(AI 원본 포함)에는 학생 정책이 없다.
create policy published_feedback_select_own_student on public.published_feedback
  for select to authenticated using (student_id = public.auth_student_id());

-- 학생의 제출 생성/상태 변경은 서버(Server Action)가 검증 후 서비스 롤로 처리한다.
-- (상태 머신을 클라이언트가 건너뛰지 못하게 학생에게는 insert/update 정책을 주지 않는다.)
