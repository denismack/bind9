#!/bin/sh
#
# Copyright (C) 2011  Internet Systems Consortium, Inc. ("ISC")
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND ISC DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS.  IN NO EVENT SHALL ISC BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
# OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

# $Id: tests.sh,v 1.9 2011/12/09 22:09:25 marka Exp $

SYSTEMTESTTOP=..
. $SYSTEMTESTTOP/conf.sh

DIGOPTS="+tcp +dnssec"
RANDFILE=random.data

status=0
n=0

n=`expr $n + 1`
echo "I:checking that the zone is signed on initial transfer ($n)"
ret=0
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list bits > signing.out.test$n 2>&1
	keys=`grep '^Done signing' signing.out.test$n | wc -l`
	[ $keys = 2 ] || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking removal of private type record via 'rndc signing -clear' ($n)"
ret=0
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list bits > signing.out.test$n 2>&1
keys=`sed -n -e 's/Done signing with key \(.*\)$/\1/p' signing.out.test$n`
for key in $keys; do
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -clear ${key} bits > /dev/null || ret=1
	break;	# We only want to remove 1 record for now.
done 2>&1 |sed 's/^/I:ns3 /'

for i in 1 2 3 4 5 6 7 8 9 10
do
	ans=0
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list bits > signing.out.test$n 2>&1
        num=`grep "Done signing with" signing.out.test$n | wc -l`
	[ $num = 1 ] && break
	sleep 1
done
[ $ans = 0 ] || ret=1

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking private type was properly signed ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.6 -p 5300 bits TYPE65534 > dig.out.ns6.test$n
grep "ANSWER: 2," dig.out.ns6.test$n > /dev/null || ret=1
grep "flags:.* ad[ ;]" dig.out.ns6.test$n > /dev/null || ret=1

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking removal of remaining private type record via 'rndc signing -clear all' ($n)"
ret=0
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -clear all bits > /dev/null || ret=1

for i in 1 2 3 4 5 6 7 8 9 10
do
	ans=0
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list bits > signing.out.test$n 2>&1
	grep "No signing records found" signing.out.test$n > /dev/null || ans=1
	[ $ans = 1 ] || break
	sleep 1
done
[ $ans = 0 ] || ret=1

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking negative private type response was properly signed ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.6 -p 5300 bits TYPE65534 > dig.out.ns6.test$n
grep "status: NOERROR" dig.out.ns6.test$n > /dev/null || ret=1
grep "ANSWER: 0," dig.out.ns6.test$n > /dev/null || ret=1
grep "flags:.* ad[ ;]" dig.out.ns6.test$n > /dev/null || ret=1

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

$NSUPDATE << EOF
zone bits
server 10.53.0.2 5300
update add added.bits 0 A 1.2.3.4
send
EOF

n=`expr $n + 1`
echo "I:checking that the record is added on the hidden master ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.2 -p 5300 added.bits A > dig.out.ns2.test$n
grep "status: NOERROR" dig.out.ns2.test$n > /dev/null || ret=1
grep "ANSWER: 1," dig.out.ns2.test$n > /dev/null || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking that update has been transfered and has been signed ($n)"
ret=0
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 added.bits A > dig.out.ns3.test$n
	grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

$NSUPDATE << EOF
zone bits
server 10.53.0.2 5300
update add bits 0 SOA ns2.bits. . 2011072400 20 20 1814400 3600
send
EOF

n=`expr $n + 1`
echo "I:checking YYYYMMDDVV (2011072400) serial on hidden master ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.2 -p 5300 bits SOA > dig.out.ns2.test$n
grep "status: NOERROR" dig.out.ns2.test$n > /dev/null || ret=1
grep "ANSWER: 1," dig.out.ns2.test$n > /dev/null || ret=1
grep "2011072400" dig.out.ns2.test$n > /dev/null || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking YYYYMMDDVV (2011072400) serial in signed zone ($n)"
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 bits SOA > dig.out.ns3.test$n
	grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
	grep "2011072400" dig.out.ns3.test$n > /dev/null || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`
n=`expr $n + 1`

echo "I:checking that the zone is signed on initial transfer, noixfr ($n)"
ret=0
for i in 1 2 3 4 5 6 7 8 9 10 1 2 3 4 5 6 7 8 9 10 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list noixfr > signing.out.test$n 2>&1
	keys=`grep '^Done signing' signing.out.test$n | wc -l`
	[ $keys = 2 ] || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

$NSUPDATE << EOF
zone noixfr
server 10.53.0.4 5300
update add added.noixfr 0 A 1.2.3.4
send
EOF

n=`expr $n + 1`
echo "I:checking that the record is added on the hidden master, noixfr ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.4 -p 5300 added.noixfr A > dig.out.ns4.test$n
grep "status: NOERROR" dig.out.ns4.test$n > /dev/null || ret=1
grep "ANSWER: 1," dig.out.ns4.test$n > /dev/null || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking that update has been transfered and has been signed, noixfr ($n)"
ret=0
for i in 1 2 3 4 5 6 7 8 9 10 1 2 3 4 5 6 7 8 9 10 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 added.noixfr A > dig.out.ns3.test$n
	grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

$NSUPDATE << EOF
zone noixfr
server 10.53.0.4 5300
update add noixfr 0 SOA ns4.noixfr. . 2011072400 20 20 1814400 3600
send
EOF

n=`expr $n + 1`
echo "I:checking YYYYMMDDVV (2011072400) serial on hidden master, noixfr ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.4 -p 5300 noixfr SOA > dig.out.ns4.test$n
grep "status: NOERROR" dig.out.ns4.test$n > /dev/null || ret=1
grep "ANSWER: 1," dig.out.ns4.test$n > /dev/null || ret=1
grep "2011072400" dig.out.ns4.test$n > /dev/null || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking YYYYMMDDVV (2011072400) serial in signed zone, noixfr ($n)"
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 noixfr SOA > dig.out.ns3.test$n
	grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
	grep "2011072400" dig.out.ns3.test$n > /dev/null || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking that the master zone signed on initial load ($n)"
ret=0
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list master  > signing.out.test$n 2>&1
	keys=`grep '^Done signing' signing.out.test$n | wc -l`
	[ $keys = 2 ] || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi

n=`expr $n + 1`
echo "I:checking removal of private type record via 'rndc signing -clear' (master) ($n)"
ret=0
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list master > signing.out.test$n 2>&1
keys=`sed -n -e 's/Done signing with key \(.*\)$/\1/p' signing.out.test$n`
for key in $keys; do
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -clear ${key} master > /dev/null || ret=1
	break;	# We only want to remove 1 record for now.
done 2>&1 |sed 's/^/I:ns3 /'

for i in 1 2 3 4 5 6 7 8 9
do
	ans=0
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list master > signing.out.test$n 2>&1
        num=`grep "Done signing with" signing.out.test$n | wc -l`
	[ $num = 1 ] && break
	sleep 1
done
[ $ans = 0 ] || ret=1

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking private type was properly signed (master) ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.6 -p 5300 master TYPE65534 > dig.out.ns6.test$n
grep "ANSWER: 2," dig.out.ns6.test$n > /dev/null || ret=1
grep "flags:.* ad[ ;]" dig.out.ns6.test$n > /dev/null || ret=1

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking removal of remaining private type record via 'rndc signing -clear' (master) ($n)"
ret=0
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -clear all master > /dev/null || ret=1
for i in 1 2 3 4 5 6 7 8 9 10
do
	ans=0
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list master > signing.out.test$n 2>&1
	grep "No signing records found" signing.out.test$n > /dev/null || ans=1
	[ $ans = 1 ] || break
	sleep 1
done
[ $ans = 0 ] || ret=1

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:check adding of record to unsigned master ($n)"
ret=0
sleep 1
cp ns3/master2.db.in ns3/master.db
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 reload master || ret=1

for i in 1 2 3 4 5 6 7 8 9
do
	ans=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 e.master A > dig.out.ns3.test$n
	grep "10.0.0.5" dig.out.ns3.test$n > /dev/null || ans=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ans=1
	[ $ans = 1 ] || break
	sleep 1
done
[ $ans = 0 ] || ret=1

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:check the added record was properly signed ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.3 -p 5300 e.master A > dig.out.ns6.test$n
grep "10.0.0.5" dig.out.ns6.test$n > /dev/null || ans=1
grep "ANSWER: 2," dig.out.ns6.test$n > /dev/null || ans=1
grep "flags:.* ad[ ;]" dig.out.ns6.test$n > /dev/null || ans=1

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking that the dynamic master zone signed on initial load ($n)"
ret=0
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 signing -list dynamic > signing.out.test$n 2>&1
	keys=`grep '^Done signing' signing.out.test$n | wc -l`
	[ $keys = 2 ] || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi

n=`expr $n + 1`
echo "I:checking adding of record to unsigned master using UPDATE ($n)"
ret=0

[ -f ns3/dynamic.db.jnl ] && { ret=1 ; echo "I:journal exists (pretest)" ; }

$NSUPDATE << EOF
zone dynamic
server 10.53.0.3 5300
update add e.dynamic 0 A 1.2.3.4
send
EOF

[ -f ns3/dynamic.db.jnl ] || { ret=1 ; echo "I:journal does not exist (posttest)" ; }

for i in 1 2 3 4 5 6 7 8 9 10
do 
	ans=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 e.dynamic > dig.out.ns3.test$n
	grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ans=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ans=1
	grep "1.2.3.4" dig.out.ns3.test$n > /dev/null || ans=1
	[ $ans = 0 ] && break
	sleep 1
done
[ $ans = 0 ] || { ret=1; echo "I:signed record not found"; cat dig.out.ns3.test$n ; }

if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:stop bump in the wire signer server ($n)"
ret=0
$PERL ../stop.pl . ns3 || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:restart bump in the wire signer server ($n)"
ret=0
$PERL ../start.pl --noclean --restart . ns3 || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

$NSUPDATE << EOF
zone bits
server 10.53.0.2 5300
update add bits 0 SOA ns2.bits. . 2011072450 20 20 1814400 3600
send
EOF

n=`expr $n + 1`
echo "I:checking YYYYMMDDVV (2011072450) serial on hidden master ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.2 -p 5300 bits SOA > dig.out.ns2.test$n
grep "status: NOERROR" dig.out.ns2.test$n > /dev/null || ret=1
grep "ANSWER: 1," dig.out.ns2.test$n > /dev/null || ret=1
grep "2011072450" dig.out.ns2.test$n > /dev/null || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking YYYYMMDDVV (2011072450) serial in signed zone ($n)"
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 bits SOA > dig.out.ns3.test$n
	grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
	grep "2011072450" dig.out.ns3.test$n > /dev/null || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

$NSUPDATE << EOF
zone noixfr
server 10.53.0.4 5300
update add noixfr 0 SOA ns4.noixfr. . 2011072450 20 20 1814400 3600
send
EOF

n=`expr $n + 1`
echo "I:checking YYYYMMDDVV (2011072450) serial on hidden master, noixfr ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.4 -p 5300 noixfr SOA > dig.out.ns4.test$n
grep "status: NOERROR" dig.out.ns4.test$n > /dev/null || ret=1
grep "ANSWER: 1," dig.out.ns4.test$n > /dev/null || ret=1
grep "2011072450" dig.out.ns4.test$n > /dev/null || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking YYYYMMDDVV (2011072450) serial in signed zone, noixfr ($n)"
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 noixfr SOA > dig.out.ns3.test$n
	grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
	grep "2011072450" dig.out.ns3.test$n > /dev/null || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

$NSUPDATE << EOF
zone bits
server 10.53.0.3 5300
update add bits 0 SOA ns2.bits. . 2011072460 20 20 1814400 3600
send
EOF

n=`expr $n + 1`
echo "I:checking forwarded update on hidden master ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.2 -p 5300 bits SOA > dig.out.ns2.test$n
grep "status: NOERROR" dig.out.ns2.test$n > /dev/null || ret=1
grep "ANSWER: 1," dig.out.ns2.test$n > /dev/null || ret=1
grep "2011072460" dig.out.ns2.test$n > /dev/null || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking forwarded update on signed zone ($n)"
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 bits SOA > dig.out.ns3.test$n
	grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
	grep "2011072460" dig.out.ns3.test$n > /dev/null || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

$NSUPDATE << EOF
zone noixfr
server 10.53.0.3 5300
update add noixfr 0 SOA ns4.noixfr. . 2011072460 20 20 1814400 3600
send
EOF

n=`expr $n + 1`
echo "I:checking forwarded update on hidden master, noixfr ($n)"
ret=0
$DIG $DIGOPTS @10.53.0.4 -p 5300 noixfr SOA > dig.out.ns4.test$n
grep "status: NOERROR" dig.out.ns4.test$n > /dev/null || ret=1
grep "ANSWER: 1," dig.out.ns4.test$n > /dev/null || ret=1
grep "2011072460" dig.out.ns4.test$n > /dev/null || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking forwarded update on signed zone, noixfr ($n)"
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$DIG $DIGOPTS @10.53.0.3 -p 5300 noixfr SOA > dig.out.ns3.test$n
	grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
	grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
	grep "2011072460" dig.out.ns3.test$n > /dev/null || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking turning on of inline signing in a slave zone via reload ($n)"
$DIG $DIGOPTS @10.53.0.5 -p 5300 +dnssec bits SOA > dig.out.ns5.test$n
grep "status: NOERROR" dig.out.ns5.test$n > /dev/null || ret=1
grep "ANSWER: 1," dig.out.ns5.test$n > /dev/null || ret=1
if [ $ret != 0 ]; then echo "I:setup broken"; fi
status=`expr $status + $ret`
cp ns5/named.conf.post ns5/named.conf
(cd ns5; $KEYGEN -q -r ../$RANDFILE bits) > /dev/null 2>&1
(cd ns5; $KEYGEN -q -r ../$RANDFILE -f KSK bits) > /dev/null 2>&1
$RNDC -c ../common/rndc.conf -s 10.53.0.5 -p 9953 reload 2>&1 | sed 's/^/I:ns5 /'
for i in 1 2 3 4 5 6 7 8 9 10
do
	ret=0
	$DIG $DIGOPTS @10.53.0.5 -p 5300 bits SOA > dig.out.ns5.test$n
	grep "status: NOERROR" dig.out.ns5.test$n > /dev/null || ret=1
	grep "ANSWER: 2," dig.out.ns5.test$n > /dev/null || ret=1
	if [ $ret = 0 ]; then break; fi
	sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:checking rndc freeze/thaw of dynamic inline zone ($n)"
ret=0
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 freeze dynamic > freeze.test$n 2>&1 || ret=1 
sleep 1
awk '$2 == ";" && $3 == "serial" { print $1 + 1, $2, $3; next; }
     { print; }
     END { print "freeze1.dynamic. 0 TXT freeze1"; } ' ns3/dynamic.db > ns3/dynamic.db.new
mv ns3/dynamic.db.new ns3/dynamic.db
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 thaw dynamic > thaw.test$n 2>&1 || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:check added record freeze1.dynamic ($n)"
for i in 1 2 3 4 5 6 7 8 9
do
    ret=0
    $DIG $DIGOPTS @10.53.0.3 -p 5300 freeze1.dynamic TXT > dig.out.ns3.test$n
    grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
    grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
    test $ret = 0 && break
    sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

# allow 1 second so that file time stamps change
sleep 1

n=`expr $n + 1`
echo "I:checking rndc freeze/thaw of server ($n)"
ret=0
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 freeze > freeze.test$n 2>&1 || ret=1
sleep 1
awk '$2 == ";" && $3 == "serial" { print $1 + 1, $2, $3; next; }
     { print; }
     END { print "freeze2.dynamic. 0 TXT freeze2"; } ' ns3/dynamic.db > ns3/dynamic.db.new
mv ns3/dynamic.db.new ns3/dynamic.db
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 thaw > thaw.test$n 2>&1 || ret=1
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

n=`expr $n + 1`
echo "I:check added record freeze2.dynamic ($n)"
for i in 1 2 3 4 5 6 7 8 9
do
    ret=0
    $DIG $DIGOPTS @10.53.0.3 -p 5300 freeze2.dynamic TXT > dig.out.ns3.test$n
    grep "status: NOERROR" dig.out.ns3.test$n > /dev/null || ret=1
    grep "ANSWER: 2," dig.out.ns3.test$n > /dev/null || ret=1
    test $ret = 0 && break
    sleep 1
done
if [ $ret != 0 ]; then echo "I:failed"; fi
status=`expr $status + $ret`

exit $status
