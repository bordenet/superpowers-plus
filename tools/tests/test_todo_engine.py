#!/usr/bin/env python3
"""Integration tests for todo-engine.py — CRUD operations on TODO.md.

Tests cover: add, complete, move, defer, list, next-id, whitespace
normalization, locking, backup, and argparse compatibility.

Run: python3 tools/tests/test_todo_engine.py -v
"""
import contextlib
import importlib.util
import io
import os
import tempfile
import unittest
import unittest.mock
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

# ---------------------------------------------------------------------------
# Load engine module from file path (avoids package structure requirement)
# ---------------------------------------------------------------------------
ENGINE_PATH = Path(__file__).resolve().parents[1] / "todo-engine.py"


def load_engine():
    if not ENGINE_PATH.exists():
        raise FileNotFoundError(f"todo-engine.py not found at {ENGINE_PATH}")
    spec = importlib.util.spec_from_file_location("todo_engine", ENGINE_PATH)
    assert spec is not None, f"Failed to create module spec from {ENGINE_PATH}"
    assert spec.loader is not None, f"Module spec has no loader for {ENGINE_PATH}"
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


SAMPLE_TODO = """\
# ACTIVE TASKS

## P1 - Today

- [ ] [20260323-01] Fix critical auth bug #engineering #urgent
  - Added: 2026-03-23

## P2 - This Week

- [ ] [20260323-02] Review PR for config refactor #engineering
  - Added: 2026-03-23
  - Note: Waiting on CI

## P3 - Backlog

- [ ] [20260323-03] Document onboarding process #process
  - Added: 2026-03-23

---

# HISTORY

## 2026-03-22
- [x] [20260322-01] Set up test fixtures #engineering
  - Done: 2026-03-22

---

# DEFERRED

---

# METRICS
"""


class TodoEngineTests(unittest.TestCase):
    """Integration tests for todo-engine.py CRUD operations."""

    def setUp(self):
        self.engine = load_engine()
        self.tmpdir = tempfile.mkdtemp(prefix="todo-test-")
        self.todo_path = Path(self.tmpdir) / "TODO.md"
        self.todo_path.write_text(SAMPLE_TODO)
        # Point TODO_FILE_PATH at our temp file so _validate_canonical_path passes
        self._orig_env = os.environ.get("TODO_FILE_PATH")
        os.environ["TODO_FILE_PATH"] = str(self.todo_path)
        # Isolate shadow dir so tests don't interfere with each other
        self._shadow_tmp = tempfile.mkdtemp(prefix="todo-shadow-test-")
        self._orig_shadow_dir = self.engine.SHADOW_DIR
        self.engine.SHADOW_DIR = self._shadow_tmp

    def tearDown(self):
        import shutil
        self.engine.SHADOW_DIR = self._orig_shadow_dir
        if self._orig_env is None:
            os.environ.pop("TODO_FILE_PATH", None)
        else:
            os.environ["TODO_FILE_PATH"] = self._orig_env
        # Clear immutable flags before cleanup (chflags uchg blocks rmtree)
        if self.todo_path.exists():
            self.engine._clear_immutable(str(self.todo_path))
        shutil.rmtree(self._shadow_tmp, ignore_errors=True)
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    # -- Original 4 tests (recovered from bytecache names) --

    def test_main_avoids_python36_incompatible_add_subparsers_required(self):
        """Verify argparse setup works (required=True on subparsers needs 3.7+)."""
        eng = self.engine
        # Just verify the parser can be constructed and help works
        with self.assertRaises(SystemExit):
            with mock.patch("sys.argv", ["todo-engine.py", "--help"]):
                with contextlib.redirect_stdout(io.StringIO()):
                    eng.main()

    def test_write_file_normalizes_whitespace(self):
        """Verify write_file collapses excessive blank lines."""
        eng = self.engine
        # Use full valid structure with excessive blank lines
        content = (
            "# ACTIVE TASKS\n\n## P1 - Today\n\n\n\n\n"
            "- [ ] 20260322-01 | some task #test\n\n"
            "## P2 - This Week\n\n## P3 - Backlog\n\n---\n\n"
            "# HISTORY\n\n---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
        )
        eng.write_file(str(self.todo_path), content)
        result = self.todo_path.read_text()
        self.assertNotIn("\n\n\n\n", result)
        self.assertIn("# ACTIVE TASKS", result)
        self.assertIn("some task", result)

    def test_write_rejects_raw_task_list(self):
        """Reject raw bullet list with no structure (the 2026-03-23 incident)."""
        eng = self.engine
        raw = "- [ ] Do something\n- [ ] Do another thing\n"
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), raw)

    def test_write_rejects_scaffold_only_wipe(self):
        """Reject content with required headers but no real tasks (empty wipe)."""
        eng = self.engine
        skeleton = (
            "# ACTIVE TASKS\n\n## P1\n\n## P2\n\n## P3\n\n"
            "# HISTORY\n\n# DEFERRED\n\n# METRICS\n"
        )
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), skeleton)

    def test_write_rejects_wrong_header_order(self):
        """Reject content where required headers appear out of order."""
        eng = self.engine
        wrong_order = (
            "# HISTORY\n\n## 2026-03-22\n\n"
            "# ACTIVE TASKS\n\n## P1\n\n## P2\n\n## P3\n\n"
            "# DEFERRED\n\n# METRICS\n"
        )
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), wrong_order)

    def test_write_rejects_duplicate_headers(self):
        """Reject content with duplicate top-level headers."""
        eng = self.engine
        duped = (
            "# ACTIVE TASKS\n\n## P1\n\n## P2\n\n## P3\n\n---\n\n"
            "# HISTORY\n\n---\n\n# ACTIVE TASKS\n\n"
            "# DEFERRED\n\n# METRICS\n"
        )
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), duped)

    def test_write_rejects_missing_priority_subsections(self):
        """Reject content missing P1/P2/P3 under ACTIVE TASKS."""
        eng = self.engine
        no_p_sections = (
            "# ACTIVE TASKS\n\n- [ ] orphan task\n\n---\n\n"
            "# HISTORY\n\n---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
        )
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), no_p_sections)

    def test_write_rejects_missing_metrics(self):
        """Reject content missing # METRICS section."""
        eng = self.engine
        no_metrics = (
            "# ACTIVE TASKS\n\n## P1\n\n## P2\n\n## P3\n\n---\n\n"
            "# HISTORY\n\n---\n\n# DEFERRED\n\n---\n\n"
            "- [ ] 20260322-01 | some task #test\n"
        )
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), no_metrics)

    def test_write_rejects_scaffold_with_filler(self):
        """Reject scaffold + arbitrary filler text (no real task artifacts)."""
        eng = self.engine
        filler = (
            "# ACTIVE TASKS\n\n## P1\n\n## P2\n\n## P3\n\n---\n\n"
            "# HISTORY\n\n---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
            "placeholder filler line\n"
        )
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), filler)

    def test_write_rejects_scaffold_with_comments(self):
        """Reject scaffold + HTML comments (like a template file)."""
        eng = self.engine
        template = (
            "# ACTIVE TASKS\n\n## P1\n\n<!-- high priority -->\n\n"
            "## P2\n\n## P3\n\n---\n\n"
            "# HISTORY\n\n---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
        )
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), template)

    def test_write_rejects_duplicate_priority_subsections(self):
        """Reject content with duplicate ## P1 subsections."""
        eng = self.engine
        dup_p1 = (
            "# ACTIVE TASKS\n\n## P1\n\n- [ ] task 1\n\n## P1\n\n"
            "## P2\n\n## P3\n\n---\n\n"
            "# HISTORY\n\n---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
        )
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), dup_p1)

    def test_write_rejects_wrong_priority_order(self):
        """Reject content where P3 appears before P1."""
        eng = self.engine
        wrong_p_order = (
            "# ACTIVE TASKS\n\n## P3\n\n- [ ] task\n\n## P1\n\n## P2\n\n"
            "---\n\n# HISTORY\n\n---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
        )
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.write_file(str(self.todo_path), wrong_p_order)

    # -- Bug #2 fix: pop-before-remove in backup rotation --

    def test_backup_rotation_tolerates_unremovable_file(self):
        """If oldest backup can't be deleted, rotation continues and a WARNING is emitted."""
        eng = self.engine
        import glob as _glob
        # Pre-create BAK_MAX_KEEP + 2 .bak files so rotation must remove 2
        bak_dir = self.engine.SHADOW_DIR
        os.makedirs(bak_dir, exist_ok=True)
        for i in range(eng.BAK_MAX_KEEP + 2):
            ts = f"20260101-{i:06d}"
            p = os.path.join(bak_dir, f"TODO.{ts}.bak")
            with open(p, "w") as f:
                f.write(f"backup {i}\n")
        all_before = sorted(_glob.glob(os.path.join(bak_dir, "TODO.*.bak")))
        oldest = all_before[0]
        # Save the real os.remove before patching so the mock can delegate to it
        real_remove = os.remove
        def selective_fail(path):
            if path == oldest:
                raise OSError("locked — cannot delete")
            real_remove(path)
        with mock.patch("os.remove", side_effect=selective_fail):
            with contextlib.redirect_stderr(io.StringIO()) as captured:
                eng.backup(str(self.todo_path))
            self.assertIn("WARNING", captured.getvalue())
        # Rotation must have continued past the stuck file:
        # worst case = BAK_MAX_KEEP (good) + 1 (stuck oldest) + 1 (new backup) = BAK_MAX_KEEP + 2
        # but the fix ensures it deletes subsequent files, keeping total ≤ BAK_MAX_KEEP + 1
        all_after = sorted(_glob.glob(os.path.join(bak_dir, "TODO.*.bak")))
        self.assertLessEqual(len(all_after), eng.BAK_MAX_KEEP + 1)

    def test_complete_with_note_moves_to_history(self):
        """Verify completion moves task to HISTORY with note metadata."""
        eng = self.engine
        args = SimpleNamespace(id="20260323-02", note="Fixed the issue")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_complete(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        # Task must be in HISTORY with [x]
        history = content.split("# HISTORY")[1]
        self.assertIn("[x] [20260323-02]", history)
        self.assertIn("Done: 2026-", history)
        self.assertIn("Fixed the issue", history)
        # Task must NOT be in ACTIVE
        active = content.split("# HISTORY")[0]
        self.assertNotIn("[20260323-02]", active)

    def test_complete_with_real_multiline_note(self):
        """Verify completion with actual newlines produces indented metadata bullets."""
        eng = self.engine
        args = SimpleNamespace(id="20260323-01", note="Line one\nLine two")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_complete(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        history = content.split("# HISTORY")[1]
        self.assertIn("[x] [20260323-01]", history)
        # Each note line must be a properly indented metadata bullet
        self.assertIn("  - Progress: Line one", history)
        self.assertIn("  - Progress: Line two", history)
        # No orphan lines — find the task block by its [x] line and check metadata
        lines = history.split("\n")
        task_start = next(i for i, l in enumerate(lines) if "[x] [20260323-01]" in l)
        # All metadata lines after the task line must be indented "  - "
        for line in lines[task_start + 1:]:
            if not line.strip():
                break  # end of task block
            self.assertTrue(line.startswith("  - "),
                            f"Orphan line (not indented metadata): {line!r}")

    def test_defer_moves_to_deferred_with_reason(self):
        """Verify defer moves task to DEFERRED section with reason metadata."""
        eng = self.engine
        args = SimpleNamespace(id="20260323-03", reason="Blocked on access")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_defer(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        deferred = content.split("# DEFERRED")[1]
        self.assertIn("20260323-03", deferred)
        self.assertIn("Deferred:", deferred)
        self.assertIn("Reason: Blocked on access", deferred)
        # Task must NOT be in P3 anymore
        p3_section = content.split("## P3")[1].split("---")[0] if "## P3" in content else ""
        self.assertNotIn("20260323-03", p3_section)

    def test_defer_with_real_multiline_reason(self):
        """Verify defer with actual newlines produces indented metadata bullets."""
        eng = self.engine
        args = SimpleNamespace(id="20260323-03", reason="Blocked\nNeed credentials")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_defer(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        deferred = content.split("# DEFERRED")[1]
        self.assertIn("20260323-03", deferred)
        # Each reason line must be a properly indented metadata bullet
        self.assertIn("  - Reason: Blocked", deferred)
        self.assertIn("  - Reason: Need credentials", deferred)
        # No orphan lines — find the task block and check metadata
        lines = deferred.split("\n")
        task_start = next(i for i, l in enumerate(lines) if "[20260323-03]" in l)
        for line in lines[task_start + 1:]:
            if not line.strip():
                break
            self.assertTrue(line.startswith("  - "),
                            f"Orphan line (not indented metadata): {line!r}")

    # -- New integration tests --

    def test_add_task_to_p1(self):
        eng = self.engine
        args = SimpleNamespace(priority="P1", description="Urgent hotfix",
                               tags="#engineering #hotfix", note="")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_add(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        self.assertIn("Urgent hotfix", content)
        self.assertIn("#engineering #hotfix", content)
        p1_section = content.split("## P1")[1].split("## P2")[0]
        self.assertIn("Urgent hotfix", p1_section)

    def test_add_task_to_p3_with_note(self):
        eng = self.engine
        args = SimpleNamespace(priority="P3", description="Research competitor",
                               tags="#product", note="Check their API docs")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_add(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        p3_section = content.split("## P3")[1].split("---")[0]
        self.assertIn("Research competitor", p3_section)
        self.assertIn("Check their API docs", p3_section)


    def test_add_task_with_multiline_note(self):
        """Verify add with real newlines produces indented metadata bullets."""
        eng = self.engine
        args = SimpleNamespace(priority="P1", description="Multi-note task",
                               tags="#test", note="First line\nSecond line")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_add(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        p1 = content.split("## P1")[1].split("## P2")[0]
        self.assertIn("Multi-note task", p1)
        self.assertIn("  - First line", p1)
        self.assertIn("  - Second line", p1)
        # No orphan lines in the task block
        lines = p1.split("\n")
        task_start = next(i for i, l in enumerate(lines) if "Multi-note task" in l)
        for line in lines[task_start + 1:]:
            if not line.strip():
                break
            self.assertTrue(line.startswith("  "),
                            f"Orphan line in add output: {line!r}")

    def test_move_task_p3_to_p1(self):
        """Verify move relocates task between priority sections."""
        eng = self.engine
        args = SimpleNamespace(id="20260323-03", to="P1")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_move(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        p1 = content.split("## P1")[1].split("## P2")[0]
        self.assertIn("20260323-03", p1)
        p3 = content.split("## P3")[1].split("---")[0]
        self.assertNotIn("20260323-03", p3)

    def test_move_task_p1_to_p2(self):
        eng = self.engine
        args = SimpleNamespace(id="20260323-01", to="P2")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_move(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        p2 = content.split("## P2")[1].split("## P3")[0]
        self.assertIn("20260323-01", p2)
        p1 = content.split("## P1")[1].split("## P2")[0]
        self.assertNotIn("20260323-01", p1)

    def test_move_invalid_target_errors(self):
        eng = self.engine
        args = SimpleNamespace(id="20260323-01", to="P4")
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stdout(io.StringIO()):
                eng.cmd_move(args, str(self.todo_path), json_mode=False)

    def test_move_nonexistent_task_errors(self):
        eng = self.engine
        args = SimpleNamespace(id="99990101-99", to="P1")
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stdout(io.StringIO()):
                eng.cmd_move(args, str(self.todo_path), json_mode=False)

    def test_list_filter_by_priority(self):
        eng = self.engine
        args = SimpleNamespace(priority="P1", tag="", show_all=False)
        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
            eng.cmd_list(args, str(self.todo_path), json_mode=True)
            output = buf.getvalue()
        import json
        data = json.loads(output)
        self.assertEqual(data["count"], 1)
        self.assertIn("20260323-01", data["tasks"][0]["id"])

    def test_list_filter_by_tag(self):
        eng = self.engine
        args = SimpleNamespace(priority="", tag="#process", show_all=False)
        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
            eng.cmd_list(args, str(self.todo_path), json_mode=True)
            output = buf.getvalue()
        import json
        data = json.loads(output)
        self.assertEqual(data["count"], 1)
        self.assertEqual(data["tasks"][0]["id"], "20260323-03")

    def test_next_id_allocates_sequential(self):
        eng = self.engine
        content = self.todo_path.read_text()
        # Use explicit date matching the fixture
        tid = eng.next_task_id(content, today="20260323")
        # Already has 20260323-01, -02, -03 so next should be -04
        self.assertEqual(tid, "20260323-04")

    def test_next_id_json_output(self):
        eng = self.engine
        args = SimpleNamespace()
        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
            eng.cmd_next_id(args, str(self.todo_path), json_mode=True)
            output = buf.getvalue()
        import json
        data = json.loads(output)
        # next_id is date-dependent; just verify format
        self.assertRegex(data["next_id"], r"^\d{8}-\d{2}$")


    def test_cmd_path_text_mode_returns_bare_path(self):
        """cmd_path in text mode prints only the bare path, no key=value."""
        eng = self.engine
        args = SimpleNamespace()
        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
            eng.cmd_path(args, str(self.todo_path), json_mode=False)
            output = buf.getvalue().strip()
        # Should be a bare path, not "path=/some/path"
        self.assertFalse(output.startswith("path="))
        self.assertEqual(output, str(self.todo_path))

    def test_cmd_path_json_mode_returns_structured(self):
        """cmd_path in JSON mode returns {"path": "..."}."""
        eng = self.engine
        args = SimpleNamespace()
        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
            eng.cmd_path(args, str(self.todo_path), json_mode=True)
            output = buf.getvalue()
        import json
        data = json.loads(output)
        self.assertEqual(data["path"], str(self.todo_path))

    def test_cmd_cat_text_mode_returns_file_contents(self):
        """cmd_cat in text mode prints raw TODO.md contents."""
        eng = self.engine
        args = SimpleNamespace()
        expected = self.todo_path.read_text()
        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
            eng.cmd_cat(args, str(self.todo_path), json_mode=False)
            output = buf.getvalue()
        self.assertEqual(output, expected)

    def test_cmd_cat_json_mode_returns_structured(self):
        """cmd_cat in JSON mode returns {"path": "...", "content": "..."}."""
        eng = self.engine
        args = SimpleNamespace()
        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
            eng.cmd_cat(args, str(self.todo_path), json_mode=True)
            output = buf.getvalue()
        import json
        data = json.loads(output)
        self.assertEqual(data["path"], str(self.todo_path))
        self.assertIn("# ACTIVE TASKS", data["content"])

    def test_cmd_cat_missing_file_errors(self):
        """cmd_cat errors when TODO.md doesn't exist (FileNotFoundError)."""
        eng = self.engine
        args = SimpleNamespace()
        missing = str(self.todo_path.parent / "nonexistent.md")
        with self.assertRaises(FileNotFoundError):
            eng.cmd_cat(args, missing, json_mode=False)

    def test_fallback_warning_emitted_to_stderr(self):
        """resolve_todo_path() warns on stderr when falling back to default."""
        eng = self.engine
        empty_home = Path(self.tmpdir) / "warn_home"
        empty_home.mkdir()
        with io.StringIO() as err_buf:
            with contextlib.redirect_stderr(err_buf):
                with unittest.mock.patch.dict(
                    os.environ, {"TODO_FILE_PATH": ""}, clear=False
                ):
                    with unittest.mock.patch(
                        "pathlib.Path.home", return_value=empty_home
                    ):
                        orig_eu = os.path.expanduser
                        def fake_eu(p):
                            return str(empty_home) + p[1:] if p.startswith("~") else orig_eu(p)
                        with unittest.mock.patch(
                            "os.path.expanduser", side_effect=fake_eu
                        ):
                            path = eng.resolve_todo_path()
            stderr_output = err_buf.getvalue()
        self.assertIn("WARNING", stderr_output)
        self.assertIn("TODO path not found", stderr_output)
        self.assertIn(".codex/TODO.md", path)

    def test_complete_nonexistent_task_errors(self):
        eng = self.engine
        args = SimpleNamespace(id="99990101-99", note="")
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.cmd_complete(args, str(self.todo_path), json_mode=False)

    def test_add_invalid_priority_errors(self):
        eng = self.engine
        args = SimpleNamespace(priority="P4", description="Bad priority",
                               tags="", note="")
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.cmd_add(args, str(self.todo_path), json_mode=False)

    def test_resolve_todo_path_env_var_wins(self):
        """Verify TODO_FILE_PATH env var takes highest precedence."""
        eng = self.engine
        with mock.patch.dict("os.environ", {"TODO_FILE_PATH": str(self.todo_path)}, clear=False):
            resolved = eng.resolve_todo_path()
            self.assertEqual(resolved, str(self.todo_path))

    def test_resolve_todo_path_env_var_beats_dotenv(self):
        """Verify env var takes precedence over .codex/.env subprocess result."""
        eng = self.engine
        env_path = "/tmp/from-env-var.md"
        dotenv_path = "/tmp/from-dotenv.md"
        # Mock subprocess to simulate .codex/.env returning a different path
        fake_result = SimpleNamespace(stdout=f"{dotenv_path}\n", returncode=0)
        with mock.patch.dict("os.environ", {"TODO_FILE_PATH": env_path}, clear=False):
            with mock.patch("subprocess.run", return_value=fake_result):
                resolved = eng.resolve_todo_path()
                # Env var must win over dotenv
                self.assertEqual(resolved, env_path)

    def test_resolve_todo_path_dotenv_used_when_env_unset(self):
        """Verify .codex/.env is consulted when TODO_FILE_PATH env var is empty."""
        eng = self.engine
        dotenv_path = "/tmp/from-dotenv.md"
        fake_result = SimpleNamespace(stdout=f"{dotenv_path}\n", returncode=0)
        fake_env_file = Path(self.tmpdir) / ".codex" / ".env"
        fake_env_file.parent.mkdir(parents=True)
        fake_env_file.write_text(f'export TODO_FILE_PATH="{dotenv_path}"\n')
        with mock.patch.dict("os.environ", {"TODO_FILE_PATH": ""}, clear=False):
            with mock.patch("pathlib.Path.home", return_value=Path(self.tmpdir)):
                with mock.patch("subprocess.run", return_value=fake_result):
                    resolved = eng.resolve_todo_path()
                    self.assertEqual(resolved, dotenv_path)

    def test_resolve_todo_path_default_when_no_env_no_dotenv(self):
        """Verify default ~/.codex/TODO.md when env var is empty and no .codex/.env."""
        eng = self.engine
        empty_home = Path(self.tmpdir) / "empty_home"
        empty_home.mkdir()
        expected = str(empty_home / ".codex" / "TODO.md")
        with mock.patch.dict("os.environ", {"TODO_FILE_PATH": ""}, clear=False):
            # Mock Path.home() so .codex/.env doesn't exist at fake home
            with mock.patch("pathlib.Path.home", return_value=empty_home):
                # Mock expanduser so ~ resolves to our fake home
                orig_expanduser = os.path.expanduser
                def fake_expanduser(p):
                    if p.startswith("~"):
                        return str(empty_home) + p[1:]
                    return orig_expanduser(p)
                with mock.patch("os.path.expanduser", side_effect=fake_expanduser):
                    resolved = eng.resolve_todo_path()
                    self.assertEqual(resolved, expected)

    def test_locking_and_release(self):
        eng = self.engine
        path = str(self.todo_path)
        # Acquire lock
        result = eng.acquire_lock(path)
        self.assertTrue(result)
        lock_dir = eng._lock_dir(path)
        self.assertTrue(Path(lock_dir).is_dir())
        # Release lock
        eng.release_lock(path)
        self.assertFalse(Path(lock_dir).exists())

    def test_backup_creates_timestamped_file(self):
        eng = self.engine
        bak = eng.backup(str(self.todo_path))
        self.assertTrue(Path(bak).exists())
        # Content should match
        original = self.todo_path.read_text()
        self.assertEqual(Path(bak).read_text(), original)


    def test_backup_writes_to_shadow_dir_not_alongside_todo(self):
        """Backup must write to SHADOW_DIR, not next to TODO.md.

        Regression: when TODO.md lives on an immutable filesystem (OneDrive +
        chflags uchg), writing .bak files alongside it fails with
        PermissionError.  Backup should use ~/.codex/todo-shadow/ instead.
        """
        eng = self.engine
        bak = eng.backup(str(self.todo_path))
        bak_path = Path(bak)
        # Must exist
        self.assertTrue(bak_path.exists())
        # Must be in SHADOW_DIR, NOT alongside TODO.md
        self.assertTrue(
            str(bak_path).startswith(eng.SHADOW_DIR),
            f"Backup {bak_path} should be under SHADOW_DIR ({eng.SHADOW_DIR}), "
            f"not alongside TODO.md ({self.todo_path.parent})"
        )
        # Must NOT be alongside TODO.md
        self.assertNotEqual(
            bak_path.parent, self.todo_path.parent,
            "Backup should not be in the same directory as TODO.md"
        )
        # Content should match
        original = self.todo_path.read_text()
        self.assertEqual(bak_path.read_text(), original)


    def test_backup_rotation_deletes_old_files(self):
        """Backup rotation must actually delete old .bak files.

        Regression: shutil.copy2 propagates uchg flags from an immutable
        source, making backups undeletable and rotation silently broken.
        Using copyfile (content-only) avoids this.
        """
        eng = self.engine
        import glob
        # Directly create BAK_MAX_KEEP + 3 fake .bak files with known names
        os.makedirs(eng.SHADOW_DIR, exist_ok=True)
        created = []
        for i in range(eng.BAK_MAX_KEEP + 3):
            name = os.path.join(eng.SHADOW_DIR, f"TODO.20260101-{i:06d}.bak")
            Path(name).write_text(f"backup {i}")
            created.append(name)
        # Now call backup() which should trigger rotation
        bak = eng.backup(str(self.todo_path))
        created.append(bak)
        # Count .bak files in SHADOW_DIR
        bak_pattern = os.path.join(eng.SHADOW_DIR, "TODO.*.bak")
        remaining = glob.glob(bak_pattern)
        self.assertLessEqual(
            len(remaining), eng.BAK_MAX_KEEP,
            f"Expected at most {eng.BAK_MAX_KEEP} backups after rotation, "
            f"found {len(remaining)}"
        )
        # Verify oldest ones were rotated out
        for old_bak in created[:4]:
            self.assertFalse(
                os.path.exists(old_bak),
                f"Old backup {old_bak} should have been rotated out"
            )


    def test_backup_does_not_inherit_readonly_from_source(self):
        """Backup file must be writable/deletable even if source is read-only.

        This is the actual regression test for the copy2→copyfile fix.
        copy2 propagates file permissions/flags; copyfile does not.
        If this test fails, backup rotation will silently break in production
        because old .bak files become undeletable.
        """
        eng = self.engine
        # Make source read-only (simulates chmod 444 portion of immutability)
        self.todo_path.chmod(0o444)
        try:
            bak = eng.backup(str(self.todo_path))
            bak_path = Path(bak)
            # The backup must exist
            self.assertTrue(bak_path.exists())
            # The backup must be writable (not inheriting read-only)
            self.assertTrue(
                os.access(bak, os.W_OK),
                f"Backup {bak} should be writable, but inherited read-only from source"
            )
            # The backup must be deletable
            try:
                os.remove(bak)
            except OSError as e:
                self.fail(f"Backup {bak} should be deletable but got: {e}")
        finally:
            # Restore write permission for test cleanup
            self.todo_path.chmod(0o644)




    def test_whitespace_normalization(self):
        eng = self.engine
        content = "a\n\n\n\n\n\nb\n"  # 6 blank lines
        result = eng._normalize_whitespace(content)
        self.assertNotIn("\n\n\n\n", result)
        self.assertIn("a\n\n\n", result)  # collapsed to 2 blank lines

    def test_find_task_includes_continuation_lines(self):
        eng = self.engine
        content = self.todo_path.read_text()
        loc = eng.find_task(content, "20260323-02")
        self.assertIsNotNone(loc)
        start, end = loc
        block = content[start:end]
        self.assertIn("20260323-02", block)
        self.assertIn("Note: Waiting on CI", block)


    # -- Claim/Unclaim/Reap tests --

    def test_claim_marks_task_in_progress(self):
        """Claim changes [ ] to [/] and adds Claimed: metadata."""
        eng = self.engine
        args = SimpleNamespace(id="20260323-01", agent="test-agent", ttl=30)
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_claim(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        self.assertIn("[/] [20260323-01]", content)
        self.assertIn("Claimed:", content)
        self.assertIn("by test-agent", content)
        self.assertIn("ttl=30", content)

    def test_claim_already_claimed_by_same_agent_refreshes(self):
        """Re-claiming by same agent refreshes the timestamp."""
        eng = self.engine
        args = SimpleNamespace(id="20260323-01", agent="test-agent", ttl=30)
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_claim(args, str(self.todo_path), json_mode=False)
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_claim(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        # Should have exactly one Claimed: line
        self.assertEqual(content.count("Claimed:"), 1)

    def test_claim_already_claimed_by_different_agent_errors(self):
        """Claiming a task held by another agent (not expired) errors."""
        eng = self.engine
        args1 = SimpleNamespace(id="20260323-01", agent="agent-a", ttl=30)
        args2 = SimpleNamespace(id="20260323-01", agent="agent-b", ttl=30)
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_claim(args1, str(self.todo_path), json_mode=False)
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.cmd_claim(args2, str(self.todo_path), json_mode=False)

    def test_claim_nonexistent_task_errors(self):
        eng = self.engine
        args = SimpleNamespace(id="99990101-99", agent="test", ttl=30)
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.cmd_claim(args, str(self.todo_path), json_mode=False)

    def test_unclaim_reverts_to_open(self):
        """Unclaim changes [/] back to [ ] and removes Claimed: metadata."""
        eng = self.engine
        claim_args = SimpleNamespace(id="20260323-01", agent="test-agent", ttl=30)
        unclaim_args = SimpleNamespace(id="20260323-01")
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_claim(claim_args, str(self.todo_path), json_mode=False)
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_unclaim(unclaim_args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        self.assertIn("[ ] [20260323-01]", content)
        self.assertNotIn("Claimed:", content)

    def test_unclaim_nonexistent_task_errors(self):
        eng = self.engine
        args = SimpleNamespace(id="99990101-99")
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.cmd_unclaim(args, str(self.todo_path), json_mode=False)

    def test_reap_expired_claims(self):
        """Reap finds expired claims and reverts them to open."""
        eng = self.engine
        # Manually write a claimed task with an expired timestamp
        content = self.todo_path.read_text()
        content = content.replace(
            "- [ ] [20260323-01] Fix critical auth bug #engineering #urgent\n"
            "  - Added: 2026-03-23",
            "- [/] [20260323-01] Fix critical auth bug #engineering #urgent\n"
            "  - Added: 2026-03-23\n"
            "  - Claimed: 2025-01-01T00:00:00 by old-agent ttl=30"
        )
        self.todo_path.write_text(content)
        args = SimpleNamespace()
        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
            eng.cmd_reap(args, str(self.todo_path), json_mode=True)
            output = buf.getvalue()
        import json
        data = json.loads(output)
        self.assertGreaterEqual(data["reaped"], 1)
        content = self.todo_path.read_text()
        self.assertIn("[ ] [20260323-01]", content)
        self.assertNotIn("Claimed:", content)

    def test_reap_preserves_active_claims(self):
        """Reap does not touch claims that are still within TTL."""
        eng = self.engine
        # Claim a task (fresh timestamp)
        claim_args = SimpleNamespace(id="20260323-01", agent="active-agent", ttl=30)
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_claim(claim_args, str(self.todo_path), json_mode=False)
        reap_args = SimpleNamespace()
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_reap(reap_args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        # Task should still be claimed
        self.assertIn("[/] [20260323-01]", content)
        self.assertIn("Claimed:", content)

    def test_claim_completed_task_errors(self):
        """Cannot claim a task that is already completed [x]."""
        eng = self.engine
        # The history task is [x]
        args = SimpleNamespace(id="20260322-01", agent="test", ttl=30)
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eng.cmd_claim(args, str(self.todo_path), json_mode=False)

    def test_list_shows_claim_info(self):
        """List output includes claim state for claimed tasks."""
        eng = self.engine
        claim_args = SimpleNamespace(id="20260323-01", agent="test-agent", ttl=30)
        with contextlib.redirect_stdout(io.StringIO()):
            eng.cmd_claim(claim_args, str(self.todo_path), json_mode=False)
        list_args = SimpleNamespace(priority="P1", tag="", show_all=False)
        with io.StringIO() as buf, contextlib.redirect_stdout(buf):
            eng.cmd_list(list_args, str(self.todo_path), json_mode=True)
            output = buf.getvalue()
        import json
        data = json.loads(output)
        self.assertEqual(data["count"], 1)
        self.assertEqual(data["tasks"][0]["state"], "in-progress")


class FileProtectionTests(unittest.TestCase):
    """Tests for OS-level chmod write protection (0444 → save-file can't write)."""

    def setUp(self):
        self.engine = load_engine()
        self.tmp = tempfile.TemporaryDirectory()
        self.todo_path = Path(self.tmp.name) / "TODO.md"
        self.todo_path.write_text(SAMPLE_TODO)
        # Point TODO_FILE_PATH at our temp file so _validate_canonical_path passes
        self._orig_env = os.environ.get("TODO_FILE_PATH")
        os.environ["TODO_FILE_PATH"] = str(self.todo_path)
        # Isolate shadow dir
        self._shadow_tmp = tempfile.TemporaryDirectory()
        self._orig_shadow_dir = self.engine.SHADOW_DIR
        self.engine.SHADOW_DIR = self._shadow_tmp.name

    def tearDown(self):
        self.engine.SHADOW_DIR = self._orig_shadow_dir
        if self._orig_env is None:
            os.environ.pop("TODO_FILE_PATH", None)
        else:
            os.environ["TODO_FILE_PATH"] = self._orig_env
        # Clear immutable flag + chmod so tempdir cleanup succeeds
        if self.todo_path.exists():
            self.engine._clear_immutable(str(self.todo_path))
            os.chmod(str(self.todo_path), 0o644)
        self.tmp.cleanup()

    def test_write_file_sets_readonly_after_write(self):
        """After write_file(), the file should be 0444 (read-only)."""
        eng = self.engine
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        mode = os.stat(str(self.todo_path)).st_mode & 0o777
        self.assertEqual(mode, 0o444,
                         f"Expected 0444, got {oct(mode)}")

    def test_write_file_succeeds_on_already_protected_file(self):
        """write_file() should work even if the file is already 0444."""
        eng = self.engine
        os.chmod(str(self.todo_path), 0o444)
        # Should not raise — write_file does chmod 0644 first
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        result = self.todo_path.read_text()
        self.assertIn("# ACTIVE TASKS", result)
        mode = os.stat(str(self.todo_path)).st_mode & 0o777
        self.assertEqual(mode, 0o444)

    def test_protected_file_blocks_direct_open(self):
        """A 0444 file should raise PermissionError on direct open('w')."""
        eng = self.engine
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        # Now try to write directly — this is what save-file would do
        with self.assertRaises(PermissionError):
            with open(str(self.todo_path), "w") as f:
                f.write("garbage")

    def test_protect_file_is_idempotent(self):
        """Calling _protect_file multiple times doesn't fail."""
        eng = self.engine
        eng._protect_file(str(self.todo_path))
        eng._protect_file(str(self.todo_path))
        mode = os.stat(str(self.todo_path)).st_mode & 0o777
        self.assertEqual(mode, 0o444)

    def test_write_reprotects_after_write_exception(self):
        """If the actual file write raises, the file is re-protected."""
        eng = self.engine
        path_str = str(self.todo_path)
        os.chmod(path_str, 0o444)  # Start protected
        # Mock open to raise AFTER unprotect has run
        with unittest.mock.patch("builtins.open", side_effect=IOError("disk full")):
            with self.assertRaises(IOError):
                eng.write_file(path_str, SAMPLE_TODO)
        # File must be re-protected despite the exception
        mode = os.stat(path_str).st_mode & 0o777
        self.assertEqual(mode, 0o444,
                         f"Expected 0444 after write failure, got {oct(mode)}")

    def test_main_enforces_protection_on_existing_writable_file(self):
        """main() should re-protect a 0644 file on any invocation."""
        eng = self.engine
        path_str = str(self.todo_path)
        os.chmod(path_str, 0o644)  # Simulate unprotected file
        # Run a read-only command (list) through dispatch
        with unittest.mock.patch.dict(os.environ, {"TODO_FILE_PATH": path_str}):
            with unittest.mock.patch("sys.argv", ["todo-engine.py", "--json", "list"]):
                buf = io.StringIO()
                with contextlib.redirect_stdout(buf):
                    eng.main()
        mode = os.stat(path_str).st_mode & 0o777
        self.assertEqual(mode, 0o444,
                         f"Expected 0444 after main(), got {oct(mode)}")

    def test_shell_redirect_fails_on_protected_file(self):
        """Shell redirect (echo > file) fails on a 0444 file."""
        eng = self.engine
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        import subprocess
        result = subprocess.run(
            ["sh", "-c", f'echo "garbage" > "{self.todo_path}"'],
            capture_output=True
        )
        self.assertNotEqual(result.returncode, 0,
                            "Shell redirect should fail on 0444 file")


    def test_stray_path_write_refused(self):
        """write_file() refuses if target path != resolved TODO_FILE_PATH.

        Incident 2026-03-26: agent fell back to ~/.codex/TODO.md when the
        real path was unwritable (chmod 444). This gate prevents that.
        """
        eng = self.engine
        stray_tmp = tempfile.TemporaryDirectory()
        stray_path = Path(stray_tmp.name) / "STRAY_TODO.md"
        stray_path.write_text(SAMPLE_TODO)
        # TODO_FILE_PATH points at self.todo_path, not stray_path
        with self.assertRaises(SystemExit) as ctx:
            eng.write_file(str(stray_path), SAMPLE_TODO)
        stray_tmp.cleanup()

    def test_canonical_path_write_allowed(self):
        """write_file() succeeds when target matches TODO_FILE_PATH."""
        eng = self.engine
        # TODO_FILE_PATH already set to self.todo_path in setUp
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        self.assertEqual(self.todo_path.read_text(), SAMPLE_TODO)



class ShadowBackupTests(unittest.TestCase):
    """Tests for shadow backup and annihilation detection."""

    def setUp(self):
        self.engine = load_engine()
        self.tmp = tempfile.TemporaryDirectory()
        self.todo_path = Path(self.tmp.name) / "TODO.md"
        self.todo_path.write_text(SAMPLE_TODO)
        # Point TODO_FILE_PATH at our temp file so _validate_canonical_path passes
        self._orig_env = os.environ.get("TODO_FILE_PATH")
        os.environ["TODO_FILE_PATH"] = str(self.todo_path)
        # Use a temporary shadow dir to avoid polluting ~/.codex
        self.shadow_tmp = tempfile.TemporaryDirectory()
        self._orig_shadow_dir = self.engine.SHADOW_DIR
        self.engine.SHADOW_DIR = self.shadow_tmp.name

    def tearDown(self):
        self.engine.SHADOW_DIR = self._orig_shadow_dir
        if self._orig_env is None:
            os.environ.pop("TODO_FILE_PATH", None)
        else:
            os.environ["TODO_FILE_PATH"] = self._orig_env
        if self.todo_path.exists():
            self.engine._clear_immutable(str(self.todo_path))
            os.chmod(str(self.todo_path), 0o644)
        self.tmp.cleanup()
        self.shadow_tmp.cleanup()

    def _shadow_path(self):
        return os.path.join(self.engine.SHADOW_DIR, "TODO.md")

    def test_no_shadow_first_run_creates_shadow(self):
        """First write with no shadow should succeed and create shadow."""
        eng = self.engine
        self.assertFalse(os.path.exists(self._shadow_path()))
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        self.assertTrue(os.path.exists(self._shadow_path()))

    def test_shadow_updated_after_write(self):
        """Shadow content should match the last successful write."""
        eng = self.engine
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        shadow_content = Path(self._shadow_path()).read_text()
        file_content = self.todo_path.read_text()
        self.assertEqual(shadow_content, file_content)

    def test_annihilation_blocked_size_drop(self):
        """Block write when new content is <40% of shadow size."""
        eng = self.engine
        # Create a large shadow
        big_content = SAMPLE_TODO + "\n" + ("- [ ] [20260323-99] Filler\n" * 50)
        Path(self._shadow_path()).write_text(big_content)
        # Try to write much smaller content (SAMPLE_TODO is ~40% of big)
        with self.assertRaises(SystemExit):
            eng.write_file(str(self.todo_path), SAMPLE_TODO)

    def test_annihilation_blocked_task_count_zero(self):
        """Block write when active tasks drop to 0 from >0.

        Content is padded so file size stays above 40% threshold —
        this ensures the TASK COUNT check fires, not the size check.
        """
        eng = self.engine
        # Shadow has 3 active tasks (SAMPLE_TODO)
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        # New content: 0 active tasks, but padded with history so size >= 40%
        # SAMPLE_TODO is ~481 bytes; we need new content > 192 bytes (40%)
        history_padding = "\n".join(
            f"- [x] [20260323-{i:02d}] Completed task {i} with details\n"
            f"  - Done: 2026-03-25"
            for i in range(1, 8)
        )
        zero_active = (
            "# ACTIVE TASKS\n\n## P1 - Today\n\n## P2 - This Week\n\n"
            "## P3 - Backlog\n\n---\n\n# HISTORY\n\n## 2026-03-25\n"
            f"{history_padding}\n\n"
            "---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
        )
        self.assertGreater(len(zero_active), len(SAMPLE_TODO) * 0.4,
                           "Test fixture too small — size check would fire first")
        stderr_buf = io.StringIO()
        with contextlib.redirect_stderr(stderr_buf):
            with self.assertRaises(SystemExit):
                eng.write_file(str(self.todo_path), zero_active)
        stderr_output = stderr_buf.getvalue()
        self.assertIn("All 3 active tasks would be deleted", stderr_output,
                      f"Expected task-count-zero branch, got: {stderr_output}")

    def test_annihilation_blocked_large_task_drop(self):
        """Block write when >5 active tasks are lost in one write.

        Content is padded so file size stays above 40% threshold —
        this ensures the TASK DROP check fires, not the size check.
        """
        eng = self.engine
        # Create shadow with 8 active tasks
        tasks = ""
        for i in range(1, 9):
            tasks += f"- [ ] [20260323-{i:02d}] Task {i} with a longer description for padding #test\n"
        big_shadow = (
            f"# ACTIVE TASKS\n\n## P1 - Today\n\n{tasks}\n"
            "## P2 - This Week\n\n## P3 - Backlog\n\n---\n\n"
            "# HISTORY\n\n---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
        )
        eng.write_file(str(self.todo_path), big_shadow)
        shadow_size = len(big_shadow)
        # New content: only 1 active task (drop of 7 > threshold of 5)
        # Pad with history so size stays above 40%
        history_padding = "\n".join(
            f"- [x] [20260323-{i:02d}] Completed task {i} with details\n"
            f"  - Done: 2026-03-25"
            for i in range(2, 9)
        )
        one_task = (
            "# ACTIVE TASKS\n\n## P1 - Today\n\n"
            "- [ ] [20260323-01] Task 1 with a longer description for padding #test\n\n"
            "## P2 - This Week\n\n## P3 - Backlog\n\n---\n\n"
            f"# HISTORY\n\n{history_padding}\n\n"
            "---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
        )
        self.assertGreater(len(one_task), shadow_size * 0.4,
                           "Test fixture too small — size check would fire first")
        stderr_buf = io.StringIO()
        with contextlib.redirect_stderr(stderr_buf):
            with self.assertRaises(SystemExit):
                eng.write_file(str(self.todo_path), one_task)
        stderr_output = stderr_buf.getvalue()
        self.assertIn("Active task count would drop from 8 to 1", stderr_output,
                      f"Expected task-drop branch, got: {stderr_output}")

    def test_legitimate_single_completion_passes(self):
        """Completing 1 task (3→2 active) should pass annihilation check."""
        eng = self.engine
        eng.write_file(str(self.todo_path), SAMPLE_TODO)  # 3 active tasks
        # Remove one task from active, add to history
        two_active = (
            "# ACTIVE TASKS\n\n## P1 - Today\n\n"
            "- [ ] [20260323-01] Fix critical auth bug #engineering\n"
            "  - Added: 2026-03-23\n\n"
            "## P2 - This Week\n\n"
            "- [ ] [20260323-02] Review PR #engineering\n"
            "  - Added: 2026-03-23\n\n"
            "## P3 - Backlog\n\n---\n\n"
            "# HISTORY\n\n## 2026-03-25\n"
            "- [x] [20260323-03] Document onboarding #process\n"
            "  - Done: 2026-03-25\n\n---\n\n"
            "# DEFERRED\n\n---\n\n# METRICS\n"
        )
        # Should NOT raise — this is a normal completion
        eng.write_file(str(self.todo_path), two_active)
        self.assertIn("# ACTIVE TASKS", self.todo_path.read_text())

    def test_shadow_bypass_when_shadow_deleted(self):
        """If shadow is manually deleted, the next write succeeds (escape hatch)."""
        eng = self.engine
        # Create shadow with lots of tasks
        tasks = ""
        for i in range(1, 9):
            tasks += f"- [ ] [20260323-{i:02d}] Task {i} #test\n"
        big = (
            f"# ACTIVE TASKS\n\n## P1 - Today\n\n{tasks}\n"
            "## P2 - This Week\n\n## P3 - Backlog\n\n---\n\n"
            "# HISTORY\n\n---\n\n# DEFERRED\n\n---\n\n# METRICS\n"
        )
        eng.write_file(str(self.todo_path), big)
        # Delete shadow (the documented escape hatch)
        os.remove(self._shadow_path())
        # Now even a tiny write should succeed
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        self.assertTrue(os.path.exists(self._shadow_path()))


    def test_unreadable_shadow_warns_and_allows_write(self):
        """Unreadable shadow emits warning to stderr but write succeeds."""
        eng = self.engine
        # Create shadow then make it unreadable
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        shadow = self._shadow_path()
        os.chmod(shadow, 0o000)
        try:
            stderr_buf = io.StringIO()
            with contextlib.redirect_stderr(stderr_buf):
                eng.write_file(str(self.todo_path), SAMPLE_TODO)
            stderr_output = stderr_buf.getvalue()
            self.assertIn("WARNING", stderr_output)
            self.assertIn("shadow", stderr_output.lower())
            # Write still succeeded
            self.assertIn("# ACTIVE TASKS", self.todo_path.read_text())
        finally:
            os.chmod(shadow, 0o644)  # Restore for cleanup

    def test_shadow_dir_as_file_warns_on_update(self):
        """If shadow file is replaced with a directory, update_shadow warns."""
        eng = self.engine
        shadow = self._shadow_path()
        # Create a file where the shadow dir should be (corrupt state)
        os.makedirs(os.path.dirname(shadow), exist_ok=True)
        # First normal write to establish shadow
        eng.write_file(str(self.todo_path), SAMPLE_TODO)
        # Now corrupt: replace shadow file with a directory
        os.remove(shadow)
        os.mkdir(shadow)
        try:
            stderr_buf = io.StringIO()
            with contextlib.redirect_stderr(stderr_buf):
                # Should warn but not crash
                eng.write_file(str(self.todo_path), SAMPLE_TODO)
            stderr_output = stderr_buf.getvalue()
            self.assertIn("WARNING", stderr_output)
        finally:
            os.rmdir(shadow)  # Cleanup


if __name__ == "__main__":
    unittest.main()
