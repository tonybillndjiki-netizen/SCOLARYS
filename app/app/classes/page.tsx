import { getAppContext } from "@/lib/data/context";

export default async function ClassesPage() {
  const context = await getAppContext();
  if (!context?.organization) return null;
  const orgId = context.organization.id;

  const [{ data: classes, error }, { data: programs }, { data: subjectLinks }] = await Promise.all([
    context.supabase.from("scolaria_classes").select("id, name, code, status, capacity, program_id").eq("organization_id", orgId).order("name"),
    context.supabase.from("scolaria_programs").select("id, name").eq("organization_id", orgId),
    context.supabase.from("scolaria_class_subjects").select("class_id").eq("organization_id", orgId),
  ]);

  const programMap = new Map((programs ?? []).map((p) => [p.id, p.name]));
  const subjectCount = new Map<string, number>();
  for (const row of subjectLinks ?? []) subjectCount.set(row.class_id, (subjectCount.get(row.class_id) ?? 0) + 1);

  return (
    <>
      <span className="badge">Organisation</span>
      <h1 className="mt-3 text-3xl font-black">Classes</h1>
      <p className="mt-2 text-sm text-[#68758a]">Une classe administrative peut porter plusieurs matières sans dupliquer les étudiants.</p>
      {error && <p className="mt-6 rounded-xl bg-[#fff0f0] p-4 text-sm text-[#a12c2c]">{error.message}</p>}

      <div className="table-shell mt-7">
        <table>
          <thead><tr><th>Classe</th><th>Formation</th><th>Matières</th><th>Capacité</th><th>Statut</th></tr></thead>
          <tbody>
            {(classes ?? []).map((item) => (
              <tr key={item.id}>
                <td><b>{item.name}</b><div className="mt-1 text-xs text-[#748096]">{item.code || "—"}</div></td>
                <td>{programMap.get(item.program_id) || "—"}</td>
                <td>{subjectCount.get(item.id) ?? 0}</td>
                <td>{item.capacity ?? "Non définie"}</td>
                <td><span className={`badge ${item.status === "active" ? "badge-ok" : ""}`}>{item.status}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {!classes?.length && !error && <div className="surface mt-7 p-8 text-sm text-[#68758a]">Aucune classe créée.</div>}
    </>
  );
}
