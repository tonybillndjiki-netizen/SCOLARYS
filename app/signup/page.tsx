"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function SignupPage() {
  const router = useRouter();
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function signUp(formData: FormData) {
    setBusy(true);
    setMessage("");
    const firstName = String(formData.get("firstName") || "").trim();
    const lastName = String(formData.get("lastName") || "").trim();
    const email = String(formData.get("email") || "").trim().toLowerCase();
    const password = String(formData.get("password") || "");
    const supabase = createClient();
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          first_name: firstName,
          last_name: lastName,
          display_name: `${firstName} ${lastName}`.trim(),
        },
        emailRedirectTo: `${location.origin}/auth/callback?next=/onboarding`,
      },
    });
    setBusy(false);
    if (error) return setMessage(error.message);
    if (data.session) {
      router.replace("/onboarding");
      router.refresh();
    } else {
      setMessage("Compte créé. Confirmez votre adresse email pour poursuivre la configuration de votre établissement.");
    }
  }

  return (
    <main className="grid min-h-screen place-items-center px-5 py-10">
      <form action={signUp} className="surface w-full max-w-xl p-8 sm:p-10">
        <Link href="/" className="font-black text-[#173f5f]">SCOLARYS</Link>
        <span className="badge mt-8">Nouvel établissement</span>
        <h1 className="mt-4 text-3xl font-black">Créer votre compte administrateur</h1>
        <p className="mt-2 text-sm leading-6 text-[#68758a]">Après activation du compte, l’assistant vous permettra de créer votre organisation et son environnement isolé.</p>
        <div className="mt-8 grid gap-5 sm:grid-cols-2">
          <div className="field"><label htmlFor="firstName">Prénom</label><input id="firstName" name="firstName" required /></div>
          <div className="field"><label htmlFor="lastName">Nom</label><input id="lastName" name="lastName" required /></div>
          <div className="field sm:col-span-2"><label htmlFor="email">Email professionnel</label><input id="email" name="email" type="email" autoComplete="email" required /></div>
          <div className="field sm:col-span-2"><label htmlFor="password">Mot de passe</label><input id="password" name="password" type="password" minLength={8} autoComplete="new-password" required /></div>
        </div>
        <button className="btn-primary mt-6 w-full" disabled={busy}>{busy ? "Création…" : "Créer mon compte"}</button>
        {message && <p className="mt-5 rounded-xl bg-[#f2f5f8] p-3 text-sm text-[#4f5d73]">{message}</p>}
        <p className="mt-7 text-sm text-[#68758a]">Déjà un compte ? <Link href="/login" className="font-bold text-[#173f5f]">Se connecter</Link></p>
      </form>
    </main>
  );
}
