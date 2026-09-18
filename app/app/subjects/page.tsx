import { getAppContext } from "@/lib/data/context";

export default async function SubjectsPage() {
  const context = await getAppContext();
  if (!context?.organization) return null;
  const orgId = context.organization.id;

  const [{ data: programs }, { data: units }, { data: subunits }, { data: subjects, error }] = await Promise.all([
    context.supabase.from("scolaria_programs").select("id, name").eq("organization_id", orgId).order("name"),
    context.supabase.from("scolaria_units").select("id, program_id, code, name, ordinal").eq("organization_id", orgId).order("ordinal"),
    context.supabase.from("scolaria_subunits").select("id, unit_id, code, name, ordinal").eq("organization_id", orgId).order("ordinal"),
    context.supabase.from("scolaria_subjects").select("id, program_id, unit_id, subunit_id, code, name, description").eq("organization_id", orgId).eq("is_active", true).order("name"),
  ]);

  const programMap = new Map((programs ?? []).map((p) => [p.id, p.name]));
  const unitMap = new Map((units ?? []).map((u) => [u.id, u]));
  const subunitMap = new Map((subunits ?? []).map((u) => [u.id, u]));

  return (
    <>
      <span className="badge">Architecture configurable</span>
      <h1 className="mt-3 text-3xl font-black">Matières, UE & UV</h1>
      <p className="mt-2 max-w-3xl text-sm leading-6 text-[#68758a]">
        Les matières simples et les parcours UE → UV coexistent dans le même modèle. B3 Tronc Commun reste une seule classe avec trois matières indépendantes.
      </p>
      {error && <p className="mt-6 rounded-xl bg-[#fff0f0] p-4 text-sm text-[#a12c2c]">{error.message}</p>}

      <div className="mt-7 grid gap-4 xl:grid-cols-2">
        {(subjects ?? []).map((subject) => {
          const unit = subject.unit_id ? unitMap.get(subject.unit_id) : null;
          const subunit = subject.subunit_id ? subunitMap.get(subject.subunit_id) : null;
          return (
            <article className="surface p-5" key={subject.id}>
              <div className="flex flex-wrap items-center gap-2 text-xs font-bold text-[#748096]">
                <span>{programMap.get(subject.program_id) || "Formation"}</span>
                {unit && <><span>›</span><span>{unit.name}</span></>}
                {subunit && <><span>›</span><span>{subunit.name}</span></>}
              </div>
              <div className="mt-4 flex items-start justify-between gap-4">
                <div>
                  <h2 className="text-lg font-black">{subject.name}</h2>
                  <div className="mt-1 text-xs font-bold uppercase tracking-[.08em] text-[#147d85]">{subject.code || "MATIÈRE"}</div>
                </div>
                <span className="badge badge-ok">Active</span>
              </div>
              <p className="mt-4 text-sm leading-6 text-[#68758a]">{subject.description || "Description à compléter."}</p>
            </article>
          );
        })}
      </div>
    </>
  );
}
