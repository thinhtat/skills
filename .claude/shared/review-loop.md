# Review loop

Shared by `/intent`, `/design-spec`, `/design-to-tickets` and `/build-plan`: the user reviews a written file or folder in Plannotator before the skill finishes.

Open the target in Plannotator: run `plannotator annotate <path>…` (one file, several files opened as one review, or a folder) with the Bash tool in the background; it exits when the user finishes in the browser, and its output arrives as a task notification. Handle its output as `~/.claude/skills/plannotator-annotate/SKILL.md` describes, with one addition: after addressing annotations, save the files and run the command again.

The loop ends on an approval (go on) or a closed session (stop the skill there, and print what has been written so far).
