import Link from "next/link";
import { notFound } from "next/navigation";
import {
  ArrowLeft,
  BookOpen,
  CalendarDays,
  Clock3,
  FileText,
  GraduationCap,
  Pencil,
  Settings2,
  UserRound,
} from "lucide-react";
import { getAppContext } from "@/lib/data/context";
import { CoursePublicationActions } from "@/components/course-publication-actions";
import {
  chapterStatusLabels,
  courseStatusLabels,
  formatDateTime,
  statusBadgeClass,
} from "@/lib/data/courses";

export default async function CourseDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const context = await getAppContext();
  if (!context?.organization || !context.role) return null;

  const courseResult = await context.supabase
    .from("scolaria_courses")
    .select(
      "id, title, description, objectives, class_id, subject_id, academic_period_id, teacher_id, estimated_hours, status, published_at, created_by, created_at, updated_at",
    )
    .eq("id", id)
    .eq("organization_id", context.organization.id)
    .maybeSingle();
  const course = courseResult.data;

  if (courseResult.error) {
    return (
      <div className="surface p-7">
        <h1 className="text-xl font-black">Cours temporairement indisponible</h1>
        <p className="mt-2 text-sm text-[#68758a]">Les données n’ont pas pu être chargées de façon fiable. Rechargez la page puis réessayez.</p>
        <Link href="/app/courses" className="btn-secondary mt-5">Retour aux cours</Link>
      </div>
    );
  }
  if (!course) notFound();

  const [classResult, subjectResult, periodResult, teacherResult, chaptersResult, linksResult, resourcesResult, lessonsResult] =
    await Promise.all([
      context.supabase
        .from("scolaria_classes")
        .select("id, name, code, program_id")
        .eq("id", course.class_id)
        .maybeSingle(),
      context.supabase
        .from("scolaria_subjects")
        .select("id, name, code")
        .eq("id", course.subject_id)
        .maybeSingle(),
      course.academic_period_id
        ? context.supabase
            .from("scolaria_academic_periods")
            .select("id, name")
            .eq("id", course.academic_period_id)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      course.teacher_id
        ? context.supabase
            .from("scolaria_profiles")
            .select("id, display_name, first_name, last_name, email")
            .eq("id", course.teacher_id)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      context.supabase
        .from("scolaria_chapters")
        .select("id, title, description, ordinal, estimated_minutes, structured_zones_enabled, status, scheduled_at, updated_at")
        .eq("course_id", id)
        .order("ordinal"),
      context.supabase
        .from("scolaria_course_competencies")
        .select("competency_id")
        .eq("course_id", id),
      context.supabase
        .from("scolaria_resources")
        .select("id, title, resource_type, status, chapter_id")
        .eq("course_id", id)
        .order("ordinal")
        .limit(8),
      context.supabase
        .from("scolaria_lessons")
        .select("id, title, starts_at, ends_at, delivery_mode, status, room")
        .eq("course_id", id)
        .gte("starts_at", new Date().toISOString())
        .neq("status", "cancelled")
        .order("starts_at")
        .limit(8),
    ]);

  const competencyIds = (linksResult.data ?? []).map((item) => item.competency_id);
  const [competenciesResult, programResult] = await Promise.all([
    competencyIds.length
      ? context.supabase
          .from("scolaria_competencies")
          .select("id, code, name")
          .in("id", competencyIds)
          .order("ordinal")
      : Promise.resolve({ data: [] as Array<{ id: string; code: string | null; name: string }>, error: null }),
    classResult.data?.program_id
      ? context.supabase
          .from("scolaria_programs")
          .select("id, name")
          .eq("id", classResult.data.program_id)
          .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
  ]);
  const competencies = competenciesResult.data;
  const program = programResult.data;
  const auxiliaryError = Boolean(
    classResult.error ||
    subjectResult.error ||
    periodResult.error ||
    teacherResult.error ||
    chaptersResult.error ||
    linksResult.error ||
    resourcesResult.error ||
    lessonsResult.error ||
    competenciesResult.error ||
    programResult.error
  );

  const teacher = teacherResult.data;
  const teacherName = teacher
    ? teacher.display_name ||
      [teacher.first_name, teacher.last_name].filter(Boolean).join(" ") ||
      teacher.email ||
      "Enseignant"
    : "Non attribué";
  const canManage =
    context.permissions.includes("courses.manage") &&
    (context.role.key !== "teacher" || course.teacher_id === context.userId);
  const statusLabel = courseStatusLabels[course.status as keyof typeof courseStatusLabels] ?? course.status;

  return (
    <>
      <Link href="/app/courses" className="inline-flex items-center gap-2 text-sm font-bold text-[#173f5f]">
        <ArrowLeft size={16} /> Retour aux cours
      </Link>

      <section className="surface mt-6 overflow-hidden">
        <div className="border-b border-[#e5eaf0] bg-gradient-to-br from-[#102f49] to-[#176978] p-6 text-white sm:p-8">
          <div className="flex flex-wrap items-start justify-between gap-5">
            <div className="max-w-4xl">
              <div className="flex flex-wrap items-center gap-2">
                <span className="badge bg-white/15 text-white">{subjectResult.data?.name ?? "Matière"}</span>
                <span className={`badge ${course.status === "published" ? "badge-ok" : "bg-white/15 text-white"}`}>{statusLabel}</span>
              </div>
              <h1 className="mt-5 text-3xl font-black tracking-[-.035em] sm:text-4xl">{course.title}</h1>
              <p className="mt-3 max-w-3xl text-sm leading-7 text-white/75">
                {course.description || "Aucune description n’a encore été ajoutée."}
              </p>
            </div>
            {canManage && (
              <div className="flex flex-wrap gap-3">
                <Link href={`/app/courses/${id}/edit`} className="btn-secondary"><Pencil size={17} /> Modifier</Link>
                <Link href={`/app/courses/${id}/studio`} className="btn-primary bg-[#15a6a6]"><Settings2 size={17} /> Studio de cours</Link>
              </div>
            )}
          </div>
        </div>

        <div className="grid gap-4 p-6 sm:grid-cols-2 sm:p-8 xl:grid-cols-4">
          <div className="rounded-2xl border border-[#edf0f4] p-4">
            <GraduationCap className="text-[#147d85]" size={20} />
            <div className="mt-3 text-xs font-black uppercase tracking-[.08em] text-[#748096]">Formation & classe</div>
            <div className="mt-2 font-bold">{program?.name ?? "Formation"}</div>
            <div className="mt-1 text-sm text-[#68758a]">{classResult.data?.name ?? "Classe"}</div>
          </div>
          <div className="rounded-2xl border border-[#edf0f4] p-4">
            <UserRound className="text-[#147d85]" size={20} />
            <div className="mt-3 text-xs font-black uppercase tracking-[.08em] text-[#748096]">Enseignant</div>
            <div className="mt-2 font-bold">{teacherName}</div>
            <div className="mt-1 text-sm text-[#68758a]">{periodResult.data?.name ?? "Toute l’année"}</div>
          </div>
          <div className="rounded-2xl border border-[#edf0f4] p-4">
            <Clock3 className="text-[#147d85]" size={20} />
            <div className="mt-3 text-xs font-black uppercase tracking-[.08em] text-[#748096]">Durée & contenu</div>
            <div className="mt-2 font-bold">{course.estimated_hours != null ? `${course.estimated_hours} h` : "Non définie"}</div>
            <div className="mt-1 text-sm text-[#68758a]">{chaptersResult.data?.length ?? 0} chapitre(s)</div>
          </div>
          <div className="rounded-2xl border border-[#edf0f4] p-4">
            <CalendarDays className="text-[#147d85]" size={20} />
            <div className="mt-3 text-xs font-black uppercase tracking-[.08em] text-[#748096]">Dernière modification</div>
            <div className="mt-2 font-bold">{formatDateTime(course.updated_at, context.timeZone)}</div>
            <div className="mt-1 text-sm text-[#68758a]">Publication : {formatDateTime(course.published_at, context.timeZone)}</div>
          </div>
        </div>
      </section>

      {auxiliaryError && (
        <p className="mt-5 rounded-xl bg-[#fff9e8] p-4 text-sm text-[#73540d]" role="status">
          Certaines informations liées au cours sont temporairement indisponibles. Aucun contenu manquant n’est remplacé par une donnée fictive.
        </p>
      )}

      {canManage && (
        <section className="surface mt-5 flex flex-wrap items-center justify-between gap-4 p-5">
          <div>
            <h2 className="font-black">Publication du cours</h2>
            <p className="mt-1 text-sm text-[#68758a]">Les étudiants accèdent uniquement au cours et aux chapitres publiés.</p>
          </div>
          <CoursePublicationActions courseId={id} currentStatus={course.status} />
        </section>
      )}

      <section className="mt-6 grid gap-5 xl:grid-cols-[1.35fr_.65fr]">
        <article className="surface p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-black">Chapitres</h2>
              <p className="mt-1 text-sm text-[#748096]">Parcours pédagogique dans l’ordre de lecture.</p>
            </div>
            {canManage && <Link href={`/app/courses/${id}/studio#new-chapter`} className="btn-primary">Ajouter un chapitre</Link>}
          </div>
          <div className="mt-5 space-y-3">
            {(chaptersResult.data ?? []).map((chapter) => (
              <div key={chapter.id} className="flex flex-wrap items-start justify-between gap-4 rounded-2xl border border-[#edf0f4] p-4">
                <div className="flex min-w-0 items-start gap-4">
                  <span className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-[#eef4f8] text-sm font-black text-[#173f5f]">{chapter.ordinal}</span>
                  <div>
                    <h3 className="font-black">{chapter.title}</h3>
                    <p className="mt-1 line-clamp-2 text-sm leading-6 text-[#68758a]">{chapter.description || "Description à compléter."}</p>
                    <div className="mt-2 flex flex-wrap gap-3 text-xs font-bold text-[#748096]">
                      <span>{chapter.estimated_minutes != null ? `${chapter.estimated_minutes} min` : "Durée libre"}</span>
                      <span>{chapter.structured_zones_enabled ? "Zones Avant · Pendant · Après" : "Zone unique"}</span>
                    </div>
                  </div>
                </div>
                <span className={`badge ${statusBadgeClass(chapter.status)}`}>
                  {chapterStatusLabels[chapter.status as keyof typeof chapterStatusLabels] ?? chapter.status}
                </span>
              </div>
            ))}
            {!chaptersResult.data?.length && !chaptersResult.error && (
              <div className="rounded-2xl border border-dashed border-[#d8e0e9] p-7 text-center text-sm text-[#748096]">
                Aucun chapitre visible pour le moment.
              </div>
            )}
            {chaptersResult.error && <p className="text-sm text-[#a12c2c]">Chapitres temporairement indisponibles.</p>}
          </div>
        </article>

        <aside className="space-y-5">
          <article className="surface p-6">
            <h2 className="text-lg font-black">Objectifs pédagogiques</h2>
            <p className="mt-3 whitespace-pre-line text-sm leading-7 text-[#68758a]">
              {course.objectives || "Objectifs à compléter."}
            </p>
          </article>
          <article className="surface p-6">
            <h2 className="text-lg font-black">Compétences</h2>
            <div className="mt-4 flex flex-wrap gap-2">
              {(competencies ?? []).map((item) => (
                <span key={item.id} className="badge">{item.code ? `${item.code} · ` : ""}{item.name}</span>
              ))}
              {!competencies?.length && !competenciesResult.error && <span className="text-sm text-[#748096]">Aucune compétence associée.</span>}
              {competenciesResult.error && <span className="text-sm text-[#a12c2c]">Compétences temporairement indisponibles.</span>}
            </div>
          </article>
          {context.role.key === "student" && (
            <article className="surface p-6">
              <h2 className="text-lg font-black">Ma progression</h2>
              <p className="mt-2 text-sm leading-6 text-[#68758a]">
                Le suivi de progression n’est pas encore activé pour ce cours. Aucun pourcentage n’est simulé.
              </p>
            </article>
          )}
        </aside>
      </section>

      <section className="mt-6 grid gap-5 lg:grid-cols-2">
        <article className="surface p-6">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-black">Ressources</h2>
              <p className="mt-1 text-sm text-[#748096]">Documents et liens visibles selon votre rôle.</p>
            </div>
            <FileText className="text-[#147d85]" size={22} />
          </div>
          <div className="mt-5 space-y-3">
            {(resourcesResult.data ?? []).map((resource) => (
              <div key={resource.id} className="flex items-center justify-between gap-3 rounded-xl border border-[#edf0f4] p-3">
                <b className="text-sm">{resource.title}</b>
                <span className={`badge ${statusBadgeClass(resource.status)}`}>{resource.resource_type} · {resource.status === "published" ? "publié" : resource.status === "archived" ? "archivé" : "brouillon"}</span>
              </div>
            ))}
            {!resourcesResult.data?.length && !resourcesResult.error && <p className="text-sm text-[#748096]">Aucune ressource visible.</p>}
            {resourcesResult.error && <p className="text-sm text-[#a12c2c]">Ressources temporairement indisponibles.</p>}
          </div>
          {canManage && <p className="mt-5 text-xs font-bold text-[#8b6410]">Ajout de ressources : prochain incrément LMS.</p>}
        </article>

        <article className="surface p-6">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-black">Séances</h2>
              <p className="mt-1 text-sm text-[#748096]">Prochaines séances rattachées à ce cours.</p>
            </div>
            <CalendarDays className="text-[#147d85]" size={22} />
          </div>
          <div className="mt-5 space-y-3">
            {(lessonsResult.data ?? []).map((lesson) => (
              <div key={lesson.id} className="rounded-xl border border-[#edf0f4] p-3">
                <div className="flex items-center justify-between gap-3"><b className="text-sm">{lesson.title}</b><span className="badge">{lesson.delivery_mode} · {lesson.status === "scheduled" ? "planifiée" : "terminée"}</span></div>
                <div className="mt-2 text-xs text-[#748096]">{formatDateTime(lesson.starts_at, context.timeZone)}{lesson.room ? ` · ${lesson.room}` : ""}</div>
              </div>
            ))}
            {!lessonsResult.data?.length && !lessonsResult.error && <p className="text-sm text-[#748096]">Aucune séance à venir.</p>}
            {lessonsResult.error && <p className="text-sm text-[#a12c2c]">Séances temporairement indisponibles.</p>}
          </div>
          {canManage && <p className="mt-5 text-xs font-bold text-[#8b6410]">Programmation de séances : prochain incrément LMS.</p>}
        </article>
      </section>
    </>
  );
}
