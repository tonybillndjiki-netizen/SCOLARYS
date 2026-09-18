"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function signIn(formData: FormData) {
    setBusy(true);
    setMessage("");
    const email = String(formData.get("email") || "").trim().toLowerCase();
    const password = String(formData.get("password") || "");
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) return setMessage(error.message);
    router.replace("/app");
    router.refresh();
  }

  async function signInWithGoogle() {
    setBusy(true);
    setMessage("");
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${location.origin}/auth/callback?next=/app` },
    });
    if (error) {
      setBusy(false);
      setMessage(`Configuration Google requise : ${error.message}`);
    }
  }

  async function requestPasswordReset(email: string) {
    if (!email) return setMessage("Saisissez votre email avant de demander la réinitialisation.");
    setBusy(true);
    const supabase = createClient();
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${location.origin}/auth/callback?next=/reset-password`,
    });
    setBusy(false);
    setMessage(error ? error.message : "Si ce compte existe, un lien de réinitialisation a été envoyé.");
  }

  return (
    <main className="grid min-h-screen place-items-center px-5 py-10">
      <section className="surface grid w-full max-w-5xl overflow-hidden lg:grid-cols-[.9fr_1.1fr]">
        <div className="bg-[#173f5f] p-8 text-white sm:p-12">
          <Link href="/" className="text-xl font-black">SCOLARYS</Link>
          <h1 className="mt-16 text-4xl font-black tracking-[-.04em]">Pilotez votre pédagogie avec une donnée fiable.</h1>
          <p className="mt-5 leading-7 text-white/75">Connexion sécurisée à votre environnement établissement.</p>
        </div>
        <form action={signIn} className="p-8 sm:p-12">
          <span className="badge">Connexion</span>
          <h2 className="mt-4 text-3xl font-black">Bienvenue</h2>
          <p className="mt-2 text-sm text-[#68758a]">Utilisez les identifiants associés à votre établissement.</p>
          <div className="mt-8 grid gap-5">
            <div className="field">
              <label htmlFor="email">Adresse email</label>
              <input id="email" name="email" type="email" autoComplete="email" required />
            </div>
            <div className="field">
              <label htmlFor="password">Mot de passe</label>
              <input id="password" name="password" type="password" autoComplete="current-password" minLength={8} required />
            </div>
            <button className="btn-primary" disabled={busy}>{busy ? "Connexion…" : "Se connecter"}</button>
          </div>
          <div className="mt-4 grid gap-3">
            <button type="button" className="btn-secondary" onClick={signInWithGoogle} disabled={busy}>Continuer avec Google</button>
            <button
              type="button"
              className="text-left text-sm font-bold text-[#173f5f]"
              onClick={() => {
                const email = (document.getElementById("email") as HTMLInputElement | null)?.value || "";
                requestPasswordReset(email.trim().toLowerCase());
              }}
            >
              Mot de passe oublié ?
            </button>
          </div>
          {message && <p className="mt-5 rounded-xl bg-[#f2f5f8] p-3 text-sm text-[#4f5d73]">{message}</p>}
          <p className="mt-8 text-sm text-[#68758a]">
            Nouvel établissement ? <Link className="font-bold text-[#173f5f]" href="/signup">Créer un espace SCOLARYS</Link>
          </p>
        </form>
      </section>
    </main>
  );
}
