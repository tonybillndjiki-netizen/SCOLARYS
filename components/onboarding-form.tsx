"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

function slugify(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function OnboardingForm() {
  const router = useRouter();
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  async function createOrganization(formData: FormData) {
    setBusy(true);
    setMessage("");
    const name = String(formData.get("name") || "").trim();
    const city = String(formData.get("city") || "").trim();
    const countryCode = String(formData.get("countryCode") || "FR").trim().toUpperCase();
    const requestedSlug = String(formData.get("slug") || "").trim();
    const slug = slugify(requestedSlug || name);
    const supabase = createClient();
    const { error } = await supabase.rpc("scolaria_create_organization", {
      organization_name: name,
      organization_slug: slug,
      organization_country_code: countryCode,
      organization_city: city || null,
    });
    setBusy(false);
    if (error) return setMessage(error.message);
    router.replace("/app");
    router.refresh();
  }

  return (
    <form action={createOrganization} className="surface w-full max-w-2xl p-8 sm:p-10">
      <span className="badge">Étape 1 / 8</span>
      <h1 className="mt-4 text-3xl font-black">Identité de l’établissement</h1>
      <p className="mt-2 text-sm leading-6 text-[#68758a]">
        Cette organisation constitue la frontière de sécurité de vos données dans SCOLARYS.
      </p>
      <div className="mt-8 grid gap-5 sm:grid-cols-2">
        <div className="field sm:col-span-2">
          <label htmlFor="name">Nom de l’établissement</label>
          <input id="name" name="name" placeholder="Ex. Institut Horizon" required />
        </div>
        <div className="field">
          <label htmlFor="city">Ville principale</label>
          <input id="city" name="city" placeholder="Paris" />
        </div>
        <div className="field">
          <label htmlFor="countryCode">Pays</label>
          <select id="countryCode" name="countryCode" defaultValue="FR">
            <option value="FR">France</option>
            <option value="BE">Belgique</option>
            <option value="CM">Cameroun</option>
            <option value="CI">Côte d’Ivoire</option>
            <option value="CG">Congo-Brazzaville</option>
          </select>
        </div>
        <div className="field sm:col-span-2">
          <label htmlFor="slug">Identifiant d’espace facultatif</label>
          <input id="slug" name="slug" placeholder="institut-horizon" pattern="[a-z0-9]+(?:-[a-z0-9]+)*" />
          <small className="text-[#748096]">Prépare les futures adresses de type ecole.scolarys.app.</small>
        </div>
      </div>
      <button disabled={busy} className="btn-primary mt-7">{busy ? "Création…" : "Créer mon établissement"}</button>
      {message && <p className="mt-5 rounded-xl bg-[#fff0f0] p-3 text-sm text-[#a12c2c]">{message}</p>}
    </form>
  );
}
