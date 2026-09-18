import { NextResponse } from "next/server";
import { Workbook } from "@excel.js/exceljs";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

const MAX_FILE_BYTES = 10 * 1024 * 1024;
const MAX_ROWS = 5000;
const MAX_COLUMNS = 100;

type RawRow = Record<string, string>;

function toText(value: unknown): string {
  if (value == null) return "";
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === "object") {
    const candidate = value as Record<string, unknown>;
    if (typeof candidate.text === "string") return candidate.text;
    if (candidate.result != null) return String(candidate.result);
    if (Array.isArray(candidate.richText)) {
      return candidate.richText
        .map((part) =>
          typeof part === "object" && part && "text" in part
            ? String((part as { text: unknown }).text)
            : "",
        )
        .join("");
    }
  }
  return String(value);
}

export async function POST(request: Request) {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();

  if (!claimsData?.claims?.sub) {
    return NextResponse.json({ error: "Authentification requise." }, { status: 401 });
  }

  const formData = await request.formData();
  const file = formData.get("file");

  if (!(file instanceof File)) {
    return NextResponse.json({ error: "Fichier Excel manquant." }, { status: 400 });
  }

  if (!file.name.toLowerCase().endsWith(".xlsx")) {
    return NextResponse.json({ error: "Seuls les fichiers .xlsx sont acceptés." }, { status: 400 });
  }

  if (file.size <= 0 || file.size > MAX_FILE_BYTES) {
    return NextResponse.json(
      { error: "Le fichier Excel doit être compris entre 1 octet et 10 Mo." },
      { status: 413 },
    );
  }

  try {
    const workbook = new Workbook();
    await workbook.xlsx.load(await file.arrayBuffer());

    const sheet = workbook.worksheets[0];
    if (!sheet) {
      return NextResponse.json({ error: "Le classeur Excel ne contient aucune feuille." }, { status: 422 });
    }

    const firstRowValues = sheet.getRow(1).values;
    const headerValues: unknown[] = Array.isArray(firstRowValues)
      ? firstRowValues.slice(1, MAX_COLUMNS + 1)
      : [];

    const headers = headerValues
      .map((value) => toText(value).trim())
      .filter((value) => Boolean(value));

    if (!headers.length) {
      return NextResponse.json({ error: "Aucun en-tête exploitable détecté." }, { status: 422 });
    }

    const rows: RawRow[] = [];
    const lastRow = Math.min(sheet.rowCount, MAX_ROWS + 1);

    for (let rowIndex = 2; rowIndex <= lastRow; rowIndex += 1) {
      const row = sheet.getRow(rowIndex);
      const item: RawRow = {};

      headers.forEach((header, index) => {
        item[header] = toText(row.getCell(index + 1).value).trim();
      });

      if (Object.values(item).some(Boolean)) rows.push(item);
    }

    if (!rows.length) {
      return NextResponse.json(
        { error: "Aucune ligne exploitable détectée dans le fichier Excel." },
        { status: 422 },
      );
    }

    return NextResponse.json({
      headers,
      rows,
      truncated: sheet.rowCount > MAX_ROWS + 1,
    });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? `Lecture Excel impossible : ${error.message}`
            : "Lecture Excel impossible.",
      },
      { status: 422 },
    );
  }
}
