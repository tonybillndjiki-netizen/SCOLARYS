"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getAppContext } from "@/lib/data/context";

type ActionState = {
  status: "idle" | "success" | "error";
  message: string;
};

type CourseStatus = "draft" | "published" | "archived";
type ChapterStatus = CourseStatus | "scheduled";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function field(formData: FormData, name: string) {
  return String(formData.get(name) ?? "").trim();
}

function nullableUuid(value: string) {
  if (!value) return null;
  return uuidPattern.test(value) ? value : "INVALID";
}

function nullableNumber(value: string) {
  if (!value) return null;
  const parsed = Number(value.replace(",", "."));
  return Number.isFinite(parsed) ? parsed : Number.NaN;
}

function isCourseStatus(value: string): value is CourseStatus {
  return ["draft", "published", "archived"].includes(value);
}

function isChapterStatus(value: string): value is ChapterStatus {
  return ["draft", "scheduled", "published", "archived"].includes(value);
}

function messageForDatabaseError(message: string) {
  if (message.includes("COURSE_TITLE_INVALID")) return "Le titre doit contenir entre 3 et 160 caractères.";
  if (message.includes("COURSE_DURATION_INVALID")) return "La durée estimée doit être un nombre positif.";
  if (message.includes("COURSE_TEACHER_INVALID")) return "L’enseignant choisi n’est pas un enseignant actif de cet établissement.";
  if (message.includes("COURSE_SUBJECT_INVALID")) return "La matière choisie est inactive ou inaccessible.";
  if (message.includes("COURSE_CLASS_SUBJECT_INVALID")) return "Cette matière n’est pas affectée à la classe choisie.";
  if (message.includes("COURSE_PERIOD_INVALID")) return "La période académique choisie est invalide.";
  if (message.includes("COURSE_COMPETENCY_INVALID")) return "Une compétence sélectionnée est invalide ou inactive.";
  if (message.includes("COURSE_ACCESS_DENIED")) return "Vous n’avez pas l’autorisation de gérer ce cours.";
  if (message.includes("CHAPTER_TITLE_INVALID")) return "Le titre du chapitre doit contenir entre 2 et 160 caractères.";
  if (message.includes("CHAPTER_DURATION_INVALID")) return "La durée du chapitre doit être positive.";
  if (message.includes("CHAPTER_SCHEDULE_INVALID")) return "Une date de publication est requise pour un chapitre programmé.";
  if (message.includes("CHAPTER_STATUS_INVALID")) return "Le statut du chapitre est invalide.";
  if (message.includes("CHAPTER_NOT_FOUND")) return "Ce chapitre n’existe plus ou n’est plus accessible.";
  if (message.includes("duplicate key")) return "Cette opération créerait un doublon.";
  return "L’opération n’a pas pu être enregistrée. Vérifiez les données et réessayez.";
}

async function courseContext() {
  const context = await getAppContext();
  if (!context?.organization || !context.role) return null;
  return {
    ...context,
    organization: context.organization,
    role: context.role,
  };
}

async function canManageCourse(courseId: string) {
  const context = await courseContext();
  if (!context || !context.permissions.includes("courses.manage") || !uuidPattern.test(courseId)) {
    return null;
  }

  const { data: course } = await context.supabase
    .from("scolaria_courses")
    .select("id, teacher_id, status, published_at")
    .eq("id", courseId)
    .eq("organization_id", context.organization.id)
    .maybeSingle();

  if (!course) return null;
  if (context.role.key === "teacher" && course.teacher_id !== context.userId) return null;
  return { context, course };
}

function parseCourseForm(formData: FormData) {
  const title = field(formData, "title");
  const classId = field(formData, "classId");
  const subjectId = field(formData, "subjectId");
  const periodId = nullableUuid(field(formData, "academicPeriodId"));
  const teacherId = nullableUuid(field(formData, "teacherId"));
  const estimatedHours = nullableNumber(field(formData, "estimatedHours"));
  const competencyIds = formData.getAll("competencyIds").map((value) => String(value));
  const description = field(formData, "description");
  const objectives = field(formData, "objectives");

  if (title.length < 3 || title.length > 160) {
    return { ok: false, error: "Le titre doit contenir entre 3 et 160 caractères." } as const;
  }
  if (!uuidPattern.test(classId) || !uuidPattern.test(subjectId)) {
    return { ok: false, error: "Sélectionnez une classe et une matière valides." } as const;
  }
  if (periodId === "INVALID" || teacherId === "INVALID") {
    return { ok: false, error: "Une sélection du formulaire est invalide." } as const;
  }
  if (estimatedHours !== null && (Number.isNaN(estimatedHours) || estimatedHours < 0 || estimatedHours > 99999)) {
    return { ok: false, error: "La durée estimée doit être comprise entre 0 et 99 999 heures." } as const;
  }
  if (competencyIds.some((value) => !uuidPattern.test(value))) {
    return { ok: false, error: "Une compétence sélectionnée est invalide." } as const;
  }
  if (description.length > 5000 || objectives.length > 5000) {
    return { ok: false, error: "La description et les objectifs sont limités à 5 000 caractères." } as const;
  }

  return {
    ok: true,
    value: {
      title,
      classId,
      subjectId,
      periodId,
      teacherId,
      estimatedHours,
      competencyIds,
      description: description || null,
      objectives: objectives || null,
    },
  } as const;
}

export async function createCourseAction(
  _previousState: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const context = await courseContext();
  if (!context || !context.permissions.includes("courses.manage")) {
    return { status: "error", message: "Permission courses.manage requise." };
  }

  const parsed = parseCourseForm(formData);
  if (!parsed.ok) return { status: "error", message: parsed.error };
  const values = parsed.value;
  const teacherId = context.role.key === "teacher" ? context.userId : values.teacherId;

  const { data, error } = await context.supabase.rpc("scolaria_create_course", {
    course_title: values.title,
    course_class_id: values.classId,
    course_subject_id: values.subjectId,
    course_description: values.description,
    course_academic_period_id: values.periodId,
    course_teacher_id: teacherId,
    course_objectives: values.objectives,
    course_estimated_hours: values.estimatedHours,
    competency_ids: values.competencyIds,
  });

  if (error || !data) {
    return {
      status: "error",
      message: messageForDatabaseError(error?.message ?? "COURSE_CREATE_FAILED"),
    };
  }

  revalidatePath("/app/courses");
  redirect(`/app/courses/${data}`);
}

export async function updateCourseAction(
  courseId: string,
  _previousState: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const managed = await canManageCourse(courseId);
  if (!managed) return { status: "error", message: "Vous ne pouvez pas modifier ce cours." };

  const parsed = parseCourseForm(formData);
  if (!parsed.ok) return { status: "error", message: parsed.error };
  const values = parsed.value;
  const rawStatus = field(formData, "status");
  if (!isCourseStatus(rawStatus)) {
    return { status: "error", message: "Le statut du cours est invalide." };
  }
  const status = rawStatus;
  const teacherId = managed.context.role.key === "teacher" ? managed.context.userId : values.teacherId;

  const { data, error } = await managed.context.supabase.rpc("scolaria_update_course", {
    target_course_id: courseId,
    course_title: values.title,
    course_class_id: values.classId,
    course_subject_id: values.subjectId,
    course_description: values.description,
    course_academic_period_id: values.periodId,
    course_teacher_id: teacherId,
    course_objectives: values.objectives,
    course_estimated_hours: values.estimatedHours,
    course_status: status,
    competency_ids: values.competencyIds,
  });

  if (error || !data) {
    return {
      status: "error",
      message: messageForDatabaseError(error?.message ?? "COURSE_UPDATE_FAILED"),
    };
  }

  revalidatePath("/app/courses");
  revalidatePath(`/app/courses/${courseId}`);
  revalidatePath(`/app/courses/${courseId}/studio`);
  redirect(`/app/courses/${courseId}`);
}

export async function setCourseStatusAction(
  courseId: string,
  _previousState: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const rawStatus = field(formData, "status");
  if (!isCourseStatus(rawStatus)) {
    return { status: "error", message: "Le statut demandé est invalide." };
  }
  const status = rawStatus;
  const managed = await canManageCourse(courseId);
  if (!managed) {
    return { status: "error", message: "Vous ne pouvez pas modifier ce cours." };
  }

  const update: { status: CourseStatus; published_at?: string | null } = { status };
  if (status === "published" && !managed.course.published_at) {
    update.published_at = new Date().toISOString();
  }
  if (status === "draft") update.published_at = null;

  const { data, error } = await managed.context.supabase
    .from("scolaria_courses")
    .update(update)
    .eq("id", courseId)
    .eq("organization_id", managed.context.organization.id)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    return { status: "error", message: messageForDatabaseError(error?.message ?? "COURSE_UPDATE_FAILED") };
  }

  revalidatePath("/app/courses");
  revalidatePath(`/app/courses/${courseId}`);
  revalidatePath(`/app/courses/${courseId}/studio`);
  return { status: "success", message: `Statut mis à jour : ${status === "published" ? "cours publié" : status === "draft" ? "brouillon" : status === "archived" ? "cours archivé" : "publication programmée"}.` };
}

function parseChapterForm(formData: FormData) {
  const title = field(formData, "title");
  const statusValue = field(formData, "status");
  if (!isChapterStatus(statusValue)) {
    return { ok: false, error: "Le statut du chapitre est invalide." } as const;
  }
  const status: ChapterStatus = statusValue;
  const duration = nullableNumber(field(formData, "estimatedMinutes"));
  const scheduledValue = field(formData, "scheduledAt");
  const scheduledDate = scheduledValue ? new Date(scheduledValue) : null;
  const description = field(formData, "description");
  const objectives = field(formData, "objectives");

  if (title.length < 2 || title.length > 160) {
    return { ok: false, error: "Le titre doit contenir entre 2 et 160 caractères." } as const;
  }
  if (duration !== null && (Number.isNaN(duration) || duration < 0 || !Number.isInteger(duration))) {
    return { ok: false, error: "La durée doit être un nombre entier positif de minutes." } as const;
  }
  if (status === "scheduled" && (!scheduledDate || Number.isNaN(scheduledDate.getTime()))) {
    return { ok: false, error: "Indiquez une date valide pour le chapitre programmé." } as const;
  }
  if (description.length > 5000 || objectives.length > 5000) {
    return { ok: false, error: "La description et les objectifs sont limités à 5 000 caractères." } as const;
  }

  return {
    ok: true,
    value: {
      title,
      status,
      duration,
      description: description || null,
      objectives: objectives || null,
      structuredZonesEnabled: formData.get("structuredZonesEnabled") === "on",
      scheduledAt: scheduledDate?.toISOString() ?? null,
    },
  } as const;
}

export async function createChapterAction(
  courseId: string,
  _previousState: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const managed = await canManageCourse(courseId);
  if (!managed) return { status: "error", message: "Vous ne pouvez pas modifier ce cours." };
  const parsed = parseChapterForm(formData);
  if (!parsed.ok) return { status: "error", message: parsed.error };
  const values = parsed.value;

  const { data, error } = await managed.context.supabase.rpc("scolaria_create_chapter", {
    target_course_id: courseId,
    chapter_title: values.title,
    chapter_description: values.description,
    chapter_objectives: values.objectives,
    chapter_estimated_minutes: values.duration,
    chapter_structured_zones_enabled: values.structuredZonesEnabled,
    chapter_scheduled_at: values.scheduledAt,
    chapter_status: values.status,
  });

  if (error || !data) {
    return { status: "error", message: messageForDatabaseError(error?.message ?? "CHAPTER_CREATE_FAILED") };
  }
  revalidatePath(`/app/courses/${courseId}`);
  revalidatePath(`/app/courses/${courseId}/studio`);
  revalidatePath("/app/courses");
  return { status: "success", message: "Chapitre ajouté." };
}

export async function updateChapterAction(
  courseId: string,
  chapterId: string,
  _previousState: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const managed = await canManageCourse(courseId);
  if (!managed || !uuidPattern.test(chapterId)) {
    return { status: "error", message: "Chapitre inaccessible." };
  }
  const parsed = parseChapterForm(formData);
  if (!parsed.ok) return { status: "error", message: parsed.error };
  const values = parsed.value;

  const { data: current, error: currentError } = await managed.context.supabase
    .from("scolaria_chapters")
    .select("published_at")
    .eq("id", chapterId)
    .eq("course_id", courseId)
    .eq("organization_id", managed.context.organization.id)
    .maybeSingle();

  if (currentError || !current) {
    return { status: "error", message: "Ce chapitre n’existe plus ou n’est plus accessible." };
  }

  const { data, error } = await managed.context.supabase
    .from("scolaria_chapters")
    .update({
      title: values.title,
      description: values.description,
      objectives: values.objectives,
      estimated_minutes: values.duration,
      structured_zones_enabled: values.structuredZonesEnabled,
      status: values.status,
      scheduled_at: values.status === "scheduled" ? values.scheduledAt : null,
      published_at:
        values.status === "published"
          ? current?.published_at || new Date().toISOString()
          : values.status === "draft"
            ? null
            : current?.published_at ?? null,
    })
    .eq("id", chapterId)
    .eq("course_id", courseId)
    .eq("organization_id", managed.context.organization.id)
    .select("id")
    .maybeSingle();

  if (error || !data) {
    return { status: "error", message: messageForDatabaseError(error?.message ?? "CHAPTER_UPDATE_FAILED") };
  }
  revalidatePath(`/app/courses/${courseId}`);
  revalidatePath(`/app/courses/${courseId}/studio`);
  revalidatePath("/app/courses");
  return { status: "success", message: "Chapitre enregistré." };
}

export async function moveChapterAction(
  courseId: string,
  chapterId: string,
  direction: "up" | "down",
): Promise<ActionState> {
  const managed = await canManageCourse(courseId);
  if (!managed || !uuidPattern.test(chapterId)) {
    return { status: "error", message: "Chapitre inaccessible." };
  }

  const { data, error } = await managed.context.supabase.rpc("scolaria_move_chapter", {
    target_chapter_id: chapterId,
    move_direction: direction,
  });
  if (error) return { status: "error", message: messageForDatabaseError(error.message) };
  if (!data) return { status: "error", message: "Le chapitre est déjà à cette extrémité du parcours." };

  revalidatePath(`/app/courses/${courseId}`);
  revalidatePath(`/app/courses/${courseId}/studio`);
  return { status: "success", message: "Ordre mis à jour." };
}

export async function deleteChapterAction(
  courseId: string,
  chapterId: string,
): Promise<ActionState> {
  const managed = await canManageCourse(courseId);
  if (!managed || !uuidPattern.test(chapterId)) {
    return { status: "error", message: "Chapitre inaccessible." };
  }

  const { data, error } = await managed.context.supabase.rpc("scolaria_delete_chapter", {
    target_chapter_id: chapterId,
  });

  if (error || data == null) {
    return { status: "error", message: messageForDatabaseError(error?.message ?? "CHAPTER_DELETE_FAILED") };
  }
  revalidatePath(`/app/courses/${courseId}`);
  revalidatePath(`/app/courses/${courseId}/studio`);
  revalidatePath("/app/courses");
  return {
    status: "success",
    message: data > 0
      ? `Chapitre et ${data} ressource${data > 1 ? "s" : ""} associée${data > 1 ? "s" : ""} supprimés.`
      : "Chapitre supprimé et parcours renuméroté.",
  };
}
