import { redirect } from "next/navigation";
import { StudentImportWizard } from "@/components/student-import-wizard";
import { getAppContext } from "@/lib/data/context";

export default async function StudentImportPage() {
  const context = await getAppContext();
  if (!context?.organization || !context.role) redirect("/app");

  const orgId = context.organization.id;
  const [{ data: classes }, { data: memberships }] = await Promise.all([
    context.supabase
      .from("scolaria_classes")
      .select("id, name, code")
      .eq("organization_id", orgId)
      .eq("status", "active")
      .order("name"),
    context.supabase
      .from("scolaria_class_memberships")
      .select("user_id, matricule")
      .eq("organization_id", orgId)
      .eq("membership_type", "student"),
  ]);

  const userIds = [...new Set((memberships ?? []).map((row) => row.user_id))];
  const { data: profiles } = userIds.length
    ? await context.supabase
        .from("scolaria_profiles")
        .select("id, email")
        .in("id", userIds)
    : { data: [] as Array<{ id: string; email: string | null }> };

  return (
    <StudentImportWizard
      organizationId={orgId}
      classes={classes ?? []}
      existingEmails={(profiles ?? []).map((p) => p.email).filter((x): x is string => Boolean(x))}
      existingMatricules={(memberships ?? []).map((m) => m.matricule).filter((x): x is string => Boolean(x))}
    />
  );
}
