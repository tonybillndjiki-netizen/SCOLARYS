import Link from "next/link";
import {
  BarChart3,
  BookOpenCheck,
  BrainCircuit,
  Building2,
  CheckCircle2,
  GraduationCap,
  ShieldCheck,
  Users,
} from "lucide-react";

const features = [
  [Building2, "Multi-établissements", "Isolation stricte des données par organisation, campus et rôles configurables."],
  [GraduationCap, "Pilotage pédagogique", "Formations, promotions, classes, UE, UV, matières, cours et progression."],
  [BookOpenCheck, "Évaluations & notes", "Quiz, devoirs, CC, présences, compétences, carnet de notes et bulletins."],
  [BrainCircuit, "SCOLARYS AI", "Architecture prévue pour assister enseignants et étudiants avec validation humaine."],
  [BarChart3, "Analytics", "Indicateurs pédagogiques et signaux de vigilance au service des équipes."],
  [ShieldCheck, "Sécurité native", "Authentification Supabase, RLS PostgreSQL, RBAC et journal d'audit."],
] as const;

export default function HomePage() {
  return (
    <main>
      <header className="mx-auto flex max-w-7xl items-center justify-between px-5 py-6 lg:px-8">
        <Link href="/" className="flex items-center gap-3 font-black tracking-tight">
          <span className="grid h-10 w-10 place-items-center rounded-xl bg-[#173f5f] text-white">S</span>
          <span>SCOLARYS</span>
        </Link>
        <div className="flex items-center gap-2">
          <Link className="btn-secondary" href="/login">Connexion</Link>
          <Link className="btn-primary" href="/signup">Créer un espace</Link>
        </div>
      </header>

      <section className="mx-auto grid min-h-[72vh] max-w-7xl items-center gap-12 px-5 py-14 lg:grid-cols-[1.1fr_.9fr] lg:px-8">
        <div>
          <span className="badge">SaaS pédagogique multi-tenant</span>
          <h1 className="mt-6 max-w-4xl text-5xl font-black tracking-[-.05em] text-[#102f49] sm:text-6xl lg:text-7xl">
            Toute votre pédagogie. Un seul environnement.
          </h1>
          <p className="mt-7 max-w-2xl text-lg leading-8 text-[#68758a]">
            SCOLARYS centralise l'organisation, l'enseignement, l'évaluation, la présence,
            les notes, les compétences, les bulletins et le pilotage pédagogique.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link className="btn-primary" href="/signup">Créer mon établissement</Link>
            <a className="btn-secondary" href="#fonctionnalites">Découvrir la plateforme</a>
          </div>
          <div className="mt-10 flex flex-wrap gap-x-6 gap-y-3 text-sm text-[#4f5d73]">
            {["RLS PostgreSQL", "RBAC configurable", "Responsive", "Audit des actions"].map((item) => (
              <span key={item} className="flex items-center gap-2">
                <CheckCircle2 size={17} className="text-[#15a6a6]" /> {item}
              </span>
            ))}
          </div>
        </div>

        <div className="surface relative overflow-hidden p-6 sm:p-8">
          <div className="mb-7 flex items-center justify-between gap-3">
            <div>
              <div className="text-sm font-bold text-[#718096]">Vue direction</div>
              <div className="mt-1 text-2xl font-black">Cockpit pédagogique</div>
            </div>
            <span className="badge badge-ok">Données sécurisées</span>
          </div>
          <div className="grid grid-cols-2 gap-4">
            {[["Étudiants", "500+"], ["Présence", "94,2 %"], ["Progression", "78 %"], ["Classes", "18"]].map(([label, value]) => (
              <div className="metric" key={label}>
                <div className="text-sm text-[#748096]">{label}</div>
                <div className="mt-2 text-3xl font-black text-[#173f5f]">{value}</div>
              </div>
            ))}
          </div>
          <div className="mt-4 rounded-2xl border border-[#e5eaf0] bg-[#f8fafc] p-5">
            <div className="mb-4 flex items-center gap-2 font-bold"><Users size={18} /> Ce qui nécessite votre attention</div>
            <div className="space-y-3 text-sm text-[#556277]">
              <div className="flex justify-between gap-3"><span>Présences à compléter</span><b>2 séances</b></div>
              <div className="flex justify-between gap-3"><span>Corrections en attente</span><b>14 travaux</b></div>
              <div className="flex justify-between gap-3"><span>Bulletins à valider</span><b>1 classe</b></div>
            </div>
          </div>
        </div>
      </section>

      <section id="fonctionnalites" className="mx-auto max-w-7xl px-5 py-20 lg:px-8">
        <div className="max-w-2xl">
          <span className="badge">Plateforme complète</span>
          <h2 className="mt-4 text-4xl font-black tracking-[-.035em] text-[#102f49]">Du campus au bulletin</h2>
          <p className="mt-4 leading-7 text-[#68758a]">
            Une architecture configurable pour écoles supérieures, universités, CFA et groupes multi-campus.
          </p>
        </div>
        <div className="mt-10 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {features.map(([Icon, title, description]) => (
            <article className="surface p-6" key={title}>
              <div className="mb-4 grid h-11 w-11 place-items-center rounded-xl bg-[#eaf4f6] text-[#147d85]">
                <Icon size={22} />
              </div>
              <h3 className="text-lg font-black">{title}</h3>
              <p className="mt-2 text-sm leading-6 text-[#68758a]">{description}</p>
            </article>
          ))}
        </div>
      </section>

      <footer className="border-t border-[#e5eaf0] px-5 py-10 text-center text-sm text-[#748096]">
        SCOLARYS — Plateforme intelligente de pilotage pédagogique.
      </footer>
    </main>
  );
}
