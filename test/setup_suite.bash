# bats-core auto-loads this file once, in its own top-level process, BEFORE
# forking any individual test's subprocess -- unlike a per-file setup(),
# `setup_suite()` runs exactly once for the whole `bats test/` (or
# `bats test/<file>.bats`) invocation.
#
# Root cause this closes: a real corruption incident where GIT_DIR (leaked
# into the shell that invoked bats, from an unrelated git experiment run
# earlier in the same shell) silently redirected a test fixture's own
# `git -C <tmpdir> init/commit` calls onto the real repo instead of its
# isolated tmpdir -- landing a fixture's "decoy" commit directly on top of
# a real commit and corrupting the shared .git/config (core.bare flipped
# true, user.email/user.name overwritten). The specific fixture involved
# (test/pre-push-git-dir-leak.bats's own DECOY setup) had no defensive
# unset of its own, and neither does any of the other ~19 files in this
# suite that do bare `git init`/`git -C` fixture work -- all of them shared
# the same implicit assumption that the calling environment is clean.
#
# Fix: unset here, once, centrally. Because this runs in bats' own parent
# process before it forks per-test subprocesses, an unset variable here is
# simply absent from every forked test's inherited environment -- no
# per-file changes needed, and no future test file can reintroduce this gap
# by omission.
setup_suite() {
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
}
