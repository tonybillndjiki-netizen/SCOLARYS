import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft, BookOpen, Eye } from "lucide-react";
import { CourseStudio } from "@/components/course-studio";
import { getAppContext } from "@/lib/data/context";
import { courseStatusLabels, statusBadgeClass } from "@/lib/data/courses";

export default async function CourseStudioPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const context = await getAppContext();
  if (!context?.organization || !context.role) return null;

  const courseResult = await context.supabase
    .from("scolaria_courses")
    .select("id, title, status, teacher_id")
    .eq("id", id)
    .eq("organization_id", context.organization.id)
    .maybeSingle();
  const course = courseResult.data;

  if (courseResult.error) redirect("/app/courses");
  if (!course) notFound();
  const canManage =
    context.permissions.includes("courses.manage") &&
    (context.role.key !== "teacher" || course.teacher_id === context.userId);
  if (!canManage) redirect(`/app/courses/${id}`);

  const { data: chapters, error } = await context.supabase
    .from("scolaria_chapters")
    .select(
      "id, title, description, objectives, ordinal, estimated_minutes, structured_zones_enabled, status, scheduled_at, updated_at",
    )
    .eq("course_id", id)
    .order("ordinal");

  return (
    <>
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <Link href={`/app/courses/${id}`} className="inline-flex items-center gap-2 text-sm font-bold text-[#173f5f]">
            <ArrowLeft size={16} /> Retour au cours
          </Link>
          <div className="mt-5 flex flex-wrap items-center gap-2">
            <span className="badge">Studio de cours</span>
            <span className={`badge ${statusBadgeClass(course.status)}`}>
              {courseStatusLabels[course.status as keyof typeof courseStatusLabels] ?? course.status}
            </span>
          </div>
          <h1 className="mt-3 text-3xl font-black">{course.title}</h1>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-[#68758a]">
            Créez, publiez et réorganisez les chapitres. Chaque changement est validé par les permissions et les politiques RLS du cours.
          </p>
        </div>
        <Link href={`/app/courses/${id}`} className="btn-secondary"><Eye size={17} /> Voir le cours</Link>
      </div>

      <div className="surface mt-6 flex flex-wrap items-center gap-4 p-5">
        <span className="grid h-11 w-11 place-items-center rounded-xl bg-[#eaf4f6] text-[#147d85]"><BookOpen size={22} /></span>
        <div>
          <div className="font-black">{chapters?.length ?? 0} chapitre(s)</div>
          <div className="mt-1 text-sm text-[#748096]">Ordre de lecture enregistré dans la base de données.</div>
        </div>
      </div>

      {error && <p className="mt-6 rounded-xl bg-[#fff0f0] p-4 text-sm text-[#a12c2c]">Chargement des chapitres impossible. Rechargez la page avant toute modification.</p>}
      {!error && <div className="mt-6"><CourseStudio courseId={id} chapters={chapters ?? []} /></div>}
    </>
  );
}
