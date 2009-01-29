#############################################################################
#
# This is the SCSCP server configuration file.
# The service provider can start the server just by the command 
# $ gap myserver.g
#
# $Id$
#
#############################################################################

#############################################################################
#
# List of necessary packages and other commands if needed
#
#############################################################################

LogTo(); # to close log file if it was opened from .gaprc
LoadPackage("scscp");
LoadPackage("anupq");
ReadPackage("scscp/example/karatsuba.g");
LoadPackage("automata");
ReadPackage("scscp/par/automata.g");

#############################################################################
#
# Procedures and functions available for the SCSCP server
# (you will be able also to install procedures contained in other files,
# including standard GAP procedures and functions)
#
#############################################################################

FactorialAsString := x -> String(Factorial( x ) );
# Returns Factorial(x) as a string to deal also with cases when
# the result is too large to be printed

IdGroupByGenerators:=function( permlist )
# Returns the number of the group, generated by given permutations,
# in the GAP Small Groups Library.
return IdGroup( Group( permlist ) );
end;

IdGroup512ByCode:=function( code )
# The function accepts the integer number that is the code for pcgs of 
# a group of order 512 and returns the number of this group in the
# GAP Small Groups library. It is assumed that the client will make sure
# that the code is valid.
local G, F, H;
G := PcGroupCode( code, 512 );
F := PqStandardPresentation( G );
end;

ApplyFunction:=function( func, arg )
return EvalString( func )( arg );
end;

LoopTest:=function( nrservers, nrsteps, k )
local port, proc, res;
# in the beginning the external client sends k=0 to the port 26133, e.g.
# NewProcess( "LoopTest", [ 2, 10, 0 ], "localhost", 26133 : return_nothing );
Print(k, " \c");
k:=k+1;
if k = nrsteps then
  Print( "--> ", k," : THE LIMIT ACHIEVED, TEST STOPPED !!! \n" );
  return true;
fi;
port := 26133 + ( k mod nrservers );
Print("--> ", k," : ", port, "\n");
proc:=NewProcess( "LoopTest", [ nrservers, nrsteps, k ], "localhost", port : return_nothing );
return true;
end;

LeaderElectionDone:=false;
# For example, to start on 4 servers, enter:
# nr:=4;NewProcess( "LeaderElection", ["init",0,nr], "localhost", 26133) : return_nothing );
LeaderElection:=function( status, id, nr )
local proc, nextport, m;
# status is either "init", "candidate" or "leader"
if not LeaderElectionDone then
	nextport := 26133 + ((SCSCPserverPort-26133+1) mod nr);
	if status="init" then # id can be anything on the init stage
	  	Print( "Initialising, sending candidate ", [SCSCPserverPort, IO_getpid() ], " to ", nextport, "\n" );
		proc:=NewProcess( "LeaderElection", [ "candidate", [ SCSCPserverPort, IO_getpid() ], nr ], 
	    	              "localhost", nextport : return_nothing );
		return true;
	elif status="candidate" then
		if id[2] = IO_getpid() then
			LeaderElectionDone := true;
			Print( "Got ", status, " ", id, ". Election done, sending leader ", id, " to ", nextport, "\n" );
			proc:=NewProcess( "LeaderElection", [ "leader", id, nr ], "localhost", nextport : return_nothing );
			return true; 			
		else
			if id[2] < IO_getpid() then
				m := id;
			else;
				m := [ SCSCPserverPort, IO_getpid() ];
			fi;
			Print( "Got ", status, " ", id, ", sending candidate ", m , " to ", nextport, "\n" );
			proc:=NewProcess( "LeaderElection", [ status, m, nr ], "localhost", nextport : return_nothing );
			return true; 
		fi;
	else
		LeaderElectionDone := true;
		Print( "Got ", status, " ", id, ", sending ", status, " ", id, " to ", nextport, "\n" );
		proc:=NewProcess( "LeaderElection", [ status, id, nr ], "localhost", nextport : return_nothing );
		return true; 
	fi;
else
  	Print( "Got ", status, " ", id, ", doing nothing \n" );
	return true;	
fi;	
end;

ResetLeaderElection:=function()
LeaderElectionDone:=false;
Print( "Reset LeaderElectionDone to ", LeaderElectionDone, "\n" );
return true;
end;

PointImages:=function( G, n )
local g;
return Set( List( GeneratorsOfGroup(G), g -> n^g ) );
end;

EvaluateOpenMathCode:=function( omc );
return omc;
end;

ChangeInfoLevel:=function(n)
SetInfoLevel(InfoSCSCP,n);
return true;
end;


#############################################################################
#
# Installation of procedures to make them available for WS 
# (you can also install procedures contained in other files,
# including standard GAP procedures and functions)
#
#############################################################################

# Other procedures
InstallSCSCPprocedure( "Factorial", Factorial, "See ?Factorial in GAP", 1, 1 );
InstallSCSCPprocedure( "WS_Factorial", FactorialAsString, "Returns result as a string to transmit large integers", 1 );
InstallSCSCPprocedure( "WS_Phi", Phi, "Euler's totient function", 1, 1 );
InstallSCSCPprocedure( "GroupIdentificationService", IdGroupByGenerators, 1, infinity, rec() );
InstallSCSCPprocedure( "IdGroup512ByCode", IdGroup512ByCode, 1 );
InstallSCSCPprocedure( "WS_IdGroup", IdGroup, "See ?IdGroup in GAP" );

# Series of factorisation methods from the GAP package FactInt
InstallSCSCPprocedure("WS_FactorsTD", FactorsTD );
InstallSCSCPprocedure("WS_FactorsPminus1", FactorsPminus1 );
InstallSCSCPprocedure("WS_FactorsPplus1", FactorsPplus1 );
InstallSCSCPprocedure("WS_FactorsECM", FactorsECM );
InstallSCSCPprocedure("WS_FactorsCFRAC", FactorsCFRAC );
InstallSCSCPprocedure("WS_FactorsMPQS", FactorsMPQS );

InstallSCSCPprocedure("WS_ConwayPolynomial", ConwayPolynomial );

KaratsubaPolynomialMultiplicationExtRepByString:=function(s1,s2)
return String( KaratsubaPolynomialMultiplicationExtRep( EvalString(s1), EvalString(s2) ) );
end;

InstallSCSCPprocedure("WS_Karatsuba", KaratsubaPolynomialMultiplicationExtRepByString);

InstallSCSCPprocedure( "ApplyFunction", ApplyFunction );

InstallSCSCPprocedure( "LoopTest", LoopTest );
InstallSCSCPprocedure( "LeaderElection", LeaderElection );
InstallSCSCPprocedure( "ResetLeaderElection", ResetLeaderElection );

InstallSCSCPprocedure( "ChangeInfoLevel", ChangeInfoLevel );

InstallSCSCPprocedure( "PointImages", PointImages );

InstallSCSCPprocedure( "EvaluateOpenMathCode", EvaluateOpenMathCode, 
    "Evaluates OpenMath code given as an input (without OMOBJ tags) wrapped in OMPlainString", 1, 1 );
# Example:
# EvaluateBySCSCP( "EvaluateOpenMathCode", 
#   [ OMPlainString("<OMA><OMS cd=\"arith1\" name=\"plus\"/><OMI>1</OMI><OMI>2</OMI></OMA>")],
#   "localhost",26133 ); 

#############################################################################
#
# procedures for automata
#
InstallSCSCPprocedure( "EpsilonToNFA", EpsilonToNFA ); # from the 'automata' package
InstallSCSCPprocedure( "TwoStackSerAut", TwoStackSerAut );
InstallSCSCPprocedure( "DerivedStatesOfAutomaton", DerivedStatesOfAutomaton );


#############################################################################
#
# Finally, we start the SCSCP server. Note that RunSCSCPserver will use the 
# next available port if the default port from scscp/config.g is unavailable
#
#############################################################################

ReadPackage("scscp/lib/errors.g"); # to patch ErrorInner in the server mode

RunSCSCPserver( SCSCPserverAddress, SCSCPserverPort );