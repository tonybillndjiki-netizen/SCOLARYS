"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import Papa from "papaparse";
import { ArrowLeft, CheckCircle2, FileSpreadsheet, Upload, XCircle } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

type ImportTarget =
  | ""
  | "matricule"
  | "nom"
  | "prenom"
  | "email"
  | "telephone"
  | "campus"
  | "formation"
  | "classe"
  | "groupe";

type RawRow = Record<string, string>;

type NormalizedRow = {
  matricule: string;
  nom: string;
  prenom: string;
  email: string;
  telephone: string;
  campus: string;
  formation: string;
  classe: string;
  groupe: string;
};

type ValidationRow = {
  raw: RawRow;
  normalized: NormalizedRow;
  status: "valid" | "duplicate" | "error";
  errors: string[];
};

const targets: Array<{ value: ImportTarget; label: string }> = [
  { value: "", label: "Ignorer" },
  { value: "matricule", label: "Matricule" },
  { value: "nom", label: "Nom" },
  { value: "prenom", label: "Prénom" },
  { value: "email", label: "Email" },
  { value: "telephone", label: "Téléphone" },
  { value: "campus", label: "Campus" },
  { value: "formation", label: "Formation" },
  { value: "classe", label: "Classe" },
  { value: "groupe", label: "Groupe" },
];

const aliases: Record<Exclude<ImportTarget, "">, string[]> = {
  matricule: ["matricule", "id etudiant", "id étudiant", "student id", "numero", "numéro"],
  nom: ["nom", "nom etudiant", "nom étudiant", "last name", "surname"],
  prenom: ["prenom", "prénom", "firstname", "first name"],
  email: ["email", "e-mail", "mail", "adresse mail", "adresse email", "adresse e-mail"],
  telephone: ["telephone", "téléphone", "tel", "mobile", "phone"],
  campus: ["campus", "site"],
  formation: ["formation", "programme", "program"],
  classe: ["classe", "class"],
  groupe: ["groupe", "group"],
};

function simplify(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function autoMapping(headers: string[]) {
  const result: Record<string, ImportTarget> = {};
  for (const header of headers) {
    const normalized = simplify(header);
    let matched: ImportTarget = "";
    for (const [target, names] of Object.entries(aliases) as Array<[Exclude<ImportTarget, "">, string[]]>) {
      if (names.map(simplify).includes(normalized)) {
        matched = target;
        break;
      }
    }
    result[header] = matched;
  }
  return result;
}

function cleanRow(row: Record<string, unknown>) {
  return Object.fromEntries(
    Object.entries(row).map(([key, value]) => [String(key).trim(), value == null ? "" : String(value).trim()]),
  );
}

function toText(value: unknown): string {
  if (value == null) return "";
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return String(value);
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === "object") {
    const candidate = value as Record<string, unknown>;
    if (typeof candidate.text === "string") return candidate.text;
    if (candidate.result != null) return String(candidate.result);
    if (Array.isArray(candidate.richText)) {
      return candidate.richText
        .map((part) => (typeof part === "object" && part && "text" in part ? String((part as { text: unknown }).text) : ""))
        .join("");
    }
  }
  return String(value);
}

function isEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

export function StudentImportWizard({
  organizationId,
  classes,
  existingEmails,
  existingMatricules,
}: {
  organizationId: string;
  classes: Array<{ id: string; name: string; code: string | null }>;
  existingEmails: string[];
  existingMatricules: string[];
}) {
  const [step, setStep] = useState(1);
  const [rows, setRows] = useState<RawRow[]>([]);
  const [headers, setHeaders] = useState<string[]>([]);
  const [mapping, setMapping] = useState<Record<string, ImportTarget>>({});
  const [sourceType, setSourceType] = useState<"csv" | "xlsx" | "paste">("csv");
  const [filename, setFilename] = useState("");
  const [paste, setPaste] = useState("");
  const [defaultClassId, setDefaultClassId] = useState("");
  const [duplicatePolicy, setDuplicatePolicy] = useState<"ignore" | "update" | "add_to_class">("ignore");
  const [busy, setBusy] = useState(false);
  const [resultMessage, setResultMessage] = useState("");
  const [importId, setImportId] = useState<string | null>(null);

  const classNameSet = useMemo(() => new Set(classes.map((item) => simplify(item.name))), [classes]);
  const existingEmailSet = useMemo(() => new Set(existingEmails.map((email) => email.trim().toLowerCase())), [existingEmails]);
  const existingMatriculeSet = useMemo(() => new Set(existingMatricules.map((value) => value.trim().toLowerCase())), [existingMatricules]);

  const normalizedRows = useMemo<NormalizedRow[]>(() => {
    const headerFor = (target: Exclude<ImportTarget, "">) =>
      Object.keys(mapping).find((header) => mapping[header] === target);

    return rows.map((row) => {
      const read = (target: Exclude<ImportTarget, "">) => {
        const header = headerFor(target);
        return header ? String(row[header] || "").trim() : "";
      };
      return {
        matricule: read("matricule"),
        nom: read("nom"),
        prenom: read("prenom"),
        email: read("email").toLowerCase(),
        telephone: read("telephone"),
        campus: read("campus"),
        formation: read("formation"),
        classe: read("classe"),
        groupe: read("groupe"),
      };
    });
  }, [mapping, rows]);

  const validated = useMemo<ValidationRow[]>(() => {
    const emailCounts = new Map<string, number>();
    const matriculeCounts = new Map<string, number>();
    for (const row of normalizedRows) {
      if (row.email) emailCounts.set(row.email, (emailCounts.get(row.email) ?? 0) + 1);
      if (row.matricule) {
        const key = row.matricule.toLowerCase();
        matriculeCounts.set(key, (matriculeCounts.get(key) ?? 0) + 1);
      }
    }

    return normalizedRows.map((normalized, index) => {
      const errors: string[] = [];
      let duplicate = false;

      if (!normalized.nom) errors.push("Nom manquant");
      if (!normalized.prenom) errors.push("Prénom manquant");
      if (!normalized.email) errors.push("Email manquant");
      else if (!isEmail(normalized.email)) errors.push("Email invalide");
      if (!normalized.matricule) errors.push("Matricule manquant");

      const resolvedClass = normalized.classe ? simplify(normalized.classe) : "";
      if (!resolvedClass && !defaultClassId) errors.push("Classe manquante");
      if (resolvedClass && !classNameSet.has(resolvedClass)) errors.push("Classe inconnue");

      if (normalized.email && (existingEmailSet.has(normalized.email) || (emailCounts.get(normalized.email) ?? 0) > 1)) {
        duplicate = true;
      }
      const matriculeKey = normalized.matricule.toLowerCase();
      if (normalized.matricule && (existingMatriculeSet.has(matriculeKey) || (matriculeCounts.get(matriculeKey) ?? 0) > 1)) {
        duplicate = true;
      }

      return {
        raw: rows[index] ?? {},
        normalized,
        status: errors.length ? "error" : duplicate ? "duplicate" : "valid",
        errors,
      };
    });
  }, [normalizedRows, rows, classNameSet, defaultClassId, existingEmailSet, existingMatriculeSet]);

  const summary = useMemo(() => ({
    total: validated.length,
    valid: validated.filter((row) => row.status === "valid").length,
    duplicate: validated.filter((row) => row.status === "duplicate").length,
    error: validated.filter((row) => row.status === "error").length,
  }), [validated]);

  function installRows(nextRows: RawRow[], nextHeaders: string[], type: "csv" | "xlsx" | "paste", name: string) {
    setRows(nextRows);
    setHeaders(nextHeaders);
    setMapping(autoMapping(nextHeaders));
    setSourceType(type);
    setFilename(name);
    setResultMessage("");
    setImportId(null);
    setStep(2);
  }

  function parseDelimited(text: string, type: "csv" | "paste", name: string) {
    const parsed = Papa.parse<Record<string, unknown>>(text, {
      header: true,
      skipEmptyLines: "greedy",
      transformHeader: (header) => header.trim(),
    });
    const parsedHeaders = (parsed.meta.fields ?? []).filter(Boolean);
    if (!parsedHeaders.length || !parsed.data.length) {
      setResultMessage("Aucune ligne exploitable détectée.");
      return;
    }
    installRows(parsed.data.map(cleanRow), parsedHeaders, type, name);
  }

  async function parseFile(file: File) {
    setBusy(true);
    setResultMessage("");
    try {
      const extension = file.name.split(".").pop()?.toLowerCase();
      if (extension === "csv" || extension === "txt") {
        parseDelimited(await file.text(), "csv", file.name);
      } else if (extension === "xlsx") {
        const Excel = await import("@excel.js/exceljs");
        const workbook = new Excel.Workbook();
        await workbook.xlsx.load(await file.arrayBuffer());
        const sheet = workbook.worksheets[0];
        if (!sheet) throw new Error("Le classeur Excel ne contient aucune feuille.");

        const firstRowValues = sheet.getRow(1).values;
        const headerValues: unknown[] = Array.isArray(firstRowValues) ? firstRowValues.slice(1) : [];
        const parsedHeaders: string[] = headerValues
          .map((value: unknown) => toText(value).trim())
          .filter((value: string) => Boolean(value));
        const parsedRows: RawRow[] = [];
        for (let i = 2; i <= sheet.rowCount; i += 1) {
          const row = sheet.getRow(i);
          const item: RawRow = {};
          parsedHeaders.forEach((header, index) => {
            item[header] = toText(row.getCell(index + 1).value).trim();
          });
          if (Object.values(item).some(Boolean)) parsedRows.push(item);
        }
        if (!parsedHeaders.length || !parsedRows.length) throw new Error("Aucune ligne exploitable détectée dans le fichier Excel.");
        installRows(parsedRows, parsedHeaders, "xlsx", file.name);
      } else {
        throw new Error("Format non pris en charge. Utilisez CSV ou Excel .xlsx.");
      }
    } catch (error) {
      setResultMessage(error instanceof Error ? error.message : "Lecture du fichier impossible.");
    } finally {
      setBusy(false);
    }
  }

  function changeMapping(header: string, value: ImportTarget) {
    setMapping((current) => {
      const next = { ...current };
      if (value) {
        Object.keys(next).forEach((key) => {
          if (key !== header && next[key] === value) next[key] = "";
        });
      }
      next[header] = value;
      return next;
    });
  }

  function downloadTemplate() {
    const text = Papa.unparse([
      {
        matricule: "B3-2026-001",
        nom: "Dupont",
        prenom: "Amina",
        email: "amina.dupont@example.com",
        telephone: "+33100000000",
        campus: "Paris",
        formation: "Bachelor 3 — Tronc Commun",
        classe: "B3 Tronc Commun",
        groupe: "Groupe A",
      },
    ]);
    const blob = new Blob([text], { type: "text/csv;charset=utf-8" });
    const href = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = href;
    anchor.download = "modele_import_etudiants_scolarys.csv";
    anchor.click();
    URL.revokeObjectURL(href);
  }

  async function provision(id: string) {
    let remaining = 1;
    let imported = 0;
    let failed = 0;
    let loops = 0;

    while (remaining > 0 && loops < 20) {
      const response = await fetch(`/api/students/import/${id}/provision`, { method: "POST" });
      const payload = await response.json().catch(() => ({}));
      if (response.status === 503 && payload.code === "CONFIGURATION_REQUIRED") {
        return {
          complete: false,
          message: "Lot enregistré et validé. Provisioning des comptes : configuration serveur requise (SUPABASE_SECRET_KEY).",
        };
      }
      if (!response.ok) throw new Error(payload.error || "Provisioning impossible.");
      imported += Number(payload.imported || 0);
      failed += Number(payload.failed || 0);
      remaining = Number(payload.remaining || 0);
      loops += 1;
    }

    return {
      complete: remaining === 0,
      message: `Provisioning terminé : ${imported} compte(s) importé(s), ${failed} ligne(s) en erreur.`,
    };
  }

  async function saveImport() {
    if (!validated.length) return;
    setBusy(true);
    setResultMessage("");
    const supabase = createClient();

    const { data: created, error } = await supabase
      .from("scolaria_student_imports")
      .insert({
        organization_id: organizationId,
        class_id: defaultClassId || null,
        filename: filename || null,
        source_type: sourceType,
        status: "validated",
        mapping,
        summary: {
          ...summary,
          duplicate_policy: duplicatePolicy,
        },
      })
      .select("id")
      .single();

    if (error || !created) {
      setBusy(false);
      setResultMessage(error?.message || "Création du lot d’import impossible.");
      return;
    }

    const payload = validated.map((item, index) => ({
      organization_id: organizationId,
      import_id: created.id,
      row_number: index + 2,
      raw_data: item.raw,
      normalized_data: item.normalized,
      validation_status: item.status,
      validation_errors: item.errors,
    }));

    let rowError: string | null = null;
    for (let offset = 0; offset < payload.length; offset += 250) {
      const { error: insertError } = await supabase
        .from("scolaria_student_import_rows")
        .insert(payload.slice(offset, offset + 250));
      if (insertError) {
        rowError = insertError.message;
        break;
      }
    }

    if (rowError) {
      await supabase
        .from("scolaria_student_imports")
        .update({ status: "failed", error_message: rowError })
        .eq("id", created.id);
      setBusy(false);
      setResultMessage(rowError);
      return;
    }

    setImportId(created.id);

    try {
      const provisionResult = await provision(created.id);
      setResultMessage(provisionResult.message);
      setStep(5);
    } catch (provisionError) {
      setResultMessage(provisionError instanceof Error ? provisionError.message : "Provisioning impossible.");
      setStep(5);
    } finally {
      setBusy(false);
    }
  }

  const mappedRequired = ["matricule", "nom", "prenom", "email"].every((target) =>
    Object.values(mapping).includes(target as ImportTarget),
  );

  return (
    <>
      <Link href="/app/students" className="inline-flex items-center gap-2 text-sm font-bold text-[#173f5f]">
        <ArrowLeft size={16} /> Retour aux étudiants
      </Link>
      <div className="mt-5">
        <span className="badge">Import massif</span>
        <h1 className="mt-3 text-3xl font-black">Importer des étudiants</h1>
        <p className="mt-2 text-sm text-[#68758a]">CSV, Excel .xlsx ou copier-coller. Les doublons ne sont jamais créés silencieusement.</p>
      </div>

      <div className="mt-6 flex gap-2 overflow-x-auto pb-1">
        {["Source", "Mapping", "Prévisualisation", "Doublons", "Résultat"].map((label, index) => (
          <div key={label} className={`whitespace-nowrap rounded-full px-3 py-2 text-xs font-black ${step === index + 1 ? "bg-[#173f5f] text-white" : step > index + 1 ? "bg-[#e9f8f3] text-[#08765a]" : "bg-[#eef1f4] text-[#748096]"}`}>
            {index + 1}. {label}
          </div>
        ))}
      </div>

      {step === 1 && (
        <section className="surface mt-6 p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div><h2 className="text-xl font-black">1. Choisir une source</h2><p className="mt-1 text-sm text-[#68758a]">La première ligne doit contenir les noms de colonnes.</p></div>
            <button type="button" className="btn-secondary" onClick={downloadTemplate}><FileSpreadsheet size={17} /> Télécharger le modèle CSV</button>
          </div>

          <div className="mt-6 grid gap-4 lg:grid-cols-2">
            <label className="grid min-h-48 cursor-pointer place-items-center rounded-2xl border-2 border-dashed border-[#d7dee7] bg-[#fbfcfd] p-7 text-center">
              <div>
                <Upload className="mx-auto text-[#173f5f]" />
                <div className="mt-3 font-black">CSV ou Excel .xlsx</div>
                <div className="mt-1 text-sm text-[#748096]">Sélectionnez un fichier depuis votre ordinateur.</div>
              </div>
              <input
                className="sr-only"
                type="file"
                accept=".csv,.txt,.xlsx"
                disabled={busy}
                onChange={(event) => {
                  const file = event.target.files?.[0];
                  if (file) void parseFile(file);
                }}
              />
            </label>

            <div className="rounded-2xl border border-[#e5eaf0] bg-white p-5">
              <div className="font-black">Copier / coller</div>
              <p className="mt-1 text-sm text-[#748096]">Collez un tableau depuis Excel, Sheets ou un fichier CSV.</p>
              <textarea
                className="mt-4 min-h-32 w-full rounded-xl border border-[#d9e0e8] p-3 text-sm"
                value={paste}
                onChange={(event) => setPaste(event.target.value)}
                placeholder={"matricule\tnom\tprenom\temail\nB3-001\tDupont\tAmina\tamina@example.com"}
              />
              <button
                type="button"
                className="btn-primary mt-3"
                disabled={!paste.trim() || busy}
                onClick={() => parseDelimited(paste, "paste", "copier-coller")}
              >
                Analyser les lignes
              </button>
            </div>
          </div>
        </section>
      )}

      {step === 2 && (
        <section className="surface mt-6 p-6">
          <h2 className="text-xl font-black">2. Faire correspondre les colonnes</h2>
          <p className="mt-1 text-sm text-[#68758a]">{rows.length} ligne(s) détectée(s) dans {filename || "la source"}.</p>

          <div className="mt-6 grid gap-3">
            {headers.map((header) => (
              <div key={header} className="grid items-center gap-3 rounded-xl border border-[#edf0f4] p-3 sm:grid-cols-[1fr_auto_1fr]">
                <b className="text-sm">{header}</b>
                <span className="hidden text-[#9aa4b2] sm:block">→</span>
                <select
                  className="min-h-11 rounded-xl border border-[#d9e0e8] bg-white px-3"
                  value={mapping[header] || ""}
                  onChange={(event) => changeMapping(header, event.target.value as ImportTarget)}
                >
                  {targets.map((target) => <option key={target.value || "ignore"} value={target.value}>{target.label}</option>)}
                </select>
              </div>
            ))}
          </div>

          <div className="mt-6 flex flex-wrap gap-3">
            <button type="button" className="btn-secondary" onClick={() => setStep(1)}>Retour</button>
            <button type="button" className="btn-primary" disabled={!mappedRequired} onClick={() => setStep(3)}>Prévisualiser</button>
          </div>
          {!mappedRequired && <p className="mt-3 text-sm text-[#a12c2c]">Matricule, nom, prénom et email doivent être associés.</p>}
        </section>
      )}

      {step === 3 && (
        <section className="mt-6">
          <div className="surface p-6">
            <div className="flex flex-wrap items-end justify-between gap-4">
              <div>
                <h2 className="text-xl font-black">3. Prévisualisation & validation</h2>
                <p className="mt-1 text-sm text-[#68758a]">Choisissez une classe par défaut si le fichier ne fournit pas la colonne classe.</p>
              </div>
              <div className="field min-w-64">
                <label htmlFor="defaultClass">Classe cible par défaut</label>
                <select id="defaultClass" value={defaultClassId} onChange={(event) => setDefaultClassId(event.target.value)}>
                  <option value="">Aucune</option>
                  {classes.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
                </select>
              </div>
            </div>

            <div className="mt-5 grid gap-3 sm:grid-cols-4">
              <div className="metric"><div className="text-xs text-[#748096]">Lignes</div><b className="mt-1 block text-2xl">{summary.total}</b></div>
              <div className="metric"><div className="text-xs text-[#748096]">Valides</div><b className="mt-1 block text-2xl text-[#08765a]">{summary.valid}</b></div>
              <div className="metric"><div className="text-xs text-[#748096]">Doublons</div><b className="mt-1 block text-2xl text-[#8b6410]">{summary.duplicate}</b></div>
              <div className="metric"><div className="text-xs text-[#748096]">Erreurs</div><b className="mt-1 block text-2xl text-[#a12c2c]">{summary.error}</b></div>
            </div>
          </div>

          <div className="table-shell mt-4">
            <table>
              <thead><tr><th>Ligne</th><th>Étudiant</th><th>Email</th><th>Matricule</th><th>Classe</th><th>État</th></tr></thead>
              <tbody>
                {validated.slice(0, 100).map((item, index) => (
                  <tr key={index}>
                    <td>{index + 2}</td>
                    <td><b>{item.normalized.prenom} {item.normalized.nom}</b></td>
                    <td>{item.normalized.email || "—"}</td>
                    <td>{item.normalized.matricule || "—"}</td>
                    <td>{item.normalized.classe || classes.find((c) => c.id === defaultClassId)?.name || "—"}</td>
                    <td>
                      <span className={`badge ${item.status === "valid" ? "badge-ok" : item.status === "duplicate" ? "badge-warn" : "badge-danger"}`}>
                        {item.status === "valid" ? "Valide" : item.status === "duplicate" ? "Doublon" : "Erreur"}
                      </span>
                      {item.errors.length > 0 && <div className="mt-1 text-xs text-[#a12c2c]">{item.errors.join(" · ")}</div>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {validated.length > 100 && <p className="mt-2 text-xs text-[#748096]">Aperçu limité aux 100 premières lignes. Toutes les lignes seront enregistrées.</p>}

          <div className="mt-6 flex flex-wrap gap-3">
            <button type="button" className="btn-secondary" onClick={() => setStep(2)}>Modifier le mapping</button>
            <button type="button" className="btn-primary" disabled={summary.error > 0} onClick={() => setStep(4)}>Gérer les doublons</button>
          </div>
          {summary.error > 0 && <p className="mt-3 text-sm text-[#a12c2c]">Corrigez les erreurs dans le fichier ou le mapping avant de poursuivre.</p>}
        </section>
      )}

      {step === 4 && (
        <section className="surface mt-6 p-6">
          <h2 className="text-xl font-black">4. Traitement des doublons</h2>
          <p className="mt-1 text-sm text-[#68758a]">{summary.duplicate} doublon(s) détecté(s) par email ou matricule.</p>

          <div className="mt-6 grid gap-3">
            {[
              ["ignore", "Ignorer", "Les lignes déjà présentes ne seront pas réimportées."],
              ["update", "Mettre à jour", "Les comptes déjà présents dans cette organisation sont conservés et leurs affectations peuvent être complétées."],
              ["add_to_class", "Ajouter à cette classe", "Le compte existant dans cette organisation est ajouté à la classe cible sans créer un second compte."],
            ].map(([value, title, description]) => (
              <label key={value} className="flex cursor-pointer gap-3 rounded-xl border border-[#e5eaf0] p-4">
                <input type="radio" name="duplicatePolicy" value={value} checked={duplicatePolicy === value} onChange={() => setDuplicatePolicy(value as typeof duplicatePolicy)} />
                <span><b className="block">{title}</b><span className="mt-1 block text-sm text-[#68758a]">{description}</span></span>
              </label>
            ))}
          </div>

          <div className="mt-6 flex flex-wrap gap-3">
            <button type="button" className="btn-secondary" onClick={() => setStep(3)}>Retour</button>
            <button type="button" className="btn-primary" disabled={busy} onClick={() => void saveImport()}>
              {busy ? "Import en cours…" : "Importer les étudiants"}
            </button>
          </div>
        </section>
      )}

      {step === 5 && (
        <section className="surface mt-6 p-8">
          <div className="flex items-start gap-3">
            {resultMessage.toLowerCase().includes("impossible") ? <XCircle className="text-[#a12c2c]" /> : <CheckCircle2 className="text-[#08765a]" />}
            <div>
              <h2 className="text-xl font-black">5. Résultat de l’import</h2>
              <p className="mt-2 text-sm leading-6 text-[#68758a]">{resultMessage || "Lot traité."}</p>
              {importId && <p className="mt-2 text-xs text-[#748096]">Référence du lot : {importId}</p>}
            </div>
          </div>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link href="/app/students" className="btn-primary">Retour aux étudiants</Link>
            <button type="button" className="btn-secondary" onClick={() => { setStep(1); setRows([]); setHeaders([]); setPaste(""); setImportId(null); setResultMessage(""); }}>Nouvel import</button>
          </div>
        </section>
      )}

      {resultMessage && step !== 5 && <p className="mt-5 rounded-xl bg-[#f2f5f8] p-4 text-sm text-[#4f5d73]">{resultMessage}</p>}
    </>
  );
}
