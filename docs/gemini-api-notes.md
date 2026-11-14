# Gemini API 문서 확인 결과 (2026-11-14 확인)

공식 문서(ai.google.dev → 현재 aistudio.google.com/docs 로 리다이렉트)를 직접 확인한 내용. Phase 3~4 구현의 근거이며, 구현 시 설치된 `@google/genai`(3.3.0) 타입 정의로 다시 검증한다.

## 핵심: 권장 API가 바뀜
- 문서 인덱스(https://aistudio.google.com/llms.txt): "Use the Interactions API (`client.interactions`) as the default across all workflows. `generateContent` is still supported for existing integrations, but is considered a legacy API."
- → 요구사항의 `generateContent` 대신 **`ai.interactions.create`** 를 사용한다.

## 영상 업로드 / 처리 대기 / 삭제 (Files API)
출처: https://aistudio.google.com/docs/video-understanding , https://aistudio.google.com/docs/files
```js
const myfile = await ai.files.upload({ file, config: { mimeType: "video/mp4" } });
let f = await ai.files.get({ name: myfile.name });
while (f.state === "PROCESSING") { /* 대기 후 */ f = await ai.files.get({ name: myfile.name }); }
if (f.state === "FAILED") throw ...;
await ai.files.delete({ name: myfile.name });   // 미삭제 시 48시간 후 자동 삭제
```
- 무료 등급 파일 최대 2GB. 지원 MIME: video/mp4, video/mov, video/webm 등 (mov 는 `video/mov` 로 명시됨)

## 생성 호출
```js
const interaction = await ai.interactions.create({
  model: "gemini-3.8-flash",
  system_instruction: "...",
  input: [
    { type: "video", uri: f.uri, mime_type: f.mimeType, resolution: "low", processing: "static" },
    { type: "text", text: "..." },   // 텍스트는 영상 뒤에 두는 것이 권장
  ],
  response_format: { type: "text", mime_type: "application/json", schema: jsonSchema },
  store: false,   // 기본은 서버에 저장됨. 미성년자 데이터이므로 저장하지 않음
});
interaction.output_text; interaction.usage; // usage.total_input_tokens / total_output_tokens / total_tokens
```
- 미디어 해상도: 콘텐츠 항목별 `resolution: "low" | "medium" | "high" | ...` (Gemini 3 이상). 출처: https://aistudio.google.com/docs/media-resolution
- 영상 토큰: low 해상도 기본 약 100 tokens/초 (프레임 66 + 오디오 32 + 메타). → 초당 계수 기본값 100의 근거
- 처리 모드 `processing: "static"`(기본) / `"agentic"`. 5분 이하 짧은 영상은 static 권장
- 구조화 출력: JSON Schema 부분집합. `minItems`/`maxItems` 는 강제됨, `minLength` 등은 무시 → zod `.parse()` 로 재검증. 문서 예시는 `z.fromJSONSchema()` 사용

## 한도 / 오류
출처: https://aistudio.google.com/docs/rate-limits , https://aistudio.google.com/docs/api-errors
- "Rate limits are applied per project, not per API key. Requests per day (RPD) quotas reset at midnight Pacific time."
- RPM, TPM(입력), RPD 중 하나라도 넘으면 429
- 429 코드 구분: `rate_limit_exceeded`(분당) / `quota_exceeded`(일일) / `too_many_requests`
- 오류 응답 형식: `{ "error": { "code": "...", "message": "..." } }`
- 모델 ID 확인: `gemini-3.8-flash`(Stable), `gemini-3.5-flash-lite` 모두 모델 목록에 존재
