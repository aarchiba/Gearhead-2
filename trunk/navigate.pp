unit navigate;
	{ This unit is the flow controller for the RPG bits of the game. }
	{ It decides where the PC is, then when the PC exits a scene it }
	{ decides where to go next. }
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

{$IFDEF ASCII}
uses gears,locale,vidgfx,backpack;
{$ELSE}
uses gears,locale,glgfx,backpack;
{$ENDIF}

Const
	Max_Number_Of_Plots = 40;
	Plots_Per_Generation = 5;

Procedure SaveChar( PC: GearPtr );

Procedure Navigator( Camp: CampaignPtr; Scene: GearPtr; var PCForces: GearPtr );

Procedure StartCampaign( PC: GearPtr );
Procedure RestoreCampaign( RDP: RedrawProcedureType );

implementation

{$IFDEF ASCII}
uses arenaplay,arenascript,interact,gearutil,narration,texutil,ghprop,rpgdice,ability,
     ghchars,ghweapon,movement,ui4gh,vidmap,vidmenus,gearparser,playwright,randmaps;
{$ELSE}
uses arenaplay,arenascript,interact,gearutil,narration,texutil,ghprop,rpgdice,ability,
     ghchars,ghweapon,movement,ui4gh,glmap,glmenus,gearparser,playwright,randmaps;
{$ENDIF}

var
	MasterEntranceList: GearPtr;

Procedure DebugMessage( msg: String );
	{ Display a debugging message, and refresh the screen right away. }
begin
	DialogMsg( msg );
	ClrScreen;
	InfoBox( ZONE_Dialog );
	RedrawConsole;
	DoFlip;
end;

Procedure SaveChar( PC: GearPtr );
	{ Save this character to disk, in the "SaveGame" directory. }
var
	Leader: GearPtr;
	FName: String;		{ Filename for the character. }
	F: Text;		{ The file to write to. }
begin
	Leader := PC;
	while ( Leader <> Nil ) and ( ( Leader^.G <> GG_Character ) or ( NAttValue( Leader^.NA , NAG_CharDescription , NAS_CharType ) <> 0 ) ) do Leader := Leader^.Next;
	if Leader = Nil then Exit;

	FName := Save_Character_Base + GearName(Leader) + Default_File_Ending;
	Assign( F , FName );
	Rewrite( F );
	WriteCGears( F , PC );
	Close( F );
end;


Function NoLivingPlayers( PList: GearPtr ): Boolean;
	{ Return TRUE if the provided list of gears contains no }
	{ living characters. Return FALSE if it contains at least }
	{ one. }
var
	it: Boolean;
begin
	{ Start by assuming TRUE, then set to FALSE if a character is found. }
	it := TRUE;

	{ Loop through all the gears in the list. }
	while PList <> Nil do begin
		if ( PList^.G = GG_Character ) and NotDestroyed( PList ) and ( NAttValue( PList^.NA , NAG_CharDescription , NAS_CharType ) = 0 ) then begin
			it := False;
		end;
		PList := PList^.Next;
	end;

	{ Return the result. }
	NoLivingPlayers := it;
end;

Procedure CampaignUpkeep( Camp: CampaignPtr );
	{ Do some gardening work on this campaign. This procedure keeps }
	{ everything in the CAMP structure shiny, fresh, and working. }
	{ - Load a new PLOT, if appropriate. }
	{ - Delete dynamic scenes. }
var
	Part,Part2: GearPtr;
begin
	{ Get rid of any dynamic scenes that have outlived their usefulness. }
	{ If a SCENE is found in the InvComs, it must be dynamic. }
	Part := Camp^.Source^.InvCom;
	while Part <> Nil do begin
		Part2 := Part^.Next;

		if ( Part^.G = GG_Scene ) or ( Part^.G = GG_MetaScene ) then begin
			DeleteFrozenLocation( GearName( Part ) , Camp^.Maps );
			RemoveGear( Camp^.Source^.InvCom , Part );
		end;

		Part := Part2;
	end;
end;

Procedure Navigator( Camp: CampaignPtr; Scene: GearPtr; var PCForces: GearPtr );
	{ This is the role-playing flow controller. It decides what scene }
	{ of an adventure gear to load next. }
var
	N: Integer;
begin
	repeat
		if SCene <> Nil then N := ScenePlayer( Camp , Scene , PCForces );

		{ Move to the destination scene, if appropriate. }
		if N > 0 then begin
			{ Perform upkeep on the campaign- delete dynamic scenes, }
			{ load new plots, yadda yadda yadda. }
			CampaignUpkeep( Camp );

			Scene := FindActualScene( Camp^.Source , N );

		end else if N < 0 then begin
			Scene := FindMetascene( Camp^.Source , N );

		{ If no destination scene was implied, check to see if there's }
		{ a dynamic scene waiting to be processed. }
		end else if SCRIPT_DynamicEncounter <> Nil then begin
			Scene := SCRIPT_DynamicEncounter;

			{ Stick the scene into the campaign. Normally scenes }
			{ are filed under SubComs, but in this case we'll store }
			{ it as an InvCom so we'll remember to delete it later. }
			InsertInvCom( Camp^.Source , Scene );

			{ Set the DynamicEncounter var to Nil, since we've moved }
			{ the scene to the campaign and don't want the ArenaScript }
			{ procedures to try and modify or delete it any more. }
			SCRIPT_DynamicEncounter := Nil;

			{ Set N to >0, since we don't want the "until..." }
			{ condition to exit. }
			N := 1;
		end;

	until ( N = 0 ) or NoLivingPlayers( PCForces ) or ( Scene = Nil );

	{ If the game is over because the PC died, do a [MORE] prompt. }
	if NoLivingPlayers( PCForces ) then begin
		MoreKey;
	end;
end;

Function ExpandDungeon( Dung: GearPtr ): GearPtr;
	{ Expand this dungeon. Return the "goal scene", which is the lowest level generated. }
	{ Add sub-levels, branches, and goal requests. }
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
				T^.Stat[ STAT_WanderMon ] := T^.Stat[ STAT_WanderMon ] + 1 + Random( 4 ) + Random( 4 );

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
				AddSAtt( S^.SA , 'CONTENT' , ReplaceHash( dungeon_goal_content_string , BSTr( NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) * 10 ) ) )
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
	if Full_RPGWorld_Info then DebugMessage( 'Expanding ' + name_base );
	SetSAtt( Dung^.SA , 'DUNGEONNAME <' + name_base + '>' );
	type_base := SAttValue( Dung^.SA , 'TYPE' );
	sub_scenes := ExtractSubScenes;
	LowestLevel := Dung;
	Branch_Number := 0;

	ExpandThisLevel( Dung );

	if Sub_Scenes <> Nil then InsertSubCom( lowestLevel , Sub_Scenes );

	ExpandDungeon := lowestlevel;
end;

Procedure ConnectScene( Scene: GearPtr );
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
		{ Locate exits with a destination of -1, then give them the proper }
		{ destination of the parent scene. }
	begin
		while E <> Nil do begin
			if E^.G = GG_MapFeature then begin
				InitExits( S , E^.SubCom );
				InitExits( S , E^.InvCom );
			end else if ( E^.G = GG_MetaTerrain ) and ( E^.Stat[ STAT_Destination ] <> 0 ) and ( S^.Parent^.G = GG_Scene ) then begin
				E^.Stat[ STAT_Destination ] := S^.Parent^.S;
			end;

			E := E^.Next;
		end;
	end;
var
	E,Loc: GearPtr;
	Entrance: String;
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
			if E^.S = GS_MetaBuilding then SetSAtt( E^.SA , 'NAME <' + GearName( Scene ) + '>' );
			E^.Stat[ STAT_Destination ] := Scene^.S;
			if Scene^.Parent^.G <> GG_World then E^.Scale := Scene^.Parent^.V;
			if NAttValue( Scene^.NA , NAG_LOcation , NAS_X ) <> 0 then begin
				SetNAtt( E^.NA , NAG_Location , NAS_X , NAttValue( Scene^.NA , NAG_LOcation , NAS_X ) );
				SetNAtt( E^.NA , NAG_Location , NAS_Y , NAttValue( Scene^.NA , NAG_LOcation , NAS_Y ) );
			end;

			{ Insert "E" as an InvCom of the parent scene. }
			{ If E isn't a building or the parent scene isn't a world, }
			{ also insert a subzone for E so it won't be stuck randomly somewhere. }
			if ( E^.S = GS_MetaBuilding ) or ( Scene^.Parent^.G = GG_World ) then begin
				InsertInvCom( Scene^.Parent , E );
			end else begin
				Loc := NewSubZone( Scene^.Parent );
				InsertSubCom( Loc , E );
			end;
		end;
	end;

	{ Initialize exits back to the upper level. }
	InitExits( Scene , Scene^.SubCom );
	InitExits( Scene , Scene^.InvCom );
end;


Procedure InitializeCampaignScenes( Adv: GearPtr; var HiSceneID: Integer );
	{ Initialize the scenes of this adventure. This involves providing them all }
	{ with unique IDs, inserting content where needed, adding entrances to superscenes. }
	Procedure CheckAlongPath( S: GearPtr );
		{ Search along this path, initializing everything. }
	begin
		while S <> Nil do begin
			if S^.G = GG_Scene then begin
				S^.S := HiSceneID;
				Inc( HiSceneID );

				if AStringHasBString( SAttValue( S^.SA , 'TYPE' ) , 'DUNGEON' ) and ( SAttValue( S^.SA , 'DENTRANCE' ) <> '' ) and ( NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) = 0 ) then begin
					ExpandDungeon( S );
				end;

				ConnectScene( S );
			end;

			CheckAlongPath( S^.SubCom );

			S := S^.Next;
		end;
	end;
	Procedure InitNamedExits( Adv,Part: GearPtr );
		{ Search for gears with a DESTINATION string attribute. Try to }
		{ set the destination stat for these gears. }
	var
		dest: String;
		scene: GearPtr;
	begin
		while Part <> Nil do begin
			dest := SAttValue( Part^.SA , 'DESTINATION' );
			if dest <> '' then begin
				scene := SeekGearByName( Adv , dest );
				if ( Scene <> Nil ) and (( Scene^.G = GG_Scene ) or ( Scene^.G = GG_World )) and ( Part^.G = GG_MetaTerrain ) then begin
					Part^.Stat[ STAT_Destination ] := Scene^.S;
				end;
			end;
			InitNamedExits( Adv , Part^.SubCom );
			InitNamedExits( Adv , Part^.InvCom );
			Part := Part^.Next;
		end;
	end;
begin
	CheckAlongPath( Adv );

	InitNamedExits( Adv , Adv );

	{ Store the HiSceneID for later use. }
	SetNAtt( Adv^.NA , NAG_Narrative , NAS_MaxSceneID , HiSceneID );
end;

Procedure InitializeCampaignNPCs( Adv: GearPtr );
	{ Provide unique character IDs for each of the pre-loaded characters. }
var
	HighCID: LongInt;
	Procedure CheckAlongPath( P: GearPtr );
	var
		S: GearPtr;	{ The Persona for this NPC. }
	begin
		while P <> Nil do begin
			if P^.G = GG_Character then begin
				SetNAtt( P^.NA , NAG_Personal , NAS_CID , HighCID );
				S := SeekGearByName( Adv , GearName( P ) + ' PERSONA' );
				if S <> Nil then S^.S := HighCID;
				Inc( HighCID );
			end;
			CheckAlongPath( P^.SubCom );
			CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
	end;
begin
	HighCID := 1;
	CheckAlongPath( Adv );
end;

Procedure InitializeAdventureContent( Adv,HomeTown: GearPtr );
	{ Initialize the static adventure content. This consists mostly of }
	{ searching through the structure for content requests and filling }
	{ those recursively as needed. }
const
	NumSubQuests = 8;
var
	MasterList: GearPtr;	{ The master list of adventure content components. }
	ScenePrototypeList: GearPtr;	{ The list of prototype scenes. }
	MaxQID,MaxLID,MaxMaxLID: Integer;
	HomeTownID,WorldID,HTFacID: Integer;	{ Needed to calculate the difficulcy ratings. }

	{ Forward declaration }
	Function AddQuestComponent( Scene,Prev: GearPtr; ConReq: String; Threat,BranchPoints: Integer; KeyScene,KeyGear: GearPtr ): GearPtr; forward;

	Function NewQID(): Integer;
		{ Return a new unique Quest ID. }
	begin
		Inc( MaxQID );
		NewQID := MaxQID;
	end;
	Function NewLID(): Integer;
		{ Return a new Layer ID unique for this quest. }
	begin
		Inc( MaxLID );
		if MaxLID > MaxMaxLID then MaxMaxLID := MaxLID;
		NewLID := MaxLID;
	end;

	Procedure FormatQuestStrings( Master , LList: GearPtr );
		{ Format all the SAtts belonging to every gear in this linked list, }
		{ and do the same recursively for all subs and invs of each. }
	var
		S: SAttPtr;
		T,SceneSubQuestQID,SceneSubQuestLID,SceneKeyChara,SceneFac: Integer;
		Scene: GearPtr;
	begin
		while LList <> Nil do begin
			S := LList^.SA;
			{ Locate the scene for the SSQQID and SSQLID. }
			Scene := LList;
			while ( Scene <> Nil ) and ( Scene^.G <> GG_Scene ) do Scene := Scene^.Parent;
			if Scene <> Nil then begin
				SceneSubQuestQID := NAttValue( Scene^.NA , NAG_SubQuestQID , 0 );
				SceneSubQuestLID := NAttValue( Scene^.NA , NAG_SubQuestLID , 0 );
				SceneKeyChara := NAttValue( Scene^.NA , NAG_QuestInfo , NAS_SceneKeyChara );
				SceneFac := NAttValue( Scene^.NA , NAG_Personal , NAS_FactionID );
			end else begin
				SceneSubQuestQID := 0;
				SceneSubQuestLID := 0;
				SceneKeyChara := 0;
				SceneFac := 0;
			end;

			while S <> Nil do begin
				{ Here's the big ugly formatting block. }
				{ It should be possible to speed this up considerably by }
				{ handling things in an efficient way, but you know what they }
				{ say about premature optimization. Something about the }
				{ programmer's wife not liking it. }
				ReplacePat( S^.Info , '%id%' , BStr( NAttValue( Master^.NA , NAG_QuestInfo , NAS_LayerID ) ) );
				ReplacePat( S^.Info , '%qid%' , BStr( NAttValue( Master^.NA , NAG_QuestInfo , NAS_QuestID ) ) );
				ReplacePat( S^.Info , '%prev_id%' , BStr( NAttValue( Master^.NA , NAG_SubQuestLID , 0 ) ) );
				ReplacePat( S^.Info , '%prev_qid%' , BStr( NAttValue( Master^.NA , NAG_SubQuestQID , 0 ) ) );
				ReplacePat( S^.Info , '%threat%' , BStr( NAttValue( Master^.NA , NAG_QuestInfo , NAS_DifficulcyLevel ) ) );
				ReplacePat( S^.Info , '%sktar%' , BStr( BasicSkillTarget( NAttValue( Master^.NA , NAG_QuestInfo , NAS_DifficulcyLevel ) ) ) );
				ReplacePat( S^.Info , '%sktar_hard%' , BStr( HardSkillTarget( NAttValue( Master^.NA , NAG_QuestInfo , NAS_DifficulcyLevel ) ) ) );
				ReplacePat( S^.Info , '%scenesq_qid%' , BStr( SceneSubQuestQID ) );
				ReplacePat( S^.Info , '%scenesq_id%' , BStr( SceneSubQuestLID ) );
				ReplacePat( S^.Info , '%scenechar%' , BStr( SceneKeyChara ) );
				ReplacePat( S^.Info , '%scenefac%' , BStr( SceneFac ) );

				for t := 1 to Num_Plot_Elements do begin
					ReplacePat( S^.Info , '%' + BStr( T ) + '%' , BStr( ElementID( Master , T ) ) );
					ReplacePat( S^.Info , '%s' + BStr( T ) + '%' , BStr( NAttValue( Master^.NA , NAG_QuestElemScene , T ) ) );
					ReplacePat( S^.Info , '%name' + BStr( T ) + '%' , SAttValue( Master^.SA , 'NAME_' + BStr( T ) ) );
				end;

				for t := 1 to NumSubQuests do begin
					ReplacePat( S^.Info , '%id' + BStr( T ) + '%' , BStr( NAttValue( Master^.NA , NAG_SubQuestLID , T ) ) );
					ReplacePat( S^.Info , '%qid' + BStr( T ) + '%' , BStr( NAttValue( Master^.NA , NAG_SubQuestQID , T ) ) );
				end;

				S := S^.Next;
			end;
			FormatQuestStrings( Master , LList^.SubCom );
			FormatQuestStrings( Master , LList^.InvCom );

			{ If this is a root level gear, we want to check its subcoms but not }
			{ its siblings. }
			if LList^.Parent = Nil then begin
				LList := Nil;
			end else begin
				LList := LList^.Next;
			end;
		end;
	end;

	Function NewSceneID: Integer;
		{ The campaign initialization should have set the maximum scene ID currently }
		{ in use. We'll use that to get a new ID. }
	begin
		AddNAtt( Adv^.NA , NAG_Narrative , NAS_MaxSceneID , 1 );
		NewSceneID := NAttValue( Adv^.NA , NAG_Narrative , NAS_MaxSceneID );
	end;

	Function AddNewScene( RootScene,Frag,KeyGear: GearPtr; SceneReq: String; AddEntrance: Boolean; BranchPoints,Faction,Threat: Integer ): GearPtr;
		{ Attempt to add a new scene to the adventure. }
		{ If this scene has a subquest associated with it, add that too. }
		{ If ADDENTRANCE is TRUE, we need to add an entrance subquest as well. }
	var
		NewScene,SQList,Entrance: GearPtr;
		ShoppingList: NAttPtr;
		InitOK: Boolean;
		SQType: String;
		SID: Integer;
	begin
		{ Add the context for the number of branch points. }
		if Full_RPGWorld_Info then DebugMessage( 'AddNewScene: ' + SceneReq );
		if BranchPoints > 0 then SceneReq := SceneReq + ' BRANCHES';

		{ Create the shopping list }
		ShoppingList := CreateComponentList( ScenePrototypeList , SceneReq );

		{ Determine the new ID for this scene. }
		SID := NewSceneID;

		{ Search for a new scene until either we get one or we run out of options. }
		NewScene := Nil;
		while ( NewScene = Nil ) and ( ShoppingList <> Nil ) do begin
			{ Pick one of the potential scenes randomly. }
			NewScene := CloneGear( SelectComponentFromList( ScenePrototypeList , ShoppingList ) );
			InsertSubCom( Adv , NewScene );

			{ Set the values needed by this scene. }
			NewScene^.S := SID;
			if KeyGear <> Nil then SetNAtt( NewScene^.NA , NAG_QuestInfo , NAS_SceneKeyChara , NAttValue( KeyGear^.NA , NAG_Personal , NAS_CID ) );
			SetNAtt( NewScene^.NA , NAG_Personal , NAS_FactionID , Faction );
			SetNAtt( NewScene^.NA , NAG_QuestInfo , NAS_DifficulcyLevel , NAttValue( Frag^.NA , NAG_QuestInfo , NAS_DifficulcyLevel ) );
			if SAttValue( NewScene^.SA , 'HABITAT' ) = '' then begin
				SetSAtt( NewScene^.SA , 'HABITAT <' + SAttValue( RootScene^.SA , 'HABITAT' ) + '>' );
			end;
			{ We don't store the QuestID right now; that gets done later as a check }
			{ to see whether or not this scene has yet been "claimed" by a quest. }

			InitOK := True;

			{ The scene insertion is successful if all this scene's }
			{ subquests can be initialized. }
			SQType := SAttValue( NewScene^.SA , 'QUEST' );
			if SQType <> '' then begin
				SQList := AddQuestComponent( RootScene , Frag , SQType , Threat , BranchPoints - 1 , NewScene , KeyGear );
				if SQList = Nil then InitOK := False
				else begin
					SetNAtt( NewScene^.NA , NAG_QuestInfo , NAS_QuestBranches , NumSiblingGears( SQList ) );
					SetNatt( NewScene^.NA , NAG_SubQuestQID , 0 , NAttValue( SQList^.NA , NAG_QuestInfo , NAS_QuestID ) );
					SetNatt( NewScene^.NA , NAG_SubQuestLID , 0 , NAttValue( SQList^.NA , NAG_QuestInfo , NAS_LayerID ) );
				end;
			end else begin
				SQList := Nil;
			end;

			{ If an entrance was requested, add that here. }
			if AddEntrance and ( NewScene <> Nil ) then begin
				SQType := SAttValue( NewScene^.SA , 'QUEST_ENTRANCE' );
				if SQType <> '' then begin
					Entrance := AddQuestComponent( RootScene , Frag , SQType , Threat , BranchPoints - 1 , NewScene , KeyGear );
					if Entrance = Nil then InitOK := False
					else begin
						AddNAtt( NewScene^.NA , NAG_QuestInfo , NAS_QuestBranches , NumSiblingGears( Entrance ) );
					end;
				end else begin
					Entrance := Nil;
					InitOK := False;
				end;
			end else begin
				Entrance := Nil;
			end;

			if InitOK then begin
				{ If this scene was a dungeon, add some more points to the QuestBranches }
				{ counter. }
				if AStringHasBString( SAttValue( NewScene^.SA , 'TYPE' ) , 'DUNGEON' ) then begin
					AddNAtt( NewScene^.NA , NAG_QuestInfo , NAS_QuestBranches , 5 );
				end;

				{ Delink the new scene and append its subquests + entrance }
				DelinkGear( Adv^.SubCom , NewScene );
				AppendGear( NewScene , SQList );
				AppendGear( NewScene , Entrance );
			end else begin
				RemoveGear( Adv^.SubCom , NewScene );
				DisposeGear( SQList );
				DisposeGear( Entrance );
			end;
		end;

		{ Get rid of the shopping list }
		DisposeNAtt( ShoppingList );

		AddNewScene := NewScene;
	end;

	Function QuestIsReusable( Q: GearPtr ): Boolean;
		{ Return TRUE if this quest is reusable, or FALSE otherwise. }
	begin
		QuestIsReusable := AStringHasBString( SAttValue( Q^.SA , 'SPECIAL' ) , 'REUSABLE' );
	end;

	Procedure ScaleRandomTreasure( LList: GearPtr; Threat: Integer );
		{ Scale any random loot values found along this path. }
		{ The treasures found as part of a quest should be }
		{ commesurate with the difficulcy rating of the quest. }
	var
		LootValue: LongInt;
	begin
		while LList <> Nil do begin
			if NAttValue( LList^.NA , NAG_Narrative , NAS_RandomLoot ) > 0 then begin
				LootValue := Calculate_Threat_Points( Threat , 2 + Random( 4 ) );
				SetNAtt( LList^.NA , NAG_Narrative , NAS_RandomLoot , LootValue );
			end;
			ScaleRandomTreasure( LList^.SubCom , Threat );
			ScaleRandomTreasure( LList^.InvCom , Threat );
			LList := LList^.Next;
		end;
	end;

	Function AddQuestComponent( Scene,Prev: GearPtr; ConReq: String; Threat,BranchPoints: Integer; KeyScene,KeyGear: GearPtr ): GearPtr;
		{ Attempt to add a new component to the tree based on the provided }
		{ information. If installation succeeded, this function will return }
		{ the component added (along with all of its sub-quests appended }
		{ to the end). }
		{ BRANCHPTS indicates how many times this component can branch. }
		Procedure CompBranchPoints( var BPMax: Integer; SQ: GearPtr );
			{ Take a look at the generated subquest and see whether or not to }
			{ increase the branches total. }
		var
			SQB: Integer;
		begin
			if ( SQ <> Nil ) then begin
				SQB := NAttValue( SQ^.NA , NAG_QuestInfo , NAS_QuestBranches );
				if SQB > BPMax then BPMax := SQB;
			end;
		end;
	var
		SContext,ComType,msg: String;
		ShoppingList: NAttPtr;
		CPro,C,C2,NewCom,SubQ,NewScene,Elem: GearPtr;
		SQBranches: Integer;	{ The highest branch points of a subquest/newscene }
					{ not including successors. }
		SQTotal: Integer;	{ As above, but including successors. }
		QID,LID,T,N,SFaction,GrabElement: Integer;
		Elem_ID,Elem_Scene: Array [1..Num_Plot_Elements] of LongInt;
		Elem_Code: Array [1..Num_Plot_Elements] of Char;
		QInUse,InitOK,DoDebug: Boolean;
	begin
		{ Remove the ComType from the Content Request }
		{ and combine it with the scene context. }
		if Full_RPGWorld_Info then DebugMessage( 'AddQuestCom: ' + ConReq );
		SContext := QuoteString( SceneContext( Nil , Scene ) );
		ComType := ExtractWord( ConReq ) + ' ' + SContext;

		{ Determine the Quest ID for this fragment now. If nessecary generate a }
		{ new Quest ID; otherwise use the Quest ID from the caller. }
		if ( Prev = Nil ) or ( ComType[2] = ':' ) then begin
			QID := NewQID();
		end else begin
			QID := NAttValue( Prev^.NA , NAG_QuestInfo , NAS_QuestID );
		end;
		LID := NewLID();

		{ Maybe increase the threat level. }
		DeleteWhiteSpace( ConReq );
		if ( ConReq <> '' ) and ( ConReq[1] = '#' ) then begin
			DeleteFirstChar( ConReq );
			T := ExtractValue( ConReq );
			if T > 0 then Threat := T;
		end else if ( Prev <> Nil ) and ( ComType[2] <> ':' ) then begin
			Threat := Threat + Random( 5 ) + 1;
		end;
		ComType := ComType + ' ' + DifficulcyContext( Threat );

		{ Add the context for the KeyScene and KeyChara. }
		if ( KeyScene <> Nil ) then begin
			AddGearXRContext( Nil , Adv , KeyScene , ComType , 'S' );
		end;
		if KeyGear <> Nil then begin
			AddGearXRContext( Nil , Adv , KeyGear , ComType , 'C' );
			{ If this is the first component to be added, record the }
			{ QuestID in the NPC. }
			if Prev = Nil then SetNAtt( KeyGear^.NA , NAG_QuestInfo , NAS_QuestID , QID );
		end;

		{ Add the context for the parameter elements. }
		for t := 1 to Num_Plot_Elements do begin
			Elem_ID[t] := 0;
			Elem_Code[t] := 'I';
			Elem_Scene[t] := 0;
		end;
		if Prev <> Nil then begin
			for t := 1 to Num_Plot_Elements do begin
				N := ExtractValue( ConReq );
				if ( N >= 1 ) and ( N <= Num_Plot_Elements ) then begin
					AddElementContext( Nil , Prev , ComType , Bstr( T )[1] , N );
					Elem_ID[ t ] := ElementID( Prev , N );
					msg := SAttValue( Prev^.SA , 'ELEMENT' + BStr( n ) );
					Elem_Code[ t ] := msg[1];
					Elem_Scene[ t ] := NAttValue( Prev^.NA , NAG_QuestElemScene , N );
					if Elem_ID[t] = 0 then begin
						DialogMsg( 'ERROR: Copying erroneous parameter' );
						DialogMsg( '=Element Desc: "' + msg + '"' );
					end;
				end;
			end;
		end;

		{ Add the context for the number of branch points. }
		if BranchPoints > 0 then ComType := ComType + ' BRANCHES';

		{ Create the component list. }
		ShoppingList := CreateComponentList( MasterList , ComType );

		{ Keep going until we get a match or run out of components. }
		NewCom := Nil;
		SubQ := Nil;

		while ( NewCom = Nil ) and ( ShoppingList <> Nil ) do begin
			{ Search through the list of components for one that }
			{ matches our criteria. }
			CPro := SelectComponentFromList( MasterList , ShoppingList );
			C := CloneGear( CPro );
			{ Right away, determine whether or not to use the debugging messages. }
			DoDebug := GearName( C ) = 'DEBUG';

			{ Copy over the submitted params. }
			for t := 1 to Num_Plot_Elements do begin
				if Elem_ID[t] <> 0 then begin
					SetNAtt( C^.NA , NAG_ElementID , T , Elem_ID[t] );
					SetSAtt( C^.SA , 'ELEMENT' + BStr( T ) + ' <' + Elem_Code[t] + '>' );
					SetNAtt( C^.NA , NAG_QuestElemScene , T , Elem_Scene[t] );
				end;
			end;

			{ Record the ID numbers of the calling fragment. }
			if Prev <> Nil then begin
				SetNatt( C^.NA , NAG_SubQuestQID , 0 , NAttValue( Prev^.NA , NAG_QuestInfo , NAS_QuestID ) );
				SetNatt( C^.NA , NAG_SubQuestLID , 0 , NAttValue( Prev^.NA , NAG_QuestInfo , NAS_LayerID ) );
			end;

			{ Record the keyscene and keychara IDs. }
			SetNAtt( C^.NA , NAG_QuestElemScene , 0 , KeyScene^.S );
			if ( KeyGear <> Nil ) then begin
				if KeyGear^.G = GG_Character then begin
					SetSAtt( C^.SA , 'ELEMENT0 <C>' );
					SetNAtt( C^.NA , NAG_ElementID , 0 , NAttValue( KeyGear^.NA , NAG_Personal , NAS_CID ) );
				end else begin
					SetSAtt( C^.SA , 'ELEMENT0 <I>' );
					SetNAtt( C^.NA , NAG_ElementID , 0 , NAttValue( KeyGear^.NA , NAG_Narrative , NAS_NID ) );
				end;
			end;

			{ Record the difficulcy rating. }
			SetNAtt( C^.NA , NAG_QuestInfo , NAS_DifficulcyLevel , Threat );
			ScaleRandomTreasure( C , Threat );

			{ Reset the SubQuest Branch Total to a minimum value of 1. }
			SQBranches := 1;
			SQTotal := 1;

			{ Attempt to match it to the city. }
			{ Every newly defined gear needs a scene. Unless a new scene }
			{ is being created, make sure we have a scene that matches }
			{ already in the city. }
			{ If the attempt to prepare this fragment fails it will be }
			{ automatically deleted. Otherwise it will be installed as an InvCom }
			{ of the adventure. }
			QInUse := NAttValue( C^.NA , NAG_QuestInfo , NAS_QuestUsed ) <> 0;
			InitOK := ( not QInUse ) and PrepareQuestFragment( Scene , C , DoDebug );
			if InitOK then begin
				{ Set the QuestID and LayerID since these will be needed }
				{ by subquests. }
				SetNAtt( C^.NA , NAG_QuestInfo , NAS_QuestID , QID );
				SetNAtt( C^.NA , NAG_QuestInfo , NAS_LayerID , LID );

				{ Set this component as used, so we don't get any recursive }
				{ looping of components. }
				if not QuestIsReusable( C ) then begin
					SetNAtt( CPro^.NA , NAG_QuestInfo , NAS_QuestUsed , 1 );
				end;

				{ Continue with the initialization. This component will only be }
				{ successfully initialized if its sub-quests and complications }
				{ are also successfully initialized. }

				{ Create any new scenes requested and store their IDs; }
				{ we need this info for the sub-quests. }
				for t := 1 to Num_Plot_Elements do begin
					msg := SAttValue( C^.SA , 'SCENE' + BStr( t ) );
					if HeadMatchesString( 'NEW ' , msg ) then begin
						ExtractWord( msg );

						{ Add the context for the associated element. }
						Elem := SeekPlotElement( Adv , C , T , Nil );
						AddGearXRContext( Nil , Adv , Elem , msg , Bstr( T )[1] );
						SFaction := GetFactionID( Elem );

						{ Send the new scene request to the proper function. }
						{ As of right now, the scene's entrance should have }
						{ the desig "ENTRANCE %s[t]%". If no such gear can }
						{ be found in C, we need a new entrance. }
						C2 := SeekGearByDesig( C , 'ENTRANCE %s' + BStr( T ) + '%' );
						NewScene := AddNewScene( Scene , C , Elem , msg + ' ' + SContext , C2 = Nil , BranchPoints - 1 , SFaction , Threat );
						if NewScene = Nil then begin
							InitOK := False;
							DialogMsg( GearName( C ) + ' DEBUG Quest error: NewScene ' + BStr( T ) + ' failed.' );
							break;
						end else begin
							{ New scenes might add to the branch total. }
							CompBranchPoints( SQBranches , NewScene );

							{ Append the new scene to the SubQuest list. }
							AppendGear( SubQ , NewScene );

							SetNAtt( C^.NA , NAG_QuestElemScene , T , NewScene^.S );
							SetSAtt( NewScene^.SA , 'name_1 <' + SAttValue( C^.SA , 'NAME_' + BStr( T ) ) + '>' );
							if SAttValue( C^.SA , 'ELEMENT' + BStr( T ) ) = '' then begin
								SetSAtt( C^.SA , 'ELEMENT' + BStr( T ) + ' <Scene>' );
								SetNAtt( C^.NA , NAG_ElementID , T , NewScene^.S );
								SetSAtt( C^.SA , 'NAME_' + BStr( T ) + ' <' + GearName( NewScene ) + '>' );
							end;

						end;
					end else if HeadMatchesString( 'GRAB ' , msg ) then begin
						{ We need to copy a scene being used by a previous element. }
						{ First get rid of the GRAB tag, then find the number of }
						{ the scene we want. }
						ExtractWord( msg );
						GrabElement := ExtractValue( msg );
						N := NAttValue( C^.NA , NAG_QuestElemScene , GrabElement );
						NewScene := FindActualScene( Adv , N );
						if N <> 0 then begin
							SetNAtt( C^.NA , NAG_QuestElemScene , T , N );
							if SAttValue( C^.SA , 'ELEMENT' + BStr( T ) ) = '' then begin
								SetSAtt( C^.SA , 'ELEMENT' + BStr( T ) + ' <Scene>' );
								SetNAtt( C^.NA , NAG_ElementID , T , N );
								SetSAtt( C^.SA , 'NAME_' + BStr( T ) + ' <' + GearName( NewScene ) + '>' );
							end;
						end else begin
							InitOK := False;
							DialogMsg( 'DEBUG Quest error: Grabbed Scene ' + BStr( T ) + ' not found.' );
							DialogMsg( '= Grab ' + BStr( GrabElement ) + ', ' + SAttValue( C^.SA , 'ELEMENT' + BStr( GrabELement ) ) );
							Break;
						end;

					end;
				end; { For T...}

				{ Now that we have all of the scenes we can proceed with the }
				{ sub-quests themselves. }
				{ If any of the subquest requests fail delete the component. }
				if InitOK then for t := 1 to NumSubQuests do begin
					msg := SAttValue( C^.SA , 'QUEST' + BStr( t ) );
					if msg <> '' then begin
						{ Is this subquest a successor or complication? }
						if ( Length( msg ) > 1 ) and ( msg[2] = ':' ) then begin
							C2 := AddQuestComponent( Scene , C , msg , Threat , BranchPoints - 1 , KeyScene , KeyGear );
							CompBranchPoints( SQBranches , C2 );
						end else begin
							{ This is a successor. It will not affect the branch points of this component. }
							C2 := AddQuestComponent( Scene , C , msg , Threat , BranchPoints - SQBranches , KeyScene , KeyGear );
							CompBranchPoints( SQTotal , C2 );
						end;

						if C2 <> Nil then begin
							AppendGear( SubQ , C2 );

							{ Store the SubQuest ID numbers. }
							SetNAtt( C^.NA , NAG_SubQuestQID , T , NAttValue( C2^.NA , NAG_QuestInfo , NAS_QuestID ) );
							SetNAtt( C^.NA , NAG_SubQuestLID , T , NAttValue( C2^.NA , NAG_QuestInfo , NAS_LayerID ) );

						end else begin
							{ This subquest could not be inserted. }
							{ Therefore, the insertion of this main }
							{ quest fails as well. }
							InitOK := False;
							if DoDebug then DialogMsg( 'DEBUG Quest error: Subquest ' + BStr( T ) + ' failed.' );
							Break;
						end;
					end;
				end;

				{ If initialization failed for whatever reason, delete }
				{ the fragment and also any new scenes created by it. }
				if not InitOK then begin
					RemoveGear( Adv^.InvCom , C );
					DisposeGear( SubQ );
				end;
			end else if DoDebug then begin
				DialogMsg( 'DEBUG Quest error: PrepareQuestFragment Failed.' );
			end;

			if DoDebug and not InitOk then DialogMsg( 'Insertion of DEBUG fragment failed.' );

			if InitOK then begin
				NewCom := C;
			end else if not QInUse then begin
				SetNAtt( CPro^.NA , NAG_QuestInfo , NAS_QuestUsed , 0 );
			end;
		end;

		{ Dispose of the list. }
		DisposeNAtt( ShoppingList );

		{ Delink our new component from the adventure and attach its subquests. }
		{ Also do all the string substitutions. }
		if NewCom <> Nil then begin
			DelinkGear( Adv^.InvCom , NewCom );

			{ Record the longest branch length generated by this component. }
			if SQBranches > SQTotal then SQTotal := SQBranches;
			SetNAtt( NewCom^.NA , NAG_QuestInfo , NAS_QuestBranches , SQTotal );

			FormatQuestStrings( NewCom , NewCom );

			{ Also format the quest strings for any scene associated with this }
			{ quest. }
			C := SubQ;
			while C <> Nil do begin
				if ( C^.G = GG_Scene ) and ( NAttValue( C^.NA , NAG_QuestInfo, NAS_QuestID ) = 0 ) then begin
					FormatQuestStrings( NewCom , C );
					SetNAtt( C^.NA , NAG_QuestInfo , NAS_QuestID , QID );
				end;
				C := C^.Next;
			end;

			AppendGear( NewCom , SubQ );
		end;

		{ Return the results. }
		AddQuestComponent := NewCom;
	end;

	Function FindQuestScene( SID: Integer ): GearPtr;
		{ Attempt to find the requested scene. If this scene is a dungeon and has }
		{ a separate "goal level", return that instead. }
	var
		it: GearPtr;
		GLID: Integer;	{ Goal Level ID. }
	begin
		it := FindActualScene( Adv , SID );
		if it <> Nil then begin
			GLID := NAttValue( it^.NA , NAG_QuestInfo , NAS_GoalLevel );
			if GLID <> 0 then it := FindActualScene( Adv , GLID );
		end;
		FindQuestScene := it;
	end;

	Procedure InsertComponent( Frag: GearPtr );
		{ FRAG is a quest component. Insert it into the adventure. }
		Procedure SetTeamForAllMasters( Scene,LList: GearPtr );
			{ Set a team number for all the master gears you find. }
			{ Recursively search through all children as well. }
		begin
			while LList <> Nil do begin
				if IsMasterGear( LList ) then ChooseTeam( LList , Scene );
				SetTeamForAllMasters( Scene , LList^.InvCom );
				SetTeamForAllMasters( Scene , LList^.SubCom );
				LList := LList^.Next;
			end;
		end;
	var
		E,Scene,PScene,Container,Team,Persona,MoveThis: GearPtr;
		T: Integer;
		ElemDesc: String;
	begin
		if Full_RPGWorld_Info then DebugMessage( 'InsertCom: ' + GearName( Frag ) );

		{ Unless this fragment is reusable, remove its prototype }
		{ from the master list now. }
		if not QuestIsReusable( Frag ) then begin
			E := SeekCurrentLevelGear( MasterList , Frag^.G , Frag^.S );
			if E <> Nil then RemoveGear( MasterList , E )
			else dialogmsg( 'WARNING: Quest fragment ' + GearName( Frag ) + ' used multiple times.' );
		end;

		{ Initialize personas and scenes. }
		for t := 1 to Num_Plot_Elements do begin
			{ Start with the element description. If nonempty, }
			{ that means we have a significant element to deal with. }
			ElemDesc := SAttValue( Frag^.SA , 'ELEMENT' + BStr( T ) );
			if ElemDesc <> '' then begin
				Scene := FindQuestScene( NAttValue( Frag^.NA , NAG_QuestElemScene , T ) );
				PScene := Scene;

				{ If this is a character, deal with the persona. }
				if UpCase( ElemDesc[1] ) = 'C' then begin
					Persona := FindMetaPersona( Frag , T );
					{ Locate the main persona; }
					{ store it in variable "E" and megalist away. }
					E := SeekPersona( Adv , ElementID( Frag , T ) );

					if PScene = Nil then begin
						{ We don't have a scene for this character. Weird. }
						DialogMsg( 'WARNING: No scene for Persona ' + Bstr( T ) + ' of ' + GearName( Frag ) );
						PScene := Adv^.SubCom;
						DialogMsg( 'I''ll just use ' + GearName( PScene ) + ' instead.' );
					end;

					if Persona <> Nil then begin
						{ We have a persona fragment to }
						{ deal with. }
						if E = Nil then begin
							DelinkGear( Frag^.SubCom , Persona );
							Persona^.S := ElementID( Frag , T );
							InsertSubCom( PScene , Persona );
							SetNAtt( Persona^.NA , NAG_QuestInfo , NAS_QuestID , NAttValue( Frag^.NA , NAG_QuestInfo , NAS_QuestID ) );
							SetNAtt( Persona^.NA , NAG_QuestInfo , NAS_LayerID , NAttValue( Frag^.NA , NAG_QuestInfo , NAS_LayerID ) );
						end else if E <> Nil then begin
							BuildMegalist( E , Persona^.SA );
						end;
					end else if ( E = Nil ) then begin
						{ We don't have a persona yet, and no persona }
						{ is defined in the component, so create a new }
						{ one from scratch. }
						Persona := LoadNewSTC( 'PERSONA_BLANK' );
						InsertSubCom( PScene , Persona );
						Persona^.S := ElementID( Frag , T );
						SetNAtt( Persona^.NA , NAG_QuestInfo , NAS_QuestID , NAttValue( Frag^.NA , NAG_QuestInfo , NAS_QuestID ) );
						SetNAtt( Persona^.NA , NAG_QuestInfo , NAS_LayerID , NAttValue( Frag^.NA , NAG_QuestInfo , NAS_LayerID ) );
					end;
				end;

				{ Deal with the scene scripts and content. }
				{ These are stored in metascenes in the subs of the frag. }
				if Scene <> Nil then begin
					Persona := SeekCurrentLevelGear( Frag^.SubCom , GG_MetaScene , T );
					if Persona <> Nil then begin
						{ Locate the "Container"- this will be the home }
						{ of this element in this scene. Mark it as such. }
						Container := SeekGearByDesig( Persona^.SubCom , 'HOME' );
						if Container <> Nil then begin
							SetSAtt( Container^.SA , 'DESIG <CONTAINER ' + BStr( T ) + '>' );
						end;

						BuildMegaList( Scene , Persona^.SA );
						while Persona^.InvCom <> Nil do begin
							MoveThis := Persona^.InvCom;
							DelinkGear( Persona^.InvCom , MoveThis );
							InsertInvCom( Scene , MoveThis );
							SetTeamForAllMasters( Scene , MoveThis );
						end;
						while Persona^.SubCom <> Nil do begin
							MoveThis := Persona^.SubCom;
							DelinkGear( Persona^.SubCom , MoveThis );
							InsertSubCom( Scene , MoveThis );
							SetTeamForAllMasters( Scene , MoveThis );
						end;
					end;
				end;
			end;	{ if ElemDesc <> '' }
		end;	{ for t... }

		{ Deploy all the prefab gears }
		while Frag^.InvCom <> Nil do begin
			E := Frag^.InvCom;
			DelinkGear( Frag^.InvCom , E );

			{ Find the element slot that this element corresponds to. }
			if ( E^.G = GG_Character ) and ( NAttValue( E^.NA , NAG_Personal , NAS_CID ) <> 0 ) then begin
				T := PlotElementID( Frag , 'C' , NAttValue( E^.NA , NAG_Personal , NAS_CID ) );
			end else begin
				T := PlotElementID( Frag , 'I' , NAttValue( E^.NA , NAG_Narrative , NAS_NID ) );
			end;

			{ Next, attempt to locate the scene associated with this element. }
			{ It should be stored as a NAtt. }
			Scene := FindQuestScene( NAttValue( Frag^.NA , NAG_QuestElemScene , T ) );
			if Scene = Nil then begin
				DialogMsg( 'ERROR: No scene ' + BStr( T ) + ' in ' + GearName( Frag ) );
				Container := Nil;
			end else begin
				Container := SeekGearByDesig( Scene^.SubCom , 'CONTAINER ' + BStr( T ) );
			end;
			{ Clear the container's designation, we no longer need it. }
			if Container <> Nil then SetSAtt( Container^.SA , 'DESIG <>' );
			if ( Container = Nil ) or ( Container^.G <> GG_MapFeature ) then Container := Scene;

			{ As long as we found the scene, proceed with the movement of stuff. }
			if Scene <> Nil then begin
				InsertInvCom( Container , E );
				if Container^.G = GG_MapFeature then SetNAtt( E^.NA , NAG_ComponentDesc , NAS_ElementID , 1 );
				SetNAtt( E^.NA , NAG_QuestInfo , NAS_QuestID , NAttValue( Frag^.NA , NAG_QuestInfo , NAS_QuestID ) );
				SetNAtt( E^.NA , NAG_QuestInfo , NAS_LayerID , NAttValue( Frag^.NA , NAG_QuestInfo , NAS_LayerID ) );

				{ If moving a character or mecha, better set its team. }
				if IsMasterGear( E ) then begin
					{ Note that a team may already be set. }
					if NAttValue( E^.NA , NAG_Location , NAS_Team ) = 0 then begin
						Team := SeekChildByName( SCENE , SAttValue( Frag^.SA , 'TEAM' + BStr( T ) ) );
						if Team <> Nil then begin
							SetNAtt( E^.NA , NAG_Location , NAS_Team , Team^.S );
						end else begin
							SetSAtt( E^.SA , 'TEAMDATA <' + SAttValue( Frag^.SA , 'TEAMDATA' + BStr( T ) ) + '>' );
							ChooseTeam( E , Scene );
						end;
					end;

					{ If this is a character with a mecha, set its renown and }
					{ skills based on the difficulcy level of the fragment. }
					if ( E^.G = GG_Character ) and IsACombatant( E ) and NotAnAnimal( E ) then begin
						SetSkillsAtLevel( E , NAttValue( Frag^.NA , NAG_QuestInfo , NAS_DifficulcyLevel ) );
						SetNAtt( E^.NA , NAG_CharDescription , NAS_Renowned , NAttValue( Frag^.NA , NAG_QuestInfo , NAS_DifficulcyLevel ) );
					end;
				end;

			end else begin
				DialogMsg( GearName( Frag ) + ': Scene not found for quest element ' + BStr( T ) + '.' );
				DisposeGear( E );
			end;
		end; { While Frag^.InvCom <> Nil... }

		{ Add the global scripts to the adventure itsel. }
		{ Use global scripts sparingly- I can see this becoming a major problem }
		{ if over-used. }
		BuildMegalist( Adv , Frag^.SA );
	end;

	Procedure PrepQuestDungeon( Frag: GearPtr );
		{ Prepare this dungeon, please. To do this we'll need to expand the dungeon }
		{ by several levels, assign unique IDs to all our new scenes, and connect }
		{ them all to each other. The SceneID of FRAG will be the first level of }
		{ the dungeon. The goal level's SceneID will be stored and all further content }
		{ sent to there. }
	var
		GoalLevel: GearPtr;
		Procedure AssignSceneIDs( SList: GearPtr );
			{ Assign unique IDs to all the scenes in this list and all of }
			{ their children scenes. Also do the connections, as long as we're here. }
		begin
			while SList <> Nil do begin
				if ( SList^.G = GG_Scene ) then begin
					SList^.S := NewSceneID();
					ConnectScene( SList );
				end;
				if SList <> GoalLevel then AssignSceneIDs( SList^.SubCom );
				SList := SList^.next;
			end;
		end;
		Procedure VerifySubScenes( SList: GearPtr );
			{ It's possible that some of the subscenes of the goal level }
			{ have exits pointing back to the L1 scene. If so, deal with that. }
			Procedure VerifyExits( MFList: GearPtr );
				{ Attempt to verify the exits throughout this list and }
				{ through the children of any map features. }
			begin
				while MFList <> Nil do begin
					if ( MFList^.G = GG_MetaTerrain ) and ( MFList^.Stat[ STAT_Destination ] = Frag^.S ) then begin
						{ Set its destination to the parent scene. }
						MFList^.Stat[ STAT_Destination ] := SList^.Parent^.S;
					end else if MFList^.G = GG_MapFeature then begin
						{ Check its children. }
						VerifyExits( MFList^.SubCom );
						VerifyExits( MFList^.InvCom );
					end;
					MFList := MFList^.Next;
				end;
			end;
		begin
			while SList <> Nil do begin
				if SList^.G = GG_Scene then begin
					{ This is a subscene. Deal with it. }
					VerifyExits( SList^.InvCom );
					VerifyExits( SList^.SubCom );
				end;

				SList := SList^.next;
			end;
		end;
		Procedure InitPrototype;
			{ The prototype must be initialized. }
			{ Things to do: }
			{ - Delete quest requests, to prevent double-dipping }
			{ - Set the L1 difficulcy rating }
		var
			Team: GearPtr;
		begin
			{ Assign the difficulcy number. }
			Team := Frag^.SubCom;
			while Team <> Nil do begin
				if ( Team^.G = GG_Team ) and ( Team^.Stat[ STAT_WanderMon ] > 0 ) then begin
					Team^.Stat[ STAT_WanderMon ] := NAttValue( Frag^.NA , NAG_QuestInfo , NAS_DifficulcyLevel ) - 12;
					if Team^.Stat[ STAT_WanderMon ] < 4 then Team^.Stat[ STAT_WanderMon ] := 2 + Random( 3 );
				end;
				Team := Team^.Next;
			end;
		end;
	begin
		{ Start by initializing the dungeon prototype. }
		InitPrototype;

		{ Next expand the dungeon. }
		GoalLevel := ExpandDungeon( Frag );

		{ Next, pass out the UniqueIDs. }
		AssignSceneIDs( Frag^.SubCom );

		{ Check the GoalLevel's subscenes for erroneous exits back to level one. }
		VerifySubScenes( GoalLevel^.InvCom );
		{ May 18 2007 - Originally only the InvComs were checked; now I'm checking the subcoms as well, }
		{ since that's where a lot of entrances are. If anything starts acting strange it's probably a }
		{ result of this. }
		VerifySubScenes( GoalLevel^.SubCom );

		{ Finally, save the ID of the goal level. }
		SetNAtt( Frag^.NA , NAG_QuestInfo , NAS_GoalLevel , GoalLevel^.S );
	end;

	Procedure InsertScene( LList,Frag: GearPtr );
		{ Insert the new scene FRAG into the adventure. }
		{ LList is a list of components; it should contain an entrance which will be }
		{ used to determine where to place FRAG. }
		Procedure InitExits( C: GearPtr; SID: Integer );
			{ Look for any metaterrain that has a DESTINATION stat of -1. }
			{ This must be a link back to the parent scene- initialize it with }
			{ the correct parent scene ID. }
		begin
			while C <> Nil do begin
				if ( C^.G = GG_MetaTerrain ) and ( C^.Stat[ STAT_Destination ] = -1 ) then begin
					C^.Stat[ STAT_Destination ] := SID;
				end;
				InitExits( C^.SubCom , SID );
				InitExits( C^.InvCom , SID );
				C := C^.Next;
			end;
		end;
		Function SeekUndeployedScene( SID: Integer; P: GearPtr ): GearPtr;
			{ Search the line of sibling components for a scene }
			{ which matches SID. Also check subs,invs. }
		var
			it: GearPtr;
		begin
			it := Nil;
			while P <> Nil do begin
				if ( P^.G = GG_Scene ) and ( P^.S = SID ) then begin
					it := P;
				end;
				if it = Nil then it := SeekUndeployedScene( SID , P^.InvCom );
				if it = Nil then it := SeekUndeployedScene( SID , P^.SubCom );
				P := P^.Next;
			end;
			SeekUndeployedScene := it;
		end;
		Procedure PrepWMonTeams( Scene: GearPtr );
			{ Check for monster teams. Set appropriate threat levels. }
		var
			Team: GearPtr;
		begin
			Team := Scene^.SubCom;
			while Team <> Nil do begin
				if ( Team^.G = GG_Team ) and ( Team^.Stat[ STAT_WanderMon ] > 0 ) then begin
					Team^.Stat[ STAT_WanderMon ] := NAttValue( Frag^.NA , NAG_QuestInfo , NAS_DifficulcyLevel );
					if Team^.Stat[ STAT_WanderMon ] < 3 then Team^.Stat[ STAT_WanderMon ] := 3;
				end;
				Team := Team^.Next;
			end;
		end;
	var
		Entrance,Element,Comp,PScene: GearPtr;
		EID,ParentSceneID: Integer;
		BaseName,UniqueName,msg: String;
		q1,q2: SAttPtr;
		Tries: Integer;
	begin
		if Full_RPGWorld_Info then DebugMessage( 'InsertScene: ' + GearName( Frag ) );

		DelinkGear( LList , Frag );

		{ Generate a unique name for this scene. }
		BaseName := SAttValue( Frag^.SA , 'NAME' );
		msg := SAttValue( Frag^.SA , 'NAME_1' );
		if msg <> '' then UniqueName := ReplaceHash( BaseName , msg )
		else UniqueName := ReplaceHash( BaseName , RandomName );
		Tries := 0;
		repeat
			PScene := SeekGearByName( Adv , UniqueName );
			if PScene <> Nil then UniqueName := ReplaceHash( BaseName , RandomName );
			Inc( Tries );
		until ( PScene = Nil ) or ( Tries > 500 );

		if Tries > 500 then begin
			{ We tried, and failed, to get a unique name. }
			UniqueName := 'Ique ' + BStr( Frag^.S );
			DialogMsg( 'ERROR: Scene ' + GearName( Frag ) + ' (' + BStr( Frag^.S ) + ') couldn''t generate unique name.' );
		end;

		SetSAtt( Frag^.SA , 'NAME <' + UniqueName + '>' );

		{ Dispose of any QUEST attributes it may have. }
		q1 := Frag^.SA;
		while q1 <> Nil do begin
			q2 := q1^.Next;
			if HeadMatchesString( 'QUEST' , q1^.info ) then RemoveSAtt( Frag^.SA , q1 );
			q1 := q2;
		end;

		{ Look for its entrance. This is gonna tell us where to place the scene }
		{ in the adventure. }
		ENtrance := SeekGearByDesig( LList , 'ENTRANCE ' + BStr( Frag^.S ) );
		if ENtrance = Nil then begin
			Entrance := SeekGearByDesig( Adv , 'ENTRANCE ' + BStr( Frag^.S ) );
			DialogMsg( 'Entrance for ' + GearName( Frag ) + ' found in adventure.' );
		end;
		if Entrance <> Nil then begin
			{ This entrance must itself have a scene where it's to be inserted. }
			{ Find that scene, then insert this scene in that one. }
			Entrance^.Stat[ STAT_Destination ] := Frag^.S;

			Comp := FindRoot( Entrance );
			{ If Comp is a scene, our job is easy: just insert FRAG as its subcom }
			{ and we're done. Otherwise, it must be a child of a component. }
			if Comp^.G = GG_Scene then begin
				InsertSubCom( Comp , Frag );
				ParentSceneID := Comp^.S;
			end else begin
				{ Drat. This means we actually have to do work. Find the parent of }
				{ the entrance that's a direct child of COMP. }
				Element := Entrance;
				while ( Element^.Parent <> Comp ) do Element := Element^.Parent;
				if Element^.G = GG_MetaScene then begin
					{ It's the metascene case. }
					ParentSceneID := NAttValue( Comp^.NA , NAG_QuestElemScene , Element^.S );
				end else begin
					{ I will assume that the element is not a character, since that }
					{ would make no sense at all. Therefore it must be an item. }
					EID := PlotElementID( Comp , 'I' , NAttValue( Element^.NA , NAG_Narrative , NAS_NID ) );
					ParentSceneID := NAttValue( Comp^.NA , NAG_QuestElemScene , EID );
				end;

				PScene := FindQuestScene( ParentSceneID );
				if PScene = Nil then PScene := SeekUndeployedScene( ParentSceneID , LList );

				if PScene <> Nil then begin
					{ As long as we've found our parent scene, insert the }
					{ fragment into it. }
					ParentSceneID := PScene^.S;
					InsertSubCom( PScene , Frag );
				end else begin
					{ No scene to be found. Bummer. }
					DialogMsg( 'ERROR- Parent scene not found for scene ' + BStr( Frag^.S ) );
					DisposeGear( Frag );
				end;
			end;

			{ If this scene is a dungeon, expand it and do all the wonderful stuff }
			{ that goes with that. We need to do this before initializing the exits }
			{ so any stairs up in the place will retain a destination of -1. }
			if ( Frag <> Nil ) and AStringHasBString( SAttValue( Frag^.SA , 'TYPE' ) , 'DUNGEON' ) then begin
				PrepQuestDungeon( Frag );
			end else begin
				{ This is not a dungeon, but may still have teams with }
				{ random monsters that need to be set. }
				PrepWMonTeams( Frag );
			end;

			{ Use the Parent Scene ID to initialize the reverse entrance. }
			if Frag <> Nil then begin
				InitExits( Frag^.SubCom , ParentSceneID );
				InitExits( Frag^.InvCom , ParentSceneID );
			end;
		end else begin
			DialogMsg( 'ERROR- Entrance not found for scene ' + BStr( Frag^.S ) );
			DisposeGear( Frag );
		end;
	end;

	Procedure AssembleQuest( LList: GearPtr );
		{ Assemble the list of quest fragments into a coherent adventure. }
		{ Place all elements, megalist all scripts, and generate all }
		{ new locations. }
	var
		Frag,F2: GearPtr;
	begin
		if Full_RPGWorld_Info then DebugMessage( 'Assembling ' + GearName( LList ) );

		{ Start by first installing the scenes. }
		Frag := LList;
		while Frag <> Nil do begin
			F2 := Frag^.Next;

			if Frag^.G = GG_Scene then begin
				InsertScene( LList , Frag );
			end;

			Frag := F2;
		end;

		{ Next, insert the quest components. }
		while LList <> Nil do begin
			Frag := LList;

			InsertComponent( Frag );
			RemoveGear( LList , Frag );
		end;

		{ Finally, clear any "in use" components that didn't actually }
		{ get used. }
		Frag := MasterList;
		while Frag <> Nil do begin
			SetNAtt( Frag^.NA , NAG_QuestInfo , NAS_QuestUsed , 0 );
			Frag := Frag^.Next;
		end;
	end;

	Function FindParentScene( Source: GearPtr ): GearPtr;
		{ If Source is a scene, return it. Otherwise return the first scene }
		{ found checking upwards through its parents. }
	begin
		while ( Source <> Nil ) and ( Source^.G <> GG_Scene ) do Source := Source^.Parent;
		FindParentScene := Source;
	end;

	Procedure AddQuest( Source: GearPtr; QuestType: String; QuestThreat: Integer );
		{ Attempt to add some new content to the adventure. }
		{ Source is the gear requesting the quest- it may be either a scene }
		{ or a character. }
	var
		KeyScene,RootScene,KeyGear: GearPtr;
		LList: GearPtr;
		QuestComplexity: Integer;
	begin
		{ Initialize the layer IDs. }
		MaxLID := 1;

		{ Determine the key scene (i.e. the scene containing SOURCE). }
		KeyScene := FindParentScene( Source );
		RootScene := FindRootScene( Nil , KeyScene );

		QuestComplexity := 10;

		{ Determine the key gear, if one exists. }
		if Source^.G <> GG_Scene then begin
			if NAttValue( Source^.NA , NAG_Personal , NAS_CID ) = 0 then SetNAtt( Source^.NA , NAG_Narrative , NAS_NID , NewNID( Nil , Adv ) );
			KeyGear := Source;
		end else KeyGear := Nil;

		{ First, generate the list of components. }
		LList := AddQuestComponent( RootScene , Nil , QuestType , QuestThreat , QuestComplexity , KeyScene , KeyGear );

		{ Next, assemble these components into actual adventure content. }
		if LList <> Nil then begin
			AssembleQuest( LList );
		end else begin
			if XXRan_Debug then DialogMsg( 'ERROR: AddQuest failed for ' + GearName( Source ) + '/' + QuestType);
		end;
	end;

	Function InitialThreat( Part: GearPtr ): Integer;
		{ Return a good default threat rating for a quest based off of PART. }
	var
		Scene: GearPtr;
		T,Threat: Integer;
	begin
		Scene := FindParentScene( Part );
		T := FindWorld( Nil , Scene )^.S;
		if Scene^.S = HomeTownID then begin
			{ This is the PC's home town. All quests are easy. }
			Threat := 5 + Random( 11 );
		end else if ( T = WorldID ) and ( NAttValue( Scene^.NA , NAG_Personal , NAS_FactionID ) = HTFacID ) then begin
			{ This is nearly the PC's home... slightly harder. }
			Threat := 10 + Random( 31 );
		end else if T = WorldID then begin
			{ This is the same world as the PC started on. A bit harder still. }
			Threat := 20 + Random( 41 );
		end else begin
			{ This is a different planet. Quests get hard here. }
			Threat := 30 + Random( 61 );
		end;
		InitialThreat := Threat;
	end;

	Procedure CheckAlongPath( LList: GearPtr );
		{ Check along this list of scenes for content requests, }
		{ also checking the sub- and inv-coms. }
		Procedure AddQuestHere( Part: GearPtr; ConReq: String );
			{ Do the grunge work of adding the quest, based on the request we've been given. }
		var
			QuestType: String;
			QuestThreat: Integer;
		begin
			QuestType := ExtractWord( ConReq );
			QuestThreat := ExtractValue( ConReq );
			if QuestThreat = 0 then QuestThreat := InitialThreat( Part );
			AddQuest( LList , QuestType , QuestThreat );
		end;
	var
		ConReq: String;
		SA: SAttPtr;
		ID: LongInt;
	begin
		while LList <> Nil do begin
			if LList^.G = GG_Scene then begin
				{ A scene can have multiple quests defined. }
				SA := LList^.SA;
				while SA <> Nil do begin
					if HeadMatchesString( 'QUEST' , SA^.Info ) then begin
						ConReq := RetrieveAString( SA^.Info );
						AddQuestHere( LList , ConReq );
					end;
					SA := SA^.Next;
				end;
			end else begin
				{ A non-scene can have only one quest defined. }
				ConReq := SAttValue( LList^.SA , 'QUEST' );
				if ConReq <> '' then begin
					if LList^.G <> GG_Character then begin
						{ Assign a narrative ID to anything that isn't }
						{ a character, but has a quest. }
						ID := NewNID( Nil , Adv );
						SetNAtt( LList^.NA , NAG_Narrative , NAS_NID , ID );
					end;
					AddQuestHere( LList , ConReq );
				end;
			end;
			CheckAlongPath( LList^.SubCom );
			CheckAlongPath( LList^.InvCom );
			LList := LList^.Next;
		end;
	end;
	Procedure CheckPersonas( LList: GearPtr );
		{ Search through LList and all its SubComs recursively searching for }
		{ quest-associated personas. When one is found, put it through the }
		{ pfrag insertor. }
	var
		NPC: GearPtr;
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_Persona ) and ( NAttValue( LList^.NA , NAG_QuestInfo , NAS_QuestID ) <> 0 ) then begin
				NPC := SeekGearByCID( Adv , LList^.S );
				if NPC <> Nil then InsertPFrags( Nil , LList , PersonalContext( Adv , NPC ) , MaxMaxLID + 1 );
			end;
			CheckPersonas( LList^.SubCom );
			LList := LList^.Next;
		end;
	end;
	Procedure AssignMasterListIDNumbers;
		{ Each fragment in the master list needs a unique ID number, stored }
		{ in its "S" descriptor. }
	var
		M: GearPtr;
		ID: Integer;
	begin
		ID := 0;
		M := MasterList;
		while M <> Nil do begin
			M^.S := ID;
			Inc( ID );
			M := M^.Next;
		end;
	end;
begin
	{ Load the component library. }
	MasterList := AggregatePattern( 'QUEST_*.txt' , Series_Directory );
	AssignMasterListIDNumbers;

	ScenePrototypeList := AggregatePattern( 'QSCENE_*.txt' , Series_Directory );

	MaxQID := 1;
	MaxMaxLID := 2;

	{ Determine the HomeTownID, HTFacID, and WorldID. }
	HomeTownID := HomeTown^.S;
	HTFacID := NAttValue( HomeTown^.NA , NAG_Personal , NAS_FactionID );
	WorldID := FindWorld( Nil , HomeTown )^.S;

	{ Start checing the adventure scenes for content requests. }
	CheckAlongPath( Adv^.SubCom );

	{ Finally finalize the personas. }
	CheckPersonas( Adv^.SubCom );

	{ Get rid of the master list. }
	DisposeGear( MasterList );
	DisposeGear( ScenePrototypeList );
end;

Procedure StartCampaign( PC: GearPtr );
	{ Start a new RPG campaign. }
	{ - Load the atlas files, then assemble them into an adventure. }
	{ - Initialize all the cities. }
	{ - Insert the PC's central story. }
var
	Camp: CampaignPtr;
	Atlas,S,S2,W,Story,Club: GearPtr;
	Factions,Artifacts: GearPtr;
	HighWorldID: Integer;
	Base,Changes: String;	{ Context Strings. }
begin
{$IFNDEF ASCII}
	Idle_Display;
{$ENDIF}

	Camp := NewCampaign;
	Camp^.Source := LoadFile( 'adventurestub.txt' , Series_Directory );
	Atlas := AggregatePattern( 'ATLAS_*.txt' , Series_Directory );

	{ Insert the factions into the adventure. }
	Factions := AggregatePattern( 'FACTIONS_*.txt' , Series_Directory );
	InsertInvCom( Camp^.Source , Factions );

	{ Insert the artifacts into the adventure. }
	Artifacts := AggregatePattern( 'ARTIFACT_*.txt' , Series_Directory );
	S := AddGear( Camp^.Source^.InvCom , Camp^.Source );
	SetSAtt( S^.SA , 'name <Artifact Collection>' );
	S^.G := GG_ArtifactSet;
	InsertInvCom( S , Artifacts );

	{ Insert the unique scene content into the adventure. }
	Artifacts := AggregatePattern( 'UNICON_*.txt' , Series_Directory );
	S := AddGear( Camp^.Source^.InvCom , Camp^.Source );
	SetSAtt( S^.SA , 'name <Unique Scene Content>' );
	S^.G := GG_ContentSet;
	InsertInvCom( S , Artifacts );
	{ Assign unique IDs to all the content bits. }
	HighWorldID := 1;
	S := Artifacts;
	while S <> Nil do begin
		SetNAtt( S^.NA , NAG_Narrative , NAS_ContentID , HighWorldID );
		S := S^.Next;
		Inc( HighWorldID );
	end;


	{ Assemble the subcoms of the adventure. }
	{ First, move over all the WORLDs. Then, move over all the SCENEs. }
	{ Assign unique IDs for everything. }
	S := Atlas;
	HighWorldID := 1;
	while S <> Nil do begin
		S2 := S^.Next;

		if S^.G = GG_World then begin
			DelinkGear( Atlas , S );
			InsertSubCom( Camp^.Source , S );
			S^.S := HighWorldID;
			Inc( HighWorldID );
		end;
		S := S2;
	end;

	{ Proceed with the scenes. }
	S := Atlas;
	while S <> Nil do begin
		S2 := S^.Next;

		if S^.G = GG_Scene then begin
			DelinkGear( Atlas , S );
			W := SeekGearByName( Camp^.Source , SAttValue( S^.SA , 'WORLD' ) );
			if ( W <> Nil ) and ( ( W^.G = GG_Scene ) or ( W^.G = GG_World ) ) then begin
				InsertSubCom( W , S );
			end else begin
				InsertSubCom( Camp^.Source , S );
			end;
		end;

		S := S2;
	end;

	{ We are now finished with the atlas. Dispose of it. }
	DisposeGear( Atlas );

	{ Locate the PC's home town. Insert a "Cavalier Club" as the starting location. }
	S := SeekGearByName( Camp^.Source , SAttValue( PC^.SA , 'HOMETOWN' ) );
	if S <> Nil then S := SeekUrbanArea( S );
	if S <> Nil then begin
		Club := LoadSingleMecha( 'stub_cavalierclub.txt' , Series_Directory );
		InsertSubCom( S , Club );
	end;

	{ Once everything is sorted where it's supposed to go, initialize the scenes. }
	{ They all need unique ID numbers, the dungeons need expansion and the cities }
	{ need random content. }
	InitializeCampaignScenes( Camp^.Source , HighWorldID );

	{ Next initialize the NPCs. }
	InitializeCampaignNPCs( Camp^.Source );

	{ Locate the PC's home town again, this time to record the scene ID. }
	{ We're also going to need this scene ID for the central story below. }
	S := SeekGearByName( Camp^.Source , SAttValue( PC^.SA , 'HOMETOWN' ) );
	if S <> Nil then begin
		SetNAtt( PC^.NA , NAG_Narrative , NAS_HomeTownID , S^.S );
	end;

	{ Insert the central story. }
	Story := LoadFile( 'corestorystub.txt' , Series_Directory );
	SetNAtt( Story^.NA , NAG_ElementID , XRP_EpisodeScene , S^.S );
	SetNAtt( Story^.NA , NAG_ElementID , XRP_TargetFac , NAttValue( PC^.NA , NAG_Personal , NAS_FactionID ) );
	SetNAtt( Camp^.Source^.NA , NAG_Personal , NAS_FactionID , NAttValue( PC^.NA , NAG_Personal , NAS_FactionID ) );

	{ Copy the PC's personal context to the story. }
	Base := SAttValue( Story^.SA , 'CONTEXT' );
	Changes := SAttValue( PC^.SA , 'CONTEXT' );
	AlterDescriptors( Base , Changes );
	SetSAtt( Story^.SA , 'CONTEXT <' + Base + '>' );

	InsertInvCom( Camp^.Source , Story );

	{ Insert the static adventure quests. }
	InitializeAdventureContent( Camp^.Source , S );

	{ Locate the Cavalier Club. This is to be the starting location. }
	{ Being the first location entered by the PC, the Cavalier Club has }
	{ the imaginative designation of "00000". }
	S := SeekGearByDesig( Camp^.Source , '00000' );
	if S <> Nil then begin
		Navigator ( Camp , S , PC );
	end;

	DisposeCampaign( Camp );
	DisposeGear( PC );
end;

Procedure RestoreCampaign( RDP: RedrawProcedureType );
	{ Select a previously saved unit from the menu. If no unit is }
	{ found, jump to the CreateNewUnit procedure above. }
var
	RPM: RPGMenuPtr;
	rpgname: String;	{ Campaign Name }
	Camp: CampaignPtr;
	F: Text;		{ A File }
	PC,Part,P2: GearPtr;
	DoSave: Boolean;
begin
	{ Create a menu listing all the units in the SaveGame directory. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( RPM , Save_Campaign_Base + Default_Search_Pattern );

	PC := Nil;

	{ If any units are found, allow the player to load one. }
	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		DialogMSG('Select campaign file to load.');

		rpgname := SelectFile( RPM , RDP );

		if rpgname <> '' then begin
			Assign(F, Save_Game_Directory + rpgname );
			reset(F);
			Camp := ReadCampaign(F);
			Close(F);

			Navigator( Camp , Camp^.GB^.Scene , PC );
			DoSave := Camp^.Source^.V <> 0;
			DisposeCampaign( Camp );
		end else begin
			DoSave := False;
		end;

	end else begin
		{ The menu was empty... print the info message. }
		DialogMsg( MsgString( 'NEWRPGCAMP_NoCamps' ) );
		DoSave := False;
	end;

	if ( PC <> Nil ) and ( DoSave or Always_Save_Character ) then begin
		if not NoLivingPlayers( PC ) then begin
			Part := PC;
			while Part <> Nil do begin
				P2 := Part^.Next;
				{ Lancemates don't get saved to the character file. }
				if ( Part^.G = GG_Character ) and ( NAttValue( Part^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_CTPrimary ) then begin
					RemoveGear( PC , Part );
				end else begin
					{ Everything else does get saved. }
					StripNAtt( Part , NAG_Visibility );
					StripNAtt( Part , NAG_EpisodeData );
					StripNAtt( Part , NAG_WeaponModifier );
					StripNAtt( Part , NAG_Action );
					StripNAtt( Part , NAG_Location );
					StripNAtt( Part , NAG_Damage );
					StripNAtt( Part , NAG_ReactionScore );
					StripNAtt( Part , NAG_FactionScore );
					StripNAtt( Part , NAG_Condition );
					StripNAtt( Part , NAG_StatusEffect );
					StripNAtt( Part , NAG_Narrative );
					SetNAtt( Part^.NA , NAG_Personal , NAS_FactionID , 0 );
				end;
				Part := P2;
			end;
			SaveChar( PC );
		end;
	end;
	if PC <> Nil then DisposeGear( PC );

	DisposeRPGMenu( RPM );
end;

initialization
	MasterEntranceList := AggregatePattern( 'ENTRANCE_*.txt' , Series_Directory );

finalization
	DisposeGear( MasterEntranceList );

end.
