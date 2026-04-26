import { createClient as createSupabaseServerClient } from "@/lib/supabase/server";
import { createUserRecord, getUsers } from "@/lib/db";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

export const metadata = {
  title: "Data Project Dashboard",
  description: "A Next.js + Tailwind + Supabase + Drizzle starter dashboard.",
};

async function createUser(data: FormData) {
  "use server";

  const name = data.get("name")?.toString().trim();
  const email = data.get("email")?.toString().trim();

  if (!name || !email) {
    return;
  }

  await createUserRecord({ name, email });
}

export default async function Home() {
  // const users = await getUsers();
  // const supabase = await createSupabaseServerClient();
  // const { data } = await supabase.auth.getSession();

  return (
    <main className="min-h-screen bg-zinc-50 text-slate-950">
      <div className="container py-10">
        <h1 className="text-3xl font-bold">Data Project Dashboard</h1>
        <p className="mt-2 text-lg text-slate-700">
          A Next.js + Tailwind + Supabase + Drizzle + Shadcn starter dashboard.
        </p>

        <Card className="space-y-6">
          <div>
            <h2 className="text-xl font-semibold">Supabase auth</h2>
          </div>
        </Card>
        </div>
    </main>
  );
}
