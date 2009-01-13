#############################################################################
#
# We store the list of 3432 primes less than 32000, extending the 
# list of 168 primes less than 1000, that is defined in GAP
#
MakeReadWriteGlobal( "Primes" );
Primes := Filtered( [ 1 .. 32000 ], IsPrimeInt );;
MakeReadOnlyGlobal( "Primes" );


LiouvilleFunction:=function( n )
#
# For an integer n, the Liouville's function of n is equal to (-1)^r(n), 
# where r(n) is the number of prime factors of n, counted according to 
# their multiplicity, with r(1)=0.
#
if n=1 then
  return 1;
elif Length( FactorsInt(n) ) mod 2 = 0  then
  return 1;
else
  return -1;
fi;
end;


#############################################################################
#
# The summatory Liouville's function L(x) is the sum
# of values of LiouvilleFunction(n) for all n from [ 1 .. x ].
#
# G. P�lya in 1919 conjectured that L(x)<=0 for all x >=2.
#
# C.B.Haselgrove in 1958 proved that this conjecture is false
# and there are infinitely many integers x with L(x)>0, but
# he neither presented such x nor give the upper bound for 
# the minimal x with L(x)>0. 
#
# A computer-aided search reported in [ R. Sherman Lehman, 
# On Liouville's Funcion, Mathematics of Computation, Vol.14, 
# No.72 (Oct., 1960), pp.311-320 ] found the counterexample to 
# be L(906180359)=+1, without claiming its minimality.
#
# The smallest counterexample is n = 906150257, reported in
# [ M. Tanaka, A Numerical Investigation on Cumulative Sum of the 
# Liouville Function. Tokyo Journal of Mathematics 3, (1980) 187-189 ]
# The P�lya conjecture fails to hold for most values of n in the region 
# of 906150257 <= n <= 906488079. In this region, the function reaches 
# a maximum value of 829 at n = 906316571.
#
SummatoryLiouvilleFunction := function( x )
local s,n;
s := 0;
n := 1;
repeat
  s := s + LiouvilleFunction(n);
  n := n+1;
until n>x;
return s;
end;


PartialSummatoryLiouvilleFunction := function( interval )
#
# To parallelize computation of the summatory Liouville's
# function, we introduce its partial analogue to split the
# whole sum on partial sums that may be computed independently.
#
# The argument 'interval' is a list [x1,x2] of length two.
# The function returns the sum of LiouvilleFunction(n) for 
# all n from [ x1 .. x2 ].
#
local x1,x2,s,n;
x1:=interval[1];
x2:=interval[2];
s := 0;
n := x1;
repeat
  s := s + LiouvilleFunction(n);
  n := n+1;
until n>x2;
return s;
end;


ParSummatoryLiouvilleFunction := function( x, chunksize )
#
# To parallelize the computation of L(x), we split the range [ 1 .. x ]
# on intervals of the length 'chunksize', and then compute the sum
# of values of the Liouville's function for each interval in parallel.
#
# We may experiment with various values of 'chunksize'. Very small 
# chunksize will cause an overhead because of longer list of intervals
# (cost of time for its generation and storing in memory) and also
# more intensive master-slave communication. Since the computation of
# one value of Liouville's function for one number is rather fast, its
# speed will be comparable with the speed of data exchange between
# master and slave, and on extremely small chunksize values instead
# of speedup there will be slowdown.
#
local intervals, r1, r2, t1, t2, result;
t1:=UNIX_Realtime();
intervals := [];
r1:=1;
r2:=Minimum( chunksize, x );
while r2 < x do
  Add( intervals, [ r1, r2 ] );
  r1:=r1+chunksize;
  r2:=r2+chunksize;
od;
Add( intervals, [ r1, x ] );
result := Sum( ParList( intervals, PartialSummatoryLiouvilleFunction ) );
t2:=UNIX_Realtime();
return rec( value:=result, realtime := t2-t1 );
end;


ParInstallTOPCGlobalFunction( "ParSummatoryLiouvilleFunctionTOPC",
#
# This is the version of the previous function which uses another
# functionality provided by the ParGAP package which enable to see
# the data exchange between the master and slaves and the progress 
# of computation.
#
# The meaning of arguments is the same as in the previous function.
# Longer chunksizes (exact values depend on machine's configuration)
# may cause ParGAP crashes with wrong reports about a dead slave
# because of variations of complexity of computation for different
# intervals. To avoid this, we set the variable slaveTaskTimeFactors
# defined in ParGAP, to 1000; this means that we allow the new task to 
# require up to 1000 times longer than the longest task so far; you may 
# adjust this parameter if this will be not enough. (before caching
# primes up to 32000, we had an example when 100 was not enough with 
# chunksize 10000 while computing the partial sum somewhere in the 15th 
# million);
#
function( x, chunksize )
local intervals, r1, r2, result, t1, t2;
t1:=UNIX_Realtime();
intervals := [];
r1:=1;
r2:=Minimum( chunksize, x );
while r2 < x do
  Add( intervals, [ r1, r2 ] );
  r1:=r1+chunksize;
  r2:=r2+chunksize;
od;
Add( intervals, [ r1, x ] );
result := [];
slaveTaskTimeFactor:=1000;
MasterSlave( TaskInputIterator( intervals ), PartialSummatoryLiouvilleFunction,
                
		function( input, output )
		  Add( result, output );
                  return NO_ACTION; 
		end,
                
		Error );

result := Sum( result );
t2:=UNIX_Realtime();
return rec( value:=result, realtime := t2-t1 );
end );