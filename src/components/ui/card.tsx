import type { ReactNode } from "react";

interface CardProps {
  children: ReactNode;
  className?: string;
}

export function Card({ children, className }: CardProps) {
  return (
    <section className={`rounded-4xl border border-slate-200 bg-white/90 p-6 shadow-sm ${className ?? ""}`}>
      {children}
    </section>
  );
}
