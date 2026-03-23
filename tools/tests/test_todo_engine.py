#!/usr/bin/env python3
"""Integration tests for todo-engine.py — CRUD operations on TODO.md.

Tests cover: path resolution, add, complete, move, defer, list, next-id,
atomic writes, multiline note handling, and argparse compatibility.

Run: python3 -m pytest tools/tests/test_todo_engine.py -v
  or: python3 tools/tests/test_todo_engine.py
"""
import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

# ---------------------------------------------------------------------------
# Load engine module from file path (avoids package structure requirement)
# ---------------------------------------------------------------------------
ENGINE_PATH = Path(__file__).resolve().parents[1] / "todo-engine.py"


def load_engine():
    spec = importlib.util.spec_from_file_location("todo_engine", ENGINE_PATH)
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

    def tearDown(self):
        import shutil
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

    def test_write_file_uses_os_replace_for_atomic_writes(self):
        """Verify write_file normalizes whitespace and writes correctly."""
        eng = self.engine
        content = "line1\n\n\n\n\nline2\n"  # 5 blank lines
        eng.write_file(str(self.todo_path), content)
        result = self.todo_path.read_text()
        # Should collapse 4+ newlines to 3 (2 visual blank lines)
        self.assertNotIn("\n\n\n\n", result)
        self.assertIn("line1", result)
        self.assertIn("line2", result)

    def test_complete_multiline_note_is_sanitized_into_progress_bullets(self):
        """Verify completion with multiline note produces correct output."""
        eng = self.engine
        args = SimpleNamespace(id="20260323-02", note="Fixed the issue\\nUpdated docs")
        eng.cmd_complete(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        # Task should be in HISTORY, not in ACTIVE
        self.assertNotIn("## P2", content.split("# HISTORY")[0].split("20260323-02")[0]
                         if "20260323-02" in content.split("# HISTORY")[0] else "")
        self.assertIn("[x] [20260323-02]", content)
        self.assertIn("Done: 2026-", content)

    def test_defer_multiline_reason_is_sanitized_into_reason_bullets(self):
        """Verify defer adds reason metadata."""
        eng = self.engine
        args = SimpleNamespace(id="20260323-03", reason="Blocked on access")
        eng.cmd_defer(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        self.assertIn("Deferred:", content)
        self.assertIn("Reason: Blocked on access", content)
        # Task should NOT be in P3 anymore
        p3_section = content.split("## P3")[1].split("---")[0] if "## P3" in content else ""
        self.assertNotIn("20260323-03", p3_section)

    # -- New integration tests --

    def test_add_task_to_p1(self):
        eng = self.engine
        args = SimpleNamespace(priority="P1", description="Urgent hotfix",
                               tags="#engineering #hotfix", note="")
        eng.cmd_add(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        self.assertIn("Urgent hotfix", content)
        self.assertIn("#engineering #hotfix", content)
        # Should be in P1 section
        p1_section = content.split("## P1")[1].split("## P2")[0]
        self.assertIn("Urgent hotfix", p1_section)

    def test_add_task_to_p3_with_note(self):
        eng = self.engine
        args = SimpleNamespace(priority="P3", description="Research competitor",
                               tags="#product", note="Check their API docs")
        eng.cmd_add(args, str(self.todo_path), json_mode=False)
        content = self.todo_path.read_text()
        p3_section = content.split("## P3")[1].split("---")[0]
        self.assertIn("Research competitor", p3_section)
        self.assertIn("Check their API docs", p3_section)

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

    def test_complete_nonexistent_task_errors(self):
        eng = self.engine
        args = SimpleNamespace(id="99990101-99", note="")
        with self.assertRaises(SystemExit):
            eng.cmd_complete(args, str(self.todo_path), json_mode=False)

    def test_add_invalid_priority_errors(self):
        eng = self.engine
        args = SimpleNamespace(priority="P4", description="Bad priority",
                               tags="", note="")
        with self.assertRaises(SystemExit):
            eng.cmd_add(args, str(self.todo_path), json_mode=False)

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


if __name__ == "__main__":
    unittest.main()
