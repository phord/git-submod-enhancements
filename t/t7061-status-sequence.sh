#!/bin/sh

test_description='sequencer state tokens'

. ./test-lib.sh

expect_tokens() {
	for TOKEN in "$@" ; do
		echo "## $TOKEN"
	done | sort
}

status_has_only() {
	expect_tokens "$@" >expect &&
	git status -S | sort >actual &&
	test_cmp expect actual
}

test_expect_success setup '
	test_commit A &&
	test_commit B oneside added &&
	git checkout A^0 &&
	test_commit C oneside created
'

test_expect_success 'status -S reports conflicted merge' '
	git checkout B^0 &&
	test_must_fail git merge C &&
	status_has_only commit-pending conflicted merge
'

test_expect_success 'git reset --hard cleans up merge status' '
	git reset --hard HEAD &&
	status_has_only
'

test_expect_success 'status -S reports conflicted rebase' '
	git reset --hard HEAD &&
	git checkout B^0 &&
	test_must_fail git rebase C &&
	status_has_only conflicted rebase
'

test_expect_success 'git rebase --abort cleans up rebase status' '
	git rebase --abort &&
	status_has_only
'

test_expect_success 'status -S reports incomplete cherry-pick' '
	git reset --hard HEAD &&
	git checkout A &&
	git cherry-pick --no-commit C &&
	status_has_only commit-pending
'

test_expect_success 'completing commit cleans up pending commit status' '
	git commit -mcompleted &&
	status_has_only
'

test_expect_success 'status -S reports failed cherry-pick' '
	git reset --hard HEAD &&
	git checkout B &&
	test_must_fail git cherry-pick C &&
	status_has_only cherry-pick commit-pending conflicted
'

test_expect_success 'resolved conflicts clear conflicted status' '
	git add oneside &&
	status_has_only cherry-pick commit-pending
'

test_expect_success 'aborted cherry-pick clears cherry-pick status' '
	git cherry-pick --abort &&
	status_has_only
'

test_expect_success 'conflicted rebase-interactive status' '
	git reset --hard HEAD &&
	git checkout B &&
	test_must_fail git rebase -i C &&
	status_has_only rebase-interactive conflicted commit-pending
'

test_expect_success 'bisect status' '
	git reset --hard HEAD &&
	git bisect start &&
	status_has_only bisect
'

test_expect_success 'bisect-reset clears bisect status' '
	git bisect reset &&
	status_has_only
'

test_done
