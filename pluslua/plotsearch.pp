unit plotsearch;
	{ This unit locates elements for the random plots. }
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
{$LONGSTRINGS ON}

interface

uses gears,locale,texutil;

Function ElementSearch( Scope, Plot: GearPtr; SearchType: Integer; Desc: String; GB: GameBoardPtr ): GearPtr;
Function FactionSearch( Scope, Plot: GearPtr; Desc: String; GB: GameBoardPtr ): GearPtr;

Function MatchPlotToAdventure( Scope,Control,Slot,Plot: GearPtr; GB: GameBoardPtr; Debug: Boolean ): Boolean;


implementation

uses 	gamebook,narration,ghchars,chargen,gearparser,wmonster,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}


Type
	PWSearchResult = Record
		thing: GearPtr;
		match: Integer;
	end;

var
	Fast_Seek_Element: Array [0..1,1..Num_Plot_Elements] of GearPtr;


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

		if ( cmd <> '' ) and ( cmd[1] = '!' ) then begin
			RDesc := RDesc + ' ' + cmd;

			{ If this relative command requires a value, }
			{ copy that over as well. }
			{ The two that don't are !Global and !Lancemate. }
			if ( UpCase( cmd )[2] <> 'G' ) and ( UpCase( cmd )[2] <> 'L' ) then begin
				cmd := ExtractWord( ZeroDesc );
				RDesc := RDesc + ' ' + cmd;
			end;

		end else if ( cmd <> '' ) and ( UpCase( cmd ) <> 'NEVERFAIL' ) then begin
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
				it := it and ( FindRootScene( FindActualScene( GB , FindSceneID( Part , GB ) ) ) = FindRootScene( FindActualScene( GB , FindSceneID( GetFSE( ExtractValue( Desc ) ) , GB ) ) ) );

			end else if ( Q = 'F' ) and ( Plot <> Nil ) then begin
				{ L1 must not equal L2. }
				it := it and ( FindRootScene( FindActualScene( GB , FindSceneID( Part , GB ) ) ) <> FindRootScene( FindActualScene( GB , FindSceneID( GetFSE( ExtractValue( Desc ) ) , GB ) ) ) );

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
				{ Ally. This part must not be an ally }
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

Function CandidateMatchesDesc( Adv,Plot,Part: GearPtr; const IDesc,RDesc: String; GB: GameBoardPtr ): Boolean;
	{ Return TRUE if the supplied gear matches this description }
	{ string, FALSE otherwise. }
var
	Context: String;
	it: Boolean;
begin
	{ DESC should contain a string list of all the stuff we want }
	{ our NPC to have. Things like gender, personality traits, }
	{ et cetera. Most of these things are intrinsic to the NPC, }
	{ but some of them are defined relative to other elements of }
	{ this plot. }

	{ Generate the context string. }
	Context := '';
	AddGearXRContext( GB , Adv , Part , Context , ' ' );

	it := PartMatchesCriteria( Context , IDesc );
	if it and ( Plot <> Nil ) then it := PartMatchesRelativeCriteria( Adv, Plot, Part, GB, RDesc );

	CandidateMatchesDesc := it;
end;

Function ElementSearch( Scope, Plot: GearPtr; SearchType: Integer; Desc: String; GB: GameBoardPtr ): GearPtr;
	{ Search high and low looking for a gear that matches }
	{ the provided search description! }
	{ SearchType is the kind of gear being sought, or 0 for any gear. }
const
	SearchSize = 100;	{ If your search has more than 100 candidates, it's too broad! }
var
	NPC: GearPtr;
	NumMatches: Integer;
	Results: Array of PWSearchResult;
	IDesc,RDesc: String;
	CheckGlobal,SeekLancemate: Boolean;

	Function IsLegalCandidate( P: GearPtr ): Boolean;
		{ Return TRUE if P is a legal choice for this search, or }
		{ FALSE otherwise. }
	begin
		if SearchType = 0 then IsLegalCandidate := True
		else IsLegalCandidate := P^.G = SearchType;
	end;

	Procedure CheckAlongPath( P: GearPtr );
		{ Check along this path looking for characters. If a match is found, }
		{ add it to the array. }
	var
		NID: LongInt;
	begin
		while ( P <> Nil ) and ( NumMatches < SearchSize ) do begin
			if ( P^.G = GG_Character ) and CandidateMatchesDesc( Scope, Plot, P , IDesc , RDesc , GB ) then begin
				{ Next, check to make sure it has an assigned NID. }
				NID := NAttValue( P^.NA , NAG_Narrative , NAS_NID );
				if ( NID <> 0 ) then begin
					Results[ NumMatches ].thing := P;
					Results[ NumMatches ].match := 1;
					Inc( NumMatches );
				end;
			end;
			{ Don't check the contents of the content set- if it hasn't yet been added to the }
			{ adventure, we don't want it. }
			{ Also, don't check the contents of metascenes- either they're already involved in }
			{ a plot or they're off-limits. }
			if ( P^.G <> GG_ContentSet ) and ( P^.G <> GG_MetaScene ) then begin
				CheckAlongPath( P^.SubCom );
				CheckAlongPath( P^.InvCom );
			end;
			P := P^.Next;
		end;
	end;
begin
	{ Step one- size the array. }
	SetLength( Results , SearchSize );

	{ Determine the scope- if searching globablly, do so. }
	CheckGlobal := AStringHasBString( Desc , '!G' );
	if CheckGlobal then Scope := FindRoot( Scope );

	SeekLancemate := AStringHasBString( Desc , '!L' );

	{ Filter the relative description from the instrinsic description. }
	IDesc := Desc;
	RDesc := FilterElementDescription( IDesc );

	{ Step two- search the adventure looking for characters. }
	NumMatches := 0;
	CheckAlongPath( Scope^.SubCom );
	if Scope^.G = GG_Scene then CheckAlongPath( Scope^.InvCom );
	{ Check the gameboard as well, as long as it's not a metascene or a temporary scene. }
	{ Actually, you can go ahead and search temp scenes as long as we're looking for a lancemate. }
	if ( GB <> Nil ) and ( SeekLancemate or not SceneIsTemp( GB^.Scene ) ) then begin
		CheckAlongPath( GB^.Meks );
	end;

	{ Check the invcomponents of the adventure only if global }
	{ NPCs are allowed by the DESC string. }
	if CheckGlobal then begin
		CheckAlongPath( FindRoot( Scope )^.InvCom );
	end;

	if NumMatches > 0 then begin
		NPC := Results[ Random( NumMatches ) ].Thing;
	end else begin
		NPC := Nil;
	end;

	ElementSearch := NPC;
end; { Element Search }

Function FactionSearch( Scope, Plot: GearPtr; Desc: String; GB: GameBoardPtr ): GearPtr;
	{ Search high and low looking for a gear that matches }
	{ the provided search description! }
	{ SearchType is the kind of gear being sought, or 0 for any gear. }
const
	SearchSize = 100;	{ If your search has more than 100 candidates, it's too broad! }
var
	Fac: GearPtr;
	NumMatches: Integer;
	Results: Array of PWSearchResult;
	IDesc,RDesc: String;

	Procedure CheckAlongPath( P: GearPtr );
		{ Check along this path looking for characters. If a match is found, }
		{ add it to the array. }
	var
		NID: LongInt;
	begin
		while ( P <> Nil ) and ( NumMatches < SearchSize ) do begin
			if ( P^.G = GG_Faction ) and CandidateMatchesDesc( Scope, Plot, P , IDesc , RDesc , GB ) then begin
				{ Next, check to make sure it has an assigned NID. }
				NID := NAttValue( P^.NA , NAG_Narrative , NAS_NID );
				if ( NID <> 0 ) then begin
					Results[ NumMatches ].thing := P;
					Results[ NumMatches ].match := 1;
					Inc( NumMatches );
				end;
			end;

			P := P^.Next;
		end;
	end;
begin
	{ Step one- size the array. }
	SetLength( Results , SearchSize );

	{ Factions are InvComs of the adventure, so make sure we're there. }
	Scope := FindRoot( Scope );

	{ Filter the relative description from the instrinsic description. }
	IDesc := Desc;
	RDesc := FilterElementDescription( IDesc );

	{ Step two- search the adventure looking for characters. }
	NumMatches := 0;
	CheckAlongPath( Scope^.InvCom );

	if NumMatches > 0 then begin
		Fac := Results[ Random( NumMatches ) ].Thing;
	end else begin
		Fac := Nil;
	end;

	FactionSearch := Fac;
end; { Faction Search }


Function InitNextPrefabElement( GB: GameBoardPtr; Adventure,Plot: GearPtr; N: Integer ): GearPtr;
	{ Initialize the next element, give it a unique ID number if }
	{ appropriate, then return a pointer to the it. }
var
	E: GearPtr;	{ The Element. }
	Name: String;
	ID: LongInt;
begin
	{ Find the first uninitialized entry in the list. }
	{ This is gonna be our next element. }
	E := Plot^.InvCom;
	While ( E <> Nil ) and ( NAttValue( E^.NA , NAG_Narrative , NAS_NID ) <> 0 ) do begin
		E := E^.Next;
	end;

	if E <> Nil then begin
		InitContentForAdventure( FindRoot( Adventure ), E );

		{ Give our new element a unique ID, and store its ID in the Plot. }
		{ If this is an encounter, also generate a MetaScene ID. }

		if ( E^.G = GG_MetaTerrain ) and ( E^.S = GS_MetaEncounter ) and not AStringHasBString( SAttValue( E^.SA , 'SPECIAL' ) , 'NOMSID' ) then begin
			SetNAtt( E^.NA , NAG_Narrative , NAS_NID , NewNID( Adventure ) );
			ID := NewMetaSceneID( Adventure );
			E^.Stat[ STAT_Destination ] := ID;
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <S Prefab>' );

			{ Maybe set this element's name. }
			Name := GearName( E );
			ReplacePat( Name , '%r%' , RandomName );
			SetSAtt( E^.SA , 'name <' + Name + '>' );

		end else begin
			ID := NewNID( Adventure );
			SetNAtt( E^.NA , NAG_Narrative , NAS_NID , ID );
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <C Prefab>' );

		end;
		SetNAtt( Plot^.NA , NAG_ElementID , N , ID );
	end;
	InitNextPrefabElement := E;
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

Function NewContentNPC( Adv,Story,Plot: GearPtr; desc: String ): GearPtr;
	{ Create a new NPC. Give it whatever traits are needed. }
var
	NPC,Fac: GearPtr;
	FacID,HTID: LongInt;
begin
	{ First, we need to determine the NPC's faction and home town. }
	{ These will be stored as separate elements. }
	FacID := ExtractValue( desc );
	if FacID <> 0 then begin
		Fac := GetFSE( FacID );
		FacID := GetFactionID( Fac );
	end;

	HTID := ExtractValue( desc );
	if HTID <> 0 then HTID := GetFSEID( Story , Plot , HTID );

	{ We have the info. Time to create our NPC. }
	NPC := RandomNPC( Adv , FacID , HTID );

	{ Do the individualization. }
	InitContentForAdventure( FindRoot( Adv ), NPC );
	IndividualizeNPC( Adv , NPC );

	{ Customize the character. }
	{ This is done after individualization because the settings here override }
	{ the settings there. }
	ApplyChardesc( NPC , Desc );

	{ Return the result. }
	NewContentNPC := NPC;
end;

Function PrepareQuestSceneElement( Adventure , Plot: GearPtr; N: Integer ): GearPtr;
	{ We've received a request for a new permanent scene. Assign a SceneID for it. }
	{ Also, copy over the difficulty rating from the plot, and mark all current }
	{ subs and invs as original content. }
	{ Also make sure to give the scene a unique name. }
	Procedure MarkChildrenAsOriginal( LList: GearPtr );
		{ Mark all the children of this quest scene as original, so if it's a }
		{ dungeon other things which get added can be set aside and placed in }
		{ the goal level. }
	begin
		while LList <> Nil do begin
			if NAttValue( LList^.NA , NAG_Narrative , NAS_QuestDungeonPlacement ) = 0 then begin
				SetNAtt( LList^.NA , NAG_NArrative , NAS_QuestDungeonPlacement , NAV_WasQDOriginal );
			end;
			LList := LList^.Next;
		end;
	end;
var
	ID,Tries: Integer;
	QS,PScene: GearPtr;
	BaseName,UniqueName: String;
begin
	ID := NewNID( Adventure );
	SetNAtt( Plot^.NA , NAG_ElementID , N , ID );
	QS := SeekCurrentLevelGear( Plot^.SubCom , GG_MetaScene , N );
	if QS <> Nil then begin
		{ Set the difficulty level, unless this has been overridden. }
		if NAttValue( QS^.NA , NAG_NArrative , NAS_DifficultyLevel ) = 0 then SetNAtt( QS^.NA , NAG_NArrative , NAS_DifficultyLevel , NAttValue( Plot^.NA , NAG_Narrative , NAS_DifficultyLevel ) );

		{ Mark the children as originals. }
		MarkChildrenAsOriginal( QS^.SubCom );
		MarkChildrenAsOriginal( QS^.InvCom );

		{ Assign a unique name for this scene. }
		{ Generate a unique name for this scene. }
		BaseName := SAttValue( QS^.SA , 'NAME' );
		UniqueName := ReplaceHash( BaseName , RandomName );
		Tries := 0;
		repeat
			PScene := SeekGearByName( Adventure , UniqueName );
			if PScene <> Nil then UniqueName := ReplaceHash( BaseName , RandomName );
			Inc( Tries );
		until ( PScene = Nil ) or ( Tries > 500 );

		if Tries > 500 then begin
			{ We tried, and failed, to get a unique name. }
			UniqueName := 'Ique ' + BStr( ID );
			DialogMsg( 'ERROR: Scene ' + GearName( Plot ) + ' (' + BStr( ID ) + ') couldn''t generate unique name.' );
		end;

		SetSAtt( QS^.SA , 'NAME <' + UniqueName + '>' );

	end;
	PrepareQuestSceneElement := QS;
end;

Function FindElement( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ; Debug: Boolean ): Boolean;
	{ Locate and store the Nth element for this plot. }
	{ Return TRUE if a suitable element could be found, or FALSE }
	{ if no suitable element exists in the adventure & this plot }
	{ will have to be abandoned. }
var
	Element: GearPtr;
	Desc,EKind: String;
	OK: Boolean;
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
			{  Also, it should be a character rather than an animal!!! }
			if ( Plot <> Nil ) then desc := ':CHARA :F4USE ' + desc;

			Element := ElementSearch( Adventure , Plot , GG_Character , Desc , GB );

			if Element <> Nil then begin
				{ Store the NPC's ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , NAttValue( Element^.NA , NAG_Narrative , NAS_NID ) );
				Fast_Seek_Element[ 1 , N ] := Element;

			end else begin
				{ No free NPCs were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'S' then begin
			{ This element is a SCENE. Find one. }
			{ Pick one of the free scenes at random. }
			Element := ElementSearch( Adventure , Plot , GG_Scene , Desc , GB );

			if Element <> Nil then begin
				{ Store the Scene ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , NAttValue( Element^.NA , NAG_Narrative , NAS_NID ) );
				Fast_Seek_Element[ 1 , N ] := Element;

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'F' then begin
			{ This element is a FACTION. Find one. }
			{ Pick one of the free scenes at random. }
			Element := FactionSearch( Adventure , Plot , Desc , GB );

			if Element <> Nil then begin
				{ Store the Scene ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , GetFactionID( Element ) );
				Fast_Seek_Element[ 1 , N ] := Element;

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'P' then begin
			{ PreFab element. Check Plot/InvCom and }
			{ retrieve it. }
			Element := InitNextPrefabElement( GB , Adventure , Plot , N );
			Fast_Seek_Element[ 1 , N ] := Element;
			OK := Element <> Nil;

		end else if EKind[1] = 'Q' then begin
			{ Quest Scene. Find the metascene template being used. }
			Element := PrepareQuestSceneElement( Adventure , Plot , N );
			Fast_Seek_Element[ 1 , N ] := Element;
			OK := Element <> Nil;

		end else if EKind[1] = 'A' then begin
			{ Artifact. Select one at random, then deploy it as a prefab element. }
			Element := SelectArtifact( FindRoot( Adventure ) , desc );
			if Element <> Nil then begin
				{ We now want to deploy the artifact as though it were a }
				{ prefab element. }
				Element^.Next := Plot^.InvCom;
				Plot^.InvCom := Element;
				Element^.Parent := Plot;
				InitNextPrefabElement( GB , Adventure , Plot , N );
				Fast_Seek_Element[ 1 , N ] := Element;
				OK := True;
			end else OK := False;

		end else if EKind[1] = 'N' then begin
			{ New NPC. Create and format one, then deploy it as a prefab element. }
			Element := NewContentNPC( Adventure , Plot^.Parent , Plot , desc );
			if Element <> Nil then begin
				{ We now want to deploy the artifact as though it were a }
				{ prefab element. }
				Element^.Next := Plot^.InvCom;
				Plot^.InvCom := Element;
				Element^.Parent := Plot;
				InitNextPrefabElement( GB , Adventure , Plot , N );
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
			end else if Adventure^.G = GG_Scene then begin
				{ Insert the current scope as this element. }
				SetSAtt( PLOT^.SA , 'ELEMENT' + BStr( N ) + ' <S>' );
				SetNAtt( PLOT^.NA , NAG_ElementID , N , RealSceneID( Adventure ) );
				Fast_Seek_Element[ 1 , N ] := Adventure;
				OK := True;

			end else OK := False;
		end;		
	end;

	if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
		if not OK then DialogMsg( 'PLOT ERROR: ' + BStr( N ) + ' Element Not Found! ' + GearName( Plot ) )
		else if desc <> '' then DialogMsg( 'PLOT ELEMENT ' + BStr( N ) + ': ' + BStr( ElementID( Plot , N ) ) + ' ' + GearName( Element ) );
	end;

	FindElement := OK;
end;

Procedure CreateElement( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr );
	{ Create and store the Nth element for this plot. }
var
	Element,Destination,Faction: GearPtr;
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
			Destination := FindActualScene( GB , FindSceneID( Destination , GB ) );
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
			if job = '' then begin
				Element := RandomNPC( FindRoot( Adventure ) , 0 , RealSceneID( FindRootScene( GB^.Scene ) ) );
				{ Do the individualization. }
				IndividualizeNPC( FindRoot( Adventure ) , Element );
				job := SAttValue( Element^.SA , 'job' );
			end else Element := LoadNewNPC( FindRoot( Adventure ) , job , True );
			if Element = Nil then Element := LoadNewNPC( FindRoot( Adventure ) , 'MECHA PILOT' , True );
			SetSAtt( Element^.SA , 'job <' + job + '>' );
			SetSAtt( Element^.SA , 'TEAMDATA <Pass>' );

			{ Customize the character. }
			ApplyChardesc( Element , Desc );

			{ Store the NPC's ID in the plot. }
			ID := NewNID( Adventure );
			SetNAtt( Element^.NA , NAG_Narrative , NAS_NID , ID );
			SetNAtt( Plot^.NA , NAG_ElementID , N , ID );
			Fast_Seek_Element[ 1 , N ] := Element;

		end else begin
			Element := Nil;
			DialogMsg( 'ERROR- CreateElement asked to create element of type ' + EKind +'.' );
			DialogMsg( 'Resultant plot ' + GearName( Plot ) + ' may fail.' );
		end;

		{ After this point, don't expect to use "desc" any more. It may have been }
		{ modified or chopped into pieces above. }

		if Element <> Nil then begin
			InitContentForAdventure( FindRoot( Adventure ), Element );

			if Destination <> Nil then begin
				if GB^.Scene = Destination then begin
					EquipThenDeploy( GB , Element , True );
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





Function DoElementGrabbing( Scope,Control,Slot,Plot: GearPtr ): Boolean;
	{ Attempt to grab elements from the story to insert into the plot. }
	{ Return TRUE if the elements were grabbed successfully, or FALSE }
	{ if they could not be grabbed for whatever reason. }
var
	EverythingOK: Boolean;
	T,N: Integer;
	Desc: String;
begin
	if Control = Nil then Exit( True );
	EverythingOK := True;

	if Scope^.G = GG_CityMood then Slot := Scope;

	if ( Control^.G = GG_Story ) or ( Control^.G = GG_CityMood ) then begin
		for t := 1 to Num_Plot_Elements do begin
			{ If an element grab is requested, process that now. }
			desc := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if ( desc <> '' ) and ( UpCase( desc[1] ) = 'G' ) then begin
				ExtractWord( desc );
				N := ExtractValue( desc );
				desc := SAttValue( Control^.SA , 'ELEMENT' + BStr( N ) );

				if Desc = '' then begin
					DialogMsg( 'ERROR: ' + GearName( Plot ) + ' tried to grab empty element ' + BStr( N ) + ' from ' + GearName( Control ) );
					EverythingOK := False;
				end else begin
					{ Only copy over the first character of the element description, }
					{ since that's all we need, and also because copying a PREFAB tag }
					{ may result in story elements being unnessecarily deleted. }
					SetSAtt( Plot^.SA , 'ELEMENT' + BStr( T ) + ' <' + desc[1] + '>' );
					SetNAtt( Plot^.NA , NAG_ElementID , T , ElementID( Control , N ) );

					{ If this gear is a character, better see whether or not }
					{ it is already involved in a plot. }
					if ( ElementID( Plot , T ) <> 0 ) and ( UpCase( Desc[1] ) = 'C' ) then begin
						{ Clear the Plot's stat for now, to keep it from }
						{ being returned by SeekPlotElement. }
						N := ElementID( Plot , T );
						SetNAtt( Plot^.NA , NAG_ElementID , T , 0 );

						if ElementInUse( Slot^.InvCom , N ) then begin
							EverythingOK := False;
						end;

						SetNAtt( Plot^.NA , NAG_ElementID , T , N );
					end;
				end;
			end;
		end;
	end;	{ If Slot^.G = GG_Story }
	DoElementGrabbing := EverythingOK;
end;


Function MatchPlotToAdventure( Scope,Control,Slot,Plot: GearPtr; GB: GameBoardPtr; Debug: Boolean ): Boolean;
	{ This PLOT gear is meant to be inserted as an INVCOM of Slot. }
	{ Perform the insertion, select unselected elements, and make sure }
	{ that everything fits. }
	{ SLOT is the place to stick the plot. It must be a descendant of the adventure. }
	{ SCOPE is usually the adventure- the the higest level at which element searches will take place. }
	{ CONTROL is the gear which controls this plot, either the story or the mood. May be nil. }
	{ IMPORTANT: PLOT must not already be inserted into SLOT!!! }
	{ This procedure will not alter the adventure beyond the scope of the plot being }
	{ added. Once installed in SLOT, this plot may be deleted without leaving }
	{ anything behind. }
var
	T: Integer;
	E: STring;
	Adventure: GearPtr;
	EverythingOK,OKNow: Boolean;
begin
	{ Error Check }
	if ( Plot = Nil ) or ( Slot = Nil ) then Exit;

	{ Initialize any prefabs and other stuff. }
	InitContentForAdventure( FindRoot( Slot ), Plot );

	{ Attempt to grab the required elements from the Slot. }
	EverythingOK := DoElementGrabbing( Scope , Control , Slot , Plot );
	if not EverythingOK then begin
		DisposeGear( Plot );
		Exit( False );
	end;

	{ We need to stick the PLOT into the SLOT to prevent }
	{ the FindElement procedure from choosing the same item for }
	{ multiple elements. }
	InsertInvCom( Slot , Plot );

	{ Locate the adventure. It must be the root of Slot. }
	Adventure := FindRoot( Slot );

	{ Select Actors }
	{ First clear the FastSeek array. }
	for t := 1 to Num_Plot_Elements do begin
		Fast_Seek_Element[ 0 , t ] := Nil;
		Fast_Seek_Element[ 1 , t ] := Nil;
	end;

	if ( Slot^.G = GG_Story ) then begin
		for t := 1 to Num_Plot_Elements do begin
			Fast_Seek_Element[ 0 , t ] := SeekPlotElement( Adventure , Slot , T , GB );
		end;
	end else if Scope^.G = GG_CityMood then begin
		{ We've been handed a mood rather than a scene. }
		for t := 1 to Num_Plot_Elements do begin
			Fast_Seek_Element[ 0 , t ] := SeekPlotElement( Adventure , Scope , T , GB );
		end;
		{ The parent of the mood should be the city it's installed in. This is what we want as }
		{ our scope. }
		Scope := Scope^.Parent;
	end;

	for t := 1 to Num_Plot_Elements do begin
		{ Check all the plot elements. Some of these may have been inherited from the SLOT. }
		if ( ElementID( Plot , T ) = 0 ) and EverythingOK then begin
			OkNow := FindElement( Scope , Plot , T , GB , Debug );

			if ( not OkNow ) and AStringHasBString( SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) ) , 'NEVERFAIL' ) then begin
				CreateElement( Adventure , Plot , T , GB );
				if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
					DialogMsg( '...but NEVERFAIL has saved the day! ID=' + BStr( ElementID( Plot , T ) ) );
				end;

				OkNow := ElementID( Plot , t ) <> 0;
			end;
		end else if EverythingOK then begin
			Fast_Seek_Element[ 1 , T ] := SeekPlotElement( Adventure , Plot , T , GB );

			{ If the element wasn't found, this will cause an error... unless, }
			{ of course, we're dealing with a MetaScene or a new Quest Scene. }
			{ These are the only element types that can not exist and still be valid. }
			E := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if ( E <> '' ) and ( E[1] = 'Q' ) then begin
				OkNow := True;
			end else if ( E = '' ) or ( ( UpCase( E[1] ) <> 'S' ) and ( ElementID( Plot , t ) > 0 ) ) then begin
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
			if ElementID( Plot , T ) <> 0 then DialogMsg( BStr( T ) + '=> ' + BStr( ElementID( Plot , T ) ) );
		end;

		EverythingOK := EverythingOK and OKNow;
	end;

	if EverythingOK then begin
		{ The plot has been successfully installed into the }
		{ adventure. Store the names of all known elements. They might come in handy later. }
		for t := 1 to Num_Plot_Elements do begin
			{ Store the name of this element, which should still be stored in }
			{ the FSE array. }
			if GB <> Nil then begin
				SetSAtt( Plot^.SA , 'NAME_' + BStr( T ) + ' <' + ElementName( Adventure , Plot , T , GB ) + '>' );
			end else begin
				SetSAtt( Plot^.SA , 'NAME_' + BStr( T ) + ' <' + GearName( Fast_Seek_Element[ 1 , t ] ) + '>' );
			end;
		end;

		{ Also store the Controller's ID, if appropriate. }
		if Control <> Nil then SetNAtt( Plot^.NA , NAG_Narrative , NAS_ControllerID , NAttValue( Control^.NA , NAG_Narrative , NAS_NID ) );

	end else begin
		{ This plot won't fit in this adventure. Dispose of it. }
		RemoveGear( Plot^.Parent^.InvCom , Plot );
	end;

	MatchPlotToAdventure := EverythingOK;
end;


end.
