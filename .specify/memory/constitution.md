<!--
SYNC IMPACT REPORT
==================
Version change: (unversioned template) → 1.0.0
Added sections: Core Principles (I–V), Tech Stack, Development Workflow, Governance
Modified principles: N/A (initial fill)
Removed sections: all placeholder tokens
Templates checked:
  ✅ plan-template.md — Constitution Check section aligns; no changes required
  ✅ spec-template.md — stack-agnostic; no changes required
  ✅ tasks-template.md — phase structure compatible; no changes required
Deferred TODOs: none
-->

# Data Project Constitution

## Core Principles

### I. TypeScript Everywhere (NON-NEGOTIABLE)

All source files MUST be TypeScript (`.ts` / `.tsx`). JavaScript files are not permitted in `src/`.
Type annotations MUST be explicit at public function boundaries; `any` is forbidden without a
`// eslint-disable` comment explaining the exception. Strict mode (`"strict": true`) MUST remain
enabled in `tsconfig.json`.

**Rationale**: The entire stack (Next.js, Drizzle, shadcn) provides first-class TypeScript types.
Bypassing the type system erodes the safety guarantees those libraries provide.

### II. Server-First Data Access

Database queries MUST originate in React Server Components, Server Actions, or Route Handlers.
Client Components MUST NOT import from `src/db/` or call Drizzle directly. All data fetching
crosses the server boundary before reaching the UI.

**Rationale**: Supabase connection strings and Drizzle schemas must never be exposed to the browser.
Server-side execution also enables connection pooling and keeps secrets in environment variables.

### III. Drizzle ORM as the Sole Data Layer

All database interactions MUST go through Drizzle ORM (`src/db/`). Raw SQL strings, `pg`/`postgres`
client calls outside `src/db/index.ts`, and direct Supabase REST/RPC calls for data mutation are
forbidden. Schema changes MUST be expressed as Drizzle migrations (`drizzle-kit generate` →
`drizzle-kit migrate`).

**Rationale**: A single, typed data layer prevents drift between the schema and runtime code, and
makes migrations auditable.

### IV. shadcn/ui + Tailwind for All UI

UI primitives MUST come from `src/components/ui/` (shadcn components). Custom components MUST be
built by composing shadcn primitives; introducing a second component library is forbidden without
amending this constitution. All styling MUST use Tailwind utility classes. Inline `style` props
are only permitted for dynamic values that cannot be expressed as Tailwind utilities or CSS variables.

**Rationale**: Keeping one component library and one styling system avoids bundle bloat and keeps
visual consistency maintainable without a dedicated design token pipeline.

### V. Simplicity — YAGNI

No abstractions, wrappers, or helper utilities may be introduced until they are needed by two or
more concrete call sites. Premature generalisation (factory functions, plugin systems, generic
repositories) MUST be rejected in review. Each file SHOULD have one clear responsibility.

**Rationale**: The codebase is early-stage. Over-engineering before requirements stabilise
increases maintenance cost with no present benefit.

## Tech Stack

| Layer | Technology | Version / Notes |
|---|---|---|
| Framework | Next.js (App Router) | 16.x, React 19 |
| Language | TypeScript | strict mode |
| Styling | Tailwind CSS | v4 (`@import "tailwindcss"`) |
| Components | shadcn/ui (Radix) | `src/components/ui/` |
| ORM | Drizzle ORM | `src/db/` — `postgres-js` driver |
| Database | Supabase (PostgreSQL) | connection via `DATABASE_URL` env var |
| Auth | Supabase Auth | `@supabase/ssr` for cookie-based sessions |

Environment variables MUST be documented in `.env.example`. Secrets MUST NOT be committed.
`DATABASE_URL` is required for all runtime and migration commands.

## Development Workflow

- **Branching**: feature branches off `main`; PRs require passing lint and build (`next build`).
- **Schema changes**: run `db:generate` → review migration SQL → run `db:migrate`; never edit
  generated migration files by hand.
- **Component additions**: use `npx shadcn@latest add <component>` to add to `src/components/ui/`;
  do not hand-write Radix primitive wrappers that duplicate available shadcn components.
- **Environment**: copy `.env.example` → `.env.local`; never commit `.env.local`.
- **Linting**: `npm run lint` must pass before merge; fix errors, do not suppress them without cause.

## Governance

This constitution supersedes all other implicit conventions in this repository. Any practice not
covered here defaults to Next.js App Router conventions and TypeScript best practices.

Amendments MUST be made by editing this file, incrementing the version, and updating
`Last Amended`. MAJOR bumps (principle removal or incompatible redefinition) require explicit
acknowledgement in the PR description. All pull requests MUST verify compliance with the five
Core Principles before merge.

**Version**: 1.0.0 | **Ratified**: 2026-04-26 | **Last Amended**: 2026-04-26
