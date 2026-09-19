"use client";

import Link from "next/link";
import { useActionState, useMemo, useState } from "react";
import { ArrowLeft, Save } from "lucide-react";
import type { CourseFormOptions } from "@/lib/data/courses";

type ActionState = {
  status: "idle" | "success" | "error";
  message: string;
};

type CourseValues = {
  title: string;
  description: string | null;
  objectives: string | null;
  classId: string;
  subjectId: string;
  academicPeriodId: string | null;
  teacherId: string | null;
  estimatedHours: number | null;
  status: "draft" | "published" | "archived";
  competencyIds: string[];
};

const initialState: ActionState = { status: "idle", message: "" };

export function CourseForm({
  action,
  options,
  mode,
  values,
  currentUserId,
  teacherLocked,
}: {
  action: (state: ActionState, formData: FormData) => Promise<ActionState>;
  options: CourseFormOptions;
  mode: "create" | "edit";
  values?: CourseValues;
  currentUserId: string;
  teacherLocked: boolean;
}) {
  const [state, formAction, pending] = useActionState(action, initialState);
  const [selectedClass, setSelectedClass] = useState(values?.classId ?? "");
  const [selectedSubject, setSelectedSubject] = useState(values?.subjectId ?? "");
  const [selectedStatus, setSelectedStatus] = useState(values?.status ?? "draft");
  const [selectedCompetencyIds, setSelectedCompetencyIds] = useState(
    () => new Set(values?.competencyIds ?? []),
  );

  const subjectIdsByClass = useMemo(() => {
    const map = new Map<string, Set<string>>();
    for (const link of options.classSubjects) {
      const ids = map.get(link.class_id) ?? new Set<string>();
      ids.add(link.subject_id);
      map.set(link.class_id, ids);
    }
    return map;
  }, [options.classSubjects]);

  const configuredSubjects = selectedClass
    ? options.subjects.filter((subject) => subjectIdsByClass.get(selectedClass)?.has(subject.id))
    : [];
  const selectedProgramId = options.classes.find((item) => item.id === selectedClass)?.program_id ?? "";
  const currentSubjectMissing =
    mode === "edit" &&
    selectedClass === values?.classId &&
    selectedSubject === values.subjectId &&
    !configuredSubjects.some((subject) => subject.id === values.subjectId);
  const availableSubjects = currentSubjectMissing
    ? [
        ...configuredSubjects,
        {
          id: values.subjectId,
          name: "Matière actuelle (inactive ou désaffectée)",
          code: null,
          program_id: selectedProgramId,
        },
      ]
    : configuredSubjects;
  const configuredCompetencies = options.competencies.filter(
    (competency) =>
      (!competency.program_id || competency.program_id === selectedProgramId) &&
      (!competency.subject_id || competency.subject_id === selectedSubject),
  );
  const missingCompetencies = (values?.competencyIds ?? [])
    .filter((id) => !configuredCompetencies.some((competency) => competency.id === id))
    .map((id) => ({
      id,
      name: "Compétence actuelle (inactive ou temporairement inaccessible)",
      code: null,
      program_id: selectedProgramId || null,
      subject_id: selectedSubject || null,
    }));
  const availableCompetencies = [...configuredCompetencies, ...missingCompetencies];
  const selectedClassName = options.classes.find((item) => item.id === selectedClass)?.name;
  const lockedTeacher = options.teachers.find((item) => item.id === currentUserId);
  const hasMinimumConfiguration = mode === "edit"
    ? Boolean(selectedClass && selectedSubject)
    : options.classes.length > 0 && options.classSubjects.length > 0;

  function changeClass(classId: string) {
    setSelectedClass(classId);
    if (!subjectIdsByClass.get(classId)?.has(selectedSubject)) {
      setSelectedSubject("");
      setSelectedCompetencyIds(new Set());
    }
  }

  function changeSubject(subjectId: string) {
    setSelectedSubject(subjectId);
    if (subjectId !== selectedSubject) setSelectedCompetencyIds(new Set());
  }

  function toggleCompetency(id: string, checked: boolean) {
    setSelectedCompetencyIds((current) => {
      const next = new Set(current);
      if (checked) next.add(id);
      else next.delete(id);
      return next;
    });
  }

  return (
    <>
      <Link href={mode === "edit" ? "../" : "/app/courses"} className="inline-flex items-center gap-2 text-sm font-bold text-[#173f5f]">
        <ArrowLeft size={16} /> Retour aux cours
      </Link>

      <form action={formAction} className="surface mt-6 p-6 sm:p-8">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <span className="badge">LMS · Cours</span>
            <h1 className="mt-3 text-3xl font-black">
              {mode === "create" ? "Créer un cours" : "Modifier le cours"}
            </h1>
            <p className="mt-2 max-w-3xl text-sm leading-6 text-[#68758a]">
              La classe, la matière et les compétences sont contrôlées côté serveur et isolées par établissement.
            </p>
          </div>
          {mode === "edit" && <span className="badge">Enregistrement manuel</span>}
        </div>

        {!hasMinimumConfiguration && (
          <div className="mt-6 rounded-xl border border-[#f0d98a] bg-[#fff9e8] p-4 text-sm text-[#73540d]">
            Configuration requise : créez une classe active et affectez-lui au moins une matière avant de créer un cours.
          </div>
        )}

        {options.loadError && (
          <div className="mt-6 rounded-xl border border-[#efb5b5] bg-[#fff0f0] p-4 text-sm text-[#a12c2c]" role="alert">
            Certaines options du cours n’ont pas pu être chargées. L’enregistrement est bloqué afin de ne perdre aucune affectation ; rechargez la page puis réessayez.
          </div>
        )}

        <div className="mt-8 grid gap-5 lg:grid-cols-2">
          <div className="field lg:col-span-2">
            <label htmlFor="course-title">Titre du cours</label>
            <input
              id="course-title"
              name="title"
              defaultValue={values?.title ?? ""}
              maxLength={160}
              minLength={3}
              placeholder="Ex. Gestion de projet — Fondamentaux"
              required
            />
          </div>

          <div className="field">
            <label htmlFor="course-class">Classe</label>
            <select
              id="course-class"
              name="classId"
              value={selectedClass}
              onChange={(event) => changeClass(event.target.value)}
              required
            >
              <option value="">Sélectionner une classe</option>
              {values?.classId && !options.classes.some((item) => item.id === values.classId) && (
                <option value={values.classId}>Classe actuelle (inactive ou inaccessible)</option>
              )}
              {options.classes.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}{item.code ? ` · ${item.code}` : ""}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label htmlFor="course-subject">Matière</label>
            <select
              id="course-subject"
              name="subjectId"
              value={selectedSubject}
              onChange={(event) => changeSubject(event.target.value)}
              disabled={!selectedClass}
              required
            >
              <option value="">
                {selectedClass ? "Sélectionner une matière" : "Choisir d’abord une classe"}
              </option>
              {availableSubjects.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}{item.code ? ` · ${item.code}` : ""}
                </option>
              ))}
            </select>
            {selectedClass && availableSubjects.length === 0 && (
              <small className="text-[#a12c2c]">Aucune matière n’est affectée à {selectedClassName}.</small>
            )}
          </div>

          <div className="field">
            <label htmlFor="course-period">Période académique</label>
            <select id="course-period" name="academicPeriodId" defaultValue={values?.academicPeriodId ?? ""}>
              <option value="">Toute l’année / non définie</option>
              {values?.academicPeriodId && !options.periods.some((item) => item.id === values.academicPeriodId) && (
                <option value={values.academicPeriodId}>Période actuelle (indisponible)</option>
              )}
              {options.periods.map((item) => (
                <option key={item.id} value={item.id}>{item.name}</option>
              ))}
            </select>
          </div>

          <div className="field">
            <label htmlFor="course-teacher">Enseignant</label>
            {teacherLocked ? (
              <>
                <input type="hidden" name="teacherId" value={currentUserId} />
                <input id="course-teacher" value={lockedTeacher?.name ?? "Vous-même"} disabled />
                <small className="text-[#748096]">Un enseignant crée uniquement ses propres cours.</small>
              </>
            ) : (
              <select id="course-teacher" name="teacherId" defaultValue={values?.teacherId ?? ""}>
                <option value="">Non attribué</option>
                {values?.teacherId && !options.teachers.some((item) => item.id === values.teacherId) && (
                  <option value={values.teacherId}>Enseignant actuel (inactif ou inaccessible)</option>
                )}
                {options.teachers.map((item) => (
                  <option key={item.id} value={item.id}>{item.name}</option>
                ))}
              </select>
            )}
          </div>

          <div className="field">
            <label htmlFor="course-duration">Durée estimée (heures)</label>
            <input
              id="course-duration"
              name="estimatedHours"
              type="number"
              min="0"
              max="99999"
              step="0.25"
              defaultValue={values?.estimatedHours ?? ""}
              placeholder="Ex. 18"
            />
          </div>

          {mode === "edit" && (
            <div className="field">
              <label htmlFor="course-status">Statut</label>
              <select
                id="course-status"
                name="status"
                value={selectedStatus}
                onChange={(event) => setSelectedStatus(event.target.value as CourseValues["status"])}
              >
                <option value="draft">Brouillon</option>
                <option value="published">Publié</option>
                <option value="archived">Archivé</option>
              </select>
            </div>
          )}

          <div className="field lg:col-span-2">
            <label htmlFor="course-description">Description</label>
            <textarea
              id="course-description"
              name="description"
              maxLength={5000}
              defaultValue={values?.description ?? ""}
              placeholder="Présentez le contenu et le contexte du cours."
            />
          </div>

          <div className="field lg:col-span-2">
            <label htmlFor="course-objectives">Objectifs pédagogiques</label>
            <textarea
              id="course-objectives"
              name="objectives"
              maxLength={5000}
              defaultValue={values?.objectives ?? ""}
              placeholder="À l’issue du cours, l’étudiant sera capable de…"
            />
          </div>
        </div>

        <fieldset className="mt-7 rounded-2xl border border-[#e5eaf0] p-5">
          <legend className="px-2 text-sm font-black text-[#354159]">Compétences associées</legend>
          {!selectedSubject && (
            <p className="text-sm text-[#748096]">Sélectionnez une matière pour afficher les compétences pertinentes.</p>
          )}
          {selectedSubject && availableCompetencies.length === 0 && (
            <p className="text-sm text-[#748096]">Aucune compétence active n’est encore configurée pour cette matière.</p>
          )}
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {selectedSubject && availableCompetencies.map((item) => (
              <label key={item.id} className="flex cursor-pointer items-start gap-3 rounded-xl border border-[#edf0f4] p-3 text-sm">
                <input
                  className="mt-1 h-4 w-4"
                  type="checkbox"
                  name="competencyIds"
                  value={item.id}
                  checked={selectedCompetencyIds.has(item.id)}
                  onChange={(event) => toggleCompetency(item.id, event.target.checked)}
                />
                <span>
                  <b>{item.name}</b>
                  {item.code && <span className="mt-1 block text-xs text-[#748096]">{item.code}</span>}
                </span>
              </label>
            ))}
          </div>
        </fieldset>

        {state.message && (
          <p
            className={`mt-6 rounded-xl p-4 text-sm ${state.status === "error" ? "bg-[#fff0f0] text-[#a12c2c]" : "bg-[#e9f8f3] text-[#08765a]"}`}
            role="status"
            aria-live="polite"
          >
            {state.message}
          </p>
        )}

        <div className="mt-7 flex flex-wrap items-center gap-3">
          <button className="btn-primary" disabled={pending || options.loadError || !hasMinimumConfiguration || !selectedSubject}>
            <Save size={17} /> {pending ? "Enregistrement…" : mode === "create" ? "Créer le cours" : "Enregistrer les modifications"}
          </button>
          <Link href={mode === "edit" ? "../" : "/app/courses"} className="btn-secondary">Annuler</Link>
        </div>
      </form>
    </>
  );
}
