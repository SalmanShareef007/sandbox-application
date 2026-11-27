type RuntimeConfig = {
  clientId: string;
  tenantId: string;
  redirectUri: string;
  apiScope: string;
  apiBaseUrl: string;
};

declare global {
  interface Window {
    __APP_CONFIG__?: Record<string, string | undefined>;
  }
}

/**
 * Values come from /config.js (written from the container's environment at startup), so one image
 * serves every customer. Local development falls back to the build-time NEXT_PUBLIC_* variables.
 */
export function runtimeConfig(): RuntimeConfig {
  const injected = typeof window !== "undefined" ? window.__APP_CONFIG__ : undefined;
  return {
    clientId: injected?.NEXT_PUBLIC_CLIENT_ID || process.env.NEXT_PUBLIC_CLIENT_ID || "",
    tenantId: injected?.NEXT_PUBLIC_TENANT_ID || process.env.NEXT_PUBLIC_TENANT_ID || "",
    redirectUri: injected?.NEXT_PUBLIC_REDIRECT_URI || process.env.NEXT_PUBLIC_REDIRECT_URI || "",
    apiScope: injected?.NEXT_PUBLIC_API_SCOPE || process.env.NEXT_PUBLIC_API_SCOPE || "",
    apiBaseUrl: injected?.NEXT_PUBLIC_API_BASE_URL || process.env.NEXT_PUBLIC_API_BASE_URL || "http://127.0.0.1:8000",
  };
}
