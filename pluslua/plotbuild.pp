unit plotbuild;
	{ This unit handles the construction of random plots. }

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

	{ G = GG_Plot                            }
	{ S = ID Number (not nessecarily unique) }
	{ v0.240 - Elements are stored as numeric attributes }

type
	{ I feel just like Dmitri Mendelev writing this... }
	ElementTable = Array [1..Num_Plot_Elements] of LongInt;

var
	persona_fragments: GearPtr;
	Standard_Plots,Standard_Moods: GearPtr;
	Dramatic_Choices: GearPtr;


Function ExpandDungeon( Dung: GearPtr ): GearPtr;
Procedure ConnectScene( Scene: GearPtr; DoInitExits: Boolean );


Function CreateSceneContent( GB: GameBoardPtr; Control: GearPtr; SPReq: String; Threat: Integer; DoDebug: Boolean ): GearPtr;


Function SeekUrbanArea( RootScene: GearPtr ): GearPtr;

Function InsertMood( City,Mood: GearPtr; GB: GameBoardPtr ): Boolean;

Function InsertRSC( Source,Frag: GearPtr; GB: GameBoardPtr ): Boolean;
Procedure EndPlot( GB: GameBoardPtr; Adv,Plot: GearPtr );

Procedure PrepareNewComponent( Story: GearPtr; GB: GameBoardPtr );

Function InsertArenaMission( Source,Mission: GearPtr; ThreatAtGeneration: Integer ): Boolean;

Procedure UpdatePlots( GB: GameBoardPtr; Renown: Integer );
Procedure UpdateMoods( GB: GameBoardPtr );

Procedure CreateChoiceList( GB: GameBoardPtr; Story: GearPtr );
Procedure ClearChoiceList( Story: GearPtr );


implementation

uses 	uiconfig,rpgdice,texutil,gamebook,interact,ability,gearparser,ghchars,ghprop,
	chargen,wmonster,plotsearch,randmaps,
{$IFDEF ASCII}
	vidgfx,vidmenus;
{$ELSE}
	sdlgfx,sdlmenus;
{$ENDIF}

Const
	Num_Sub_Plots = 8;

Var
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
		ET[t] := 0;
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
	S := Part^.Scripts;
	while S <> Nil do begin
		ApplyDictionaryToString( S^.Info , Dictionary );
		S := S^.Next;
	end;
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
					E^.Stat[ STAT_Destination ] := NAttValue( S^.Parent^.NA , NAG_Narrative , NAS_NID );
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
		E^.Stat[ STAT_Destination ] := NAttValue( Scene^.NA , NAG_Narrative , NAS_NID );
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
			E^.Stat[ STAT_Destination ] := NAttValue( Scene^.NA , NAG_Narrative , NAS_NID );
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
	EntryLevelID: LongInt;
	Procedure AssignSceneIDs( SList: GearPtr );
		{ Assign unique IDs to all the scenes in this list and all of }
		{ their children scenes. Also do the connections, as long as we're here. }
		{ On top of that, record the entry level ID. Got all that? Good. }
	begin
		while SList <> Nil do begin
			if ( SList^.G = GG_Scene ) then begin
				if SList <> GoalLevel then SetNAtt( SList^.NA , NAG_Narrative , NAS_NID , NewNID( Adv ) );

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
	EntryLevelID := NewNID( Adv );
	SetNAtt( SceneProto^.NA , NAG_Narrative , NAS_NID , EntryLevelID );
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
				Entrance^.Stat[ STAT_Destination ] := NAttValue( Scene^.NA , NAG_Narrative , NAS_NID );
				SetSAtt( Entrance^.SA , 'DESIG <FINAL' + BStr( NAttValue( Scene^.NA , NAG_Narrative , NAS_NID ) ) + '>' );
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
					E^.Stat[ STAT_Destination ] := NAttValue( S^.Parent^.NA , NAG_Narrative , NAS_NID );
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
				SetNAtt( QS^.NA , NAG_Narrative , NAS_NID , ElementID( Quest , EIn ) );

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

Procedure MoveElements( GB: GameBoardPtr; Adv,Plot: GearPtr; IsAQuest: Boolean );
	{ There are a bunch of elements in this plot. Some of them need to be moved. }
	{ Make it so. }
	{ GB may be nil, but Adv must be a component of the adventure. }
var
	T,PlaceIndex: Integer;
	PlaceCmd,EDesc,TeamName,DebugRec: String;
	Element,Dest,MF,Team,MS,Thing,DScene,Dest0: GearPtr;
	InSceneNotElement: Boolean;
	EID: LongInt;
begin

	{ Loop through all elements, looking for stuff to move. }
	for t := 1 to Num_Plot_ELements do begin
		PlaceCmd := SAttValue( Plot^.SA , 'PLACE' + BStr( T ) );
		if PlaceCmd <> '' then begin
			EDesc := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			DebugRec := PlaceCmd;
			if ( EDesc <> '' ) and ( UpCase( EDesc[1] ) = 'S' ) then begin
				{ I can't believe you just asked me to move a scene... }
				{ What you really must want is for me to move an encounter }
				{ attached to a metascene. Yeah, that must be it. }
				EID := ElementID( Plot , T );
				if EID < 0 then begin
					Element := FindSceneEntrance( FindRoot( Adv ) , GB , EID );
				end else begin
					Element := Nil;
				end;
			end else begin
				{ Just find the regular element. }
				Element := SeekPlotElement( FindRoot( Adv ) , Plot , T , GB );
			end;

			InSceneNotElement := ( PlaceCmd[1] = '~' );
			if InSceneNotElement then DeleteFirstChar( PlaceCmd );

			if PlaceCmd = '/' then begin
				Dest := SeekCurrentLevelGear( FindRoot( Adv )^.InvCom , GG_PlotThingSet , 0 );
				InSceneNotElement := False;
			end else begin
				PlaceIndex := ExtractValue( PlaceCmd );
				Dest := SeekPlotElement( FindRoot( Adv ) , Plot , PlaceIndex , GB );
			end;

			TeamName := RetrieveBracketString( PlaceCmd );

			if Element = Nil then begin
				DialogMsg( 'ERROR- Element ' + BStr( T ) + ' of ' + GearName( Plot ) + ' not found for movement.' );
				Exit;
			end;

			{ Next, delink the gear for movement... but there's a catch. }
			{ We don't want the delinker to give our element an OriginalHome }
			{ if it's a prefab element, because we want to do that ourselves }
			{ now in a bit. }
			{ Don't delink if we have a scene- in that case, we're just here to transfer }
			{ over the metascene stuff. }
			if Element^.G <> GG_Scene then begin
				if ( Element^.Parent <> Nil ) and ( Element^.Parent^.G = GG_Plot ) and IsInvCom( Element ) then begin
					DelinkGear( Element^.Parent^.InvCom , Element );
				end else begin
					DelinkGearForMovement( GB , Element );
				end;
			end;

			if InSceneNotElement and (( Dest = Nil ) or ( Dest^.G <> GG_Scene )) then begin
				{ If the destination is a metascene, locate its entrance. }
				if ( Dest = Nil ) or ( Dest^.G = GG_MetaScene ) then begin
					Dest := FindSceneEntrance( FindRoot( Adv ) , GB , ElementID( Plot , PlaceIndex ) );
				end;

				{ Try to find the associated scene now. }
				if ( Dest <> Nil ) and not IsAQuest then begin
					Dest := FindActualScene( GB , FindSceneID( Dest , GB ) );
				end;
			end;

			if ( Dest <> Nil ) then begin
				if ( Dest^.G <> GG_Scene ) and ( Dest^.G <> GG_MetaScene ) and IsLegalInvCom( Dest , Element ) then begin
					{ If E can be an InvCom of Dest, stick it there. }
					InsertInvCom( Dest , Element );
				end else begin
					{ If Dest isn't a scene, find the scene DEST is in itself }
					{ and stick E in there. }
					Dest0 := Dest;
					while ( Dest <> Nil ) and ( not IsAScene( Dest ) ) do Dest := Dest^.Parent;
					if Dest = Nil then begin
						DialogMsg( 'ERROR: ' + GearName( Dest0 ) + ' selected as place for ' + GearName( Element ) );
						Exit;
					end;

					if IsMasterGear( Element ) then begin
						if TeamName <> '' then begin
							Team := SeekChildByName( Dest , TeamName );
							if ( Team <> Nil ) and ( Team^.G = GG_Team ) then begin
								SetNAtt( Element^.NA , NAG_Location , NAS_Team , Team^.S );
							end else begin
								ChooseTeam( Element , Dest );
							end;
						end else begin
							ChooseTeam( Element , Dest );
						end;
					end;

					{ If a Metascene map feature has been defined as this element's home, }
					{ stick it there instead of in the scene proper. Such an element will }
					{ always be MiniMap component #1, so set that value here too. }
					if ( Dest^.G = GG_MetaScene ) then begin
						MF := SeekGearByDesig( Dest^.SubCom , 'HOME ' + BStr( T ) );
						if MF <> Nil then begin
							Dest := MF;
							SetNAtt( Element^.NA , NAG_ComponentDesc , NAS_ELementID , 1 );
						end;
					end;

					{ If this is a quest, then this element might have some supplemental }
					{ scene content. Better take a look. }
					if IsAQuest and IsAScene( Dest ) then begin
						MS := SeekCurrentLevelGear( Plot^.SubCom , GG_MetaScene , T );
						if MS <> Nil then begin
							{ Store the destination scene- we'll need it later. }
							DScene := Dest;

							{ This metascene may also contain a home for this element. }
							MF := SeekGearByDesig( MS^.SubCom , 'HOME' );
							if ( MF <> Nil ) and ( Element^.G <> GG_Scene ) then begin
								Dest := MF;
								SetNAtt( Element^.NA , NAG_ComponentDesc , NAS_ELementID , 1 );
							end;

							{ Copy over all InvComs and SubComs. }
							while ( MS^.InvCom <> Nil ) do begin
								Thing := MS^.InvCom;
								DelinkGear( MS^.InvCom , Thing );
								InsertInvCom( DScene , Thing );
							end;
							while ( MS^.SubCom <> Nil ) do begin
								Thing := MS^.SubCom;
								DelinkGear( MS^.SubCom , Thing );
								InsertSubCom( DScene , Thing );
							end;
						end;
					end;

					{ If this is a prefab element and we're deploying }
					{ to a metascene, assign an OriginalHome value of -1 }
					{ to make sure it doesn't get deleted when the plot }
					{ ends. }
					if NAttValue( Element^.NA , NAG_ParaLocation , NAS_OriginalHome ) = 0 then begin
						if Dest^.G = GG_MetaScene then SetNAtt( Element^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );
					end;

					if ( GB <> Nil ) and ( Dest = GB^.Scene ) then begin
						EquipThenDeploy( GB , Element , True );
					end else if Element^.G <> GG_Scene then begin
						InsertInvCom( Dest , Element );
					end;
				end;
			end else begin
				DialogMsg( 'ERROR: Destination not found for ' + GearName( Element ) + '/' + GearName( Plot )  + ' PI:' + BStr( PlaceIndex ) );
				DialogMsg( DebugRec );
				InsertInvCom( Plot , Element );
			end;
		end;
	end;
end;



Function AddSubPlot( GB: GameBoardPtr; Scope,Control,Slot,Plot0: GearPtr; SPReq: String; LayerID,SubPlotSlot,Threat: LongInt; IsAQuest,DoDebug: Boolean ): GearPtr; forward;


Function InitShard( GB: GameBoardPtr; Scope,Control,Slot,Shard: GearPtr; PlotID,LayerID,Threat: LongInt; const ParamIn: ElementTable; IsAQuest,DoDebug: Boolean ): GearPtr;
	{ SHARD is a plot fragment candidate. Attempt to add it to the Slot. }
	{ Attempt to add its subplots as well. }
	{ SCOPE is the search scope for elements. }
	{ CONTROL is the controller of this subplot, a story or mood. }
	{ SLOT is where this plot should be stored. Plots are always InvComs. }
	{ SHARD is the prospective subplot which will either be installed in SLOT or deleted. }
	{ Before initializing a shard, the following will be done: }
	{ - Parameter elements copied over }
	{ - Any character gears present will be randomized }
	{ Initializing includes the following: }
	{ - Set combatant skill levels for quests }
	{ Upon successfully initializing a shard, this procedure will then do the following: }
	{ - Delink the shard from the Slot, and attach all subplots. }
	{ - Create a plot stub and mark it with the PlotID; copy over all elements used by }
	{   this shard and place it as Slot's invcom. This stub is to prevent other shards }
	{   from selecting characters or items used here. }
	{ - Initialize quest metascenes with the PlotID. }
	{ - Return the shard list }
	{ If installation fails, SHARD will be deleted and NIL will be returned. }
	Procedure DisposeSPList( SPList: GearPtr );
		{ Delete this subplot list, taking with it any associated placeholders. }
	var
		SP: GearPtr;
	begin
		while SPList <> Nil do begin
			SP := SPList;
			RemoveGear( SPList , SP );
		end;
	end;
	Procedure ScaleRandomTreasure( LList: GearPtr );
		{ Scale any random loot values found along this path. }
		{ The treasures found as part of a quest should be }
		{ commesurate with the Difficulty rating of the quest. }
	var
		LootValue: LongInt;
	begin
		while LList <> Nil do begin
			if NAttValue( LList^.NA , NAG_Narrative , NAS_RandomLoot ) > 0 then begin
				LootValue := Calculate_Threat_Points( Threat , 10 + Random( 15 ) );
				SetNAtt( LList^.NA , NAG_Narrative , NAS_RandomLoot , LootValue );
			end;
			ScaleRandomTreasure( LList^.SubCom );
			ScaleRandomTreasure( LList^.InvCom );
			LList := LList^.Next;
		end;
	end;













	Procedure PrepQuestCombatants( LList: GearPtr );

		{ If this is a quest, scale any combatant NPCs to the proper level. }
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_Character ) then begin
				if NotAnAnimal( Llist ) and IsACombatant( LList ) then begin
					SetSkillsAtLevel( LList , Threat );
				end;
			end;
			LList := LList^.Next;
		end;
	end;

	Procedure InitializeMapFeatures( LList: GearPtr );
		{ Mark all map features, their subs and invs, with the PlotID of the }
		{ parent scene. Why do this? So scripts can then locate the quest }
		{ without too much difficulty. }
	begin
		while LList <> Nil do begin
			if NAttValue( LList^.NA , NAG_Narrative , NAS_PlotID ) = 0 then SetNAtt( LList^.NA , NAG_Narrative , NAS_PlotID , PlotID );
			if LList^.G = GG_MapFeature then begin
				InitializeMapFeatures( LList^.SubCom );
				InitializeMapFeatures( LList^.InvCom );
			end;
			LList := LList^.Next;
		end;
	end;
	Procedure PrepQuestMetascenes( LList: GearPtr );
		{ If this is a quest, mark the map features. }
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_MetaScene ) then begin
				{ Also mark all of the scene's things with the PlotID, so scripts can locate }
				{ the quest easily. }
				InitializeMapFeatures( LList^.SubCom );
				InitializeMapFeatures( LList^.InvCom );
			end;
			LList := LList^.Next;
		end;
	end;
var
	InitOK: Boolean;
	T,NumParam: Integer;
	I,SubPlot: GearPtr;
	SPID: LongInt;
	SPReq,EDesc: String;
begin
	{ Assign the values to this shard. }
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_PlotID , PlotID );
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_NID , LayerID );
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_DifficultyLevel , Threat );

	{ Scale the random treasure, based upon the threat value provided. }
	ScaleRandomTreasure( Shard^.SubCom );
	ScaleRandomTreasure( Shard^.InvCom );

	{ Start by copying over all provided parameters. }
	{ Also count the number of parameters passed; it could be useful. }
	NumParam := 0;
	for t := 1 to Num_Plot_Elements do begin
		if ParamIn[ t ] <> 0 then begin
			SetNAtt( Shard^.NA , NAG_ElementID , T , ParamIn[ t ] );
			SetSAtt( Shard^.SA , 'ELEMENT' + BStr( T ) + ' <Param>' );
			Inc( NumParam );
		end;
	end;

	{ Check the remaining parameters for artifacts. }
	for t := ( NumParam + 1 ) to Num_Plot_Elements do begin
		EDesc := UpCase( SAttValue( Shard^.SA , 'ELEMENT' + BStr( T ) ) );
		if ( EDesc = '' ) then begin
			Break;
		end else if ( EDesc[1] = 'A' ) then begin
			{ This is an artifact request. If no difficulcy context has been }
			{ defined, add one ourselves. }
			if not AStringHasBString( EDesc , '!' ) then begin
				EDesc := EDesc + ' ' + DifficulcyContext( Threat );
				SetSAtt( Shard^.SA , 'ELEMENT' + BStr( T ) + ' <' + EDesc + '>' );
			end;
		end;
	end;

	{ Next, randomize the NPCs. }
	I := Shard^.InvCom;
	while I <> Nil do begin
		{ Character gears have to be individualized. }
		if ( I^.G = GG_Character ) and NotAnAnimal( I ) then begin
			IndividualizeNPC( I );
		end;
		I := I^.Next;
	end;

	{ Attempt the basic content insertion routine. }
	if DoDebug then SetSAtt( Shard^.SA , 'name <DEBUG>' );
	InitOK := MatchPlotToAdventure( Scope , Control , Slot , Shard , GB , False );

	{ If the installation has gone well so far, time to move on. }
	if InitOK then begin
		{ Initialize the prefab NPCs for a quest. }
		if IsAQuest then begin
			PrepQuestCombatants( Shard^.InvCom );
			PrepQuestMetascenes( Shard^.SubCom );
		end;

		{ If any of the needed subplots fail, installation of this shard fails }
		{ as well. }
		{ Arena missions may not request subplots. Sorry, that's just how it is. }
		if Shard^.G <> GG_Scene then begin
			for t := 1 to Num_Sub_Plots do begin
				SPReq := SAttValue( Shard^.SA , 'SUBPLOT' + BStr( T ) );
				if SPReq <> '' then begin
					SPID := NewNID( FindRoot( Slot ) );
					SubPlot := AddSubPlot( GB , Scope , Control , Shard , Shard , SPReq , SPID , T , Threat , IsAQuest, DoDebug );
					if SubPlot = Nil then begin
						{ The subplot request failed, meaning that this shard fails }
						{ as well. }
						InitOK := False;
						RemoveGear( Slot^.InvCom , Shard );
						Break;
					end;
				end;
			end;
		end;
	end;

	{ Return our result. }
	if InitOk then begin
		InitShard := Shard;
	end else begin
		InitShard := Nil;
	end;
end;

Function AddSubPlot( GB: GameBoardPtr; Scope,Control,Slot,Plot0: GearPtr; SPReq: String; LayerID,SubPlotSlot,Threat: LongInt; IsAQuest,DoDebug: Boolean ): GearPtr;
	{ A request has been issued for a subplot. Search through the plot }
	{ component list and see if there's anything that matches our criteria. }
	{ Scope = The lower bound for the element search, usually a city, a world, or the entire adventure. }
	{ Control = The story or mood which controls this plot. May well be Nil. }
	{ Slot = The gear into which this plot will be inserted. Must be a node in the adventure. }
	{ Plot0 = the plot requesting the subplot. If root, it will be Nil. }
var
	ShoppingList: NAttPtr;
	Context,SPContext: String;
	ParamList: ElementTable;
	T,E: Integer;
	Shard: GearPtr;
	NotFoundMatch: Boolean;
	PlotID: LongInt;
	IsBranchPlot: Boolean;
begin
	{ First determine the request context, i.e. what kind of a subplot }
	{ we're meant to load. }
	Context := ExtractWord( SPReq );
	DeleteWhiteSpace( SPReq );

	{ Determine the difficulty rating of this subplot. }
	if ( SPReq <> '' ) and ( SPReq[1] = '#' ) then begin
		DeleteFirstChar( SPReq );
		T := ExtractValue( SPReq );
		if T > 0 then Threat := T;
	end else if threat < 10 then begin
		threat := 10;
	end;
	{ Add this difficulty rating to the context. }
	Context := Context + ' ' + DifficulcyContext( Threat );

	{ Next add the story, quest, and parent plot contexts. }
	if ( Control <> Nil ) and ( ( Control^.G = GG_Story ) or ( Control^.G = GG_CityMood ) ) then Context := Context + ' ' + StoryContext( GB , Control );
	if IsAQuest then AddGearXRContext( GB , FindRoot( Slot ) , Scope , Context , 'L' );
	if Plot0 <> Nil then begin
		SPContext := SAttValue( Plot0^.SA , 'SPContext' );
		if SPContext <> '' then Context := Context + ' ' + SPContext;
	end else begin
		SPContext := '';
	end;

	{ Determine whether this is a regular subplot or a branch plot that will start its own narrative thread. }
	IsBranchPlot := ( Length( Context ) > 2 ) and ( Context[2] = ':' );
	{ This will determine whether we inherit the PlotID from Plot0, or generate a new one. }
	if IsBranchPlot or ( Plot0 = Nil ) then PlotID := NewNID( FindRoot( Slot ) )
	else PlotID := NAttValue( Plot0^.NA , NAG_Narrative , NAS_PlotID );

	{ Store the details for this subplot in Plot0. }
	if Plot0 <> Nil then begin
		SetNAtt( Plot0^.NA , NAG_SubPlotLayerID , SubPlotSlot , LayerID );
		SetNAtt( Plot0^.NA , NAG_SubPlotPlotID , SubPlotSlot , PlotID );

		{ Determine the parameters to be sent, and add context info for them. }
		ClearElementTable( ParamList );
		T := 1;
		while ( SPReq <> '' ) and ( T <= Num_Plot_Elements ) do begin
			E := ExtractValue( SPReq );
			if ( E >= 1 ) and ( E <= Num_Plot_Elements ) then begin
				{ This element is being shared with the subplot. }
				ParamList[t] := ElementID( Plot0 , E );
				AddElementContext( GB , Plot0 , Context , BStr( T )[1] , E );
				Inc( T );
			end;
		end;
	end else begin
		{ We have no parameters to send. Clear the param list. }
		ClearElementTable( ParamList );
	end;

	{ We have the finished context. Create the shopping list. }
	{ Positive component values are from the main subplot list. Negative }
	{ component values point to items from the quest_frags list. }
	ShoppingList := CreateComponentList( Standard_Plots , Context );

	if XXRan_Debug and ( Control <> Nil ) and ( Control^.G = GG_Story ) then begin
		if NumNAtts( ShoppingList ) < 5 then begin
			DialogMsg( '[DEBUG] Only ' + BStr( NumNatts( ShoppingList ) ) + ' components for "' + Context + '".' );
		end;
	end;

	{ Based on this shopping list, search for applocable subplots and attempt to }

	{ fit them into the adventure. }

	NotFoundMatch := True;
	Shard := Nil;
	while ( ShoppingList <> Nil ) and NotFoundMatch do begin
		if XXRan_Wizard and ( ShoppingList <> Nil ) and ( Control^.G = GG_Story ) and not IsAQuest then begin
			Shard := CloneGear( ComponentMenu( Standard_Plots , ShoppingList ) );
		end else if DoDebug and not IsAQuest then begin
			DialogMsg( Context );
			Shard := CloneGear( ComponentMenu( Standard_Plots , ShoppingList ) );
		end else begin
			Shard := CloneGear( SelectComponentFromList( Standard_Plots , ShoppingList ) );
		end;
		if Shard <> Nil then begin
			{ See if we can add this one to the list. If not, it will be }
			{ deleted by InitShard. }
			if SPContext <> '' then SetSAtt( Shard^.SA , 'SPCONTEXT <' + SPContext + '>' );
			Shard := InitShard( GB , Scope , Control , Slot , Shard , PlotID , LayerID , Threat , ParamList , IsAQuest , DoDebug );
			if Shard <> Nil then NotFoundMatch := False;
		end;
	end;

	{ Get rid of the shopping list. }
	DisposeNAtt( ShoppingList );

	{ Return our selected subplot. }
	AddSubPlot := Shard;
end;

Procedure CompleteThePlot( GB: GameBoardPtr; Scope,Control,Plot: GearPtr; IsAQuest: Boolean );
	{ This Plot has been successfully added to the adventure. Now, take a look through }
	{ all of its components and do the time-consuming initialization routines that we've }
	{ been putting off until now. }
var
	Adventure: GearPtr;
	Context: String;

	Procedure InitPrefabMood( Mood: GearPtr );
		{ Moods can grab elements from either the plot that spawned them or the story }
		{ that spawned the plot. Do that now. }
	var
		Grab_Source: GearPtr;
		t,N: LongInt;
		desc: String;
	begin
		for t := 1 to Num_Plot_Elements do begin
			{ If an element grab is requested, process that now. }
			desc := SAttValue( Mood^.SA , 'ELEMENT' + BStr( T ) );
			if ( desc <> '' ) and ( UpCase( desc[1] ) = 'G' ) then begin
				ExtractWord( desc );
				N := ExtractValue( desc );

				{ If we got a positive value, grab from the plot. Otherwise grab from }
				{ the presumed story. }
				if N > 0 then Grab_Source := Plot
				else Grab_Source := Control;
				N := Abs( N );

				SetSAtt( Mood^.SA , 'ELEMENT' + BStr( T ) + ' <PARAM>' );
				SetNAtt( Mood^.NA , NAG_ElementID , T , ElementID( Grab_Source , N ) );
			end;
		end; { For t ... }
	end;

	Procedure InitListStrings( LList: GearPtr; Dictionary: SAttPtr );
		{ Run LList, all of its siblings and children, through the ReplaceStrings }
		{ procedure. }
		{ Once the strings are initialized, activate the scripts. }
	begin
		while LList <> Nil do begin
			if LList^.G <> GG_Plot then begin
				ReplaceStrings( LList , Dictionary );
				InitListStrings( LList^.SubCom , Dictionary );
				InitListStrings( LList^.InvCom , Dictionary );
			end;
			LList := LList^.Next;
		end;
	end;


	Function SelectPFrag( ProtoNode: GearPtr; const PContext,NextID: String; ID: Integer ): GearPtr;
		{ Create and initialize a persona fragment for this node. }
	var
		F: GearPtr;	{ The persona fragment to insert. }
		info,TypeLabel,msg: String;
		Dic: SATTPtr;
		Param: Array [1..8] of String;
		T: Integer;
	begin
		info := SAttValue( ProtoNode^.SA , 'REQUEST' );
		TypeLabel := ExtractWord( info );
		{ Create the dictionary. }
		Dic := Nil;
		SetSAtt( Dic , '%id% <' + BStr( ID ) + '>' );
		SetSAtt( Dic , '%next% <' + NextID + '>' );
		for t := 1 to 8 do begin
			msg := ExtractWord( Info );
			if msg <> '' then SetSAtt( Dic , '%' + BStr( t ) + '% <' + msg + '>' )
			else SetSAtt( Dic , '%' + BStr( t ) + '% <ERROR_' + BStr( t ) + '>' );
		end;

		{ Next, search for a matching fragment... }
		F := FindNextComponent( persona_fragments , TypeLabel + ' ' + Context );
		if F <> Nil then begin
			{ If one was found, prep it for inclusion in the persona. }
			F := CloneGear( F );

			InitListStrings( F , Dic );

		end else begin
			DialogMsg( 'ERROR: No persona fragment found for ' + TypeLabel + ' ' + Context );
		end;

		DisposeSAtt( Dic );
		SelectPFrag := F;
	end;

	Procedure InitializeConversationTree( const PContext: String; PTree: GearPtr );
		{ This procedure does two things: It replaces ProtoNodes with Persona }
		{ Fragments, and it assigns a NodeID to every SayNode. }
	var
		NodeID,PFID: Integer;
		Function UniqueLabel( PNode: GearPtr ): String;
			{ Return the identifier of PNode, or if no such identifier exists }
			{ assign it one according to the PFID. }
		var
			L: String;
		begin
			if PNode <> Nil then begin
				L := SAttValue( PNode^.SA , 'LABEL' );
				if L = '' then begin
					L := 'PFRAGNEXT_' + BStr( PFID );
					SetSAtt( PNode^.SA , 'LABEL <' + L + '>' );
				end;
			end else L := 'na';
			UniqueLabel := L;
		end;
		Procedure InitCTAlongPath( PList: GearPtr );
			{ Check along this linked list assigning NodeIDs. }
		var
			PFrag,PTmp: GearPtr;
			PFNext: String;
		begin
			while PList <> Nil do begin
				if PList^.G = GG_PersonaNode then begin
					if PList^.S = GS_ProtoNode then begin
						{ This is a persona fragment request. Locate an appropriate }
						{ fragment, then drop it in here. }
						PFNext := UniqueLabel( PList^.Next );
						PFrag := SelectPFrag( PList, PContext, PFNext, PFID );
						Inc( PFID );

						{ Alright, we have the PFrag; try to insert it right after }
						{ PList. }
						if PFrag <> Nil then begin
							{ Bad Programmer! Directly juggling pointers is bad }
							{ practice! Try not to do this yourself. }
							PTmp := PList^.Next;
							PList^.Next := PFrag;
							PFrag^.Next := PTmp;
							PFrag^.Parent := PList^.Parent;
							{ This PFrag started life as a Persona. }
							{ Convert it to a PNode. }
							PFrag^.G := GG_PersonaNode;
							PFrag^.S := GS_NullNode;

							{ Add a GOTO at the end to connect it to the NEXT. }
							if PFrag^.Next <> Nil then begin
								PTmp := AddGear( PFrag^.SubCom , PFrag );
								PTmp^.G := GG_PersonaNode;
								PTmp^.S := GS_GotoNode;
								SetSAtt( PTmp^.SA , 'GOTO <' + PFNext + '>' );
							end;
						end;
					end else if PList^.S = GS_SayNode then begin
						PList^.Stat[ STAT_PersonaNodeID ] := NodeID;
						Inc( NodeID );
					end;

					InitCTAlongPath( PList^.SubCom );
				end;
				PList := PList^.Next;
			end;
		end;
	begin
		{ Initialize the NodeID to the minimum value. }
		PFID := 1;
		NodeID := PNODE_GREETING;
		InitCTAlongPath( PTree );
	end;

	Procedure LinkConversationTree( Persona: GearPtr );
		{ Add every SayNode in the persona tree to Persona's Lua script. }
		Function FindNodeByLabel( PList: GearPtr; const NodeLabel: String ): GearPtr;
			{ Search the Persona tree for a node with this label. }
		var
			it: GearPtr;
		begin
			it := Nil;
			while ( PList <> Nil ) and ( it = Nil ) do begin
				if UpCase( SAttValue( PList^.SA , 'LABEL' ) ) = NodeLabel then it := PList;
				if ( it = Nil ) then it := FindNodeByLabel( PList^.SubCom , NodeLabel );
				PList := PList^.Next;
			end;
			FindNodeByLabel := it;
		end;
		Function GetNodeID( PNode: GearPtr ): Integer;
			{ Return the NodeID of this node. }
		var
			RNode: GearPtr;	{ The referenced node. }
		begin
			if ( PNode^.S = GS_ReplyNode ) or ( PNode^.S = GS_NullNode ) then begin
				if PNode^.SubCom <> Nil then begin
					GetNodeID := GetNodeID( PNode^.SubCom );
				end else begin
					RecordError( 'ERROR: No subcom for ReplyNode ' + SAttValue( PNode^.SA , 'msg' ) );
					GetNodeID := 0;
				end;
			end else if ( PNode^.S = GS_ProtoNode ) then begin
				{ A ProtoNode should be followed by the actual persona fragment that was }
				{ requested. So, return that ID. }
				if PNode^.Next <> Nil then begin
					GetNodeID := GetNodeID( PNode^.Next );
				end else begin
					RecordError( 'ERROR: No next for ProtoNode ' + SAttValue( PNode^.SA , 'request' ) );
					GetNodeID := 0;
				end;

			end else if PNode^.S = GS_GotoNode then begin
				if PNode^.Stat[ STAT_PERSONANODEID ] <> 0 then begin
					{ We've already located this node's target. }
					GetNodeID := PNode^.Stat[ STAT_PERSONANODEID ];
				end else begin
					RNode := FindNodeByLabel( Persona^.SubCom , UpCase( SAttValue( PNode^.SA , 'GOTO' ) ) );
					if ( RNode <> Nil ) and ( RNode^.S <> GS_GotoNode ) then begin
						PNode^.Stat[ STAT_PERSONANODEID ] := GetNodeID( RNode );
						GetNodeID := PNode^.Stat[ STAT_PERSONANODEID ];
					end else begin
						RecordError( 'ERROR: No ref for GotoNode ' + SAttValue( PNode^.SA , 'GOTO' ) );
						GetNodeID := 0;
					end;
				end;
			end else GetNodeID := PNode^.Stat[ STAT_PERSONANODEID ];
		end;
		Procedure CheckSayNodesAlongPath( PList: GearPtr );
			{ Check along this linked list for SayNodes. }
		var
			msg: String;
			P: GearPtr;
			PID: Integer;
		begin
			while PList <> Nil do begin
				if PList^.G = GG_PersonaNode then begin
					if PList^.S = GS_SayNode then begin
						StoreSAtt( Persona^.Scripts , 'P.node_' + BStr( PList^.Stat[ STAT_PersonaNodeID ] ) + ' = { ' );
						StoreSAtt( Persona^.Scripts , 'msg = "' + SAttValue( PList^.SA , 'MSG' ) + '", ' );
						msg := SAttValue( PList^.SA , 'EFFECT' );
						if msg <> '' then StoreSAtt( Persona^.Scripts , 'effect = function(self,chatnpc) ' + msg + ' end, ' );

						if PList^.Next <> Nil then begin
							msg := SAttValue( PList^.SA , 'CONDITION' );
							if msg <> '' then StoreSAtt( Persona^.Scripts , 'condition = function(self,chatnpc) ' + msg + ' end, ' );

							StoreSAtt( Persona^.Scripts , 'nextid = "node_' + BStr( GetNodeID( PList^.Next ) ) + '", ' );
						end;

						if PList^.SubCom <> Nil then begin
							{ Add any prompts found along this path. }
							StoreSAtt( Persona^.Scripts , 'prompts = { ' );
							P := PList^.SubCom;
							while P <> Nil do begin
								if ( P^.G = GG_PersonaNode ) and ( P^.S = GS_ReplyNode ) then begin
									PID := GetNodeID( P );
									msg := SAttValue( P^.SA , 'msg' );
									if ( PID <> 0 ) and ( msg <> '' ) then begin
										StoreSAtt( Persona^.Scripts , '[' + BStr( PID ) + '] = { msg = "' + msg + '", ' );
										msg := SAttValue( P^.SA , 'condition' );
										if msg <> '' then StoreSAtt( Persona^.Scripts , 'condition = function(self,chatnpc) ' + msg + ' end, ' );
										StoreSAtt( Persona^.Scripts , '}, ' );
									end;
								end;
								P := P^.Next;
							end;

							StoreSAtt( Persona^.Scripts , '} ' );
						end;

						StoreSAtt( Persona^.Scripts , '} ' );

					end;

					CheckSayNodesAlongPath( PList^.SubCom );
				end;
				PList := PList^.Next;
			end;
		end;
	begin
		CheckSayNodesAlongPath( Persona^.SubCom );
	end;

	Procedure PrepAllPersonas( Adventure: GearPtr );
		{ Prepare the personas of this plot. }
		{ Also store the mission recharge time for any NPCs involved. }
	var
		P,P2,NPC: GearPtr;
		PContext: String;
	begin
		P := Plot^.SubCom;
		while P <> Nil do begin
			P2 := P^.Next;
			if P^.G = GG_Persona then begin
				NPC := SeekPlotElement( Adventure , Plot , P^.S , GB );
				if ( NPC <> Nil ) and ( GB <> Nil ) then SetNAtt( NPC^.NA , NAG_Personal , NAS_PlotRecharge , GB^.ComTime + 86400 );

				PContext := Context;
				AddGearXRContext( GB, Adventure, NPC, PContext, '@' );

				{ We have a bunch of PNodes that need to be linked into a single Lua script. }
				{ Step One: Go through the tree, assign a nodeID to every SayNode and expand }
				{ every ProtoNode. }
				InitializeConversationTree( PContext , P^.SubCom );

				{ Our conversation tree has been initialized. Link the Lua code together. }
				LinkConversationTree( P );

				{ Unless we've been asked to debug, get rid of the persona nodes. They are no }
				{ longer needed. }
				if not Persona_Debug then begin
					DisposeGear( P^.SubCom );
				end;
			end;
			P := P2;
		end;
	end;

	Procedure PrepMetaScenes( Adventure: GearPtr );
		{ Maps are stored by name, so each metascene needs a unique name. }
		{ Since it already has a unique ID number this shouldn't be much trouble. }
	var
		M,Entrance: GearPtr;
		FID: LongInt;
	begin
		M := Plot^.SubCom;
		while M <> Nil do begin
			if ( M^.G = GG_MetaScene ) and ( M^.S >= 1 ) and ( M^.S <= Num_Plot_Elements ) then begin
				{ Store the entrance of the metascene. We'll need it later. }
				Entrance := FindSceneEntrance( Adventure , GB , ElementID( Plot , M^.S ) );
				if Entrance <> Nil then begin
					SetNAtt( M^.NA , NAG_Narrative , NAS_EntranceScene , FindSceneID( Entrance , GB ) );
				end;

				{ If this metascene has a faction set, it will be an element of the plot. }
				FID := NAttValue( M^.NA , NAG_Personal , NAS_FactionID );
				if FID <> 0 then begin
					SetNAtt( M^.NA , NAG_Personal , NAS_FactionID , ElementID( Plot , FID ) );
				end;

				if SAttValue( M^.SA , 'NAME' ) = '' then SetSAtt( M^.SA , 'NAME <METASCENE:' + BStr( ElementID( Plot , M^.S ) ) + '>' );
				SetSAtt( M^.SA , 'CONTEXT <' + SAttValue( M^.SA , 'CONTEXT' ) + ' ' + Context + '>' );
			end;
			M := M^.Next;
		end;
	end;

	Procedure DoStringSubstitutions();
		{ Do the string substitutions for this subplot. Basically, }
		{ create the dictionary and pass it on to the substituter. }
		{ Once the strings are initialized, activate the scripts. }
	var
		Dictionary: SAttPtr;
		T: Integer;
	begin
		{ Begin creating. }
		Dictionary := Nil;
		SetSAtt( Dictionary , '%plotid% <' + BStr( NAttValue( Plot^.NA , NAG_Narrative , NAS_PlotID ) ) + '>' );
		SetSAtt( Dictionary , '%id% <' + BStr( NAttValue( Plot^.NA , NAG_Narrative , NAS_NID ) ) + '>' );
		SetSAtt( Dictionary , '%threat% <' + BStr( NAttValue( Plot^.NA , NAG_Narrative , NAS_DifficultyLevel ) ) + '>' );
		for t := 1 to Num_Sub_Plots do begin
			SetSAtt( Dictionary , '%id' + BStr( T ) + '% <' + Bstr( NAttValue( Plot^.NA , NAG_SubPlotLayerID , T ) ) + '>' );
			SetSAtt( Dictionary , '%plotid' + BStr( T ) + '% <' + Bstr( NAttValue( Plot^.NA , NAG_SubPlotPlotID , T ) ) + '>' );
		end;
		for t := 1 to Num_Plot_Elements do begin
			{ If dealing with the main plot, do substitutions for the Element Indicies now. }
			SetSAtt( Dictionary , '%' + BStr( T ) + '% <' + BStr( ElementID( Plot , T ) ) + '>' );
			SetSAtt( Dictionary , '%name' + BStr( T ) + '% <' + SAttValue( Plot^.SA , 'name_' + BStr( T ) ) + '>' );
		end;

		{ Run the provided subplot through the convertor. }
		ReplaceStrings( Plot , Dictionary );

		InitListStrings( Plot^.SubCom , Dictionary );
		InitListStrings( Plot^.InvCom , Dictionary );
		DisposeSAtt( Dictionary );
	end;

	Procedure ActivatePlotScripts();
		Procedure ActivatePlotChildren( LList: GearPtr );
			{ Activate all the Lua scripts along this tree, ignoring }
			{ subplots for the time being. }
		begin
			while LList <> Nil do begin
				if LList^.G <> GG_Plot then begin
					ActivateGearScript( LList );
				end;
				LList := LList^.Next;
			end;
		end;
	begin
		ActivateGearScript( Plot );
		ActivatePlotChildren( Plot^.SubCom );
		ActivatePlotChildren( Plot^.InvCom );
	end;
var
	PFab: GearPtr;
begin
	Adventure := FindRoot( Plot );
	Context := SAttValue( Plot^.SA , 'CONTEXT' );
	if ( Control <> Nil ) and ( Control^.G = GG_Story ) then begin
		Context := Context + StoryContext( GB , Control );
	end;

	DoStringSubstitutions();
	PrepAllPersonas( FindRoot( Plot ) );
	PrepMetaScenes( FindRoot( Plot ) );

	ActivatePlotScripts();

	{ Do any processing needed by the InvComs. }
	PFab := Plot^.InvCom;
	while PFab <> Nil do begin
		if PFab^.G = GG_CityMood then InitPrefabMood( PFab );
		PFab := PFab^.Next;
	end;

	{ Mark MetaScenes and Personas with the PlotID of the plot which owns }
	{ them. }
	PFab := Plot^.SubCom;
	while PFab <> Nil do begin
		if ( PFab^.G = GG_Persona ) or ( PFab^.G = GG_MetaScene ) then begin
			SetNAtt( PFab^.NA , NAG_Narrative , NAS_PlotID , NAttValue( Plot^.NA , NAG_Narrative , NAS_PlotID ) );
		end;
		PFab := PFab^.Next;
	end;

	InstallQuestScenes( Adventure , Scope , Plot );
	MoveElements( GB , Adventure , Plot , IsAQuest );

	{ Do some extra processing of the InvComs that needed the above processing to }
	{ be complete first. }
	PFab := Plot^.InvCom;
	while PFab <> Nil do begin
		if PFab^.G = GG_Plot then CompleteThePlot( GB , Scope , Control , Plot , IsAQuest );
		PFab := PFab^.Next;
	end;
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


Function CreateMegaPlot( GB: GameBoardPtr; Scope,Control,Slot: GearPtr; SPReq: String; Threat: Integer; IsAQuest,DoDebug: Boolean ): GearPtr;
	{ A MegaPlot has been requested. }
	{ Create all subplots, and initialize everything. }
var
	Plot0,MyMega: GearPtr;
	LayerID: LongInt;
begin
	{ Initialize some of the variables we're going to need. }
	LayerID := NewNID( FindRoot( Slot ) );
	if Slot^.G = GG_Plot then Plot0 := Slot
	else Plot0 := Nil;

	{ Generate the narrative tree. }
	MyMega := AddSubPlot( GB , Scope , Control , Slot , Plot0 , SPReq , LayerID , 0 , Threat , IsAQuest , DoDebug );

	{ Now that we have the list, assemble it. }
	if MyMega <> Nil then begin
		InitRandomLoot( MyMega^.SubCom );
		InitRandomLoot( MyMega^.InvCom );

		CompleteThePlot( GB , Scope , Control , MyMega , IsAQuest );
	end;

	CreateMegaPlot := MyMega;
end;

Function CreateSceneContent( GB: GameBoardPtr; Control: GearPtr; SPReq: String; Threat: Integer; DoDebug: Boolean ): GearPtr;
	{ Attempt to create some scene content for the scene being created in GB. }
	{ If the content is successfully created, it will end up as an invcom of }
	{ the adventure itself. It's up to the randmaps content inserter to install }
	{ everything + delete this plot. }
var
	it: GearPtr;
begin
	it := CreateMegaPlot( GB , FindRootScene( GB^.Scene ) , Control , FindRoot( GB^.Scene ) , SPReq , Threat , False , DoDebug );
	CreateSceneContent := it;
end;


Function XSceneDesc( Scene: GearPtr ): String;
	{ Return the regular scene description plus a few extra bits. }
var
	it: String;
	FID: LongInt;
	Adv,Fac: GearPtr;
begin
	{ Just copying the code above for now- it's not complicated, and should }
	{ save time from creating/copying two strings. If you are reading this }
	{ source code to learn how to program, DO NOT DO THIS YOURSELF!!! It's a }
	{ bad thing and will probably come back to bite me in the arse later on. }
	{ Also, feel free to use the word "arse" in your comments. }
	if ( Scene = Nil ) or not IsAScene( Scene ) then begin
		it := '';
	end else begin
		it := SAttValue( Scene^.SA , 'TYPE' ) + ' ' + SAttValue( Scene^.SA , 'CONTEXT' ) + ' SCALE' + BStr( Scene^.V );

		Adv := FindRoot( Scene );
		FID := NAttValue( Scene^.NA , NAG_Personal , NAS_FactionID );
		Fac := SeekFaction( Adv , FID );
		if Fac <> Nil then it := it + ' ' + SATtValue( Fac^.SA , 'DESIG' )
		else it := it + ' NOFAC';
		if ( FID <> 0 ) and ( FID = NAttValue( Adv^.NA , NAG_Personal , NAS_FactionID ) ) then it := it + ' PCFAC';
	end;

	XSceneDesc := QuoteString( it );
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








Function InsertMood( City,Mood: GearPtr; GB: GameBoardPtr ): Boolean;
	{ This function will insert a mood into the adventure and move it to its correct place. }
var
	AllOK: Boolean;
	TimeLimit: LongInt;
	Trigger: String;
	Dictionary: SAttPtr;
begin
	AllOK := MatchPlotToAdventure( City , Nil , City , Mood , GB , False );

	if AllOK then begin
		{ Set the time limit, if appropriate. }
		TimeLimit := NAttValue( Mood^.NA , NAG_MoodData , NAS_MoodTimeLimit );
		if TimeLimit > 0 then SetNAtt( Mood^.NA , NAG_MoodData , NAS_MoodTimeLimit , TimeLimit + GB^.ComTime );

		{ Do string substitutions- %name1%..%name20%, %city% }
		Dictionary := Nil;
		SetSAtt( Dictionary , '%city% <' + GearName( City ) + '>' );
		for TimeLimit := 1 to Num_Plot_Elements do begin
			SetSAtt( Dictionary , '%me_' + BStr( TimeLimit ) + '% <' + BStr( ElementID( Mood, TimeLimit ) ) + '>' );
			SetSAtt( Dictionary , '%me_name' + BStr( TimeLimit ) + '% <' + SAttValue( Mood^.SA , 'NAME_' + BStr( TimeLimit ) ) + '>' );
		end;
		ReplaceStrings( Mood , Dictionary );
		DisposeSAtt( Dictionary );

		{ Run the mood's initialization code. }
{		Trigger := 'UPDATE';
		TriggerGearScript( GB , Mood , Trigger );
}	end;

	InsertMood := AllOK;
end;

Function InsertRSC( Source,Frag: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Insert random scene content, then save some information that will be }
	{ needed later. }
begin
	InsertRSC := MatchPlotToAdventure( FindRoot( Source ) , Nil , Source , Frag , GB , False );;
end;

Procedure EndPlot( GB: GameBoardPtr; Adv,Plot: GearPtr );
	{ This plot is over... }
	Procedure DelinkAndPutAway( var LList: GearPtr );
		{ Delink and put away everything you find that needs }
		{ to be saved in this list. }
	var
		M,M2: GearPtr;
	begin
		M := LList;
		while M <> Nil do begin
			DelinkAndPutAway( M^.InvCom );
			DelinkAndPutAway( M^.SubCom );
			M2 := M^.Next;
			if NAttValue( M^.NA , NAG_ParaLocation , NAS_OriginalHome ) <> 0 then begin
				if StdPlot_Debug then DialogMsg( 'EndPlot: Putting away ' + GearName( M ) + '.' );
				DelinkGear( LList , M );
				PutAwayGlobal( GB , M );
			end;
			M := M2;
		end;
	end;
var
	P2,P3: GearPtr;
begin
	{ Deal with metascenes and other things that need to be cleaned up. }
	P2 := Plot^.SubCom;
	while ( P2 <> Nil ) do begin
		P3 := P2^.Next;

		{ Deal with metascenes as well. }
		if ( P2^.G = GG_MetaScene ) then begin
			{ This metascene has to be deleted. Remove everything from it. }
			if GB^.Scene = P2 then begin
				{ If this scene is the current scene, just turn it into }
				{ a dynamic scene and it'll be deleted automatically }
				{ when the player exits. }
				DelinkGear( Plot^.SubCom , P2 );
				if ( P2^.S >= 1 ) and ( P2^.S <= Num_Plot_Elements ) then SetNAtt( P2^.NA , NAG_Narrative , NAS_NID , ElementID( Plot , P2^.S ) );
				InsertInvCom( FindRoot( Plot ) , P2 );

			end else begin
				{ Search for global gears in the invcom, storing them as needed. }
				DelinkAndPutAway( P2^.InvCom );
				DelinkAndPutAway( P2^.SubCom );
				DeleteFrozenLocation( GearName( P2 ) , GB^.Camp^.Maps );
			end;

		end;

		P2 := P3;
	end;

	{ Finally, set the PLOT's type to absolutely nothing, so it will }
	{ be removed. }
	Plot^.G := GG_AbsolutelyNothing;
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
	C: GearPtr;
begin
	C := CreateMegaPlot( GB, FindRoot( Story ) , Story , Story , '*PLOT_CORE' , NAttValue( Story^.NA , NAG_Narrative , NAS_DifficultyLevel ) , False , XXRan_Debug );

	if C <> Nil then begin
		SetTrigger( GB , 'UPDATE' );

		{ Store the name of this component for reference. }
		StoreXXRanHistory( C );
	end else begin
		DialogMsg( 'Plot deadend in ' + GearName( Story ) + ': ' + StoryContext( GB , Story ) );
		DialogMsg( 'Send above information to "pyrrho12@yahoo.ca". Together, we can stomp out deadends.' );
	end;
end;

Function InsertArenaMission( Source,Mission: GearPtr; ThreatAtGeneration: Integer ): Boolean;
	{ Insert an arena mission into the campaign. }
var
	it: Boolean;
	P: GearPtr;
	T: Integer;
	EDesc: String;
begin
	{ Look through the elements. If KEY was requested, replace it with the }
	{ core campaign enemy faction. }
	for t := 1 to Num_Plot_Elements do begin
		EDesc := UpCase( SAttValue( Mission^.SA , 'ELEMENT' + BStr( T ) ) );
		if EDesc = 'KEY' then begin
			SetSAtt( Mission^.SA , 'ELEMENT' + BStr( T ) + ' <FACTION ENEMY>' );
			SetNAtt( Mission^.NA , NAG_ElementID , T , NAttValue( Source^.NA , NAG_AHQData , NAS_CoreMissionEnemy ) );
		end;
	end;

	{ Attempt the plot insertion. }
{	it := InsertPlot( Source , Source , Mission , Nil , ThreatAtGeneration );
}
	{ If the mission was successfully added, we need to do extra initialization. }
	if it then begin
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

Procedure UpdatePlots( GB: GameBoardPtr; Renown: Integer );
	{ It's time to update the plots. Check the city, and also its associated moods. }
	{ For each one, check to see how many associated plots it has, then try to load }
	{ a new plot if there's any room. }
var
	Adv,City,Mood: GearPtr;
	Function NumAttachedPlots( CID: LongInt ): Integer;
		{ Return the total number of plots attached to this Controller ID. }
	var
		P: GearPtr;
		Total: Integer;
	begin
		P := Adv^.InvCom;
		Total := 0;
		while P <> Nil do begin
			if ( P^.G = GG_Plot ) and ( NAttValue( P^.NA , NAG_Narrative , NAS_ControllerID ) = CID ) then Inc( Total );
			P := P^.Next;
		end;
		NumAttachedPlots := Total;
	end;
	Function NumAllowedPlots( Controller: GearPtr ): Integer;
		{ Return the maximum number of plots that this controller can have attached. }
	begin
		if Controller^.G = GG_CityMood then begin
			NumAllowedPlots := Controller^.V;
		end else begin
			NumAllowedPlots := 10;
		end;
	end;
	Procedure AddAPlot( Controller: GearPtr );
		{ Select a legal plot for this controller and attempt to insert it into }
		{ the adventure. }
	var
		plot_cmd: String;
		N: Integer;
	begin
		{ Determine the plot type being requested. If no explicit request is found, }
		{ go with a *GENERAL plot. }
		plot_cmd := SAttValue( Controller^.SA , 'PLOT_TYPE' );
		if plot_cmd = '' then plot_cmd := '*GENERAL';

		{ Next, create a list of those plots which match the plot_cmd. }
		CreateMegaPlot( GB, City, Controller, FindRoot( City ) , plot_cmd , Renown , False , False );
	end;
	Procedure CheckAttachedPlots( Controller: GearPtr );
		{ Check to see how many plots are associated with this controller. }
		{ If more plots are needed, add one. }
	var
		ControllerID: LongInt;
		Attached,Allowed: Integer;
	begin
		ControllerID := NAttValue( Controller^.NA , NAG_Narrative , NAS_NID );

		{ Count how many plots are being used by the city and each of its moods. }
		Allowed := NumAllowedPlots( Controller );

		{if XXRan_Debug and ( Controller^.G = GG_Scene ) then DialogMsg( GearName( Controller ) + ': ' + BStr( NumAttachedPlots( ControllerID ) ) + '/' + Bstr( Allowed ) );}
		if Allowed > 0 then begin
			Attached := NumAttachedPlots( ControllerID );

			{ If we have room for some more plots, try adding one. }
			if Attached < Allowed then begin
				AddAPlot( Controller );
			end;
		end;
	end;
begin
	{ Locate the adventure and the city. These will be important. }
	Adv := FindRoot( GB^.Scene );
	City := FindRootScene( GB^.Scene );

	{ If either the adventure or the city cannot be found, exit. }
	if ( Adv = Nil ) or ( Adv^.G <> GG_Adventure ) or ( City = Nil ) then Exit;

	{ Go through the city and the moods one by one. If there's a free space for a plot, }
	{ attempt to load one. }
	CheckAttachedPlots( City );
	Mood := City^.SubCom;
	while Mood <> Nil do begin
		if Mood^.G = GG_CityMood then CheckAttachedPlots( Mood );
		Mood := Mood^.Next;
	end;
end;

Procedure UpdateMoods( GB: GameBoardPtr );
	{ Check through all the towns in the current world. Check the time limits on all }
	{ moods found, removing those that have expired. If a town has no mood attached, }
	{ consider attaching one. }
	Function SetNewMood( Scene: GearPtr ): Boolean;
		{ Attempt to attach a new mood to this scene. Return TRUE if a mood was }
		{ added successfully, or FALSE if it wasn't. }
	var
		scene_context: String;
		Mood: GearPtr;
		InitOK: Boolean;
	begin
		scene_context := '';
		AddGearXRContext( GB , FindRoot( Scene ) , Scene , Scene_Context , 'L' );
		Mood := FindNextComponent( Standard_Moods , scene_context );
		InitOK := False;
		if Mood <> Nil then begin
			{ We don't want to use the entry from the standard mood list; }
			{ make a clone of it that we're free to whack around. }
			Mood := CloneGear( Mood );
			SetNAtt( Mood^.NA , NAG_MoodData , NAS_MoodTimeLimit , 86400 + Random( 86400 ) + Random( 86400 ) );
			InitOK := InsertMood( Scene , Mood , GB );
		end;
		SetNewMood := InitOK;
	end;
	Procedure UpdateMoodsForScene( Scene: GearPtr );
		{ Check to see if this scene has any moods. Delete those moods which }
		{ have outlived their usefulness. If no moods were found, consider }
		{ adding one. }
	var
		Mood,M2: GearPtr;
		MoodFound: Boolean;
		TimeLimit: LongInt;
	begin
		{ If Scene = Nil, we have a major problem. }
		if Scene = Nil then Exit;

		{ No mood found yet- we haven't started searching! }
		MoodFound := False;

		{ Look through all the moods in this scene and decide what to do with them. }
		Mood := Scene^.SubCom;
		while Mood <> Nil do begin
			M2 := Mood^.Next;
			if Mood^.G = GG_CityMood then begin
				{ Even if this mood is getting deleted, we don't want to load }
				{ a new one right away, so set MOODFOUND to TRUE... as long as }
				{ it's a major mood. Otherwise, who cares about it? }
				if Mood^.S = GS_MajorMood then MoodFound := True;

				{ Check the time limit now. }
				TimeLimit := NAttValue( Mood^.NA , NAG_MoodData , NAS_MoodTimeLimit );
				if ( TimeLimit > 0 ) and ( TimeLimit < GB^.ComTime ) then begin
					RemoveGear( Scene^.SubCom , Mood );
				end;
			end;
			Mood := M2;
		end;

		{ If no moods were found, maybe add a new mood. }
		if ( not MoodFound ) and ( NAttValue( Scene^.NA , NAG_Narrative , NAS_MoodRecharge ) <= GB^.ComTime ) then begin
			{ There's a chance of loading a new mood. }
			{ NIEHH: Nothing Interesting Ever Happens Here. If the scene being examined is the }
			{ town the PC is currently in, no new mood will be loaded. }
			if ( Random( 5 ) = 1 ) and ( Scene <> FindRootScene( GB^.Scene ) ) then begin
				{ Try to set a mood. }
				{ If setting the mood fails, set the recharge timer. }
				if not SetNewMood( Scene ) then SetNAtt( Scene^.NA , NAG_Narrative , NAS_MoodRecharge , GB^.ComTime + 7200 + Random( 43200 ) );
			end else begin
				{ No mood this time- try again in a day or so. }
				SetNAtt( Scene^.NA , NAG_Narrative , NAS_MoodRecharge , GB^.ComTime + 43200 + Random( 86400 ) );
			end;
		end;
	end;
var
	World, Scene: GearPtr;
begin
	World := FindWorld( GB , GB^.Scene );
	if World <> Nil then begin
		Scene := World^.SubCom;
		while Scene <> Nil do begin
			UpdateMoodsForScene( Scene );
			Scene := Scene^.Next;
		end;
	end;
end;

Procedure CreateChoiceList( GB: GameBoardPtr; Story: GearPtr );
	{ It's time for the PC to make a dramatic choice. Create a list of }
	{ legal choices, attempt to add them to the story, then mark the ones }
	{ which load with a tag to indicate their nature. }
var
	Context: String;
	LList,DC: GearPtr;
	DCRS,t,N: Integer;	{ Dramatic Choice Reward Seed, plus two counters }
	DCRList: Array [0..4] of Byte;	{ Dramatic Choice Reward List }
begin
	{ Step One: Determine the choice context. }
	Context := StoryContext( GB , Story );

	{ Determine which instant reward will be eligible for loading. }
	{ The reward choices are numbered 11 to 20. 16 through 20 are second-tier }
	{ copies of 11 through 15. }
	N := 0;
	{ Only add a reward option if we are not yet at the conclusion. }
	if NAttValue( Story^.NA , NAG_Narrative , NAS_DifficultyLevel ) <= 80 then begin
		DCRS := NAttValue( Story^.NA , NAG_XXRan , NAS_DCRSeed );
		if DCRS = 0 then begin
			DCRS := Random( 20000 ) + 1;
			SetNAtt( Story^.NA , NAG_XXRan , NAS_DCRSeed , DCRS );
		end;
		DCRS := DCRS + NAttValue( Story^.NA , NAG_XXRan , NAS_EpisodeNumber );
		for t := 11 to 15 do begin
			if NAttValue( Story^.NA , NAG_Completed_DC , T ) = 0 then begin
				DCRList[N] := T;
				Inc( N );
			end;
		end;
		if N > 0 then begin
			N := DCRList[ DCRS mod N ];
		end else begin
			{ All of the first-tier rewards have been completed. Check the }
			{ second tier. }
			N := 0;
			for t := 16 to 20 do begin
				if NAttValue( Story^.NA , NAG_Completed_DC , T ) = 0 then begin
					DCRList[N] := T;
					Inc( N );
				end;
			end;
			if N > 0 then N := DCRList[ DCRS mod N ];
		end;
	end;

	{ Step Two: Go through the list of dramatic choices. Try to add all }
	{ which apply in this situation. }
	LList := Dramatic_Choices;
	while LList <> Nil do begin
		{ A choice can be added if: }
		{ - It was the reward option selected and stored in N. }
		{  or   }
		{ - Its REQUIRES field is satisfied by the context generated above. }
		{ - It has not already been completed. }
		if ( LList^.V > 0 ) then begin
			if ( LList^.V = N ) or ( ( ( LList^.V < 11 ) or ( LList^.V > 20 ) ) and ( NAttValue( Story^.NA , NAG_Completed_DC , LList^.V ) = 0 ) and PartMatchesCriteria( Context , SAttValue( LList^.SA , 'REQUIRES' ) ) ) then begin
				DC := CloneGear( LList );
{				if InsertPlot( FindRoot( GB^.Scene ) , Story , DC , GB , NAttValue( Story^.NA , NAG_Narrative , NAS_DifficultyLevel ) ) then begin
					SetNAtt( DC^.NA , NAG_XXRan , NAS_IsDramaticChoicePlot , 1 );
				end;
}			end;
		end;
		LList := LList^.Next;
	end;
end;


Procedure ClearChoiceList( Story: GearPtr );
	{ The PC has apparently made a choice. Get rid of all the choice }
	{ records from this story since we don't need them anymore. }
var
	DC,DC2: GearPtr;
begin
	DC := Story^.InvCom;
	while DC <> Nil do begin
		DC2 := DC^.Next;
		if NAttValue( DC^.NA , NAG_XXRan , NAS_IsDramaticChoicePlot ) <> 0 then begin
			RemoveGear( Story^.InvCom , DC );
		end;
		DC := DC2;
	end;
end;



initialization
	persona_fragments := AggregatePattern( 'PFRAG_*.txt' , setting_directory );
	if persona_fragments = Nil then writeln( 'ERROR!!!' );
	Standard_Plots := LoadRandomSceneContent( '*.txt' , series_directory );
	Standard_Moods := AggregatePattern( 'MOOD_*.txt' , setting_directory );
	Dramatic_Choices := AggregatePattern( 'CHOICE_*.txt' , series_directory );

	MasterEntranceList := AggregatePattern( 'ENTRANCE_*.txt' , Setting_Directory );


finalization
	DisposeGear( persona_fragments );
	DisposeGear( Standard_Plots );
	DisposeGear( Standard_Moods );
	DisposeGear( Dramatic_Choices );

	DisposeGear( MasterEntranceList );


end.
