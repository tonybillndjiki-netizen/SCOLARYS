"use client";

import { useRouter } from "next/navigation";
import { FormEvent, useActionState, useEffect, useRef, useState, useTransition } from "react";
import { ArrowDown, ArrowUp, GripVertical, Plus, Save, Trash2 } from "lucide-react";
import {
  createChapterAction,
  deleteChapterAction,
  moveChapterAction,
  updateChapterAction,
} from "@/app/app/courses/actions";
import { chapterStatusLabels, statusBadgeClass } from "@/lib/data/courses";

type ActionState = {
  status: "idle" | "success" | "error";
  message: string;
};

type Chapter = {
  id: string;
  title: string;
  description: string | null;
  objectives: string | null;
  ordinal: number;
  estimated_minutes: number | null;
  structured_zones_enabled: boolean;
  status: "draft" | "scheduled" | "published" | "archived";
  scheduled_at: string | null;
  updated_at: string;
};

const initialState: ActionState = { status: "idle", message: "" };

function dateTimeLocal(value: string | null) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Date(date.getTime() - date.getTimezoneOffset() * 60_000).toISOString().slice(0, 16);
}

function localDateTimeToIso(value: string) {
  if (!value) return "";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "" : date.toISOString();
}

function ChapterFields({ chapter }: { chapter?: Chapter }) {
  const [status, setStatus] = useState(chapter?.status ?? "draft");
  const [scheduledAtLocal, setScheduledAtLocal] = useState(dateTimeLocal(chapter?.scheduled_at ?? null));

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <div className="field lg:col-span-2">
        <label htmlFor={chapter ? `title-${chapter.id}` : "new-chapter-title"}>Titre</label>
        <input
          id={chapter ? `title-${chapter.id}` : "new-chapter-title"}
          name="title"
          defaultValue={chapter?.title ?? ""}
          minLength={2}
          maxLength={160}
          placeholder="Ex. Cadrer un projet"
          required
        />
      </div>
      <div className="field">
        <label htmlFor={chapter ? `duration-${chapter.id}` : "new-chapter-duration"}>Durée estimée (minutes)</label>
        <input
          id={chapter ? `duration-${chapter.id}` : "new-chapter-duration"}
          name="estimatedMinutes"
          type="number"
          min="0"
          step="1"
          defaultValue={chapter?.estimated_minutes ?? ""}
          placeholder="Ex. 90"
        />
      </div>
      <div className="field">
        <label htmlFor={chapter ? `status-${chapter.id}` : "new-chapter-status"}>Statut</label>
        <select
          id={chapter ? `status-${chapter.id}` : "new-chapter-status"}
          name="status"
          value={status}
          onChange={(event) => setStatus(event.target.value as Chapter["status"])}
        >
          {Object.entries(chapterStatusLabels).map(([value, label]) => (
            <option key={value} value={value}>{label}</option>
          ))}
        </select>
      </div>
      {status === "scheduled" && (
        <div className="field lg:col-span-2">
          <label htmlFor={chapter ? `schedule-${chapter.id}` : "new-chapter-schedule"}>Publication programmée</label>
          <input
            id={chapter ? `schedule-${chapter.id}` : "new-chapter-schedule"}
            type="datetime-local"
            value={scheduledAtLocal}
            onChange={(event) => setScheduledAtLocal(event.target.value)}
            required
          />
          <input type="hidden" name="scheduledAt" value={localDateTimeToIso(scheduledAtLocal)} />
          <small className="text-[#748096]">
            Date cible enregistrée dans votre fuseau local. La publication reste manuelle dans cet incrément.
          </small>
        </div>
      )}
      <div className="field lg:col-span-2">
        <label htmlFor={chapter ? `description-${chapter.id}` : "new-chapter-description"}>Description</label>
        <textarea
          id={chapter ? `description-${chapter.id}` : "new-chapter-description"}
          name="description"
          maxLength={5000}
          defaultValue={chapter?.description ?? ""}
          placeholder="Présentez le chapitre et son déroulé."
        />
      </div>
      <div className="field lg:col-span-2">
        <label htmlFor={chapter ? `objectives-${chapter.id}` : "new-chapter-objectives"}>Objectifs</label>
        <textarea
          id={chapter ? `objectives-${chapter.id}` : "new-chapter-objectives"}
          name="objectives"
          maxLength={5000}
          defaultValue={chapter?.objectives ?? ""}
          placeholder="Objectifs spécifiques du chapitre."
        />
      </div>
      <label className="flex cursor-pointer items-start gap-3 rounded-xl border border-[#e5eaf0] p-4 lg:col-span-2">
        <input
          className="mt-1 h-4 w-4"
          type="checkbox"
          name="structuredZonesEnabled"
          defaultChecked={chapter?.structured_zones_enabled ?? true}
        />
        <span>
          <b className="text-sm">Structurer en Avant / Pendant / Après</b>
          <span className="mt-1 block text-xs leading-5 text-[#748096]">
            Désactivez cette option pour utiliser une zone de contenu unique.
          </span>
        </span>
      </label>
    </div>
  );
}

function CreateChapterForm({ courseId }: { courseId: string }) {
  const router = useRouter();
  const formRef = useRef<HTMLFormElement>(null);
  const [formVersion, setFormVersion] = useState(0);
  const [state, action, pending] = useActionState(createChapterAction.bind(null, courseId), initialState);

  useEffect(() => {
    if (state.status === "success") {
      formRef.current?.reset();
      setFormVersion((version) => version + 1);
      router.refresh();
    }
  }, [router, state]);

  return (
    <form ref={formRef} action={action} id="new-chapter" className="surface p-6 sm:p-7">
      <div className="flex items-start justify-between gap-4">
        <div>
          <span className="badge">Nouveau chapitre</span>
          <h2 className="mt-3 text-xl font-black">Ajouter au parcours</h2>
          <p className="mt-1 text-sm text-[#748096]">Le chapitre sera ajouté à la fin et pourra être réordonné ensuite.</p>
        </div>
        <Plus className="text-[#147d85]" size={24} />
      </div>
      <div className="mt-6"><ChapterFields key={formVersion} /></div>
      {state.message && (
        <p className={`mt-5 rounded-xl p-3 text-sm ${state.status === "error" ? "bg-[#fff0f0] text-[#a12c2c]" : "bg-[#e9f8f3] text-[#08765a]"}`} role="status">
          {state.message}
        </p>
      )}
      <button className="btn-primary mt-6" disabled={pending}>
        <Plus size={17} /> {pending ? "Ajout…" : "Ajouter le chapitre"}
      </button>
    </form>
  );
}

function ChapterCard({
  courseId,
  chapter,
  first,
  last,
}: {
  courseId: string;
  chapter: Chapter;
  first: boolean;
  last: boolean;
}) {
  const router = useRouter();
  const [operationMessage, setOperationMessage] = useState("");
  const [busy, startTransition] = useTransition();
  const [state, action, saving] = useActionState(
    updateChapterAction.bind(null, courseId, chapter.id),
    initialState,
  );

  useEffect(() => {
    if (state.status === "success") router.refresh();
  }, [router, state]);

  function move(direction: "up" | "down") {
    setOperationMessage("");
    startTransition(async () => {
      const result = await moveChapterAction(courseId, chapter.id, direction);
      setOperationMessage(result.message);
      if (result.status === "success") router.refresh();
    });
  }

  function remove(event: FormEvent) {
    event.preventDefault();
    if (!window.confirm(`Supprimer le chapitre « ${chapter.title} », ses blocs et toutes ses ressources associées ? Cette action est irréversible.`)) return;
    setOperationMessage("");
    startTransition(async () => {
      const result = await deleteChapterAction(courseId, chapter.id);
      setOperationMessage(result.message);
      if (result.status === "success") router.refresh();
    });
  }

  return (
    <article className="surface overflow-hidden">
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-[#edf0f4] p-5">
        <div className="flex min-w-0 items-center gap-3">
          <GripVertical className="shrink-0 text-[#a5afbd]" size={20} aria-hidden="true" />
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-[#eef4f8] text-sm font-black text-[#173f5f]">{chapter.ordinal}</span>
          <div className="min-w-0">
            <h3 className="truncate font-black">{chapter.title}</h3>
            <div className="mt-1 text-xs text-[#748096]">
              {chapter.estimated_minutes != null ? `${chapter.estimated_minutes} min` : "Durée non définie"} · {chapter.structured_zones_enabled ? "3 zones" : "Zone unique"}
            </div>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className={`badge ${statusBadgeClass(chapter.status)}`}>{chapterStatusLabels[chapter.status]}</span>
          <button type="button" className="btn-secondary h-10 min-h-0 px-3" disabled={first || busy} onClick={() => move("up")} aria-label={`Monter ${chapter.title}`}>
            <ArrowUp size={16} /> Monter
          </button>
          <button type="button" className="btn-secondary h-10 min-h-0 px-3" disabled={last || busy} onClick={() => move("down")} aria-label={`Descendre ${chapter.title}`}>
            <ArrowDown size={16} /> Descendre
          </button>
        </div>
      </div>

      <details className="group">
        <summary className="cursor-pointer list-none px-5 py-4 text-sm font-bold text-[#173f5f] group-open:border-b group-open:border-[#edf0f4]">
          Modifier les informations du chapitre
        </summary>
        <form action={action} className="p-5 sm:p-6">
          <ChapterFields chapter={chapter} />
          {state.message && (
            <p className={`mt-5 rounded-xl p-3 text-sm ${state.status === "error" ? "bg-[#fff0f0] text-[#a12c2c]" : "bg-[#e9f8f3] text-[#08765a]"}`} role="status">
              {state.message}
            </p>
          )}
          <div className="mt-6 flex flex-wrap items-center gap-3">
            <button className="btn-primary" disabled={saving || busy}>
              <Save size={17} /> {saving ? "Enregistrement…" : "Enregistrer"}
            </button>
            <button type="button" className="btn-secondary text-[#a12c2c]" disabled={saving || busy} onClick={remove}>
              <Trash2 size={17} /> Supprimer
            </button>
          </div>
        </form>
      </details>
      {operationMessage && <p className="border-t border-[#edf0f4] px-5 py-3 text-sm text-[#68758a]" role="status">{operationMessage}</p>}
    </article>
  );
}

export function CourseStudio({ courseId, chapters }: { courseId: string; chapters: Chapter[] }) {
  return (
    <div className="grid gap-6 xl:grid-cols-[1.35fr_.65fr]">
      <section>
        <div className="space-y-4">
          {chapters.map((chapter, index) => (
            <ChapterCard
              key={chapter.id}
              courseId={courseId}
              chapter={chapter}
              first={index === 0}
              last={index === chapters.length - 1}
            />
          ))}
          {!chapters.length && (
            <div className="surface border-dashed p-8 text-center">
              <h2 className="text-lg font-black">Le parcours est vide</h2>
              <p className="mt-2 text-sm text-[#68758a]">Créez le premier chapitre avec le formulaire ci-contre.</p>
            </div>
          )}
        </div>
      </section>
      <aside className="xl:sticky xl:top-6 xl:self-start">
        <CreateChapterForm courseId={courseId} />
        <div className="mt-4 rounded-2xl border border-[#dce7ee] bg-[#eef7f8] p-5 text-sm leading-6 text-[#315b65]">
          Le réordonnancement utilise des opérations atomiques Monter / Descendre. Le glisser-déposer sera ajouté après validation de ce premier incrément.
        </div>
      </aside>
    </div>
  );
}
