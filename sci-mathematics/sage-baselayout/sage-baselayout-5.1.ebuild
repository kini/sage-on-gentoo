# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="4"

inherit eutils prefix toolchain-funcs versionator

SAGE_P="sage-$(replace_version_separator 2 '.')"
MY_P="sage_scripts-$(replace_version_separator 2 '.')"
SAGEROOT="sage_root-$(replace_version_separator 2 '.')"

DESCRIPTION="Sage baselayout files"
HOMEPAGE="http://www.sagemath.org"
SRC_URI="http://sage.math.washington.edu/home/release/${SAGE_P}/${SAGE_P}/spkg/standard/${MY_P}.spkg -> ${P}.tar.bz2
	http://sage.math.washington.edu/home/release/${SAGE_P}/${SAGE_P}/spkg/standard/${SAGEROOT}.spkg -> ${SAGEROOT}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86 ~amd64-linux ~x86-linux"
IUSE="debug testsuite X tools"

RESTRICT="mirror"

DEPEND=""
if  [[ ${CHOST} == *-darwin* ]] ; then
	RDEPEND="${DEPEND}
		tools? ( dev-vcs/mercurial )
		debug? ( sys-devel/gdb-apple )"
else
	RDEPEND="${DEPEND}
		tools? ( dev-vcs/mercurial )
		debug? ( sys-devel/gdb )"
fi

S="${WORKDIR}/${MY_P}"
ROOT_S="${WORKDIR}/${SAGEROOT}"

# TODO: scripts into /usr/libexec ?
src_prepare() {
	# ship our own version of sage-env
	cat > sage-env <<-EOF
		#!/bin/bash

		export SAGE_ROOT="${EPREFIX}/usr/share/sage"
		export SAGE_LOCAL="${EPREFIX}/usr/"
		export SAGE_DATA="${EPREFIX}/usr/share/sage/data"
		export SAGE_DOC="${EPREFIX}/usr/share/sage/devel/sage/doc"

		if [[ -z \${DOT_SAGE} ]]; then
			export DOT_SAGE="\${HOME}/.sage"
		fi

		export SAGE_STARTUP_FILE="\${DOT_SAGE}/init.sage"
		export SAGE_TESTDIR="\${DOT_SAGE}/tmp"
		export SAGE_SERVER="http://www.sagemath.org/"
		export EPYTHON=python2.7
	EOF

	# make .desktop file
	cat > "${T}"/sage-sage.desktop <<-EOF
		[Desktop Entry]
		Name=Sage Shell
		Type=Application
		Comment=Math software for algebra, geometry, number theory, cryptography and numerical computation
		Exec=sage
		TryExec=sage
		Icon=sage
		Categories=Education;Science;Math;
		Terminal=true
	EOF

	# TODO: do not remove scons and M2

	# replace ${SAGE_ROOT}/local with ${SAGE_LOCAL}
	epatch "${FILESDIR}"/${PN}-4.7.2-fix-SAGE_LOCAL.patch

	# solve sage-notebook start-up problems (after patching them)
	mv sage-notebook sage-notebook-real
	mv sage-notebook-insecure sage-notebook-insecure-real

	cat > sage-notebook <<-EOF
		#!/bin/bash

		source ${EPREFIX}/etc/sage-env
		${EPREFIX}/usr/bin/sage-notebook-real "\$@"
	EOF

	cat > sage-notebook-insecure <<-EOF
		#!/bin/bash

		source ${EPREFIX}/etc/sage-env
		${EPREFIX}/usr/bin/sage-notebook-insecure-real "\$@"
	EOF

	# sage startup script is placed into /usr/bin
	sed -i "s:\"\$SAGE_ROOT\"/sage:\"\$SAGE_LOCAL\"/bin/sage:g" \
		sage-maketest || die "failed to patch path for Sage's startup script"

	sed -i "s:sage_fortran:$(tc-getFC):g" sage-g77_shared \
		|| die "failed to patch fortran compiler path"

	# TODO: if USE=debug/testsuite, remove corresponding options

	# replace $SAGE_ROOT/local with $SAGE_LOCAL
	sed -i "s:\$SAGE_ROOT/local:\$SAGE_LOCAL:g" sage-gdb sage-gdb-ipython \
		sage-cachegrind sage-callgrind sage-massif sage-omega sage-valgrind \
		|| die "failed to patch GNU Debugger scripts"

	# replace MAKE by MAKEOPTS in sage-num-threads.py
	sed -i "s:os.environ\[\"MAKE\"\]:os.environ\[\"MAKEOPTS\"\]:g" \
		sage-num-threads.py

	# remove developer- and unsupported options
	cd "${ROOT_S}"
	epatch "${FILESDIR}"/${PN}-5.1-gentooify-startup-script.patch.bz2
	eprefixify spkg/bin/sage
}

src_install() {
	# TODO: patch sage-core and remove sage-native-execute ?

	# core scripts which are needed in every case
	dobin sage-cleaner sage-banner sage-eval sage-ipython \
		sage-maxima.lisp sage-native-execute sage-run sage-num-threads.py \
		sage-rst2txt sage-rst2sws

	dobin "${ROOT_S}"/spkg/bin/sage

	# install sage-env under /etc
	insinto /etc
	doins sage-env

	if use testsuite ; then
		# DOCTESTING helper scripts
		dobin sage-doctest sage-maketest sage-ptest sage-test
	fi

	if use tools ; then
		# install some of sage tools for spkg development
		dobin sage-pkg
	fi

	# COMMAND helper scripts
	dobin sage-cython sage-notebook* sage-python

	# additonal helper scripts
	dobin sage-preparse sage-startuptime.py

	if use debug ; then
		# GNU DEBUGGER helper schripts
		dobin sage-gdb sage-gdb-ipython sage-gdb-commands

		# VALGRIND helper scripts
		dobin sage-cachegrind sage-callgrind sage-massif sage-omega \
			sage-valgrind
	fi

	# install file for sage/misc/inline_fortran.py
	dobin sage-g77_shared

	insinto /usr/bin
	doins *doctest.py ipy_profile_sage.py

	insinto /usr/share/sage
	doins -r "${ROOT_S}"/ipython
	doins "${ROOT_S}"/COPYING.txt

	insinto /etc
	doins "${FILESDIR}"/gprc.expect

	# install devel directories and link
	dodir /usr/share/sage/devel/sage-main
	dosym /usr/share/sage/devel/sage-main /usr/share/sage/devel/sage

	if use X ; then
		# unpack icon
		cp "${FILESDIR}"/sage.svg.bz2 "${T}" || die "failed to copy icon"
		bzip2 -d "${T}"/sage.svg.bz2 || die "failed to unzip icon"

		doicon "${T}"/sage.svg
		domenu "${T}"/sage-sage.desktop
	fi
}

pkg_postinst() {
	einfo "If you upgraded from a previous ${PN} a file into /etc/env.d has been removed."
	einfo "In this case you need to update your environment with:"
	einfo ""
	einfo "  env-update && source /etc/profile"
	einfo ""
	einfo "or logoff and logon to your shell, otherwise Sage may fail to start"
}
