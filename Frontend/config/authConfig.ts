import { Configuration } from "@azure/msal-browser";
import { runtimeConfig } from "@/lib/runtimeConfig";

const config = runtimeConfig();

export const msalConfig: Configuration = {
  auth: {
    clientId: config.clientId,
    authority: `https://login.microsoftonline.com/${config.tenantId}`,
    redirectUri: config.redirectUri || undefined,
    postLogoutRedirectUri: config.redirectUri || undefined,
  },
  cache: { cacheLocation: "sessionStorage" },
};

export const loginRequest = {
  scopes: ["openid", "profile", "User.Read"],
};

export const apiRequest = {
  scopes: [config.apiScope],
};

export const graphRequest = {
  scopes: ["User.Read"],
};
