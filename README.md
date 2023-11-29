# saltman

make docker-build
make docker-up

make salt-master
salt-key -L -y
salt '*' test.ping     # wait 10 sec, should work after one or two min unilt salt automatically refreshes the keys