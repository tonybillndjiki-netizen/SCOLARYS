import Link from "next/link";
import { BookOpen, ChevronLeft, ChevronRight, Clock3, Plus, Search, Users } from "lucide-react";
import { getAppContext } from "@/lib/data/context";
import {
  courseStatusLabels,
  formatDateTime,
  getCourseFormOptions,
  statusBadgeClass,
} from "@/lib/data/courses";

const pageSize = 12;
const zeroUuid = "00000000-0000-0000-0000-000000000000";
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function param(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] ?? "" : value ?? "";
}

function uuidParam(value: string | string[] | undefined) {
  const normalized = param(value);
  return uuidPattern.test(normalized) ? normalized : "";
}

function paginationHref(
  values: Record<string, string | string[] | undefined>,
  page: number,
) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) {
    const normalized = param(value);
    if (normalized && key !== "page") search.set(key, normalized);
  }
  if (page > 1) search.set("page", String(page));
  const query = search.toString();
  return query ? `/app/courses?${query}` : "/app/courses";
}

export default async function CoursesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const context = await getAppContext();
  if (!context?.organization || !context.role) return null;
  const params = await searchParams;
  const orgId = context.organization.id;
  const roleKey = context.role.key;
  const requestedPage = Number.parseInt(param(params.page), 10);
  const currentPage = Number.isFinite(requestedPage) && requestedPage > 0 ? requestedPage : 1;
  const q = param(params.q).trim().slice(0, 80);
  const selectedProgram = uuidParam(params.program);
  const selectedClass = uuidParam(params.class);
  const selectedSubject = uuidParam(params.subject);
  const selectedTeacher = uuidParam(params.teacher);
  const selectedPeriod = uuidParam(params.period);
  const requestedStatus = param(params.status);
  const selectedStatus = Object.hasOwn(courseStatusLabels, requestedStatus) ? requestedStatus : "";

  const [options, programsResult] = await Promise.all([
    getCourseFormOptions(context),
    context.supabase
      .from("scolaria_programs")
      .select("id, name")
      .eq("organization_id", orgId)
      .eq("is_active", true)
      .order("name"),
  ]);
  const programs = programsResult.data;

  const classIdsForProgram = selectedProgram
    ? options.classes.filter((item) => item.program_id === selectedProgram).map((item) => item.id)
    : [];

  let coursesQuery = context.supabase
    .from("scolaria_courses")
    .select(
      "id, title, description, class_id, subject_id, academic_period_id, teacher_id, estimated_hours, status, updated_at",
      { count: "exact" },
    )
    .eq("organization_id", orgId);

  if (roleKey === "teacher") coursesQuery = coursesQuery.eq("teacher_id", context.userId);
  if (roleKey === "student") coursesQuery = coursesQuery.eq("status", "published");
  if (q) coursesQuery = coursesQuery.ilike("title", `%${q}%`);
  if (selectedProgram) {
    coursesQuery = classIdsForProgram.length
      ? coursesQuery.in("class_id", classIdsForProgram)
      : coursesQuery.eq("id", zeroUuid);
  }
  if (selectedClass) coursesQuery = coursesQuery.eq("class_id", selectedClass);
  if (selectedSubject) coursesQuery = coursesQuery.eq("subject_id", selectedSubject);
  if (selectedTeacher) coursesQuery = coursesQuery.eq("teacher_id", selectedTeacher);
  if (selectedPeriod) coursesQuery = coursesQuery.eq("academic_period_id", selectedPeriod);
  if (selectedStatus) coursesQuery = coursesQuery.eq("status", selectedStatus);

  const from = (currentPage - 1) * pageSize;
  const { data: courses, error, count } = await coursesQuery
    .order("updated_at", { ascending: false })
    .range(from, from + pageSize - 1);

  const courseIds = (courses ?? []).map((item) => item.id);
  const teacherIds = [
    ...new Set((courses ?? []).map((item) => item.teacher_id).filter((id): id is string => Boolean(id))),
  ];
  const [chaptersResult, courseTeachersResult] = await Promise.all([
    courseIds.length
      ? context.supabase
          .from("scolaria_chapters")
          .select("course_id")
          .in("course_id", courseIds)
      : Promise.resolve({ data: [] as Array<{ course_id: string }>, error: null }),
    teacherIds.length
      ? context.supabase
          .from("scolaria_profiles")
          .select("id, display_name, first_name, last_name, email")
          .in("id", teacherIds)
      : Promise.resolve({ data: [] as Array<{ id: string; display_name: string | null; first_name: string | null; last_name: string | null; email: string | null }>, error: null }),
  ]);
  const chapters = chaptersResult.data;
  const courseTeachers = courseTeachersResult.data;
  const auxiliaryError = options.loadError || Boolean(programsResult.error || chaptersResult.error || courseTeachersResult.error);

  const classMap = new Map(options.classes.map((item) => [item.id, item]));
  const subjectMap = new Map(options.subjects.map((item) => [item.id, item]));
  const periodMap = new Map(options.periods.map((item) => [item.id, item.name]));
  const programMap = new Map((programs ?? []).map((item) => [item.id, item.name]));
  const teacherMap = new Map(
    (courseTeachers ?? []).map((profile) => [
      profile.id,
      profile.display_name ||
        [profile.first_name, profile.last_name].filter(Boolean).join(" ") ||
        profile.email ||
        "Enseignant",
    ]),
  );
  for (const teacher of options.teachers) teacherMap.set(teacher.id, teacher.name);
  const chapterCount = new Map<string, number>();
  for (const chapter of chapters ?? []) {
    chapterCount.set(chapter.course_id, (chapterCount.get(chapter.course_id) ?? 0) + 1);
  }

  const total = count ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const canCreate = context.permissions.includes("courses.manage");
  const pageTitle = roleKey === "teacher" || roleKey === "student" ? "Mes cours" : "Cours";

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <span className="badge">Phase 3 · LMS</span>
          <h1 className="mt-3 text-3xl font-black">{pageTitle}</h1>
          <p className="mt-2 text-sm text-[#68758a]">
            {total} cours accessible{total > 1 ? "s" : ""} dans {context.organization.name}.
          </p>
        </div>
        {canCreate && (
          <Link href="/app/courses/new" className="btn-primary">
            <Plus size={17} /> Créer un cours
          </Link>
        )}
      </div>

      <form className="surface mt-7 p-5" method="get">
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          <div className="field md:col-span-2">
            <label htmlFor="courses-search">Rechercher</label>
            <div className="relative">
              <Search className="pointer-events-none absolute left-3 top-3 text-[#8a96a8]" size={18} />
              <input id="courses-search" name="q" defaultValue={q} className="pl-10" placeholder="Titre du cours" />
            </div>
          </div>
          <div className="field">
            <label htmlFor="courses-program">Formation</label>
            <select id="courses-program" name="program" defaultValue={selectedProgram}>
              <option value="">Toutes</option>
              {(programs ?? []).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="courses-class">Classe</label>
            <select id="courses-class" name="class" defaultValue={selectedClass}>
              <option value="">Toutes</option>
              {options.classes.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="courses-subject">Matière</label>
            <select id="courses-subject" name="subject" defaultValue={selectedSubject}>
              <option value="">Toutes</option>
              {options.subjects.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="courses-teacher">Enseignant</label>
            <select id="courses-teacher" name="teacher" defaultValue={selectedTeacher}>
              <option value="">Tous</option>
              {options.teachers.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="courses-period">Période</label>
            <select id="courses-period" name="period" defaultValue={selectedPeriod}>
              <option value="">Toutes</option>
              {options.periods.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="courses-status">Statut</label>
            <select id="courses-status" name="status" defaultValue={selectedStatus}>
              <option value="">Tous</option>
              {Object.entries(courseStatusLabels).map(([value, label]) => (
                <option key={value} value={value}>{label}</option>
              ))}
            </select>
          </div>
        </div>
        <div className="mt-5 flex flex-wrap gap-3">
          <button className="btn-primary" type="submit"><Search size={17} /> Appliquer les filtres</button>
          <Link href="/app/courses" className="btn-secondary">Réinitialiser</Link>
        </div>
      </form>

      {error && (
        <p className="mt-6 rounded-xl bg-[#fff0f0] p-4 text-sm text-[#a12c2c]">
          Chargement des cours impossible. Rechargez la page ou réessayez dans quelques instants.
        </p>
      )}

      {auxiliaryError && !error && (
        <p className="mt-6 rounded-xl bg-[#fff9e8] p-4 text-sm text-[#73540d]" role="status">
          Certaines informations complémentaires sont temporairement indisponibles ; elles sont affichées par un tiret plutôt que remplacées par une valeur supposée.
        </p>
      )}

      <section className="mt-7 grid gap-5 lg:grid-cols-2 2xl:grid-cols-3">
        {(courses ?? []).map((course) => {
          const classItem = classMap.get(course.class_id);
          const subject = subjectMap.get(course.subject_id);
          const statusLabel = courseStatusLabels[course.status as keyof typeof courseStatusLabels] ?? course.status;
          return (
            <Link href={`/app/courses/${course.id}`} className="surface group flex min-h-72 flex-col p-6 transition hover:-translate-y-0.5 hover:shadow-xl" key={course.id}>
              <div className="flex items-start justify-between gap-4">
                <span className="grid h-11 w-11 place-items-center rounded-xl bg-[#eaf4f6] text-[#147d85]">
                  <BookOpen size={22} />
                </span>
                <span className={`badge ${statusBadgeClass(course.status)}`}>{statusLabel}</span>
              </div>
              <div className="mt-5 text-xs font-black uppercase tracking-[.08em] text-[#147d85]">
                {subject?.name ?? "Matière"}
              </div>
              <h2 className="mt-2 text-xl font-black group-hover:text-[#0f7379]">{course.title}</h2>
              <p className="mt-3 line-clamp-2 text-sm leading-6 text-[#68758a]">
                {course.description || "Aucune description."}
              </p>
              <div className="mt-auto grid gap-2 border-t border-[#edf0f4] pt-5 text-sm text-[#5e6b7f] sm:grid-cols-2">
                <span className="flex items-center gap-2"><Users size={15} /> {classItem?.name ?? "Classe"}</span>
                <span>{classItem ? programMap.get(classItem.program_id) ?? "Formation" : "Formation"}</span>
                <span>{course.teacher_id ? teacherMap.get(course.teacher_id) ?? (auxiliaryError ? "—" : "Enseignant indisponible") : "Non attribué"}</span>
                <span>{periodMap.get(course.academic_period_id ?? "") ?? "Toute l’année"}</span>
                <span className="flex items-center gap-2"><BookOpen size={15} /> {chaptersResult.error ? "—" : chapterCount.get(course.id) ?? 0} chapitre(s)</span>
                <span className="flex items-center gap-2"><Clock3 size={15} /> {formatDateTime(course.updated_at, context.timeZone)}</span>
              </div>
              {roleKey === "student" && (
                <span className="mt-4 text-xs font-bold text-[#748096]">Suivi de progression : à venir</span>
              )}
            </Link>
          );
        })}
      </section>

      {!courses?.length && !error && (
        <div className="surface mt-7 p-8 text-center">
          <h2 className="text-lg font-black">Aucun cours ne correspond</h2>
          <p className="mt-2 text-sm text-[#68758a]">
            Ajustez les filtres{canCreate ? " ou créez le premier cours de cette sélection" : ""}.
          </p>
          {canCreate && <Link href="/app/courses/new" className="btn-primary mt-5"><Plus size={17} /> Créer un cours</Link>}
        </div>
      )}

      {totalPages > 1 && (
        <nav className="mt-7 flex items-center justify-center gap-3" aria-label="Pagination des cours">
          {currentPage > 1 ? (
            <Link className="btn-secondary" href={paginationHref(params, currentPage - 1)}><ChevronLeft size={17} /> Précédent</Link>
          ) : <span className="btn-secondary pointer-events-none opacity-50"><ChevronLeft size={17} /> Précédent</span>}
          <span className="text-sm font-bold text-[#5e6b7f]">Page {currentPage} sur {totalPages}</span>
          {currentPage < totalPages ? (
            <Link className="btn-secondary" href={paginationHref(params, currentPage + 1)}>Suivant <ChevronRight size={17} /></Link>
          ) : <span className="btn-secondary pointer-events-none opacity-50">Suivant <ChevronRight size={17} /></span>}
        </nav>
      )}
    </>
  );
}
