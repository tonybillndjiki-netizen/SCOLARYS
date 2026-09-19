import { createClient } from "@/lib/supabase/server";

export async function getAppContext() {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;

  if (!userId) return null;

  const { data: membership } = await supabase
    .from("scolaria_organization_members")
    .select("organization_id, role_id")
    .eq("user_id", userId)
    .eq("status", "active")
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (!membership) {
    return {
      userId,
      supabase,
      membership: null,
      organization: null,
      role: null,
      profile: null,
      permissions: [] as string[],
      timeZone: "Europe/Paris",
    };
  }

  const [{ data: organization }, { data: role }, { data: profile }, { data: rolePermissions }, { data: settings }] = await Promise.all([
    supabase
      .from("scolaria_organizations")
      .select("id, name, slug, plan_key, logo_url")
      .eq("id", membership.organization_id)
      .single(),
    supabase
      .from("scolaria_roles")
      .select("id, key, name")
      .eq("id", membership.role_id)
      .single(),
    supabase
      .from("scolaria_profiles")
      .select("id, display_name, first_name, last_name, email, avatar_url, platform_role")
      .eq("id", userId)
      .single(),
    supabase
      .from("scolaria_role_permissions")
      .select("permission_id")
      .eq("organization_id", membership.organization_id)
      .eq("role_id", membership.role_id),
    supabase
      .from("scolaria_organization_settings")
      .select("timezone")
      .eq("organization_id", membership.organization_id)
      .maybeSingle(),
  ]);

  const permissionIds = (rolePermissions ?? []).map((item) => item.permission_id);
  const { data: permissionRows } = permissionIds.length
    ? await supabase
        .from("scolaria_permissions")
        .select("code")
        .in("id", permissionIds)
    : { data: [] as Array<{ code: string }> };

  return {
    userId,
    supabase,
    membership,
    organization,
    role,
    profile,
    permissions: (permissionRows ?? []).map((item) => item.code),
    timeZone: settings?.timezone || "Europe/Paris",
  };
}
