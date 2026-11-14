-- RLS / 트리거 / 테넌트 격리 테스트. 실패 시 예외로 중단된다.
\set ON_ERROR_STOP 1

create or replace function pg_temp.assert(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ASSERTION FAILED: %', msg; end if;
end $$;

-- 사용자로 "로그인"
create or replace function pg_temp.login(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, false);
  execute 'set role authenticated';
end $$;

create or replace function pg_temp.logout() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', false);
end $$;

-- ---------------------------------------------------------------------
-- 준비: 선생님 2명(각자 공부방), 학생 2명(A 공부방), 공부방 B 학생 1명
-- ---------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'ta@x.test',
   '{"signup_kind":"teacher","academy_name":"A 공부방","display_name":"선생님A"}'),
  ('00000000-0000-0000-0000-0000000000b1', 'tb@x.test',
   '{"signup_kind":"teacher","academy_name":"B 공부방","display_name":"선생님B"}'),
  -- 학생 계정: signup_kind 없음 → 트리거가 아무것도 만들지 않음
  ('00000000-0000-0000-0000-0000000000a2', 's1@x.test', '{}'),
  ('00000000-0000-0000-0000-0000000000a3', 's2@x.test', '{}'),
  ('00000000-0000-0000-0000-0000000000b2', 's3@x.test', '{}'),
  -- 공격 시도: 메타데이터에 role/academy_id 를 넣어도 무시되어야 함
  ('00000000-0000-0000-0000-0000000000e1', 'evil@x.test',
   '{"role":"teacher","academy_id":"ignored"}');

select pg_temp.assert((select count(*) from public.academies) = 2, 'teacher signup creates academies');
select pg_temp.assert((select count(*) from public.academy_settings) = 2, 'settings row per academy');
select pg_temp.assert((select count(*) from public.ai_model_limits) = 4, 'limit rows per academy x model');
select pg_temp.assert(not exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-0000000000e1'),
  'non-teacher signup creates no profile');
select pg_temp.assert(
  (select rpd from public.ai_model_limits l join public.profiles p on p.academy_id = l.academy_id
   where p.id = '00000000-0000-0000-0000-0000000000a1' and l.model = 'gemini-3.8-flash') = 20,
  'default flash rpd = 20');

-- 선생님 가입 필수값 누락 시 가입 자체가 실패해야 함
do $$ begin
  insert into auth.users (email, raw_user_meta_data) values ('bad@x.test', '{"signup_kind":"teacher"}');
  raise exception 'should have failed';
exception when others then
  if sqlerrm = 'should have failed' then raise; end if;
end $$;

-- 변수 대신 임시 테이블에 id 보관
create temp table ids as
select
  (select academy_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1') as acad_a,
  (select academy_id from public.profiles where id = '00000000-0000-0000-0000-0000000000b1') as acad_b;
grant select on ids to authenticated;

insert into public.profiles (id, academy_id, role, display_name)
select '00000000-0000-0000-0000-0000000000a2'::uuid, acad_a, 'student'::public.user_role, '학생1' from ids union all
select '00000000-0000-0000-0000-0000000000a3'::uuid, acad_a, 'student'::public.user_role, '학생2' from ids union all
select '00000000-0000-0000-0000-0000000000b2'::uuid, acad_b, 'student'::public.user_role, '학생3' from ids;

insert into public.classes (id, academy_id, name)
select '10000000-0000-0000-0000-00000000000a'::uuid, acad_a, '초5 국어' from ids union all
select '10000000-0000-0000-0000-00000000000c'::uuid, acad_a, '중1 영어' from ids union all
select '10000000-0000-0000-0000-00000000000b'::uuid, acad_b, 'B반' from ids;

insert into public.students (id, academy_id, profile_id, class_id, name, ai_consent)
select '20000000-0000-0000-0000-0000000000a2'::uuid, acad_a, '00000000-0000-0000-0000-0000000000a2'::uuid,
       '10000000-0000-0000-0000-00000000000a'::uuid, '학생1', true from ids union all
select '20000000-0000-0000-0000-0000000000a3'::uuid, acad_a, '00000000-0000-0000-0000-0000000000a3'::uuid,
       '10000000-0000-0000-0000-00000000000c'::uuid, '학생2', false from ids union all
select '20000000-0000-0000-0000-0000000000b2'::uuid, acad_b, '00000000-0000-0000-0000-0000000000b2'::uuid,
       '10000000-0000-0000-0000-00000000000b'::uuid, '학생3', true from ids;

insert into public.assignments (id, academy_id, class_id, title)
select '30000000-0000-0000-0000-00000000000a'::uuid, acad_a, '10000000-0000-0000-0000-00000000000a'::uuid, '낭독 과제' from ids union all
select '30000000-0000-0000-0000-00000000000c'::uuid, acad_a, '10000000-0000-0000-0000-00000000000c'::uuid, '영어 말하기' from ids;

insert into public.submissions (id, academy_id, assignment_id, student_id, status)
select '40000000-0000-0000-0000-00000000000a'::uuid, acad_a, '30000000-0000-0000-0000-00000000000a'::uuid,
       '20000000-0000-0000-0000-0000000000a2'::uuid, 'review_pending'::public.submission_status from ids;

insert into public.feedback_drafts (submission_id, academy_id, source, ai_original)
select '40000000-0000-0000-0000-00000000000a'::uuid, acad_a, 'ai'::public.feedback_source, '{"summary":"원본"}'::jsonb from ids;

insert into public.academy_api_keys (academy_id, ciphertext, iv, auth_tag, masked)
select acad_a, 'c', 'i', 't', 'AIza••••1234' from ids;

insert into storage.objects (bucket_id, name)
select 'submissions', acad_a || '/20000000-0000-0000-0000-0000000000a2/40000000-0000-0000-0000-00000000000a.mp4' from ids union all
select 'submissions', acad_a || '/20000000-0000-0000-0000-0000000000a3/x.mp4' from ids union all
select 'submissions', acad_b || '/20000000-0000-0000-0000-0000000000b2/y.mp4' from ids;

-- ---------------------------------------------------------------------
-- 테넌트 격리: 다른 공부방의 반/계정과 연결 불가 (복합 FK)
-- ---------------------------------------------------------------------
do $$ begin
  insert into public.students (academy_id, class_id, name)
  select acad_a, '10000000-0000-0000-0000-00000000000b'::uuid, '침입' from ids;
  raise exception 'should have failed';
exception when foreign_key_violation then null; end $$;

-- 선생님 계정을 학생 행에 연결 불가
do $$ begin
  update public.students set profile_id = null where id = '20000000-0000-0000-0000-0000000000a3';
  insert into public.students (academy_id, profile_id, name)
  select acad_a, '00000000-0000-0000-0000-0000000000a1'::uuid, '선생님을 학생으로' from ids;
  raise exception 'should have failed';
exception when others then
  if sqlerrm = 'should have failed' then raise; end if;
end $$;
update public.students set profile_id = '00000000-0000-0000-0000-0000000000a3' where id = '20000000-0000-0000-0000-0000000000a3';

-- ---------------------------------------------------------------------
-- 선생님 A
-- ---------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select pg_temp.assert((select count(*) from public.classes) = 2, 'teacher A sees only A classes');
select pg_temp.assert((select count(*) from public.students) = 2, 'teacher A sees only A students');
select pg_temp.assert((select count(*) from public.profiles) = 3, 'teacher A sees A profiles');
select pg_temp.assert((select count(*) from public.feedback_drafts) = 1, 'teacher sees drafts');
select pg_temp.assert((select count(*) from public.academy_settings) = 1, 'teacher sees own settings');
select pg_temp.assert((select count(*) from storage.objects) = 2, 'teacher sees A videos only');

-- API 키 테이블은 선생님도 직접 조회 불가(권한 회수)
do $$ begin
  perform * from public.academy_api_keys;
  raise exception 'should have failed';
exception when insufficient_privilege then null; end $$;

-- 다른 공부방에 반 생성 불가
do $$ begin
  insert into public.classes (academy_id, name) select acad_b, '침입반' from ids;
  raise exception 'should have failed';
exception when insufficient_privilege then null; end $$;

-- 사용량 기록 직접 쓰기 불가(한도 우회 차단)
do $$ begin
  insert into public.ai_usage_events (academy_id, model, kind, la_date, estimated_input_tokens)
  select acad_a, 'gemini-3.8-flash', 'analysis', current_date, 0 from ids;
  raise exception 'should have failed';
exception when insufficient_privilege then null; end $$;

-- 자기 역할 변경 불가 (profiles update 정책 없음 → 0행 갱신)
update public.profiles set role = 'student' where id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.logout();
select pg_temp.assert((select role from public.profiles where id = '00000000-0000-0000-0000-0000000000a1') = 'teacher',
  'profile role cannot be self-changed');

-- 선생님 A 의 CRUD 는 동작
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
insert into public.attendance (academy_id, student_id, date, status)
select acad_a, '20000000-0000-0000-0000-0000000000a2'::uuid, date '2026-11-14', 'present' from ids;
update public.academy_settings set max_upload_mb = 150;
select pg_temp.assert((select max_upload_mb from public.academy_settings) = 150, 'teacher updates settings');
select pg_temp.logout();

-- ---------------------------------------------------------------------
-- 선생님 B: A 데이터 전혀 안 보임
-- ---------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
select pg_temp.assert((select count(*) from public.classes) = 1, 'teacher B sees only B class');
select pg_temp.assert((select count(*) from public.submissions) = 0, 'teacher B sees no A submissions');
select pg_temp.assert((select count(*) from public.feedback_drafts) = 0, 'teacher B sees no A drafts');
update public.students set name = '해킹' where id = '20000000-0000-0000-0000-0000000000a2';
select pg_temp.logout();
select pg_temp.assert((select name from public.students where id = '20000000-0000-0000-0000-0000000000a2') = '학생1',
  'teacher B cannot update A student');

-- ---------------------------------------------------------------------
-- 학생1 (A, 초5 국어)
-- ---------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a2');
select pg_temp.assert((select count(*) from public.students) = 1, 'student sees only self');
select pg_temp.assert((select count(*) from public.classes) = 1, 'student sees only own class');
select pg_temp.assert((select count(*) from public.assignments) = 1, 'student sees own class assignments');
select pg_temp.assert((select count(*) from public.submissions) = 1, 'student sees own submissions');
select pg_temp.assert((select count(*) from public.attendance) = 1, 'student sees own attendance');
select pg_temp.assert((select count(*) from public.feedback_drafts) = 0, 'student cannot see drafts/AI original');
select pg_temp.assert((select count(*) from public.published_feedback) = 0, 'nothing published yet');
select pg_temp.assert((select count(*) from public.academy_settings) = 0, 'student cannot see settings');
select pg_temp.assert((select count(*) from public.ai_usage_events) = 0, 'student cannot see usage');
select pg_temp.assert((select count(*) from public.ai_model_limits) = 0, 'student cannot see limits');
select pg_temp.assert((select count(*) from public.profiles) = 1, 'student sees only own profile');
select pg_temp.assert((select count(*) from storage.objects) = 1, 'student sees only own video');

do $$ begin
  perform * from public.academy_api_keys;
  raise exception 'should have failed';
exception when insufficient_privilege then null; end $$;

-- 학생은 제출 상태를 직접 바꿀 수 없음
update public.submissions set status = 'published';
-- 학생은 직접 제출 행을 만들 수 없음(서버 경유)
do $$ begin
  insert into public.submissions (academy_id, assignment_id, student_id)
  select acad_a, '30000000-0000-0000-0000-00000000000a'::uuid, '20000000-0000-0000-0000-0000000000a2'::uuid from ids;
  raise exception 'should have failed';
exception when insufficient_privilege then null; end $$;
-- 학생은 동의 여부를 스스로 바꿀 수 없음
update public.students set ai_consent = true;
select pg_temp.logout();
select pg_temp.assert((select status from public.submissions where id = '40000000-0000-0000-0000-00000000000a') = 'review_pending',
  'student cannot change submission status');

-- 공개 후에는 보임
insert into public.published_feedback (submission_id, academy_id, student_id, content)
select '40000000-0000-0000-0000-00000000000a'::uuid, acad_a, '20000000-0000-0000-0000-0000000000a2'::uuid, '{"summary":"공개본"}' from ids;
select pg_temp.login('00000000-0000-0000-0000-0000000000a2');
select pg_temp.assert((select count(*) from public.published_feedback) = 1, 'student sees published feedback');
select pg_temp.logout();

-- 학생2 는 학생1 의 공개 피드백/제출물을 볼 수 없음
select pg_temp.login('00000000-0000-0000-0000-0000000000a3');
select pg_temp.assert((select count(*) from public.published_feedback) = 0, 'other student cannot see feedback');
select pg_temp.assert((select count(*) from public.submissions) = 0, 'other student cannot see submissions');
select pg_temp.assert((select count(*) from public.assignments) = 1, 'student2 sees only own class assignment');
select pg_temp.assert((select ai_consent from public.students) = false, 'consent unchanged by student');
select pg_temp.logout();

-- 익명: 아무것도 안 보임
set role anon;
do $$ begin
  perform * from public.students;
  raise exception 'should have failed';
exception when insufficient_privilege then null; end $$;
reset role;

\echo 'rls.test.sql: all assertions passed'
