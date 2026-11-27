"use client";

import { useEffect, useState } from "react";
import { PublicClientApplication } from "@azure/msal-browser";
import { MsalProvider } from "@azure/msal-react";
import {msalConfig} from "@/config/authConfig";
import RoleProvider from "@/components/providers/RoleProvider";

// One shared instance: React dev mode runs effects twice, and a second handleRedirectPromise() call
// finds the redirect state already consumed and fails with no_token_request_cache_error.
let msalReady: Promise<PublicClientApplication> | null = null;

function getMsal(): Promise<PublicClientApplication> {
  msalReady ??= (async () => {
    const pca = new PublicClientApplication(msalConfig);
    await pca.initialize();

    // Completes the login after Microsoft redirects back to your app
    const result = await pca.handleRedirectPromise();
    if (result?.account) {
      pca.setActiveAccount(result.account);
    } else {
      const accounts = pca.getAllAccounts();
      if (accounts.length > 0) pca.setActiveAccount(accounts[0]);
    }
    return pca;
  })();
  return msalReady;
}

export default function MsalProviderWrapper({
  children,
}: {
  children: React.ReactNode;
}) {
  const [instance, setInstance] = useState<PublicClientApplication | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getMsal().then(setInstance).catch((cause: unknown) => {
      msalReady = null;
      setError(cause instanceof Error ? cause.message : "Authentication could not start.");
    });
  }, []);

  if (error) return <div role="alert" className="p-8 text-sm">Authentication unavailable: {error}</div>;

  if (!instance) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background">
      <div className="h-8 w-8 animate-spin rounded-full border-2 border-border border-t-accent" />
    </div>
  );
}

  return <MsalProvider instance={instance}><RoleProvider>{children}</RoleProvider></MsalProvider>;
}