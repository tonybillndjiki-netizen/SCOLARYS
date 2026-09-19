import type { getAppContext } from "@/lib/data/context";

type AppContext = NonNullable<Awaited<ReturnType<typeof getAppContext>>>;

export type CourseFormOptions = {
  classes: Array<{ id: string; name: string; code: string | null; program_id: string }>;
  subjects: Array<{ id: string; name: string; code: string | null; program_id: string }>;
  classSubjects: Array<{ class_id: string; subject_id: string }>;
  periods: Array<{ id: string; name: string }>;
  teachers: Array<{ id: string; name: string }>;
  competencies: Array<{
    id: string;
    name: string;
    code: string | null;
    program_id: string | null;
    subject_id: string | null;
  }>;
  loadError: boolean;
};

export async function getCourseFormOptions(context: AppContext): Promise<CourseFormOptions> {
  if (!context.organization) {
    return {
      classes: [],
      subjects: [],
      classSubjects: [],
      periods: [],
      teachers: [],
      competencies: [],
      loadError: true,
    };
  }

  const orgId = context.organization.id;
  const [classesResult, subjectsResult, classSubjectsResult, periodsResult, competenciesResult, rolesResult] =
    await Promise.all([
      context.supabase
        .from("scolaria_classes")
        .select("id, name, code, program_id")
        .eq("organization_id", orgId)
        .eq("status", "active")
        .order("name"),
      context.supabase
        .from("scolaria_subjects")
        .select("id, name, code, program_id")
        .eq("organization_id", orgId)
        .eq("is_active", true)
        .order("name"),
      context.supabase
        .from("scolaria_class_subjects")
        .select("class_id, subject_id")
        .eq("organization_id", orgId),
      context.supabase
        .from("scolaria_academic_periods")
        .select("id, name")
        .eq("organization_id", orgId)
        .order("starts_on"),
      context.supabase
        .from("scolaria_competencies")
        .select("id, name, code, program_id, subject_id")
        .eq("organization_id", orgId)
        .eq("is_active", true)
        .order("ordinal")
        .order("name"),
      context.supabase
        .from("scolaria_roles")
        .select("id")
        .eq("organization_id", orgId)
        .eq("key", "teacher")
        .maybeSingle(),
    ]);

  const teacherRoleId = rolesResult.data?.id;
  const teacherMembershipsResult = teacherRoleId
    ? await context.supabase
        .from("scolaria_organization_members")
        .select("user_id")
        .eq("organization_id", orgId)
        .eq("role_id", teacherRoleId)
        .eq("status", "active")
    : { data: [] as Array<{ user_id: string }>, error: null };

  const teacherIds = [...new Set((teacherMembershipsResult.data ?? []).map((item) => item.user_id))];
  const teacherProfilesResult = teacherIds.length
    ? await context.supabase
        .from("scolaria_profiles")
        .select("id, display_name, first_name, last_name, email")
        .in("id", teacherIds)
    : {
        data: [] as Array<{
          id: string;
          display_name: string | null;
          first_name: string | null;
          last_name: string | null;
          email: string | null;
        }>,
        error: null,
      };

  const teachers = (teacherProfilesResult.data ?? [])
    .map((profile) => ({
      id: profile.id,
      name:
        profile.display_name ||
        [profile.first_name, profile.last_name].filter(Boolean).join(" ") ||
        profile.email ||
        "Enseignant",
    }))
    .sort((a, b) => a.name.localeCompare(b.name, "fr"));

  return {
    classes: classesResult.data ?? [],
    subjects: subjectsResult.data ?? [],
    classSubjects: classSubjectsResult.data ?? [],
    periods: periodsResult.data ?? [],
    teachers,
    competencies: competenciesResult.data ?? [],
    loadError: Boolean(
      classesResult.error ||
      subjectsResult.error ||
      classSubjectsResult.error ||
      periodsResult.error ||
      competenciesResult.error ||
      rolesResult.error ||
      teacherMembershipsResult.error ||
      teacherProfilesResult.error
    ),
  };
}

export const courseStatusLabels = {
  draft: "Brouillon",
  published: "Publié",
  archived: "Archivé",
} as const;

export const chapterStatusLabels = {
  draft: "Brouillon",
  scheduled: "Planifié",
  published: "Publié",
  archived: "Archivé",
} as const;

export function statusBadgeClass(status: string) {
  if (status === "published") return "badge-ok";
  if (status === "scheduled") return "badge-warn";
  if (status === "archived") return "badge-danger";
  return "";
}

export function formatDateTime(value: string | null | undefined, timeZone = "Europe/Paris") {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  try {
    return new Intl.DateTimeFormat("fr-FR", {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone,
    }).format(date);
  } catch {
    return new Intl.DateTimeFormat("fr-FR", {
      dateStyle: "medium",
      timeStyle: "short",
      timeZone: "Europe/Paris",
    }).format(date);
  }
}
