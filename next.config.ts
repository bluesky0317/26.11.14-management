import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // 서버 전용 패키지는 번들에 포함하지 않는다(키 처리 코드가 클라이언트로 새지 않게).
  serverExternalPackages: ["@google/genai"],
  experimental: {
    serverActions: {
      // 영상은 Storage로 직접 업로드하므로 Server Action 본문은 작게 유지한다.
      bodySizeLimit: "1mb",
    },
  },
};

export default nextConfig;
