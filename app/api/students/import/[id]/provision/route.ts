import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

type StudentData = {
  matricule?: string;
  nom?: string;
  prenom?: string;
  email?: string;
  telephone?: string;
  classe?: string;
  groupe?: string;
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

export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;

  if (!userId) {
    return NextResponse.json({ error: "Authentification requise." }, { status: 401 });
  }

  const { data: importJob, error: importError } = await supabase
    .from("scolaria_student_imports")
    .select("id, organization_id, class_id, status, summary")
    .eq("id", id)
    .single();

  if (importError || !importJob) {
    return NextResponse.json({ error: "Lot d’import inaccessible." }, { status: 404 });
  }

  const { data: membership } = await supabase
    .from("scolaria_organization_members")
    .select("role_id")
    .eq("organization_id", importJob.organization_id)
    .eq("user_id", userId)
    .eq("status", "active")
    .single();

  if (!membership) {
    return NextResponse.json({ error: "Accès refusé." }, { status: 403 });
  }

  const { data: rolePermissions } = await supabase
    .from("scolaria_role_permissions")
    .select("permission_id")
    .eq("organization_id", importJob.organization_id)
    .eq("role_id", membership.role_id);

  const permissionIds = (rolePermissions ?? []).map((row) => row.permission_id);
  const { data: permissions } = permissionIds.length
    ? await supabase
        .from("scolaria_permissions")
        .select("code")
        .in("id", permissionIds)
    : { data: [] as Array<{ code: string }> };

  if (!(permissions ?? []).some((permission) => permission.code === "students.manage")) {
    return NextResponse.json({ error: "Permission students.manage requise." }, { status: 403 });
  }

  const admin = createAdminClient();
  if (!admin) {
    return NextResponse.json(
      {
        code: "CONFIGURATION_REQUIRED",
        error: "SUPABASE_SECRET_KEY doit être configurée côté serveur pour provisionner les comptes.",
      },
      { status: 503 },
    );
  }

  const summary = (importJob.summary ?? {}) as Record<string, unknown>;
  const duplicatePolicy =
    summary.duplicate_policy === "update" || summary.duplicate_policy === "add_to_class"
      ? String(summary.duplicate_policy)
      : "ignore";

  const [{ data: studentRole }, { data: classes }, { data: rows }] = await Promise.all([
    admin
      .from("scolaria_roles")
      .select("id")
      .eq("organization_id", importJob.organization_id)
      .eq("key", "student")
      .single(),
    admin
      .from("scolaria_classes")
      .select("id, name")
      .eq("organization_id", importJob.organization_id)
      .eq("status", "active"),
    admin
      .from("scolaria_student_import_rows")
      .select("id, row_number, normalized_data, validation_status, validation_errors")
      .eq("import_id", id)
      .in("validation_status", ["valid", "duplicate"])
      .order("row_number")
      .limit(50),
  ]);

  if (!studentRole) {
    return NextResponse.json({ error: "Rôle étudiant introuvable." }, { status: 500 });
  }

  if (!rows?.length) {
    await admin
      .from("scolaria_student_imports")
      .update({ status: "completed" })
      .eq("id", id);

    return NextResponse.json({ imported: 0, failed: 0, remaining: 0 });
  }

  const classByName = new Map(
    (classes ?? []).map((item) => [simplify(item.name), item.id]),
  );

  let imported = 0;
  let failed = 0;

  await admin
    .from("scolaria_student_imports")
    .update({ status: "importing", error_message: null })
    .eq("id", id);

  for (const row of rows) {
    const data = (row.normalized_data ?? {}) as StudentData;
    const email = String(data.email || "").trim().toLowerCase();
    const matricule = String(data.matricule || "").trim();
    const firstName = String(data.prenom || "").trim();
    const lastName = String(data.nom || "").trim();
    const phone = String(data.telephone || "").trim() || null;
    const requestedClass = String(data.classe || "").trim();

    if (row.validation_status === "duplicate" && duplicatePolicy === "ignore") {
      await admin
        .from("scolaria_student_import_rows")
        .update({ validation_status: "ignored" })
        .eq("id", row.id);
      continue;
    }

    const classId =
      (requestedClass ? classByName.get(simplify(requestedClass)) : null) ||
      importJob.class_id ||
      null;

    if (!email || !matricule || !firstName || !lastName || !classId) {
      failed += 1;
      await admin
        .from("scolaria_student_import_rows")
        .update({
          validation_status: "error",
          validation_errors: ["Données obligatoires ou classe cible manquantes au provisioning."],
        })
        .eq("id", row.id);
      continue;
    }

    const { data: existingStudentByMatricule } = await admin
      .from("scolaria_student_records")
      .select("user_id, email")
      .eq("organization_id", importJob.organization_id)
      .eq("matricule", matricule)
      .maybeSingle();

    if (
      existingStudentByMatricule &&
      existingStudentByMatricule.email.toLowerCase() !== email
    ) {
      failed += 1;
      await admin
        .from("scolaria_student_import_rows")
        .update({
          validation_status: "error",
          validation_errors: ["Matricule déjà attribué à un autre étudiant."],
        })
        .eq("id", row.id);
      continue;
    }

    const { data: existingProfile } = await admin
      .from("scolaria_profiles")
      .select("id, email")
      .ilike("email", email)
      .maybeSingle();

    let targetUserId = existingProfile?.id ?? null;

    if (targetUserId) {
      const { data: sameOrgMembership } = await admin
        .from("scolaria_organization_members")
        .select("id")
        .eq("organization_id", importJob.organization_id)
        .eq("user_id", targetUserId)
        .maybeSingle();

      if (!sameOrgMembership) {
        failed += 1;
        await admin
          .from("scolaria_student_import_rows")
          .update({
            validation_status: "error",
            validation_errors: [
              "Compte déjà existant hors de cette organisation : invitation explicite requise.",
            ],
          })
          .eq("id", row.id);
        continue;
      }
    } else {
      const { data: invited, error: inviteError } =
        await admin.auth.admin.inviteUserByEmail(email, {
          data: {
            first_name: firstName,
            last_name: lastName,
            display_name: `${firstName} ${lastName}`.trim(),
          },
        });

      if (inviteError || !invited.user) {
        failed += 1;
        await admin
          .from("scolaria_student_import_rows")
          .update({
            validation_status: "error",
            validation_errors: [
              inviteError?.message || "Invitation du compte impossible.",
            ],
          })
          .eq("id", row.id);
        continue;
      }

      targetUserId = invited.user.id;

      await admin.from("scolaria_invitations").insert({
        organization_id: importJob.organization_id,
        email,
        role_id: studentRole.id,
        class_id: classId,
        invitation_type: "student",
        status: "pending",
        invited_by: userId,
        created_by: userId,
      });
    }

    if (!targetUserId) {
      failed += 1;
      continue;
    }

    const { error: memberError } = await admin
      .from("scolaria_organization_members")
      .upsert(
        {
          organization_id: importJob.organization_id,
          user_id: targetUserId,
          role_id: studentRole.id,
          status: "active",
          joined_at: new Date().toISOString(),
          created_by: userId,
        },
        { onConflict: "organization_id,user_id" },
      );

    const { error: studentError } = await admin
      .from("scolaria_student_records")
      .upsert(
        {
          organization_id: importJob.organization_id,
          user_id: targetUserId,
          matricule,
          first_name: firstName,
          last_name: lastName,
          email,
          phone,
          status: "active",
          source: "import",
          created_by: userId,
        },
        { onConflict: "organization_id,user_id" },
      );

    const { error: classError } = await admin
      .from("scolaria_class_memberships")
      .upsert(
        {
          organization_id: importJob.organization_id,
          class_id: classId,
          user_id: targetUserId,
          membership_type: "student",
          matricule,
          status: "active",
          created_by: userId,
        },
        { onConflict: "class_id,user_id,membership_type" },
      );

    if (memberError || studentError || classError) {
      failed += 1;
      await admin
        .from("scolaria_student_import_rows")
        .update({
          validation_status: "error",
          validation_errors: [
            memberError?.message ||
              studentError?.message ||
              classError?.message ||
              "Échec de l’affectation étudiant.",
          ],
        })
        .eq("id", row.id);
      continue;
    }

    imported += 1;
    await admin
      .from("scolaria_student_import_rows")
      .update({
        validation_status: "imported",
        existing_user_id: targetUserId,
        validation_errors: [],
      })
      .eq("id", row.id);
  }

  const { count: remaining } = await admin
    .from("scolaria_student_import_rows")
    .select("*", { count: "exact", head: true })
    .eq("import_id", id)
    .in("validation_status", ["valid", "duplicate"]);

  if ((remaining ?? 0) === 0) {
    await admin
      .from("scolaria_student_imports")
      .update({
        status: "completed",
        summary: {
          ...summary,
          last_batch_imported: imported,
          last_batch_failed: failed,
        },
      })
      .eq("id", id);
  }

  return NextResponse.json({
    imported,
    failed,
    remaining: remaining ?? 0,
  });
}
