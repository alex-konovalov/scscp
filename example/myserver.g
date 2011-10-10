#############################################################################
#
# This is the SCSCP server configuration file.
# The service provider can start the server just by the command 
# $ gap myserver.g
#
#############################################################################

#############################################################################
#
# Load necessary packages and read external files. 
# Put here and other commands if needed.
#
#############################################################################

LogTo(); # to close log file if it was opened from .gaprc
LoadPackage("scscp");
LoadPackage("factint");
LoadPackage("anupq");
LoadPackage("monoid");
LoadPackage("cvec");
ReadPackage("scscp/example/karatsuba.g");

#############################################################################
#
# Procedures and functions available for the SCSCP server
# (you can also install procedures contained in other files,
# including standard GAP procedures and functions) by adding
# appropriate calls to InstallSCSCPprocedure below.
#
#############################################################################


#############################################################################
#
# IdGroupByGenerators( <list of permutations> )
# 
# Returns the number of the group, generated by given permutations,
# in the GAP Small Groups Library.
# 
IdGroupByGenerators:=function( permlist )
return IdGroup( Group( permlist ) );
end;


#############################################################################
#
#  QuillenSeriesByIdGroup( [ ord, nr] )
#  
# Let G:=SmallGroup( ord, nr ) be a p-group of order p^n. It was proved in 
# [D.Quillen, The spectrum of an equivariant cohomology ring II, Ann. of 
# Math., (2) 94 (1984), 573-602] that the number of conjugacy classes of 
# maximal elementary abelian subgroups of given rank is determined by the 
# group algebra KG. 
# The function calculates this numbers for each possible rank and returns 
# a list of the length n, where i-th element corresponds to the number of
# conjugacy classes of maximal elementary abelian subgroups of the rank i.
#
QuillenSeriesByIdGroup := function( id )
local G, qs, latt, msl, ccs, ccs_repr, i, x, n;
G := SmallGroup( id );
latt := LatticeSubgroups(G);
msl := MinimalSupergroupsLattice(latt);
ccs := ConjugacyClassesSubgroups(latt);
ccs_repr := List(ccs, Representative);
qs := [];
for i in [ 1 .. LogInt( Size(G), PrimePGroup(G) ) ] do
  qs[i]:=0;
od;
for i in [ 1 .. Length(ccs_repr) ] do 
  if IsElementaryAbelian( ccs_repr[i] ) then
    if ForAll( msl[i], 
               x -> IsElementaryAbelian( ccs[x[1]][x[2]] ) = false ) then
      n := LogInt( Size(ccs_repr[i]), PrimePGroup(G) );
      qs[n] := qs[n] + 1;
    fi;
  fi;
od;
return [ id, qs ];
end;


PointImages:=function( G, n )
local g;
return Set( List( GeneratorsOfGroup(G), g -> n^g ) );
end;

SCSCPadditionService:=function(a,b)
return a+b;
end;

#############################################################################
#
# Installation of procedures to make them available for WS 
# (you can also install procedures contained in other files,
# including standard GAP procedures and functions)
#
#############################################################################

# Simple procedures for tests and demos
InstallSCSCPprocedure( "Identity", x -> x, "Identity procedure for tests", 1, 1 );
InstallSCSCPprocedure( "WS_Factorial", Factorial, "See ?Factorial in GAP", 1, 1 );
InstallSCSCPprocedure( "addition", SCSCPadditionService, "to add two integers", 2, 2 );
InstallSCSCPprocedure( "WS_Phi", Phi, "Euler's totient function, see ?Phi in GAP", 1, 1 );
InstallSCSCPprocedure( "Length", Length, 1, 1 );
InstallSCSCPprocedure( "Size", Size, 1, 1 );
InstallSCSCPprocedure( "Determinant", Determinant );
InstallSCSCPprocedure( "NrConjugacyClasses", NrConjugacyClasses, 1, 1 );
InstallSCSCPprocedure( "SylowSubgroup", SylowSubgroup, 2, 2 );
InstallSCSCPprocedure( "IsPrimeInt", IsPrimeInt, 1, 1 );

# Group identification in the GAP small group library
InstallSCSCPprocedure( "GroupIdentificationService", IdGroupByGenerators, 
	"Accepts a list of permutations and returns IdGroup of the group they generate", 1, infinity );
InstallSCSCPprocedure( "WS_IdGroup", IdGroup, "See ?IdGroup in GAP", 1, 1 );


###########################################################################
#
# IdGroup512ByCode( <pcgs code of the group> )
# 
# The function accepts the integer number that is the code for pcgs of 
# a group of order 512 and returns the number of this group in the
# GAP Small Groups library. It is assumed that the client will make sure
# that the code really corresponds to the group of order 512, since this
# can not be checked from the code itself.
#
# This function requires ANUPQ package for IdStandardPresented512Group.
#
if ARCH_IS_UNIX() then
  IdGroup512ByCode:=function( code )
  local G, F, H;
  G := PcGroupCode( code, 512 );
  F := PqStandardPresentation( G );
  H := PcGroupFpGroup( F );
  return IdStandardPresented512Group( H );
  end;
  InstallSCSCPprocedure( "IdGroup512ByCode", IdGroup512ByCode, 
	  "Identification of groups of order 512 using the ANUPQ package", 1, 1 );
fi;
	
InstallSCSCPprocedure( "MatrixGroup", Group );

# Important MIP (modular isomorphism problem for group algebras of finite p-group 
# over the field of p elements) invariant
InstallSCSCPprocedure( "QuillenSeriesByIdGroup", QuillenSeriesByIdGroup, 
	"Quillen series of a finite p-group given by IdGroup (list of two integers)", 1, 1 );

# Service used to compute automorphism groups of transformation semigroups with
# the MONOID package, which requires the GRAPE package, and the latter requires 
# the external program 'nauty' by Brendan D. McKay
InstallSCSCPprocedure( "WS_AutomorphismGroup", AutomorphismGroup, 1, 1 );

# GAP group libraries
InstallSCSCPprocedure( "WS_AlternatingGroup", AlternatingGroup );
InstallSCSCPprocedure( "WS_SymmetricGroup", SymmetricGroup );
InstallSCSCPprocedure( "WS_SmallGroup", SmallGroup );
InstallSCSCPprocedure( "WS_TransitiveGroup", TransitiveGroup );
InstallSCSCPprocedure( "WS_PrimitiveGroup", PrimitiveGroup );
InstallSCSCPprocedure( "MathieuGroup", MathieuGroup );

# Multiplication services
InstallSCSCPprocedure( "WS_Mult", function(a,b) return a*b; end );
InstallSCSCPprocedure( "WS_MultMatrix", 
	function(a,b) 
	if not IsMatrix(a) or not IsMatrix(b) then
		Error( "The argument must be a matrix!" );
	else
		return a*b; 
	fi;
	end );

# Lattice of subgroups
InstallSCSCPprocedure( "WS_LatticeSubgroups", LatticeSubgroups, 1, 1 );
	
# Series of factorisation methods from the GAP package FactInt
InstallSCSCPprocedure("WS_FactorsTD", FactorsTD, 
	"FactorsTD from FactInt package, see ?FactorsTD in GAP", 1, 2 );
InstallSCSCPprocedure("WS_FactorsPminus1", FactorsPminus1, 
	"FactorsPminus1 from FactInt package, see ?FactorsPminus1 in GAP", 1, 4 );
InstallSCSCPprocedure("WS_FactorsPplus1", FactorsPplus1, 
	"FactorsPplus1 from FactInt package, see ?FactorsPplus1 in GAP", 1, 4 );
InstallSCSCPprocedure("WS_FactorsECM", FactorsECM, 
	"FactorsECM from FactInt package, see ?FactorsECM in GAP", 1, 5 );
InstallSCSCPprocedure("WS_FactorsCFRAC", FactorsCFRAC, 
	"FactorsCFRAC from FactInt package, see ?FactorsCFRAC in GAP", 1, 1 );
InstallSCSCPprocedure("WS_FactorsMPQS", FactorsMPQS, 
	"FactorsMPQS from FactInt package, see ?FactorsMPQS in GAP", 1, 1 );

InstallSCSCPprocedure("WS_ConwayPolynomial", ConwayPolynomial, "See ?ConwayPolynomial in GAP", 2, 2 );

InstallSCSCPprocedure( "PointImages", PointImages, 
	"1st argument is a permutation group G, 2nd is an integer n. Returns the set of images of n under generators of G", 2, 2 );

KaratsubaPolynomialMultiplicationExtRepByString:=function(s1,s2)
return String( KaratsubaPolynomialMultiplicationExtRep( EvalString(s1), EvalString(s2) ) );
end;

InstallSCSCPprocedure("WS_Karatsuba", KaratsubaPolynomialMultiplicationExtRepByString, 
	"See Examples chapter in the SCSCP package manual", 2, 2 );


#############################################################################
#
# procedures for the UnitLib package for the parallel computation of the
# normalized unit group of a modular group algebra of a finite p-group
# from the GAP small groups library
#
if LoadPackage("unitlib") = true then
  if CompareVersionNumbers( GAPInfo.PackagesInfo.("unitlib")[1].Version, "3.0.0" ) then
	InstallSCSCPprocedure( "NormalizedUnitCFpower", NormalizedUnitCFpower );
	InstallSCSCPprocedure( "NormalizedUnitCFcommutator", NormalizedUnitCFcommutator );
  fi;		
fi;


#############################################################################
#
# procedure to test pickling/unpickling from the IO package for data encoding
# 
IO_UnpickleStringAndPickleItBack:=function( picklestr )
return( IO_PickleToString( IO_UnpickleFromString( picklestr ) ) );
end;

InstallSCSCPprocedure( "IO_UnpickleStringAndPickleItBack", IO_UnpickleStringAndPickleItBack, 
	"To test how pickling format from IO package may be used for data transmitting (see ?IO_Pickle, ?IO_Unpickle)", 1, 1 );


#############################################################################
#
# some private code which may be missing in your installation
# 
if IsExistingFile( Concatenation( GAPInfo.PackagesInfo.("scscp")[1].InstallationPath,"/example/private.g") ) then
	Read( Concatenation( GAPInfo.PackagesInfo.("scscp")[1].InstallationPath,"/example/private.g") );
fi;

if IsExistingFile( Concatenation( GAPInfo.PackagesInfo.("scscp")[1].InstallationPath,"/example/orbits.g") ) then
	Read( Concatenation( GAPInfo.PackagesInfo.("scscp")[1].InstallationPath,"/example/orbits.g") );
fi;

if IsExistingFile( Concatenation( GAPInfo.PackagesInfo.("scscp")[1].InstallationPath,"/example/rewrite.g") ) then
	Read( Concatenation( GAPInfo.PackagesInfo.("scscp")[1].InstallationPath,"/example/rewrite.g") );
	InstallSCSCPprocedure( "RewritabilityWorker", RewritabilityWorker );
fi;

#############################################################################
#
# Finally, we start the SCSCP server. 
#
#############################################################################

RunSCSCPserver( SCSCPserverAddress, SCSCPserverPort );