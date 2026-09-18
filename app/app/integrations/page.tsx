import { CalendarDays, Cloud, GraduationCap } from "lucide-react";

const integrations = [
  {
    name: "Google Classroom",
    description: "Synchronisation des classes, ressources et devoirs autorisés.",
    icon: GraduationCap,
  },
  {
    name: "Google Drive",
    description: "Accès contrôlé aux ressources et fichiers Google Workspace.",
    icon: Cloud,
  },
  {
    name: "Google Calendar",
    description: "Synchronisation des cours, examens et soutenances autorisés.",
    icon: CalendarDays,
  },
];

export default function IntegrationsPage() {
  return (
    <>
      <span className="badge">Services externes</span>
      <h1 className="mt-3 text-3xl font-black">Intégrations</h1>
      <p className="mt-2 max-w-3xl text-sm leading-6 text-[#68758a]">
        SCOLARYS n’affiche jamais une connexion externe comme active sans configuration OAuth réelle.
      </p>
      <div className="mt-7 grid gap-4 lg:grid-cols-3">
        {integrations.map(({ name, description, icon: Icon }) => (
          <article className="surface p-6" key={name}>
            <span className="grid h-11 w-11 place-items-center rounded-xl bg-[#eef4f8] text-[#173f5f]"><Icon size={22} /></span>
            <h2 className="mt-5 text-lg font-black">{name}</h2>
            <p className="mt-2 min-h-12 text-sm leading-6 text-[#68758a]">{description}</p>
            <div className="mt-5 border-t border-[#edf0f4] pt-4">
              <span className="badge badge-warn">Configuration requise</span>
              <p className="mt-3 text-xs leading-5 text-[#748096]">Identifiants OAuth et consentement administrateur requis avant activation.</p>
            </div>
          </article>
        ))}
      </div>
    </>
  );
}
