# Unofficial guide of RPM building

```sh
unset CVSROOT
pushd contrib/distrib
sh release.sh $VERSION /tmp
sudo mv /tmp/$TARBALL /usr/src/redhat/SOURCES

cvs -d :ext:$NAME@cvs.savannah.nongnu.org:/cvsroot/zonecheck co -r $TAG zonecheck
cd zonecheck
PREFIX=/usr ruby installer.rb  configure
cd contrib/distrib/rpm
sudo rpmbuild -bb zonecheck.spec
```