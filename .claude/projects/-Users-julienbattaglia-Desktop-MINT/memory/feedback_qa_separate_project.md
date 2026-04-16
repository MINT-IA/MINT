---
name: QA as separate project
description: User wants all human QA/testing to be a separate dedicated project, not inline during phase execution
type: feedback
---

Human QA verification should NOT be done inline during autonomous phase execution. The user wants all manual testing, QA, and human verification items to be collected and done as a separate dedicated project using GSD.

**Why:** User prefers to batch all QA work rather than interrupting autonomous execution for manual testing.

**How to apply:** During autonomous execution, always select "Continue without validation" for human_needed verification items. Collect all deferred items — they will be addressed in a separate QA project.
