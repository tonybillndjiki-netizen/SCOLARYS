"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  BookOpen,
  Boxes,
  GraduationCap,
  LayoutDashboard,
  LogOut,
  Plug,
  School,
  Users,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";

const nav = [
  { href: "/app", label: "Dashboard", icon: LayoutDashboard },
  { href: "/app/programs", label: "Formations", icon: GraduationCap },
  { href: "/app/classes", label: "Classes", icon: School },
  { href: "/app/students", label: "Étudiants", icon: Users },
  { href: "/app/subjects", label: "Matières", icon: BookOpen },
  { href: "/app/integrations", label: "Intégrations", icon: Plug },
] as const;

export function AppShell({
  organizationName,
  roleName,
  userName,
  children,
}: {
  organizationName: string;
  roleName: string;
  userName: string;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();

  async function signOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.replace("/login");
    router.refresh();
  }

  return (
    <div className="min-h-screen lg:grid lg:grid-cols-[260px_1fr]">
      <aside className="hidden border-r border-[#e5eaf0] bg-[#102f49] text-white lg:flex lg:min-h-screen lg:flex-col">
        <div className="border-b border-white/10 p-6">
          <Link href="/app" className="flex items-center gap-3 font-black tracking-tight">
            <span className="grid h-10 w-10 place-items-center rounded-xl bg-white text-[#173f5f]">S</span>
            SCOLARYS
          </Link>
          <div className="mt-5 text-xs font-bold uppercase tracking-[.12em] text-white/45">Établissement</div>
          <div className="mt-1 text-sm font-bold">{organizationName}</div>
        </div>
        <nav className="flex-1 space-y-1 p-4">
          {nav.map(({ href, label, icon: Icon }) => {
            const active = href === "/app" ? pathname === href : pathname.startsWith(href);
            return (
              <Link
                key={href}
                href={href}
                className={`flex items-center gap-3 rounded-xl px-3 py-3 text-sm font-bold transition ${active ? "bg-white text-[#173f5f]" : "text-white/70 hover:bg-white/10 hover:text-white"}`}
              >
                <Icon size={18} /> {label}
              </Link>
            );
          })}
        </nav>
        <div className="border-t border-white/10 p-4">
          <div className="px-3 py-2">
            <div className="text-sm font-bold">{userName}</div>
            <div className="text-xs text-white/50">{roleName}</div>
          </div>
          <button onClick={signOut} className="mt-2 flex w-full items-center gap-3 rounded-xl px-3 py-3 text-sm font-bold text-white/70 hover:bg-white/10 hover:text-white">
            <LogOut size={18} /> Déconnexion
          </button>
        </div>
      </aside>

      <div className="min-w-0">
        <header className="sticky top-0 z-30 border-b border-[#e5eaf0] bg-white/95 px-4 py-3 backdrop-blur lg:hidden">
          <div className="flex items-center justify-between gap-3">
            <Link href="/app" className="font-black text-[#173f5f]">SCOLARYS</Link>
            <button onClick={signOut} aria-label="Se déconnecter" className="rounded-lg border border-[#e5eaf0] p-2"><LogOut size={18} /></button>
          </div>
          <nav className="mt-3 flex gap-2 overflow-x-auto pb-1">
            {nav.map(({ href, label }) => (
              <Link key={href} href={href} className={`whitespace-nowrap rounded-lg px-3 py-2 text-xs font-bold ${pathname === href ? "bg-[#173f5f] text-white" : "bg-[#f0f3f6] text-[#4f5d73]"}`}>
                {label}
              </Link>
            ))}
          </nav>
        </header>
        <main className="mx-auto max-w-[1500px] p-5 sm:p-7 lg:p-9">{children}</main>
      </div>
    </div>
  );
}
