#############################################################################
##
#W process.gi               The SCSCP package             Alexander Konovalov
#W                                                               Steve Linton
##
#H $Id$
##
#############################################################################


DeclareRepresentation( "IsProcessRepresentation", 
                       IsPositionalObjectRep,
                       [ 1, 2 ] );
                       
ProcessesFamily := NewFamily( "ProcessesFamily(...)", IsProcess );
                       
ProcessDefaultType := NewType( ProcessesFamily, 
                               IsProcessRepresentation and IsProcess);


#############################################################################
##
#M  ViewObj( <process> )
##
InstallMethod( ViewObj, "for process",
[ IsProcessRepresentation and IsProcess ],
function( proc )
    local stream, pid;
    stream := proc![1];
    pid := proc![2];
    Print("< ");
    if IsClosedStream(stream) then
        Print("closed ");
    fi;
    Print("process at ",stream![2],":",stream![3][1], " pid=", pid, " >");
end);


#############################################################################
##
#M  PrintObj( <ioTCPstream> )
##
InstallMethod( PrintObj, "for process",
[ IsProcessRepresentation and IsProcess ],
function( proc )
    local stream, pid;
    stream := proc![1];
    pid := proc![2];
    Print("< ");
    if IsClosedStream(stream) then
        Print("closed ");
    fi;
    Print("process at ",stream![2],":",stream![3][1], " pid=", pid, " >");
end);


#############################################################################
#
# NewProcess( command, listargs, server, port )
#
# The function sends the request to the SCSCP server, and
# returns the InputOutputTCPStream for waiting the result
#
InstallGlobalFunction( NewProcess,
function( command, listargs, server, port )

local stream, initmessage, session_id, omtext, localstream,
      return_cookie, return_nothing, attribs, ns, server_scscp_version, pid;

if ValueOption("return_cookie") <> fail then
  return_cookie := ValueOption( "return_cookie" );
else
  return_cookie := false;  
fi;

if ValueOption("return_nothing") <> fail then
  return_nothing := ValueOption( "return_nothing" );
else
  return_nothing := false;  
fi;

stream := InputOutputTCPStream( server, port );
initmessage := ReadLine( stream );
NormalizeWhitespace( initmessage );
Info( InfoSCSCP, 1, "Got connection initiation message" );
Info( InfoSCSCP, 2, initmessage );
session_id := initmessage{ [ PositionSublist(initmessage,"service_id=")+12 .. 
                             PositionSublist(initmessage,"\" scscp_versions")-1 ] };
attribs := [ [ "call_ID", session_id ] ];
pid := EvalString(session_id{[PositionNthOccurrence(session_id,':',2)+1 .. Length(session_id)]});
 

WriteLine( stream, "<?scscp version=\"1.0\" ?>" );
server_scscp_version := ReadLine( stream );
if server_scscp_version <> "<?scscp version=\"1.0\" ?>\n" then
  Error("Incompatible protocol versions, the server requires ", server_scscp_version );
fi;
  
if return_cookie then
  Add( attribs, [ "option_return_cookie", "" ] );
fi; 

if return_nothing then
  Add( attribs, [ "option_return_nothing", "" ] );
fi; 

if InfoLevel( InfoSCSCP ) > 2 then
  Print("#I Composing procedure_call message: \n");
  omtext:="";
  localstream := OutputTextString( omtext, true );
  OMPutProcedureCall( localstream, 
                      command, 
                      rec(     object := listargs, 
                           attributes := attribs ) );
  Print(omtext);
fi;

OMPutProcedureCall( stream, 
                    command, 
                      rec(     object := listargs, 
                           attributes := attribs ) );
              
Info( InfoSCSCP, 1, "Request sent ...");                           
return Objectify( ProcessDefaultType, [ stream, pid ] );
end); 


#############################################################################
#
# CompleteProcess( <stream> )
#
# The function waits for the process completion, 
# then collects the result and closes the stream
#
InstallGlobalFunction( CompleteProcess,
function( process )
local stream, result, return_cookie;

if ValueOption("return_cookie") <> fail then
  return_cookie := ValueOption( "return_cookie" );
else
  return_cookie := false;  
fi;

stream := process![1];
IO_Select( [ stream![1] ], [ ], [ ], [ ], 60*60, 0 );
result := OMGetObjectWithAttributes( stream );
# This needs to be fixed. Reference must be converted automatically to the
# remote object. Then there is no need in a option for cookie in this function.
if return_cookie then
  result.object := RemoteObject( result.object, stream![2], stream![3][1] );
fi;
Info( InfoSCSCP, 2, "Got back: object ", result.object, " with attributes ", result.attributes );
CloseStream(stream); 
return result;
end);


#############################################################################
#
# TerminateProcess( <process> )
#
# The function is supposed to send the interrupt signal to the server.
# Now it just closes the stream on the client side, but the server will
# recognize this only when the computation will be completed. We introduce
# this function as a nameplace for further implementing a proper interrupt
# mechanism.
#
InstallGlobalFunction( TerminateProcess,
function( process )
# THIS WORKS ONLY LOCALLY
if process![1]![2]="localhost" then
  IO_kill( process![2], IO.SIGINT );
fi;  
# closing stream too early (for example, when server writes to it)
# causes server crash because of the broken pipe :( 
# we need to send a proper Ctrl-C signal to the server, then it
# will enter into a break loop and will send an error message from the
# break loop to the client - this happens when you press Ctrl-C in the
# server's window.
# CloseStream(process![1]); 
#
# Another possible scenarios:
#
# 1) Multi-user service: the SCSCP server accepts A:1 incoming request and starts another
# process B:2. The client communicates with B:2, and then sends to A:1 request to interrupt
# the service B:2. Then A:1 performs (in GAP) either "IO_kill(<pid>,15);" or
# Exec("kill -s SIGUSR2 <pid>");
#
# 2) Single-user service: We start two parallel services, A:1 is the production service, and B:1
# is used to interrupt (and restart somehow?) the service A:1
#
# 3) Remote user executes (in GAP) Exec("ssh <hostname> kill -s SIGUSR2 <pid>");"
# (need have enough credentials to login into remote machine).
#
#
# (3) Works remotely. However, the user must be an owner of the process, since only the super-user
# may send signals to other users' processes, and there are other possible issues as well.
#
# (1) and (2) require some care of a register of users and their respective pid
# so the request like
#
#    <OMS cd="scscp1" name="interrupt_computation" />
#    <OMSTR>call_identifier</OMSTR>
#
# should lead to terminate that session for which the client is authorised.
# This must be feasible.
#
end);


#############################################################################
#
# SynchronizeProcessesN( <list of processes> )
#
SynchronizeProcessesN := function( processes )
local result, waitinglist, descriptors, s, nrdesc, i, nrprocess;
result := [];
waitinglist:=[ 1 .. Length(processes) ];
while Length(waitinglist) > 0 do
  descriptors := List( processes{waitinglist}, s -> IO_GetFD( s![1] ) );  
  IO_select( descriptors, [ ], [ ], 60*60, 0 );
  nrdesc := First( [ 1 .. Length(descriptors) ], i -> descriptors[i]<>fail );
  nrprocess := waitinglist[ nrdesc ];
  Info( InfoSCSCP, 1, "Process number ", nrprocess, " is ready");
  result[nrprocess] := CompleteProcess( processes[nrprocess] );
  SubtractSet(waitinglist,[nrprocess]); 
od;
return result;
end;


#############################################################################
#
# SynchronizeProcesses2( a, b )
#
# We can faster synchronize two processes, avoiding list manipulations
#
SynchronizeProcesses2 := function( a, b )
local result, descriptors;
result:=[];
descriptors := [ IO_GetFD( a![1] ), IO_GetFD( b![1] ) ];
IO_select( descriptors, [ ], [ ], 60*60, 0 );
if descriptors[1]<>fail then # 1st process is ready
  Info( InfoSCSCP, 1, "Process number 1 is ready");
  result[1] := CompleteProcess( a );
  Info( InfoSCSCP, 1, "Closed 1st process, waiting for 2nd ...");  
  result[2] := CompleteProcess( b );
  return result;
elif descriptors[2]<>fail then # 2nd process is ready
  Info( InfoSCSCP, 1, "Process number 2 is ready");
  result[2] := CompleteProcess( b );
  Info( InfoSCSCP, 1, "Closed 2nd process, waiting for 1st ...");  
  result[1] := CompleteProcess( a );  
  return result;
else
  Error("Error in Synchronize2, both descriptors failed!!! \n");
fi;
end;


#############################################################################
#
# SynchronizeProcesses( <list of processes> )
# SynchronizeProcesses( <process1>, ..., <processN> )
InstallGlobalFunction( SynchronizeProcesses,
function( arg )
if Length(arg)=2 then
  return SynchronizeProcesses2( arg[1], arg[2] );
else
  return SynchronizeProcessesN( arg[1] );
fi;
end);


#############################################################################
#
# FirstProcessN( <list of processes> )
#
FirstProcessN := function( processes )
local descriptors, nrdesc, i, result, nr;
descriptors := List( processes, s -> IO_GetFD( s![1] ) );  
IO_select( descriptors, [ ], [ ], 60*60, 0 );
nrdesc := First( [ 1 .. Length(descriptors) ], i -> descriptors[i]<>fail );
Info( InfoSCSCP, 1, "Process number ", nrdesc, " is ready");
result := CompleteProcess( processes[ nrdesc ] );
for nr in [ 1 .. Length(descriptors) ] do
  if nr <> nrdesc then
    TerminateProcess( processes[nr] );
  fi;  
od; 
return result;
end;


#############################################################################
#
# FirstProcess2( a, b )
#
# We can faster handle the case of two processes, avoiding list manipulations
#
FirstProcess2 := function( a, b )
local result, descriptors;
result:=[];
descriptors := [ IO_GetFD( a![1] ), IO_GetFD( b![1] ) ];
IO_select( descriptors, [ ], [ ], 60*60, 0 );
if descriptors[1]<>fail then # 1st process is ready
  Info( InfoSCSCP, 1, "Process number 1 is ready");
  result := CompleteProcess( a );
  TerminateProcess( b );
  return result;
elif descriptors[2]<>fail then # 2nd process is ready
  Info( InfoSCSCP, 1, "Process number 2 is ready");
  result := CompleteProcess( b );
  TerminateProcess( a );  
  return result;
else
  Error("Error in FirstProcess2, both descriptors failed!!! \n");
fi;
end;


#############################################################################
#
# FirstProcess( <list of processes> )
# FirstProcess( <process1>, ..., <processN> )
InstallGlobalFunction( FirstProcess,
function( arg )
if Length(arg)=2 then
  return FirstProcess2( arg[1], arg[2] );
else
  return FirstProcessN( arg[1] );
fi;
end);