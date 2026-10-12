# How to Use This Package

Give the entire extracted folder to your coding AI together with the
repository.

Primary instruction: "Read every file in this specification folder
before writing code. Follow 00-MASTER-DEVELOPMENT-PROMPT.md and
08-IMPLEMENTATION-PHASES.md. Begin with Phase 0 and Phase 1. Do not use
placeholder implementations for active-phase functionality. Build and
test before proceeding."

Recommended workflow: - Commit at phase boundaries. - Keep architecture
decisions in `/docs/adr`. - Ask the coding agent to show test output. -
Review rule changes carefully because game logic is the product core. -
Keep online game outcomes server-authoritative. - Keep original
branding/assets throughout.

This blueprint is intentionally product-level. Before launch, finalize
the exact Ludo rules preset, visual identity, supported
countries/languages, monetization model, moderation policy, and
infrastructure scale target.
