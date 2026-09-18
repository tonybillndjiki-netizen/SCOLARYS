"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function ResetPasswordPage() {
  const router = useRouter();
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function updatePassword(formData: FormData) {
    const password = String(formData.get("password") || "");
    const confirmation = String(formData.get("confirmation") || "");
    if (password !== confirmation) {
      setMessage("Les deux mots de passe ne correspondent pas.");
      return;
    }
    setBusy(true);
    const supabase = createClient();
    const { error } = await supabase.auth.updateUser({ password });
    setBusy(false);
    if (error) return setMessage(error.message);
    router.replace("/app");
    router.refresh();
  }

  return (
    <main className="grid min-h-screen place-items-center px-5">
      <form action={updatePassword} className="surface w-full max-w-md p-8">
        <span className="badge">Sécurité du compte</span>
        <h1 className="mt-4 text-3xl font-black">Nouveau mot de passe</h1>
        <div className="mt-7 grid gap-5">
          <div className="field">
            <label htmlFor="password">Nouveau mot de passe</label>
            <input id="password" name="password" type="password" minLength={8} required />
          </div>
          <div className="field">
            <label htmlFor="confirmation">Confirmer</label>
            <input id="confirmation" name="confirmation" type="password" minLength={8} required />
          </div>
          <button disabled={busy} className="btn-primary">{busy ? "Enregistrement…" : "Enregistrer"}</button>
        </div>
        {message && <p className="mt-4 rounded-xl bg-[#f2f5f8] p-3 text-sm">{message}</p>}
      </form>
    </main>
  );
}
