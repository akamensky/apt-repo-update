#!/bin/bash

# Execute with /path/to/apt-repo-update.sh /path/to/repo repo_name YOURGPGKEYID

REPODIR=${1}
REPONAME=${2}
GPG_NAME=${3}
VERSION=6.0

# Check for ${REPODIR} and exit if does not exist!
if [ ! -d ${REPODIR} ] ; then
    echo "${REPODIR} is not a directory or does not exist"
    exit 1
fi

cd ${REPODIR}

# Check for dists/${REPONAME} and create
if [ ! -d dists/${REPONAME} ] ; then
    echo "Creating dists/${REPONAME} ..."
    mkdir -p dists/${REPONAME}
fi

# Check for dists/${REPONAME}/main/binary-i386 and create
if [ ! -d dists/${REPONAME}/main/binary-i386 ] ; then
    echo "Creating dists/${REPONAME}/main/binary-i386 ..."
    mkdir -p dists/${REPONAME}/main/binary-i386
fi

# Check for dists/${REPONAME}/main/binary-amd64 and create
if [ ! -d dists/${REPONAME}/main/binary-amd64 ] ; then
    echo "Creating dists/${REPONAME}/main/binary-amd64 ..."
    mkdir -p dists/${REPONAME}/main/binary-amd64
fi

# Check for pool/${REPONAME}/main and create
if [ ! -d pool/${REPONAME}/main ] ; then
    echo "Creating pool/${REPONAME}/main ..."
    mkdir -p pool/${REPONAME}/main
fi

for bindir in `find dists/${REPONAME} -type d -name "binary*"`; do
    arch=`echo ${bindir}|cut -d"-" -f 2`
    echo "Processing arch ${arch}"

    overrides_file=/tmp/overrides
    package_file=${bindir}/Packages
    release_file=${bindir}/Release

    # Create simple overrides file to stop warnings
    cat /dev/null > ${overrides_file}
    for pkg in `ls pool/${REPONAME}/main/ | grep -E "(all|${arch})\.deb"`; do
        pkg_name=`/usr/bin/dpkg-deb -f pool/${REPONAME}/main/${pkg} Package`
        echo "${pkg_name} Priority extra" >> ${overrides_file}
    done

    # Index of packages is written to Packages which is also zipped
    dpkg-scanpackages -a ${arch} pool/${REPONAME}/main ${overrides_file} > ${package_file}
    # The line above is also commonly written as:
    # dpkg-scanpackages -a ${arch} pool/${REPONAME}/main /dev/null > $package_file
    gzip -9c ${package_file} > ${package_file}.gz
    bzip2 -c ${package_file} > ${package_file}.bz2

    # Cleanup
    rm ${overrides_file}
done

# Release info goes into Release & Release.gpg which includes an md5 & sha1 hash of Packages.*
# Generate & sign release file
# cd ${REPODIR}/dists/${REPONAME}
cat > dists/${REPONAME}/Release <<ENDRELEASE
Suite: ${REPONAME}
Version: ${VERSION}
Component: main
Origin: <input>
Label: <input>
Architecture: i386 amd64
Date: `date`
ENDRELEASE

# Generate hashes
echo "MD5Sum:" >> dists/${REPONAME}/Release
for hashme in `find dists/${REPONAME}/main -type f`; do
    md5=`openssl dgst -md5 ${hashme}|cut -d" " -f 2`
    size=`stat -c %s ${hashme}`
    fname=`echo "${hashme}" | cut -d"/" -f 3-`
    echo " ${md5} ${size} ${fname}" >> dists/${REPONAME}/Release
done
echo "SHA1:" >> dists/${REPONAME}/Release
for hashme in `find dists/${REPONAME}/main -type f`; do
    sha1=`openssl dgst -sha1 ${hashme}|cut -d" " -f 2`
    size=`stat -c %s ${hashme}`
    fname=`echo "${hashme}" | cut -d"/" -f 3-`
    echo " ${sha1} ${size} ${fname}" >> dists/${REPONAME}/Release
done
echo "SHA256:" >> dists/${REPONAME}/Release
for hashme in `find dists/${REPONAME}/main -type f`; do
    sha1=`openssl dgst -sha256 ${hashme}|cut -d" " -f 2`
    size=`stat -c %s ${hashme}`
    fname=`echo "${hashme}" | cut -d"/" -f 3-`
    echo " ${sha1} ${size} ${fname}" >> dists/${REPONAME}/Release
done

# Sign!
read -sp 'GPG Password: ' gpgpass
gpg --batch --passphrase ${gpgpass} --yes -u ${GPG_NAME} --sign --digest-algo SHA256 -bao dists/${REPONAME}/Release.gpg dists/${REPONAME}/Release
echo "DONE"
cd -
