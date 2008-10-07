unit arenaplay;
	{ This unit holds the combat loop for Arena. }
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

Const
	SATT_Artifact = 'ARTIFACT';

Procedure CombatMain( Camp: CampaignPtr );
Function ScenePlayer( Camp: CampaignPtr ; Scene: GearPtr; var PCForces: GearPtr ): Integer;

implementation

{$IFDEF ASCII}
uses ability,aibrain,arenacfe,arenascript,backpack,gearutil,ghmodule,ghholder,
     ghchars,ghprop,ghweapon,grabgear,menugear,movement,pcaction,
     playwright,randmaps,rpgdice,skilluse,texutil,ui4gh,wmonster,
     vidmap,vidgfx,action,narration,gearparser,customization;
{$ELSE}
uses ability,aibrain,arenacfe,arenascript,backpack,gearutil,ghmodule,ghholder,
     ghchars,ghprop,ghweapon,grabgear,menugear,movement,pcaction,
     playwright,randmaps,rpgdice,skilluse,texutil,ui4gh,wmonster,
     glmap,glgfx,action,narration,gearparser,customization;
{$ENDIF}
const
	DEBUG_ON: Boolean = False;

Procedure SelectEquipmentForNPC( GB: GameBoardPtr; NPC: GearPtr; Renown: Integer );
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
				if NAttValue( I2^.NA , NAG_Narrative , NAS_IsRandomEquipment ) <> 0 then begin
					RemoveGear( Slot^.InvCom , I2 );
				end else begin
					DelinkGear( Slot^.InvCom , I2 );
					InsertInvCom( NPC , I2 );
				end;
			end;
			I2 := I3;
		end;

		{ Mark ITEM as being generated randomly. }
		SetNAtt( Item^.NA , NAG_Narrative , NAS_IsRandomEquipment , 1 );

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
		if Item <> Nil then EquipItem( Slot , Item )
		else DialogMsg( 'Couldn''t generate item for ' + GearName( Slot ) + '/' + GearName( NPC ) + ', $' + BStr( MaxValue ) );
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
			Best_Value := 0;
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
const
	Min_Spending_Limit = 2500;
var
	Fac,Scene: GearPtr;
begin
	{ Initialize the values. }
	Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
	Faction_Desc := 'GENERAL ';
	if Fac <> Nil then Faction_Desc := Faction_Desc + SAttValue( Fac^.SA , 'DESIG' );
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Scene := FindRootScene( GB , GB^.Scene );
		if Scene <> Nil then begin
			Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( Scene^.NA , NAG_Personal , NAS_FactionID ) );
			if Fac <> Nil then Faction_Desc := Faction_Desc + ' ' + SAttValue( Fac^.SA , 'DESIG' );
		end;
	end;

	if Renown < 10 then Renown := 10;
	Spending_Limit := Calculate_Threat_Points( Renown , 1 );
	if Spending_Limit < Min_Spending_Limit then Spending_Limit := Min_Spending_Limit;

	Legality_Limit := -NAttValue( NPC^.NA , NAG_CharDescription , NAS_Lawful );
	if Legality_Limit < 10 then Legality_Limit := 10;

	{ Unlike the previous, this will split things into several separate parts. }
	BuyArmorForNPC();

	{ Purchase some weapons. }
	BuyWeaponsForNPC();
end;


Procedure ProcessMovement( GB: GameBoardPtr; Mek: GearPtr );
	{ Call the LOCALE movement routine, then update the display }
	{ here if need be. }
var
	result,Team: Integer;
begin
	{ Call the movement procedure, and store the result. }
	result := EnactMovement( GB , Mek );

	{ Depending upon what happened, update the display. }
	if result > 0 then begin
		{ Check for previously unseen enemies. }
		if OnTheMap( GB , NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) ) then VisionCheck( GB , Mek )
		{ Print message if mek has fled the battle. }
		else begin
			DialogMSG( PilotName( Mek ) + ' has left this area.');

			{ Set trigger here. }
			Team := NAttValue( Mek^.NA , NAG_Location , NAS_Team );
			SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( Team ) );
			SetTrigger( GB , TRIGGER_UnitEliminated + BStr( NAttValue( Mek^.NA , NAG_EpisodeData , NAS_UID ) ) );
		end;

		{ Check for charges and crashes. }
		ResolveAfterEffects( GB );
	end;
end;

Function Confused( Mek: GearPtr ): Boolean;
	{ Return true if either the pilot or the mecha is either }
	{ HAYWIRE or STONED. }
var
	Pilot: GearPtr;
begin
	if Mek^.G = GG_Mecha then begin
		Pilot := LocatePilot( Mek );
	end else begin
		Pilot := Nil;
	end;

	Confused := HasStatus( Mek , NAS_Haywire ) or HasStatus( Mek , NAS_Stoned ) or HasStatus( Pilot , NAS_Haywire ) or HasStatus( Pilot , NAS_Stoned );
end;

Procedure GetMekInput( Mek: GearPtr; Camp: CampaignPtr; ControlByPlayer: Boolean );
	{ Decide what the mek in question is gonna do next. }
begin
	{ This procedure has to branch depending upon whether we have a }
	{ player controlled mek or a computer controlled mek. }

	{ Branch the first - If this mecha has a HAYWIRE status effect }
	{ it may move randomly 50% of the time. }
	if Confused( Mek ) and ( Random( 2 ) = 1 ) then begin
		ConfusedInput( Mek , Camp^.GB );

	end else if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = 1 ) or ControlByPlayer then begin
		{ It's a player mek. }
{$IFDEF ASCII}
		FocusOn( Mek );
{$ENDIF}
		GetPlayerInput( Mek , Camp );
	end else begin
		{ it's a computer mek. }
		GetAIInput( Mek , Camp^.GB );
	end;
end;

Procedure CheckMapScroll( GB: GameBoardPtr );
	{ Space maps don't have well defined borders. If everyone moves over to one side }
	{ of the map, the entire map contents will shift to try and center things. }
	Function IsActiveParticipant( Part: GearPtr ): Boolean;
		{ Return TRUE if PART is an active participant in the battle for }
		{ purposes of map scrolling. }
	begin
{		if ( Part^.G = GG_Prop ) then begin
			IsActiveParticipant := GearOperational( Part );
		end else begin}
			IsActiveParticipant := GearActive( Part );
{		end;}
	end;
	Function GetDelta( axis,a,b: Integer ): Integer;
		{ Determine whether or not the map should be scrolled along this }
		{ axis, and if so in what direction. }
		{ A is the boundary of the "low zone", B is the boundary of the "high zone". }
		{ If one zone is occupied and the other isn't, scroll the map in that direction. }
	var
		M: GearPtr;
		Low_Zone_Occupied,High_Zone_Occupied: Boolean;
		P: Integer;
	begin
		M := GB^.Meks;
		Low_Zone_Occupied := False;
		High_Zone_Occupied := False;
		while ( M <> Nil ) and not ( Low_Zone_Occupied and High_Zone_Occupied ) do begin
			if OnTheMap( GB , M ) and IsActiveParticipant( M ) then begin
				P := NAttValue( M^.NA , NAG_Location , Axis );
				if P < A then Low_Zone_Occupied := True
				else if P > B then High_Zone_Occupied := True;
			end;
			M := M^.Next;
		end;
		if Low_Zone_Occupied and not High_Zone_Occupied then GetDelta := -1
		else if High_Zone_Occupied and not Low_Zone_Occupied then GetDelta := 1
		else GetDelta := 0;
	end;
var
	DX,DY: Integer;
	M: GearPtr;
begin
	{ Only do scrolling while there's enemies about. }
	if IsSafeArea( GB ) then Exit;

	DX := GetDelta( NAS_X , GB^.map_width div 3 + 1 , GB^.map_width * 2 div 3 );
	DY := GetDelta( NAS_Y , GB^.map_height div 3 + 1 , GB^.map_height * 2 div 3 );
	if ( DX = 0 ) and ( DY = 0 ) then Exit;

	M := GB^.Meks;
	while M <> Nil do begin
		if OnTheMap( GB , M ) then begin
			AddNAtt( M^.NA , NAG_Location , NAS_X , -DX );
			AddNAtt( M^.NA , NAG_Location , NAS_Y , -DY );
		end;

		M := M^.Next;
	end;
end;

Procedure CheckMeks( Camp: CampaignPtr );
	{ Check through all the meks in this scenario. If it's time }
	{ for one to move according to its ETA, call the movement }
	{ procedure. }
var
	M: GearPtr;
	ETA: LongInt;
	PCMoved,PCActed: Boolean;
	PC: GearPtr;
begin
	M := Camp^.GB^.meks;
	PCMoved := False;
	PCActed := False;
	PC := Nil;

	while M <> Nil do begin
		{ If this gameboard should be exited, better stop processing meks. }
		{ We perform the check here in case some script action happening before }
		{ the first mecha moved caused this condition. }
		if not KeepPlayingSC( Camp^.GB ) then break;

		if IsMasterGear( M ) then begin
			{ Check for actions in progress. }
			if NotDestroyed( M ) and OnTheMap( Camp^.GB , M ) then begin
				ETA := NAttValue( M^.NA , NAG_Action , NAS_MoveETA );
				if ETA <= Camp^.GB^.ComTime then begin
					ProcessMovement( Camp^.GB , M );
					if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and GearActive( M ) then begin
						PC := M;
						PCMoved := True;
					end;
				end;
			end;

			{ Check for input. }
			if GearActive( M ) and OnTheMap( Camp^.GB , M ) then begin
				ETA := NAttValue( M^.NA , NAG_Action , NAS_CallTime );
				if ETA <= Camp^.GB^.ComTime then begin
					GetMekInput( M , Camp , False );
					if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then PCActed := True;
				end;

			end;

			{ Check for drift. }
			if NAttValue( M^.NA , NAG_Action , NAS_DriftSpeed ) > 0 then begin
				ETA := NAttValue( M^.NA , NAG_Action , NAS_DriftETA );
				if ETA <= Camp^.GB^.ComTime then begin
					DoDrift( Camp^.GB , M );
					if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and GearActive( M ) then begin
						PCMoved := True;
						PC := M;
					end;
				end;
			end;

		end; { if IsMasterGear then... }

		M := M^.Next;
	end;

	if PCMoved and ( PC <> Nil ) then begin
		if ( Camp^.GB^.Scene <> Nil ) and ( Camp^.GB^.Scene^.Stat[ STAT_SpaceMap ] <> 0 ) then CheckMapScroll( Camp^.GB );
		if not PCActed then begin
			FocusOn( PC );
			CombatDisplay( Camp^.GB );
			DoFLip;
		end;
	end;
end;


Procedure UniversalVisionCheck( GB: GameBoardPtr );
	{ Do a vision check for every model on the board. }
var
	M: GearPtr;
begin
	{ First, we need to make sure the shadow map is up to date. }
	UpdateShadowMap( GB );

	{ Next, go through each gear on the gameboard, doing vision checks as needed. }
	M := GB^.Meks;
	while M <> Nil do begin
		if IsMasterGear( M ) and OnTheMap( GB , M ) then VisionCheck( GB , M );
		M := M^.Next;
	end;

	{ Finally, focus on the PC. }
	M := GG_LocatePC( GB );
	if M <> Nil then FocusOn( M );
end;

Procedure CombatMain( Camp: CampaignPtr );
	{ This is the main meat-and-potatoes combat procedure. }
	{ Actually, it's pretty simple. All the difficult work is }
	{ done by the procedures it calls. }
	{ This function returns 1 if the player won, -1 if the computer }
	{ won, and 0 if the game ended in a draw. }
var
	T: String;
	FX_String,FX_Desc: String;
begin
	{ To start with, do a vision check for everyone, }
	{ then set up the display. }
	UniversalVisionCheck( Camp^.GB );
	CombatDisplay( Camp^.GB );

	{ Set the gameboard's pointer to the campaign. }
	Camp^.GB^.Camp := Camp;

	{ Get rid of the old AI pathfinding maps. }
	ClearHotMaps;

	{ Initialize the FX_Strings }
	if Camp^.GB^.Scene <> Nil then begin
		case NATtValue( Camp^.GB^.Scene^.NA , NAG_EnvironmentData , NAS_Atmosphere ) of
			NAV_Vacuum: 	begin
					FX_String := '1 DAMAGE 10 0 ArmorIgnore GasAttack NoMetal CanResist';
					FX_Desc   := MsgString( 'ENVIRO_VACUUM' );
					end;
		else 	begin
			FX_String := '';
			FX_Desc   := '';
			end;
		end;
	end else begin
		FX_String := '';
		FX_Desc   := '';
	end;

	{ Set the STARTGAME trigger, and update all props. }
	SetTrigger( Camp^.GB , TRIGGER_StartGame );
	T := 'UPDATE';
	CheckTriggerAlongPath( T , Camp^.GB , Camp^.GB^.Meks , True );

	{ Add some random monsters, if appropriate. }
	RestockRandomMonsters( Camp^.GB );

	{ Do some graphics initializing, if needed. }
{$IFNDEF ASCII}
	InitGraphicsForScene( Camp^.GB );
{$ENDIF}

	{Start main combat loop here.}
	{Keep going until there's only one side left.}
	while KeepPlayingSC( Camp^.GB ) do begin
		AdvanceGameClock( Camp^.GB , False );

		{ Once every 10 minutes, roll for random monsters. }
		if ( Camp^.GB^.ComTime mod AP_10minutes ) = 233 then RestockRandomMonsters( Camp^.GB );

		{ Once every hour, make sure the PC is still alive. }
		if ( Camp^.GB^.ComTime mod AP_Hour ) = 0 then SetTrigger( Camp^.GB , 'NU1' );

		{ Update clouds every 30 seconds. }
		if ( Camp^.GB^.ComTime mod 30 ) = 0 then BrownianMotion( Camp^.GB );

		{ Update encounters every 20 seconds. }
		if ( Camp^.GB^.ComTime mod 20 ) = 2 then HandleEncounters( Camp^.GB );

		{ Handle environmental effects every 2 minutes. }
		if ( FX_String <> '' ) and ( ( Camp^.GB^.ComTime mod 120 ) = 17 ) then MassEffectFrontEnd( Camp^.GB , FX_String , FX_Desc );

		HandleTriggers( Camp^.GB );

		CheckMeks( Camp );

		if Screen_Needs_Redraw and Thorough_Redraw then begin
			CombatDisplay( Camp^.GB );
			DoFlip;
			Screen_Needs_Redraw := False;
		end;

	{end main combat loop.}
	end;

	{ Handle the last pending triggers. }
	SetTrigger( Camp^.GB , TRIGGER_EndGame );
	HandleTriggers( Camp^.GB );
end;

Function CanTakeTurn( GB: GameBoardPtr; M: GearPtr ): Boolean;
	{ Return TRUE if M can act in this turn. }
begin
	CanTakeTurn := GearOperational( M ) and OnTheMap( GB , M );
end;

Procedure TacticsTurn( Camp: CampaignPtr; M: GearPtr; IsPlayerMek: Boolean );
	{ It's time for this mecha to act. }
	{ Give it 60 seconds in which to do everything. }
var
	CallTime,ETA: LongInt;
	BeginTime,EndTime: LongInt;
	DidBeginTurn: Boolean;
	PCMoved: Boolean;
begin
	{ Get rid of the old AI pathfinding maps. }
	ClearHotMaps;

	DidBeginTurn := False;

	BeginTime := NAttValue( Camp^.GB^.Scene^.NA , NAG_SceneData , NAS_TacticsTurnStart );
	EndTime := BeginTime + TacticsRoundLength - 1;
	Repeat
		PCMoved := False;
		{ Check for Mecha's action first. }
		ETA := NAttValue( M^.NA , NAG_Action , NAS_MoveETA );
		if ETA <= Camp^.GB^.ComTime then begin
			ProcessMovement( Camp^.GB , M );
			if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and GearActive( M ) then begin
				PCMoved := True;
			end;
		end;
		{ Check for drift. }
		if NAttValue( M^.NA , NAG_Action , NAS_DriftSpeed ) > 0 then begin
			ETA := NAttValue( M^.NA , NAG_Action , NAS_DriftETA );
			if ETA <= Camp^.GB^.ComTime then begin
				DoDrift( Camp^.GB , M );
				if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and GearActive( M ) then begin
					PCMoved := True;
				end;
			end;
		end;
		if PCMoved and ( Camp^.GB^.Scene <> Nil ) and ( Camp^.GB^.Scene^.Stat[ STAT_SpaceMap ] <> 0 ) then CheckMapScroll( Camp^.GB );

		{ Check for input. }
		CallTime := NAttValue( M^.NA , NAG_Action , NAS_CallTime );
		if ( CallTime <= Camp^.GB^.ComTime ) and CanTakeTurn( Camp^.GB , M ) then begin
			if GearOperational( M ) then begin
				if IsPlayerMek and not DidBeginTurn then begin
					BeginTurn( Camp^.GB , M );
					DidBeginTurn := True;
					Tactics_Turn_In_Progess := True;
				end;

				GetMekInput( M , Camp , IsPlayerMek );
				if ( Calltime >= NAttValue( M^.NA , NAG_Action , NAS_CallTime ) ) and not IsPlayerMek then begin
					{ This model is apparently wasting time, somehow. }
					SetNAtt( M^.NA , NAG_Action , NAS_CallTime , Camp^.GB^.ComTime + 1);
				end;
			end else begin
				SetNAtt( M^.NA , NAG_Action , NAS_CallTime , Camp^.GB^.ComTime + 60);
			end;
		end else begin
			inc( Camp^.GB^.ComTime );
		end;

		{ Handle triggers now. }
		HandleTriggers( Camp^.GB );

	until ( Camp^.GB^.ComTime >= EndTime ) or ( not OnTheMap( Camp^.GB , M ) ) or Destroyed( M ) or ( not KeepPlayingSC( Camp^.GB ) );

	{ At the end, reset the comtime. }
	Camp^.GB^.ComTime := BeginTime;

	{ Turn off the tactics turn indicators. }
	Tactics_Turn_In_Progess := False;
end;


Procedure TacticsMain( Camp: CampaignPtr );
	{ This is the main meat-and-potatoes combat procedure. }
	{ It functions as the above procedure, but a bit more strangely. }
	{ You see, in order to have a tactics mode without changing any other part }
	{ of the program, this procedure must fool all the PC-input and AI routines }
	{ into believing that the clock is ticking, whereas in fact it's just ticking }
	{ for that one particular model for a stretch of 60 seconds. }
	{ PRECONDITION: Camp^.GB^.Scene <> Nil }
var
	T: String;
	M: GearPtr;
	Team: Integer;
	FoundPCToAct: Boolean;
	FX_String,FX_Desc: String;
begin
	{ To start with, do a vision check for everyone, }
	{ then set up the display. }
	UniversalVisionCheck( Camp^.GB );

	{ Set the gameboard's pointer to the campaign. }
	Camp^.GB^.Camp := Camp;

	{ Get rid of the old AI pathfinding maps. }
	ClearHotMaps;

	{ Initialize the FX_Strings }
	if Camp^.GB^.Scene <> Nil then begin
		case NATtValue( Camp^.GB^.Scene^.NA , NAG_EnvironmentData , NAS_Atmosphere ) of
			NAV_Vacuum: 	begin
					FX_String := '1 DAMAGE 10 0 ArmorIgnore GasAttack NoMetal CanResist';
					FX_Desc   := MsgString( 'ENVIRO_VACUUM' );
					end;
		else 	begin
			FX_String := '';
			FX_Desc   := '';
			end;
		end;
	end else begin
		FX_String := '';
		FX_Desc   := '';
	end;

	{ Set the STARTGAME trigger, and update all props. }
	SetTrigger( Camp^.GB , TRIGGER_StartGame );
	T := 'UPDATE';
	CheckTriggerAlongPath( T , Camp^.GB , Camp^.GB^.Meks , True );

	{ Add some random monsters, if appropriate. }
	RestockRandomMonsters( Camp^.GB );

	{ Do some graphics initializing, if needed. }
{$IFNDEF ASCII}
	InitGraphicsForScene( Camp^.GB );
{$ENDIF}

	{Start main combat loop here.}
	{Keep going until there's only one side left.}
	while KeepPlayingSC( Camp^.GB ) do begin

		HandleTriggers( Camp^.GB );

		{ Each round lasts one minute. }
		{ Handle the player mecha first. }
		repeat
			FoundPCToAct := False;
			M := Camp^.GB^.Meks;
			while ( M <> Nil ) and KeepPlayingSC( Camp^.GB ) do begin
				team := NAttValue( M^.NA , NAG_Location , NAS_Team );
				if ( Team = NAV_DefPlayerTeam ) or ( Team = NAV_LancemateTeam ) then begin
					if NotDestroyed( M ) and OnTheMap( Camp^.GB , M ) then begin
						if CanTakeTurn( Camp^.GB , M ) and ( NAttValue( M^.NA , NAG_Action , NAS_CallTime ) < ( Camp^.GB^.ComTime + TacticsRoundLength - 1 ) ) then begin
							FoundPCToAct := True;
						end;
						TacticsTurn( Camp , M , True );
					end;
				end;
				M := M^.Next;
			end;
		until ( not FoundPCToAct );

		{ Handle the enemy mecha next, as long as the game hasn't been quit. }
		if KeepPlayingSC( Camp^.GB ) then begin
			{ Handle NPC mecha }
			M := Camp^.GB^.Meks;
			while M <> Nil do begin
				team := NAttValue( M^.NA , NAG_Location , NAS_Team );
				if ( Team <> NAV_DefPlayerTeam ) and ( Team <> NAV_LancemateTeam ) and ( Team <> 0 ) then begin
					if NotDestroyed( M ) and OnTheMap( Camp^.GB , M ) then begin
						TacticsTurn( Camp , M , False );
					end;
				end;
				M := M^.Next;
			end;

			{ Advance the clock by 60 seconds. }
			QuickTime( Camp^.GB , TacticsRoundLength );
			AddNAtt( Camp^.GB^.Scene^.NA , NAG_SceneData , NAS_TacticsTurnStart , TacticsRoundLength );
			HandleTriggers( Camp^.GB );

			{ Update clouds every round. }
			for team := 1 to ( TacticsRoundLength div 30 ) do BrownianMotion( Camp^.GB );

			{ Handle environmental effects every other round. }
			if ( FX_String <> '' ) and ( ( ( Camp^.GB^.ComTime div TacticsRoundLength ) mod 2 ) = 1 ) then MassEffectFrontEnd( Camp^.GB , FX_String , FX_Desc );

			{ Once every 10 rounds, roll for random monsters. }
			if ( ( Camp^.GB^.ComTime div TacticsRoundLength ) mod 10 ) = 0 then RestockRandomMonsters( Camp^.GB );
		end;
	end;

	{ Handle the last pending triggers. }
	SetTrigger( Camp^.GB , TRIGGER_EndGame );
	HandleTriggers( Camp^.GB );
end;


Procedure PreparePCForces( GB: GameBoardPtr; var PCForces: GearPtr );
	{ ******************************* }
	{ *** PC Forces PreProcessing *** }
	{ ******************************* }
	{ Before sticking the PCs on the map, must first check whether or not }
	{ to stick them in mecha. }
	Function IsValidForScene( Mek: GearPtr ): Boolean;
		{ Return TRUE if this mecha is valid for this scene, or FALSE otherwise. }
	begin
		if ( GB^.Scene <> Nil ) and AStringHasBString( SAttValue( GB^.Scene^.SA , 'SPECIAL' ) , 'TownMecha' ) then begin
			IsValidForScene := ( BaseMoveRate( GB^.Scene , Mek , MM_Walk ) > 0 ) or ( BaseMoveRate( GB^.Scene , Mek , MM_Roll ) > 0 ) or ( BaseMoveRate( GB^.Scene , Mek , MM_Skim ) > 0 ) or ( BaseMoveRate( GB^.Scene , Mek , MM_Fly ) > 100 );
		end else begin
			{ If no check is specified, this mecha is automatically valid. }
			IsValidForScene := True;
		end;
	end;
var
	PCT,PC2,PCMek: GearPtr;
begin
	{ Pass One - Set PC Team for all units. }
	PCT := PCForces;
	while PCT <> Nil do begin
		{ The exact team is going to depend on whether this is the primary PC or }
		{ just a lancemate. }
		if NAttValue( PCT^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_CTPrimary then begin
			SetNAtt( PCT^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );
		end else begin
			SetNAtt( PCT^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
		end;
		PCT := PCT^.Next;
	end;

	{ Pass Two - Insert pilots into mecha as appropriate. }
	PCT := PCForces;
	while PCT <> Nil do begin
		PC2 := PCT^.Next;

		{ If this gear is a character, and is at a smaller scale than }
		{ the map, check to see if he/she has a mecha to get into. }
		if ( PCT^.G = GG_Character ) and ( PCT^.Scale < GB^.Scale ) then begin
			PCMek := FindPilotsMecha( PCForces , PCT );
			if ( PCMek <> Nil ) and ( PCMek^.Scale <= GB^.Scale ) and HasAtLeastOneValidMovemode( PCMek ) and IsValidForScene( PCMek ) then begin
				{ A mek has been found. Insert the pilot into it. }
				DelinkGear( PCForces , PCT );

				{ If the pilot is a lancemate, so is the mecha. }
				if NAttValue( PCT^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_CTPrimary then begin
					SetNAtt( PCMek^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );
				end;
				if not BoardMecha( PCMek , PCT ) then begin
					{ The pilot couldn't board the mecha for whatever reason. }
					{ Stick the pilot back in the list, at the beginning. }
					PCT^.Next := PCForces;
					PCForces := PCT;
				end;
			end;
		end;

		PCT := PC2;
	end;
end;

Procedure PrepareNPCForces( GB: GameBoardPtr; Scene: GearPtr );
	{ Prepare the NPC forces involved in this scene for whatever is about to happen. }
	{ If they have mecha defined, stick them in it. }
var
	N,N2,Mek: GearPtr;
begin
	N := Scene^.InvCom;
	while N <> Nil do begin
		N2 := N^.Next;

		if IsMasterGear( N ) and IsACombatant( N ) and NotAnAnimal( N ) and ( NAttValue( N^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then begin

			{ On big maps, load a mecha. On small maps, give equipment. }
			if Scene^.V > 0 then begin
				MEK := SelectNPCMecha( GB , Scene , N );

				if ( Mek <> Nil ) and ( Mek^.SCale <= Scene^.V ) and ( Mek^.G = GG_Mecha ) then begin
					{ Customize the mecha for its pilot. }
					MechaMakeover( Mek , NAttValue( N^.NA , NAG_Personal , NAS_SpecialistSkill ) , NAttValue( N^.NA , NAG_Personal , NAS_MechaTheme ) , MechaModPoints( N ) );

					{ Stick the mecha in the scene, stick the pilot in the mecha, and }
					{ set the needed values. }
					InsertInvCom( Scene , MEK );
					DelinkGear( Scene^.InvCom , N );
					SetNAtt( MEK^.NA , NAG_Location , NAS_Team , NAttValue( N^.NA , NAG_Location , NAS_Team ) );
					SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Temporary , 1 );
					SetNAtt( Mek^.NA , NAG_Personal , NAS_FactionID , NATtValue( N^.NA , NAG_Personal , NAS_FactionID ) );
					if not BoardMecha( Mek , N ) then begin
						InsertInvCom( Scene , N );
					end;
				end else if Mek <> Nil then begin
					DisposeGear( Mek );
				end;
			end else begin
				{ This is a personal-scale map. Give this combatant }
				{ some equipment to use. }
				SelectEquipmentForNPC( GB , N , NAttValue( N^.NA , NAG_CharDescription , NAS_Renowned ) );
			end;
		end;

		N := N2;
	end;
end;


Function NonRecoveryScene( GB: GameBoardPtr ): Boolean;
	{ Return TRUE if this scene isn't a good location for recovery. }
begin
	NonRecoveryScene := ( GB^.Scene = Nil ) or ( not AStringHasBString( SAttValue( GB^.Scene^.SA , 'TYPE' ) , 'TOWN' ) );
end;

Function ShouldDeployLancemate( GB: GameBoardPtr; LM , Scene: GearPtr ): Boolean;
	{ Return TRUE if LM should be placed on this map, or FALSE if LM should be }
	{ kept on the sidelines. }
begin
	if AStringHasBString( SAttValue( Scene^.SA , 'SPECIAL' ) , 'SOLO' ) then begin
		ShouldDeployLancemate := False;
	end else if LM^.Scale < ( Scene^.V - 1 ) then begin
		ShouldDeployLancemate := False;
	end else if ( LM^.G = GG_Character ) and ( NAttValue( LM^.NA , NAG_Damage , NAS_OutOfAction ) <> 0 ) and NonRecoveryScene( GB ) then begin
		ShouldDeployLancemate := False;
	end else begin
		ShouldDeployLancemate := True;
	end;
end;

Procedure PrepareTeams( GB: GameBoardPtr );
	{ Go through all the teams in play. If any of them have a DEPLOY script, }
	{ call that now. }
	{ These scripts will typically be used to request dynamic opponents. }
var
	T: GearPtr;
	d: String;
begin
	if ( GB^.Scene = Nil ) then exit;
	T := GB^.Scene^.SubCom;
	while T <> Nil do begin
		if ( T^.G = GG_Team ) and ( SAttValue( T^.SA , 'DEPLOY' ) <> '' ) then begin
			d := 'DEPLOY';
			TriggerGearScript( GB , T , D );
		end;
		T := T^.Next;
	end;
end;


Procedure DeployJJang( Camp: CampaignPtr; Scene,PCForces: GearPtr );
	{ Deploy the game forces as described in the Scene. }
var
	it,it2: GearPtr;
begin
	if DEBUG_ON then DialogMsg( 'DeployJJang' );

	{ ERROR CHECK - If this campaign already has a GameBoard, no need to }
	{ deploy anything. It was presumably just restored from disk and should }
	{ be fully stocked. }
	if Camp^.GB <> Nil then Exit;

	{ Record the tactics turn start time. }
	{ This gets reset along with the scene, but should not be reset for saved games. }
	SetNAtt( Scene^.NA , NAG_SceneData , NAS_TacticsTurnStart , Camp^.ComTime );

	{ Generate the map for this scene. It will either be created }
	{ randomly or drawn from the frozen maps. }
	Camp^.gb := UnfreezeLocation( GearName( Scene ) , Camp^.Maps );
	if Camp^.GB = Nil then Camp^.gb := RandomMap( SCene );

	Camp^.GB^.ComTime := Camp^.ComTime;
	Camp^.gb^.Scene := Scene;
	Camp^.gb^.Scale := Scene^.V;

	{ Get the PC Forces ready for deployment. }
	PreparePCForces( Camp^.GB , PCForces );
	PrepareNPCForces( Camp^.GB , Scene );

	{ Stick the metaterrain on the map, since the PC position may well be }
	{ determined by this. }
	it := Scene^.InvCom;
	while it <> Nil do begin
		it2 := it^.Next;

		{ Check to see if this is metaterrain. }
		if ( it^.G = GG_MetaTerrain ) then begin
			DelinkGear( Scene^.InvCom , it );
			DeployMek( Camp^.gb , it , True );
		end;

		it := it2;
	end;


	{ Stick the PC forces on the map. }
	{ Clear the PC_TEAM saved position. }
	PC_Team_X := 0;
	while PCForces <> Nil do begin
		it2 := PCForces^.Next;
		it := PCForces;
		DelinkGear( PCForces , it );
		if NAttValue( it^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
			DeployMek( Camp^.gb , it , GearActive( it ) AND ( ( it^.Scale <= Camp^.GB^.Scale ) or ( ( Camp^.GB^.Scene <> Nil ) and ( Camp^.GB^.Scene^.G = GG_World ) ) ) );
		end else begin
			if GearActive( it ) AND ( it^.Scale <= Camp^.GB^.Scale ) AND ShouldDeployLancemate( Camp^.GB , it , Scene ) then begin
				DeployMek( Camp^.gb , it , True );
				SetNAtt( it^.NA , NAG_Damage , NAS_OutOfAction , 0 );
			end else begin
				DeployMek( Camp^.gb , it , False );
			end;
		end;
		PCForces := it2;
	end;

	{ Check the orders of the lancemates. }
	SetLancemateOrders( Camp^.GB );

	{ Stick the local NPCs on the map. }
	it := Scene^.InvCom;
	while it <> Nil do begin
		it2 := it^.Next;

		{ Check to see if this is a character. }
		if ( it^.G >= 0 ) then begin
			DelinkGear( Scene^.InvCom , it );
			if NAttValue( it^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
				DeployMek( Camp^.gb , it , ( it^.G = GG_Character ) );
			end else begin
				DeployMek( Camp^.gb , it , ( ( it^.Scale <= Scene^.V ) or ( it^.G = GG_Character ) ) );
			end;
		end;

		it := it2;
	end;

	{ Finally, deploy any temp forces and perform initialization requested by teams. }
	PrepareTeams( Camp^.GB );
end;

Function IsGlobalGear( NPC: GearPtr ): Boolean;
	{ This function will decide whether or not the NPC is global. }
	{ Global NPCs are stored as subcomponents of the ADVENTURE }
	{ gear. }
begin
	IsGlobalGear := NAttValue( NPC^.NA , NAG_ParaLocation , NAS_OriginalHome ) <> 0;
end;


Function ShouldDeleteDestroyed( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
	{ Return TRUE if MEK should be deleted, or FALSE otherwise. }
	{ MEK shouldn't be deleted if it's an artefact. }
begin
	ShouldDeleteDestroyed := not AStringHasBString( SAttValue( Mek^.SA , 'TYPE' ) , SAtt_Artifact );
end;

Procedure PutAwayGear( GB: GameBoardPtr; var Mek,PCForces: GearPtr );
	{ The game is over. Put MEK wherever it belongs. }
	function ShouldBeMoved: Boolean;
		{ MEK is a member of the player team. }
		{ Return TRUE if Mek should be moved, or FALSE otherwise. }
		{ It should be moved if it's a character, if it's the }
		{ PC's chosen mecha, or if the current scene is dynamic }
		{ or a metascene. Got all that? }
	begin
		if ( GB^.Scene = Nil ) or IsInvCom( GB^.Scene ) or ( GB^.Scene^.S < 0 ) then begin
			ShouldBeMoved := True;
		end else if ( GB^.Scene^.G = GG_MetaScene ) then begin
			ShouldBeMoved := True;
		end else if Mek^.G = GG_Character then begin
			ShouldBeMoved := True;
		end else if SAttValue( Mek^.SA , 'PILOT' ) <> '' then begin
			ShouldBeMoved := True;
		end else begin
			ShouldBeMoved := False;
		end;
	end;
begin
	if Mek = Nil then begin
		Exit;
	end else if ( Mek^.G = GG_MetaTerrain ) and ( Mek^.S = GS_MetaFire ) then begin
		DisposeGear( Mek );
	end else if ( Mek^.G = GG_MetaTerrain ) and ( Mek^.S = GS_MetaEncounter ) and ( Mek^.Stat[ STAT_Destination ] < 0 ) and MetaSceneNotInUse( GB^.Camp^.Source , Mek^.Stat[ STAT_Destination ] ) then begin
		DisposeGear( Mek );
	end else if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Temporary ) <> 0 then begin
		DisposeGear( Mek );
	end else if Destroyed( Mek ) and ShouldDeleteDestroyed( GB , Mek ) then begin
		DisposeGear( Mek );
	end else if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ShouldBeMoved then begin
		{ Strip the location & visibility info. }
		StripNAtt( Mek , NAG_Location );
		StripNAtt( Mek , NAG_Visibility );
		StripNAtt( Mek , NAG_Action );
		StripNAtt( Mek , NAG_EpisodeData );

		{ Get rid of FLUMMOX and BURN conditions. }
		SetNAtt( Mek^.NA , NAG_StatusEffect , NAS_Burn , 0 );
		SetNAtt( Mek^.NA , NAG_StatusEffect , NAS_Flummoxed , 0 );

		{ Store the mecha in the PCForces list. }
		Mek^.Next := PCForces;
		PCForces := Mek;

	end else if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ShouldBeMoved then begin
		{ Strip the location & visibility info. }
		StripNAtt( Mek , NAG_Location );
		StripNAtt( Mek , NAG_Visibility );
		StripNAtt( Mek , NAG_Action );
		StripNAtt( Mek , NAG_EpisodeData );

		{ Get rid of FLUMMOX and BURN conditions. }
		SetNAtt( Mek^.NA , NAG_StatusEffect , NAS_Burn , 0 );
		SetNAtt( Mek^.NA , NAG_StatusEffect , NAS_Flummoxed , 0 );

		{ Make sure to record that this is a lancemate, if appropriate. }
		if ( Mek^.G = GG_Character ) and ( NAttValue( Mek^.NA , NAG_CharDescription , NAS_CharType ) = 0 ) then SetNAtt( Mek^.NA , NAG_CharDescription , NAS_CharType , NAV_CTLancemate );

		{ Store the mecha in the PCForces list. }
		Mek^.Next := PCForces;
		PCForces := Mek;

	end else begin
		{ Strip the stuff we don't want to save. }
		StripNAtt( Mek , NAG_Visibility );
		StripNAtt( Mek , NAG_Action );
		StripNAtt( Mek , NAG_EpisodeData );
		StripNAtt( Mek , NAG_Condition );

		if GB^.Scene <> Nil then begin
			if IsGlobalGear( Mek ) and IsInvCom( GB^.Scene ) then begin
				StripNAtt( Mek , NAG_Location );
				StripNAtt( Mek , NAG_Damage );
				PutAwayGlobal( GB , Mek );
			end else begin
				InsertInvCom( GB^.Scene , Mek );
			end;
		end else begin
			DisposeGear( Mek );
		end;
	end;

end;


Procedure ApplyEmergencyHealing( Adv: GearPtr; GB: GameboardPtr );
	{ Apply healing to any character or mecha on the PC's team that has been destroyed. }
	{ Anything not restored to health by this procedure is likely to be deleted. If that }
	{ includes the PC, then the game is over. }
var
	PC: GearPtr;
	team,T,SkRk: LongInt;
begin
	PC := GB^.Meks;

	while PC <> Nil do begin
		team := NAttValue( PC^.NA , NAG_Location , NAS_Team );
		if ( team = NAV_DefPlayerTeam ) or ( team = NAV_LancemateTeam ) then begin
			if Destroyed( PC ) then begin
				{ Check every repair skill for applicability. }
				for t := 1 to NumSkill do begin
					if ( SkillMan[ T ].Usage = USAGE_Repair ) then begin
						if ( TotalRepairableDamage( PC , T ) > 0 ) and TeamHasSkill( GB , NAV_DefPlayerTeam , T ) then begin
							{ Determine how many repair points it's possible }
							{ to apply. }
							if ( PC^.G = GG_Mecha ) then begin
								SkRk := RollStep( TeamSkill( GB , NAV_DefPlayerTeam , T ) ) - 5;
							end else begin
								SkRk := RollStep( TeamSkill( GB , NAV_DefPlayerTeam , T ) ) - 7;
							end;
							if SkRk < 0 then SkRk := 0;
							ApplyEmergencyRepairPoints( PC , T , SkRk );
							if PC^.G = GG_Character then SetNAtt( PC^.NA , NAG_Damage , NAS_OutOfAction , 1 );
						end;
					end;
				end;	{ Checking the repair skills. }

				{ What happense next depends on whether this is arena mode or RPG mode. }
				if ( Adv <> Nil ) and ( Adv^.S = GS_ArenaCampaign ) then begin
					{ Killed PCs who don't get the medicine roll in arena mode are out of luck. }
					{ Record a message in the scene to tell whether this gear is recovered }
					{ or destroyed. }
					if PC^.G = GG_Character then begin
						{ It's a character. The message will be handled by the medic. }
						if NotDestroyed( PC ) then begin
							AddSAtt( GB^.Scene^.SA , ARENAREPORT_CharRecovered , GearName( PC ) );
						end else begin
							AddSAtt( GB^.Scene^.SA , ARENAREPORT_CharDied , GearName( PC ) );
						end;
					end else begin
						{ It's a thing. The message will be handled by the mechanic. }
						if NotDestroyed( PC ) then begin
							AddSAtt( GB^.Scene^.SA , ARENAREPORT_MechaRecovered , GearName( PC ) );
						end else begin
							AddSAtt( GB^.Scene^.SA , ARENAREPORT_MechaDestroyed , GearName( PC ) );
						end;
					end;
				end else begin
					if ( PC^.G = GG_Character ) and ( Team = NAV_DefPlayerTeam ) and Destroyed( PC ) then begin
						{ At this point in time, the PC is dead. Attempt to load a }
						{ rescue scenario. If the rescue fails, then the PC will be }
						{ perminantly dead. }
						if ( NAttValue( PC^.NA , NAG_Personal , NAS_Resurrections ) < ((NAttValue( PC^.NA , NAG_CharDescription , NAS_Heroic ) div 10 ) + 1 + RollStep( 1 ) ) ) and StartRescueScenario( GB , PC , '*DEATH' ) then begin
							AddNAtt( PC^.NA , NAG_Personal , NAS_Resurrections , 1 );
							if Random( 3 ) = 1 then ApplyPerminantInjury( PC );
							AddReputation( PC , 6 , -10 );
							AddMoraleDmg( PC , 100 );
						end;
					end else if GearActive( PC ) then begin
						StripNAtt( PC , NAG_StatusEffect );
						if PC^.G = GG_Mecha then begin
							DialogMsg( ReplaceHash( MsgString( 'DJ_MECHARECOVERED' ) , GearName( PC ) ) );
						end else if ( PC^.G = GG_Character ) and ( Team = NAV_DefPlayerTeam ) then begin
							StartRescueScenario( GB , PC , '*RECOVERY' );
							AddReputation( PC , 6 , -10 );
							AddMoraleDmg( PC , 100 );
						end else begin
							DialogMsg( ReplaceHash( MsgString( 'DJ_OUTOFACTION' ) , PilotName( PC ) ) );
						end;
					end;
				end; { If ArenaCampaign ... Else }
			end;	{ if Destroyed... }
		end;
		PC := PC^.Next;
	end;
end;

Procedure PreparePCForDelink( GB: GameBoardPtr );
	{ Check the PC forces; restore any dead characters based on the repair skills }
	{ posessed by the party; maybe call a rescue procedure. }
var
	PC,TruePC: GearPtr;
	team: LongInt;
begin
	{ Step One: Delink the pilots from their mecha. }
	PC := GB^.Meks;
	while PC <> Nil do begin
		team := NAttValue( PC^.NA , NAG_Location , NAS_Team );
		if ( PC^.G = GG_Mecha ) and ( ( team = NAV_DefPlayerTeam ) or ( team = NAV_LancemateTeam ) ) then begin
			repeat
				TruePC := ExtractPilot( PC );
				if TruePC <> Nil then begin
					AppendGear( GB^.Meks , TruePC );
				end;
			until TruePC = Nil;
		end;
		PC := PC^.Next;
	end;

	{ Step Two: Apply emergency healing to all. }
	{ If this scene is of a NORESCUE type, don't bother. }
	if ( GB^.Scene = Nil ) or not AStringHasBString( SAttValue( GB^.Scene^.SA , 'SPECIAL' ) , 'NORESCUE' ) then begin
		ApplyEmergencyHealing( FindRoot( GB^.Scene ) , GB );
	end;

	{ Step Three: Remove PILOT tags from mecha whose pilots are }
	{ no longer with us. }
	PC := GB^.Meks;
	while PC <> Nil do begin
		team := NAttValue( PC^.NA , NAG_Location , NAS_Team );
		if ( team = NAV_DefPlayerTeam ) or ( team = NAV_LancemateTeam ) then begin
			if ( PC^.G = GG_Mecha ) and ( SAttValue( PC^.SA , 'PILOT' ) <> '' ) then begin
				TruePC := SeekGearByName( GB^.Meks , SAttValue( PC^.SA , 'PILOT' ) );
				if ( TruePC = Nil ) or Destroyed( TruePC ) then begin
					SetSAtt( PC^.SA , 'PILOT <>' );
				end;
			end;
		end;
		PC := PC^.Next;
	end;
end;

Procedure DoPillaging( GB: GameBoardPtr );
	{ Pillage everything that isn't nailed down. }
var
	PC,M,M2: GearPtr;
	Cash,NID: LongInt;
begin
	Cash := 0;
	PC := GG_LocatePC( GB );

	{ If this is a NOPILLAGE scene, exit. }
	if ( GB^.Scene <> Nil ) and AStringHasBString( SAttValue( GB^.Scene^.SA, 'SPECIAL' ) , 'NOPILLAGE' ) then Exit;

	if ( PC <> Nil ) and OnTheMap( GB , PC ) then begin
		{ First pass: Shakedown anything that's destroyed. }
		M := GB^.Meks;
		while M <> Nil do begin
			if OnTheMap( GB , M ) and IsMasterGear( M ) and not GearOperational( M ) then begin
				cash := cash + SHakeDown( GB , M , 1 , 1 );
			end;
			M := M^.Next;
		end;

		{ Second pass: Pick up anything we can! }
		M := GB^.Meks;
		while M <> Nil do begin
			M2 := M^.Next;

			if OnTheMap( GB , M ) and NotDestroyed( M ) and IsLegalInvcom( PC , M ) and ( M^.G > 0 ) and not IsMasterGear( M ) then begin
				DelinkGear( GB^.Meks , M );

				{ Clear the item's location values. }
				StripNAtt( M , NAG_Location );

				InsertInvCom( PC , M );
				NID := NAttValue( M^.NA , NAG_Narrative , NAS_NID );
				if NID <> 0 then SetTrigger( GB , TRIGGER_GetItem + BStr( NID ) );
			end;

			M := M2;
		end;

		{ Finally, hand the PC any money that was found. }
		PC := LocatePilot( PC );
		if ( PC <> Nil ) and ( Cash > 0 ) then AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cash );
	end;
end;

Function DelinkJJang( GB: GameBoardPtr ): GearPtr;
	{ Delink all the components of the scenario, filing them away }
	{ for fututure use. Return a pointer to the surviving PC forces. }
var
	PCForces,Mek,Pilot: GearPtr;
begin
	if DEBUG_ON then DialogMsg( 'DelinkJJang' );

	{ Step one - Delete obsoleted teams. }
	{ A team will be deleted if it has no members, if it isn't the }
	{ player team or the neutral team, and if it has no wandering }
	{ monsters allocated. }
	DeleteObsoleteTeams( GB );
	if DEBUG_ON then DialogMsg( 'Team update complete.' );

	{ Step one-and-a-half: If this is a dynamic scene, and is safe, and pillaging }
	{ is enabled, then pillage away! }
	if IsInvCom( GB^.Scene ) and IsSafeArea( GB ) and Pillage_On then begin
		DoPillaging( GB );
	end;

	{ Step two - Remove all models from game board. }
	{ Initialize the PC Forces to Nil. }
	PCForces := Nil;

	{ Prepare the PCForces for delinkage. }
	PreparePCForDelink( GB );

	{ Keep processing while there's gears to process. }
	while GB^.Meks <> Nil do begin
		{ Delink the first gear from the list. }
		Mek := GB^.Meks;
		Pilot := Nil;
		DelinkGear( GB^.Meks , Mek );

		{ Decide what to do with this gear. }
		{ - If a mecha or disembodied module, remove its pilots. }
		{ - if on player team, store in PCForces }
		{ - if not on player team, store in GB^.Scene }
		{ - if destroyed, delete it }
		if ( Mek^.G = GG_Mecha ) or ( Mek^.G = GG_Module ) then begin
			{ Delink the pilot, and add to the list. }
			repeat
				Pilot := ExtractPilot( Mek );
				if Pilot <> Nil then begin
					PutAwayGear( GB , Pilot , PCForces );
				end;
			until Pilot = Nil;
		end;

		{ Send MEK to its destination. }
		PutAwayGear( GB , Mek , PCForces );

	end;

	DelinkJJang := PCForces;
end;


Function WorldPlayer( Camp: CampaignPtr ; Scene: GearPtr; var PCForces: GearPtr ): Integer;
	{ The player is about to explore the world map. Hooray! }
	{ This uses a separate procedure from regular exploration. }
var
	it: Integer;
begin
	DeployJjang( Camp , Scene , PCForces );

	it := WorldMapMain( Camp );

	PCForces := DelinkJJang( Camp^.GB );

	{ Save the final ComTime in the Campaign. }
	Camp^.ComTime := Camp^.GB^.ComTime;

	Camp^.GB^.Scene := Nil;
	DisposeMap( Camp^.gb );
	WorldPlayer := it;
end;

Function RealScenePlayer( Camp: CampaignPtr ; Scene: GearPtr; var PCForces: GearPtr ): Integer;
	{ Construct then play a scenario. }
	{ Note that this procedure ABSOLUTELY DEFINITELY requires that }
	{ the SCENE gear be defined. }
var
	N: Integer;
begin
	DeployJJang( Camp , Scene , PCForces );

	{ Once everything is deployed, save the campaign. }
	if DoAutoSave then PCSaveCampaign( Camp , GG_LocatePC( Camp^.GB ) , False );

	if ( Camp^.Source <> Nil ) and ( Camp^.Source^.G = GG_Adventure ) then begin
		if Camp^.Source^.S = GS_ArenaCampaign then begin
			if Arena_Use_Tactics then TacticsMain( Camp )
			else CombatMain( Camp );
		end else begin
			if RPG_Use_Tactics then TacticsMain( Camp )
			else CombatMain( Camp );
		end;
	end else begin
		CombatMain( Camp );
	end;

	PCForces := DelinkJJang( Camp^.gb );

	{ Save the final ComTime in the Campaign. }
	Camp^.ComTime := Camp^.GB^.ComTime;

	{ Get rid of the Focused_On_Mek. }
	FocusOn( Nil );

	{ If SCENE is a part of Camp\Source, the map needs to be saved. }
	{ Otherwise dispose of the map and the scene together. }
	if ( FindGearIndex( Camp^.Source , Camp^.GB^.Scene ) <> -1 ) then begin
		if ( SAttValue( Camp^.GB^.Scene^.SA , 'NAME' ) <> '' ) then begin
			FreezeLocation( GearName( Scene ) , Camp^.GB , Camp^.Maps );
		end;
		Camp^.gb^.Scene := Nil;
	end;

	{ Record the returncode before freeing the gameboard. }
	N := Camp^.gb^.ReturnCode;
	DisposeMap( Camp^.gb );

	RealScenePlayer := N;
end;

Function ScenePlayer( Camp: CampaignPtr ; Scene: GearPtr; var PCForces: GearPtr ): Integer;
	{ Call the appropriate player routine based on scene type. }
begin
	if ( Scene <> Nil ) and ( Scene^.G = GG_World ) then begin
		ScenePlayer := WorldPlayer( Camp , Scene , PCForces );
	end else begin
		ScenePlayer := RealScenePlayer( Camp , Scene , PCForces );
	end;
end;


end.
