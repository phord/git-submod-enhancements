#!/bin/sh
#

test_description='Native support for git commands across submodules

This test verifies that native directory-traversing git commands can
also traverse into submodules.
'

. ./test-lib.sh


test_expect_success 'setup a submodule tree' '
	echo file > file &&
	git add file &&
	test_tick &&
	git commit -m upstream &&
	git clone . super &&
	git clone super submodule &&
	(
		cd super &&
		git submodule add ../submodule sub1 &&
		git submodule add ../submodule sub2 &&
		git submodule add ../submodule sub3 &&
		git config -f .gitmodules --rename-section \
			submodule.sub1 submodule.foo1 &&
		git config -f .gitmodules --rename-section \
			submodule.sub2 submodule.foo2 &&
		git config -f .gitmodules --rename-section \
			submodule.sub3 submodule.foo3 &&
		git add .gitmodules &&
		test_tick &&
		git commit -m "submodules" &&
		git submodule init sub1 &&
		git submodule init sub2 &&
		git submodule init sub3
	) &&
	(
		cd submodule &&
		echo different > file &&
		git add file &&
		test_tick &&
		git commit -m "different"
	) &&
	(
		cd super &&
		(
			cd sub3 &&
			git pull
		) &&
		git add sub3 &&
		test_tick &&
		git commit -m "update sub3"
	)
'

sub1sha1=$(cd super/sub1 && git rev-parse HEAD)
sub2sha1=$(cd super/sub2 && git rev-parse HEAD)
sub3sha1=$(cd super/sub3 && git rev-parse HEAD)

cat > expect <<EOF
100644 blob f73f3093ff865c514c6c51f867e35f693487d0d3	file
160000 commit $sub1sha1	sub1
160000 commit $sub2sha1	sub2
160000 commit $sub3sha1	sub3
EOF

test_expect_success 'test ls-tree with submodules' '
	git clone super clone &&
	(
		cd clone &&
		git submodule update --init -- sub1 sub3 &&
		git ls-tree HEAD >../actual
	) &&
	grep -v gitmodules actual >cleaned &&
	test_i18ncmp expect cleaned
'

cat >expect <<EOF
100644 blob f73f3093ff865c514c6c51f867e35f693487d0d3	file
100644 blob f73f3093ff865c514c6c51f867e35f693487d0d3	sub1/file
100644 blob 8dca2f88bcfeb5fb3ecb832c4170ea85ef7be25c	sub3/file
EOF

test_expect_success 'ls-tree --submodule recurses into submodules' '
	(
		cd clone &&
		git submodule update --init -- sub1 sub3 &&
		git ls-tree --submodule HEAD >../actual
	) &&
	grep -v gitmodules actual >cleaned &&
	test_i18ncmp expect cleaned
'

test_expect_success 'setup nested submodules' '
	git clone submodule nested1 &&
	git clone submodule nested2 &&
	git clone submodule nested3 &&
	(
		cd nested3 &&
		git submodule add ../submodule submodule &&
		test_tick &&
		git commit -m "submodule" &&
		git submodule init submodule
	) &&
	(
		cd nested2 &&
		git submodule add ../nested3 nested3 &&
		test_tick &&
		git commit -m "nested3" &&
		git submodule init nested3
	) &&
	(
		cd nested1 &&
		git submodule add ../nested2 nested2 &&
		test_tick &&
		git commit -m "nested2" &&
		git submodule init nested2
	) &&
	(
		cd super &&
		mkdir subdir &&
		git submodule add ../nested1 subdir/nested1 &&
		test_tick &&
		git commit -m "nested1" &&
		git submodule init subdir/nested1
	)
'

test_expect_success 'setup partially updated nested submodules' '
	git clone super clone2 &&
	(
		cd clone2 &&
		git submodule update --init &&
		test_must_fail git rev-parse --resolve-git-dir subdir/nested1/nested2/.git &&
		git submodule foreach "git submodule update --init" &&
		git rev-parse --resolve-git-dir subdir/nested1/nested2/.git &&
		test_must_fail git rev-parse --resolve-git-dir subdir/nested1/nested2/nested3/.git
	)
'

cat >expect <<EOF
100644 blob f73f3093ff865c514c6c51f867e35f693487d0d3	file
100644 blob f73f3093ff865c514c6c51f867e35f693487d0d3	sub1/file
100644 blob f73f3093ff865c514c6c51f867e35f693487d0d3	sub2/file
100644 blob 8dca2f88bcfeb5fb3ecb832c4170ea85ef7be25c	sub3/file
100644 blob 8dca2f88bcfeb5fb3ecb832c4170ea85ef7be25c	subdir/nested1/file
100644 blob 8dca2f88bcfeb5fb3ecb832c4170ea85ef7be25c	subdir/nested1/nested2/file
EOF

test_expect_success 'ls-tree --submodule recurses multiple levels of submodules' '
	(
		cd clone2 &&
		git ls-tree --submodule HEAD >../actual
	) &&
	grep -v gitmodules actual >cleaned &&
	test_i18ncmp expect cleaned
'

cat >expect <<EOF
100644 blob 8dca2f88bcfeb5fb3ecb832c4170ea85ef7be25c	nested1/file
100644 blob 8dca2f88bcfeb5fb3ecb832c4170ea85ef7be25c	nested1/nested2/file
EOF

test_expect_success 'ls-tree --submodule deduces path to submodule' '
	(
		cd clone2 &&
		git ls-tree --submodule HEAD:subdir >../actual
	) &&
	grep -v gitmodules actual >cleaned &&
	test_i18ncmp expect cleaned
'

cat >expect <<EOF
100644 blob f73f3093ff865c514c6c51f867e35f693487d0d3	file
EOF

test_expect_success 'ls-tree --submodule treats submodules as trees' '
	(
		cd clone2 &&
		git ls-tree --submodule HEAD:sub1 >../actual
	) &&
	grep -v gitmodules actual >cleaned &&
	test_i18ncmp expect cleaned
'

test_done
