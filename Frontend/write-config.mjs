// Writes public/config.js from the container environment so the browser gets per-customer values at runtime.
import { writeFileSync } from "node:fs";
import { join } from "node:path";

const keys = [
  "NEXT_PUBLIC_CLIENT_ID",
  "NEXT_PUBLIC_TENANT_ID",
  "NEXT_PUBLIC_REDIRECT_URI",
  "NEXT_PUBLIC_API_SCOPE",
  "NEXT_PUBLIC_API_BASE_URL",
];

const config = Object.fromEntries(keys.map((key) => [key, process.env[key] || ""]));
writeFileSync(join(import.meta.dirname, "public", "config.js"), `window.__APP_CONFIG__ = ${JSON.stringify(config)};\n`);
