# Mid-Execution Replanning

If a retrospective or harsh review reveals the remaining plan is fundamentally wrong (not just needs tweaking):

1. **State clearly:** "The plan needs replanning from Phase N onward."
2. **Defer remaining TODOs** via `todo-crud.sh defer --reason "Replanning triggered"`
3. **Return to Phase B** (Plan) with the new understanding — the completed phases and their retros are inputs
4. **Re-run Phase C** (Stress-Test) on the revised plan
5. **Re-enroll** via Phase D — new TODOs replace the deferred ones

This is NOT failure — it's the system working as designed. Continuing with a broken plan is the failure.

---

# Resuming a Project

If a project was started in a previous session:

1. Check TODO.md for `#plan-<project>` items via `todo-crud.sh list`
2. Identify the last completed phase
3. Run a retrospective on the completed phase
4. Improve remaining TODOs
5. Resume execution from the next incomplete phase
