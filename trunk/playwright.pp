unit playwright;
	{ This unit handles the insertion of random plots. }
	{ It has a lot of procedures for selecting random elements from the }
	{ adventure based on criteria provided by the plot to be inserted. }
{
	GearHead2, a roguelike mecha CRPG
	Copyright (C) 2005 Joseph Hewitt

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

interface

uses gears,locale;

	{ G = GG_Plot                            }
	{ S = ID Number (not nessecarily unique) }
	{ v0.240 - Elements are stored as numeric attributes }

const
	GS_XRanStory = 1;

var
	persona_fragments: GearPtr;
	Standard_XXRan_Components: GearPtr;


Procedure BuildMegalist( Dest: GearPtr; AddOn: SAttPtr );


Function SceneDesc( Scene: GearPtr ): String;

Function NumFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
Function FindFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; Num: Integer ): GearPtr;

Function SearchForScene( Adventure , Plot: GearPtr; GB: GameBoardPtr; Desc: String ): GearPtr;


Procedure AddGearXRContext( GB: GameBoardPtr; Adv,Part: GearPtr; var Context: String; palette_entry_code: Char );
Procedure AddElementContext( GB: GameBoardPtr; Story: GearPtr; var Context: String; palette_entry_code: Char; Element_Num: Integer );
Function StoryContext( GB: GameBoardPtr; Story: GearPtr ): String;

Function SeekUrbanArea( RootScene: GearPtr ): GearPtr;
Procedure InsertPFrags( Plot,Persona: GearPtr; const Context: String; ID: Integer );
Procedure PrepAllPersonas( Adventure,Plot: GearPtr; GB: GameBoardPtr; MinID: Integer );
Procedure PrepMetaScenes( Adventure,Plot: GearPtr; GB: GameBoardPtr );

Function PersonalContext( Adv,NPC: GearPtr ): String;
Function DifficulcyContext( Threat: Integer ): String;

Function InsertStory( Slot,Story: GearPtr; GB: GameBoardPtr ): Boolean;
Function InsertSubPlot( Slot,SubPlot: GearPtr; GB: GameBoardPtr ): Boolean;
Function InsertPlot( Slot,Plot: GearPtr; GB: GameBoardPtr ): Boolean;

Function InsertGlobalArc( Adventure,ARC: GearPtr; GB: GameBoardPtr ): Boolean;
Function InsertStoryArc( Story,Arc: GearPtr; GB: GameBoardPtr ): Boolean;
Function InsertRSC( Source,Frag: GearPtr; GB: GameBoardPtr ): Boolean;
Procedure AdvancePlot( GB: GameBoardPtr; Adv,Plot: GearPtr; N: Integer );

Procedure PrepareNewComponent( Story: GearPtr; GB: GameBoardPtr );

Function PrepareQuestFragment( City,Frag: GearPtr; DoDebug: Boolean ): Boolean;
Function InsertArenaMission( Source,Mission: GearPtr ): Boolean;


implementation

{$IFDEF ASCII}
uses 	ui4gh,rpgdice,vidgfx,texutil,gearutil,interact,ability,gearparser,ghchars,narration,ghprop,
	vidmenus,arenascript,mpbuilder;
{$ELSE}
uses 	ui4gh,rpgdice,glgfx,texutil,gearutil,interact,ability,gearparser,ghchars,narration,ghprop,
	glmenus,arenascript,mpbuilder;
{$ENDIF}

var
	Fast_Seek_Element: Array [0..1,1..Num_Plot_Elements] of GearPtr;

Procedure BuildMegalist( Dest: GearPtr; AddOn: SAttPtr );
	{ Combine the scripts listed in ADDON into LLIST. }
	{ If a script with the same label already exists in LLIST, the new }
	{ script from ADDON supercedes it, while the old script gets moved to }
	{ a new label. }
var
	SPop,Key,Current: String;
	SPopSA: SAttPtr;
begin
	SPop := 'na';
	while AddOn <> Nil do begin
		{ If there's currently a SAtt in the megalist with this }
		{ key, it has to be "pushed" to a new position. }
		Key := UpCase( RetrieveAPreamble( AddOn^.Info ) );
		if ( Key <> 'REQUIRES' ) and ( Key <> 'DESC' ) and ( Key <> 'DESIG' ) and ( Key <> 'SPECIAL' )
					 and not ( HeadMatchesString( 'ELEMENT' , Key ) or HeadMatchesString( 'TEAM' , Key ) or HeadMatchesString( 'CONTENT' , Key ) or HeadMatchesString( 'CONTEXT' , Key )
					 or HeadMatchesString( 'MINIMAP' , Key ) or HeadMatchesString( 'QUEST' , Key ) or HeadMatchesString( 'SCENE' , Key ) or HeadMatchesString( 'NAME' , Key )
					 or HeadMatchesString( 'PLACE' , Key ) ) then begin
			Current := AS_GetString( Dest , Key );

			if Current <> '' then begin
				SPopSA := AddSAtt( Dest^.SA , Key , Current );
				SPop := RetrieveAPreamble( SPopSA^.Info );
			end;

			ReplacePat( AddOn^.Info , '%pop%' , SPop );
			SetSAtt( Dest^.SA , AddOn^.Info );
		end;

		AddOn := AddOn^.Next;
	end;
end;

Function FilterElementDescription( var IDesc: String ): String;
	{ Given this element description, break it up into the }
	{ intrinsic and relative description strings. }
	{ Note that the tag "NEVERFAIL" is edited out at this stage. }
var
	ZeroDesc,cmd,RDesc: String;
begin
	ZeroDesc := IDesc;
	RDesc := '';
	IDesc := '';

	while ZeroDesc <> '' do begin
		cmd := ExtractWord( ZeroDesc );

		if cmd[1] = '!' then begin
			RDesc := RDesc + ' ' + cmd;

			{ If this relative command requires a value, }
			{ copy that over as well. }
			{ The two that don't are !Global and !Lancemate. }
			if ( UpCase( cmd )[2] <> 'G' ) and ( UpCase( cmd )[2] <> 'L' ) then begin
				cmd := ExtractWord( ZeroDesc );
				RDesc := RDesc + ' ' + cmd;
			end;

		end else if UpCase( cmd ) <> 'NEVERFAIL' then begin
			IDesc := IDesc + ' ' + cmd;

		end;

	end;

	FilterElementDescription := RDesc;
end;

Function GetFSE( N: Integer ): GearPtr;
	{ Get the FastSeekElement requested. }
begin
	if N > 0 then begin
		GetFSE := Fast_Seek_Element[ 1 , N ]
	end else begin
		GetFSE := Fast_Seek_Element[ 0 , Abs( N ) ];
	end;
end;

Function GetFSEID( Story , Plot: GearPtr; N: Integer ): Integer;
	{ Return the ID of the FSE listed. }
begin
	if N > 0 then begin
		GetFSEID := ElementID( Plot , N );
	end else if Story <> Nil then begin
		GetFSEID := ElementID( Story , N );
	end else begin
		GetFSEID := 0;
	end;
end;

Function PWAreEnemies( Adv, Part: GearPtr; N: Integer ): Boolean;
	{ Return TRUE if the faction of element N is an enemy of the }
	{ faction of PART. }
var
	Fac: GearPtr;
	F0,F1: Integer;
begin
	F0 := GetFactionID( GetFSE( N ) );
	F1 := GetFactionID( Part );

	{ A faction is never its own enemy. }
	if F0 = F1 then Exit( False );

	Fac := SeekFaction( Adv , F1 );

	if Fac <> Nil then begin
		PWAreEnemies := NAttValue( Fac^.NA , NAG_FactionScore , F0 ) < 0;
	end else begin
		PWAreEnemies := False;
	end;
end;

Function PWAreAllies( Adv, Part: GearPtr; N: Integer ): Boolean;
	{ Return TRUE if the faction of element N is an ally of the }
	{ faction of PART. }
var
	Fac: GearPtr;
	F0,F1: Integer;
begin
	F0 := GetFactionID( GetFSE( N ) );
	F1 := GetFactionID( Part );

	{ A faction is always allied with itself. }
	if F0 = F1 then Exit( True );

	Fac := SeekFaction( Adv , F1 );

	if Fac <> Nil then begin
		PWAreAllies := NAttValue( Fac^.NA , NAG_FactionScore , F0 ) > 0;
	end else begin
		PWAreAllies := False;
	end;
end;

Function PartMatchesRelativeCriteria( Adv,Plot,Part: GearPtr; GB: GameBoardPtr; Desc: String ): Boolean;
	{ Return TRUE if the part matches the relative criteria }
	{ provided, or FALSE if it does not. }
var
	it: Boolean;
	cmd: String;
	Q: Char;
begin
	{ Assume TRUE unless shown otherwise. }
	it := True;

	{ Lancemates can only be selected if they're asked for by the plot. }
	if AStringHasBString( Desc , '!LANCEMATE' ) then it := ( Part^.G = GG_Character ) and ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam )
	else it := ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam );

	{ Check all the bits in the description string. }
	While ( Desc <> '' ) and it do begin
		Cmd := ExtractWord( Desc );
		if Cmd <> '' then begin
			DeleteFirstChar( cmd );
			Q := UpCase( cmd )[ 1 ];

			if ( Q = 'N' ) and ( Plot <> Nil ) then begin
				{ L1 must equal L2. }
				it := it and ( FindRootScene( GB , FindActualScene( GB , FindGearScene( Part , GB ) ) ) = FindRootScene( GB , FindActualScene( GB , FindGearScene( GetFSE( ExtractValue( Desc ) ) , GB ) ) ) );

			end else if ( Q = 'F' ) and ( Plot <> Nil ) then begin
				{ L1 must not equal L2. }
				it := it and ( FindRootScene( GB , FindActualScene( GB , FindGearScene( Part , GB ) ) ) <> FindRootScene( GB , FindActualScene( GB , FindGearScene( GetFSE( ExtractValue( Desc ) ) , GB ) ) ) );

			end else if Q = 'M' then begin
				{ MEMBER. This part must belong to the }
				{ requested faction. }
				it := it and ( GetFactionID( Part ) = ExtractValue( Desc ) );

			end else if ( Q = 'C' ) and ( Plot <> Nil ) then begin
				{ COMRADE. This part must belong to the }
				{ same faction as the requested element. }
				it := it and ( GetFactionID( GetFSE( ExtractValue( Desc ) ) ) = GetFactionID( Part ) );

			end else if ( Q = 'X' ) and ( Plot <> Nil ) then begin
				{ eXclude. This part must not be an ally }
				{ of the faction of the requested element. }
				it := it and ( not PWAreAllies( Adv, Part , ExtractValue( Desc ) ) );

			end else if ( Q = 'O' ) and ( Plot <> Nil ) then begin
				{ Okay. This part must not be an enemy }
				{ of the faction of the requested element. }
				it := it and ( not PWAreEnemies( Adv, Part , ExtractValue( Desc ) ) );

			end else if ( Q = 'A' ) and ( Plot <> Nil ) then begin
				{ eXclude. This part must not be an ally }
				{ of the faction of the requested element. }
				it := it and PWAreAllies( Adv, Part , ExtractValue( Desc ) );

			end else if ( Q = 'E' ) and ( Plot <> Nil ) then begin
				{ ENEMY. The faction of the requested }
				{ element must be hated by this part's }
				{ faction. }
				it := it and PWAreEnemies( Adv, Part , ExtractValue( Desc ) );

			end;
		end;
	end;

	{ Return the result. }
	PartMatchesRelativeCriteria := it;
end;

Function NPCMatchesDesc( Adv,Plot,NPC: GearPtr; IDesc,RDesc: String; GB: GameBoardPtr ): Boolean;
	{ Return TRUE if the supplied NPC matches this description }
	{ string, FALSE otherwise. Note that an extra check is performed }
	{ to prevent animals from being chosen for plots, which could }
	{ otherwise happen if the animal in question has a Character ID. }
	{ Thank you Fluffy the Stegosaurus. }
var
	it: Boolean;
begin
	{ DESC should contain a string list of all the stuff we want }
	{ our NPC to have. Things like gender, personality traits, }
	{ et cetera. Most of these things are intrinsic to the NPC, }
	{ but some of them are defined relative to other elements of }
	{ this plot. }

	it := PartMatchesCriteria( XNPCDesc( Adv , NPC ) , IDesc );
	if it then it := PartMatchesRelativeCriteria( Adv, Plot, NPC, GB, RDesc );

	NPCMatchesDesc := it and NotAnAnimal( NPC );
end;

Function NumFreeNPC( Adv, Plot: GearPtr; Desc: String; GB: GameBoardPtr ): Integer;
	{ This function will count the number of CHARACTER gears }
	{ present in ADVENTURE which have a CID, which match the DESC, }
	{ and which are not currently involved in a plot. }
var
	IDesc,RDesc: String;
	Total: Integer;
	Function CheckAlongPath( P: GearPtr ): Integer;
	var
		CID: LongInt;
		N: Integer;
	begin
		N := 0;
		while P <> Nil do begin
			if ( P^.G = GG_Character ) and NPCMatchesDesc( Adv, Plot, P , IDesc , RDesc , GB ) then begin
				{ Next, check to make sure it has an assigned CID. }
				CID := NAttValue( P^.NA , NAG_Personal , NAS_CID );
				if ( CID <> 0 ) then Inc( N );
			end;
			N := N + CheckAlongPath( P^.SubCom );
			if P^.G <> GG_MetaScene then N := N + CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
		CheckAlongPath := N;
	end;
begin
	{ Initialize the total to 0. }
	Adv := FindRoot( Adv );

	{ Filter the relative description from the instrinsic description. }
	IDesc := Desc;
	RDesc := FilterElementDescription( IDesc );

	Total := CheckAlongPath( Adv^.SubCom );

	{ Check the invcomponents of the adventure only if global }
	{ NPCs are allowed by the DESC string. }
	if AStringHasBString( RDesc , '!G' ) then begin
		Total := Total + CheckAlongPath( Adv^.InvCom );
	end;
	if GB <> Nil then begin
		Total := Total + CheckAlongPath( GB^.Meks );
	end;

	{ Return the value. }
	NumFreeNPC := Total;
end;

Function FindFreeNPC( Adventure,Plot: GearPtr; Desc: String; Num: Integer; GB: GameBoardPtr ): GearPtr;
	{ Locate the Nth free NPC in the tree. }
var
	CID,N: Integer;
	RDesc: String;
	TheGearWeWant: GearPtr;
{ PROCEDURES BLOCK. }
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while ( Part <> Nil ) and ( TheGearWeWant = Nil ) do begin
			{ Increment N if this gear matches our description. }
			if ( Part^.G = GG_Character ) and NPCMatchesDesc( Adventure, Plot, Part , Desc , RDesc , GB ) then begin
				{ Next, check to make sure it has an assigned CID. }
				CID := NAttValue( Part^.NA , NAG_Personal , NAS_CID );
				if ( CID <> 0 ) then Inc( N );
			end;

			if N = Num then TheGearWeWant := Part;
			if ( TheGearWeWant = Nil ) and ( Part^.G <> GG_MetaScene ) then CheckAlongPath( Part^.InvCom );
			if TheGearWeWant = Nil then CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	TheGearWeWant := Nil;
	N := 0;

	{ Filter the description into relative and intrinsic bits. }
	RDesc := FilterElementDescription( Desc );

	{ Part 0 is the master gear itself. }
	if Num < 1 then Exit( Adventure );

	{ Check the invcomponents of the adventure only if global }
	{ NPCs are allowed by the DESC string. }
	if AStringHasBString( RDesc , '!G' ) then begin
		CheckAlongPath( Adventure^.InvCom );
	end;
	if TheGearWeWant = Nil then CheckAlongPath( Adventure^.SubCom );
	if TheGearWeWant = Nil then CheckAlongPath( GB^.Meks );

	FindFreeNPC := TheGearWeWant;
end; { FindFreeNPC }

Function CharacterSearch(Adv, Plot: GearPtr; Desc: String; GB: GameBoardPtr ): GearPtr;
	{ Search high and low looking for a character that matches }
	{ the provided search description! }
var
	NPC: GearPtr;
	NumMatches: Integer;
begin
	NumMatches := NumFreeNPC( Adv , Plot , Desc , GB );
	if NumMatches > 0 then begin
		{ Pick one of the free NPCs at random. }
		NPC := FindFreeNPC( Adv , Plot , Desc , Random( NumMatches ) + 1 , GB );
	end else begin
		{ No free NPCs were found. Bummer. }
		NPC := Nil;
	end;
	CharacterSearch := NPC;
end; { Character Search }


Function SceneDesc( Scene: GearPtr ): String;
	{ Create a description string for this scene. }
var
	it: String;
begin
	if ( Scene = Nil ) or not IsAScene( Scene ) then begin
		it := '';
	end else begin
		it := SAttValue( Scene^.SA , 'TYPE' ) + ' ' + SAttValue( Scene^.SA , 'CONTEXT' ) + ' SCALE' + BStr( Scene^.V );
	end;
	SceneDesc := QuoteString( it );
end;

Function NumFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
	{ Find out how many scenes match the provided description. }
var
	RDesc: String;
	Function CheckAlongPath( P: GearPtr ): Integer;
	var
		N: Integer;
	begin
		N := 0;
		while P <> Nil do begin
			if ( P^.G = GG_Scene ) and PartMatchesCriteria( SceneDesc( P ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, P, GB, RDesc ) then begin
				Inc( N );
			end;
			N := N + CheckAlongPath( P^.SubCom );
			P := P^.Next;
		end;
		CheckAlongPath := N;
	end;
begin
	RDesc := FilterElementDescription( Desc );

	if ( Adventure^.G = GG_Scene ) and PartMatchesCriteria( SceneDesc( Adventure ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Adventure, GB, RDesc ) then begin
		NumFreeScene := CheckAlongPath( Adventure^.SubCom ) + 1;
	end else begin
		NumFreeScene := CheckAlongPath( Adventure^.SubCom );
	end;
end;

Function FindFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; Num: Integer ): GearPtr;
	{ Find the NUM'th scene that matches the provided description. }
var
	S2: GearPtr;
	RDesc: String;
{ PROCEDURES BLOCK. }
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while ( Part <> Nil ) and ( S2 = Nil ) do begin
			{ Decrement N if this gear matches our description. }
			if ( Part^.G = GG_Scene ) and PartMatchesCriteria( SceneDesc( Part ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Part, GB, RDesc ) then begin
				Dec( Num );

				if Num = 0 then S2 := Part;
			end;

			if Num > 0 then CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	S2 := Nil;
	RDesc := FilterElementDescription( Desc );

	if ( Adventure^.G = GG_Scene ) and PartMatchesCriteria( SceneDesc( Adventure ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Adventure, GB, RDesc ) then begin
		if Num = 1 then begin
			S2 := Adventure;
		end else begin
			Dec( Num );
			CheckAlongPath( Adventure^.SubCom );
		end;
	end else begin
		CheckAlongPath( Adventure^.SubCom );
	end;

	FindFreeScene := S2;
end;

Function SearchForScene( Adventure , Plot: GearPtr; GB: GameBoardPtr; Desc: String ): GearPtr;
	{ Try to find a scene matching the description. }
var
	NumElements: Integer;
begin
	NumElements := NumFreeScene( Adventure , Plot , GB , Desc );
	if NumElements > 0 then begin
		{ Pick one of the free scenes at random. }
		SearchForScene := FindFreeScene( Adventure , Plot , GB , Desc , Random( NumElements ) + 1 );
	end else begin
		SearchForScene := Nil;
	end;
end;

Function NumFreeEntryPoints( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
	{ Find out how many scenes match the provided description. }
var
	RDesc: String;
	Function CheckAlongPath( P: GearPtr ): Integer;
	var
		N: Integer;
	begin
		N := 0;
		while P <> Nil do begin
			if ( P^.G = GG_MetaTerrain ) and ( P^.S <> GS_MetaEncounter ) and ( P^.Stat[ STAT_Destination ] < 0 ) and PartMatchesCriteria( SAttValue( P^.SA , 'REQUIRES' ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, P, GB, RDesc ) then begin
				if MetaSceneNotInUse( Adventure , P^.Stat[ STAT_Destination ] ) then Inc( N );
			end;
			N := N + CheckAlongPath( P^.SubCom );
			N := N + CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
		CheckAlongPath := N;
	end;
begin
	RDesc := FilterElementDescription( Desc );

	NumFreeEntryPoints := CheckAlongPath( Adventure^.SubCom ) + CheckAlongPath( GB^.Meks );
end;

Function FindFreeEntryPoint( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; N: Integer ): GearPtr;
	{ Find out how many scenes match the provided description. }
var
	E2: GearPtr;
	RDesc: String;
	Procedure CheckAlongPath( P: GearPtr );
	begin
		while ( P <> Nil ) and ( E2 = Nil ) do begin
			if ( P^.G = GG_MetaTerrain ) and ( P^.S <> GS_MetaEncounter ) and ( P^.Stat[ STAT_Destination ] < 0 ) and PartMatchesCriteria( SAttValue( P^.SA , 'REQUIRES' ) , Desc ) and
				PartMatchesRelativeCriteria( Adventure, Plot, P, GB, RDesc ) and MetaSceneNotInUse( Adventure , P^.Stat[ STAT_Destination ] ) then begin
					Dec( N );
					if N = 0 then E2 := P;
			end;
			if E2 = Nil then CheckAlongPath( P^.SubCom );
			if E2 = Nil then CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
	end;
begin
	E2 := Nil;
	RDesc := FilterElementDescription( Desc );

	CheckAlongPath( Adventure^.SubCom );
	if E2 = Nil then CheckAlongPath( GB^.Meks );

	FindFreeEntryPoint := E2;
end;

Function SearchForMetasceneEntryPoint( Adventure , Plot: GearPtr; GB: GameBoardPtr; Desc: String ): GearPtr;
	{ Locate a metaterrain gear which has a negative destination number that's }
	{ currently unused. }
var
	NumElements: Integer;
begin
	NumElements := NumFreeEntryPoints( Adventure , Plot , GB , Desc );
	if NumElements > 0 then begin
		{ Pick one of the free scenes at random. }
		SearchForMetasceneEntryPoint := FindFreeEntryPoint( Adventure , Plot , GB , Desc , Random( NumElements ) + 1 );
	end else begin
		SearchForMetasceneEntryPoint := Nil;
	end;
end;

function FactionDesc( Adv,Fac: GearPtr ): String;
	{ Return a description of the provided faction. }
var
	it: String;
begin
	{ Basic description is the faction's TYPE string attribute. }
	it := SATtValue( Fac^.SA , 'TYPE' ) + ' ' + SATtValue( Fac^.SA , 'CONTEXT' ) + ' ' + SATtValue( Fac^.SA , 'DESIG' );

	if IsArchEnemy( Adv, Fac ) then it := it + ' ARCHENEMY';
	if IsArchAlly( Adv, Fac ) then it := it + ' ARCHALLY';

	FactionDesc := it;
end;

Function NumFreeFaction( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
	{ Find out how many factions match the provided description. }
var
	Fac: GearPtr;
	N: Integer;
	RDesc: String;
begin
	Fac := Adventure^.InvCom;
	N := 0;
	RDesc := FilterElementDescription( Desc );

	while Fac <> Nil do begin
		if ( Fac^.G = GG_Faction ) and PartMatchesCriteria( FactionDesc( Adventure,Fac ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Fac, GB, RDesc ) then Inc( N );
		Fac := Fac^.Next;
	end;

	NumFreeFaction := N;
end;

Function FindFreeFaction( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; Num: Integer ): GearPtr;
	{ Find the NUM'th scene that matches the provided description. }
var
	Fac,F2: GearPtr;
	RDesc: String;
begin
	Fac := Adventure^.InvCom;
	F2 := Nil;
	RDesc := FilterElementDescription( Desc );

	while Fac <> Nil do begin
		if ( Fac^.G = GG_Faction ) and PartMatchesCriteria( FactionDesc( Adventure,Fac ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Fac, GB, RDesc ) then begin
			Dec( Num );
			if Num = 0 then F2 := Fac;
		end;
		Fac := Fac^.Next;
	end;

	FindFreeFaction := F2;
end;

Function DeployNextPrefabElement( GB: GameBoardPtr; Adventure,Plot: GearPtr; N: Integer; MovePrefabs: Boolean ): GearPtr;
	{ Deploy the next element, give it a unique ID number if }
	{ appropriate, then return a pointer to the it. }
var
	E,Dest,Target: GearPtr;	{ Element & Destination. }
	D,P: Integer;
	Place,SubStr: String;
	ID: LongInt;
	InSceneNotElement: Boolean;
begin
	{ Find the first uninitialized entry in the list. }
	{ This is gonna be our next element. }
	E := Plot^.InvCom;
	While ( E <> Nil ) and ( SAttValue( E^.SA , 'ELEMENT' ) <> '' ) do begin
		E := E^.Next;
	end;

	if E <> Nil then begin
		{ Give our new element a unique ID, and store its ID in the Plot. }
		{ Characters who aren't animals get CIDs, encounters get scene IDs, }
		{ everything else gets NIDs. }
		if ( E^.G = GG_Character ) and NotAnAnimal( E ) then begin
			ID := NewCID( GB , Adventure );
			SetNAtt( E^.NA , NAG_Personal , NAS_CID , ID );
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <C Prefab>' );
			SetSAtt( E^.SA , 'ELEMENT <C Prefab>' );
		end else if ( E^.G = GG_MetaTerrain ) and ( E^.S = GS_MetaEncounter ) and not AStringHasBString( SAttValue( E^.SA , 'SPECIAL' ) , 'NOMSID' ) then begin
			ID := NewMetaSceneID( Adventure );
			E^.Stat[ STAT_Destination ] := ID;
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <S Prefab>' );
			SetSAtt( E^.SA , 'ELEMENT <S Prefab>' );

		end else begin
			ID := NewNID( GB , Adventure );
			SetNAtt( E^.NA , NAG_Narrative , NAS_NID , ID );
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <I Prefab>' );
			SetSAtt( E^.SA , 'ELEMENT <I Prefab>' );
		end;
		SetNAtt( Plot^.NA , NAG_ElementID , N , ID );


		If MovePrefabs then begin
			{ Find out if we have to put this element somewhere else. }
			Place := SAttValue( Plot^.SA , 'PLACE' + BStr( N ) );

			{ If we have to put it somewhere, do so now. }
			{ Otherwise leave it where it is. }
			if Place <> '' then begin
				{ Delink the element from the plot. }
				DelinkGear( Plot^.InvCom , E );

				{ Determine its target location. }
				{ If the PLACE string starts with a tilde, we want to }
				{ place the prefab element in the same scene as the relative }
				{ element rather than the element itself. }
				InSceneNotElement := Place[1] = '~';
				if InSceneNotElement then DeleteFirstChar( Place );

				D := ExtractValue( Place );
				Dest := GetFSE( D );

				if InSceneNotElement and (( Dest = Nil ) or ( Dest^.G <> GG_Scene )) then begin
					{ If the destination is a metascene, locate its entrance. }
					if ( Dest = Nil ) or ( Dest^.G = GG_MetaScene ) then begin
						Dest := FindSceneEntrance( Adventure , GB , GetFSEID( Plot^.Parent , Plot , D ) );
					end;

					{ Try to find the associated scene now. }
					if Dest <> Nil then begin
						Dest := FindActualScene( GB , FindGearScene( Dest , GB ) );
					end;
				end;

				if Dest = Nil then begin
					{ An invalid location was specified... }
					DisposeGear( E );

				end else if ( Dest^.G <> GG_Scene ) and ( Dest^.G <> GG_MetaScene ) and IsLegalInvCom( Dest , E ) then begin
					{ If E can be an InvCom of Dest, stick it there. }
					InsertInvCom( Dest , E );

				end else begin
					{ If Dest isn't a scene, find the scene DEST is in itself }
					{ and stick E in there. }
					while ( Dest <> Nil ) and ( not IsAScene( Dest ) ) do Dest := Dest^.Parent;

					if Dest <> Nil then begin
						{ Maybe set this item next to another item. }
						P := Pos( '!N' , Place );
						if P > 0 then begin
							SubStr := copy( Place , P , 255 );
							ExtractWord( SubStr );
							ID := ExtractValue( SubStr );
							Target := GetFSE( ID );
							if ( Target <> Nil ) and ( ( Target^.G = GG_Scene ) or ( Target^.G = GG_MetaScene ) ) then begin
								if ID > 0 then begin
									Target := FindSceneEntrance( Adventure , GB , ElementID( Plot , ID ) );
								end else begin
									Target := FindSceneEntrance( Adventure , GB , ElementID( Plot^.Parent , Abs( ID ) ) );
								end;
							end;
							if Target <> Nil then begin
								SetNAtt( E^.NA , NAG_ParaLocation , NAS_X , NAttValue( Target^.NA , NAG_Location , NAS_X ) );
								SetNAtt( E^.NA , NAG_ParaLocation , NAS_Y , NAttValue( Target^.NA , NAG_Location , NAS_Y ) );
							end;
						end;

						{ If the destination is the current scene, }
						{ we'll want to deploy this element right away. }
						{ Otherwise just shove it in the invcoms. }
						if Dest = GB^.Scene then begin
							DeployMek( GB , E , True );
						end else begin
							InsertInvCom( Dest , E );
						end;

						{ If E is a character, this brings us to the next problem: }
						{ we need to assign a TEAM for E to be a member of. }
						if E^.G = GG_Character then begin
							SetSAtt( E^.SA , 'TEAMDATA <' + Place + '>' );
							ChooseTeam( E , Dest );
						end;

						{ If DEST is a metascene, give E an OriginalHome }
						{ of -1 so it isn't deleted when the scene ends. }
						if ( Dest^.G = GG_MetaScene ) or IsInvCom( Dest ) then SetNAtt( E^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );

					end else begin
						{ Couldn't find a SCENE gear. Get rid of E. }
						DisposeGear( E );
					end;
				end; { If MovePrefabs }
			end;

		end; { if place <> '' }

	end;
	DeployNextPrefabElement := E;
end;

Function SelectArtifact( Adventure: GearPtr; Desc: String ): GearPtr;
	{ Select an artifact at random. If one can be found, delink it from the }
	{ artifact collection and return its address. }
var
	AC,A,Part: GearPtr;
	N: Integer;
begin
	{ Step One: Find the artifact set. }
	AC := SeekCurrentLevelGear( Adventure^.InvCom , GG_ArtifactSet , 0 );
	A := Nil;

	if AC <> Nil then begin
		{ Count the number of appropriate gears. }
		Part := AC^.InvCom;
		N := 0;
		while Part <> Nil do begin
			if PartMatchesCriteria( SAttValue( Part^.SA , 'REQUIRES' ) , Desc ) then Inc( N );
			Part := Part^.next;
		end;

		{ Next, grab one at random. }
		if N > 0 then begin
			N := Random( N );
			Part := AC^.InvCom;
			while ( Part <> Nil ) and ( A = Nil ) do begin
				if PartMatchesCriteria( SAttValue( Part^.SA , 'REQUIRES' ) , Desc ) then begin
					if N = 0 then A := Part;
					Dec( N );
				end;
				Part := Part^.next;
			end;
		end;
	end;
	if A <> Nil then DelinkGear( AC^.InvCom , A );
	SelectArtifact := A;
end;

Function FindElement( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ; MovePrefabs, Debug: Boolean ): Boolean;
	{ Locate and store the Nth element for this plot. }
	{ Return TRUE if a suitable element could be found, or FALSE }
	{ if no suitable element exists in the adventure & this plot }
	{ will have to be abandoned. }
var
	Element: GearPtr;
	Desc,EKind: String;
	OK: Boolean;
	NumElements: Integer;
begin
	{ Error check }
	if ( N < 1 ) or ( N > Num_Plot_Elements ) then Exit( False );

	{ Find the description for this element. }
	desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );
	DeleteWhiteSpace( Desc );

	{ Initialize OK to TRUE. }
	OK := True;

	if desc <> '' then begin
		EKind := ExtractWord( Desc );

		if EKind[1] = 'C' then begin
			{ This element is a CHARACTER. Find one. }

			{ IMPORTANT!!!: Character being sought muct not have a plot already!!! }
			if ( Plot <> Nil ) then desc := 'NOTUSED ' + desc;

			Element := CharacterSearch( Adventure , Plot , Desc , GB );

			if Element <> Nil then begin
				{ Store the NPC's ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , NAttValue( Element^.NA , NAG_Personal , NAS_CID ) );
				Fast_Seek_Element[ 1 , N ] := Element;

			end else begin
				{ No free NPCs were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'S' then begin
			{ This element is a SCENE. Find one. }
			{ Pick one of the free scenes at random. }
			Element := SearchForScene( Adventure , Plot , GB , Desc );

			if Element <> Nil then begin
				{ Store the Scene ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , Element^.S );
				Fast_Seek_Element[ 1 , N ] := Element;

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'M' then begin
			{ This element is a METASCENE. Find one. }
			{ Pick one of the free scenes at random. }
			Element := SearchForMetasceneEntryPoint( Adventure , Plot , GB , Desc );

			if Element <> Nil then begin
				{ Store the Scene ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , Element^.Stat[ STAT_Destination ] );
				Fast_Seek_Element[ 1 , N ] := FindMetascene( Adventure , Element^.Stat[ STAT_Destination ] );

				{ Change its type to SCENE, since it will be treated as a scene hereafter. }
				SetSAtt( PLOT^.SA , 'ELEMENT' + BStr( N ) + ' <SMETA>' );

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;
			end;

		end else if EKind[1] = 'F' then begin
			{ Faction element. }
			NumElements := NumFreeFaction( Adventure , Plot , GB , Desc );
			if NumElements > 0 then begin
				{ Pick one of the free scenes at random. }
				Element := FindFreeFaction( Adventure , Plot , GB , Desc , Random( NumElements ) + 1 );
				Fast_Seek_Element[ 1 , N ] := Element;

				{ Store the Scene ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , Element^.S );

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'P' then begin
			{ PreFab element. Check Plot/InvCom and }
			{ retrieve it. }
			Element := DeployNextPrefabElement( GB , Adventure , Plot , N , MovePrefabs );
			Fast_Seek_Element[ 1 , N ] := Element;
			OK := Element <> Nil;

		end else if EKind[1] = 'A' then begin
			{ Artifact. Select one at random, then deploy it as a prefab element. }
			Element := SelectArtifact( Adventure , desc );
			if Element <> Nil then begin
				{ We now want to deploy the artifact as though it were a }
				{ prefab element. }
				Element^.Next := Plot^.InvCom;
				Plot^.InvCom := Element;
				Element^.Parent := Plot;
				DeployNextPrefabElement( GB , Adventure , Plot , N , MovePrefabs );
				Fast_Seek_Element[ 1 , N ] := Element;
				OK := True;
			end else OK := False;

		end else if ( EKind[1] = '.' ) then begin
			if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
				{ Insert the current scene as this element. }
				SetSAtt( PLOT^.SA , 'ELEMENT' + BStr( N ) + ' <S>' );
				SetNAtt( PLOT^.NA , NAG_ElementID , N , RealSceneID( GB^.Scene ) );
				Fast_Seek_Element[ 1 , N ] := GB^.Scene;
				OK := True;
			end else OK := False;
		end;		
	end;

	if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
		if not OK then DialogMsg( 'PLOT ERROR: ' + BStr( N ) + ' Element Not Found!' )
		else if desc <> '' then DialogMsg( 'PLOT ELEMENT ' + BStr( N ) + ': ' + BStr( ElementID( Plot , N ) ) + ' ' + GearName( Element ) );
	end;

	FindElement := OK;
end;

Function SeekUrbanArea( RootScene: GearPtr ): GearPtr;
	{ Locate an urban area contained within this scene. It may either be the }
	{ scene itself or a subscene thereof. An urban area is somewhere that buildings }
	{ may safely be placed. }
	Function IsUrbanArea( Scene: GearPtr ): Boolean;
	begin
		IsUrbanArea := ( Scene^.G = GG_Scene ) and AStringHasBString( SAttValue( Scene^.SA , 'TYPE' ) , 'URBAN' );
	end;
	Function SearchSubScenes( LList: GearPtr ): GearPtr;
		{ Search this list of sub-scenes to locate an urban scene. }
	var
		Scene: GearPtr;
	begin
		Scene := Nil;
		while ( Scene = Nil ) and ( LList <> Nil ) do begin
			if IsUrbanArea( LList ) then Scene := LList;
			if Scene = Nil then SearchSubScenes( LList^.SubCom );
			LList := LList^.Next;
		end;
		SearchSubScenes := Scene;
	end;
begin
	if IsUrbanArea( RootScene ) then Exit( RootScene );
	SeekUrbanArea := SearchSubScenes( RootScene^.SubCom );
end;


Procedure CreateElement( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr );
	{ Create and store the Nth element for this plot. }
var
	Element,Destination,Faction,EntranceList,Dest2: GearPtr;
	Desc,EKind,SubStr,job: String;
	ID,P: Integer;
begin
	{ Error check }
	if ( N < 1 ) or ( N > Num_Plot_Elements ) then Exit;

	{ Find the description for this element. }
	desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );
	DeleteWhiteSpace( Desc );

	{ Locate the !Near clause, if it exists. }
	P := Pos( '!N' , desc );
	if P > 0 then begin
		SubStr := copy( desc , P , 255 );
		ExtractWord( SubStr );
		ID := ExtractValue( SubStr );
		Destination := GetFSE( ID );

		if ( Destination <> Nil ) and ( Destination^.G <> GG_MetaScene ) then begin
			Destination := FindActualScene( GB , FindGearScene( Destination , GB ) );
		end;
	end else begin
		Destination := Nil;
	end;

	{ Locate the !Comrade clause, if it exists. }
	{ If no !Comrade found, try !Ally as well. }
	P := Pos( '!C' , desc );
	if P = 0 then P := Pos( '!A' , desc );
	if P > 0 then begin
		SubStr := copy( desc , P , 255 );
		ExtractWord( SubStr );
		ID := ExtractValue( SubStr );
		Faction := GetFSE( ID );
		if ( Faction <> Nil ) then begin
			Faction := SeekFaction( Adventure , GetFactionID( Faction ) );
		end;
	end else begin
		Faction := Nil;
	end;


	if desc <> '' then begin
		EKind := ExtractWord( Desc );

		if EKind[1] = 'C' then begin
			{ This element is a CHARACTER. Create one. }
			job := SAttValue( Plot^.SA , 'NEVERFAIL' + BStr( N ) );
			if job = '' then job := 'MECHA PILOT';
			Element := LoadNewNPC( job , True );
			if Element = Nil then Element := LoadNewNPC( 'MECHA PILOT' , True );
			SetSAtt( Element^.SA , 'job <' + job + '>' );
			SetSAtt( Element^.SA , 'TEAMDATA <Pass>' );

			{ Store the NPC's ID in the plot. }
			ID := NewCID( GB , Adventure );
			SetNAtt( Element^.NA , NAG_Personal , NAS_CID , ID );
			SetNAtt( Plot^.NA , NAG_ElementID , N , ID );
			Fast_Seek_Element[ 1 , N ] := Element;

		end else if EKind[1] = 'M' then begin
			{ MetaScene element. }
			{ Create a building to use as the entrance, give it a unique ID number, }
			{ then change the element type to Scene. }
			FilterElementDescription( Desc );
			if Faction <> Nil then desc := desc + ' ' + SAttValue( Faction^.SA , 'DESIG' );
			EntranceList := AggregatePattern( 'ENTRANCE_*.txt' , Series_Directory );
			Element := CloneGear( FindNextComponent( EntranceList , Desc ) );
			DisposeGear( EntranceList );
			if Element = Nil then Element := LoadNewSTC( 'BUILDING' );
			SetSAtt( Element^.SA , 'NAME <' + RandomBuildingName( Element ) + '>' );

			{ This is gonna be a new building, so don't stick it just anywhere. }
			{ We want to place this element in the URBAN area of the scene. }
			{ Note that if no urban area can be found, NEVERFAIL will actually }
			{ fail. Woah! }
			Dest2 := SeekUrbanArea( Destination );
			if Dest2 <> Nil then begin
				Destination := Dest2;
				ID := NewMetaSceneID( Adventure );
				Element^.Stat[ STAT_Destination ] := ID;
				SetNAtt( Plot^.NA , NAG_ElementID , N , ID );
				SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <S>' );
			end else begin
				DisposeGear( Element );
				Element := Nil;
			end;

		end else begin
			Element := Nil;
{$IFDEF DEBUG}
			DialogMsg( 'ERROR- CreateElement asked to create element of type ' + EKind +'.' );
			DialogMsg( 'Resultant plot ' + GearName( Plot ) + ' may fail.' );
{$ENDIF}

		end;

		{ After this point, don't expect to use "desc" any more. It may have been }
		{ modified or chopped into pieces above. }

		if Element <> Nil then begin
			if Destination <> Nil then begin
				if GB^.Scene = Destination then begin
					DeployMek( GB , Element , True );
				end else begin
					InsertInvCom( Destination , Element );
				end;
				if IsAScene( Destination ) and IsMasterGear( Element ) then begin
					ChooseTeam( Element , Destination );
				end;

			end else begin
				InsertInvCom( Plot , Element );
			end;

			if Faction <> Nil then begin
				SetNAtt( Element^.NA , NAG_Personal , NAS_FactionID , Faction^.S );
			end;

			{ Indicate that this is a prefab element, so if the plot fails it'll be deleted. }
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <' + SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) + ' PREFAB>' );
		end;
	end;
end;


Procedure FormatRumorString( Adventure,Plot,RBase: GearPtr; GB: GameBoardPtr );
	{ Make sure the rumor strings are properly formatted for this plot. }
	{ RBase is the gear whose rumor we are currently interested in. }
	{ Also, format rumor strings for all sub-components. }
var
	R0: String;
	S: GearPtr;
	T: Integer;
begin
	{ Locate the rumor string. }
	R0 := SAttValue( RBase^.SA , 'RUMOR' );

	if R0 <> '' then begin
		for t := 1 to Num_Plot_Elements do begin
			ReplacePat( R0 , '!' + BStr( T ) , ElementName( Adventure , Plot , T , GB ) );
		end;

		SetSAtt( RBase^.SA , 'RUMOR <' + R0 + '>' );
	end;

	{ Format the rumors of all sub and inv components. }
	S := RBase^.SubCom;
	while S <> Nil do begin
		FormatRumorString( Adventure , Plot , S , GB );
		S := S^.Next;
	end;

	S := RBase^.InvCom;
	while S <> Nil do begin
		FormatRumorString( Adventure , Plot , S , GB );
		S := S^.Next;
	end;
end;

Procedure AddGearXRContext( GB: GameBoardPtr; Adv,Part: GearPtr; var Context: String; palette_entry_code: Char );
	{ Add the context information for PART to CONTEXT. }
var
	F: GearPtr;
	msg,m2: String;
begin
	if Part <> Nil then begin
		Context := Context + ' ' + palette_entry_code + ':++';

		{ Add additional information about PART. }
		msg := SAttValue( Part^.SA , 'DESIG' );
		if msg <> '' then Context := Context + ' ' + palette_entry_code + ':' + msg;
		msg := SAttValue( Part^.SA , 'CONTEXT' );
		while msg <> '' do begin
			m2 := ExtractWord( msg );
			if m2 <> '' then Context := Context + ' ' + palette_entry_code + ':' + m2;
		end;

		{ If Part isn't a faction itself, add the designation of its faction. }
		if Part^.G <> GG_Faction then begin
			F := SeekFaction( Adv , NAttValue( Part^.NA , NAG_Personal , NAS_FactionID ) );
			if F <> Nil then begin
				msg := SAttValue( F^.SA , 'DESIG' );
				if msg <> '' then Context := Context + ' ' + palette_entry_code + ':' + msg;
			end;
		end;

		{ If Part is a character, add relationship info. Unless the }
		{ relationship is ENEMY, in which case it's covered below. }
		if Part^.G = GG_Character then begin
			Case NAttValue( Part^.NA , NAG_Relationship , 0 ) of
				NAV_Family: Context := Context + ' ' + palette_entry_code + ':FAMILY';
				NAV_Lover: Context := Context + ' ' + palette_entry_code + ':LOVER';
				NAV_Friend: Context := Context + ' ' + palette_entry_code + ':FRIEND';
			end;
			m2 := SAttValue( Part^.SA , 'JOB_DESIG' );
			if m2 <> '' then Context := Context + ' ' + palette_entry_code + ':' + m2;
		end;

		if IsArchEnemy( Adv , Part ) then Context := Context + ' ' + palette_entry_code + ':ENEMY';
		if IsArchAlly( Adv , Part ) then Context := Context + ' ' + palette_entry_code + ':ALLY';

	end else begin
		Context := Context + ' ' + palette_entry_code + ':--';

	end;
end;

Procedure AddElementContext( GB: GameBoardPtr; Story: GearPtr; var Context: String; palette_entry_code: Char; Element_Num: Integer );
	{ Add the context details for element T of STORY. }
var
	IsMetaScene: Boolean;
	Adv,E: GearPtr;
	msg: String;
begin
	IsMetaScene := False;
	Adv := FindRoot( Story );

	{ If this element is a scene, tell whether it's a regular scene }
	{ or a metascene. }
	msg := SAttValue( Story^.SA , 'ELEMENT' + BStr( Element_Num ) );
	if ( msg <> '' ) and ( UpCase( msg[1] ) = 'S' ) then begin
		if ElementID( Story , Element_Num ) >= 0 then begin
			Context := Context + ' ' + palette_entry_code + ':perm';
		end else begin
			Context := Context + ' ' + palette_entry_code + ':meta';
			IsMetaScene := True;
		end;
	end;

	E := SeekPlotElement( Adv , Story , Element_Num , GB );
	if ( E = Nil ) and IsMetaScene and ( FindSceneEntrance( Adv , GB , ElementID( Story , Element_Num ) ) <> Nil ) then begin
		Context := Context + ' ' + palette_entry_code + ':++';
	end else begin
		AddGearXRContext( GB , Adv , E , Context , palette_entry_code );
	end;
end;

Function DifficulcyContext( Threat: Integer ): String;
	{ Return a string describing this difficulcy level. }
begin
	if Threat > 80 then begin
		DifficulcyContext := '!Ex';
	end else if Threat > 60 then begin
		DifficulcyContext := '!Hi';
	end else if Threat > 40 then begin
		DifficulcyContext := '!Md';
	end else if Threat > 20 then begin
		DifficulcyContext := '!Lo';
	end else begin
		DifficulcyContext := '!Ne';
	end;
end;

Function StoryContext( GB: GameBoardPtr; Story: GearPtr ): String;
	{ Describe the context of this story in a concise string. }
var
	it,msg: String;
	T: Integer;
begin
	{ Get the basic context. }
	it := SAttValue( Story^.SA , 'CONTEXT' );

	{ Add a description for the difficulcy rating. }
	it := it + ' ' + DifficulcyContext( NAttValue( Story^.NA , NAG_XXRan , NAS_DifficulcyLevel ) );

	{ Add the extra random palette entries. }
	if ( Story^.G = GG_Story ) and ( Story^.S = GS_XRANStory ) then begin
		for t := 1 to Num_Plot_Elements do begin
			{ If this element represents to a palette entry, add its info }
			{ to the context. }
			msg := SAttValue( Story^.SA , 'palette_entry_code' + BStr( T ) );
			if msg <> '' then AddElementContext( GB , Story , it , msg[1] , T );
		end;
	end;
	StoryContext := it;
end;


Procedure InsertPFrags( Plot,Persona: GearPtr; const Context: String; ID: Integer );
	{ Prepare the persona for use in the game. Search its string attributes and }
	{ add any persona fragments that are requested. }
var
	F: GearPtr;	{ The persona fragment to insert. }
	S,FS: SAttPtr;
	head,info,TypeLabel: String;
	Param: Array [1..8] of String;
	T: Integer;
begin
	S := Persona^.SA;
	while S <> Nil do begin
		if S^.Info[1] = '*' then begin
			{ This is a fragment request. Start by determining the relevant data. }
			head := RetrieveAPreamble( S^.Info );
			DeleteFirstChar( head );

			info := RetrieveAString( S^.info );
			TypeLabel := ExtractWord( info );
			for t := 1 to 8 do Param[t] := ExtractWord( Info );

			{ Next, search for a matching fragment... }
			F := FindNextComponent( persona_fragments , TypeLabel + ' ' + Context );
			if F <> Nil then begin
				{ If one was found, prep it for inclusion in the persona. }
				F := CloneGear( F );
				FS := F^.SA;
				while FS <> Nil do begin
					{ Format the strings. Tasks: }
					{ - Rename "START" to "HEAD" }
					{ - Replace %1% through %8% with parameters }
					{ - Replace %id% with BStr( ID ) }
					if UpCase( RetrieveAPreamble( FS^.Info ) ) = 'START' then begin
						FS^.Info := head + ' <' + RetrieveAString( FS^.Info ) + '>';
					end;
					ReplacePat( FS^.Info , '%id%' , BStr( ID ) );
					ReplacePat( FS^.Info , '%1%' , Param[1] );
					ReplacePat( FS^.Info , '%2%' , Param[2] );
					ReplacePat( FS^.Info , '%3%' , Param[3] );
					ReplacePat( FS^.Info , '%4%' , Param[4] );
					ReplacePat( FS^.Info , '%5%' , Param[5] );
					ReplacePat( FS^.Info , '%6%' , Param[6] );
					ReplacePat( FS^.Info , '%7%' , Param[7] );
					ReplacePat( FS^.Info , '%8%' , Param[8] );

					FS := FS^.Next;
				end;

				{ Copy everything to the main persona. }
				FS := F^.SA;
				while FS <> Nil do begin
					SetSAtt( Persona^.SA , FS^.Info );
					FS := FS^.Next;
				end;

				{ Increment the ID counter. }
				Inc( ID );

				DisposeGear( F );
			end;
		end;

		{ - Replace %E1% through %E8% with element IDs }
		if Plot <> Nil then begin
			for t := 1 to Num_Plot_Elements do begin
				ReplacePat( S^.Info , '%E' + BStr( T ) + '%' , BStr( ElementID( Plot , T ) ) );
			end;
		end;

		S := S^.Next;

	end;
end;

Function PersonalContext( Adv,NPC: GearPtr ): String;
	{ Return the context for this NPC. The context should include the trait }
	{ description and the faction designation. }
	{ This function is used for selecting persona fragments. }
var
	it: String;
	Theme: Integer;
begin
	if NPC = Nil then exit( '' );
	it := XNPCDesc( Adv , NPC );
	{ Add the theme here. }
	Theme := NAttValue( NPC^.NA , NAG_Personal , NAS_MechaTheme );
	if Theme <> 0 then it := it + ' [MT' + BStr( Theme ) + ']';
	PersonalContext := it;
end;

Procedure PrepAllPersonas( Adventure,Plot: GearPtr; GB: GameBoardPtr; MinID: Integer );
	{ Prepare the personas of this plot. }
var
	P,P2: GearPtr;
	Context: String;
begin
	P := Plot^.SubCom;
	Context := SAttValue( Plot^.SA , 'CONTEXT' );
	if ( Plot^.Parent <> Nil ) and ( Plot^.Parent^.G = GG_Story ) then begin
		Context := Context + StoryContext( GB , Plot^.Parent );
{	end else begin
		Context := Context + SAttValue( Plot^.SA , 'CONTEXT' );
}	end;
	while P <> Nil do begin
		P2 := P^.Next;
		if P^.G = GG_Persona then begin
			InsertPFrags( Plot , P , Context + PersonalContext( Adventure , GetFSE( P^.S ) ) , MinID );
		end;
		P := P2;
	end;
end;

Procedure PrepMetaScenes( Adventure,Plot: GearPtr; GB: GameBoardPtr );
	{ Maps are stored by name, so each metascene needs a unique name. }
	{ Since it already has a unique ID number this shouldn't be much trouble. }
var
	M,Entrance,T: GearPtr;
	Context: String;
begin
	if ( Plot^.Parent <> Nil ) and ( Plot^.Parent^.G = GG_Story ) then begin
		Context := StoryContext( GB , Plot^.Parent );
	end else begin
		Context := SAttValue( Plot^.SA , 'CONTEXT' );
	end;
	M := Plot^.SubCom;
	while M <> Nil do begin
		if ( M^.G = GG_MetaScene ) and ( M^.S >= 1 ) and ( M^.S <= Num_Plot_Elements ) then begin
			{ Store the entrance of the metascene. We'll need it later. }
			Entrance := FindSceneEntrance( Adventure , GB , ElementID( Plot , M^.S ) );
			if Entrance <> Nil then begin
				SetNAtt( M^.NA , NAG_Narrative , NAS_EntranceScene , FindGearScene( Entrance , GB ) );
			end;

			{ Prep the local personas. }
			T := M^.SubCom;
			while T <> Nil do begin
				if ( T^.G = GG_Persona ) and ( T^.S >= 1 ) and ( T^.S <= Num_Plot_Elements ) then begin
					{ Replace S with the CID of element T^.S. }
					InsertPFrags( Plot , T , Context + ' ' + PersonalContext( Adventure , GetFSE( T^.S ) ) , 1 );
					T^.S := ElementID( Plot , T^.S );
				end;
				T := T^.Next;
			end;

			SetSAtt( M^.SA , 'NAME <METASCENE:' + BStr( ElementID( Plot , M^.S ) ) + '>' );
			SetSAtt( M^.SA , 'CONTEXT <' + SAttValue( M^.SA , 'CONTEXT' ) + ' ' + Context + '>' );
		end;
		M := M^.Next;
	end;
end;


Procedure InitPlot( Adventure,Plot: GearPtr; GB: GameBoardPtr );
	{ Initialize this plot. }
	{ - Format rumor strings. }
	{ - Provide unique names for all metascenes. }
begin
	FormatRumorString( Adventure , Plot , Plot , GB );
	PrepMetaScenes( Adventure , Plot , GB );
	PrepAllPersonas( Adventure , Plot , GB , 1 );
end;

Procedure InitRandomLoot( LList: GearPtr );
	{ Search this list for random loot requests. Upon finding one, }
	{ fill the resultant gear with sstuff. }
const
	Default_Category = 'TREASURE';
var
	LootVal: LongInt;
	Loot_Category, Loot_Factions: String;
begin
	while LList <> Nil do begin
		InitRandomLoot( LList^.SubCom );
		InitRandomLoot( LList^.InvCom );
		LootVal := NAttValue( LList^.NA , NAG_Narrative , NAS_RandomLoot );
		if LootVal > 0 then begin
			{ A request for random loot has been placed. Find the loot }
			{ categories and the loot faction, then proceed to stuff. }
			Loot_Category := SAttValue( LList^.SA , 'LOOT_CATEGORY' );
			if Loot_Category = '' then Loot_Category := Default_Category;
			Loot_Factions := 'GENERAL ' + SAttValue( LList^.SA , 'LOOT_FACTIONS' );
			RandomLoot( LList , LootVal , Loot_Category , Loot_Factions );
			SetNAtt( LList^.NA , NAG_Narrative , NAS_RandomLoot , 0 );
		end;
		LList := LList^.Next;
	end;
end;

Function MatchPlotToAdventure( Slot,Plot: GearPtr; GB: GameBoardPtr; DoFullInit,MovePrefabs,Debug: Boolean ): Boolean;
	{ This PLOT gear is meant to be inserted into this ADVENTURE gear. }
	{ Perform the insertion, select unselected elements, and make sure }
	{ that everything fits. }
	{ IMPORTANT: PLOT must not already be inserted into SLOT!!! }
	{ This procedure also works for Stories. }
var
	T: Integer;
	E: STring;
	Adventure,PFE: GearPtr;	{ Prefab Element }
	EverythingOK,OKNow: Boolean;
begin
	{ Error Check }
	if ( Plot = Nil ) or ( Slot = Nil ) then Exit;

	EverythingOK := True;

	{ We need to stick the PLOT into the ADVENTURE to prevent }
	{ the FindElement procedure from choosing the same item for }
	{ multiple elements. }
	InsertInvCom( Slot , Plot );
	Adventure := FindRoot( Slot );

	{ Select Actors }
	{ First clear the FastSeek array. }
	for t := 1 to Num_Plot_Elements do begin
		Fast_Seek_Element[ 0 , t ] := Nil;
		Fast_Seek_Element[ 1 , t ] := Nil;
	end;

	if Slot^.G = GG_Story then begin
		for t := 1 to Num_Plot_Elements do begin
			Fast_Seek_Element[ 0 , t ] := SeekPlotElement( Adventure , Slot , T , GB );
		end;
	end;

	for t := 1 to Num_Plot_Elements do begin
		{ If we are inserting an adventure arc instead of a truly }
		{ random plot, several of the elements may already have been }
		{ assigned. The plot is OK if those elements exist & are OK. }
		if ( ElementID( Plot , T ) = 0 ) and EverythingOK then begin
			OkNow := FindElement( Adventure , Plot , T , GB , MovePrefabs , Debug );

			if AStringHasBString( SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) ) , 'NEVERFAIL' ) and ( not OkNow ) then begin
				CreateElement( Adventure , Plot , T , GB );
				if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
					DialogMsg( '...but NEVERFAIL has saved the day! ID=' + BStr( ElementID( Plot , T ) ) );
				end;

				OkNow := ElementID( Plot , t ) <> 0;
			end;
		end else if EverythingOK then begin
			Fast_Seek_Element[ 1 , T ] := SeekPlotElement( Adventure , Plot , T , GB );

			{ If the element wasn't found, this will cause an error... unless, }
			{ of course, we're dealing with a MetaScene. This is the only element }
			{ type that can not exist and still be valid. }
			E := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if ( E = '' ) or ( ( UpCase( E[1] ) <> 'S' ) and ( ElementID( Plot , t ) > 0 ) ) then begin
				OkNow := Fast_Seek_Element[ 1 , T ] <> Nil;
			end else begin
				OkNow := True;
			end;
			if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
				if not OKNow then DialogMsg( 'PLOT ERROR: ' + GearName( Plot ) + BStr( T ) + ' Predefined Element ' + BStr( ElementID( Plot , t ) ) + ' Not Found!' )
				else DialogMsg( 'PLOT ELEMENT ' + BStr( T ) + ': ' + ElementName( Adventure , Plot , T , GB ) );
			end;
		end;

		if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
			DialogMsg( BStr( T ) + '=> ' + BStr( ElementID( Plot , T ) ) );
		end;

		EverythingOK := EverythingOK and OKNow;
	end;

	if EverythingOK then begin
		{ The plot has been successfully installed into the }
		{ adventure. Initialize the stuff... rumor strings }
		{ mostly. }
		{ Quest content doesn't get initialized here- that gets done later. }
		if DoFullInit then InitPlot( Adventure , Plot , GB );

		{ Actually, quest content does get its treasures initialized here. }
		InitRandomLoot( Plot^.InvCom );

		{ Also store the names of all known elements. They might come in handy later. }
		for t := 1 to Num_Plot_Elements do begin
			{ Store the name of this element, which should still be stored in }
			{ the FSE array. }
			SetSAtt( Plot^.SA , 'NAME_' + BStr( T ) + ' <' + GearName( Fast_Seek_Element[ 1 , t ] ) + '>' );
		end;
	end else begin
		{ This plot won't fit in this adventure. Dispose of it. }
		{ First get rid of any already-placed prefab elements. }
		for t := 1 to Num_Plot_Elements do begin
			E := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if AStringHasBString( E , 'PREFAB' ) then begin
				PFE := SeekPlotElement( Adventure , Plot , T , GB );
				if PFE <> Nil then begin
					if IsSubCom( PFE ) then begin
						RemoveGear( PFE^.Parent^.SubCom , PFE );
					end else if IsInvCom( PFE ) then begin
						RemoveGear( PFE^.Parent^.InvCom , PFE );
					end else if ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , PFE ) then begin
						RemoveGear( GB^.Meks , PFE );
					end;
				end; {if PFE <> Nil}
			end;			
		end;

		RemoveGear( Plot^.Parent^.InvCom , Plot );
	end;

	MatchPlotToAdventure := EverythingOK;
end;

Function InsertStory( Slot,Story: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick STORY into SLOT, selecting Actors and Locations }
	{ as required. If everything is found, insert STORY as an InvCom }
	{ of the SLOT. Otherwise, delete it. }
begin
	InsertStory := MatchPlotToAdventure( Slot , Story , GB , True, True , False );
end;

Function InsertSubPlot( Slot,SubPlot: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick SUBPLOT into SLOT, but better not initialize anything. }
begin
	{ Step One and Only - Attempt to insert this plot into the adventure. }
	InsertSubPlot := MatchPlotToAdventure( Slot , SubPlot , GB , False , False , False );
end;

Function InsertPlot( Slot,Plot: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick PLOT into SLOT, selecting Actors and Locations }
	{ as required. If everything is found, insert PLOT as an InvCom }
	{ of SLOT. Otherwise, delete it. }
	{ If SLOT is a story, copy over grabbed elements and so on. }
var
	Desc: String;
	T,N: Integer;
	P2: GearPtr;
	EverythingOK: Boolean;
begin
	EverythingOK := True;

	{ Step One - Copy element info from the parent story as required. }
	{ If there are any characters requested by this plot, }
	{ check to see if they are currently involved in other plots. If so, }
	{ insertion will fail. }
	if SLOT^.G = GG_Story then begin
		for t := 1 to Num_Plot_Elements do begin
			{ If an element grab is requested, process that now. }
			desc := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if ( desc <> '' ) and ( UpCase( desc[1] ) = 'G' ) then begin
				ExtractWord( desc );
				N := ExtractValue( desc );
				desc := SAttValue( Slot^.SA , 'ELEMENT' + BStr( N ) );
				{ Only copy over the first character of the element description, }
				{ since that's all we need, and also because copying a PREFAB tag }
				{ may result in story elements being unnessecarily deleted. }
				SetSAtt( Plot^.SA , 'ELEMENT' + BStr( T ) + ' <' + desc[1] + '>' );
				SetNAtt( Plot^.NA , NAG_ElementID , T , ElementID( Slot , N ) );
			end;

			{ If this gear is a character, better see whether or not }
			{ it is already involved in a plot. }
			if ( ElementID( Plot , T ) <> 0 ) and ( UpCase( Desc[1] ) = 'C' ) then begin
				{ Clear the Plot's stat for now, to keep it from }
				{ being returned by SeekPlotElement. }
				N := ElementID( Plot , T );
				SetNAtt( Plot^.NA , NAG_ElementID , T , 0 );

				P2 := FindPersonaPlot( FindRoot( Slot ) , N );
				if P2 <> Nil then begin
					EverythingOK := False;
				end;

				SetNAtt( Plot^.NA , NAG_ElementID , T , N );
			end;
		end;
	end;	{ If Slot^.G = GG_Story }

	{ Step Two - Attempt to insert this plot into the adventure. }
	if EverythingOK then begin
		InsertPlot := InitMegaPlot( GB , Slot , Plot ) <> Nil;
	end else begin
		DisposeGear( Plot );
		InsertPlot := False;
	end;
end;


Function InsertGlobalArc( Adventure,ARC: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick ARC into ADVENTURE, selecting Actors and Locations }
	{ as required. If everything is found, insert PLOT as an InvCom }
	{ of the Adventure. Otherwise, delete it. }
begin
	{ Step One and Only - Attempt to insert this plot into the adventure. }
	InsertGlobalArc := MatchPlotToAdventure( Adventure , ARC , GB , True , True , False );
end;

Function InsertStoryArc( Story,Arc: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick ARC into Story, selecting Actors and Locations }
	{ as required. If everything is found, insert PLOT as an InvCom }
	{ of the Story. Otherwise, delete it. }
var
	Desc: String;
	T,N: Integer;
	Plot: GearPtr;
	EverythingOK: Boolean;
begin
	EverythingOK := True;

	{ Step One - Copy element info from the parent story as required. }
	{ If there are any characters requested by this plot, }
	{ check to see if they are currently involved in other plots. If so, }
	{ insertion will fail. }
	if Story^.G = GG_Story then begin
		for t := 1 to Num_Plot_Elements do begin
			{ If an element grab is requested, process that now. }
			desc := SAttValue( Arc^.SA , 'ELEMENT' + BStr( T ) );
			if ( desc <> '' ) and ( UpCase( desc[1] ) = 'G' ) then begin
				ExtractWord( desc );
				N := ExtractValue( desc );
				desc := SAttValue( Story^.SA , 'ELEMENT' + BStr( N ) );
				{ Only copy over the first character of the element description, }
				{ since that's all we need, and also because copying a PREFAB tag }
				{ may result in story elements being unnessecarily deleted. }
				SetSAtt( Arc^.SA , 'ELEMENT' + BStr( T ) + ' <' + desc[1] + '>' );
				SetNAtt( Arc^.NA , NAG_ElementID , T , ElementID( Story , N ) );
			end;

			{ If this gear is a character, better see whether or not }
			{ it is already involved in a plot. }
			if ( ElementID( Arc , T ) <> 0 ) and ( UpCase( Desc[1] ) = 'C' ) then begin
				{ Clear the arc's stat for now, to keep it from }
				{ being returned by SeekPlotElement. }
				N := ElementID( Arc , T );
				SetNAtt( Arc^.NA , NAG_ElementID , T , 0 );

				Plot := FindPersonaPlot( FindRoot( Story ) , N );
				if Plot <> Nil then begin
					EverythingOK := False;
				end;

				SetNAtt( Arc^.NA , NAG_ElementID , T , N );
			end;
		end;
	end;	{ If Story^.G = GG_Story }

	{ Step Two - Attempt to insert this plot into the adventure. }
	if EverythingOK then begin
		InsertStoryArc := MatchPlotToAdventure( Story , ARC , GB , True , True , False );
	end else begin
		DisposeGear( Arc );
		InsertStoryArc := False;
	end;
end;

Function InsertRSC( Source,Frag: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Insert random scene content, then save some information that will be }
	{ needed later. }
var
	it: Boolean;
begin
	InsertRSC := MatchPlotToAdventure( Source , Frag , GB , True , True , False );;
end;

Procedure AdvancePlot( GB: GameBoardPtr; Adv,Plot: GearPtr; N: Integer );
	{ This plot is over... but it's possible that we'll be able to }
	{ move to a sub-plot. }
var
	T: Integer;
	SubPlot,P2,P3,M,M2: GearPtr;
	EName: String;
begin
	{ Find the sub-plot, if one exists. }
	P2 := Plot^.SubCom;
	SubPlot := Nil;
	while ( P2 <> Nil ) do begin
		P3 := P2^.Next;
		if ( P2^.G = GG_Plot ) and ( P2^.S = N ) then SubPlot := P2;

		{ Deal with metascenes as well. }
		if ( P2^.G = GG_MetaScene ) then begin
			{ This metascene has to be deleted. Remove everything from it. }
			if GB^.Scene = P2 then begin
				{ If this scene is the current scene, just turn it into }
				{ a dynamic scene and it'll be deleted automatically }
				{ when the player exits. }
				DelinkGear( Plot^.SubCom , P2 );
				if ( P2^.S >= 1 ) and ( P2^.S <= Num_Plot_Elements ) then P2^.S := ElementID( Plot , P2^.S );
				InsertInvCom( FindRoot( Plot ) , P2 );

			end else begin
				{ Search for global gears in the invcom, storing them as needed. }
				M := P2^.InvCom;
				while M <> Nil do begin
					M2 := M^.Next;
					if NAttValue( M^.NA , NAG_ParaLocation , NAS_OriginalHome ) <> 0 then begin
						DelinkGear( P2^.InvCom , M );
						PutAwayGlobal( GB , M );
					end;
					M := M2;
				end;
				DeleteFrozenLocation( GearName( P2 ) , GB^.Camp^.Maps );
			end;

		end;

		P2 := P3;
	end;

	if SubPlot <> Nil then begin
		{ Copy over all relevant values, then put the sub-plot }
		{ in its correct place. }
		SubPlot^.V := Plot^.V;
		for t := 1 to Num_Plot_Elements do begin
			SetNAtt( SubPlot^.NA , NAG_ElementID , T , ElementID( Plot , T ) );
			EName := 'ELEMENT' + BStr( T );
			SetSAtt( SubPlot^.SA , EName + ' <' + SAttValue( Plot^.SA , EName ) + '>' );
		end;
		DelinkGear( Plot^.SubCom , SubPlot );
		InsertInvCom( Adv , SubPlot );
		InitPlot( FindRoot( Adv ) , SubPlot , GB );
	end;

	{ Finally, set the PLOT's type to absolutely nothing, so it will }
	{ be removed. }
	Plot^.G := GG_AbsolutelyNothing;
end;

Procedure ComponentMenuRedraw;
	{ The redraw for the component selector below. }
begin
	ClrScreen;
	InfoBox( ZONE_Menu );
	InfoBox( ZONE_Info );
	InfoBox( ZONE_Caption );
	GameMsg( 'Select the next component in the core story.', ZONE_Caption , StdWhite );
end;

Function ComponentMenu( CList: GearPtr; ShoppingList: NAttPtr ): GearPtr;
	{ Select one of the components from a menu. }
var
	RPM: RPGMenuPtr;
	C: GearPtr;
	N: Integer;
begin
	RPM := CreateRPGMenu( MenuItem, MenuSelect , ZONE_Menu );
	AttachMenuDesc( RPM , ZONE_Info );
	while ShoppingList <> Nil do begin
		C := RetrieveGearSib( CList , ShoppingList^.S );
		AddRPGMenuItem( RPM , '[' + BStr( ShoppingList^.V ) + ']' + GearName( C ) , ShoppingList^.S , SAttValue( C^.SA , 'DESC' ) );
		ShoppingList := ShoppingList^.Next;
	end;

	N := SelectMenu( RPM , @ComponentMenuRedraw );
	DisposeRPGMenu( RPM );
	ComponentMenu := RetrieveGearSib( CList , N );
end;

Procedure PrepareNewComponent( Story: GearPtr; GB: GameBoardPtr );
	{ Load a new component for this story. }
	Procedure StoreXXRanHistory( C: GearPtr );
		{ Store the details of this component in the story. }
	var
		msg: String;
		T: Integer;
	begin
		AddSAtt( Story^.SA , 'XXRAN_SEQUENCE' , GearName( C ) );
		msg := '';
		for t := 1 to num_plot_elements do begin
			msg := msg + '[' + BStr( T ) + ':' + BStr( ElementID( Story , t ) ) + ']';
		end;
		AddSAtt( Story^.SA , 'XXRAN_SSTATE' , msg );
		msg := '';
		for t := 1 to num_plot_elements do begin
			msg := msg + '[' + BStr( T ) + ':' + BStr( ElementID( C , t ) ) + ']';
		end;
		AddSAtt( Story^.SA , 'XXRAN_PSTATE' , msg );
	end;
var
	All_Comps,C: GearPtr;
	Shopping_List: NAttPtr;
	plot_desc,desc: String;
	t,N: Integer;
	MergeOK,DeleteAllComps: Boolean;
	Function TaskCanConclude: Boolean;
		{ Return TRUE if this task can be a conclusion task, or FALSE otherwise. }
	begin
		TaskCanConclude := AStringHasBString( plot_desc , '+T--' ) or AStringHasBString( plot_desc , '+Tre' );
	end;
begin
	desc := SAttValue( Story^.SA , 'XXRAN_PATTERN' );
	if desc = 'COMP_*.txt' then begin
		All_Comps := Standard_XXRan_Components;
		DeleteAllComps := False;
	end else begin
		All_Comps := AggregatePattern( desc , Series_Directory );
		DeleteAllComps := True;
	end;
	plot_desc := StoryContext( GB , Story );

	{ Either load a regular plot (marked with a #A tag) or one of the two }
	{ episode resolution plots (#w and #l for wins and losses, respectively). }
	if ( NAttValue( Story^.NA , NAG_XXRan , NAS_PlotPointCompleted ) > NAttValue( Story^.NA , NAG_XXRan , NAS_PlotPointGoal ) ) and TaskCanConclude then begin
		if NAttValue( Story^.NA , NAG_XXRan , NAS_PlotPointVictory ) >= NAttValue( Story^.NA , NAG_XXRan , NAS_PlotPointGoal ) then begin
			{ This episode was "won". }
			plot_desc := '#W ' + plot_desc;
		end else begin
			{ This episode was "lost". }
			plot_desc := '#L ' + plot_desc;
		end;
	end else begin
		plot_desc := '#A ' + plot_desc;
	end;

	Shopping_List := CreateComponentList( All_Comps , plot_desc );

	{ If xxran debug is on, print some extra information. }
	if XXRan_Debug then begin
		if NumNAtts( Shopping_List ) < 5 then begin
			DialogMsg( '[DEBUG] Only ' + BStr( NumNatts( Shopping_List ) ) + ' components for "' + plot_desc + '".' );
		end;
	end;

	repeat
		if XXRan_Wizard and ( Shopping_List <> Nil ) then begin
			C := ComponentMenu( All_Comps , Shopping_List );
		end else begin
			C := SelectComponentFromList( All_Comps , Shopping_List );
		end;

		if C <> Nil then begin
			C := CloneGear( C );

			for t := 1 to Num_Plot_Elements do begin
				{ If an element grab is requested, process that now. }
				desc := SAttValue( C^.SA , 'ELEMENT' + BStr( T ) );
				if ( desc <> '' ) and ( UpCase( desc[1] ) = 'G' ) then begin
					ExtractWord( desc );
					N := ExtractValue( desc );
					desc := SAttValue( Story^.SA , 'ELEMENT' + BStr( N ) );
					{ Only copy over the first character of the element description, }
					{ since that's all we need, and also because copying a PREFAB tag }
					{ may result in story elements being unnessecarily deleted. }
					SetSAtt( C^.SA , 'ELEMENT' + BStr( T ) + ' <' + desc[1] + '>' );
					SetNAtt( C^.NA , NAG_ElementID , T , ElementID( Story , N ) );
				end;

			end;

			MergeOK := MatchPlotToAdventure( Story , C , GB , True , True , False );
		end else MergeOK := False;
	until MergeOK or ( Shopping_List = Nil );

	if MergeOK then begin
		{ Assign a ComponentID to the new component. }
		SetNAtt( C^.NA , NAG_XXRan , NAS_ComponentID , NAttValue( Story^.NA , NAG_XXRan , NAS_ComponentID ) );
		AddNAtt( Story^.NA , NAG_XXRan , NAS_ComponentID , 1 );
		SetTrigger( GB , 'UPDATE' );

		{ Store the name of this component for reference. }
		StoreXXRanHistory( C );
	end else begin
		DialogMsg( 'Plot deadend in ' + GearName( Story ) + ': ' + plot_desc );
	end;

	if DeleteAllComps then DisposeGear( All_Comps );
	DisposeNAtt( Shopping_List );
end;

Function PrepareQuestFragment( City,Frag: GearPtr; DoDebug: Boolean ): Boolean;
	{ Attempt to match this quest fragment to the adventure. Quest fragments can }
	{ use a subset of the resources available to other types of content- in }
	{ particular, they can't use character searches and their personas are not }
	{ initialized until the assembly routine that comes later. }
	{ This procedure is responsible for: }
	{ - Locating and initializing elements (via MatchPlotToAdventure) }
	{ - Locating and storing element scenes }
	{ - Storing the element names for later use }
var
	MatchOK: Boolean;
	T,KSID: Integer;
	EDesc,SceneDesc: String;
	Scene: GearPtr;
begin
	{ First, insert the key character as requested. }
	for t := 1 to Num_Plot_Elements do begin
		EDesc := UpCase( SAttValue( Frag^.SA , 'ELEMENT' + BStr( T ) ) );
		if EDesc = 'KEY' then begin
			SetSAtt( Frag^.SA , 'ELEMENT' + BStr( T ) + ' <' + SAttValue( Frag^.SA , 'ELEMENT0' ) + '>' );
			SetSAtt( Frag^.SA , 'SCENE' + BStr( T ) + ' <KEY>' );
			SetNAtt( Frag^.NA , NAG_ElementID , T , NAttValue( Frag^.NA , NAG_ElementID , 0 ) );
		end else if ( EDesc <> '' ) and ( EDesc[1] = 'A' ) then begin
			{ This is an artifact request. If no difficulcy context has been }
			{ defined, add one ourselves. }
			if not AStringHasBString( EDesc , '!' ) then begin
				EDesc := EDesc + ' ' + DifficulcyContext( NAttValue( Frag^.NA , NAG_QuestInfo , NAS_DifficulcyLevel ) );
				SetSAtt( Frag^.SA , 'ELEMENT' + BStr( T ) + ' <' + EDesc + '>' );
			end;
		end;
	end;

	{ Make sure the city really is the city. }
	City := FindRootScene( Nil , City );

	{ Second, locate the rest of the elements. }
	MatchOK := MatchPlotToAdventure( FindROot( City ) , Frag , Nil , FALSE , FALSE , FALSE );

	{ If this worked, get all the needed scenes and store the element names. }
	if MatchOK then begin
		for t := 1 to Num_Plot_Elements do begin
			{ If any scene cannot be found, delete FRAG and set MATCHOK to FALSE. }
			SceneDesc := SAttValue( Frag^.SA , 'SCENE' + BStr( T ) );

			{ We aren't concerned if no scene was defined; nor are we concerned }
			{ if a new scene is requested. Those get added later. }
			if UpCase( SceneDesc ) = 'KEY' then begin
				{ The key scene was requested. }
				KSID := NAttValue( Frag^.NA , NAG_QuestElemScene , 0 );
				if KSID <> 0 then begin
					SetNAtt( Frag^.NA , NAG_QuestElemScene , T , KSID );
					if SAttValue( Frag^.SA , 'ELEMENT' + BStr( T ) ) = '' then begin
						SetSAtt( Frag^.SA , 'ELEMENT' + BStr( T ) + ' <Scene>' );
						SetNAtt( Frag^.NA , NAG_ElementID , T , KSID );
					end;
				end else begin
					if DoDebug then DialogMsg( 'DEBUG Quest error: Key Scene not found not found for ' + GearName( Frag ) + '.' );
					RemoveGear( FindRoot( City )^.InvCom , Frag );
					MatchOK := False;
					Break;
				end;
			end else if ( SceneDesc <> '' ) and not ( HeadMatchesString( 'NEW ' , SceneDesc ) or HeadMatchesString( 'GRAB ' , SceneDesc ) ) then begin
				Scene := SearchForScene( City , Frag , Nil , SceneDesc );
				if Scene <> Nil then begin
					SetNAtt( Frag^.NA , NAG_QuestElemScene , T , Scene^.S );
					if SAttValue( Frag^.SA , 'ELEMENT' + BStr( T ) ) = '' then begin
						SetSAtt( Frag^.SA , 'ELEMENT' + BStr( T ) + ' <Scene>' );
						SetNAtt( Frag^.NA , NAG_ElementID , T , Scene^.S );
						SetSAtt( Frag^.SA , 'NAME_' + BStr( T ) + ' <' + GearName( Scene ) + '>' );
					end;
				end else begin
					if DoDebug then DialogMsg( 'DEBUG Quest error: Scene ' + BStr( T ) + ' not found for ' + GearName( Frag ) + '.' );
					RemoveGear( FindRoot( City )^.InvCom , Frag );
					MatchOK := False;
					Break;
				end;
			end;
		end;
	end else if DoDebug then begin
		DialogMsg( 'DEBUG Quest error: MatchPlotToAdventure Failed.' );
	end;

	PrepareQuestFragment := MatchOK;
end;

Function InsertArenaMission( Source,Mission: GearPtr ): Boolean;
	{ Insert an arena mission into the campaign. }
var
	it: Boolean;
	P: GearPtr;
	Desc: String;
	T: Integer;
begin
	it := MatchPlotToAdventure( Source , Mission , Nil , TRUE , False , False );

	{ If the mission was successfully added, we need to do extra initialization. }
	if it then begin
		{ Alter the DESC string, to contain the element names. }
		Desc := SAttValue( Mission^.SA , 'DESC' );
		for t := 1 to Num_Plot_ELements do begin
			ReplacePat( Desc , '%name' + BStr( T ) + '%' , GearName( Fast_Seek_Element[ 1 , t ] ) );
		end;
		SetSAtt( Mission^.SA , 'DESC <' + Desc + '>' );

		{ Set correct PersonaIDs for all the personas involved. }
		P := Mission^.SubCom;
		while P <> Nil do begin
			if P^.G = GG_Persona then begin
				P^.S := ElementID( Mission , P^.S );
			end;
			P := P^.Next;
		end;
	end;

	InsertArenaMission := it;
end;

initialization
	persona_fragments := AggregatePattern( 'PFRAG_*.txt' , series_directory );
	if persona_fragments = Nil then writeln( 'ERROR!!!' );
	Standard_XXRan_Components := AggregatePattern( 'COMP_*.txt' , series_directory );

finalization
	DisposeGear( persona_fragments );
	DisposeGear( Standard_XXRan_Components );

end.
