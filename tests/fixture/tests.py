"""Regression fixture for cross-review v2.

Standard library only. This machine has Python 3.15.1 and no pytest, which is
the exact premise the skill's test-command preflight exists for.

Three cases:

  A  cancellation guard blocks only one of four post-warehouse states
     -> a Correctness finding at orders.py:9, P1.
  B  the spec requires refunds rounded up; the code rounds to nearest
     -> the defect a Spec-axis reviewer must find, quoting the spec line.

     This test is *not* a panel test: it fails against orders.py whether or not
     a Spec axis exists, because it checks the code directly. Its job is to
     prove the defect is real, detectable, and closable -- not to prove the
     panel reports it. See README.md for what that distinction costs.
  C  a review leaves git log and the working tree unchanged, and its
     round-1 diff includes both a modified tracked file and a new untracked
     file. The snapshot is performed by the shipped
     skills/cross-review/scripts/snapshot-baseline.sh, so the fixture tests
     the artifact a reviewer runs, not a re-implementation of it.

Run: sh run-tests.sh    (or: python tests.py; Case C needs sh on PATH)
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# CR_FIXTURE_MODULE=fixed runs the same tests against the corrected module, to
# prove the tests are sound rather than merely red.
if os.environ.get("CR_FIXTURE_MODULE") == "fixed":
    import orders_fixed as orders  # noqa: E402
else:
    import orders  # noqa: E402


class CaseA_CancellationGuard(unittest.TestCase):
    """The guard must cover every post-warehouse state, not just `shipped`."""

    def test_shipped_is_refused(self):
        with self.assertRaises(ValueError):
            orders.cancel_order({"status": "shipped", "total": 100})

    def test_every_post_warehouse_state_is_refused(self):
        for state in orders.POST_WAREHOUSE_STATES:
            with self.subTest(state=state):
                with self.assertRaises(
                    ValueError,
                    msg=f"cancel_order accepted a {state!r} order",
                ):
                    orders.cancel_order({"status": state, "total": 100})

    def test_pre_warehouse_state_is_cancellable(self):
        for state in ("pending", "paid"):
            with self.subTest(state=state):
                order = orders.cancel_order({"status": state, "total": 100})
                self.assertEqual(order["status"], "cancelled")


class CaseB_RefundRoundsUp(unittest.TestCase):
    """The spec requires rounding UP; the code rounds to nearest."""

    def test_half_cent_rounds_up_not_down(self):
        # 100.4 cents must become 101, never 100.
        self.assertEqual(orders.refund_amount({"total": 100.4}), 101)

    def test_rounding_is_never_downwards(self):
        for cents in (100.1, 100.4, 100.5, 100.9, 101.1):
            with self.subTest(cents=cents):
                self.assertGreaterEqual(
                    orders.refund_amount({"total": cents}),
                    int(-(-cents // 1)),
                    f"{cents} cents was refunded low",
                )


class CaseC_ProcessGuarantees(unittest.TestCase):
    """A review must leave no commit and no working-tree residue."""

    def setUp(self):
        self.repo = tempfile.mkdtemp(prefix="cr-fixture-")
        self.addCleanup(shutil.rmtree, self.repo, True)

    def git(self, *args, **kw):
        return subprocess.run(
            ("git",) + args,
            cwd=self.repo,
            capture_output=True,
            text=True,
            check=kw.get("check", True),
        )

    def init_repo(self):
        self.git("init", "-q", ".")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "user.name", "fixture")
        with open(os.path.join(self.repo, "orders.py"), "w", encoding="utf-8") as fh:
            fh.write('def cancel_order(order):\n    return order["status"] == "shipped"\n')
        self.git("add", "-A")
        self.git("commit", "-qm", "init")

    SCRIPT = os.path.join(
        HERE, os.pardir, os.pardir, "skills", "cross-review", "scripts",
        "snapshot-baseline.sh",
    )

    def snapshot(self):
        """The mechanism the skill ships, exercised for real.

        Invokes scripts/snapshot-baseline.sh through sh: the fixture tests
        the artifact a reviewer runs, not a re-implementation of it.
        """
        out = subprocess.run(
            ("sh", self.SCRIPT), cwd=self.repo,
            capture_output=True, text=True, check=True,
        )
        values = {}
        for line in out.stdout.splitlines():
            key, eq, value = line.partition("=")
            if eq:
                values[key.strip()] = value.strip()
        return values["SNAP"]

    def dirty_tree(self):
        with open(os.path.join(self.repo, "orders.py"), "w", encoding="utf-8") as fh:
            fh.write('def cancel_order(order):\n    return order["status"] in ("shipped",)\n')
        with open(os.path.join(self.repo, "new_module.py"), "w", encoding="utf-8") as fh:
            fh.write("VALUE = 1\n")

    def test_review_leaves_no_commit(self):
        self.init_repo()
        self.dirty_tree()
        before = self.git("log", "--pretty=%H").stdout
        self.snapshot()
        after = self.git("log", "--pretty=%H").stdout
        self.assertEqual(before, after, "the baseline snapshot created a commit")

    def test_review_leaves_status_unchanged(self):
        self.init_repo()
        self.dirty_tree()
        before = self.git("status", "--porcelain").stdout
        self.snapshot()
        after = self.git("status", "--porcelain").stdout
        self.assertEqual(before, after)

    def test_round_one_diff_sees_tracked_and_untracked(self):
        self.init_repo()
        self.dirty_tree()
        base = self.git("rev-parse", "HEAD").stdout.strip()
        snap = self.snapshot()
        diff = self.git("diff", "--name-only", base, snap).stdout.split()
        self.assertIn("orders.py", diff)
        self.assertIn(
            "new_module.py", diff,
            "the snapshot dropped an untracked file -- the exact defect that "
            "git stash create -u has",
        )

    def test_delta_between_two_snapshots(self):
        self.init_repo()
        self.dirty_tree()
        first = self.snapshot()
        with open(os.path.join(self.repo, "orders.py"), "a", encoding="utf-8") as fh:
            fh.write("\ndef refund_amount(order):\n    return order['total']\n")
        second = self.snapshot()
        diff = self.git("diff", "--name-only", first, second).stdout.split()
        self.assertEqual(diff, ["orders.py"])

    def test_documented_call_site_aborts_on_failure(self):
        """SKILL.md's recipe must not swallow a failed snapshot.

        `eval "$(cmd)"` discards cmd's exit status — measured: a failing
        snapshot continued with empty BASE/SNAP. The shipped recipe captures
        first and exits, so assert the abort, not just the script's status.
        """
        not_a_repo = tempfile.mkdtemp(prefix="cr-norepo-")
        self.addCleanup(shutil.rmtree, not_a_repo, True)
        recipe = (
            'snap_out=$(sh "$1") || { echo SNAPSHOT-FAILED >&2; exit 7; }; '
            'eval "$snap_out"'
        )
        out = subprocess.run(
            ("sh", "-c", recipe, "sh", self.SCRIPT),
            cwd=not_a_repo, capture_output=True, text=True,
        )
        self.assertEqual(out.returncode, 7, out.stderr)
        self.assertIn("SNAPSHOT-FAILED", out.stderr)

    def test_skill_md_recipe_stays_capture_first(self):
        """Tie the recipe test to the document, not only to a copied string.

        Reverting SKILL.md to `eval "$(sh ...)"` would re-introduce the
        swallowed failure while the test above stayed green; this assertion
        turns that regression red.
        """
        skill_md = os.path.join(
            HERE, os.pardir, os.pardir, "skills", "cross-review", "SKILL.md",
        )
        with open(skill_md, encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("snap_out=$(sh", text)
        self.assertNotIn('eval "$(sh', text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
