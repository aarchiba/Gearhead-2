unit gears;
	{ The building block from which everything in this game }
	{ is constructed is called a GEAR. This unit has been }
	{ ripped and stripped down from GH2 v0.627.}
{
	Dungeone Monkey Unlimited, a tactics combat CRPG
	Copyright (C) 2010 Joseph Hewitt

	This library is free software; you can redistribute it and/or modify it
	under the terms of the GNU Lesser General Public License as published by
	the Free Software Foundation; either version 2.1 of the License, or (at
	your option) any later version.

	The full text of the LGPL can be found in license.txt.

	This library is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
	General Public License for more details. 

	You should have received a copy of the GNU Lesser General Public License
	along with this library; if not, write to the Free Software Foundation,
	Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA 
}
{$LONGSTRINGS ON}

interface

uses lua,lualib,lauxlib;

Const
	NumGearStats = 8;	{The number of STAT slots}
				{in a GEAR record}

	{ Include the game constants here. I've externalized all of them so }
	{ the same list can be loaded into Lua- good thing both Pascal and Lua }
	{ use the same assignment operator for constants, eh? }
	{$I gamedata/gh_constants.txt}

	MassPerMV = 15;		{ Amount of mass per MV , TR modifier. }

	{ This array tells if a given material regenerates damage. }
	MAT_Regenerate: Array [0..NumMaterial] of Boolean = (
		False, True, True
	);

	Lua_is_Go: Boolean = False;


Type
	SAttPtr = ^SAtt;
	SAtt = Record		{*** STRING ATTRIBUTE ***}
		info: String;
		next: SAttPtr;
	end;

	NAttPtr = ^NAtt;
	NAtt = Record		{*** NUMERICAL ATTRIBUTE ***}
		G,S: Integer;		{General, Specific, Value}
		V: LongInt;
		next: NAttPtr;
	end;

	GearPtr = ^gear;
	gear = Record		{*** GEARHEAD BIT ***}
		G,S,V: Integer;		{General Descriptive,}
					{Specific Descriptive,}
					{and Value Descriptive}
		Scale: Integer;
		Stat: Array [1..NumGearStats] of Integer;

		Scripts: SAttPtr;	{ The Lua scripts associated with this gear }

		SA: SAttPtr;		{String Attributes.}
		NA: NAttPtr;		{Numerical Attributes.}

		next: GearPtr;		{Next sibling Gear}
		subcom: GearPtr;	{Child Internal Gear}
		invcom: GearPtr;	{Child External Gear}
		parent: GearPtr;	{Parent of the current Gear.}
	end;


var
	MyLua: PLua_State;
	MyErrors: SAttPtr;



Function CreateSAtt(var LList: SAttPtr): SAttPtr;
Procedure DisposeSAtt(var LList: SAttPtr);
Procedure RemoveSAtt(var LList,LMember: SAttPtr);
Function FindSAtt(LList: SAttPtr; const Code_In: String): SAttPtr;
Function SetSAtt(var LList: SAttPtr; const Info: String): SAttPtr;
Function StoreSAtt(var LList: SAttPtr; const Info: String): SAttPtr;
Function AddSAtt( var LList: SAttPtr; const S_Label_in,S_Data: String ): SAttPtr;
Function SAttValue(LList: SAttPtr; const Code: String): String;
function NumSAtts( GList: SAttPtr ): Integer;
function RetrieveSAtt( List: SAttPtr; N: Integer ): SAttPtr;
function SelectRandomSAtt( SAList: SAttPtr ): SAttPtr;
Function LoadStringList( const FName_In: String ): SAttPtr;
Procedure SaveStringList( const FName: String; SList: SattPtr );
Procedure ExpandFileList( var FList: SAttPtr; const P: String );
Function CreateFileList( const P: String ): SAttPtr;

Procedure SortStringList( var LList: SAttPtr );

Procedure RecordError( const ErrMsg: String );


Function NumHeadMatches( const head_in: String; LList: SAttPtr ): Integer;
Function FindHeadMatch( const head_in: String; LList: SAttPtr; N: Integer ): SAttPtr;

Function CreateNAtt(var LList: NAttPtr): NAttPtr;
Procedure DisposeNAtt(var LList: NAttPtr);
Procedure RemoveNAtt(var LList,LMember: NAttPtr);
Function FindNAtt(LList: NAttPtr; G,S: Integer): NAttPtr;
Function SetNAtt(var LList: NAttPtr; G,S: Integer; V: LongInt): NAttPtr;
Function AddNAtt(var LList: NAttPtr; G,S: Integer; V: LongInt): NAttPtr;
Function NAttValue(LList: NAttPtr; G,S: Integer): LongInt;
Procedure StripNAtt( Part: GearPtr ; G: Integer );
Function NumNAtts( LList: NAttPtr ): Integer;
function SelectRandomNAtt( NAList: NAttPtr ): NAttPtr;

Function LastGear(LList: GearPtr): GearPtr;
Function NewGear: GearPtr;
Procedure AppendGear( var LList: GearPtr; It: GearPtr );
Function AddGear(var LList: GearPtr; Parent: GearPtr): GearPtr;
Procedure DisposeGear(var LList: GearPtr);
Procedure RemoveGear(var LList,LMember: GearPtr);
Procedure DelinkGear(var LList,LMember: GearPtr);

Procedure ActivateGearScript( MyGear: GearPtr );
Procedure ActivateGearTree( MyGear: GearPtr );

function NumSiblingGears( GList: GearPtr ): Integer;
function SelectRandomGear( GList: GearPtr ): GearPtr;

function FindRoot( Part: GearPtr ): GearPtr;
Procedure InsertSubCom( Parent,NewMember: GearPtr );
Procedure InsertInvCom( Parent,NewMember: GearPtr );

Function IsFoundAlongTrack( Track,Part: GearPtr ): Boolean;
Function IsSubCom( Part: GearPtr ): Boolean;
Function IsInvCom( Part: GearPtr ): Boolean;

Function CloneSAtt( SA: SAttPtr ): SAttPtr;
Procedure AppendStringList( Dest,AddThis: SAttPtr );

Function CloneGear( Part: GearPtr ): GearPtr;
Function InstantGear( Part: GearPtr ): GearPtr;

Function RetrieveGearSib( List: GearPtr; N: Integer ): GearPtr;
Procedure Rescale( Part: GearPtr; SF: Integer );


Procedure MarkGearsWithNAtt( Master: GearPtr; G,S,V: LongInt );
Procedure MarkGearsWithSAtt( Master: GearPtr; const Info: String );

Procedure WriteCGears( var F: Text; G: GearPtr );
Function ReadCGears( var F: Text ): GearPtr;

Function LocateGearByIndex( Master: GearPtr; Num: Integer ): GearPtr;
Function FindGearIndex( Master , FindThis: GearPtr ): Integer;
function SeekGearByDesig( LList: GearPtr; Name: String ): GearPtr;

Function CreateComponentList( MasterList: GearPtr; const Context: String ): NAttPtr;
Function RandomComponentListEntry( ShoppingList: NAttPtr ): NAttPtr;
Function SelectComponentFromList( MasterList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;

function SeekGearByIDTag( LList: GearPtr; G,S,V: LongInt ): GearPtr;


implementation

uses sysutils,dos,texutil;

Const
	SaveFileContinue = 0;
	SaveFileSentinel = -1;

Type
	SAScriptRecPtr = ^SAScriptRec;
	SAScriptRec = Record
		SA: SAttPtr;
	end;


Function LastSAtt( LList: SAttPtr ): SAttPtr;
	{ Find the last SAtt in this particular list. }
begin
	if LList <> Nil then while LList^.Next <> Nil do LList := LList^.Next;

	LastSAtt := LList;
end;

Function CreateSAtt(var LList: SAttPtr): SAttPtr;
	{Add a new element to the tail of LList.}
var
	it: SAttPtr;
begin
	{Allocate memory for our new element.}
	New(it);
	if it = Nil then exit( Nil );
	it^.Next := Nil;

	{Attach IT to the list.}
	if LList = Nil then begin
		LList := it;
	end else begin
		LastSAtt( LList )^.Next := it;
	end;

	{Return a pointer to the new element.}
	CreateSAtt := it;
end;

Procedure DisposeSAtt(var LList: SAttPtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: SAttPtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;
		Dispose(LList);
		LList := LTemp;
	end;
end;

Procedure RemoveSAtt(var LList,LMember: SAttPtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: SAttPtr;
begin
	{Initialize A and B}
	B := LList;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		RecordError('ERROR- RemoveSAtt asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		LList := B^.Next;
		Dispose(B);
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		Dispose(B);
	end;
end;

Function LabelsMatch( const info,code: String ): Boolean;
	{ Return TRUE if UpCase( CODE ) matches UpCase( INFO ) all the }
	{ way to the first '<', ignoring spaces and tabs. }
var
	i_pos,c_pos: Integer;
begin
	{ error check... }
	if ( info = '' ) or ( code = '' ) then Exit( False );
	i_pos := 0;
	c_pos := 0;
	repeat
		inc( i_pos );
		inc( c_pos );
		while (i_pos <= Length(info)) and ((info[i_pos] = ' ') or (info[i_pos] = #9)) do begin
			Inc(i_pos);
		end;
		while (c_pos <= Length(code)) and ((code[c_pos] = ' ') or (code[c_pos] = #9)) do begin
			Inc(c_pos);
		end;
	until ( i_pos > Length( info ) ) or ( c_pos > Length( code ) ) or ( UpCase( info[i_pos] ) <> UpCase( code[c_pos] ) );

	LabelsMatch := ( c_pos > Length( code ) ) and ( i_pos <= Length( info ) ) and ( info[i_pos] = '<' );
end;

Function FindSAtt(LList: SAttPtr; const Code_In: String): SAttPtr;
	{Search through the list looking for a String Attribute}
	{whose code matches CODE and return its address.}
	{Return Nil if no such SAtt can be found.}
var
	it: SAttPtr;
	Code: String;
begin
	{Initialize IT to Nil.}
	it := Nil;

	Code := UpCase(Code_In);

	{Check through all the SAtts looking for the SATT in question.}
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if LabelsMatch( LList^.info , Code ) then it := LList;
		LList := LList^.Next;
	end;

	FindSAtt := it;
end;

Function SetSAtt(var LList: SAttPtr; const Info: String): SAttPtr;
	{Add string attribute Info to the list. However, a gear}
	{may not have two string attributes with the same name.}
	{So, check to see whether or not the list already contains}
	{a string attribute of this type; if so, just replace the}
	{INFO field. If not, create a new SAtt and fill it in.}
var
	it: SAttPtr;
	code: String;
begin
	{Determine the CODE of the string.}
	code := Info;
	code := ExtractWord(code);

	{See if that code already exists in the list,}
	{if not create a new entry for it.}
	it := FindSAtt(LList,code);

	{Plug in the value.}
	if RetrieveAString( Info ) = '' then begin
		if it <> Nil then RemoveSAtt( LList , it );
	end else begin
		if it = Nil then it := CreateSAtt(LList);
		it^.info := Info;
	end;

	{Return a pointer to the new attribute.}
	SetSAtt := it;
end;

Function StoreSAtt(var LList: SAttPtr; const Info: String): SAttPtr;
	{ Add string attribute Info to the list. This procedure }
	{ doesn't check to make sure this attribute isn't duplicated. }
var
	it: SAttPtr;
begin
	it := CreateSAtt(LList);
	it^.info := Info;

	{Return a pointer to the new attribute.}
	StoreSAtt := it;
end;

Function AddSAtt( var LList: SAttPtr; const S_Label_In,S_Data: String ): SAttPtr;
	{ Store this data in the string attributes list with kind-of the }
	{ same label. If the label already exists, store under Label1, }
	{ then the next data under Label2, and so on. }
var
	T: SAttPtr;
	S_Label,Info: String;
	Max,N: Integer;
begin
	{ ERROR CHECK- if no line exists currently, just add the basic label. }
	if FindSAtt( LList , S_Label_In ) = Nil then begin
		Exit( SetSAtt( LList , S_Label_In + ' <' + S_Data + '>' ) );
	end;

	{ Find the maximum value of this label currently stored in }
	{ the list. }
	Max := 1;
	S_Label := UpCase( S_Label_In ) + '_';

	{ Scan the list for examples of this label. }
	T := LList;
	while T <> Nil do begin
		Info := T^.Info;
		Info := UpCase( ExtractWord( Info ) );

		{ If the first characters are the same as S_label, this }
		{ is another copy of the list. }
		if Copy( Info , 1 , Length( S_Label ) ) = S_Label then begin
			Info := Copy( Info , Length( S_Label ) + 1 , Length( Info ) );
			N := ExtractValue( Info );
			if N >= Max then Max := N + 1;
		end;

		T := T^.Next;
	end;

	AddSAtt := SetSAtt( LList , S_Label + BStr( Max ) + ' <' + S_Data + '>' );
end;

Function SAttValue(LList: SAttPtr; const Code: String): String;
	{Find a String Attribute which corresponds to Code, then}
	{return its embedded alligator string.}
var
	it: SAttPtr;
begin
	it := FindSAtt(LList,Code);

	if it = Nil then Exit('');

	SAttValue := RetrieveAString(it^.info);
end;

function NumSAtts( GList: SAttPtr ): Integer;
	{ Count the number of sibling gears along this track. }
var
	N: Integer;
begin
	N := 0;
	while GList <> Nil do begin
		Inc( N );
		GList := GList^.Next;
	end;
	NumSAtts := N;
end;

function RetrieveSAtt( List: SAttPtr; N: Integer ): SAttPtr;
	{ Retrieve a SAtt from the list. }
begin
	{ error check- if asked to find a gear before the first one in }
	{ the list, obviously we can't do that. Return Nil. }
	if N < 1 then Exit( Nil );

	{ Search for the desired gear. }
	while ( N > 1 ) and ( List <> Nil ) do begin
		Dec( N );
		List := List^.Next;
	end;

	{ Return the last gear found. }
	RetrieveSAtt := List;
end;

function SelectRandomSAtt( SAList: SAttPtr ): SAttPtr;
	{ Pick one of the string attributes from the provided }
	{ list at random. }
var
	ST: SAttPtr;
	N,T: Integer;
begin
	{ Count the number of SAtts total. }
	ST := SAList;
	N := NumSAtts( SAList );
	{ Choose one randomly. }
	if N > 0 then begin
		T := Random( N ) + 1;
		ST := RetrieveSATt( SAList , T );
	end;
	SelectRandomSAtt := ST;
end;

Function LoadStringList( const FName_In: String ): SAttPtr;
	{ Load a list of string attributes from the listed file, }
	{ if it can be found. }
var
	SList: SAttPtr;
	F: Text;
	S: String;
        FName: String;
begin
	SList := Nil;
	FName := FSearch( FName_In , '.' );
	if FName <> '' then begin
		Assign( F , FName );
		Reset( F );

		{ Get rid of the opening comment }
		ReadLn( F , S );

		while not EOF( F ) do begin
			ReadLn( F , S );
			if ( S <> '' ) and ( S[1] <> '%' ) then StoreSAtt( SList , S );
		end;

		Close( F );
	end;
	LoadStringList := SList;
end;

Procedure SaveStringList( const FName: String; SList: SattPtr );
	{ Save a list of string attributes to the listed filename. }
var
	F: Text;
begin
	Assign( F , FName );
	Rewrite( F );

	WriteLn( F , '%%% File saved by SaveStringList %%%' );

	while SList <> Nil do begin
		WriteLn( F , SList^.Info );
		SList := SList^.Next;
	end;
	Close( F );
end;

Procedure ExpandFileList( var FList: SAttPtr; const P: String );
	{ Add more files to the list. }
var
	SRec: SearchRec;
begin
	FindFirst( P , AnyFile , SRec );

	{ As long as there are files which match our description, }
	{ process them. }
	While DosError = 0 do begin
		StoreSAtt( FList , SRec.Name );

		{ Look for the next file in the directory. }
		FindNext( SRec );
	end;
	FindClose( SRec );
end;

Function CreateFileList( const P: String ): SAttPtr;
	{ Create a list of file names which match the requested pattern. }
var
	LList: SAttPtr;
begin
	{ Start the search process going... }
	LList := Nil;
	ExpandFileList( LList , P );
	CreateFileList := LList;
end;

Procedure SortStringList( var LList: SAttPtr );
	{ Sort this list of strings in alphabetical order. }
var
	sorted: SAttPtr;	{The sorted list}
	a,b,c,d: SAttPtr;{Counters. We always need them, you know.}
	youshouldstop: Boolean;	{Can you think of a better name?}
begin
	{Initialize A and Sorted.}
	a := LList;
	Sorted := Nil;

	while a <> Nil do begin
		b := a;		{b is to be added to sorted}
		a := a^.next;	{increase A to the next item in the menu}

		{Give b's Next field a value of Nil.}
		b^.next := nil;

		{Locate the correct position in Sorted to store b}
		{ Get rid of anything that isn't a mecha. }
		if HeadMatchesString( 'PC_' , b^.info ) then begin
			{ This is an equipment file, not a mecha file. Delete it. }
			DisposeSAtt( b );
		end else if Sorted = Nil then
			{This is the trivial case- Sorted is empty.}
			Sorted := b
		else if UpCase( b^.info ) < Upcase( Sorted^.info ) then begin
			{b should be the first element in the list.}
			c := sorted;
			sorted := b;
			sorted^.next := c;
			end
		else begin
			{c and d will be used to move through Sorted.}
			c := Sorted;

			{Locate the last item lower than b}
			youshouldstop := false;
			repeat
				d := c;
				c := c^.next;

				if c = Nil then
					youshouldstop := true
				else if UpCase( c^.info ) > UpCase( b^.info ) then begin
					youshouldstop := true;
				end;
			until youshouldstop;
			b^.next := c;
			d^.next := b;
		end;
	end;
	LList := Sorted;
end;

Procedure RecordError( const ErrMsg: String );
	{ Store an error in the MyErrors list. }
begin
	StoreSAtt( MyErrors , ErrMsg );
end;

Function NumHeadMatches( const head_in: String; LList: SAttPtr ): Integer;
	{ Return how many SAtts in the list match the HEAD provided. }
	{ A match is made if the first Length(head) characters of }
	{ the string attribute are equal to head. }
var
	N: Integer;
        Head: String;
begin
	N := 0;
	Head := UpCase( Head_In );
	while LList <> Nil do begin
		if UpCase( Copy( LList^.Info , 1 , Length( Head ) ) ) = Head then begin
			Inc( N );
		end;
		LList := LList^.Next;
	end;
	NumHeadMatches := N;
end;

Function FindHeadMatch( const head_in: String; LList: SAttPtr; N: Integer ): SAttPtr;
	{ Return head match number N, as defined above. }
	{ If no match is found return Nil. }
var
	HM: SAttPtr;
        Head: String;
begin
	HM := Nil;
	Head := UpCase( Head_In );
	while LList <> Nil do begin
		if UpCase( Copy( LList^.Info , 1 , Length( Head ) ) ) = Head then begin
			Dec( N );
			if N = 0 then HM := LList;
		end;
		LList := LList^.Next;
	end;
	FindHeadMatch := HM;
end;

Function CreateNAtt(var LList: NAttPtr): NAttPtr;
	{Add a new element to the head of LList.}
var
	it: NAttPtr;
begin
	{Allocate memory for our new element.}
	New(it);
	if it = Nil then exit( Nil );

	{Initialize values.}

	it^.Next := LList;
	LList := it;

	{Return a pointer to the new element.}
	CreateNAtt := it;
end;

Procedure DisposeNAtt(var LList: NAttPtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: NAttPtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;
		Dispose(LList);
		LList := LTemp;
	end;
end;

Procedure RemoveNAtt(var LList,LMember: NAttPtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: NAttPtr;
begin
	{Initialize A and B}
	B := LList;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		RecordError('ERROR- RemoveLink asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		LList := B^.Next;
		Dispose(B);
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		Dispose(B);
	end;
end;

Function FindNAtt(LList: NAttPtr; G,S: Integer): NAttPtr;
	{Locate the numerical attribute described by G,S and}
	{return a pointer to it. If no such attribute exists}
	{in the list, return Nil.}
var
	it: NAttPtr;
begin
	{Initialize it to Nil.}
	it := Nil;

	{Loop through all the elements.}
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if (LList^.G = G) and (LList^.S = S) then it := LList;
		LList := LList^.Next;
	end;

	{Return the value.}
	FindNatt := it;
end;

Function SetNAtt(var LList: NAttPtr; G,S: Integer; V: LongInt ): NAttPtr;
	{Set the Numerical Attribute described by G,S to value V.}
	{If the attribute already exists, change its value. If not,}
	{create the attribute.}
var
	it: NAttPtr;
begin
	it := FindNAtt(LList,G,S);

	if ( it = Nil ) and ( V <> 0 ) then begin
		{The attribute doesn't currently exist. Create it.}
		it := CreateNAtt(LList);
		it^.G := G;
		it^.S := S;
		it^.V := V;
	end else if ( it <> Nil ) and ( V = 0 ) then begin
		RemoveNAtt( LList , it );
	end else if it <> Nil then begin
		{The attribute is already posessed. Just change}
		{its Value field.}
		it^.V := V;
	end;

	SetNAtt := it;
end;

Function AddNAtt(var LList: NAttPtr; G,S: Integer; V: LongInt ): NAttPtr;
	{Add value V to the value field of the Numerical Attribute}
	{described by G,S. If the attribute does not exist, create}
	{it and set its value to V.}
	{If, as a result of this operation, V drops to 0,}
	{the numerical attribute will be removed and Nil will}
	{be returned.}
var
	it: NAttPtr;
begin
	it := FindNAtt(LList,G,S);

	if it = Nil then begin
		{The attribute doesn't currently exist. Create it.}
		it := CreateNAtt(LList);
		it^.G := G;
		it^.S := S;
		it^.V := V;
	end else begin
		it^.V := it^.V + V;
	end;

	if it^.V = 0 then RemoveNAtt(LList,it);

	AddNAtt := it;
end;

Function NAttValue(LList: NAttPtr; G,S: Integer): LongInt;
	{Return the value of Numeric Attribute G,S. If this}
	{attribute is not posessed, return 0.}
var
	it: LongInt;
begin
	it := 0;
	while LList <> Nil do begin
		if (LList^.G = G) and (LList^.S = S) then it := LList^.V;
		LList := LList^.Next;
	end;
	NAttValue := it;
end;

Procedure StripNAtt( Part: GearPtr ; G: Integer );
	{ Remove all numeric attributes of general type G from }
	{ PART and all of its children. }
var
	SG: GearPtr;
	NA,NA2: NAttPtr;
begin
	{ Remove from PART. }
	NA := Part^.NA;
	while NA <> Nil do begin
		NA2 := NA^.Next;
		if NA^.G = G then RemoveNAtt( Part^.NA , NA );
		NA := NA2;
	end;

	{ Remove from the InvComponents. }
	SG := Part^.InvCom;
	while SG <> Nil do begin
		StripNAtt( SG , G );
		SG := SG^.Next;
	end;

	{ Remove from the SubComponents. }
	SG := Part^.SubCom;
	while SG <> Nil do begin
		StripNAtt( SG , G );
		SG := SG^.Next;
	end;
end;

Function NumNAtts( LList: NAttPtr ): Integer;
	{ Count the number of siblings in this list. }
var
	N: Integer;
begin
	N := 0;
	while LList <> Nil do begin
		Inc( N );
		LList := LList^.Next;
	end;
	NumNAtts := N;
end;

function RetrieveNAttByListPos( List: NAttPtr; N: Integer ): NAttPtr;
	{ Return the N'th NAtt from the list. }
begin
	{ error check- if asked to find a gear before the first one in }
	{ the list, obviously we can't do that. Return Nil. }
	if N < 1 then Exit( Nil );

	{ Search for the desired attribute. }
	while ( N > 1 ) and ( List <> Nil ) do begin
		Dec( N );
		List := List^.Next;
	end;

	{ Return the last attribute found. }
	RetrieveNAttByListPos := List;
end;

function SelectRandomNAtt( NAList: NAttPtr ): NAttPtr;
	{ Out of all the NAtts in the list, select one at random. }
var
	N,T: Integer;
	it: NAttPtr;
begin
	{ Count the number of NAtts total. }
	it := Nil;
	N := NumNAtts( NAList );
	{ Choose one randomly. }
	if N > 0 then begin
		T := Random( N ) + 1;
		it := RetrieveNAttByListPos( NAList , T );
	end;
	SelectRandomNAtt := it;
end;

Function LastGear(LList: GearPtr): GearPtr;
	{Search through the linked list, and return the last element.}
	{If LList is empty, return Nil.}
begin
	if LList <> Nil then
		while LList^.Next <> Nil do
			LList := LList^.Next;
	LastGear := LList;
end;

Function NewGear: GearPtr;
	{ Create a new gear, and initialize it to default values. }
var
	it: GearPtr;
	T: Integer;
begin
	{Allocate memory for our new element.}
	New(it);
	if it = Nil then exit( Nil );

	{Initialize values.}
	it^.Next := Nil;
	it^.SA := Nil;
	it^.NA := Nil;
	it^.SubCom := Nil;
	it^.InvCom := Nil;
	it^.Parent := Nil;

	it^.Scripts := Nil;

	it^.G := 0;
	it^.S := 0;
	it^.V := 0;
	it^.Scale := 0;

	for t := 1 to NumGearStats do it^.Stat[t] := 0;

	NewGear := it;
end;

Procedure AppendGear( var LList: GearPtr; It: GearPtr );
	{ Attach IT to the end of the list. }
begin
	{Attach IT to the list.}
	if LList = Nil then
		LList := it
	else
		LastGear(LList)^.Next := it;
end;

Function AddGear(var LList: GearPtr; Parent: GearPtr): GearPtr;
	{Add a new element to the end of LList.}
var
	it: GearPtr;
begin
	it := NewGear;

	it^.Parent := Parent;
	AppendGear( LList , It );

	{Return a pointer to the new element.}



	AddGear := it;
end;

Function Lua_SAtt_Reader( L: Plua_State; ud: Pointer; sz: Psize_t ): PChar; cdecl;
	{ This procedure will provide the next chunk of a lua script. }
var
	MSR: SAScriptRecPtr;
	ThisSA: SAttPtr;
begin
	MSR := SAScriptRecPtr( ud );
	{ Find the next non-empty string attribute. }
	while ( MSR^.SA <> Nil ) and ( Length( MSR^.SA^.Info ) < 1 ) do MSR^.SA := MSR^.SA^.Next;
	ThisSA := MSR^.SA;

	if ThisSA = Nil then begin
		Lua_SAtt_Reader := Nil;
	end else begin
		{ Move the MSR pointer to the next SATT in line. }
		MSR^.SA := MSR^.SA^.Next;
		sz^ := Length( ThisSA^.Info );
		Lua_SAtt_Reader := @( ThisSA^.Info[1] );
	end;
end;

Procedure LoadSAttScripts( SList: SAttPtr );
	{ Load the script located in this list onto the stack. }
var
	MyScriptRec: SAScriptRec;
begin
	MyScriptRec.SA := SList;
	if lua_load( MyLua , @Lua_SAtt_Reader , @MyScriptRec , 'LoadSAttScripts' ) <> 0 then RecordError( 'LoadSAttScripts ERROR: ' + lua_tostring( MyLua , -1 ) );
end;

Procedure ActivateGearScript( MyGear: GearPtr );
	{ We want to associate a script with this gear. Make it so. }
begin
	if Lua_is_Go then begin
		lua_getglobal( MyLua , 'gh_register' );
		lua_pushlightuserdata( MyLua , Pointer( MyGear ) );
		LoadSAttScripts( MyGear^.Scripts );
		if lua_pcall( MyLua , 2 , 0 , 0 ) <> 0 then RecordError( 'Register ERROR: ' + lua_tostring( MyLua , -1 ) );
	end else begin
		RecordError( 'Register ERROR: Cannot register before LUA_IS_GO' );
	end;
end;

Procedure ActivateGearTree( MyGear: GearPtr );
	{ Activate all the gears within this tree. }
var
	T: GearPtr;
begin
	ActivateGearScript( MyGear );
	T := MyGear^.SubCom;
	while T <> Nil do begin
		ActivateGearTree( T );
		T := T^.Next;
	end;
	T := MyGear^.InvCom;
	while T <> Nil do begin
		ActivateGearTree( T );
		T := T^.Next;
	end;
end;


Procedure DisposeGear( var LList: GearPtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: GearPtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;

		{ Dispose of its scripts. }
		{ We need to do this first, since the NAtts and SAtts may be }
		{ needed by the Lua deallocator. }
		if Lua_is_Go then begin
			lua_getglobal( MyLua , 'gh_deregister' );
			lua_pushlightuserdata( MyLua , Pointer( LList ) );
			if lua_pcall( MyLua , 1 , 0 , 0 ) <> 0 then RecordError( 'DeRegister ERROR: ' + lua_tostring( MyLua , -1 ) );
		end;
		if LList^.Scripts <> Nil then begin
			DisposeSAtt( LList^.Scripts );
		end;

		{Dispose of all resources and children attached to this GEAR.}
		if LList^.SA <> Nil then DisposeSAtt(LList^.SA);
		if LList^.NA <> Nil then DisposeNAtt(LList^.NA);

		DisposeGear( LList^.SubCom );
		DisposeGear( LList^.InvCom );

		{Dispose of the GEAR itself.}
		Dispose(LList);
		LList := LTemp;
	end;
end;

Procedure RemoveGear(var LList,LMember: GearPtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: GearPtr;
begin
	{Initialize A and B}
	B := LList;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		RecordError('ERROR- RemoveGear asked to remove a link that doesnt exist.');
	end else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		LList := B^.Next;
		B^.Next := Nil;
		DisposeGear(B);
		LMember := Nil;
	end else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		B^.next := Nil;
		DisposeGear(B);
		LMember := Nil;
	end;
end;

Procedure DelinkGear(var LList,LMember: GearPtr);
	{Locate and extract member LMember from list LList.}
var
	a,b: GearPtr;
begin
	{Initialize A and B}
	B := LList;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		RecordError('ERROR- DelinkGear asked to remove a link that doesnt exist.' + SAttValue( LList^.SA , 'NAME' ) + ' , ' + SAttValue( LMember^.SA , 'NAME' ));
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		LList := B^.Next;
		B^.Next := Nil;
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		B^.next := Nil;
	end;

	{ LMember has been delinked. Get rid of its parent, if it had one. }
	LMember^.Parent := Nil;
end;

function NumSiblingGears( GList: GearPtr ): Integer;
	{ Count the number of sibling gears along this track. }
var
	N: Integer;
begin
	N := 0;
	while GList <> Nil do begin
		Inc( N );
		GList := GList^.Next;
	end;
	NumSiblingGears := N;
end;

function SelectRandomGear( GList: GearPtr ): GearPtr;
	{ Pick one of the sibling gears from the provided }
	{ list at random. }
var
	ST: GearPtr;
	N,T: Integer;
begin
	{ Count the number of gears total. }
	N := NumSiblingGears( GList );

	{ Choose one randomly. }
	if N > 0 then begin
		T := Random( N ) + 1;
		ST := GList;
		N := 1;
		while N < T do begin
			Inc( N );
			St := St^.Next;
		end;
	end else begin
		ST := Nil;
	end;
	SelectRandomGear := ST;
end;


function FindRoot( Part: GearPtr ): GearPtr;
	{ Locate the master of PART. Return NIL if there is no master. }
begin
	{ Move the pointer up to either root level or the first Master parent. }
	while ( Part <> Nil ) and ( Part^.Parent <> Nil ) do Part := Part^.Parent;

	FindRoot := Part;
end;

Procedure InsertSubCom( Parent,NewMember: GearPtr );
	{ Insert the new gear NewMember as a child of Parent. }
begin
	if Parent^.SubCom = Nil then begin
		Parent^.SubCom := NewMember;
	end else begin
		LastGear(Parent^.SubCom)^.Next := NewMember;
	end;

	{ Set the parent value to the parent gear. Do this for every }
	{ item in the NewMember list. }
	while NewMember <> Nil do begin
		NewMember^.Parent := Parent;
		NewMember := NewMember^.Next;
	end;
end;

Procedure InsertInvCom( Parent,NewMember: GearPtr );
	{ Insert the new gear NewMember as a child of Parent. }
begin
	if Parent^.InvCom = Nil then begin
		Parent^.InvCom := NewMember;
	end else begin
		LastGear(Parent^.InvCom)^.Next := NewMember;
	end;

	{ Set the parent value to the parent gear. Do this for every }
	{ item in the NewMember list. }
	while NewMember <> Nil do begin
		NewMember^.Parent := Parent;
		NewMember := NewMember^.Next;
	end;
end;

Function CloneSAtt( SA: SAttPtr ): SAttPtr;
	{ Exactly copy a list of strings. }
var
	LList: SAttPtr;
begin
	LList := Nil;
	while SA <> Nil do begin
		StoreSAtt( LList , SA^.Info );
		SA := SA^.Next;
	end;
	CloneSAtt := LList;
end;

Procedure AppendStringList( Dest,AddThis: SAttPtr );
	{ Merge one list of strings into another. }
begin
	while AddThis <> Nil do begin
		StoreSAtt( Dest , AddThis^.Info );
		AddThis := AddThis^.Next;
	end;
end;


Function CloneGear( Part: GearPtr ): GearPtr;
	{ Create an exact copy of PART, including all attributes and }
	{ components. }
	{ Note that a cloned gear will not yet have its scripts activated... }
	Procedure XeroxGear( Master,Blank: GearPtr );
		{ Copy Master to Blank, ignoring the connective fields. }
	var
		NA: NAttPtr;
		T: Integer;
	begin
		{ Copy basic info. }
		Blank^.G := Master^.G;
		Blank^.S := Master^.S;
		Blank^.V := Master^.V;
		Blank^.Scale := Master^.Scale;

		{ Copy stats. }
		for T := 1 to NumGearStats do Blank^.Stat[t] := Master^.Stat[t];

		{ Copy attributes. }
		NA := Master^.NA;
		while NA <> Nil do begin
			SetNAtt( Blank^.NA , NA^.G , NA^.S , NA^.V );
			NA := NA^.Next;
		end;

		Blank^.SA := CloneSAtt( Master^.SA );
		Blank^.Scripts := CloneSAtt( Master^.Scripts );
	end;

	Function CloneTrack( Parent,Part: GearPtr ): GearPtr;
		{ Copy this gear and all its siblings. }
	var
		it,P2: GearPtr;
	begin
		it := Nil;

		while Part <> Nil do begin
			P2 := AddGear( it , Parent );
			XeroxGear( Part , P2 );
			P2^.SubCom := CloneTrack( P2 , Part^.SubCom );
			P2^.InvCom := CloneTrack( P2 , Part^.InvCom );
			Part := Part^.Next;
		end;

		CloneTrack := it;
	end;
var
	it: GearPtr;
begin
	if Part = Nil then exit( Nil );

	it := NewGear;
	XeroxGear( Part , it );
	it^.SubCom := CloneTrack( it , Part^.SubCom );
	it^.InvCom := CloneTrack( it , Part^.InvCom );
	CloneGear := it;
end;

Function InstantGear( Part: GearPtr ): GearPtr;
	{ Clones a gear and activates its scripts at the same time. }
var
	it: GearPtr;
begin
	it := CloneGear( Part );
	ActivateGearTree( Part );
	InstantGear := it;
end;

Function RetrieveGearSib( List: GearPtr; N: Integer ): GearPtr;
	{ Find the address of the Nth sibling gear in this list. }
	{ If no such gear exists, return Nil. }
begin
	{ error check- if asked to find a gear before the first one in }
	{ the list, obviously we can't do that. Return Nil. }
	if N < 1 then Exit( Nil );

	{ Search for the desired gear. }
	while ( N > 1 ) and ( List <> Nil ) do begin
		Dec( N );
		List := List^.Next;
	end;

	{ Return the last gear found. }
	RetrieveGearSib := List;
end;

Procedure Rescale( Part: GearPtr; SF: Integer );
	{ Alter the scale of this part and all its subcoms. }
var
	S: GearPtr;
begin
	Part^.Scale := SF;
	S := Part^.SubCom;
	while S <> Nil do begin
		Rescale( S , SF );
		S := S^.Next;
	end;
	S := Part^.InvCom;
	while S <> Nil do begin
		Rescale( S , SF );
		S := S^.Next;
	end;
end;


Function IsFoundAlongTrack( Track,Part: GearPtr ): Boolean;
	{ Return TRUE if PART is found as a sibling component somewhere }
	{ along TRACK, or FALSE if it cannot be found. }
var
	it: Boolean;
begin
	it := False;

	While Track <> Nil do begin
		if Track = Part then it := True;
		Track := Track^.Next;
	end;

	IsFoundAlongTrack := it;
end;

Function IsSubCom( Part: GearPtr ): Boolean;
	{ Return TRUE if PART is a subcomponent of its parent, FALSE otherwise. }
begin
	{ First an error check- if PART doesn't exist, or if it is at root }
	{ level, it can't be a subcom. }
	if ( Part = Nil ) or ( Part^.Parent = Nil ) then begin
		IsSubCom := False;
	end else begin
		IsSubCom := IsFoundAlongTrack( Part^.Parent^.SubCom , Part );
	end;
end;

Function IsInvCom( Part: GearPtr ): Boolean;
	{ Return TRUE if PART is an invcomponent of its parent, FALSE otherwise. }
begin
	{ First an error check- if PART doesn't exist, or if it is at root }
	{ level, it can't be an invcom. }
	if ( Part = Nil ) or ( Part^.Parent = Nil ) then begin
		IsInvCom := False;
	end else begin
		IsInvCom := IsFoundAlongTrack( Part^.Parent^.InvCom , Part );
	end;
end;

Procedure MarkGearsWithNAtt( Master: GearPtr; G,S,V: LongInt );
	{ Mark all the gears in this tree with the provided NAtt. }
	Procedure DoAlongPath( LList: GearPtr );
		{ Mark the NAtt along this list, and along all children. }
	begin
		while LList <> Nil do begin
			SetNAtt( LList^.NA , G , S , V );
			DoAlongPath( LList^.SubCom );
			DoAlongPath( LList^.InvCom );
			LList := LList^.Next;
		end;
	end;
begin
	SetNAtt( Master^.NA , G , S , V );
	DoAlongPath( Master^.SubCom );
	DoAlongPath( Master^.InvCom );
end;

Procedure MarkGearsWithSAtt( Master: GearPtr; const Info: String );
	{ Mark all the gears in this tree with the provided SAtt. }
	Procedure DoAlongPath( LList: GearPtr );
		{ Mark the SAtt along this list, and along all children. }
	begin
		while LList <> Nil do begin
			SetSAtt( LList^.SA , Info );
			DoAlongPath( LList^.SubCom );
			DoAlongPath( LList^.InvCom );
			LList := LList^.Next;
		end;
	end;
begin
	SetSAtt( Master^.SA , Info );
	DoAlongPath( Master^.SubCom );
	DoAlongPath( Master^.InvCom );
end;

Procedure WriteCGears( var F: Text; G: GearPtr );
	{ This procedure writes to file F a compacted list of gears. }
	{ Hopefully, it will be an efficient procedure, saving }
	{ only as much data as is needed. }
	Procedure ExportLuaVars( Part: GearPtr );
		{ We are going to export the Lua varaibles associated with }
		{ the gear. To do that, we're going to have to call a Lua }
		{ function and then export the string we get back. }
	var
		MyScript: String;
	begin
		if Lua_is_Go then begin
			lua_getglobal( MyLua , 'gh_exportvars' );
			lua_pushlightuserdata( MyLua , Pointer( Part ) );
			if lua_pcall( MyLua , 1 , 1 , 0 ) <> 0 then RecordError( 'ExportLuaVars ERROR: ' + lua_tostring( MyLua , -1 ) )
			else begin
				MyScript := lua_tostring( MyLua , -1 );
				if MyScript <> '' then writeln( F , MyScript );
			end;
			{ Get rid of the boolean or error message now on the stack. }
			lua_settop( MyLua , 0 );
		end else begin
			RecordError( 'Register ERROR: Cannot register variables before LUA_IS_GO' );
		end;
	end;
var
	msg: String;	{ A single line for the save file. }
	T: Integer;
	NA: NAttPtr;	{ Numeric Attribute pointer }
	SA: SAttPtr;	{ String Attribute pointer }
begin
	while G <> Nil do begin
		{ Write the proceed value here. }
		{ Record G , S , V , and Scale. }
		msg := BStr( SaveFileContinue ) + ' ' + BStr( G^.G ) + ' ' + BStr( G^.S ) + ' ' + BStr( G^.V ) + ' ' + BStr( G^.Scale );
		writeln( F , msg );

		{ Export a single line to record any stats this gear has }
		{ which differ from the default values. }
		msg := 'Stats ';
		for t := 1 to NumGearStats do begin
			if G^.Stat[T] <> 0 then msg := msg + BStr( T ) + ' ' + BStr( G^.Stat[T] ) + ' ';
		end;
		writeln( F , msg );

		{ Export Numeric Attributes }
		NA := G^.NA;
		while NA <> Nil do begin
			msg := BStr( SaveFileContinue ) + ' ' + BStr( NA^.G ) + ' ' + BStr( NA^.S ) + ' ' + BStr( NA^.V );
			writeln( F , msg );
			NA := NA^.Next;
		end;
		{ Write the sentinel line here. }
		writeln( F , SaveFileSentinel );

		{ Export String Attributes }
		SA := G^.SA;
		while SA <> Nil do begin
			{ Error check- only output valid string attributes. }
			if Pos('<',SA^.Info) > 0 then writeln( F , SA^.Info );
			SA := SA^.Next;
		end;
		{ Write the sentinel line here. }
		writeln( F , 'Z' );

		{ Export Scripts }
		SA := G^.Scripts;
		while SA <> Nil do begin
			{ Error check- only output valid string attributes. }
			{ Remember that we tack on a carriage return to the end of each line, so }
			{ you don't need to save that to the file. }
			if Length( SA^.Info ) > 1 then writeln( F , Copy( SA^.Info , 1 , Length( SA^.Info ) - 1 ) );
			SA := SA^.Next;
		end;
		{ Write the sentinel line here. }
		writeln( F , 'ZZZ' );
		{ If appropriate, export script variables. }
		ExportLuaVars( G );
		{ Write another sentinel. }
		writeln( F , 'ZZZ' );


		{ Export the subcomponents and invcomponents of this gear. }
		WriteCGears( F , G^.InvCom );
		WriteCGears( F , G^.SubCom );

		{ Move to the next gear in the list. }
		G := G^.Next;
	end;

	{ Write the sentinel line here. }
	writeln( F , SaveFileSentinel );
end;

Function ReadCGears( var F: Text ): GearPtr;
	{ Read a series of gears which have been saved by the SaveGears }
	{ procedure. The 'C' means Compact. }

	Function ReadNumericAttributes( var it: NAttPtr ): NAttPtr;
		{ Read some numeric attributes from the file. }
	var
		N,G,S: Integer;
		V: LongInt;
		TheLine: String;
	begin
		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ Extract the action code. }
			N := ExtractValue( TheLine );

			{ If this action code implies that there's a gear }
			{ to load, get to work. }
			if N = SaveFileContinue then begin
				{ Read the specific values of this NAtt. }
				G := ExtractValue( TheLine );
				S := ExtractValue( TheLine );
				V := ExtractValue( TheLine );
				SetNAtt( it , G , S , V );
			end;
		until ( N = SaveFileSentinel ) or EoF( F );

		ReadNumericAttributes := it;
	end;

	Function ReadStringAttributes( var it: SAttPtr ): SAttPtr;
		{ Read some string attributes from the file. }
	var
		TheLine: String;
	begin
		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ If this is a valid string attribute, file it. }
			if Pos('<',TheLine) > 0 then begin
				SetSAtt( it , TheLine );
			end;
		until ( Pos('<',TheLine) = 0 ) or EoF( F );

		ReadStringAttributes := it;
	end;


	Function ReadLuaScripts( var it: SAttPtr ): SAttPtr;
		{ Read some string attributes from the file. }
	var
		TheLine: String;
	begin
		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ If this is a valid string attribute, file it. }
			if TheLine = 'ZZZ' then begin
				Break;
			end else if Length( TheLine ) > 0 then begin
				{ Remember to add a carriage return to the end of each }
				{ line. Or is that a linefeed? Don't matter. }
				StoreSAtt( it , TheLine + #10 );
			end;
		until EoF( F );

		ReadLuaScripts := it;
	end;
	Procedure ReadLuaVars( Part: GearPtr );
		{ We have a second block of Lua code to read: The variable }
		{ initialization. Read it and run it. }
	var
		script: SAttPtr;
	begin
		script := nil;
		ReadLuaScripts( script );
		if script <> Nil then begin
			if Lua_is_Go then begin
				lua_getglobal( MyLua , 'gh_readvars' );
				lua_pushlightuserdata( MyLua , Pointer( Part ) );
				LoadSAttScripts( script );
				if lua_pcall( MyLua , 2 , 0 , 0 ) <> 0 then RecordError( 'ReadLuaVars ERROR: ' + lua_tostring( MyLua , -1 ) );
			end else begin
				RecordError( 'Register ERROR: Cannot register variables before LUA_IS_GO' );
			end;

			DisposeSAtt( script );
		end;
	end;

	Function REALReadGears( Parent: GearPtr ): GearPtr;
		{ This is the workhorse procedure. It's the part that }
		{ actually does the reading from disk. }
	var
		it,Part: GearPtr;
		TheLine: String; { The info is read one text line at a time. }
		N,G,S,V,Sc: Integer;
	begin
		{ Initialize our gear list to NIL. }
		it := Nil;

		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ Extract the action code. }
			N := ExtractValue( TheLine );

			{ If this action code implies that there's a gear }
			{ to load, get to work. }
			if N = SaveFileContinue then begin
				{ Extract the remaining values from the line. }

				G := ExtractValue( TheLine );
				S := ExtractValue( TheLine );
				V := ExtractValue( TheLine );
				Sc := ExtractValue( TheLine );

				{ Add a new gear to the list, and initialize it. }
				Part := AddGear( it , Parent );
				Part^.G := G;
				Part^.S := S;
				Part^.V := V;
				Part^.Scale := Sc;

				{ Read the stats line, and save it for now. }
				readln( F , TheLine );

				{ Remove the STATS tag }
				ExtractWord( TheLine );
				{ Keep processing until we run out of string. }
				while TheLine <> '' do begin
					{ Determine what stat to adjust. }
					G := ExtractValue( TheLine );
					V := ExtractValue( TheLine );
					{ If this is a legal stat, adjust it. Otherwise, ignore. }
					if ( G > 0 ) and ( G <= NumGearStats ) then begin
						Part^.Stat[G] := V;
					end;
				end;

				{ Read Numeric Attributes }
				ReadNumericAttributes( Part^.NA );

				{ Read String Attributes and Scripts }
				ReadStringAttributes( Part^.SA );
				ReadLuaScripts( Part^.Scripts );

				{ Register the scripts. }
				ActivateGearScript( Part );

				{ Read the variable initialization. }
				ReadLuaVars( Part );

				{ Read InvComs }
				Part^.InvCom := RealReadGears( Part );

				{ Read SubComs }
				Part^.SubCom := RealReadGears( Part );
			end;

		until ( N = SaveFileSentinel ) or EoF( F );

		RealReadGears := it;
	end;

begin
	{ Call the real procedure with a PARENT value of Nil. }
	ReadCGears := REALReadGears( Nil );
end;

Function LocateGearByIndex( Master: GearPtr; Num: Integer ): GearPtr;
	{ Locate the Nth part in the tree. }
var
	N: Integer;
	TheGearWeWant: GearPtr;
{ PROCEDURES BLOCK. }
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while ( Part <> Nil ) and ( TheGearWeWant = Nil ) do begin
			Inc(N);
			if N = Num then TheGearWeWant := Part;
			if TheGearWeWant = Nil then CheckAlongPath( Part^.InvCom );
			if TheGearWeWant = Nil then CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	TheGearWeWant := Nil;
	N := 0;

	{ Part 0 is the master gear itself. }
	if Num < 1 then Exit( Master );

	CheckAlongPath( Master^.InvCom );
	if TheGearWeWant = Nil then CheckAlongPath( Master^.SubCom );

	LocateGearByIndex := TheGearWeWant;
end; { LocateGearByNumber }

Function FindGearIndex( Master , FindThis: GearPtr ): Integer;
	{ Search through master looking for FINDTHIS. }
	{ Once found, return its index number. Return -1 if it }
	{ cannot be found. }
var
	N,it: Integer;
{ PROCEDURES BLOCK }
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while ( Part <> Nil ) and ( it = -1 ) do begin
			Inc(N);
			if ( Part = FindThis ) then it := N;
			CheckAlongPath( Part^.InvCom );
			CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	N := 0;
	it := -1;
	if Master = FindThis then it := 0;
	CheckAlongPath( Master^.InvCom );
	CheckAlongPath( Master^.SubCom );
	FindGearIndex := it;
end; { FindGearIndex }

function SeekGearByDesig( LList: GearPtr; Name: String ): GearPtr;
	{ Seek a gear with the provided designation. If no such gear is }
	{ found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	Name := UpCase( Name );
	while LList <> Nil do begin
		if UpCase( SAttValue( LList^.SA , 'DESIG' ) ) = Name then it := LList;
		if ( it = Nil ) then it := SeekGearByDesig( LList^.SubCom , Name );
		if ( it = Nil ) then it := SeekGearByDesig( LList^.InvCom , Name );
		LList := LList^.Next;
	end;
	SeekGearByDesig := it;
end;

Function CreateComponentList( MasterList: GearPtr; const Context: String ): NAttPtr;
	{ Create a list of components to be used by SELECTCOMPONENTFROMLIST below. }
	{ The list will be of the form G:0 S:[Component Index] V:[Match Weight]. }
var
	C: GearPtr;	{ A component. }
	N: Integer;	{ A counter. }
	MW: Integer;	{ The match-weight of the current component. }
	ShoppingList: NAttPtr;	{ The list of legal components. }
begin
	{ Initialize all the values. }
	ShoppingList := Nil;
	C := MasterList;
	N := 1;

	{ Go through the list, adding everything that matches. }
	while C <> Nil do begin
		MW := StringMatchWeight( Context , SAttValue( C^.SA , 'REQUIRES' ) );
		if MW > 0 then begin
			SetNAtt( ShoppingList , 0 , N , MW );
		end;

		Inc( N );
		C := C^.Next;
	end;

	CreateComponentList := ShoppingList;
end;

Function RandomComponentListEntry( ShoppingList: NAttPtr ): NAttPtr;
	{ We've been handed a shopping list. Select one of the elements from this }
	{ list randomly based on the weight of the V values. }
var
	N: Integer;
	C,It: NAttPtr;
begin
	{ Error check- no point in working with an empty list. }
	if ShoppingList = Nil then Exit( Nil );

	{ Step one- count the number of matching plots. }
	C := ShoppingList;
	N := 0;
	while C <> Nil do begin
		N := N + C^.V;
		C := C^.Next;
	end;

	{ Pick one of the matches at random. }
	C := ShoppingList;
	N := Random( N );
	it := Nil;
	while ( C <> Nil ) and ( it = Nil ) do begin
		N := N - C^.V;
		if ( N < 0 ) and ( it = Nil ) then it := C;
		C := C^.Next;
	end;

	{ Return the entry we found. }
	RandomComponentListEntry := it;
end;

Function SelectComponentFromList( MasterList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;
	{ Given a list of numeric attributes holding the selection weights of all legal }
	{ components from MasterList, select one of those components and return a pointer }
	{ to its entry in MasterList. }
	{ Afterwards remove the selected component's entry from the shopping list. }
var
	N: Integer;
	It: NAttPtr;
begin
	{ Error check- no point in working with an empty list. }
	if ShoppingList = Nil then Exit( Nil );

	{ Step one- pick an entry. }
	it := RandomComponentListEntry( ShoppingList );

	{ Remove IT from the list, and return the gear it points to. }
	{ Store the index before deleting IT. }
	N := it^.S;
	RemoveNAtt( ShoppingList , it );
	SelectComponentFromList := RetrieveGearSib( MasterList , N );
end;

function SeekGearByIDTag( LList: GearPtr; G,S,V: LongInt ): GearPtr;
	{ Seek a gear which posesses a NAtt with the listed G,S,V score. }
var
	it: GearPtr;
begin
	it := Nil;
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if NAttValue( LList^.NA , G , S ) = V then it := LList;
		if ( it = Nil ) then it := SeekGearByIDTag( LList^.SubCom , G , S , V );
		if ( it = Nil ) then it := SeekGearByIDTag( LList^.InvCom , G , S , V );
		LList := LList^.Next;
	end;
	SeekGearByIDTag := it;
end;

Procedure LoadLuaConstants;
	{ Attempt to load the constants into Lua. This is the same include file }
	{ as that used in compiling the program. }
var
	CF: SAttPtr;
begin
	CF := LoadStringList( 'gamedata/gh_constants.txt' );
	if CF <> Nil then begin
		LoadSAttScripts( CF );
		if lua_pcall( MyLua , 0 , 0 , 0 ) <> 0 then RecordError( 'LoadLuaConstants ERROR: ' + lua_tostring( MyLua , -1 ) );
		DisposeSAtt( CF );
	end else begin
		RecordError( 'LoadLuaConstants ERROR: Constants file not found.' );
	end;
end;

Procedure ErrorDump;
	{ Dump the errors to StdOut. }
var
	E: SAttPtr;
begin
	E := MyErrors;
	while E <> Nil do begin
		writeln( E^.Info );
		E := E^.Next;
	end;
end;

initialization
	MyErrors := Nil;
	MyLua := lua_open;
	luaL_openlibs( MyLua );

	LoadLuaConstants;


finalization
	if MyErrors <> Nil then begin
		SaveStringList( 'errors.txt' , MyErrors );
{$IFDEF LINUX}
		ErrorDump;
{$ENDIF}
		DisposeSAtt( MyErrors );
	end;
	lua_close( MyLua );
end.
