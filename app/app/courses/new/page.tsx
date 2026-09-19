import { redirect } from "next/navigation";
import { CourseForm } from "@/components/course-form";
import { getAppContext } from "@/lib/data/context";
import { getCourseFormOptions } from "@/lib/data/courses";
import { createCourseAction } from "../actions";

export default async function NewCoursePage() {
  const context = await getAppContext();
  if (!context?.organization || !context.role) redirect("/app/courses");
  if (!context.permissions.includes("courses.manage")) redirect("/app/courses");

  const options = await getCourseFormOptions(context);

  return (
    <CourseForm
      action={createCourseAction}
      options={options}
      mode="create"
      currentUserId={context.userId}
      teacherLocked={context.role.key === "teacher"}
    />
  );
}
