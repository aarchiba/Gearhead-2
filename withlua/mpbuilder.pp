unit mpbuilder;
	{ MEGA PLOT ASSEMBLE! It's like a Voltron of narrative content! }
	{ This unit contains the functions and procedures for creating }
	{ big amalgamations of components. }
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

uses gears,locale,narration;

Type
	ElementDesc = Record
		EType: Char;
		EValue: LongInt;
	end;
	{ I feel just like Dmitri Mendelev writing this... }
	ElementTable = Array [1..Num_Plot_Elements] of ElementDesc;

var
	Sub_Plot_List: GearPtr;


Procedure ReplaceStrings( Part: GearPtr; Dictionary: SAttPtr );
Function ComponentMenu( CList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;
Procedure ClearElementTable( var ET: ElementTable );

Function ExpandDungeon( Dung: GearPtr ): GearPtr;
Procedure ConnectScene( Scene: GearPtr; DoInitExits: Boolean );

Function InitMegaPlot( GB: GameBoardPtr; Scope,Slot,Plot: GearPtr; Threat: Integer ): GearPtr;

Function LoadQuestFragments: GearPtr;
Function AddQuest( Adv,City,QPF_Proto: GearPtr; var Quest_Frags: GearPtr; QReq: String ): Boolean;


implementation

uses playwright,texutil,gamebook,gearparser,ghchars,randmaps,
	uiconfig,wmonster,rpgdice,ghprop,ability,
{$IFDEF ASCII}
	vidgfx,vidmenus;
{$ELSE}
	sdlgfx,sdlmenus;
{$ENDIF}

Const
	Num_Sub_Plots = 8;

Var
	standard_trigger_list: SAttPtr;
	changes_used_so_far: String;
	MasterEntranceList: GearPtr;


Procedure ComponentMenuRedraw;
	{ The redraw for the component selector below. }
begin
	ClrScreen;
	InfoBox( ZONE_Menu );
	InfoBox( ZONE_Info );
	InfoBox( ZONE_Caption );
	GameMsg( 'Select the next component in the core story.', ZONE_Caption , StdWhite );
	RedrawConsole;
end;

Function ComponentMenu( CList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;
	{ Select one of the components from a menu. }
var
	RPM: RPGMenuPtr;
	C: GearPtr;
	N: Integer;
	SL: NAttPtr;
begin
	RPM := CreateRPGMenu( MenuItem, MenuSelect , ZONE_Menu );
	AttachMenuDesc( RPM , ZONE_Info );
	SL := ShoppingList;
	while SL <> Nil do begin
		C := RetrieveGearSib( CList , SL^.S );
		AddRPGMenuItem( RPM , '[' + BStr( SL^.V ) + ']' + GearName( C ) , SL^.S , SAttValue( C^.SA , 'DESC' ) );
		SL := SL^.Next;
	end;

	N := SelectMenu( RPM , @ComponentMenuRedraw );
	SetNAtt( ShoppingList , 0 , N , 0 );
	DisposeRPGMenu( RPM );
	ComponentMenu := RetrieveGearSib( CList , N );
end;

Procedure ClearElementTable( var ET: ElementTable );
	{ Clear this table's stored elements by setting all IDs }
	{ to zero. }
var
	t: Integer;
begin
	for t := 1 to Num_Plot_Elements do begin
		ET[t].EValue := 0;
	end;
end;


Procedure ReplaceStrings( Part: GearPtr; Dictionary: SAttPtr );
	{ We have a dictionary of substitute strings, and a part to do the replacements on. }
var
	S: SAttPtr;
begin
	S := Part^.SA;
	while S <> Nil do begin
		ApplyDictionaryToString( S^.Info , Dictionary );
		S := S^.Next;
	end;
end;

Procedure InitListStrings( LList: GearPtr; Dictionary: SAttPtr );
	{ Run LList, all of its siblings and children, through the ReplaceStrings }
	{ procedure. }
begin
	while LList <> Nil do begin
		ReplaceStrings( LList , Dictionary );
		InitListStrings( LList^.SubCom , Dictionary );
		InitListStrings( LList^.InvCom , Dictionary );
		LList := LList^.Next;
	end;
end;


Function IsStandardTrigger( const S_Head: String ): Boolean;
	{ Return TRUE if S_Head is one of the standard triggers, or FALSE if it }
	{ isn't. }
var
	ST: SAttPtr;
	MatchFound: Boolean;
begin
	{ Go through the list of standard triggers; stop when we find a match. }
	ST := standard_trigger_list;
	MatchFound := False;
	while ( ST <> Nil ) and not MatchFound do begin
		if HeadMatchesString( ST^.Info , S_Head ) then MatchFound := True;
		ST := ST^.Next;
	end;
	IsStandardTrigger := MatchFound;
end;


Function ExpandDungeon( Dung: GearPtr ): GearPtr;
	{ Expand this dungeon. Return the "goal scene", which is the lowest level generated. }
	{ Add sub-levels, branches, and goal requests. }
	{ Note that this procedure will not assign SceneIDs nor will it connect the levels }
	{ with entrances. }
var
	name_base,type_base: String;
	branch_number: Integer;
	sub_scenes: GearPtr;
	LowestLevel: GearPtr;
	Function ExtractSubScenes: GearPtr;
		{ Remove any scenes that are subcoms of the dungeon, and }
		{ return them in a list. }
	var
		it,S,S2: GearPtr;
	begin
		it := Nil;
		S := Dung^.SubCom;
		while S <> Nil do begin
			S2 := S^.Next;
			if S^.G = GG_Scene then begin
				DelinkGear( Dung^.SubCom , S );
				AppendGear( it , S );
			end;
			S := S2;
		end;
		ExtractSubScenes := it;
	end;
	Procedure EliminateClonedScenes( DL: GearPtr );
		{ When cloning the prototype dungeon level, don't copy }
		{ the sub-scenes as well. }
	var
		S,S2: GearPtr;
	begin
		S := DL^.SubCom;
		while S <> Nil do begin
			S2 := S^.Next;
			if S^.G = GG_Scene then begin
				RemoveGear( DL^.SubCom , S );
			end;
			S := S2;
		end;
	end;
	Procedure AddNewDungeonLevel( S: GearPtr; Branch: Integer );
	var
		S2,T: GearPtr;
	begin
		S2 := CloneGear( S );
		{ Eliminate any sub-scenes of S2. }
		EliminateClonedScenes( S2 );
		InsertSubCom( S , S2 );
		{ We don't want to use the main dungeon entrance type for this entrance, }
		{ so copy the DEntrance string instead. }
		SetSAtt( S2^.SA , 'ENTRANCE <' + SAttValue( S^.SA , 'DENTRANCE' ) + '>' );

		{ Increase the dungeon level. }
		AddNAtt(  S2^.NA , NAG_Narrative , NAS_DungeonLevel , 1 );
		if NAttValue( S2^.NA , NAG_Narrative , NAS_DungeonLevel ) > NAttValue( LowestLevel^.NA , NAG_Narrative , NAS_DungeonLevel ) then LowestLevel := S2;
		SetNAtt( S2^.NA , NAG_Narrative , NAS_DungeonBranch , Branch );

		{ Increase the difficulcy level. }
		T := S2^.SubCom;
		while T <> Nil do begin
			if ( T^.G = GG_Team ) and ( T^.Stat[ STAT_WanderMon ] > 0 ) then begin
				T^.Stat[ STAT_WanderMon ] := T^.Stat[ STAT_WanderMon ] + 1 + Random( 3 ) + Random( 2 );

				{ Add the context description for the difficulcy level. }
				SetSAtt( S2^.SA , 'type <' + type_base + ' ' + DifficulcyContext( T^.Stat[ STAT_WanderMon ] ) );

			end;
			T := T^.Next;
		end;
	end;
	Procedure ExpandThisLevel( S: GearPtr );
		{ Search for dungeons among the adventure's scenes. If you find any, }
		{ maybe expand them by adding sub-dungeons. }
	const
		Branch_Suffix: Array [1..10] of char = ( 'a','b','c','d','e','f','g','h','i','j' );
		dungeon_goal_content_string = 'SOME 1 # SUB *DUNGEON_GOAL';
	var
		S2: GearPtr;
		Branch: Integer;
	begin
		Branch := NAttValue( S^.NA , NAG_Narrative , NAS_DungeonBranch );
		if ( S^.G = GG_Scene ) and AStringHasBString( SAttValue( S^.SA , 'TYPE' ) , 'DUNGEON' ) and ( SAttValue( S^.SA , 'DENTRANCE' ) <> '' ) then begin
			if NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) < ( RollStep( 3 ) + 1 ) then begin
				{ Maybe add a branch. }
				AddNewDungeonLevel( S , Branch );

				if ( Random( 5 ) = 1 ) and ( Branch_Number < 9 ) then begin
					AddNewDungeonLevel( S , Branch_Number + 1 );
					Inc( Branch_Number );
				end;
			end else begin
				{ If not adding a deeper level, add DungeonGoal content. }
				AddSAtt( S^.SA , 'CONTENT' , ReplaceHash( dungeon_goal_content_string , BSTr( NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) * 10 + 15 ) ) )
			end;

			{ Name the dungeon. }
			if Branch = 0 then begin
				SetSAtt( S^.SA , 'name <' + name_base + ', L' + BStr( NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) + 1 ) );
			end else begin
				SetSAtt( S^.SA , 'name <' + name_base + ', L' + BStr( NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) + 1 )  + Branch_Suffix[ Branch ] );
			end;
		end;
		S2 := S^.SubCom;
		while S2 <> Nil do begin
			ExpandThisLevel( S2 );
			S2 := S2^.Next;
		end;
	end;
begin
	{ Record some information, initialize some variables. }
	name_base := GearName( Dung );
	if Full_RPGWorld_Info then DialogMsg( 'Expanding ' + name_base );
	SetSAtt( Dung^.SA , 'DUNGEONNAME <' + name_base + '>' );
	type_base := SAttValue( Dung^.SA , 'TYPE' );
	sub_scenes := ExtractSubScenes;
	LowestLevel := Dung;
	Branch_Number := 0;

	ExpandThisLevel( Dung );

	if Sub_Scenes <> Nil then InsertSubCom( lowestLevel , Sub_Scenes );

	ExpandDungeon := lowestlevel;
end;



Procedure ConnectScene( Scene: GearPtr; DoInitExits: Boolean );
	{ SCENE needs to be connected to its parent scene. This means that any }
	{ entrances in PARENT pointing to SCENE have to be given the correct }
	{ destination number, and any entrances in SCENE leading back to PARENT }
	{ also have to be given the correct destination number. }
	{ PRECON: Scene and its parent must have already been given scene IDs. }
	Function FindEntranceByName( EG: GearPtr; Name: String ): GearPtr;
		{ Find an entrance with the provided name. }
		{ This may be in one of the parent scene's subcoms, or one of its }
		{ map feature's subcoms or invcoms. }
	var
		it: GearPtr;
	begin
		it := Nil;
		Name := UpCase( Name );
		while ( EG <> Nil ) and ( it = Nil ) do begin
			if ( EG^.G = GG_MetaTerrain ) and ( UpCase( SAttValue( EG^.SA , 'NAME' ) ) = Name ) then it := EG
			else if ( EG^.G = GG_MapFeature ) then begin
				it := FindEntranceByName( EG^.SubCom , Name );
				if ( it = Nil ) then it := FindEntranceByName( EG^.InvCom , Name );
			end;
			EG := EG^.Next;
		end;
		FindEntranceByName := it;
	end;
	Procedure InitExits( S,E: GearPtr );
		{ Locate exits with a nonzero destination, then give them the proper }
		{ destination of the parent scene. }
	begin
		while E <> Nil do begin
			if E^.G = GG_MapFeature then begin
				InitExits( S , E^.SubCom );
				InitExits( S , E^.InvCom );
			end else if ( E^.G = GG_MetaTerrain ) and ( E^.Stat[ STAT_Destination ] <> 0 ) then begin
				if ( S^.Parent^.G = GG_Scene ) then begin
					E^.Stat[ STAT_Destination ] := S^.Parent^.S;
				end else if S^.Parent^.G = GG_MetaScene then begin
					{ We must be dealing with a quest scene. No problem- }
					{ I know exactly where its SceneID is. }
					E^.Stat[ STAT_Destination ] := ElementID( S^.Parent^.Parent , S^.Parent^.S );
				end;
			end;

			E := E^.Next;
		end;
	end;
var
	E,Loc: GearPtr;
	Entrance,EName: String;
begin
	{ Insert entrance to super-scene. }
	E := FindEntranceByName( Scene^.Parent^.SubCom , GearName( Scene ) );
	if E = Nil then begin
		Entrance := SAttValue( Scene^.SA , 'DUNGEONNAME' );
		if Entrance <> '' then begin
			E := FindEntranceByName( Scene^.Parent^.SubCom , Entrance );
		end;
	end;
	if ( E <> Nil ) and ( E^.G = GG_MetaTerrain ) then begin
		{ A named entrance was found. Initialize it. }
		E^.Stat[ STAT_Destination ] := Scene^.S;
	end else begin
		{ No entrance for this scene was specified. Better create one. }
		E := FindNextComponent( MasterEntranceList , SAttValue( Scene^.SA , 'ENTRANCE' ) );
		if E <> Nil then begin
			E := CloneGear( E );
			if ( E^.S = GS_MetaBuilding ) or ( E^.S = GS_MetaEncounter ) then begin
				EName := SAttValue( Scene^.SA , 'DUNGEONNAME' );
				if EName = '' then EName := GearName( Scene );
				SetSAtt( E^.SA , 'NAME <' + EName + '>' );
			end;
			E^.Stat[ STAT_Destination ] := Scene^.S;
			if Scene^.Parent^.G <> GG_World then E^.Scale := Scene^.Parent^.V;
			if NAttValue( Scene^.NA , NAG_LOcation , NAS_X ) <> 0 then begin
				SetNAtt( E^.NA , NAG_Location , NAS_X , NAttValue( Scene^.NA , NAG_LOcation , NAS_X ) );
				SetNAtt( E^.NA , NAG_Location , NAS_Y , NAttValue( Scene^.NA , NAG_LOcation , NAS_Y ) );
			end;

			{ Insert "E" as an InvCom of the parent scene. }
			{ If E isn't a building or the parent scene isn't a world, }
			{ also insert a subzone for E so it won't be stuck randomly somewhere. }
			if ( E^.S = GS_MetaBuilding ) or ( E^.S = GS_MetaEncounter ) or ( Scene^.Parent^.G = GG_World ) then begin
				InsertInvCom( Scene^.Parent , E );
			end else begin
				Loc := NewSubZone( Scene^.Parent );
				InsertSubCom( Loc , E );
			end;
		end;
	end;

	{ Initialize exits back to the upper level. }
	if DoInitExits then begin
		InitExits( Scene , Scene^.SubCom );
		InitExits( Scene , Scene^.InvCom );
	end;
end;

Procedure PrepQuestDungeon( Adv,SceneProto: GearPtr );
	{ Prepare this dungeon, please. To do this we'll need to expand the dungeon }
	{ by several levels, assign unique IDs to all our new scenes, and connect }
	{ them all to each other. }
	{ The SceneID which has already been assigned will be the SceneID of the }
	{ goal level. The ScenePrototype, which will serve as the entry level, }
	{ will be given a new SceneID. Make sure that you use this new SceneID }
	{ for assigning the entrance. }
	{ The procedure for expanding a quest dungeon is as follows: }
	{ 1 - Remove non-original subs and invs, saving them for the goal level. }
	{ 2 - Expand the dungeon. }
	{ 3 - Assign SceneIDs as needed and connect the scenes. }
	{     At the same time, record the ID of the entry level. }
	{ 4 - Reinstall the subs and invs from step 1 into the goal level. }
var
	GoalLevel,NOSubs,NOInvs: GearPtr;
	EntryLevelID: Integer;
	Procedure AssignSceneIDs( SList: GearPtr );
		{ Assign unique IDs to all the scenes in this list and all of }
		{ their children scenes. Also do the connections, as long as we're here. }
		{ On top of that, record the entry level ID. Got all that? Good. }
	begin
		while SList <> Nil do begin
			if ( SList^.G = GG_Scene ) then begin
				if SList <> GoalLevel then SList^.S := NewNID( Adv );

				{ Record the entry level ID. }
				SetNAtt( SList^.NA , NAG_Narrative , NAS_DungeonEntrance , EntryLevelID );

				ConnectScene( SList , True );
			end;
			if SList <> GoalLevel then AssignSceneIDs( SList^.SubCom );
			SList := SList^.next;
		end;
	end;
	Procedure InitPrototype;
		{ The prototype must be initialized. }
		{ Things to do: }
		{ - Set the L1 Difficulty rating }
		{ - Strip out the non-original SubComs and InvComs. }
		Function StripNonOriginals( var LList: GearPtr ): GearPtr;
			{ Remove anything from this list that doesn't have the WasQDOriginal tag. }
			{ Return the list of removed items. }
		var
			LL,LL2,OutList: GearPtr;
		begin
			LL := LList;
			OutList := Nil;
			while LL <> Nil do begin
				LL2 := LL^.Next;
				if NAttValue( LL^.NA , NAG_Narrative , NAS_QuestDungeonPlacement ) <> NAV_WasQDOriginal then begin
					DelinkGear( LList , LL );
					AppendGear( OutList , LL );
				end;
				LL := LL2;
			end;
			StripNonOriginals := OutList;
		end;
	var
		Team: GearPtr;
	begin
		{ Assign the Difficulty number. }
		Team := SceneProto^.SubCom;
		while Team <> Nil do begin
			if ( Team^.G = GG_Team ) and ( Team^.Stat[ STAT_WanderMon ] > 0 ) then begin
				Team^.Stat[ STAT_WanderMon ] := NAttValue( SceneProto^.NA , NAG_Narrative , NAS_DifficultyLevel ) - 10;
				if Team^.Stat[ STAT_WanderMon ] < 4 then Team^.Stat[ STAT_WanderMon ] := 2 + Random( 3 );
			end;
			Team := Team^.Next;
		end;

		{ Strip out the non-original subs and invs. }
		NOSubs := StripNonOriginals( SceneProto^.SubCom );
		NOInvs := StripNonOriginals( SceneProto^.InvCom );
	end;
	Procedure ReinstallSubsAndInvs;
		{ Reinstall the subs and invs, placing them in either the goal or the }
		{ entry levels. }
	var
		part: GearPtr;
	begin
		{ Begin with the subs. }
		while NoSubs <> Nil do begin
			part := NoSubs;
			DelinkGear( NoSubs , part );
			if NAttValue( Part^.NA , NAG_Narrative , NAS_QuestDungeonPlacement ) = NAV_ForEntryLevel then begin
				InsertSubCom( SceneProto , part );
			end else begin
				InsertSubCom( GoalLevel , part );
			end;
		end;

		{ Finish with the invs. }
		while NOInvs <> Nil do begin
			part := NoInvs;
			DelinkGear( NoInvs , part );
			if NAttValue( Part^.NA , NAG_Narrative , NAS_QuestDungeonPlacement ) = NAV_ForEntryLevel then begin
				InsertInvCom( SceneProto , part );
			end else begin
				InsertInvCom( GoalLevel , part );
			end;
		end;
	end;
begin
	{ **************** }
	{ *** STEP ONE *** }
	{ **************** }
	{ Start by initializing the dungeon prototype. }
	InitPrototype;

	{ **************** }
	{ *** STEP TWO *** }
	{ **************** }
	{ Next expand the dungeon. }
	GoalLevel := ExpandDungeon( SceneProto );

	{ ****************** }
	{ *** STEP THREE *** }
	{ ****************** }
	{ Next, pass out the UniqueIDs. }
	{ Also take this opportunity to connect everything. }
	SceneProto^.S := NewNID( Adv );
	EntryLevelID := SceneProto^.S;
	AssignSceneIDs( SceneProto^.SubCom );

	{ ***************** }
	{ *** STEP FOUR *** }
	{ ***************** }
	{ Re-insert the NOSubs and NOInvs into the finished dungeon. }
	ReinstallSubsAndInvs;
end;


Procedure InstallQuestScenes( Adv , City , Quest: GearPtr );
	{ QUEST probably contains a number of metascenes which we have to deal with. }
	{ If these are newly-defined scenes, they get placed in the adventure. Otherwise }
	{ they get combined with existing scenes. }
	{ 1 - Locate the destination for each scene. }
	{   - If a destination cannot be found, assign it to the city. }
	{   - Clear the PLACE attribute after reading it. }
	{ 2 - Move scene to its destination, and change type. }
	{   - Perform additional initialization. }
	{ 3 - Expand dungeons. }
	{   - If this isn't a dungeon, initialize any WMon teams that may exist. }
	{   - Element ID will be the SceneID of the goal level. }
	{ 4 - Locate and initialize entrances. }
	{   - Make sure dungeon entrances point to the entrance, not the goal level. }
	{   - If no entrance can be found, use default ConnectScene procedure. }
	{ 5 - Locate and initialize exits. }
	Procedure PrepWMonTeams( Scene: GearPtr );
		{ Check for monster teams. Set appropriate threat levels. }
	var
		Team: GearPtr;
	begin
		Team := Scene^.SubCom;
		while Team <> Nil do begin
			if ( Team^.G = GG_Team ) and ( Team^.Stat[ STAT_WanderMon ] > 0 ) then begin
				Team^.Stat[ STAT_WanderMon ] := NAttValue( Scene^.NA , NAG_Narrative , NAS_DifficultyLevel );
				if Team^.Stat[ STAT_WanderMon ] < 3 then Team^.Stat[ STAT_WanderMon ] := 3;
			end;
			Team := Team^.Next;
		end;
	end;
	Procedure InitializeEntrance( Scene: GearPtr; SIDtoSeek: Integer );
		{ Initialize the entrances for this scene. Note that because of dungeons, }
		{ the SceneID to seek might not be the same as the current SceneID of the }
		{ scene. Therefore, search for the provided SceneID, but set the SceneID }
		{ of the provided scene. }
	var
		Entrance: GearPtr;
		EDesig: String;
		FoundAnEntrance: Boolean;
	begin
		{ Haven't started... therefore, we haven't found an entrance yet. }
		FoundAnEntrance := False;

		{ Create the designation that we're looking for. }
		EDesig := 'ENTRANCE ' + BStr( SIDtoSeek );

		{ Now that we have this, start searching for entrances until we }
		{ run out of them. There may be more than one. }
		repeat
			ENtrance := SeekGearByDesig( Quest , EDesig );
			if ENtrance = Nil then begin
				Entrance := SeekGearByDesig( Adv , EDesig );
			end;

			if Entrance <> Nil then begin
				FoundAnEntrance := True;
				Entrance^.Stat[ STAT_Destination ] := Scene^.S;
				SetSAtt( Entrance^.SA , 'DESIG <FINAL' + BStr( Scene^.S ) + '>' );
			end;

		until Entrance = Nil;

		{ If we haven't found any entrances, or if we're requesting one, }
		{ call the automatic scene connector. }
		if ( SAttValue( Scene^.SA , 'ENTRANCE' ) <> '' ) or not FoundAnEntrance then begin
			{ Don't bother initializing the exits, because we're doing that ourselves below. }
			ConnectScene( Scene , False );
		end;
	end;
	Procedure InitExits( S,E: GearPtr );
		{ Locate exits with a nonzero destination, then give them the proper }
		{ destination of the parent scene. }
	begin
		while E <> Nil do begin
			if E^.G = GG_MapFeature then begin
				InitExits( S , E^.SubCom );
				InitExits( S , E^.InvCom );
			end else if ( E^.G = GG_MetaTerrain ) and ( E^.Stat[ STAT_Destination ] = -1 ) then begin
				if ( S^.Parent^.G = GG_Scene ) then begin
					E^.Stat[ STAT_Destination ] := S^.Parent^.S;
				end else if S^.Parent^.G = GG_MetaScene then begin
					{ We must be dealing with a quest scene. No problem- }
					{ I know exactly where its SceneID is. }
					E^.Stat[ STAT_Destination ] := ElementID( S^.Parent^.Parent , S^.Parent^.S );
				end;
			end;

			E := E^.Next;
		end;
	end;
var
	QS,QS2,Dest: GearPtr;
	EDesc,DDesc: String;
	N,EIn: Integer;
begin
	{ Loop through all the subcoms looking for potential quest scenes. }
	QS := Quest^.SubCom;
	while QS <> Nil do begin
		QS2 := QS^.Next;

		if QS^.G = GG_MetaScene then begin
			{ Find out whether this is a quest scene or not. If not, }
			{ then it's just a list of contents to stuff into one of the }
			{ pre-existing scenes. }
			EDesc := SAttValue( Quest^.SA , 'ELEMENT' + BStr( QS^.S ) );
			if ( EDesc <> '' ) and ( UpCase( EDesc[1] ) = 'Q' ) then begin
				{ **************** }
				{ *** STEP ONE *** }
				{ **************** }
				{ We've got a live one. Start by locating the destination. }
				DDesc := SAttValue( Quest^.SA , 'PLACE' + BStr( QS^.S ) );
				N := ExtractValue( DDesc );
				Dest := SeekPlotElement( Adv , Quest , N , Nil );
				if ( Dest = Nil ) or not IsAScene( Dest ) then Dest := City;
				{ Remove the PLACE string, so the element placer doesn't try to move it. }
				SetSAtt( Quest^.SA , 'PLACE' + BStr( QS^.S ) + ' <>' );

				{ **************** }
				{ *** STEP TWO *** }
				{ **************** }
				{ Move the new scene to its destination. Change it from a metascene }
				{ into an actual scene. Update its element description in the quest. }
				DelinkGear( Quest^.SubCom , QS );
				InsertSubCom( Dest , QS );
				{ Record the element index. }
				EIn := QS^.S;
				SetSAtt( Quest^.SA , 'ELEMENT' + BStr( EIn ) + ' <S>' );
				QS^.G := GG_Scene;
				QS^.S := ElementID( Quest , EIn );

				{ Also copy over the HABITAT, if this scene doesn't have one. }
				if SAttValue( QS^.SA , 'HABITAT' ) = '' then SetSAtt( QS^.SA , 'HABITAT <' + SAttValue( City^.SA , 'HABITAT' ) + '>' );

				{ ****************** }
				{ *** STEP THREE *** }
				{ ****************** }
				{ If this scene is a dungeon, expand it. The current SceneID will be }
				{ retained by the goal level; check QS^.S to find the ID of the entry. }
				if AStringHasBString( SAttValue( QS^.SA , 'TYPE' ) , 'DUNGEON' ) then PrepQuestDungeon( Adv, QS )
				else PrepWMonTeams( QS );

				{ ***************** }
				{ *** STEP FOUR *** }
				{ ***************** }
				{ Locate and initialize the scene's entrance. }
				{ Just in case this is a dungeon, don't forget to use QS^.S rather than }
				{ the ElementID. }
				InitializeEntrance( QS , ElementID( Quest , EIn ) );

				{ ***************** }
				{ *** STEP FIVE *** }
				{ ***************** }
				{ Locate and initialize the scene's exits. These should point to the }
				{ parent scene. }
				InitExits( QS , QS^.SubCom );
				InitExits( QS , QS^.InvCom );
			end;
		end;

		QS := QS2;
	end;
end;

Procedure DeployQuest( Adv , City , Quest: GearPtr );
	{ Deploy this quest. }
	Procedure ConvertPersonas;
		{ Change the quest personas from plot-style element-indexed ones to }
		{ regular style CID-indexed ones. }
	var
		P: GearPtr;
	begin
		P := Quest^.SubCom;
		while P <> Nil do begin
			if P^.G = GG_Persona then begin
				P^.S := ElementID( Quest , P^.S );
			end;
			P := P^.Next;
		end;
	end;
begin
	{ Remove the quest from the adventure, and stick it into the city. }
	DelinkGear( Adv^.InvCom , Quest );
	InsertSubCom( City , Quest );

{	PrepAllPersonas( Adv , Quest , Nil , NAttValue( Adv^.NA , NAG_Narrative , NAS_MaxPlotLayer ) + 1 );}
	ConvertPersonas;
	InstallQuestScenes( Adv , City , Quest );
{	MoveElements( Nil , Adv , Quest , True );}
end;

Function InitMegaPlot( GB: GameBoardPtr; Scope,Slot,Plot: GearPtr; Threat: Integer ): GearPtr;
	{ We've just been handed a prospective megaplot. }
	{ Create all subplots, and initialize everything. }
	{ 1 - Create list of components }
	{ 2 - Merge all components into single plot }
	{ 3 - Insert persona fragments }
	{ 4 - Deploy elements as indicated by PLACE strings }
var
	SPList,FakeFrags: GearPtr;
	PlotID,LayerID: LongInt;
	FakeParams: ElementTable;
begin

end;


Function LoadQuestFragments: GearPtr;
	{ Load and initialize the quest fragments. }
	Procedure AssignMasterListIDNumbers( M: GearPtr );
		{ Each fragment in the master list needs a unique ID number, stored }
		{ in its "S" descriptor. }
	var
		ID: Integer;
	begin
		ID := 0;
		while M <> Nil do begin
			M^.S := ID;
			Inc( ID );
			M := M^.Next;
		end;
	end;
var
	Frags: GearPtr;
begin
	Frags := AggregatePattern( 'QUEST_*.txt' , Series_Directory );

	{ Initialize the quest fragments. }
	AssignMasterListIDNumbers( Frags );
	LoadQuestFragments := Frags;
end;

Function AddQuest( Adv,City,QPF_Proto: GearPtr; var Quest_Frags: GearPtr; QReq: String ): Boolean;
	{ Add a quest to the provided city. }
	{ QPF_Proto is a prototype for a prefab element to be added to a quest. }
	{ Quest_Frags is the list of quest fragments. Some of them may get deleted here. }
	{ QReq is the quest request taken from the ATLAS. }
var
	QList,Quest: GearPtr;
begin

end;


initialization
	{ Load the list of subplots from disk. }
	Sub_Plot_List := LoadRandomSceneContent( 'MEGA_*.txt' , series_directory );
	standard_trigger_list := LoadStringList( Data_Directory + 'standard_triggers.txt' );
	MasterEntranceList := AggregatePattern( 'ENTRANCE_*.txt' , Series_Directory );


finalization
	{ Dispose of the list of subplots. }
	DisposeGear( Sub_Plot_List );
	DisposeSAtt( standard_trigger_list );
	DisposeGear( MasterEntranceList );

end.
