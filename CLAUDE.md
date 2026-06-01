# CLAUDE.md — Standing workflow directive

For **any** new feature or change to an existing feature, you will **ALWAYS**
follow this workflow without asking the user to confirm each step:

1. **Create a working feature branch** off `master` (e.g. `NNN-short-slug` or
   `NNN-<feature>-<amendment>` for amendments to an existing feature). Ensure
   `feature.json` (and any related speckit metadata) is updated to reflect the
   new/amended feature.
2. **Run the full speckit pipeline** in order:
   1. `/speckit.clarify`
   2. `/speckit.plan`
   3. `/speckit.tasks`
   4. `/speckit.analyze` — remediate any BLOCKER/MAJOR findings before
      proceeding
   5. `/speckit.implement`
3. **Push, PR, merge**: push the branch to `origin`, raise a PR against
   `master`, and squash-merge it (delete the remote + local branch).
4. **Roll out on master**: `git checkout master && git pull --ff-only`, then
   run `terraform plan` and `terraform apply` for the affected stack(s).
   Restore any temporary infrastructure changes (e.g. state SA firewall) when
   done.

## Autonomy rules

- You are **fully autonomous**. Drive every step (branch creation, speckit
  pipeline, edits, tests, plans, applies, PR creation, merges, post-merge
  rollout, firewall restoration) end-to-end without pausing for
  confirmation. The user is hands-off unless one of the explicit
  stop-and-ask conditions at the bottom of this file fires.
- Make smart, defensible decisions yourself. **Do not ask the user**
  clarifying questions unless a step is genuinely blocked by missing
  information that cannot be inferred.
- **Scratch / temp work belongs in `temp/scratchpad/`** (gitignored), NEVER
  in `/tmp`. State backups, intermediate plan files, ad-hoc notes,
  PR-body drafts, throwaway scripts, etc. all live there. Anything in
  `/tmp` may be lost between sessions; `temp/scratchpad/` persists with
  the workspace and is excluded from git.
- When the speckit `clarify` step would normally ask the user questions,
  encode the most defensible answers directly into the spec as resolved
  clarifications instead.
- Standing answers (apply unless the user says otherwise):
  - Branch name: `NNN-<feature>-<short-slug>` off master.
  - Amendments to a shipped feature: append to the existing
    `specs/NNN-<feature>/` artifacts (new FR-NNN, new C-clarifications,
    new Phase in `tasks.md`) rather than creating a new feature folder.
  - Variables should be runtime-configurable via tfvars, never hard-coded.
  - Defaults preserve existing behaviour.
  - Validation lives at every input boundary (defence-in-depth).
  - Tests added for every new variable/code path (positive + negative).
  - `terraform fmt -recursive` + `terraform test` must be green before merge.
  - **No public access for ANY service (private-by-default mandate).** Every
    service that supports it MUST be deployed with `publicNetworkAccess`
    disabled / public network rules set to `Deny`, and reached exclusively via
    a private endpoint (plus the matching private DNS zone). This applies to
    new services and, on next touch, to existing ones. Any service that
    genuinely cannot use a private endpoint (e.g. a resource type with no
    Private Link support) is the ONLY exception, and must be called out
    explicitly in the spec/PR with the reason. Public exposure is never the
    default and is never enabled "for convenience".
- Live-Azure operations (plan/apply against real subscriptions) are part of
  step 4 and run automatically after merge. Restore the state SA firewall
  (publicNetworkAccess=Disabled, defaultAction=Deny, remove temp IPs)
  when finished.
- Only stop and ask when:
  - A destructive operation has no safe automatic recovery path (e.g.
    deleting a resource that holds irreplaceable data).
  - Credentials/secrets need to be supplied.
  - The user's intent is genuinely ambiguous between materially different
    outcomes.
