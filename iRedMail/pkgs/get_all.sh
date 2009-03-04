#!/bin/sh

# Author:   Zhang Huangbin (michaelbibby <at> gmail.com)
# Date:     $LastChangedDate: 2008-03-02 21:11:40 +0800 (Sun, 02 Mar 2008) $
# Purpose:  Fetch all extra packages we need to build mail server.

ROOTDIR="$(pwd)"
CONF_DIR="${ROOTDIR}/../conf"

. ${CONF_DIR}/global
. ${CONF_DIR}/functions

FETCH_CMD="wget -c --referer ${PROG_NAME}-${PROG_VERSION}"

#
# Mirror site.
# Site directory structure:
#
#   ${MIRROR}/
#           |- rpms/
#               |- 5/
#               |- 6/ (not present yet)
#           |- misc/
#
# You can find nearest mirror in this page:
#   http://code.google.com/p/iredmail/wiki/Mirrors
#
MIRROR='http://www.iredmail.org/yum'

# Where to store packages and software source tarball.
PKG_DIR="${ROOTDIR}/rpms"
MISC_DIR="${ROOTDIR}/misc"

# RPM file list and misc file list.
RPMLIST="${ROOTDIR}/rpmlist.${ARCH}"
NOARCHLIST="${ROOTDIR}/rpmlist.noarch"
MISCLIST="${ROOTDIR}/misc.list"

MD5_FILES="MD5.${ARCH} MD5.noarch MD5.misc"

mirror_notify()
{
    cat <<EOF
*********************************************************************
**************************** Mirrors ********************************
*********************************************************************
* If you can't fetch packages, please try to use another mirror site
* listed in below url:
*
*   - http://code.google.com/p/iredmail/wiki/Mirrors
*
*********************************************************************
EOF

    echo 'export status_mirror_notify="DONE"' >> ${STATUS_FILE}
}

prepare_dirs()
{
    ECHO_INFO "Creating necessary directories..."
    for i in ${PKG_DIR} ${MISC_DIR}
    do
        [ -d "${i}" ] || mkdir -p "${i}"
    done
}

check_pkg_which()
{
    ECHO_INFO "Checking necessary package: which.${ARCH}..."
    for i in $(echo $PATH|sed 's/:/ /g'); do
        [ -x $i/which ] && export HAS_WHICH='YES'
    done

    [ X"${HAS_WHICH}" != X'YES' ] && install_pkg which.${ARCH}
    if [ X"$?" != X"0" ]; then
        ECHO_INFO "Please install package 'createrepo' first." && exit 255
    else
        echo 'export status_check_pkg_which="DONE"' >> ${STATUS_FILE}
    fi
}

check_pkg_createrepo()
{
    ECHO_INFO "Checking necessary package: createrepo.noarch..."
    which createrepo >/dev/null 2>&1

    [ X"$?" != X"0" ] && install_pkg createrepo.noarch
    if [ X"$?" != X"0" ]; then
        ECHO_INFO "Please install package 'createrepo' first." && exit 255
    else
        echo 'export status_check_createrepo="DONE"' >> ${STATUS_FILE}
    fi
}

fetch_rpms()
{
    if [ X"${DOWNLOAD_PKGS}" == X"YES" ]; then
        cd ${PKG_DIR}

        rpm_total=$(cat ${RPMLIST} ${NOARCHLIST} | wc -l | awk '{print $1}')
        rpm_count=1

        for i in $(cat ${RPMLIST} ${NOARCHLIST}); do
            ECHO_INFO "Fetching package: (${rpm_count}/${rpm_total}) $(eval echo ${i})..."
            ${FETCH_CMD} ${MIRROR}/rpms/5/${i}

            rpm_count=$((rpm_count+1))
        done
    else
        :
    fi
}

fetch_misc()
{
    if [ X"${DOWNLOAD_PKGS}" == X"YES" ]; then
        # Source relate config files.
        . ${CONF_DIR}/pypolicyd-spf
        . ${CONF_DIR}/squirrelmail
        . ${CONF_DIR}/phpldapadmin
        . ${CONF_DIR}/roundcube
        . ${CONF_DIR}/postfixadmin
        . ${CONF_DIR}/phpmyadmin
        . ${CONF_DIR}/extmail
        . ${CONF_DIR}/horde

        # Fetch all misc packages.
        cd ${MISC_DIR}

        misc_total=$(cat ${MISCLIST} | grep '^[a-z0-9A-Z\$]' | wc -l | awk '{print $1}')
        misc_count=1

        for i in $(cat ${MISCLIST} | grep '^[a-z0-9A-Z\$]' )
        do
            ECHO_INFO "Fetching (${misc_count}/${misc_total}): $(eval echo ${i})..."

            cd ${MISC_DIR}
            eval ${FETCH_CMD} ${MIRROR}/misc/${i}

            misc_count=$((misc_count + 1))
        done
    else
        :
    fi
}

check_md5()
{
    cd ${ROOTDIR}

    for i in ${MD5_FILES}; do
        ECHO_INFO -n "Checking MD5 via file: ${i}..."
        md5sum -c ${ROOTDIR}/${i} |grep 'FAILED'

        if [ X"$?" == X"0" ]; then
            echo -e "\n${OUTPUT_FLAG} MD5 check failed. Check your rpm packages. Script exit...\n"
            exit 255
        else
            echo -e "\t[ OK ]"
            echo 'export status_fetch_rpms="DONE"' >> ${STATUS_FILE}
            echo 'export status_fetch_misc="DONE"' >> ${STATUS_FILE}
            echo 'export status_check_md5="DONE"' >> ${STATUS_FILE}
        fi
    done
}

create_yum_repo()
{
    # createrepo
    ECHO_INFO -n "Generating yum repository..."
    cd ${PKG_DIR} && createrepo . >/dev/null 2>&1 && echo -e "\t[ OK ]"

    # Backup old repo file.
    [ -f ${LOCAL_REPO_FILE} ] && cp ${LOCAL_REPO_FILE} ${LOCAL_REPO_FILE}.${DATE}

    # Generate new repo file.
    cat > ${LOCAL_REPO_FILE} <<EOF
[${LOCAL_REPO_NAME}]
name=Yum repo generated by ${PROG_NAME}: http://${PROG_NAME}.googlecode.com/
baseurl=file://${PKG_DIR}/
enabled=1
gpgcheck=0
EOF

    echo 'export status_create_yum_repo="DONE"' >> ${STATUS_FILE}
}

echo_end_msg()
{
    cat <<EOF
********************************************************
* All tasks had been finished Successfully. Next step:
*
*   # cd ..
*   # sh ${PROG_NAME}.sh
*
********************************************************

EOF
}

if [ -e ${STATUS_FILE} ]; then
    . ${STATUS_FILE}
else
    echo '' > ${STATUS_FILE}
fi

check_user root && \
check_arch && \
check_status_before_run mirror_notify && \
check_status_before_run check_pkg_which && \
check_status_before_run check_pkg_createrepo && \
prepare_dirs && \
fetch_rpms && \
fetch_misc && \
check_md5 && \
create_yum_repo && \
check_dialog && \
echo_end_msg
