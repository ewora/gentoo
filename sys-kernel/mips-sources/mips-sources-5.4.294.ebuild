# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# EAPI Version
EAPI="8"

#//------------------------------------------------------------------------------

# Version Data
GENPATCHREV="10"			# Tarball revision for patches

# Directories
MIPS_PATCHES="${WORKDIR}/mips-patches"

# Kernel-2 Vars
K_SECURITY_UNSUPPORTED="yes"
K_NOUSENAME="yes"
K_NOSETEXTRAVERSION="yes"
K_NOUSEPR="yes"
K_BASE_VER="5.3"
K_FROM_GIT="yes"
ETYPE="sources"

# Inherit Eclasses
inherit kernel-2
detect_version

# Version Data
F_KV="${PVR}"
BASE_KV="$(ver_cut 1-2)"
[[ "${EXTRAVERSION}" = -rc* ]] && KVE="${EXTRAVERSION}"

# Portage Vars
DESCRIPTION="Kernel.org sources for MIPS-based machines"
HOMEPAGE="https://wiki.gentoo.org/wiki/Project:MIPS"
SRC_URI="${KERNEL_URI}
	https://dev.gentoo.org/~kumba/distfiles/${PN}-${BASE_KV}-patches-v${GENPATCHREV}.tar.xz"
S="${WORKDIR}/linux-${OKV}"
KEYWORDS="-* ~mips"
IUSE="experimental ip27 ip28 ip30 symlink"

# Specify any patches or patch familes to NOT apply here.
# Use only the 4-digit number followed by a '*'.
P_EXCLUDE=""

# Machine Support Control Variables
DO_IP22="test"				# If "yes", enable IP22 support		(SGI Indy, Indigo2 R4x00)
DO_IP27="yes"				# 		   IP27 support		(SGI Origin)
DO_IP28="no"				# 		   IP28 support		(SGI Indigo2 Impact R10000)
DO_IP30="yes"				# 		   IP30 support		(SGI Octane)
DO_IP32="yes"				# 		   IP32 support		(SGI O2, R5000/RM5200 Only)

# Machine Stable Version Variables
SV_IP22=""				# If set && DO_IP22 == "no", indicates last "good" IP22 version
SV_IP27=""				# 	    DO_IP27 == "no", 			   IP27
SV_IP28="4.19.x"			# 	    DO_IP28 == "no", 			   IP28
SV_IP30=""				# 	    DO_IP30 == "no", 			   IP30
SV_IP32=""				# 	    DO_IP32 == "no", 			   IP32

#//------------------------------------------------------------------------------

err_disabled_mach() {
	# Get args
	local m_name="${1}"
	local m_abbr="${2}"
	local m_use="${3}"
	local is_test="${4}"

	# Get stable version, if exists
	local stable_ver="SV_${m_abbr}"
	stable_ver="${!stable_ver}"

	# See if this machine needs a USE passed or skip dying
	local has_use
	[[ "${m_use}" != "skip" ]] \
		&& has_use="USE=\"${m_use}\" "

	# Print error && (maybe) die
	echo -e ""
	if [[ "${is_test}" != "test" ]]; then
		eerror "${m_name} Support has been disabled in this ebuild"
		eerror "revision.  If you wish to merge ${m_name} sources, then"
		eerror "run ${has_use}emerge =mips-sources-${stable_ver}"
		[[ "${m_use}" != "skip" ]] \
			&& die "${m_name} Support disabled."
	else
		ewarn "${m_name} Support has been marked as needing testing in this"
		ewarn "ebuild revision.  This usually means that any patches to support"
		ewarn "${m_name} have been forward ported and maybe even compile-tested,"
		ewarn "but not yet booted on real hardware, possibly due to a lack of access"
		ewarn "to such hardware.  If you happen to boot this kernel and have no"
		ewarn "problems at all, then please inform the maintainer.  Otherwise, if"
		ewarn "experience a bug, an oops/panic, or some other oddity, then please"
		ewarn "file a bug at bugs.gentoo.org, and assign it to the mips team."
	fi

	return 0
}

err_only_one_mach_allowed() {
	echo -e ""
	eerror "A patchset for a specific machine-type has already been selected."
	eerror "No other patches for machines-types are permitted.  You will need a"
	eerror "separate copy of the kernel sources for each different machine-type"
	eerror "you want to build a kernel for."
	die "Only one machine-type patchset allowed"
}

fkv_to_machtype() {
	# For any machines that use external patches, we rename the source
	# tree to match the machine type.
	local fkv="${F_KV%-*}"
	local v="${fkv}"
	for x in {ip27,ip28,ip30}; do
		use ${x} && v="${v}.${x}" && break
	done

	echo "${v}"
}

pkg_postinst() {
	if ! use symlink; then
		return 0
	fi

	local kern_sym="/usr/src/linux"

	# Check that /usr/src/linux is safe to overwrite
	if [[ -e "${kern_sym}" && ! -L "${kern_sym}" ]]; then
		die "${kern_sym} already exists, but is not a symbolic link"
	fi

	# Symlink /usr/src/linux as appropriate
	local kern_ver=$(fkv_to_machtype)
	ln -snf "linux-${kern_ver}" "${kern_sym}"
}

pkg_setup() {
	local arch_is_selected="no"
	local m_ip m_enable m_name

	# Exclusive machine patchsets
	# These are not allowed to be mixed together, thus only one of them may be applied
	# to a tree per merge.
	for x in									\
		"ip27 SGI Origin 200/2000"						\
		"ip28 SGI Indigo2 Impact R10000"					\
		"ip30 SGI Octane"
	do
		set -- ${x}		# Set positional params
		m_ip="${1}"		# Grab the first param (HW IP for SGI)
		shift			# Shift the positions
		m_name="${*}"		# Get the rest (Name)

		if ! use ${m_ip}; then
			continue
		fi

		# Fetch the value indiciating if the machine is enabled or not
		m_enable="DO_${m_ip/ip/IP}"
		m_enable="${!m_enable}"

		# Make sure only one of these exclusive machine patches is selected
		[[ "${arch_is_selected}" = "no" ]]				\
			&& arch_is_selected="yes"				\
			|| err_only_one_mach_allowed

		# Is the machine support disabled or marked as needing testing?
		case "${m_enable}" in
			"test") err_disabled_mach "${m_name}" "${m_ip/ip/IP}" "${m_ip}" "test" ;;
			"no") err_disabled_mach "${m_name}" "${m_ip/ip/IP}" "${m_ip}" ;;
		esac

		# Show relevant information about the machine
		show_${m_ip}_info
	done

	# All other systems that don't have a USE flag go here
	# These systems have base-line support included in linux-mips git, so
	# instead of failing, if disabled, we simply warn the user
	if [[ "${arch_is_selected}" = "no" ]]; then
		[[ "${DO_IP22}" = "no" ]]						\
			&& err_disabled_mach "SGI Indy/Indigo2 R4x00" "IP22" "skip"	\
			|| show_ip22_info
		[[ "${DO_IP32}" = "no" ]]						\
			&& err_disabled_mach "SGI O2" "IP32" "skip"			\
			|| show_ip32_info

	fi
}

show_ip22_info() {
	echo -e ""
	einfo "IP22 systems with an R5000 processor should work with this release."
	einfo "The R4x00 series of processors tend to be rather flaky, especially the"
	einfo "R4600.  If you have to run an R4x00 processor, then try to use an R4400."
	einfo ""
	einfo "Some Notes:"
	einfo "\t- The only supported graphics card right is Newport (XL)."
	einfo "\t- There is no driver for Extreme (XZ)."
	echo -e ""
}

show_ip27_info() {
	echo -e ""
	ewarn "IP27 Origin 2k/Onyx2 systems may be prone to sudden hard lockups."
	ewarn "The exact trigger is unknown at this time."
	echo -e ""
}

show_ip28_info() {
	echo -e ""
	einfo "Support for the Indigo2 Impact R10000 is now in the mainline kernel.  However,"
	einfo "due to the R10000 Speculative Execution issue that exists with this machine,"
	einfo "nothing is guaranteed to work correctly.  Consider enabling ${HILITE}CONFIG_KALLSYMS${NORMAL}"
	einfo "in your kernel so that if the machine Oopes, you'll be able to provide valuable"
	einfo "feedback that can be used to trace down the crash."
	echo -e ""
}

show_ip30_info() {
	echo -e ""
	eerror "Things that DON'T work:"
	eerror "\t- Do not use CONFIG_SLUB, otherwise, you'll get errors when booting"
	eerror "\t\040\040regarding duplicate /sys/kernel/slab/* entries in sysfs."
	eerror "\t- Impact (MGRAS) Xorg driver no longer functions due to severe bitrot."
	eerror "\t- Octane is limited to a maximum of 2GB of memory right now due to a"
	eerror "\t\040\040hardware quirk in the BRIDGE PCI chip that limits BRIDGE DMA"
	eerror "\t\040\040addresses to 31-bits when converted into physical addresses."
	echo -e ""
	ewarn "Things that might work, but have problems, or are unknown:"
	ewarn "\t- Serial support on the Octane uses a very basic UART driver that drives"
	ewarn "\t\040\040the 16550A chip on the IOC3 directly.  It does not use interrupts,"
	ewarn "\t\040\040only a polling routine on a timer, which makes it slow and CPU-"
	ewarn "\t\040\040intensive.  The baud rate is limited to no more than 38.4kbps on"
	ewarn "\t\040\040this driver.  Patches for getting the Altix IOC3 serial driver to"
	ewarn "\t\040\040work (which uses DMA and supports faster baud rates) are welcome."
	ewarn "\t- MENET boards appear to have the four ethernet ports detected, however"
	ewarn "\t\040\040the six serial ports don't appear to get picked up by the IOC3"
	ewarn "\t\040\040UART driver.  The NIC part number is also not read correctly"
	ewarn "\t\040\040from the four Number-In-a-Cans."
	ewarn "\t- Other XIO-based devices, like various Impact addons, remain untested"
	ewarn "\t\040\040and are not guaranteed to work."
	ewarn "\t- Upon rebooting, Octane may not return to the PROM.  Holding down the"
	ewarn "\t\040\040reset button for up to ten seconds, releasing, then pressing it"
	ewarn "\t\040\040again for one or two seconds may trigger the system to return"
	ewarn "\t\040\040to the PROM.  Please wait at least five seconds after each attempt"
	ewarn "\t\040\040to see if the machine responds.  As a last resort, unplugging the"
	ewarn "\t\040\040power cord for 30 seconds will also work, but be aware the power"
	ewarn "\t\040\040supplies on these systems will not appreciate this due to their"
	ewarn "\t\040\040relative old age."
	echo -e ""
	einfo "Things that DO work:"
	einfo "\t- SMP support."
	einfo "\t- Impact (MGRAS), console only."
	einfo "\t- VPro (Odyssey), console only."
	einfo "\t- PCI card cages (showbox) should work for many devices, except certain"
	einfo "\t\040\040types such as PCI-to-PCI bridges (USB hubs, USB flash card readers)."
	einfo "\t- SCSI, RTC, basic PCI, IOC3 Ethernet, keyboard, and mouse.  Please"
	einfo "\t\040\040report any problems with these devices."
	einfo "\t- SGI AceNIC/Tigon II gigabit cards will work in the PCI card cage/shoebox."
	echo -e ""
}

show_ip32_info() {
	echo -e ""
	einfo "IP32 systems function well, however there are some notes:"
	einfo "\t- A sound driver now exists for IP32."
	einfo "\t- Framebuffer console is limited to 4MB.  Anything greater"
	einfo "\t\040\040specified when building the kernel will oops or"
	einfo "\t\040\040panic the kernel."
	echo -e ""
	eerror "IP32 Systems may be unstable and prone to lockups under a 5.4.x LTS kernel."
	eerror "The cause is unknown at this time."
	echo -e ""

	einfo "To Build 64bit kernels for SGI O2 (IP32) or SGI Indy/Indigo2 R4x00 (IP22)"
	einfo "systems, you need to use the ${GOOD}vmlinux.32${NORMAL} make target."
	einfo "Once done, boot the ${GOOD}vmlinux.32${NORMAL} file (NOT vmlinux)."
}

src_unpack() {
	# Unpack the kernel sources, update to the latest rev (if needed),
	# and apply the latest patch from linux-mips git.
	kernel-2_src_unpack

	# Unpack the mips-sources patchset to ${WORKDIR}/mips-patches-${BASE_KV}.
	echo -e ""
	cd "${WORKDIR}"
	unpack "${PN}-${BASE_KV}-patches-v${GENPATCHREV}.tar.xz"

	# Create a new folder called 'patch-symlinks' and create symlinks to
	# all mips-patches in there.  If we want to exclude a patch, we'll
	# just delete the symlink instead of the actual patch.
	mkdir patch-symlinks
	cd patch-symlinks
	for x in ../mips-patches-${BASE_KV}/*.patch; do
		ln -s "${x}" "${x##../mips-patches-*/}"
	done

	# With symlinks created, setup the variables referencing external
	# machine patches and if a machine USE flag is enabled, then unset
	# its corresponding variable.
	# See 0000_README for the patch numbers and their meanings.
	local p_generic="51*"
	local p_ip27="52*" p_ip28="53*" p_ip30="54*"
	local p_xp="80*"
	use ip27 && unset p_generic p_ip27
	use ip28 && unset p_ip28
	use ip30 && unset p_generic p_ip30
	use experimental && unset p_xp

	# Remove symlinks for any patches that we don't want applied.  We
	# do this by looping through all the above variables, and deleting
	# matching symlinks that point to the corresponding patches.
	# The remaining symlinks will be applied to the kernel source.
	#
	# $P_EXCLUDE is a new var that can be set in an ebuild to exclude
	# specific patches by wildcarding the patch number.
	local patchlist="${p_generic} ${p_ip27} ${p_ip28} ${p_ip30} ${p_xp} ${P_EXCLUDE}"
	for x in $patchlist;
		do rm -f "./${x}"
	done

	# Rename the source tree, if needed.
	local old="${WORKDIR}/linux-${F_KV%-*/_/-}"
	local new="${WORKDIR}/linux-$(fkv_to_machtype)"
	if [[ "${old}" != "${new}" ]]; then
		mv "${old}" "${new}" || die
	fi
	S="${new}"

	# Set the EXTRAVERSION to linux-VERSION-mipsgit-GITDATE
	EXTRAVERSION="${EXTRAVERSION}-gentoo-mips"
	unpack_set_extraversion
}

src_prepare() {
	# Apply patches to the kernel tree.
	eapply "${WORKDIR}/patch-symlinks"/

	eapply_user
}
