import Link from "next/link";
import { ArrowRight, BookOpen, GraduationCap, Library, School, Users } from "lucide-react";
import { getAppContext } from "@/lib/data/context";

export default async function DashboardPage() {
  const context = await getAppContext();
  if (!context?.organization) return null;
  const { supabase, organization } = context;
  const orgId = organization.id;
  let coursesQuery = supabase
    .from("scolaria_courses")
    .select("*", { count: "exact", head: true })
    .eq("organization_id", orgId);
  if (context.role?.key === "teacher") coursesQuery = coursesQuery.eq("teacher_id", context.userId);
  if (context.role?.key === "student") coursesQuery = coursesQuery.eq("status", "published");

  const [programs, classes, students, subjects, courses, recentClasses] = await Promise.all([
    supabase.from("scolaria_programs").select("*", { count: "exact", head: true }).eq("organization_id", orgId).eq("is_active", true),
    supabase.from("scolaria_classes").select("*", { count: "exact", head: true }).eq("organization_id", orgId).eq("status", "active"),
    supabase.from("scolaria_class_memberships").select("*", { count: "exact", head: true }).eq("organization_id", orgId).eq("membership_type", "student").eq("status", "active"),
    supabase.from("scolaria_subjects").select("*", { count: "exact", head: true }).eq("organization_id", orgId).eq("is_active", true),
    coursesQuery,
    supabase.from("scolaria_classes").select("id, name, code, program_id").eq("organization_id", orgId).eq("status", "active").order("name").limit(5),
  ]);

  const metrics = [
    { label: "Formations", value: programs.error ? null : programs.count ?? 0, icon: GraduationCap, href: "/app/programs" },
    { label: "Classes", value: classes.error ? null : classes.count ?? 0, icon: School, href: "/app/classes" },
    { label: "Étudiants", value: students.error ? null : students.count ?? 0, icon: Users, href: "/app/students" },
    { label: "Matières", value: subjects.error ? null : subjects.count ?? 0, icon: BookOpen, href: "/app/subjects" },
    { label: "Cours", value: courses.error ? null : courses.count ?? 0, icon: Library, href: "/app/courses" },
  ];
  const hasDataError = Boolean(
    programs.error || classes.error || students.error || subjects.error || courses.error || recentClasses.error
  );

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <span className="badge">Pilotage</span>
          <h1 className="mt-3 text-3xl font-black tracking-[-.035em]">Dashboard</h1>
          <p className="mt-2 text-sm text-[#68758a]">{organization.name} · données en temps réel depuis Supabase</p>
        </div>
        <span className={`badge ${hasDataError ? "badge-danger" : "badge-ok"}`}>
          {hasDataError ? "Chargement partiel" : "Données chargées"}
        </span>
      </div>

      <section className="mt-7 grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        {metrics.map(({ label, value, icon: Icon, href }) => (
          <Link href={href} className="metric group" key={label}>
            <div className="flex items-center justify-between">
              <span className="grid h-10 w-10 place-items-center rounded-xl bg-[#eaf4f6] text-[#147d85]"><Icon size={20} /></span>
              <ArrowRight size={17} className="text-[#9aa4b2] transition group-hover:translate-x-1" />
            </div>
            <div className="mt-5 text-3xl font-black text-[#173f5f]">{value ?? "—"}</div>
            <div className="mt-1 text-sm font-bold text-[#68758a]">{label}</div>
          </Link>
        ))}
      </section>

      <section className="mt-6 grid gap-5 xl:grid-cols-[1.2fr_.8fr]">
        <article className="surface p-6">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-black">Classes actives</h2>
              <p className="mt-1 text-sm text-[#748096]">Structure pédagogique actuellement disponible.</p>
            </div>
            <Link href="/app/classes" className="text-sm font-bold text-[#173f5f]">Voir tout</Link>
          </div>
          <div className="mt-5 divide-y divide-[#edf0f4]">
            {(recentClasses.data ?? []).map((item) => (
              <div className="flex items-center justify-between gap-4 py-4" key={item.id}>
                <div>
                  <div className="font-bold">{item.name}</div>
                  <div className="mt-1 text-xs text-[#748096]">{item.code || "Sans code"}</div>
                </div>
                <span className="badge badge-ok">Active</span>
              </div>
            ))}
            {!recentClasses.data?.length && !recentClasses.error && <p className="py-6 text-sm text-[#748096]">Aucune classe active.</p>}
            {recentClasses.error && <p className="py-6 text-sm text-[#a12c2c]">Classes temporairement indisponibles.</p>}
          </div>
        </article>

        <article className="surface p-6">
          <h2 className="text-xl font-black">Déploiement du produit</h2>
          <p className="mt-2 text-sm leading-6 text-[#68758a]">Le socle multi-tenant, l’authentification, les rôles et la structure scolaire sont actifs. Les modules métier sont ajoutés dans l’ordre de développement défini.</p>
          <div className="mt-5 space-y-3">
            {[
              ["Foundation", "Opérationnel", "badge-ok"],
              ["School Management", "En cours", "badge-warn"],
              ["LMS · Cours", "En cours", "badge-warn"],
              ["Assessments", "À intégrer", ""],
            ].map(([label, status, cls]) => (
              <div key={label} className="flex items-center justify-between gap-3 rounded-xl border border-[#edf0f4] p-3">
                <b className="text-sm">{label}</b><span className={`badge ${cls}`}>{status}</span>
              </div>
            ))}
          </div>
        </article>
      </section>
    </>
  );
}
