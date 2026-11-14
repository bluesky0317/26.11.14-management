-- =====================================================================
-- Storage: 과제 영상 버킷
-- 경로 규칙: {academy_id}/{student_id}/{submission_id}.{ext}
--   - 첫 폴더가 academy_id 이므로 선생님 권한은 폴더명으로 판별한다.
-- 업로드는 서버가 발급한 signed upload URL 로만 한다(서버 경유 금지, 크기 제한은
-- 버킷 file_size_limit + 서버 검증 + 클라이언트 사전 검사로 3중 확인).
-- 따라서 사용자 역할에 insert/update 정책은 주지 않는다.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'submissions', 'submissions', false,
  -- 버킷 상한(2GB = Gemini 무료 Files API 최대). 공부방별 상한(기본 200MB)은 서버가 검증.
  2147483648,
  array['video/mp4', 'video/quicktime', 'video/webm']
)
on conflict (id) do nothing;

-- 선생님: 자기 공부방 폴더의 영상 조회(재생용 signed URL 발급 포함)
create policy submissions_teacher_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'submissions'
    and public.auth_role() = 'teacher'
    -- uuid 캐스팅 대신 텍스트 비교: 규칙에 맞지 않는 경로가 있어도 캐스팅 오류가 나지 않게
    and (storage.foldername(name))[1] = public.auth_academy_id()::text
  );

-- 학생: 본인 폴더의 영상만 조회
create policy submissions_student_read_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'submissions'
    and public.auth_role() = 'student'
    and (storage.foldername(name))[1] = public.auth_academy_id()::text
    and (storage.foldername(name))[2] = public.auth_student_id()::text
  );
