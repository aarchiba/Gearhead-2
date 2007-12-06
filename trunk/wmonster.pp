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
{$LONGSTRINGS ON}

interface

uses gears,locale;

const
	{ This is the minimum point value for meks when calling the STOCKSCENE }
	{ procedure. }
	MinPointValue = 65000;


Procedure RestockRandomMonsters( GB: GameBoardPtr );
Procedure StockBoardWithMonsters( GB: GameBoardPtr; Renown,Strength,TeamID: Integer; MDesc: String );

Function MechaMatchesFaction( Mek: GearPtr; const Factions: String ): Boolean;
Function OptimalMechaValue( Renown: Integer ): LongInt;
Function GenerateMechaList( MPV: LongInt; Factions,Desc: String ): SAttPtr;

Procedure AddTeamForces( GB: GameBoardPtr; TeamID,Renown,Strength: Integer );

Function SelectNPCMecha( GB: GameBoardPtr; Scene,NPC: GearPtr ): GearPtr;

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

Function MonsterStrength( Mon: GearPtr; Renown: Integer ): Integer;
	{ Return the Strength, or point cost, of this monster. The strength }
	{ isn't based objectively on the monster's level, but calculated }
	{ relatively from the provided threat value. }
const
	BaseStrengthValue = 15;
	MinStrengthValue = 1;
var
	it: Integer;
begin
	it := MonsterThreatLevel( Mon );
	if it > Renown then begin
		it := ( it * 3 - Renown * 2 ) * BaseStrengthValue div Renown;
	end else begin
		it := it * BaseStrengthValue div Renown;
	end;
	if it < MinStrengthValue then it := MinStrengthValue;
	MonsterStrength := it;
end;

Function GenerateMonster( Renown,Scale: Integer; const MType,Habitat: String; Scene: GearPtr ): GearPtr;
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
	MonRenown,MaxRenown: Integer;
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
	MaxRenown := ( Renown * 3 ) div 2;
	if MaxRenown < ( Renown + 20 ) then MaxRenown := Renown + 20;
	while WM <> Nil do begin
		{ If this monster matches our criteria, maybe add its number to the list. }
		if ( WM^.Scale <= Scale ) and HabitatMatch( WM ) and EnvironmentMatch( WM ) then begin
			MonRenown := MonsterThreatLevel( WM );
			Match := MatchWeight( MType , SAttValue( WM^.SA , 'TYPE' ) );
			if ( Match > 0 ) then begin
				if ( ( MonRenown > ( Renown + 10 ) ) or ( MonRenown < ( Renown - 20 ) ) ) then begin
					Match := Match div 4;
				end;
				if Match < 1 then Match := 1;
			end;

			{ If this monster's threat value is within the acceptable range, add it to the list. }
			{ Otherwise see if it's the smallest TV found so far, in which case store its identity }
			{ just in case no monsters with acceptable TV are found. }
			if MonRenown <= MaxRenown then begin
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

	DisposeNAtt( ShoppingList );
	SetSATt( WM^.SA , 'JOB <ANIMAL>' );
	GenerateMonster := WM;
end;

Procedure AddRandomMonsters( GB: GameBoardPtr; const WMonType: String; TeamID , Renown,Strength,Gen: Integer );
	{ Place some wandering monsters on the map. }
var
	WM: GearPtr;
	Habitat: String;
begin
	{ Find the WMonType and the Habitat. }
	if GB^.Scene <> Nil then begin
		Habitat := SAttValue( GB^.Scene^.SA , 'HABITAT' );
	end else Habitat := '';

	while ( Gen > 0 ) and ( Strength > 0 ) do begin
		WM := GenerateMonster( Renown , GB^.Scale , WMonType , Habitat , GB^.Scene );
		SetNAtt( WM^.NA , NAG_Location , NAS_Team , TeamID );
		DeployMek( GB , WM , True );

		{ Reduce the generation counter and the threat points. }
		Strength := Strength - MonsterStrength( WM , Renown );
		Dec( Gen );
	end;
end;

Procedure StockBoardWithMonsters( GB: GameBoardPtr; Renown,Strength,TeamID: Integer; MDesc: String );
	{ Place some monsters in this scene. }
begin
	AddRandomMonsters( GB , MDesc , TeamID , Renown , Strength , 9999 );
end;

Function TeamTV( MList: GearPtr; Team,Threat: Integer ): LongInt;
	{ Calculate the total monster strength value of active models belonging }
	{ to TEAM which are present on the map. }
	{ Generally, only characters have monster threat values. }
var
	it: LongInt;
begin
	it := 0;

	while MList <> Nil do begin
		if GearActive( MList ) and ( NAttValue( MList^.NA , NAG_Location , NAS_TEam ) = Team ) then begin
			it := it + MonsterStrength( MList , Threat );
		end;
		MList := MList^.Next;
	end;

	TeamTV := it;
end;

Procedure RestockRandomMonsters( GB: GameBoardPtr );
	{ Replenish this level's supply of random monsters. }
var
	Team: GearPtr;
	TPV: LongInt;
	DungeonStrength: Integer;
begin
	{ Error check - make sure the scene is defined. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;

	DungeonStrength := GB^.map_width * GB^.map_height div 10;

	{ Search through the scene gear for teams which need random }
	{ monsters. If they don't have enough PV, add some monsters. }
	Team := GB^.Scene^.SubCom;
 	while Team <> Nil do begin
		{ if this gear is a team, and it has a wandering monster }
		{ allocation set, add some monsters. }
		if ( Team^.G = GG_Team ) and ( Team^.STat[ STAT_WanderMon ] > 0 ) then begin
			{ Calculate total point value of this team's units. }
			TPV := TeamTV( GB^.Meks , Team^.S , Team^.Stat[ STAT_WanderMon ] );

			if TPV < DungeonStrength then begin
				AddRandomMonsters( GB , SAttValue( Team^.SA , 'TYPE' ) , Team^.S , Team^.Stat[ STAT_WanderMon ] , DungeonStrength - TPV , Random( 3 ) );
			end;
		end;

		{ Move to the next gear. }
		Team := Team^.Next;
	end;
end;

Function MechaMatchesFaction( Mek: GearPtr; const Factions: String ): Boolean;
	{ Return TRUE if this mecha matches one of the listed factions. }
begin
	MechaMatchesFaction := PartAtLeastOneMatch( SAttValue( Mek^.SA , 'FACTIONS' ) , Factions );
end;

Function MechaMatchesFactionAndTerrain( Mek: GearPtr; const Factions,Terrain_Type: String ): Boolean;
	{ Return TRUE if MEK is a legal design for the faction and map, }
	{ or FALSE otherwise. }
begin
	MechaMatchesFactionAndTerrain := ( Mek^.G = GG_Mecha ) and MechaMatchesFaction( Mek , Factions ) and PartMatchesCriteria( SAttValue( Mek^.SA , 'TYPE' ) , Terrain_Type );
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

Function OptimalMechaValue( Renown: Integer ): LongInt;
	{ Return the optimal mecha value for a grunt NPC fighting a character }
	{ with the provided renown. }
const
	MinOMV = 50000;
var
	it: LongInt;
begin
	it := Calculate_Threat_Points( Renown , 20 );
	if it < MinOMV then it := MinOMV;
	OptimalMechaValue := it;
end;

Function PurchaseForces( ShoppingList: SAttPtr; Renown,Strength: Integer ): GearPtr;
	{ Pick a number of random meks. Add pilots to these meks. }
	{ The expected PC skill level is measured by RENOWN. The difficulty of the }
	{ encounter is measured by STRENGTH, which is a percentage with 100 representing }
	{ an average fight. }
	{ Within this procedure it is assumed that 7 points of renown translate to one }
	{ point of skill. That isn't necessarily true at the high and low ends of the spectrum, }
	{ but it's a good heuristic. }
const
	BasicGruntCost = 30;
	SkillPlusCost = 15;
	SkillMinusCost = 7;
var
	OptimalValue: LongInt;	{ The ideal value for a mecha. }

	Function ObtainMekFromFile( S: String ): GearPtr;
		{ Using the description string S, locate and load }
		{ a mek from disk. }
	var
		N: LongInt;
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
		if Strength >= BasicGruntCost then begin
			t := 3;
			while ( t > 0 ) and ( V < ( OptimalValue div 2 ) ) do begin
				M2 := SelectRandomSAtt( ShoppingList )^.Info;
				V2 := ExtractValue( M2 );
				if V2 > V then begin
					M1 := M2;
					V := V2;
				end;

				Dec( T );
			end;
		end else begin
			{ If STRENGTH is running out, select a small mecha instead. }
			t := 2;
			while ( t > 0 ) do begin
				M2 := SelectRandomSAtt( ShoppingList )^.Info;
				V2 := ExtractValue( M2 );
				if V2 < V then begin
					M1 := M2;
					V := V2;
				end;

				Dec( T );
			end;
		end;

		{ Return the info string selected. }
		SelectNextMecha := M1;
	end;
var
	MPV: LongInt;
	StrCost: LongInt;	{ The number of strength points this mecha will cost. }

	Lvl,Bonus: LongInt;		{ Pilot level. }
	Mek,MList,CP,Pilot: GearPtr;
begin
	{ Initialize our list to Nil. }
	MList := Nil;

	{ Record the optimal mecha value. }
	OptimalValue := OptimalMechaValue( Renown );

	{ Keep processing until we run out of points. }
	{ The points are represented by STRENGTH. }
	while ( Strength > 0 ) and ( ShoppingList <> Nil ) do begin
		{ Select a mek at random. }
		{ Load & Clone the mek. }
		Mek := ObtainMekFromFile( SelectNextMecha );
		{ Determine its cash value. }
		MPV := GearValue( Mek );

		{ From this, we may determine its base STRENGTH value. }
		StrCost := ( MPV * BasicGruntCost ) div OptimalValue;
		if StrCost < 5 then StrCost := 5;

		{ Select a pilot skill level. }
		{ Base pilot level is 20 beneath the PC's renown. }
		Lvl := Renown - 20;

		{ This level may be adjusted up or down depending on the mecha's cost. }
		if StrCost > Strength then begin
			{ We've gone overbudget. Whack this mecha's pilot. }
			Lvl := Lvl - ( StrCost - Strength );
			StrCost := Strength;

		end else if ( ( StrCost * 3 ) < Strength ) and ( Strength > 90 ) and ( Random( 3 ) <> 1 ) then begin
			{ We have plenty of points to spare. Give this pilot some lovin'. }
			Bonus := Random( 3 ) + 1;
			Lvl := Lvl + Bonus * 7;
			StrCost := StrCost + Bonus * SkillPlusCost;

		end else if ( StrCost > ( BasicGruntCost + 1 + Random( 20 ) ) ) and ( Strength < ( 76 + Random( 175 ) ) ) then begin
			{ Slightly overbudget... can reduce the cost with skill reduction. }
			{ Note that we won't be reducing skills at all if STRENGTH is }
			{ sufficiently high. }
			Bonus := Random( 4 );
			Lvl := Lvl - Bonus * 7;
			StrCost := StrCost - Bonus * SkillMinusCost;

		end else if StrCost < ( BasicGruntCost - 1 - Random( 15 ) ) then begin
			{ Underbudget... we can afford a better pilot. }
			Bonus := Random( 3 );
			if Random( 10 ) = 4 then Inc( Bonus );
			Lvl := Lvl + Bonus * 7;
			StrCost := StrCost + Bonus * SkillPlusCost;
		end;

		{ If Strength is extremely high, maybe give an extra skill point }
		{ in order to increase the cost. This extra skill point costs more than }
		{ the above, since it can potentially raise the pilot to named-NPC-like }
		{ status. }
		if ( Strength > ( 201 + Random( 300 ) ) ) and ( Strength > ( StrCost * 3 ) ) then begin
			Lvl := Lvl + 7;
			StrCost := StrCost + SkillPlusCost * 2;
		end;

		{ Add this mecha to our list. }
		AppendGear( MList , Mek );

		{ Create a pilot, add it to the mecha. }
		CP := SeekGear( Mek , GG_CockPit , 0 );
		if CP <> Nil then begin
			Pilot := RandomPilot( 80  , 10 );
			SetSkillsAtLevel( Pilot , Lvl );
			InsertSubCom( CP , Pilot );
		end;

		{ Reduce UPV by an appropriate amount. }
		Strength := Strength - StrCost;
	end;

	PurchaseForces := MList;
end;

Procedure AddTeamForces( GB: GameBoardPtr; TeamID,Renown,Strength: Integer );
	{ Add forces to the gameboard. }
	{ RENOWN is the expected renown of the player's team. }
	{ STRENGTH is the difficulty level of this fight expressed as a percent. }
var
	SList: SAttPtr;
	MList,Mek,Pilot: GearPtr;
	desc,fdesc: String;
	team,fac,rscene: GearPtr;
	MaxMekShare,MPV: LongInt;
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
	if Strength < 202 then MaxMekShare := 200
	else MaxMekShare := ( Strength div 2 ) + 100;
	MPV := ( OptimalMechaValue( Renown ) * MaxMekShare ) div 100;
	if MPV < 300000 then MPV := 300000;
	SList := GenerateMechaList( MPV , fdesc , desc );

	{ Generate the mecha list. }
	MList := PurchaseForces( SList , Renown , Strength );

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



Function SelectNPCMecha( GB: GameBoardPtr; Scene,NPC: GearPtr ): GearPtr;
	{ Select a mecha for the provided NPC. }
	{ This mecha must match the NPC's faction, renown, and must also be legal for }
	{ this game board. }
const
	Min_Max_Cost = 400000;
	Max_Min_Cost = 1000000;
var
	MechaList: GearPtr;
	Factions,Terrain_Type: String;
	Renown: LongInt;
	SRec: SearchRec;
	M,M2,Fac,DList,RScene: GearPtr;
	Cost,Minimum_Cost, Maximum_Cost: LongInt;
begin
	MechaList := Nil;

	Renown := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned );

	{ Determine the factions to be used by the NPC. }
	Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
	Factions := 'GENERAL';
	if Fac <> Nil then Factions := Factions + ' ' + SAttValue( Fac^.SA , 'DESIG' )
	else begin
		rscene := FindRootScene( GB , Scene );
		if rscene <> Nil then begin
			Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( RScene^.NA , NAG_Personal , NAS_FactionID ) );
			if Fac <> Nil then factions := factions + ' ' + SAttValue( Fac^.SA , 'DESIG' );
		end;
	end;

	{ Determine the terrain type to be used. }
	if ( Scene <> Nil ) then Terrain_Type := SAttValue( Scene^.SA , 'TERRAIN' )
	else Terrain_Type := 'GROUND';

	{ Determine the maximum and minimum mecha costs. }
	Maximum_Cost := OptimalMechaValue( Renown ) * 3;
	if Maximum_Cost < Min_Max_Cost then Maximum_Cost := Min_Max_Cost;
	Minimum_Cost := Maximum_Cost div 3;
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
		DialogMsg( GearName( NPC ) + ' is forced to take a crappy mecha...' + Terrain_Type + ' ' + Factions + BStr( Minimum_Cost ) + ' - ' + Bstr( Maximum_Cost ) );
		M := LoadSingleMecha( 'buruburu.txt' , Design_Directory );
	end;

	SelectNPCMecha := M;
end;

end.
