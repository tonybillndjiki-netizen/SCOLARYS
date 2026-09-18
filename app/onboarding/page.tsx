import { redirect } from "next/navigation";
import { OnboardingForm } from "@/components/onboarding-form";
import { createClient } from "@/lib/supabase/server";

export default async function OnboardingPage() {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;

  if (!userId) redirect("/login");

  const { data: membership } = await supabase
    .from("scolaria_organization_members")
    .select("id")
    .eq("user_id", userId)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();

  if (membership) redirect("/app");

  return (
    <main className="grid min-h-screen place-items-center px-5 py-10">
      <OnboardingForm />
    </main>
  );
}
