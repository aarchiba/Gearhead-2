unit gearparser;
	{This unit reads a text file and converts it into game}
	{data for GearHead.}
	{ See MDLref.txt for a list of commands. }
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

uses dos,rpgdice,texutil,gears,ghmecha,ghmodule,ghchars,ghweapon,ghsupport,gearutil,locale,interact,ability,ui4gh,ghholder;

Const
	SLOT_Next = 0;
	SLOT_Sub  = 1;
	SLOT_Inv  = 2;

var
	Parser_Macros: SAttPtr;

	Archetypes_List: GearPtr;
	WMonList: GearPtr;
	Standard_Equipment_List: GearPtr;
	STC_Item_List: GearPtr;
	Factions_List: GearPtr;
	Mecha_Theme_List: GearPtr;

Procedure ScaleSkillsToLevel( NPC: GearPtr; Lvl: Integer );
Procedure SetSkillsAtLevel( NPC: GearPtr; Lvl: Integer );
Function SelectMechaByFactionAndRenown( Factions: String; Renown: Integer ): String;
Procedure IndividualizeNPC( NPC: GearPtr );
Procedure SelectEquipmentForNPC( NPC: GearPtr; Renown: Integer );


Procedure CheckValidity( var it: GearPtr );
Procedure ApplyCharDesc( NPC: GearPtr; CDesc: String );

Function LoadFile( FName,DName: String ): GearPtr;
Function LoadFile( FName: String ): GearPtr;
Function LoadGearPattern( FName,DName: String ): GearPtr;

Function AggregatePattern( FName,DName: String ): GearPtr;
Function LoadRandomSceneContent( FName,DName: String ): GearPtr;

Function LoadSingleMecha( FName,DName: String ): GearPtr;
Function LoadNewMonster( MonsterName: String ): GearPtr;
Function LoadNewNPC( NPCName: String; RandomizeNPCs: Boolean ): GearPtr;
Function LoadNewSTC( Desig: String ): GearPtr;

Procedure RandomLoot( Box: GearPtr; SRP: LongInt; const l_type,l_factions: String );

implementation

{$IFDEF ASCII}
uses vidgfx;
{$ELSE}
uses glgfx;
{$ENDIF}

Const
	Recursion_Level: Integer = 0;

Procedure SelectThemeAndSpecialty( NPC: GearPtr );
	{ Set a theme and a specialty skill for this NPC. }
const
	Default_Skill_List = '1 2 3 4 5 12 18 42';
var
	Faction,Theme: GearPtr;
	SkillPossibilities: Array [1..NumSkill] of Boolean;
	SpecSkill,T,N: Integer;
	SkList: String;
begin
	if NAttValue( NPC^.NA , NAG_Personal , NAS_SpecialistSkill ) <> 0 then begin
		DialogMsg( 'WARNING: ' + GearName( NPC ) + '/' + SAttValue( NPC^.SA , 'JOB' ) + '/' + BStr( NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) ) + ' had spec skill ' + BStr( NAttValue( NPC^.NA , NAG_Personal , NAS_SpecialistSkill ) ) + ' set.' );
	end;

	{ Start by locating the faction. This should contain a list of preferred skill specialties. }
	Faction := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
	if Faction <> Nil then SkList := SAttValue( Faction^.SA , 'Specialist_Skills' )
	else SkList := Default_Skill_List;
	if ( SkList = '' ) or ( Random(10) = 1) then SkList := Default_Skill_List;

	{ Clear the SkillPossibilities array, then fill it with entries from the SkList. }
	for t := 1 to NumSkill do SkillPossibilities[t] := False;
	while SkList <> '' do begin
		T := ExtractValue( SkList );
		if ( T >= 1 ) and ( T <= NumSkill ) then SkillPossibilities[t] := True;
	end;

	{ Count the number of skills, pick one at random. }
	N := 0;
	for t := 1 to NumSkill do if SkillPossibilities[t] then Inc( N );
	N := Random( N );
	SpecSkill := 0;
	for t := 1 to NumSkill do begin
		if SkillPossibilities[t] then begin
			Dec( N );
			if N = -1 then begin
				SpecSkill := T;
				break;
			end;
		end;
	end;
	if SpecSkill = 0 then SpecSkill := Random( 5 ) + 1;

	{ Store the specialist skill, and prepare to select the theme. }
	SetNAtt( NPC^.NA , NAG_Personal , NAS_SpecialistSkill , SpecSkill );
	SetNAtt( NPC^.NA , NAG_Skill , SpecSkill , 12 );

	{ Next, it's time to find a theme for this NPC. The theme selected }
	{ is gonna depend on a bunch of stuff: The NPC's faction, the NPC's job, }
	{ personality traits and yadda yadda yadda... }
	{ All characters can take GENERAL themes. }
	SkList := 'GENERAL ' + NPCTraitDesc( NPC ) + ' ' + SAttValue( NPC^.SA , 'JOB_DESIG' );
	{ Add the specialist skill. }
	SkList := SkList + ' [' + BStr( SpecSkill ) + ']';
	if Faction <> Nil then SkList := SkList + ' ' + SAttValue( Faction^.SA , 'DESIG' );

	Theme := FindNextComponent( Mecha_Theme_List , SkList );
	if Theme <> Nil then SetNAtt( NPC^.NA , NAG_Personal , NAS_MechaTheme , Theme^.S )
	else DialogMsg( 'ERROR: No theme found for ' + SkList );
end;

Procedure ScaleSkillsToLevel( NPC: GearPtr; Lvl: Integer );
	{ Scale this NPC's skills to the requested level. }
var
	Skill: NAttPtr;
begin
	{ If the NPC doesn't have a specialist skill, pick a skill and theme now. }
	if IsACombatant( NPC ) and ( NAttValue( NPC^.NA , NAG_Personal , NAS_MechaTheme ) = 0 ) then begin
		SelectThemeAndSpecialty( NPC );
	end;

	Skill := NPC^.NA;
	while Skill <> Nil do begin
		if Skill^.G = NAG_Skill then begin
			Skill^.V := ( Skill^.V * Lvl ) div 100;
			if Skill^.V < 1 then Skill^.V := 1;
		end;
		Skill := Skill^.Next;
	end;
end;

Procedure SetSkillsAtLevel( NPC: GearPtr; Lvl: Integer );
	{ Set all of this NPC's skills to an appropriate value for }
	{ the requested level. }
var
	SkLvl: Integer;
	Skill: NAttPtr;
begin
	{ If the NPC doesn't have a specialist skill, pick a skill and theme now. }
	if IsACombatant( NPC ) and ( NAttValue( NPC^.NA , NAG_Personal , NAS_MechaTheme ) = 0 ) then begin
		SelectThemeAndSpecialty( NPC );
	end;

	{ Determine the value to set all skills to. }
	SkLvl := ( Lvl div 7 ) + 3;
	if SkLvl < 1 then SkLvl := 1;

	{ Go through the skills and set them. }
	Skill := NPC^.NA;
	while Skill <> Nil do begin
		if Skill^.G = NAG_Skill then begin
			Skill^.V := SkLvl;
		end;
		Skill := Skill^.Next;
	end;

	{ Apply a slight bonus to the specialist skill. }
	SkLvl := NAttValue( NPC^.NA , NAG_Personal , NAS_SpecialistSkill );
	if ( SkLvl > 0 ) and ( SkLvl <= NumSkill ) then AddNAtt( NPC^.NA , NAG_Skill , SkLvl , 1 );
end;


Function SelectMechaByFactionAndRenown( Factions: String; Renown: Integer ): String;
	{ Select a mecha based on factions and renown. }
	Function MechaFileMatchWeight( MList: GearPtr ): LongInt;
		{ In order to pass this test, this file must match several }
		{ requirements. There must be mecha capable of travelling in }
		{ all terrain types, there must be at least one mecha matching }
		{ the NPC's faction. }
	const
		Num_Terr_Specs = 2;
		Terr_Spec_Name: Array [1..Num_Terr_Specs] of string = (
		'GROUND', 'SPACE'
		);
	var
		M: GearPtr;
		T,N: Integer;
		Total: Int64;
		FacFound: Boolean;
		TerrType: String;
		Terr_Spec_Found: Array [1..Num_Terr_Specs] of Boolean;
	begin
		{ Initialize the Terr_Spec_Found array }
		for t := 1 to Num_Terr_Specs do Terr_Spec_Found[t] := False;
		Total := 0;
		N := 0;
		FacFound := False;

		{ Go through the list searching for stuff. }
		M := MList;
		while M <> Nil do begin
			if M^.G = GG_Mecha then begin
				Total := Total + GearValue( M );

				if PartAtLeastOneMatch( SAttValue( M^.SA , 'FACTIONS' ) , Factions ) then FacFound := True;

				TerrType := SAttValue( M^.SA , 'TYPE' );
				for t := 1 to Num_Terr_Specs do begin
					if AStringHasBString( TerrType , Terr_Spec_Name[ t ] ) then Terr_Spec_Found[ t ] := True;
				end;

				Inc( N );
			end;
			M := M^.Next;
		end;

		{ Check to see if all the terrain types were found. }
		for t := 1 to Num_Terr_Specs do if not Terr_Spec_Found[t] then FacFound := False;

		if FacFound and ( N > 0 ) then begin
			MechaFileMatchWeight := Total div N;
		end else MechaFileMatchWeight := 0;
	end;
const
	Min_Max_Cost = 400000;
	Max_Min_Cost = 750000;
var
	SRec: SearchRec;
	MechaList: SAttPtr;
	DList: GearPtr;
	Minimum_Cost, Maximum_Cost: LongInt;
	File_Cost: LongInt;
	MekName: String;
begin
	MechaList := Nil;

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

		File_Cost := MechaFileMatchWeight( DList );
		if File_Cost > 0 then begin
			if ( File_Cost > Minimum_Cost ) and ( File_Cost < Maximum_Cost ) then begin
				StoreSAtt( MechaList , SRec.Name );
			end;
		end;

		{ Dispose of the list. }
		DisposeGear( DList );

		{ Look for the next file in the directory. }
		FindNext( SRec );
	end;

	if MechaList <> Nil then begin
		MekName := SelectRandomSAtt( MechaList )^.Info;
		DisposeSAtt( MechaList );
	end else begin
		MekName := 'buruburu.txt';
	end;

	SelectMechaByFactionAndRenown := MekName;
end;

Procedure IndividualizeNPC( NPC: GearPtr );
	{ Randomize up this NPC a bit, to give it that hand-crafted }
	{ NPC look. }
	{ Note that if the NPC has a name by the time it reaches here, its }
	{ personality traits and stats will not be touched. }
var
	N,T,Lvl: Integer;
begin
	{ If the NPC doesn't have a body defined, create one. }
	if NPC^.SubCom = Nil then begin
		ExpandCharacter( NPC );
	end;

	{ Give the NPC a random name + gender + age + personality traits. }
	if SAttValue( NPC^.SA , 'NAME' ) = '' then begin
		SetSAtt( NPC^.SA , 'NAME <' + RandomName + '>' );
		SetNAtt( NPC^.NA , NAG_CharDescription , NAS_Gender , Random( 2 ) );
		AddNAtt( NPC^.NA , NAG_CharDescription , NAS_DAge , 1 + Random( 10 ) - Random( 10 ) + RollStep( 5 ) );

		{ Give out some personality traits. }
		{ Most NPCs have at least a single trait in the group Sociable,Easygoing,Cheerful }
		if Random( 5 ) <> 1 then begin
			if Random( 3 ) = 1 then begin
				AddReputation( NPC, 3 + Random( 3 ) , -RollStep( 40 ) );
			end else begin
				AddReputation( NPC, 3 + Random( 3 ) ,  RollStep( 40 ) );
			end;
		end;
		{ Add RollStep(2) other personality traits. }
		N := RollStep( 2 );
		for t := 1 to N do begin
			{ Positive traits are far more common than negative ones. }
			if Random( 3 ) = 1 then begin
				if Random( 7 ) = 1 then begin
					AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , -RollStep( 50 ) );
				end else begin
					AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , -RollStep( 20 ) );
				end;
			end else begin
				if Random( 7 ) = 1 then begin
					AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , RollStep( 50 ) );
				end else begin
					AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , RollStep( 20 ) );
				end;
			end;
		end;

		{ Randomize up those stats a bit. }
		for t := 1 to NumGearStats do begin
			NPC^.Stat[T] := NPC^.Stat[T] + Random( 4 ) - Random( 4 );
			if Random( 32 ) = 1 then NPC^.Stat[T] := NPC^.Stat[T] + Random( 5 ) - Random( 5 );
			if NPC^.Stat[T] < 1 then NPC^.Stat[T] := 1;
		end;
	end;

	{ If this is a combatant character, set the skills to match the reputation. }
	if IsACombatant( NPC ) then begin
		Lvl := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned );
		if Lvl = 0 then begin
			AddReputation( NPC , Abs( NAS_Renowned ) , Random( 75 ) );
			if Random( 3 ) = 1 then AddReputation( NPC , Abs( NAS_Renowned ) , -Random( 25 ) );
			Lvl := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned );
		end;

		{ Give some random equipment. }
		{ Only do this once, otherwise certain characters might get it a }
		{ second time. }
		if NAttValue( NPC^.NA , NAG_Narrative , NAS_GotFreeEquipment ) = 0 then begin
			SelectEquipmentForNPC( NPC , Lvl );
			SetNAtt( NPC^.NA , NAG_Narrative , NAS_GotFreeEquipment , 1 );
		end;

		Lvl := Lvl + 50;
		if Lvl < 25 then Lvl := 25;
		ScaleSkillsToLevel( NPC , Lvl );
	end;

	{ The random personality traits may have affected morale. }
	SetNAtt( NPC^.NA , NAG_Condition , NAS_MoraleDamage , 0 );
end;

Procedure SelectEquipmentForNPC( NPC: GearPtr; Renown: Integer );
	{ This procedure will select some decent equipment for the given NPC from the standard }
	{ equipment list. Faction will be taken into account. }
	{ Many of these procedures will rely upon a special kind of shopping list }
	{ composed of numeric attributes. }
	{ SHOPPING LIST }
	{ G = Item index in Standard_Equipment_List }
	{ S = Undefined }
	{ V = Item "goodness"- basically cost plus a bonus for appropriateness }
var
	Faction_Desc: String;
	Spending_Limit,Legality_Limit: LongInt;
	Function ItemLegalForFaction( I: GearPtr ): Boolean;
		{ Return TRUE if this item can be used by the NPC's faction, or FALSE }
		{ otherwise. }
		{ This function uses the FACTION_DESC string, so better initialize it }
		{ before calling this one. }
	begin
		ItemLegalForFaction := PartAtLeastOneMatch( SAttValue( I^.SA , 'FACTIONS' ) , Faction_Desc ) and ( NAttValue( I^.NA , NAG_GearOps , NAS_Legality ) <= Legality_Limit );
	end;
	Procedure AddToShoppingList( var ShoppingList: NAttPtr; Item: GearPtr; N: Integer );
		{ Calculate this item's desirability and add it to the list. }
	var
		Desi: LongInt;	{ Short for desirability. }
	begin
		Desi := GearValue( Item );
		{ If this item is limited to certain factions, it gets extra desirability. }
		if not AStringHasBString( SAttValue( Item^.SA , 'FACTIONS' ) , 'GENERAL' ) then Desi := ( Desi * 5 ) div 4;
		SetNAtt( ShoppingList , N , 0 , Desi );
	end;
	Procedure EquipItem( Slot , Item: GearPtr );
		{ This is the real equipping procedure. Stuff ITEM into SLOT. }
		{ As noted in TheRules.txt, any nonmaster gear can only have one }
		{ item of any particular "G" type equipped at a time. So, if }
		{ SLOT already has equipment of type ITEM^.G, unequip that and }
		{ stuff it into PC's general inventory. }
	var
		I2,I3: GearPtr;
	begin
		{ First, check for already equipped items. }
		I2 := Slot^.InvCom;
		while I2 <> Nil do begin
			I3 := I2^.Next;		{ This next step might delink I2, so... }
			if ( I2^.G = Item^.G ) or ( Slot^.G = GG_Holder ) then begin
				DelinkGear( Slot^.InvCom , I2 );
				InsertInvCom( NPC , I2 );
			end;
			I2 := I3;
		end;

		{ We can now link ITEM into SLOT. }
		InsertInvCom( Slot , Item );
	end;
	Function SelectItemForNPC( ShoppingList: NAttPtr ): GearPtr;
		{ Considering this shopping list, select an item for the NPC }
		{ based on the listed desirabilities. Then, locate the item }
		{ referred to in the master item list, clone it, and return the }
		{ copy. Hooray! }
	var
		SLI: NAttPtr;
		Total: Int64;
		N: Integer;
		Item: GearPtr;
	begin
		{ Quick way out- if this list is empty, no sense in doing any real }
		{ work, is there? }
		if ShoppingList = Nil then Exit( Nil );

		{ To start, go through the list and count up how many }
		{ points we'll be dealing with. }
		{ Quadratic weighting didn't work so well- back to linear. }
		Total := 0;
		SLI := ShoppingList;
		while SLI <> Nil do begin
			Total := Total + SLI^.V;
{			Total := Total + ( SLI^.V * SLI^.V );}
			SLI := SLI^.Next;
		end;

		{ Next, go through one more time and pick one randomly. }
		Total := Random( Total );
		SLI := ShoppingList;
		N := 0;
		while ( N = 0 ) and ( SLI <> Nil ) do begin
			Total := Total - SLI^.V;
{			Total := Total - ( SLI^.V * SLI^.V );}
			if Total < 0 then N := SLI^.G;
			SLI := SLI^.Next;
		end;

		{ Ah, finally. We should now have a usable number. }
		Item := RetrieveGearSib( Standard_Equipment_List , N );
		SelectItemForNPC := CloneGear( Item );
	end;
	Function GenerateShoppingList( Slot: GearPtr; GG: Integer; MaxValue: LongInt ): NAttPtr;
		{ Generate a shopping list of items with Gear General value GG which }
		{ can be equipped as InvComs of Slot. }
		Function ModifiedGearValue( Item: GearPtr ): LongInt;
			{ This just basically calls GearValue, but applies an extra markup to melee weapons. }
			{ I do this to keep the high end melee weapons out of the hands of low end thugs. }
			{ Melee weapons are naturally cheaper than ranged weapons, so to keep the low to high }
			{ spread we'll have to fudge things a little. }
		begin
			if ( Item^.G = GG_Weapon ) and ( ( Item^.S = GS_Melee ) or ( Item^.S = GS_EMelee ) ) then begin
				ModifiedGearValue := GearValue( Item ) * 3;
			end else begin
				ModifiedGearValue := GearValue( Item );
			end;
		end;
	var
		ShoppingList: NAttPtr;
		Item: GearPtr;
		N: Integer;
	begin
		ShoppingList := Nil;
		Item := Standard_Equipment_List;
		N := 1;
		while Item <> Nil do begin
			if ( Item^.G = GG ) and ItemLegalForFaction( Item ) and isLegalInvCom( Slot , Item ) and ( ModifiedGearValue( Item ) < MaxValue ) then begin
				AddToShoppingList( ShoppingList , Item , N );
			end;
			Inc( N );
			Item := Item^.Next;
		end;
		GenerateShoppingList := ShoppingList;
	end;
	Procedure GenerateItemForSlot( Slot: GearPtr; GG: Integer; MaxValue: LongInt );
		{ Generate an item for this slot of the requested GG type and equip it. }
	var
		ShoppingList: NAttPtr;
		Item: GearPtr;
	begin
		ShoppingList := GenerateShoppingList( Slot , GG , MaxValue );
		Item := SelectItemForNPC( ShoppingList );
		DisposeNAtt( ShoppingList );
		EquipItem( Slot , Item );
	end;
	Procedure BuyArmorForNPC();
		{ Armor will be purchased in sets if possible. }
		Function IsArmorSet( S: GearPtr ): Boolean;
			{ Is this gear an armor set? }
			{ This procedure seems a bit like overkill, but it should cover all }
			{ possibilities. }
		var
			A: GearPtr;
			SampleLeg,SampleArm,SampleBody: GearPtr;
			NeededLegs,NeededArms,NeededBodies: Integer;
		begin
			if S^.G <> GG_Set then Exit( False );

			{ Locate the sample arm, leg, and body that we're going to need. }
			SampleLeg := SeekCurrentLevelGear( NPC^.SubCom , GG_Module , GS_Leg );
			if SampleLeg <> Nil then NeededLegs := 2
			else NeededLegs := 0;

			SampleArm := SeekCurrentLevelGear( NPC^.SubCom , GG_Module , GS_Arm );
			if SampleArm <> Nil then NeededArms := 2
			else NeededArms := 0;

			SampleBody := SeekCurrentLevelGear( NPC^.SubCom , GG_Module , GS_Body );
			if SampleBody <> Nil then NeededBodies := 1
			else NeededBodies := 0;

			{ Check through the armor to make sure it has a body, two arms, and two legs }
			{ in SF: 0. The helmet is optional. }
			A := S^.InvCom;
			while A <> Nil do begin
				if ( A^.G = GG_ExArmor ) and ( A^.Scale = 0 ) then begin
					if ( A^.S = GS_Arm ) and IsLegalInvCom( SampleArm , A ) then Dec( NeededArms )
					else if ( A^.S = GS_Leg ) and IsLegalInvCom( SampleLeg , A ) then Dec( NeededLegs )
					else if ( A^.S = GS_Body ) and IsLegalInvCom( SampleBody , A ) then Dec( NeededBodies );
				end;
				A := A^.Next;
			end;

			IsArmorSet := (NeededLegs < 1 ) and ( NeededArms < 1 ) and ( NeededBodies < 1 );
		end;
		Function SetInPriceRange( S: GearPtr ): Boolean;
			{ Check this armor set to make sure that nothing within it }
			{ is more expensive than our spending limit. }
		var
			A: GearPtr;
			AllOK: Boolean;
		begin
			{ Assume TRUE unless found FALSE. }
			AllOK := TRUE;
			A := S^.InvCom;
			while A <> Nil do begin
				if GearValue( A ) > Spending_Limit then AllOK := False;
				A := A^.Next;
			end;
			SetInPriceRange := AllOK;
		end;
		Procedure GetArmorForLimb( Limb: GearPtr );
			{ We're getting armor for this particular limb. }
		begin
			GenerateItemForSlot( Limb , GG_ExArmor , Spending_Limit );
		end;
		Procedure WearArmorSet( ASet: GearPtr );
			{ An armor set has been chosen. Wear it by going through }
			{ the NPC's modules and applying armor to each one by one. }
		var
			Limb,Armor: GearPtr;
		begin
			Limb := NPC^.SubCom;
			while Limb <> Nil do begin
				if Limb^.G = GG_Module then begin
					{ Try to locate armor for this part. }
					Armor := SeekCurrentLevelGear( ASet^.InvCom , GG_ExArmor , Limb^.S );
					if Armor <> Nil then begin
						if IsLegalInvCom( Limb , Armor ) then begin
							DelinkGear( ASet^.InvCom , Armor );
							EquipItem( Limb , Armor );
						end else begin
							RemoveGear( ASet^.InvCom , Armor );
							GetArmorForLimb( Limb );
						end;
					end else if Random( 60 ) <= Renown then begin
						GetArmorForLimb( Limb );
					end;
				end;

				Limb := Limb^.Next;
			end;
		end;
		Procedure ApplyPiecemealArmor();
			{ No armor set was found. Instead, go through each limb and }
			{ locate an independant piece of armor for each. }
		var
			Limb: GearPtr;
		begin
			Limb := NPC^.SubCom;
			while Limb <> Nil do begin
				if Limb^.G = GG_Module then begin
					{ Try to locate armor for this part. }
					if Random( 40 ) <= Renown then GetArmorForLimb( Limb );
				end;

				Limb := Limb^.Next;
			end;
		end;
	var
		A: GearPtr;
		ShoppingList: NAttPtr;
		N: Integer;
	begin
		{ Start by looking for an armor set. }
		{ Create the shopping list. }
		ShoppingList := Nil;
		A := Standard_Equipment_List;
		N := 1;
		while A <> Nil do begin
			if IsArmorSet( A ) and SetInPriceRange( A ) and ItemLegalForFaction( A ) then begin
				AddToShoppingList( ShoppingList , A , N );
			end;
			Inc( N );
			A := A^.Next;
		end;

		{ Select a set from the shopping list. }
		A := SelectItemForNPC( ShoppingList );
		DisposeNAtt( ShoppingList );

		{ If we got something, use it. }
		if A <> Nil then begin
			WearArmorSet( A );
			{ Get rid of the leftover set bits. }
			DisposeGear( A );
		end else begin
			{ No armor set was found. Instead, apply piecemeal armor to }
			{ this character. }
			ApplyPiecemealArmor();
		end;
	end;
	Procedure BuyWeaponsForNPC();
		{ In order to buy weapons we're going to have to search for appropriate parts. }
		{ Look for some arms- the first arm found gets a primary weapon. Each additional }
		{ arm has a random chance of getting either a secondary weapon or a shield. I }
		{ know that people usually only come with two arms, but as with all things it's best }
		{ to keep this procedure as versatile as possible. }
		Function WSNeeded( Wep: GearPtr ): Integer;
			{ Return the skill needed by this weapon. }
			{ Note that WEP absolutely must be a weapon. No passing me other kinds of crap!!! }
		begin
			if ( Wep^.S = GS_Melee ) or ( Wep^.S = GS_EMelee ) then WSNeeded := 8
			else if ( Wep^.S = GS_Missile ) or ( Wep^.S = GS_Grenade ) or ( Wep^.V > 10 ) then WSNeeded := 7
			else WSNeeded := 6;
		end;
		Function GenerateWeaponList( Slot: GearPtr; WS: Integer; MaxValue: LongInt ): NAttPtr;
			{ Generate a shopping list of weapons using the provided skill which }
			{ can be equipped as InvComs of Slot. }
		var
			ShoppingList: NAttPtr;
			Item,Best_Offer: GearPtr;
			N,Best_N: Integer;
			WCost,Best_Value: LongInt;
		begin
			ShoppingList := Nil;
			Item := Standard_Equipment_List;
			N := 1;
			Best_Offer := Nil;
			while Item <> Nil do begin
				if ( Item^.G = GG_Weapon ) and ItemLegalForFaction( Item ) and isLegalInvCom( Slot , Item ) and ( WSNeeded( Item ) = WS ) then begin
					WCost := GearValue( Item );
					if ( WCost < MaxValue ) then begin
						AddToShoppingList( ShoppingList , Item , N );
					end else begin
						if ( Best_Offer = Nil ) or ( WCost < Best_Value ) then begin
							Best_Offer := Item;
							Best_N := N;
							Best_Value := WCost;
						end;
					end;
				end;
				Inc( N );
				Item := Item^.Next;
			end;
			{ If, after all that, the list is empty... good thing we went looking for a spare, innit? }
			if ( ShoppingList = Nil ) and ( Best_Offer <> Nil ) then AddToShoppingList( ShoppingList , Best_Offer , Best_N );
			GenerateWeaponList := ShoppingList;
		end;
		Procedure GenerateWeaponForSlot( Slot: GearPtr; WS: Integer; MaxValue: LongInt );
			{ Generate an weapon for this slot of the requested WS type and equip it. }
		var
			ShoppingList: NAttPtr;
			Item: GearPtr;
		begin
			ShoppingList := GenerateWeaponList( Slot , WS , MaxValue );
			Item := SelectItemForNPC( ShoppingList );
			DisposeNAtt( ShoppingList );
			EquipItem( Slot , Item );
		end;

	var
		Limb,Hand: GearPtr;
		NeedPW,NeedRanged: Boolean;	{ Need Primary Weapon }
		AC_Skill,HW_Skill,SA_Skill: Integer;
	begin
		Limb := NPC^.SubCom;
		NeedPW := True;
		NeedRanged := True;
		AC_Skill := SkillValue( NPC , 8 );
		HW_Skill := SkillValue( NPC , 7 );
		SA_Skill := SkillValue( NPC , 6 );
		while Limb <> Nil do begin
			if ( Limb^.G = GG_Module ) and ( Limb^.S = GS_Arm ) then begin
				Hand := SeekCurrentLevelGear( Limb^.SubCom , GG_Holder , GS_Hand );
				if ( Hand <> Nil ) then begin
					if NeedPW then begin
						if ( SA_Skill >= HW_Skill ) and ( SA_Skill >= AC_Skill ) then begin
							{ Small Arms skill dominates. Better get a small arms weapon. }
							GenerateWeaponForSlot( Hand , 6 , Spending_Limit * 2 );
							NeedRanged := False;
						end else if ( AC_Skill >= HW_Skill ) then begin
							{ Armed Combat dominates. Better get a melee weapon. }
							GenerateWeaponForSlot( Hand , 8 , Spending_Limit * 2 );
						end else begin
							{ Might as well get a heavy weapon. }
							GenerateWeaponForSlot( Hand , 7 , Spending_Limit * 2 );
							NeedRanged := False;
						end;
						NeedPW := False;
					end else if Random( 100 ) < Renown then begin
						{ Add either a shield or a second weapon. }
						if Random( 20 ) = 1 then begin
							GenerateItemForSlot( Limb , GG_Shield , Spending_Limit );
						end else if NeedRanged then begin
							if SA_Skill >= HW_Skill then GenerateWeaponForSlot( Hand , 6 , Spending_Limit )
							else GenerateWeaponForSlot( Hand , 7 , Spending_Limit );
							NeedRanged := False;
						end else begin
							GenerateItemForSlot( Hand , GG_Weapon , Spending_Limit );
						end;
					end;
				end;
			end;
			Limb := Limb^.Next;
		end;
	end;
var
	Fac: GearPtr;
begin
	{ Initialize the values. }
	Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
	Faction_Desc := 'GENERAL ';
	if Fac <> Nil then Faction_Desc := Faction_Desc + SAttValue( Fac^.SA , 'DESIG' );

	if Renown < 10 then Renown := 10;
	Spending_Limit := Calculate_Threat_Points( Renown , 1 );

	Legality_Limit := -NAttValue( NPC^.NA , NAG_CharDescription , NAS_Lawful );
	if Legality_Limit < 10 then Legality_Limit := 10;

	{ Unlike the previous, this will split things into several separate parts. }
	BuyArmorForNPC();

	{ Purchase some weapons. }
	BuyWeaponsForNPC();
end;

Procedure ComponentScan( it: GearPtr );
	{ This procedure will check each individual component of a mek }
	{ to make sure it is legal. }
begin
	{Loop through all the components.}
	while it <> Nil do begin
		{Perform specific checks here.}
		CheckGearRange( it );

		if it^.SubCom <> Nil then ComponentScan(it^.SubCom);
		if it^.InvCom <> Nil then ComponentScan(it^.InvCom);
		it := it^.Next;
	end;
end;

Procedure CheckMechaMetrics(it: GearPtr);
	{ Examine the components of this mecha to make sure it has everything }
	{ it needs. }
	{ - Exactly one Cockpit }
	{ - Exactly one Body }
	{ - Exactly one engine in the body; If not present, add one. }
	{ - Exactly one gyroscope in the body; If not present, add one. }
	{ If unrecoverable errors are encountered, mark mek as invalid. }
var
	S,SG: GearPtr;
	Body,CPit: Integer;
	procedure SubComScan( P: GearPtr );
	begin
		while P <> Nil do begin
			if P^.G = GG_Cockpit then Inc( CPit );
			if P^.SubCom <> Nil then SubComScan( P^.SubCom );
			P := P^.Next;
		end;
	end;
begin
	{ Count the number of body modules. }
	{ ASSERT: All level one subcomponents will be modules, and }
	{  if a body module is found it will be of the correct size. }
	{  The range checker, called before this procedure, should have }
	{  dealt with that already. }
	S := it^.SubCom;
	Body := 0;
	while S <> Nil do begin
		if ( S^.G = GG_Module ) and ( S^.S = GS_Body ) then begin
			Inc( Body );
			if Body = 1 then begin
				{ Check for the engine. If no engine, install one. }
				SG := S^.SubCom;
				while ( SG <> Nil ) and (( SG^.G <> GG_Support ) or ( SG^.S <> GS_Engine )) do SG := SG^.Next;
				if SG = Nil then begin
					{ Add an engine here. }
					SG := NewGear( S );
					SG^.G := GG_Support;
					SG^.S := GS_Engine;
					SG^.V := S^.V;
					InitGear( SG );
					InsertSubCom( S , SG );
				end;

				{ Check for the gyro. If no gyro, install one. }
				SG := S^.SubCom;
				while ( SG <> Nil ) and (( SG^.G <> GG_Support ) or ( SG^.S <> GS_Gyro )) do SG := SG^.Next;
				if SG = Nil then begin
					{ Add an engine here. }
					SG := NewGear( S );
					SG^.G := GG_Support;
					SG^.S := GS_Gyro;
					SG^.V := 1;
					InitGear( SG );
					InsertSubCom( S , SG );
				end;
			end;
		end;
		S := S^.Next;
	end;
	if Body <> 1 then begin
		it^.G := GG_AbsolutelyNothing;
	end;

	{ Make sure the mecha has exactly one cockpit. }
	CPit := 0;
	SubComScan( it^.SubCom );
	if CPit <> 1 then begin
		it^.G := GG_AbsolutelyNothing;
	end;
end;

Procedure MetricScan( var head: GearPtr );
	{ Scan all the parts, looking for parts which need some counting done. }
var
	P,P2: GEarPtr;
begin
	P := Head;
	while P <> Nil do begin
		P2 := P^.Next;

		{Perform specific checks here.}
		if P^.G = GG_Mecha then CheckMechaMetrics( P );

		{ After the above checking, this gear might be marked for }
		{ deletion. If so, delete it. }
		if P^.G = GG_AbsolutelyNothing then begin
			RemoveGear( Head , P );
		end else begin
			if P^.SubCom <> Nil then MetricScan(P^.SubCom);
			if P^.InvCom <> Nil then MetricScan(P^.InvCom);
		end;
		P := P2;
	end;

end;

Procedure CheckValidity( var it: GearPtr );
	{Check the gears that have just been loaded and make sure}
	{that they conform to the game rules. To do this, we will}
	{scan through every gear in the list, recursing to this}
	{procedure as necessary.}
begin
	{ Do the individual components check. }
	ComponentScan( it );

	{ Do the metrics check for specific components. }
	MetricScan( it );
end;

Procedure ApplyCharDesc( NPC: GearPtr; CDesc: String );
	{ Apply a character description string to this NPC. The character description }
	{ string can contain all kinds of info: personality traits, gender, etc. }
var
	CCD_Cmd: String;	{ Command extracted from line. }
	t: Integer;
begin
	{ Error check! This command only works for characters. }
	if ( NPC = Nil ) or ( NPC^.G <> GG_Character ) then Exit;

	while CDesc <> '' do begin
		CCD_Cmd := ExtractWord( CDesc );

		{ Check to see if this is a gender command. }
		for t := 0 to 1 do begin
			if CCD_Cmd = UpCase( MsgString( 'GenderName_' + BStr( T ) ) ) then begin
				SetNAtt( NPC^.NA , NAG_CharDescription , NAS_Gender , T );
			end;
		end;

		{ If not, check to see if it's a personality command. }
		for t := 1 to Num_Personality_Traits do begin
			if CCD_Cmd = UpCase( MsgString( 'TRAITNAME_' + BStr( T ) + '_+' ) ) then begin
				if NAttValue( NPC^.NA , NAG_CharDescription , -T ) < 50 then begin
					SetNAtt( NPC^.NA , NAG_CharDescription , -T , 50 );
				end else begin
					AddNAtt( NPC^.NA , NAG_CharDescription , -T , 10 );
				end;
			end else if CCD_Cmd = UpCase( MsgString( 'TRAITNAME_' + BStr( T ) + '_-' ) ) then begin
				if NAttValue( NPC^.NA , NAG_CharDescription , -T ) > -50 then begin
					SetNAtt( NPC^.NA , NAG_CharDescription , -T , -50 );
				end else begin
					AddNAtt( NPC^.NA , NAG_CharDescription , -T , -10 );
				end;
			end;
		end;

		{ If not, check to see if it's an age command. }
		if CCD_Cmd = 'YOUNG' then begin
			{ Set the character's age to something below 20. }
			while NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) >= 0 do begin
				AddNAtt( NPC^.NA , NAG_CharDescription , NAS_DAge , -( Random( 6 ) + 1 ) );
			end;
		end else if CCD_Cmd = 'OLD' then begin
			{ Set the character's age to something above 40. }
			while NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) <= 20 do begin
				AddNAtt( NPC^.NA , NAG_CharDescription , NAS_DAge , ( Random( 15 ) + RollStep( 5 ) ) );
			end;

		end else if CCD_Cmd = 'PCFRIEND' then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_Friend );
		end else if CCD_Cmd = 'PCFAMILY' then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_Family );
		end else if CCD_Cmd = 'PCLOVER' then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_Lover );
		end else if CCD_Cmd = 'PCENEMY' then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_ArchEnemy );

		end;
	end;

end;

Function ReadGear( var F: Text; RandomizeNPCs: Boolean ): GearPtr;
	{F is an open file of type F.}
	{Start reading information from the file, stopping}
	{whenever all the info is read.}
	{ Note that the current implementation of this procedure contracts }
	{ out all validity checking to the CheckGearRange procedure }
	{ in gearutil.pp. }
const
	NDum: GearPtr = Nil;
var
	TheLine,cmd: String;
	it,C: GearPtr;	{IT is the total list which is returned.}
			{C is the current GEAR being worked on.}
	dest: Byte;	{DESTination of the next GEAR to be added.}
			{ 0 = Sibling; 1 = SubCom; 2 = InvCom }

{*** LOCAL PROCEDURES FOR GHPARSER ***}

Procedure InstallGear(IG_G,IG_S,IG_V: Integer);
	{Install a GEAR of the specified type in the currently}
	{selected installation location. }
begin
	{Determine where the GEAR is to be installed, and check to}
	{see if this is a legal place to stick it.}

	{Do the installing}
	{if C = Nil, we're installing as a sibling at the root level.}
	{ASSERT: If IT = Nil, then C = Nil as well.}
	if (dest = 0) or (C = Nil) then begin
		{NEXT COMPONENT}
		if C = Nil then C := AddGear(it,NDum)
		else C := AddGear(C,C^.Parent);

	end else if dest = 1 then begin
		{SUB COMPONENT}
		C := AddGear(C^.SubCom,C);
		dest := SLOT_Next;
	end else if dest = 2 then begin
		{INV COMPONENT}
		C := AddGear(C^.InvCom,C);
		dest := SLOT_Next;
	end;

	C^.G := IG_G;
	C^.S := IG_S;
	C^.V := IG_V;
	InitGear(C);
end;

Procedure AssignStat( AS_Slot, AS_Val: Integer );
	{ Set stat SLOT of the current gear to value VAL. }
	{ Do nothing if there's some reason why this is impossible. }
begin
	{ Can only assign a stat if the current gear is defined. }
	if C <> Nil then begin
		{ Make sure NUM is in the allowable range. }
		if ( AS_Slot >= 1 ) and ( AS_Slot <= NumGearStats ) then begin
			C^.Stat[ AS_Slot ] := AS_Val;
		end;
	end;
end;

Procedure AssignNAtt( ANA_G, ANA_S, ANA_V: LongInt );
	{ Store the described numeric attribute in the current gear. }
	{ Do nothing if there's some reason why this is impossible. }
begin
	{ Can only store info if the current gear is defined. }
	if C <> Nil then begin
		SetNAtt( C^.NA , ANA_G , ANA_S , ANA_V );
	end;
end;

Procedure CheckMacros( CM_CMD: String );
	{ This command wasn't found in the list of basic commands. }
	{ Maybe it's part of the macro file? Check and see. }
	Function GetMacroValue( var GMV_FX: String ): LongInt;
		{ Extract a value from the macro string, or read it }
		{ from the current line. }
	var
		GMV_MacDat,GMV_LineDat: String;
	begin
		{ First, read the data definition. }
		GMV_MacDat := ExtractWord( GMV_FX );

		{ If the first character is a ?, this means that we should }
		{ read the value from the regular line. }
		if ( GMV_MacDat <> '' ) and ( GMV_MacDat[1] = '?' ) then begin
			{ If the data is found, return it. }
			{ Otherwise return the macro default value. }
			GMV_LineDat := ExtractWord( TheLine );
			if GMV_LineDat <> '' then begin
				GetMacroValue := ExtractValue( GMV_LineDat );
			end else begin
				DeleteFirstChar( GMV_MacDat );
				GetMacroValue := ExtractValue( GMV_MacDat );
			end;
		end else begin
			GetMacroValue := ExtractValue( GMV_MacDat );
		end;
	end;
var
	CM_FX: String;
	CM_A, CM_B, CM_C: LongInt;
begin
	CM_FX := SAttValue( Parser_Macros , CM_CMD );

	{ If a macro matching this command was found, process it. }
	if CM_FX <> '' then begin
		CM_CMD := UpCase( ExtractWord( CM_FX ) );

		if CM_CMD[1] = 'G' then begin
			{ Gear Macro }
			CM_A := GetMacroValue( CM_FX );
			CM_B := GetMacroValue( CM_FX );
			CM_C := GetMacroValue( CM_FX );
			InstallGear( CM_A , CM_B , CM_C );

		end else if CM_CMD[1] = 'S' then begin
			{ Stat Macro }
			CM_A := GetMacroValue( CM_FX );
			CM_B := GetMacroValue( CM_FX );
			AssignStat( CM_A , CM_B );

		end else if CM_CMD[1] = 'N' then begin
			{ NAtt Macro }
			CM_A := GetMacroValue( CM_FX );
			CM_B := GetMacroValue( CM_FX );
			CM_C := GetMacroValue( CM_FX );
			AssignNAtt( CM_A , CM_B , CM_C );

		end else if CM_CMD[1] = 'M' then begin
			{ MODULE Macro }
			CM_A := GetMacroValue( CM_FX );
			InstallGear( GG_Module , CM_A , MasterSize( C ) );

		end;
	end;
end;

Procedure CMD_Sub;
	{Set the destination to SUBCOMPONENT}
begin
	dest := SLOT_Sub;
end;

Procedure CMD_Inv;
	{Set the destination to INVCOMPONENT}
begin
	dest := SLOT_Inv;
end;

Procedure CMD_End;
	{Finish off a range of subcomponents.}
	{If Dest = 0, move to the parent gear.}
	{If Dest <> 0, set Dest to 0.}
begin
	if (dest = 0) and (C <> Nil) then C := C^.Parent
	else dest := 0;
end;


Procedure CMD_Size;
	{Set the V field of the current module to the supplied value.}
var
	CS_Size: Integer;
begin
	CS_Size := ExtractValue(TheLine);

	if C <> Nil then C^.V := CS_Size;
end;

Procedure CMD_Arch;
	{Create a new archetypal character gear.}
	{ The rest of this line is the name of the new archetype. }
begin
	InstallGear(GG_Character,0,0);
	DeleteWhiteSpace( TheLine );
	SetSAtt( C^.SA , 'Name <' + TheLine + '>' );
	TheLine := '';
end;

Procedure CMD_StatLine;
	{ Read all the stats for this gear from a single line. }
var
	CSL_N,CSL_V: Integer;
begin
	{ Error Check! }
	if C = Nil then Exit;

	CSL_N := 1;
	while ( TheLine <> '' ) and ( CSL_N <= NumGearStats ) do begin
		CSL_V := ExtractValue( TheLine );
		C^.Stat[CSL_N] := CSL_V;
		Inc( CSL_N );
	end;
end;

Procedure CMD_SetAlly;
	{ Read this team's allies from the line. }
var
	CSA_AllyID: Integer;
begin
	if ( C = Nil ) then Exit;

	while ( TheLine <> '' ) do begin
		CSA_AllyID := ExtractValue( TheLine );
		if C^.G = GG_Faction then begin
			SetNAtt( C^.NA , NAG_FactionScore , CSA_AllyID , 10 );
		end else begin
			SetNAtt( C^.NA , NAG_SideReaction , CSA_AllyID , NAV_AreAllies );
		end;
	end;
end;

Procedure CMD_SetEnemy;
	{ Read this team's enemies from the line. }
var
	CSE_EnemyID: Integer;
begin
	if ( C = Nil ) then Exit;

	while ( TheLine <> '' ) do begin
		CSE_EnemyID := ExtractValue( TheLine );
		if C^.G = GG_Faction then begin
			AddNAtt( C^.NA , NAG_FactionScore , CSE_EnemyID , -10 );
		end else begin
			SetNAtt( C^.NA , NAG_SideReaction , CSE_EnemyID , NAV_AreEnemies );
		end;
	end;
end;

Procedure META_InsertPartIntoIt( IPII_Part: GEarPtr );
	{ Insert a part into the current gear-being-loaded by the }
	{ method specified in the dest variable. Afterwards, set C }
	{ to equal this new part. }
begin
	if IPII_Part <> Nil then begin
		{ Stick the part somewhere appropriate. }
		if (dest = 0) or (C = Nil) then begin
			{NEXT COMPONENT}
			{ If there is no currently defined C component, }
			{ stick the NPC as the next component at root level. }
			if C = Nil then LastGear( it )^.Next := IPII_Part
			else begin
				LastGear( C )^.Next := IPII_Part;
				IPII_Part^.Parent := C^.Parent;
			end;
		end else if dest = 1 then begin
			{SUB COMPONENT}
			InsertSubCom( C , IPII_Part );
		end else if dest = 2 then begin
			{INV COMPONENT}
			InsertInvCom( C , IPII_Part );
		end;
		dest := SLOT_Next;

		{ Set the current gear to the item's base record. }
		{ Any further modifications will be done there. }
		C := IPII_Part;
	end;
end;

Procedure CMD_NPC;
	{ Search for & then duplicate one of the standard character }
	{ archetypes, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	NPC: GearPtr;
begin
	{ NPC cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the NPC record first. }
	{ Exit the procedure if no appropriate NPC can be found. }
	DeleteWhiteSpace( TheLine );

	{ Note that this procedure doesn't randomize the NPCs itself- that }
	{ will have to wait for the second pass which will randomize all NPCs }
	{ together. }
	NPC := LoadNewNPC( TheLine , False );
	if NPC = Nil then begin
		Exit;
	end;

	{ Get rid of the NPC name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the NPC somewhere appropriate. }
	META_InsertPartIntoIt( NPC );
end;

Procedure CMD_Monster;
	{ Search for & then duplicate one of the standard monster }
	{ archetypes, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	Mon: GearPtr;
begin
	{ Monster cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the Monster record first. }
	{ Exit the procedure if no appropriate NPC can be found. }
	DeleteWhiteSpace( TheLine );
	Mon := LoadNewMonster( TheLine );
	if Mon = Nil then begin
		Exit;
	end;

	{ Get rid of the NPC name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the monster somewhere appropriate. }
	META_InsertPartIntoIt( Mon );
end;

Procedure CMD_STC;
	{ Search for & then duplicate one of the standard item }
	{ archetypes, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	STC_Part: GearPtr;
begin
	{ Item cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the item record first. }
	{ Exit the procedure if no appropriate item can be found. }
	DeleteWhiteSpace( TheLine );
	STC_Part := LoadNewSTC( TheLine );
	if STC_Part = Nil then begin
		Exit;
	end;

	{ Get rid of the item name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the item somewhere appropriate. }
	META_InsertPartIntoIt( STC_Part );
end;

Procedure CMD_Scale;
	{ Sets the scale field for the current gear. }
var
	CS_Scale: Integer;
begin
	{ Error check- if there is no current gear, exit this procedure. }
	if ( C = Nil ) then Exit;

	{ Determine what scale to set the current gear to. }
	CS_Scale := ExtractValue( TheLine );

	C^.Scale := CS_Scale;
end;

Procedure CMD_Set_ID;
	{ Sets the "S" descriptor of this gear. Since this gear has already likely been }
	{ initialized, this can be a bad thing to do... use "SetID" only on virtual gear types }
	{ like personas, metascenes, and so on. }
var
	CS_S: Integer;
begin
	{ Error check- if there is no current gear, exit this procedure. }
	if ( C = Nil ) then Exit;

	{ Determine what scale to set the current gear to. }
	CS_S := ExtractValue( TheLine );

	C^.S := CS_S;
end;

Procedure CMD_CharDesc;
	{ This procedure allows certain aspects of a character gear to be }
	{ modified. }
begin
	{ Call the character description procedure above, then clear the line }
	{ to make sure it's not interpreted as a command sequence. }
	ApplyCharDesc( C , TheLine );
	TheLine := '';
end;

Procedure GoIndividualize( LList: GearPtr );
	{ Individualize any NPCs found along this list or in the children of it. }
begin
	while LList <> Nil do begin
		if LList^.G = GG_Character then IndividualizeNPC( LList );
		GoIndividualize( LList^.SubCom );
		GoIndividualize( LList^.InvCom );
		LList := LList^.Next;
	end;
end;

begin
	{ Initialize variables. }
	it := Nil;
	C := Nil;
	dest := SLOT_Next;

	{ Increase the recursion level; the NPC command uses recursion }
	{ and could get stuck in an endless loop. }
	Inc( Recursion_Level );

	while not EoF(F) do begin
		{Read the line from disk, and delete leading whitespace.}
		readln(F,TheLine);
		DeleteWhiteSpace(TheLine);

		if ( TheLine = '' ) or ( TheLine[1] = '%' ) then begin
			{ *** COMMENT *** }
			TheLine := '';

		end else if Pos('<',TheLine) > 0 then begin
			{ *** STRING ATTRIBUTE *** }
			if C <> Nil then SetSAtt(C^.SA,TheLine);

		end else begin
			{ *** COMMAND LINE *** }

			{To make things easier upon us, just set the whole}
			{line to uppercase now.}
			TheLine := UpCase(TheLine);

			{Keep processing the line until the end is reached.}
			while TheLine <> '' do begin
				CMD := ExtractWord(TheLine);

				{Branch depending upon what the command is.}
					if CMD = 'SUB' then CMD_Sub
				else	if CMD = 'INV' then CMD_Inv
				else	if CMD = 'END' then CMD_End
				else	if CMD = 'SIZE' then CMD_Size
				else	if CMD = 'SETID' then CMD_Set_ID
				else	if CMD = 'ARCH' then CMD_Arch
				else	if CMD = 'STATLINE' then CMD_StatLine
				else	if CMD = 'SETALLY' then CMD_SetAlly
				else	if CMD = 'SETENEMY' then CMD_SetEnemy
				else	if CMD = 'NPC' then CMD_NPC
				else	if CMD = 'SCALE' then CMD_Scale
				else	if CMD = 'CHARDESC' then CMD_CharDesc
				else	if CMD = 'MONSTER' then CMD_Monster
				else	if CMD = 'STC' then CMD_STC
				else	CheckMacros( CmD );
			end;
		end;
	end;

	{ If the NPCs are to be randomized, do that now. Why not do it at the }
	{ point when they're loaded? Because they can still be modified by other }
	{ commands, that's why. Imagine you create a NPC, then set its faction. }
	{ if the individualization were done directly at the moment of creation, }
	{ then the individualization procedure wouldn't know the NPC's faction. }
	{ This would be bad. So, we do individualization as an extra step at the end. }
	if RandomizeNPCs then GoIndividualize( it );

	{Run a check on each of the Master Gears we have loaded,}
	{making sure that they are both valid and complete. If}
	{there are any errors, remove the offending entries.}
	{ See TheRules.txt for a brief outline of things to be checked. }
	CheckValidity(it);

	{ Decrement the recursion level. }
	Dec( Recursion_Level );

	ReadGear := it;
end; { ReadGear }

Function LoadFile( FName,DName: String ): GearPtr;
	{ Open and load a text file. }
var
	F: Text;
	it: GearPtr;
begin
	{ Use FSEARCH to confirm the file name. }
	FName := FSearch( FName , DName );
	it := Nil;
	if FName <> '' then begin
		{ The filename has been found and confirmed. }
		{ Actually load the file. }
		Assign( F , FName );
		Reset( F );
		it := ReadGear( F , True );
		Close( F );
	end;
	LoadFile := it;
end;

Function LoadFile( FName: String ): GearPtr;
	{ Open and load a text file. }
begin
	LoadFile := LoadFile( FName , '.' );
end;

Function LoadGearPattern( FName,DName: String ): GearPtr;
	{ Attempt to load a gear file from disk. Search for }
	{ pattern matches. }
var
	FList: SAttPtr;
	it: GearPtr;
begin
	it := Nil;
	if FName <> '' then begin
		{ Build search list for files that match the source. }
		FList := CreateFileList( DName + FName );

		if FList <> Nil then begin
			FName := SelectRandomSAtt( FList )^.Info;
			DisposeSAtt( FList );

			it := LoadFile( FName , DName );
		end;
	end;

	{ Return the selected & loaded gears. }
	LoadGearPattern := it;
end;

Function AggregatePattern( FName,DName: String ): GearPtr;
	{ Search for the given pattern. Then, load all files that match }
	{ the pattern and concatenate them together. Did I spell that }
	{ right? Probably not. }
var
	FList,F: SAttPtr;
	part,it: GearPtr;
begin
	it := Nil;
	if FName <> '' then begin
		{ Build search list for files that match the pattern. }
		FList := CreateFileList( DName + FName );
		F := FList;

		while F <> Nil do begin
			part := LoadFile( F^.Info , DName );
			AppendGear( it , part );
			F := F^.Next;
		end;
		DisposeSAtt( FList );
	end;

	{ Return the selected & loaded gears. }
	AggregatePattern := it;
end;

Function LoadRandomSceneContent( FName,DName: String ): GearPtr;
	{ Search for the given pattern. Then, load all files that match }
	{ the pattern and concatenate them together. Don't randomize NPCs; }
	{ that will be done later. }
var
	FList,F: SAttPtr;
	part,it: GearPtr;
	InFile: Text;
begin
	it := Nil;
	if FName <> '' then begin
		{ Build search list for files that match the pattern. }
		FList := CreateFileList( DName + FName );
		F := FList;

		while F <> Nil do begin
			Assign( InFile , DName + F^.Info );
			Reset( InFile );
			part := ReadGear( InFile , False );
			Close( InFile );

			AppendGear( it , part );
			F := F^.Next;
		end;
		DisposeSAtt( FList );

	end;

	{ Return the selected & loaded gears. }
	LoadRandomSceneContent := it;
end;


Function LoadSingleMecha( FName,DName: String ): GearPtr;
	{ Load a mecha file. Return a single mecha from that file. }
	{ Return Nil if the mecha could not be loaded. }
var
	MList,Mek: GearPtr;
begin
	{ Use the above procedure to load a mecha from disk. }
	MList := LoadGearPattern( FName , DName );
	Mek := Nil;

	if MList <> Nil then begin
		Mek := CloneGear( SelectRandomGear( MList ) );
		DisposeGear( MList );
	end;

	LoadSingleMecha := Mek;
end;

Function LoadNamedGear( FName,GName: String ): GearPtr;
	{ This function will load a file with the given file name. }
	{ Once that is loaded, it will search for a single gear within }
	{ that file with the given gear name. }
var
	F: Text;
	G,LList: GearPtr;
begin
	{ Open and load the archetypes. }
	Assign( F , FName );
	Reset( F );
	LList := ReadGear( F , True );
	Close( F );

	{ Locate the desired archetype. }
	G := SeekGearByName( LList , GName );
	if G <> Nil then G := CloneGear( G );

	{ Dispose of the list & return the cloned gear. }
	DisposeGear( LList );
	LoadNamedGear := G;
end;


Function LoadNewMonster( MonsterName: String ): GearPtr;
	{ This function will load the default monster list and }
	{ return a monster of the requested type. }
var
	Mon: GearPtr;
begin
	{ Load monster from disk. }
	if WMonList <> Nil then begin
		Mon := CloneGear( SeekGearByName( WMonList , MonsterName ) );
	end else begin
		Mon := Nil;
	end;

	{ If it loaded successfully, set its job to "ANIMAL". }
	if Mon <> Nil then begin
		SetSATt( Mon^.SA , 'JOB <ANIMAL>' );
	end;

	{ Return whatever value was returned. }
	LoadNewMonster := Mon;
end;

Function LoadNewNPC( NPCName: String; RandomizeNPCs: Boolean ): GearPtr;
	{ This function will load the NPC archetypes list and }
	{ return a character of the requested type. }
var
	NPC: GearPtr;
begin
	{ Attempt to load the NPC from the standard archetypes file. }
	if Archetypes_List = Nil then begin
		NPC := LoadNamedGear( Archetypes_File , NPCName );
	end else begin
		NPC := CloneGear( SeekGearByName( Archetypes_List , NPCName ) );
	end;

	{ If the NPC was loaded, set its job name and individualize it. }
	if NPC <> Nil then begin
		{ Store a JOB description. This will be the archetype name. }
		SetSATt( NPC^.SA , 'JOB <' + NPCName + '>' );
		SetSAtt( NPC^.SA , 'NAME <>' );

		if RandomizeNPCs then IndividualizeNPC( NPC );
	end;

	{ Return the finished product. }
	LoadNewNPC := NPC;
end;

Function LoadNewSTC( Desig: String ): GearPtr;
	{ This function will load the STC parts list and }
	{ return an item of the requested type. }
var
	Item: GearPtr;
begin
	{ Attempt to load the item from the standard items file. }
	if STC_Item_List = Nil then Exit( Nil );

	Item := CloneGear( SeekGearByDesig( STC_Item_List , Desig ) );

	{ Return the finished product. }
	LoadNewSTC := Item;
end;

Procedure LoadArchetypes;
	{ Load the default, archetypal gears which may be used in the }
	{ construction of other gears. This includes NPC archetypes and }
	{ so forth. }
var
	F: Text;
begin
	{ Open and load the archetypes. }
	Assign( F , Archetypes_File );
	Reset( F );
	Archetypes_List := ReadGear( F , False );
	Close( F );

	Assign( F , STC_Item_File );
	Reset( F );
	STC_Item_List := ReadGear( F , True );
	Close( F );
end;

Procedure RandomLoot( Box: GearPtr; SRP: LongInt; const l_type,l_factions: String );
	{ Fill BOX with SRV (suggested retail price) worth of junk from the standard }
	{ equipment files. }
	Function ItemIsLegal( I: GearPtr ): Boolean;
		{ Return TRUE if I's type and factions match those requested, or }
		{ FALSE otherwise. Oh, I should also be a legal invcom of BOX. }
	begin
		ItemIsLegal := PartAtLeastOneMatch( l_type , SAttValue( I^.SA , 'CATEGORY' ) ) and PartAtLeastOneMatch( l_factions , SAttValue( I^.SA , 'FACTIONS' ) ) and IsLegalInvCom( Box , I );
	end;
	Function RLWeight( Cost,MIC: LongInt ): LongInt;
		{ Return the chance of this item being selected. }
	begin
		if Cost < ( MIC div 4 ) then begin
			RLWeight := 1;
		end else begin
			RLWeight := Cost;
		end;
	end;
	Function SelectAnItem: GearPtr;
		{ Select an appropriate item from the standard items list. }
	var
		Total: Int64;
		MIC,Cost: LongInt;
		I,Selected_Item: GearPtr;
	begin
		Selected_Item := Nil;
		{ Calculate Max Item Cost }
		MIC := ( SRP * 3 ) div 2;
		if MIC < ( SRP + 1000 ) then MIC := SRP + 1000;

		{ Start by finding the total cost of all legal items. }
		I := Standard_Equipment_List;
		Total := 0;
		while I <> Nil do begin
			if ItemIsLegal( I ) then begin
				Cost := GearValue( I );
{				if Cost < MIC then Total := Total + ( Cost * Cost );}
				if Cost < MIC then Total := Total + RLWeight( Cost , MIC );
			end;
			I := I^.Next;
		end;

		{ If no items found, exit NIL. }
		if Total < 1 then Exit( Nil );

		{ Next, go through the list again, selecting one at random. }
		I := Standard_Equipment_List;
		Total := Random( Total );
		while ( I <> Nil ) and ( Selected_Item = Nil ) do begin
			if ItemIsLegal( I ) then begin
				Cost := GearValue( I );
				if Cost < MIC then begin
					Total := Total - RLWeight( Cost , MIC );
					if Total < 1 then Selected_Item := I;
				end;
			end;
			I := I^.Next;
		end;

		SelectAnItem := CloneGear( I );
	end;
var
	Item: GearPtr;
begin
	{ Keep processing until we run out of money or objects. }
	while SRP > 0 do begin
		Item := SelectAnItem;
		if Item <> Nil then begin
			SRP := SRP - GearValue( Item );
			InsertInvCom( Box , Item );
		end else begin
			{ No item found. Set SRP to 0. }
			SRP := 0;
		end;
	end;
end;

initialization
	Parser_Macros := LoadStringList( Parser_Macro_File );
	WMonList := AggregatePattern( Monsters_File_Pattern , Series_Directory );
	Standard_Equipment_List := AggregatePattern( PC_Equipment_Pattern , Design_Directory );

	LoadArchetypes;

	Factions_List := AggregatePattern( 'FACTIONS_*.txt' , Series_Directory );
	Mecha_Theme_List := AggregatePattern( 'THEME_*.txt' , Series_Directory );

finalization
	DisposeSAtt( Parser_Macros );
	DisposeGear( Archetypes_List );
	DisposeGear( WMonList );
	DisposeGear( Standard_Equipment_List );
	DisposeGear( STC_Item_List );
	DisposeGear( Factions_List );
	DisposeGear( Mecha_Theme_List );

end.
