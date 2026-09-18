import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { getAppContext } from "@/lib/data/context";

export default async function ProtectedLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const context = await getAppContext();

  if (!context) redirect("/login");
  if (!context.membership || !context.organization || !context.role) redirect("/onboarding");

  return (
    <AppShell
      organizationName={context.organization.name}
      roleName={context.role.name}
      userName={context.profile?.display_name || context.profile?.email || "Utilisateur"}
    >
      {children}
    </AppShell>
  );
}
