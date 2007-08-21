unit WMonster;
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

const
	{ This is the minimum point value for meks when calling the STOCKSCENE }
	{ procedure. }
	MinPointValue = 65000;


Procedure RestockRandomMonsters( GB: GameBoardPtr );
Function GenerateMechaList( MPV: LongInt; Factions,Desc: String ): SAttPtr;
Function PurchaseForces( ShoppingList: SAttPtr; UPV: LongInt ): GearPtr;
Procedure StockSceneWithEnemies( Scene: GearPtr; UPV: longInt; TeamID: Integer );
Procedure StockSceneWithMonsters( Scene: GearPtr; MPV,TeamID: Integer; MDesc: String );

Procedure AddTeamForces( GB: GameBoardPtr; TeamID: Integer; UPV: LongInt );
Procedure StockBoardWithMonsters( GB: GameBoardPtr; MPV,TeamID: Integer; MDesc: String );

Function SelectNPCMecha( Scene,NPC: GearPtr ): GearPtr;

implementation

{$IFDEF ASCII}
uses dos,ability,action,gearutil,ghchars,gearparser,texutil,vidmap,narration,vidgfx,movement;
{$ELSE}
uses dos,ability,action,gearutil,ghchars,gearparser,texutil,glmap,narration,glgfx,movement;
{$ENDIF}

Function MatchWeight( S, M: String ): Integer;
	{ Return a value showing how well the monster M matches the }
	{ quoted source S. }
var
	Trait: String;
	it: Integer;
begin
	it := 0;

	while M <> '' do begin
		Trait := ExtractWord( M );

		if AStringHasBString( S , Trait ) then begin
			if it = 0 then it := 1
			else it := it * 2;
		end;
	end;

	MatchWeight := it;
end;

Function GenerateMonster( MaxTV,Scale: Integer; const MType,Habitat: String; Scene: GearPtr ): GearPtr;
	{ Generate a monster with no greater than MaxTV threat value, }
	{ which corresponds to MDesc. Its type must match MType and its habitat must be compatable with Habitat. }
	{ Finally, the monsters's characteristics must be appropriate for the scene it will be placed in: }
	{ really, the big thing to check is that the generated monster will be able to breathe in this scene. }
	Function HabitatMatch( M: GearPtr ): Boolean;
		{ Return TRUE if M can appear in this habitat, or FALSE otherwise. }
	var
		MHabitat: String;
	begin
		if Habitat = '' then Exit( True );
		MHabitat := SAttValue( M^.SA , 'HABITAT' );
		HabitatMatch := ( MHabitat = '' ) or PartAtLeastOneMatch( Habitat , MHabitat );
	end;
	Function EnvironmentMatch( M: GearPtr ): Boolean;
		{ Return TRUE if this monster can survive in SCENE, or FALSE otherwise. }
	begin
		if Scene = Nil then begin
			EnvironmentMatch := True;
		end else if NAttValue( Scene^.NA , NAG_EnvironmentData , NAS_Atmosphere ) = NAV_Vacuum then begin
			EnvironmentMatch := IsEnviroSealed( M ) or ( NAttValue( M^.NA , NAG_GearOps , NAS_Material ) = NAV_Metal );
		end else begin
			EnvironmentMatch := True;
		end;
	end;
var
	ShoppingList,ShoppingItem: NAttPtr;
	Total,Smallest,SmallTV: LongInt;
	WM: GearPtr;
	N,Match: Integer;
begin
	ShoppingList := Nil;
	WM := WMonList;
	N := 1;
	Total := 0;
	Smallest := 0;
	SmallTV := 100000;
	while WM <> Nil do begin
		{ If this monster matches our criteria, maybe add its number to the list. }
		if ( WM^.Scale <= Scale ) and HabitatMatch( WM ) and EnvironmentMatch( WM ) then begin
			Match := MatchWeight( MType , SAttValue( WM^.SA , 'TYPE' ) );

			{ If this monster's threat value is within the acceptable range, add it to the list. }
			{ Otherwise see if it's the smallest TV found so far, in which case store its identity }
			{ just in case no monsters with acceptable TV are found. }
			if MonsterThreatLevel( WM ) <= MaxTV then begin
				SetNAtt( ShoppingList , 0 , N , Match );
				Total := Total + Match;
			end else if MonsterThreatLevel( WM ) < SmallTV then begin
				Smallest := N;
				SmallTV := MonsterThreatLevel( WM );
			end;
		end;

		{ Move to the next monster, and increase the monster index. }
		WM := WM^.Next;
		Inc( N );
	end;


	if Total > 0 then begin
		Match := Random( Total );
		ShoppingItem := ShoppingList;
		while Match > ShoppingItem^.V do begin
			Match := Match - ShoppingItem^.V;
			ShoppingItem := ShoppingItem^.Next;
		end;
		N := ShoppingItem^.S;

		{ Return the selected monster. }
		WM := CloneGear( RetrieveGearSib( WMonList , N ) );
	end else if Smallest > 0 then begin
		WM := CloneGear( RetrieveGearSib( WMonList , Smallest ) );
	end else begin
		{ Return a random monster. }
		WM := CloneGear( SelectRandomGear( WMonList ) );
	end;
	SetSATt( WM^.SA , 'JOB <ANIMAL>' );
	GenerateMonster := WM;
end;

Procedure AddRandomMonsters( GB: GameBoardPtr; Team: GearPtr; Threat: Integer );
	{ Place some wandering monsters on the map. }
var
	WM: GearPtr;
	WMonType,Habitat: String;
	Gen,MaxTV: LongInt;	{ Maximum Threat Value }
begin
	{ Find the WMonType and the Habitat. }
	WMonType := SAttValue( Team^.SA , 'TYPE' );
	if GB^.Scene <> Nil then begin
		Habitat := SAttValue( GB^.Scene^.SA , 'HABITAT' );
	end else Habitat := '';

	{ Determine the maximum threat value. }
	MaxTV := Team^.Stat[ STAT_WanderMon ] div 2;
	if MaxTV < 1 then MaxTV := 1;

	{ Decide upon how many monsters to add. }
	Gen := Random( 5 );

	while ( Gen > 0 ) and ( Threat > 0 ) do begin
		WM := GenerateMonster( MaxTV , GB^.Scale , WMonType , Habitat , GB^.Scene );
		SetNAtt( WM^.NA , NAG_Location , NAS_Team , Team^.S );
		DeployMek( GB , WM , True );

		{ Reduce the generation counter and the threat points. }
		Threat := Threat - MonsterThreatLevel( WM );
		Dec( Gen );
	end;
end;

Procedure RestockRandomMonsters( GB: GameBoardPtr );
	{ Replenish this level's supply of random monsters. }
var
	Team: GearPtr;
	TPV: LongInt;
begin
	{ Error check - make sure the scene is defined. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;

	{ Search through the scene gear for teams which need random }
	{ monsters. If they don't have enough PV, add some monsters. }
	Team := GB^.Scene^.SubCom;
 	while Team <> Nil do begin
		{ if this gear is a team, and it has a wandering monster }
		{ allocation set, add some monsters. }
		if ( Team^.G = GG_Team ) and ( Team^.STat[ STAT_WanderMon ] > 0 ) then begin
			{ Calculate total point value of this team's units. }
			TPV := TeamTV( GB^.Meks , Team^.S );

			if TPV < Team^.Stat[ STAT_WanderMon ] then begin
				AddRandomMonsters( GB , Team , Team^.Stat[ STAT_WanderMon ] - TPV );
			end;
		end;

		{ Move to the next gear. }
		Team := Team^.Next;
	end;

end;

Function MechaMatchesFactionAndTerrain( Mek: GearPtr; const Factions,Terrain_Type: String ): Boolean;
	{ Return TRUE if MEK is a legal design for the faction and map, }
	{ or FALSE otherwise. }
begin
	MechaMatchesFactionAndTerrain := ( Mek^.G = GG_Mecha ) and PartAtLeastOneMatch( SAttValue( Mek^.SA , 'FACTIONS' ) , Factions ) and PartMatchesCriteria( SAttValue( Mek^.SA , 'TYPE' ) , Terrain_Type );
end;


Function GenerateMechaList( MPV: LongInt; Factions,Desc: String ): SAttPtr;
	{ Build a list of mechas from the DESIGN diectory which have }
	{ a maximum point value of MPV or less. }
	{ Format for the description string is: pv index <filename> }
	{ where PV = Point Value, Index = Root Gear Number (since a }
	{ design file may contain more than one mecha), and filename }
	{ is the filename stored as an alligator string. }
	{ DESC is the terrain description taken from the scene. }
var
	SRec: SearchRec;
	it,current: SAttPtr;
	DList,Mek: GearPtr;
	F: Text;
	N,MinValFound: LongInt;	{ The lowest value found so far. }
	MVInfo: String;		{ Info on the mek with the lowest value. }
begin
	it := Nil;
	MinValFound := 0;
	MVInfo := '';

	{ Start the search process going... }
	FindFirst( Design_Directory + Default_Search_Pattern , AnyFile , SRec );

	{ As long as there are files which match our description, }
	{ process them. }
	While DosError = 0 do begin
		{ Load this mecha design file from disk. }
		DList := LoadFile( SRec.Name , Design_Directory );

		{ Search through it for mecha. }
		Mek := DList;
		N := 1;
		while Mek <> Nil do begin
			if ( Mek^.G = GG_Mecha ) then begin
				if ( GearValue( Mek ) <= MPV ) and MechaMatchesFactionAndTerrain( Mek , Factions , DESC ) then begin
					Current := CreateSAtt( it );
					Current^.Info := BStr( GearValue( Mek ) ) + ' ' + BStr( N ) + ' <' + SRec.Name + '>';
				end;
				if ( ( GearValue( Mek ) < MinValFound ) or ( MinValFound = 0 ) ) and MechaMatchesFactionAndTerrain( Mek , Factions , DESC ) then begin
					MVInfo := BStr( GearValue( Mek ) ) + ' ' + BStr( N ) + ' <' + SRec.Name + '>';
					MinValFound := GearValue( Mek );
				end;
			end;
			Mek := Mek^.Next;
			Inc( N );
		end;

		{ Dispose of the list. }
		DisposeGear( DList );

		{ Look for the next file in the directory. }
		FindNext( SRec );
	end;

	{ Error check- we don't want to return an empty list, }
	{ but we will if we have to. }
	if ( it = Nil ) and ( MVInfo <> '' ) then begin
		Current := CreateSAtt( it );
		Current^.Info := MVInfo;
	end;

	GenerateMechaList := it;
end;

Function PurchaseForces( ShoppingList: SAttPtr; UPV: LongInt ): GearPtr;
	{ Pick a number of random meks with point value at least }
	{ equal to UPV. Add pilots to these meks. }

	Function ObtainMekFromFile( S: String ): GearPtr;
		{ Using the description string S, locate and load }
		{ a mek from disk. }
	var
		N: LongInt;
		F: Text;
		FList,Mek: GearPtr;
	begin
		{ Load the design file. }
		FList := LoadFile( RetrieveAString( S ) , Design_Directory );

		{ Get the number of the mek we want. }
		N := ExtractValue( S );

		{ Clone the mecha we want. }
		Mek := CloneGear( RetrieveGearSib( FList , N ) );

		{ Get rid of the design record. }
		DisposeGear( FList );

		{ Return the mek obtained. }
		ObtainMekFromFile := Mek;
	end;

	Function SelectNextMecha: String;
		{ Select a mecha file to load. Try to make it appropriate }
		{ to the point value of the encounter. }
	var
		M1,M2: STring;
		T: Integer;
		V,V2: LongInt;
	begin
		{ Select a mecha at random, and find out its point value. }
		M1 := SelectRandomSAtt( ShoppingList )^.Info;
		V := ExtractValue( M1 );

		{ If the PV of this mecha seems a bit low, }
		{ look for a more expensive model and maybe pick that }
		{ one instead. }
		t := 3;
		while ( t > 0 ) and ( V < ( UPV div 5 ) ) do begin
			M2 := SelectRandomSAtt( ShoppingList )^.Info;
			V2 := ExtractValue( M2 );
			if V2 > V then begin
				M1 := M2;
				V := V2;
			end;

			Dec( T );
		end;

		{ Return the info string selected. }
		SelectNextMecha := M1;
	end;
var
	MPV: LongInt;
	Lvl: LongInt;		{ Pilot level. }
	StPt,SkPt: LongInt;	{ Stat points and skill points of the pilot. }
	Mek,MList,CP: GearPtr;
begin
	{ Initialize our list to Nil. }
	MList := Nil;

	{ Keep processing until we run out of points. }
	while ( UPV > 0 ) and ( ShoppingList <> Nil ) do begin
		{ Select a mek at random. }
		{ Load & Clone the mek. }
		Mek := ObtainMekFromFile( SelectNextMecha );
		MPV := GearValue( Mek );

		{ Select a pilot skill level. }
		{ Set default values. }
		StPt := 90;
		SkPt := 3;

		if ( MPV > UPV ) or ( Random(10) = 1 ) then begin
			{ Level will be between 0 and -5 }
			Lvl := Random( 6 );
			StPt := StPt - ( Lvl * 3 );
			SkPt := SkPt - ( Lvl div 2 );
			MPV := ( MPV * ( 10 - Lvl ) ) div 10;

		end else if Random( MPV ) < Random( UPV ) then begin
			{ Level will be between 0 and 20 }
			Lvl := Random( 21 );

			{ Make sure we don't go overboard. }
			while ( ( ( MPV * ( 5 + Lvl ) ) div 5 ) > UPV ) and ( Lvl > 0 ) do begin
				Dec( Lvl );
			end;

			StPt := StPt + Lvl;
			SkPt := SkPt + ( Lvl div 2 );
			MPV := ( MPV * ( 5 + Lvl ) ) div 5;
		end;

		{ Add this mecha to our list. }
		Mek^.Next := MList;
		MList := Mek;

		{ Insert pilot in this mecha. }
		CP := SeekGear( Mek , GG_CockPit , 0 );
		if CP <> Nil then begin
			InsertSubCom( CP , RandomPilot( StPt , SkPt ) );
		end;

		{ Reduce UPV by an appropriate amount. }
		UPV := UPV - MPV;
	end;

	PurchaseForces := MList;
end;

Procedure StockSceneWithSoldiers( Scene: GearPtr; UPV: LongInt; TeamID: Integer );
	{ Fill this team with people, but instead of mechas just give }
	{ them some random equipment. }
var
	EquipList,NPC: GearPtr;
	EPV,AvgPointValue: LongInt;
	StPt,SkPt,Lvl: Integer;
begin
	EquipList := AggregatePattern( PC_Equipment_Pattern , Design_Directory );

	AvgPointValue := 800;
	{ Use Lvl temporarily to store the maximum number of combatants we want. }
	lvl := 10 + Random( 20 );
	if ( UPV div AvgPointValue ) > lvl then AvgPointValue := UPV div lvl;

	While UPV > 0 do begin
		StPt := 90;
		SkPt := 5;
		EPV := AvgPointValue + Random( 500 ) - Random( 500 );
		if EPV > UPV then EPV := UPV
		else if EPV < 500 then EPV := 500;

		if ( EPV < 1000 ) or ( Random( 5 ) = 1 ) then begin
			Lvl := -Random( 5 );
			StPt := StPt + 2*Lvl;
			SkPt := SkPt + Lvl;
			EPV := EPV - ( 500 - lvl * lvl * 20 );
			UPV := UPV - ( 500 - lvl * lvl * 20 );
		end else if ( EPV > 1500 ) and ( Random( 5 ) <> 1 ) then begin
			repeat
				Lvl := Random( 10 );
			until ( 500 + lvl * lvl * 150 ) < ( EPV div 2 );
			StPt := StPt + Lvl;
			SkPt := SkPt + Lvl;
			EPV := EPV - ( 500 + lvl * lvl * 150 );
			UPV := UPV - ( 500 + lvl * lvl * 150 );
		end else begin
			EPV := EPV - 500;
			UPV := UPV - 500;
		end;

		NPC := RandomSoldier( StPt , SkPt );
		ExpandCharacter( NPC );

		SelectCombatEquipment( NPC , EquipList , EPV );
		UPV := UPV - EPV;

		{ Set its team to the ID provided. }
		SetNAtt( NPC^.NA , NAG_Location , NAS_Team , TeamID );

		{ Place it in the scene. }
		InsertInvCom( Scene , NPC );
	end;

	DisposeGear( EquipList );
end;

Procedure StockSceneWithMeks( Scene: GearPtr; UPV: longInt; TeamID: Integer );
	{ This scene requires a number of mecha to be added. Purchase an }
	{ appropriate value of mecha, then stick them in the scene. }
var
	ShoppingList: SAttPtr;
	MaxPointValue: LongInt;
	MList,Mek: GearPtr;
begin
	{ Generate the shopping list, then purchase mecha. }
	MaxPointValue := UPV div 2;
	if MaxPointValue < MinPointValue then MaxPointValue := MinPointValue;
	ShoppingList := GenerateMechaList( UPV , 'GENERAL' , '' );
	MList := PurchaseForces( ShoppingList , UPV );
	DisposeSAtt( ShoppingList );

	{ Stick the mecha in the scene. }
	while MList <> Nil do begin
		{ Delink the first mecha from the list. }
		Mek := MList;
		DelinkGear( MList , Mek );

		{ Set its team to the ID provided. }
		SetNAtt( Mek^.NA , NAG_Location , NAS_Team , TeamID );

		{ Place it in the scene. }
		InsertInvCom( Scene , Mek );
	end;

end;

Procedure StockSceneWithEnemies( Scene: GearPtr; UPV: longInt; TeamID: Integer );
	{ Put some enemies in the scene. }
begin
	if Scene^.V = 0 then begin
		StockSceneWithSoldiers( Scene , UPV , TeamID );
	end else begin
		StockSceneWithMeks( Scene , UPV , TeamID );
	end;
end;

Procedure StockSceneWithMonsters( Scene: GearPtr; MPV,TeamID: Integer; MDesc: String );
	{ Place some monsters in this scene. }
var
	M: GearPtr;
begin
	while MPV > 0 do begin
		{ Grab a monster. }
		M := GenerateMonster( MPV , Scene^.V , MDesc, SAttValue( Scene^.SA , 'HABITAT' ) , Scene );

		{ Reduce the PV by the monster's threat value. }
		MPV := MPV - MonsterThreatLevel( M );

		{ Set the team to the correct value. }
		{ Set its team to the ID provided. }
		SetNAtt( M^.NA , NAG_Location , NAS_Team , TeamID );

		{ Stick the monster in the scene. }
		InsertInvCom( Scene , M );
	end;

end;

Procedure AddTeamForces( GB: GameBoardPtr; TeamID: Integer; UPV: LongInt );
	{ Add forces to the gameboard. }
var
	SList: SAttPtr;
	MList,Mek,Pilot: GearPtr;
	desc,fdesc: String;
	team,fac,rscene: GearPtr;
	MPV: LongInt;
begin
	{ First, generate the mecha description. }
	{ GENERAL mecha are always welcome. }
	fdesc := 'GENERAL';
	team := LocateTeam( GB , TeamID );
	if team <> Nil then begin
		Fac := SeekFaction( GB^.Scene , NAttValue( Team^.NA , NAG_Personal , NAS_FactionID ) );
		if Fac <> Nil then fdesc := fdesc + ' ' + SAttValue( Fac^.SA , 'DESIG' );
	end;
	{ Also add the terrain description from the scene. }
	desc := '';
	if GB^.Scene <> Nil then begin
		desc := desc + ' ' + SAttValue( GB^.Scene^.SA , 'TERRAIN' );

		{ Also locate the faction of the root scene; this will give the "generic" }
		{ mecha for this particular region. }
		if Fac = Nil then begin
			rscene := FindRootScene( GB , GB^.Scene );
			if rscene <> Nil then begin
				Fac := SeekFaction( GB^.Scene , NAttValue( RScene^.NA , NAG_Personal , NAS_FactionID ) );
				if Fac <> Nil then fdesc := fdesc + ' ' + SAttValue( Fac^.SA , 'DESIG' );
			end;
		end;
	end;

	{ Generate the list of mecha. }
	MPV := UPV div 2;
	if MPV < 300000 then MPV := 300000;
	SList := GenerateMechaList( MPV , fdesc , desc );

	{ Generate the mecha list. }
	MList := PurchaseForces( SList , UPV );

	{ Get rid of the shopping list. }
	DisposeSAtt( SList );

	{ Deploy the mecha on the map. }
	while MList <> Nil do begin
		{ Delink the first gear from the list. }
		Mek := MList;
		Pilot := LocatePilot( Mek );
		DelinkGear( MList , Mek );

		{ Set its team to the requested value. }
		SetNAtt( Mek^.NA , NAG_Location , NAS_Team , TeamID );
		if Pilot <> Nil then SetNAtt( Pilot^.NA , NAG_Location , NAS_Team , TeamID );

		{ Designate both mecha and pilot as temporary. }
		SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Temporary , 1 );
		if Pilot <> Nil then SetNAtt( Pilot^.NA , NAG_EpisodeData , NAS_Temporary , 1 );

		{ Place it on the map. }
		DeployMek( GB , Mek , True );
	end;
end;

Procedure StockBoardWithMonsters( GB: GameBoardPtr; MPV,TeamID: Integer; MDesc: String );
	{ Place some monsters in this scene. }
var
	M: GearPtr;
begin
	while MPV > 0 do begin
		{ Grab a monster. }
		M := GenerateMonster( MPV , GB^.Scale , MDesc , SAttValue( GB^.Scene^.SA , 'HABITAT' ) , GB^.Scene );

		{ Reduce the PV by the monster's threat value. }
		MPV := MPV - MonsterThreatLevel( M );

		{ Set the team to the correct value. }
		{ Set its team to the ID provided. }
		SetNAtt( M^.NA , NAG_Location , NAS_Team , TeamID );

		{ Stick the monster in the scene. }
		DeployMek( GB , M , True );
	end;

end;


Function SelectNPCMecha( Scene,NPC: GearPtr ): GearPtr;
	{ Select a mecha for the provided NPC. }
	{ This mecha must match the NPC's faction, renown, and must also be legal for }
	{ this game board. }
var
	MechaList: GearPtr;
	Factions,Terrain_Type: String;
	Renown: LongInt;
const
	Min_Max_Cost = 400000;
	Max_Min_Cost = 750000;
var
	SRec: SearchRec;
	M,M2,Fac,DList,RScene: GearPtr;
	Cost,Minimum_Cost, Maximum_Cost: LongInt;
	MekName: String;
begin
	MechaList := Nil;

	Renown := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned );

	{ Determine the factions to be used by the NPC. }
	Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
	Factions := 'GENERAL';
	if Fac <> Nil then Factions := Factions + SAttValue( Fac^.SA , 'DESIG' )
	else begin
		rscene := FindRootScene( Nil , Scene );
		if rscene <> Nil then begin
			Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( RScene^.NA , NAG_Personal , NAS_FactionID ) );
			if Fac <> Nil then factions := factions + ' ' + SAttValue( Fac^.SA , 'DESIG' );
		end;
	end;

	{ Determine the terrain type to be used. }
	if ( Scene <> Nil ) then Terrain_Type := SAttValue( Scene^.SA , 'TERRAIN' )
	else Terrain_Type := 'GROUND';

	{ Determine the maximum and minimum mecha costs. }
	Maximum_Cost := Calculate_Threat_Points( Renown , 25 );
	if Maximum_Cost < Min_Max_Cost then Maximum_Cost := Min_Max_Cost;
	Minimum_Cost := Maximum_Cost div 2 - 200000;
	if Minimum_Cost > Max_Min_Cost then Minimum_Cost := Max_Min_Cost;

	{ Start the search process going... }
	FindFirst( Design_Directory + Default_Search_Pattern , AnyFile , SRec );

	{ As long as there are files which match our description, }
	{ process them. }
	While DosError = 0 do begin
		{ Load this mecha design file from disk. }
		DList := LoadFile( SRec.Name , Design_Directory );

		{ Look through this list for mecha to use. }
		M := DList;
		while M <> Nil do begin
			M2 := M^.Next;
			if MechaMatchesFactionAndTerrain( M , Factions , Terrain_Type ) then begin
				Cost := GearValue( M );
				if ( Cost >= Minimum_Cost ) and ( Cost <= Maximum_Cost ) then begin
					{ This is a legal mecha, usable in this terrain, and }
					{ within our price range. Add it to the list. }
					DelinkGear( DList , M );
					AppendGear( MechaList , M );
				end;
			end;
			M := M2;
		end;

		{ Dispose of the design list. }
		DisposeGear( DList );

		{ Look for the next file in the directory. }
		FindNext( SRec );
	end;

	{ By now, we should have a mecha list full of candidates. If not, we better load }
	{ something generic and junky. }
	if MechaList <> Nil then begin
		M := SelectRandomGear( MechaList );
		DelinkGear( MechaList , M );
		DisposeGear( MechaList );
	end else begin
		DialogMsg( GearName( NPC ) + ' is forced to take a crappy mecha...' );
		M := LoadSingleMecha( 'buruburu.txt' , Design_Directory );
	end;

	SelectNPCMecha := M;
end;

end.
