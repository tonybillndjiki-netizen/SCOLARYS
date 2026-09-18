import { GraduationCap } from "lucide-react";
import { getAppContext } from "@/lib/data/context";

export default async function ProgramsPage() {
  const context = await getAppContext();
  if (!context?.organization) return null;

  const { data: programs, error } = await context.supabase
    .from("scolaria_programs")
    .select("id, code, name, level, description, is_active")
    .eq("organization_id", context.organization.id)
    .order("name");

  return (
    <>
      <span className="badge">Structure pédagogique</span>
      <h1 className="mt-3 text-3xl font-black">Formations</h1>
      <p className="mt-2 text-sm text-[#68758a]">Programmes accessibles dans {context.organization.name}.</p>

      {error && <p className="mt-6 rounded-xl bg-[#fff0f0] p-4 text-sm text-[#a12c2c]">{error.message}</p>}
      <div className="mt-7 grid gap-4 lg:grid-cols-2 2xl:grid-cols-3">
        {(programs ?? []).map((program) => (
          <article className="surface p-6" key={program.id}>
            <div className="flex items-start justify-between gap-4">
              <span className="grid h-11 w-11 place-items-center rounded-xl bg-[#eaf4f6] text-[#147d85]"><GraduationCap size={22} /></span>
              <span className={`badge ${program.is_active ? "badge-ok" : ""}`}>{program.is_active ? "Active" : "Inactive"}</span>
            </div>
            <div className="mt-5 text-xs font-black uppercase tracking-[.08em] text-[#748096]">{program.code || "PROGRAMME"}</div>
            <h2 className="mt-2 text-xl font-black">{program.name}</h2>
            <div className="mt-2 text-sm font-bold text-[#173f5f]">{program.level || "Niveau configurable"}</div>
            <p className="mt-4 text-sm leading-6 text-[#68758a]">{program.description || "Aucune description."}</p>
          </article>
        ))}
      </div>
      {!programs?.length && !error && <div className="surface mt-7 p-8 text-sm text-[#68758a]">Aucune formation créée pour le moment.</div>}
    </>
  );
}
