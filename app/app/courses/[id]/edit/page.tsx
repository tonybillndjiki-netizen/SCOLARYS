import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { CourseForm } from "@/components/course-form";
import { getAppContext } from "@/lib/data/context";
import { getCourseFormOptions } from "@/lib/data/courses";
import { updateCourseAction } from "../../actions";

export default async function EditCoursePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const context = await getAppContext();
  if (!context?.organization || !context.role) redirect("/app/courses");
  if (!context.permissions.includes("courses.manage")) redirect(`/app/courses/${id}`);

  const [courseResult, competencyLinksResult, options] = await Promise.all([
    context.supabase
      .from("scolaria_courses")
      .select(
        "id, title, description, objectives, class_id, subject_id, academic_period_id, teacher_id, estimated_hours, status",
      )
      .eq("id", id)
      .eq("organization_id", context.organization.id)
      .maybeSingle(),
    context.supabase
      .from("scolaria_course_competencies")
      .select("competency_id")
      .eq("course_id", id),
    getCourseFormOptions(context),
  ]);
  const course = courseResult.data;
  const competencyLinks = competencyLinksResult.data;

  if (courseResult.error) {
    return (
      <div className="surface p-7">
        <h1 className="text-xl font-black">Modification temporairement indisponible</h1>
        <p className="mt-2 text-sm text-[#68758a]">Le cours n’a pas pu être chargé sans risque de perte de données. Rechargez la page puis réessayez.</p>
        <Link href={`/app/courses/${id}`} className="btn-secondary mt-5">Retour au cours</Link>
      </div>
    );
  }
  if (!course) notFound();
  if (context.role.key === "teacher" && course.teacher_id !== context.userId) {
    redirect(`/app/courses/${id}`);
  }

  const action = updateCourseAction.bind(null, id);

  return (
    <CourseForm
      action={action}
      options={{ ...options, loadError: options.loadError || Boolean(competencyLinksResult.error) }}
      mode="edit"
      currentUserId={context.userId}
      teacherLocked={context.role.key === "teacher"}
      values={{
        title: course.title,
        description: course.description,
        objectives: course.objectives,
        classId: course.class_id,
        subjectId: course.subject_id,
        academicPeriodId: course.academic_period_id,
        teacherId: course.teacher_id,
        estimatedHours: course.estimated_hours,
        status: course.status,
        competencyIds: (competencyLinks ?? []).map((item) => item.competency_id),
      }}
    />
  );
}
