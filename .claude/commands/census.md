---
description: Surface 3 underused tools relevant to the user's next task (Discipline 14)
---

Surface the top 3 underused tools relevant to the task: **$ARGUMENTS**

Run the suggestion mode of the tool census:

!`bash bin/tool-census.sh --suggest "$ARGUMENTS"`

If no suggestions matched, also run:

!`bash bin/tool-census.sh --underused | head -20`

Then present the results to the user as a 3-bullet list (tool name + category + a one-line "when to use" hint inferred from the tool's directory or `SKILL.md` description), and ask whether to invoke one of them before proceeding with the manual approach.

Background: this command implements Discipline 14 of the claude-code-discipline-kit (`tooling/claude-code-discipline-kit/docs/TOOL_DISCOVERY.md`). The premise is that long-lived projects accumulate 100-200 tools but operators only use ~10%. Surfacing 3 relevant underused tools at the start of a non-trivial task forces awareness without adding friction.
