"use client";

import { useActionState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Archive, Rocket } from "lucide-react";
import { setCourseStatusAction } from "@/app/app/courses/actions";

type ActionState = {
  status: "idle" | "success" | "error";
  message: string;
};

const initialState: ActionState = { status: "idle", message: "" };

export function CoursePublicationActions({
  courseId,
  currentStatus,
}: {
  courseId: string;
  currentStatus: string;
}) {
  const router = useRouter();
  const [state, action, pending] = useActionState(
    setCourseStatusAction.bind(null, courseId),
    initialState,
  );

  useEffect(() => {
    if (state.status === "success") router.refresh();
  }, [router, state]);

  return (
    <div>
      <form action={action} className="flex flex-wrap gap-3">
        {currentStatus !== "published" && (
          <button className="btn-primary" name="status" value="published" disabled={pending}>
            <Rocket size={17} /> {pending ? "Mise à jour…" : "Publier le cours"}
          </button>
        )}
        {currentStatus !== "draft" && (
          <button className="btn-secondary" name="status" value="draft" disabled={pending}>
            Repasser en brouillon
          </button>
        )}
        {currentStatus !== "archived" && (
          <button className="btn-secondary" name="status" value="archived" disabled={pending}>
            <Archive size={17} /> Archiver
          </button>
        )}
      </form>
      {state.message && (
        <p
          className={`mt-3 rounded-xl p-3 text-sm ${state.status === "error" ? "bg-[#fff0f0] text-[#a12c2c]" : "bg-[#e9f8f3] text-[#08765a]"}`}
          role="status"
          aria-live="polite"
        >
          {state.message}
        </p>
      )}
    </div>
  );
}
