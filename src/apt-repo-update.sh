#!/bin/bash

# Execute with /path/to/apt-repo-update.sh /path/to/repo repo_name YOURGPGKEYID

REPODIR=${1}
REPONAME=${2}
GPG_NAME=${3}
VERSION=6.0

for bindir in `find ${REPODIR}/dists/${REPONAME} -type d -name "binary*"`; do
    arch=`echo ${bindir}|cut -d"-" -f 2`
    echo "Processing ${bindir} with arch ${arch}"

    overrides_file=/tmp/overrides
    package_file=${bindir}/Packages
    release_file=${bindir}/Release

    # Create simple overrides file to stop warnings
    cat /dev/null > ${overrides_file}
    for pkg in `ls ${REPODIR}/pool/main/ | grep -E "(all|${arch})\.deb"`; do
        pkg_name=`/usr/bin/dpkg-deb -f pool/main/${pkg} Package`
        echo "${pkg_name} Priority extra" >> ${overrides_file}
    done

    # Index of packages is written to Packages which is also zipped
    dpkg-scanpackages -a ${arch} ${REPODIR}/pool/main ${overrides_file} > ${package_file}
    # The line above is also commonly written as:
    # dpkg-scanpackages -a ${arch} pool/main /dev/null > $package_file
    gzip -9c ${package_file} > ${package_file}.gz
    bzip2 -c ${package_file} > ${package_file}.bz2

    # Cleanup
    rm ${overrides_file}
done

# Release info goes into Release & Release.gpg which includes an md5 & sha1 hash of Packages.*
# Generate & sign release file
cd ${REPODIR}/dists/${REPONAME}
cat > Release <<ENDRELEASE
Suite: ${REPONAME}
Version: ${VERSION}
Component: main
Origin: <input>
Label: <input>
Architecture: i386 amd64
Date: `date`
ENDRELEASE

# Generate hashes
echo "MD5Sum:" >> Release
for hashme in `find main -type f`; do
    md5=`openssl dgst -md5 ${hashme}|cut -d" " -f 2`
    size=`stat -c %s ${hashme}`
    echo " ${md5} ${size} ${hashme}" >> Release
done
echo "SHA1:" >> Release
for hashme in `find main -type f`; do
    sha1=`openssl dgst -sha1 ${hashme}|cut -d" " -f 2`
    size=`stat -c %s ${hashme}`
    echo " ${sha1} ${size} ${hashme}" >> Release
done

# Sign!
read -sp 'GPG Password: ' gpgpass
gpg --batch --passphrase ${gpgpass} --yes -u ${GPG_NAME} --sign -bao Release.gpg Release
echo "DONE"
cd -
