import Link from "next/link";
import { Upload } from "lucide-react";
import { getAppContext } from "@/lib/data/context";

export default async function StudentsPage() {
  const context = await getAppContext();
  if (!context?.organization) return null;
  const orgId = context.organization.id;

  const [{ data: students, error }, { data: memberships }, { data: classes }] = await Promise.all([
    context.supabase
      .from("scolaria_student_records")
      .select("id, user_id, matricule, first_name, last_name, email, phone, status, created_at")
      .eq("organization_id", orgId)
      .order("last_name"),
    context.supabase
      .from("scolaria_class_memberships")
      .select("user_id, class_id, status")
      .eq("organization_id", orgId)
      .eq("membership_type", "student")
      .eq("status", "active"),
    context.supabase
      .from("scolaria_classes")
      .select("id, name")
      .eq("organization_id", orgId),
  ]);

  const classMap = new Map((classes ?? []).map((item) => [item.id, item.name]));
  const classByUser = new Map<string, string[]>();
  for (const item of memberships ?? []) {
    const current = classByUser.get(item.user_id) ?? [];
    current.push(classMap.get(item.class_id) || "Classe");
    classByUser.set(item.user_id, current);
  }

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <span className="badge">Effectifs</span>
          <h1 className="mt-3 text-3xl font-black">Étudiants</h1>
          <p className="mt-2 text-sm text-[#68758a]">
            Un seul dossier étudiant par organisation, avec des affectations de classe séparées.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <span className="badge">{students?.length ?? 0} étudiant(s)</span>
          <Link href="/app/students/import" className="btn-primary">
            <Upload size={17} /> Importer des étudiants
          </Link>
        </div>
      </div>

      {error && <p className="mt-6 rounded-xl bg-[#fff0f0] p-4 text-sm text-[#a12c2c]">{error.message}</p>}
      <div className="table-shell mt-7">
        <table>
          <thead>
            <tr>
              <th>Étudiant</th>
              <th>Matricule</th>
              <th>Email</th>
              <th>Téléphone</th>
              <th>Classe(s)</th>
              <th>Statut</th>
            </tr>
          </thead>
          <tbody>
            {(students ?? []).map((item) => (
              <tr key={item.id}>
                <td><b>{item.first_name} {item.last_name}</b></td>
                <td>{item.matricule}</td>
                <td>{item.email}</td>
                <td>{item.phone || "—"}</td>
                <td>{(classByUser.get(item.user_id) ?? []).join(", ") || "—"}</td>
                <td><span className={`badge ${item.status === "active" ? "badge-ok" : item.status === "pending" || item.status === "invited" ? "badge-warn" : ""}`}>{item.status}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {!students?.length && !error && (
        <div className="surface mt-7 p-8">
          <h2 className="text-lg font-black">Aucun étudiant inscrit</h2>
          <p className="mt-2 text-sm leading-6 text-[#68758a]">
            Utilisez l’assistant d’import pour charger un CSV, un fichier Excel .xlsx ou des lignes copiées depuis un tableur.
          </p>
          <Link href="/app/students/import" className="btn-primary mt-5">
            <Upload size={17} /> Lancer un import
          </Link>
        </div>
      )}
    </>
  );
}
