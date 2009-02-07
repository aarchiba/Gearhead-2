unit services;
	{ This is an offshoot of the ArenaTalk/ArenaScript interaction }
	{ stuff. It's supposed to handle shops & other cash transactions }
	{ for the GearHead RPG engine. }
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
	num_standard_schemes = 5;
	standard_lot_colors: Array [0..num_standard_schemes-1] of string = (
	'152 172 183 199 188 162 200   0 200', 	{ Coral, Gull Grey, Purple }
	' 80  80  85 130 144 114 200 200   0',	{ Dark Grey, Battleship Grey, Yellow }
	' 66 121 179 210 215  80 205  25   0',	{ Default player colors }
	'201 205 229  49  91 161   0 200   0',	{ Aero Blue, Azure, Green }
	'240 240 240 208  34  51  50  50 150'	{ White, Red Goes Fasta, Blue }
	);


var
	{ The following vars are primarily needed by the interaction routines in }
	{ arenascript.pp, but they're needed here too and this is the higher level }
	{ unit so here they are. }
	CHAT_Message: String;	{ The message in the interact window. }
	CHAT_React: Integer;	{ How the NPC feels about the PC. }
	I_Endurance: Integer;	{ How much of the PC's crap the NPC is }
		{ willing to take. When it reaches 0, the NPC says goodbye. }

Function RepairMasterCost( Master: GearPtr; Skill: Integer ): LongInt;
Function ReloadMasterCost( M: GearPtr; ReloadGeneralInv: Boolean ): LongInt;
Procedure DoReloadMaster( M: GearPtr; ReloadGeneralInv: Boolean );


Procedure OpenShop( GB: GameBoardPtr; PC,NPC: GearPtr; Stuff: String );
Procedure OpenSchool( GB: GameBoardPtr; PC,NPC: GearPtr; Stuff: String );
Procedure ExpressDelivery( GB: GameBoardPtr; PC,NPC: GearPtr );
Procedure ShuttleService( GB: GameBoardPtr; PC,NPC: GearPtr );


implementation

uses ability,arenacfe,backpack,gearutil,ghchars,ghmodule,gearparser,
     ghswag,ghweapon,interact,menugear,rpgdice,skilluse,texutil,
     description,narration,ui4gh,ghprop,
     customization,
{$IFDEF ASCII}
	vidgfx,vidmap,vidmenus,vidinfo;
{$ELSE}
{$IFDEF CUTE}
	cutegfx,cutemap,glmenus,glinfo;
{$ELSE}
	glgfx,glmap,glmenus,glinfo;
{$ENDIF}
{$ENDIF}

Const
	CredsPerDP = 1;		{ Cost to repair 1DP of damage. }
	MaxShopItems = 21;	{ Maximum number of items in a shop. }

var
	SERV_GB: GameBoardPtr;
	SERV_PC,SERV_NPC,SERV_Info: GearPtr;
	SERV_Menu: RPGMenuPtr;


Procedure ServiceRedraw;
	{ Redraw the screen for whatever service is going to go on. }
var
	Part: GearPtr;
begin
	CombatDisplay( SERV_GB );
	SetupServicesDisplay;

	if ( SERV_Info <> Nil ) and ( Serv_Menu <> Nil ) then begin
		Part := RetrieveGearSib( SERV_Info , CurrentMenuItemValue( SERV_Menu ) );
		if Part <> Nil then begin
			BrowserInterfaceInfo( Part , ZONE_ItemsInfo );

		end;
	end else if Serv_Info <> Nil then begin
		BrowserInterfaceInfo( SERV_Info , ZONE_ItemsInfo );
	end;

	if SERV_NPC <> Nil then NPCPersonalInfo( SERV_NPC , ZONE_ShopCaption );

	CMessage( '$' + BStr( NAttValue( SERV_PC^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_ItemsPCInfo , InfoHilight );
	GameMsg( CHAT_Message , ZONE_ShopMsg , InfoHiLight );
end;

Procedure SellStuffRedraw;
	{ Redraw the screen for whatever service is going to go on. }
var
	N: Integer;
	Part: GearPtr;
begin
	CombatDisplay( SERV_GB );
	SetupServicesDisplay;

	if ( SERV_Info <> Nil ) and ( Serv_Menu <> Nil ) then begin
		N := CurrentMenuItemValue( SERV_Menu );
		if N > 0 then begin
			Part := LocateGearByNumber( SERV_Info , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Part , ZONE_ItemsInfo );
			end;
		end;
	end else if Serv_Info <> Nil then begin
		BrowserInterfaceInfo( SERV_Info , ZONE_ItemsInfo );
	end;

	if SERV_NPC <> Nil then NPCPersonalInfo( SERV_NPC , ZONE_ShopCaption );

	CMessage( '$' + BStr( NAttValue( SERV_PC^.NA , NAG_Experience , NAS_Credits ) ) , ZONE_ItemsPCInfo , InfoHilight );
	GameMsg( CHAT_Message , ZONE_ShopMsg , InfoHiLight );
end;

Procedure ServicesBackpackRedraw;
	{ A redrawer for the backpack, as accessed from services. }
	{ Just do the combat display and call it even. }
begin
	CombatDisplay( SERV_GB );
end;

Function ScalePrice( PC,NPC: GearPtr; Price: Int64 ): LongInt;
	{ Modify the price listed based upon the PC's shopping skill. }
var
	ShopRk,ShopTr,R: Integer;		{ ShopRank and ShopTarget }
begin
	{ Determine the Shopping skill rank of the buyer. }
	ShopRk := SkillValue( PC , 21 );

	{ Determine the shopping target number, which should be the EGO }
	{ stat of the storekeeper. }
	if ( NPC = Nil ) or ( NPC^.G <> GG_Character ) then ShopTr := 10
	else begin
		{ Target is based on both the Ego of the shopkeeper }
		{ and also on the relationship with the PC. }
		ShopTr := NPC^.Stat[ STAT_Ego ];
		R := ReactionScore( Nil , PC , NPC );
		if R > 0 then begin
			ShopTr := ShopTr - ( R div 5 );
		end else if R < 0 then begin
			{ It's much harder to haggle if the shopkeep }
			{ doesn't like you. }
			ShopTr := ShopTr + Abs( R ) div 2;
		end;
	end;

	{ If ShopRk beats ShopTr, lower the asking price. }
	if ShopRk > ShopTr then begin
		{ Every point of shopping skill that the unit has }
		{ gives a 2% discount to whatever is being purchased. }
		ShopRk := ( ShopRk - ShopTr ) * 2;
		if ShopRk > 50 then ShopRk := 50;

		Price := ( Price * (100 - ShopRk ) ) div 100;
	end;
	if Price < 1 then Price := 1;

	ScalePrice := Price;
end;

Function PurchasePrice( PC,NPC,Item: GearPtr ): LongInt;
	{ Determine the purchase price of ITEM as being sold by NPC }
	{ to PC. }
begin
	{ Scale the base cost for the item. }
	PurchasePrice := ScalePrice( PC , NPC , GearCost( Item ) );
end;

Procedure ShoppingXP( PC , Part: GearPtr );
	{ The PC has just purchased PART. Give some XP to the PC's shopping }
	{ skill, then print a message if appropriate. }
var
	Price: LongInt;
begin
	{ Find the price of the gear. This must be positive or it'll }
	{ crash the logarithm function. }
	Price := GearCost( Part );
	if Price < 1 then Price := 1;
	if DoleSkillExperience( PC , 21 , Round( Ln( Price ) * 5 ) + 1 ) then begin
		DialogMsg( MsgString( 'SHOPPING_SkillAdvance' ) );
	end;
end;

Function ShopTolerance( GB: GameBoardPtr; NPC: GearPtr ): Integer;
	{ Tolerance measures the legality/illegality of items. This function }
	{ returns the maximum legality level stocked by this shopkeeper. }
var
	Scene: GearPtr;
	Tolerance: Integer;
begin
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Scene := FindRootScene( GB , GB^.Scene );
		if AStringHasBSTring( SAttValue( GB^.Scene^.SA , 'SPECIAL' ) , 'UNREGULATED' ) then begin
			Tolerance := NAttValue( GB^.Scene^.NA , NAG_GearOps , NAS_Legality );
		end else begin
			Tolerance := NAttValue( Scene^.NA , NAG_GearOps , NAS_Legality );
		end;

		{ Criminal shopkeepers have a higher than normal tolerance. }
		if NAttValue( NPC^.NA , NAG_CharDescription , NAS_Lawful ) < 0 then begin
			Tolerance := Tolerance - ( NAttValue( NPC^.NA , NAG_CharDescription , NAS_Lawful ) div 2 ) + 5;
		end;
	end else begin
		Tolerance := 0;
	end;
	ShopTolerance := Tolerance;
end;

procedure BuyAmmoClips( GB: GameBoardPtr; PC,NPC,Weapon: GearPtr );
	{ Allow spare clips to be purchased for this weapon. }
	{ If possible, add some special clip types. }
var
	AmmoList: GearPtr;
	Procedure AddAmmoToList( Proto: GearPtr );
		{ Create a clone of this ammunition and add it to the list. }
		{ If appropriate, add some ammo variants. We will assume for the }
		{ purpose of this procedure that no item will ever have multiple }
		{ ammo clips of the same type; i.e. you would not have a 5mm rifle }
		{ which also had an integrated 5mm rifle built into it. If you }
		{ design a weapon like that you are a truly terrible person, and }
		{ I wash my hands of you. }
	var
		A: GearPtr;
	begin
		A := CloneGear( Proto );
		AppendGear( AmmoList , A );
	end;
	Procedure LookForAmmo( LList: GearPtr );
		{ Search along this linked list looking for ammo. If you find }
		{ any, copy it and add it to the list. Then, add any ammo varieties }
		{ allowed by the shopkeeper's skill level and tolerance. }
	begin
		while LList <> Nil do begin
			if LList^.G = GG_Ammo then begin
				AddAmmoToList( LList );
			end;

			LookForAmmo( LList^.SubCom );
			LList := LList^.Next;
		end;
	end;
var
	ShopMenu: RPGMenuPtr;
	Ammo: GearPtr;
	N: Integer;
begin
	{ Step One: Create the list of ammo. }
	AmmoList := Nil;
	LookForAmmo( Weapon^.SubCom );

	{ Step Two: Create the shopping menu. }
	ShopMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
	N := 1;
	Ammo := AmmoList;
	while Ammo <> Nil do begin
		AddRPGMenuItem( ShopMenu , GearName( Ammo ) + ' ($' + BStr( GearCost( Ammo ) ) + ')' , N );

		Inc( N );
		Ammo := Ammo^.Next;
	end;
	RPMSortAlpha( ShopMenu );
	AlphaKeyMenu( ShopMenu );
	AddRPGMenuItem( ShopMenu , MsgString( 'EXIT' ) , -1 );

	{ Step Three: Keep shopping until the PC selects exit. }


	{ Upon exiting, dispose of the ammo list. }
	DisposeRPGMenu( ShopMenu );
	DisposeGear( AmmoList );
end;

procedure PurchaseGearMenu( GB: GameBoardPtr; PC,NPC,Part: GearPtr );
	{ The PC may or may not want to buy PART. }
	{ Show the price of this gear, and ask whether or not the }
	{ player wants to make this purchase. }
	{ If this item contains any SF:0 ammunition, offer to sell some }
	{ backup clips as well. }
var
	YNMenu: RPGMenuPtr;
	Cost: LongInt;
	N: Integer;
	msg: String;
begin
	Cost := PurchasePrice( PC , NPC , Part );

	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
	AddRPGMenuItem( YNMenu , 'Buy ' + GearName( Part ) + ' ($' + BStr( Cost ) + ')' , 1 );
	if ( Part^.SubCom <> Nil ) or ( Part^.InvCom <> Nil ) then AddRPGMenuItem( YNMenu , MsgString( 'SERVICES_BrowseParts' ) , 2 );
	if ( SeekSubsByG( Part^.SubCom , GG_Ammo ) <> Nil ) and ( Part^.Scale = 0 ) then AddRPGMenuItem( YNMenu , MsgString( 'SERVICES_BuyClips' ) , 3 );
	AddRPGMenuItem( YNMenu , 'Search Again' , -1 );

	msg := MSgString( 'BuyPROMPT' + Bstr( Random( 4 ) + 1 ) );
	msg := ReplaceHash( msg , GearName( Part ) );
	msg := ReplaceHash( msg , BStr( Cost ) );

	CHAT_Message := Msg;

	repeat
		Serv_Info := Part;
		Serv_Menu := Nil;
		N := SelectMenu( YNMenu , @ServiceRedraw );

		if N = 1 then begin
			if NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
				{ Copy the gear, then stick it in inventory. }
				Part := CloneGear( Part );

				GivePartToPC( GB , Part , PC );

				{ Reduce the buyer's cash by the cost of the gear. }
				AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -Cost );

				CHAT_Message := MsgString( 'BUYREPLY' + BStr( Random( 4 ) + 1 ) );
				if NPC <> Nil then DoleSkillExperience( NPC , 21 , ( ( Round( Ln( Cost ) * 100 ) ) div ( Part^.Scale * 2 + 1 ) ) + 1 );

				DialogMSG( 'You have purchased ' + GearName( Part ) + '.' );

				{ Give some XP to the PC's SHOPPING skill. }
				ShoppingXP( PC , Part );
			end else begin
				{ Not enough cash to buy... }
				DialogMSG( 'You don''t have enough money to buy ' + GearName( Part ) + '.' );
				CHAT_Message := MsgString( 'BUYNOCASH' + BStr( Random( 4 ) + 1 ) );

			end;
		end else if N = 2 then begin

			MechaPartBrowser( Part , @ServiceRedraw );

		end else if N = 3 then begin

			BuyAmmoClips( GB , PC , NPC , Part )

		end else if N = -1 then begin
			CHAT_Message := MsgString( 'BUYCANCEL' + BStr( Random( 4 ) + 1 ) );

		end;
	until N <> 2;

	DisposeRPGMenu( YNMenu );
end;

Function SellGear( var LList,Part: GearPtr; PC,NPC: GearPtr; const Categories: String ): Boolean;
	{ The unit may or may not want to sell PART. }
	{ Show the price of this gear, and ask whether or not the }
	{ player wants to make this sale. }
var
	YNMenu: RPGMenuPtr;
	Cost: Int64;
	R,ShopRk,ShopTr: Integer;
	N: Integer;
	WasStolen: Boolean;
	msg: String;
begin
	{ First - check to see whether or not the item is stolen. }
	{ Most shopkeepers won't buy stolen goods. The PC has to locate }
	{ a fence for illicit transactions. }
	WasStolen := NAttValue( Part^.NA , NAG_NArrative , NAS_Stolen ) <> 0;
	if WasStolen then begin
		N := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Lawful );
		Cost := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Heroic );
		if Cost > 0 then N := N + Cost;
		if N >= 0 then begin
			{ This shopkeeper won't buy stolen items. }

			CHAT_Message := MsgString( 'SERVICES_StolenResponse' );

			DialogMsg( MsgString( 'SERVICES_StolenDesc' ) );

			{ If the shopkeeper doesn't already hate the PC, }
			{ then the PC's reputation and relation scores }
			{ may both get damaged. }
			if ( PC <> Nil ) and ( NAttValue( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_PErsonal , NAS_CID ) ) >= -20 ) then begin
				AddReputation( PC , 2 , -1 );
				if N > Random( 200 ) then AddReputation( PC , 6 , -1 );
				AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_PErsonal , NAS_CID ) , -( Random( 6 ) + 1 ) );
			end;

			Exit( False );
		end;
	end;

	Cost := GearCost( Part );
	if Destroyed( Part ) then Cost := Cost div 3;

	{ If this part matches the category of the shopkeeper, it's worth more money. }
	{ Actually, it works so that selling inappropriate items are penalized. }
	if not ( ( Part^.Scale < 1 ) and PartAtLeastOneMatch ( Categories , SAttValue( Part^.Sa , 'CATEGORY' ) ) ) then begin
		Cost := ( Cost * 2 ) div 3;
	end;

	{ Determine shopping rank. }
	ShopRk := SkillValue( PC , 21 );

	{ Determine shopping target. }
	if ( NPC = Nil ) or ( NPC^.G <> GG_Character ) then ShopTr := 10
	else begin
		{ Target is based on both the Ego of the shopkeeper }
		{ and also on the relationship with the PC. }
		ShopTr := NPC^.Stat[ STAT_Ego ];
		R := ReactionScore( Nil , PC , NPC );
		if R > 0 then begin
			ShopTr := ShopTr - ( R div 5 );
		end else if R < 0 then begin
			{ It's much harder to haggle if the shopkeep }
			{ doesn't like you. }
			ShopTr := ShopTr + Abs( R ) div 2;
		end;
	end;

	{ Every point of shopping skill that the unit has }
	{ gives a 1% bonus to the money gained. }
	ShopRk := ShopRk - ShopTR;
	if ShopRk > 40 then ShopRk := 40
	else if ShopRk < 0 then ShopRk := 0;

	Cost := ( Cost * (20 + ShopRk ) ) div 100;
	if Cost < 1 then Cost := 1;

	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
	AddRPGMenuItem( YNMenu , 'Sell ' + GearName( Part ) + ' ($' + BStr( Cost ) + ')' , 1 );
	AddRPGMenuItem( YNMenu , 'Maybe later' , -1 );

	{ Query the menu - Sell it or not? }
	msg := MSgString( 'SELLPROMPT' + Bstr( Random( 4 ) + 1 ) );
	msg := ReplaceHash( msg , BStr( Cost ) );
	msg := ReplaceHash( msg , GearName( Part ) );

	CHAT_Message := Msg;
	SERV_Menu := Nil;
	SERV_Info := Part;
	N := SelectMenu( YNMenu , @ServiceRedraw );

	if N = 1 then begin
		{ Increase the buyer's cash by the price of the gear. }
		AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cost );


		CHAT_Message := MSgString( 'SELLREPLY' + Bstr( Random( 4 ) + 1 ) );

		DialogMSG( 'You have sold ' + GearName( Part ) + ' for $' + BStr( Cost ) + '.' );

		{ If the item was stolen, trash the PC's reputation here. }
		if WasStolen then begin
			AddReputation( PC , 2 , -5 );
		end;

		RemoveGear( LList , Part );
	end else begin

		CHAT_Message := MSgString( 'SELLCANCEL' + Bstr( Random( 4 ) + 1 ) );

	end;

	DisposeRPGMenu( YNMenu );
	SERV_Info := Nil;

	SellGear := N = 1;
end;



Function RepairMasterCost( Master: GearPtr; Skill: Integer ): LongInt;
	{ Return the expected cost of repairing every component of }
	{ MASTER which can be handled using SKILL. }
var
	it: LongInt;
begin
	it := TotalRepairableDamage( Master , SKill ) * CredsPerDP;

	{ Since parts that could be helped by First Aid heal by themselves }
	{ usually, the cost to treat injuries using the First Aid skill is }
	{ substantially reduced. }
	if ( Skill = 20 ) and ( it > 0 ) then begin
		it := it div 2;
		if it < 1 then it := 1;
	end;

	RepairMasterCost := it;
end;

Function RepairAllCost( GB: GameBoardPtr; Skill: Integer ): LongInt;
	{ Determine the cost of repairing every item belonging to Team 1. }
var
	Part: GearPtr;
	Cost: longInt;
begin
	{ Initialize values. }
	Part := GB^.Meks;
	Cost := 0;

	{ Browse through each gear on the board, adding the cost to repair }
	{ each Team 1 mek or character. }
	while Part <> Nil do begin
		if ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then begin
			{ Only repair mecha which have pilots assigned!!! }
			{ If the PC had to patch up all that salvage every time... Brr... }
			if ( Part^.G <> GG_Mecha ) or ( SAttValue( Part^.SA , 'PILOT' ) <> '' ) then begin
				Cost := Cost + RepairMasterCost( Part , Skill );
			end;
		end;

		Part := Part^.Next;
	end;

	RepairAllCost := Cost;
end;

Procedure DoRepairMaster( GB: GameBoardPtr; Master,Repairer: GearPtr; Skill: Integer );
	{ Remove the damage counters from every component of MASTER which }
	{ can be affected using the provided SKILL. }
var
	TRD: LongInt;
begin
	{ Repair this part, if appropriate. }
	TRD := TotalRepairableDamage( Master , SKill );
	ApplyRepairPoints( Master , Skill , TRD );

	{ Wait an amount of time, depending on the repairer's skill }
	{ level. }
	QuickTime( GB , AP_Minute + RollStep( 12 ) - SkillValue( Repairer , SKill ) );
end;

Procedure DoRepairAll( GB: GameBoardPtr; NPC: GearPtr; Skill: Integer );
	{ Repair every item belonging to Team 1. }
var
	Part: GearPtr;
begin
	{ Initialize values. }
	Part := GB^.Meks;

	{ Browse through each gear on the board, repairing }
	{ each Team 1 mek or character. }
	while Part <> Nil do begin
		if ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then begin
			{ Only repair mecha which have pilots assigned!!! }
			{ If the PC had to patch up all that salvage every time... Brr... }
			if ( Part^.G <> GG_Mecha ) or ( SAttValue( Part^.SA , 'PILOT' ) <> '' ) then begin
				DoRepairMaster( GB , Part , NPC , Skill );
			end;
		end;

		Part := Part^.Next;
	end;
end;

Procedure RepairAllFrontEnd( GB: GameBoardPtr; PC, NPC: GearPtr; Skill: Integer );
	{ Run the REPAIR ALL procedure, and charge the PC for the work done. }
	{ If the PC doesn't have enough money to repair everything roll to }
	{ see if the NPC will do this work for free. }
const
	NumRepairSayings = 5;
var
	msg: String;
	Cost,Cash: LongInt;
	R: Integer;
begin
	{ Determine the cost of repairing everything, and also }
	{ the amount of cash the PC has. }
	Cost := ScalePrice( PC , NPC , RepairAllCost( GB , Skill ) );
	Cash := NAttValue( PC^.NA, NAG_Experience , NAS_Credits );
	R := ReactionScore( Nil , PC , NPC );
	msg := '';

	{ See whether or not the PC will be charged for this repair. }
	{ If the NPC likes the PC well enough, the service will be free. }
	if ( Random( 150 ) + 10 ) < R then begin
		{ The NPC will do the PC a favor, and do this one for free. }
		msg := MsgString( 'SERVICES_RAFree' );
		Cost := 0;
	end else if ( Cash < Cost ) and ( R > ( 10 + NPC^.Stat[ STAT_Ego ] ) ) then begin
		msg := MsgString( 'SERVICES_RACantPay' );
		AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) , -Random( 10 ) );
		Cost := 0;
	end;

	if Cost < Cash then begin
		DoRepairAll( GB , NPC , Skill );
		AddNAtt( PC^.NA, NAG_Experience , NAS_Credits , -Cost );
		if msg = '' then msg := MsgString( 'SERVICES_RADoRA' + BStr( Random( NumRepairSayings ) + 1 ) );
	end else begin
		msg := MsgString( 'SERVICES_RALousyBum' );
	end;


	CHAT_Message := msg;

end;

Procedure RepairOneFrontEnd( GB: GameBoardPtr; Part, PC, NPC: GearPtr; Skill: Integer );
	{ Run the REPAIR MASTER procedure, and charge the PC for the work done. }
	{ If the PC doesn't have enough money to repair everything roll to }
	{ see if the NPC will do this work for free. }
const
	NumRepairSayings = 5;
var
	Cost,Cash: LongInt;
	R: Integer;
begin
	{ Determine the cost of repairing everything, and also }
	{ the amount of cash the PC has. }
	Cost := ScalePrice( PC , NPC , RepairMasterCost( PArt , Skill ) );
	Cash := NAttValue( PC^.NA, NAG_Experience , NAS_Credits );
	R := ReactionScore( Nil , PC , NPC );

	{ See whether or not the PC will be charged for this repair. }
	{ If the NPC likes the PC well enough, the service will be free. }
	if ( Random( 90 ) + 10 ) < R then begin
		{ The NPC will do the PC a favor, and do this one for free. }
		CHAT_Message := MsgString( 'SERVICES_RAFree' );
		Cost := 0;
	end else if ( Cash < Cost ) and ( R > 10 ) then begin
		CHAT_Message := MsgString( 'SERVICES_RACantPay' );
		AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) , -Random( 5 ) );
		Cost := 0;
	end;

	if Cost < Cash then begin
		DoRepairMaster( GB , Part , NPC , Skill );
		AddNAtt( PC^.NA, NAG_Experience , NAS_Credits , -Cost );

		CHAT_Message := MSgString( 'SERVICES_RADoRA' + BStr( Random( NumRepairSayings ) + 1 ) );

	end else begin
		CHAT_Message := MsgString( 'SERVICES_RALousyBum' );
	end;
end;

Function ReloadMagazineCost( Mag: GearPtr ): LongInt;
	{ Calculate the cost of reloading this magazine. }
var
	Spent: Integer;
	it: LongInt;
begin
	it := 0;
	if Mag^.G = GG_Ammo then begin
		Spent := NAttValue( Mag^.NA , NAG_WeaponModifier , NAS_AmmoSpent );
		if Spent > 0 then begin
			it := ( ComponentValue( Mag , True , True ) * Spent ) div Mag^.Stat[ STAT_AmmoPresent ];
			if it < 5 then it := 5;
		end;
	end;

	if it > 0 then begin
		{ Reduce the reload cost by a factor of 5- apparently, magazines are really expensive. }
		it := it div 5;
		if it < 1 then it := 1;
	end;

	ReloadMagazineCost := it;
end;

Function ReloadMasterCost( M: GearPtr; ReloadGeneralInv: Boolean ): LongInt;
	{ Return the cost of refilling all magazines held by M. }
var
	Part: GearPtr;
	it: LongInt;
begin
	it := ReloadMagazineCost( M );

	Part := M^.SubCom;
	while Part <> Nil do begin
		it := it + ReloadMasterCost( Part , ReloadGeneralInv );
		Part := Part^.Next;
	end;

	if ReloadGeneralInv or not IsMasterGear( M ) then begin
		Part := M^.InvCom;
		while Part <> Nil do begin
			it := it + ReloadMasterCost( Part , ReloadGeneralInv );
			Part := Part^.Next;
		end;
	end;

	ReloadMasterCost := it;
end;

Procedure DoReloadMaster( M: GearPtr; ReloadGeneralInv: Boolean );
	{ Clear all ammo usage by M. }
var
	Part: GearPtr;
begin
	{ If this is an ammunition gear, set the number of shots fired to 0. }
	if M^.G = GG_Ammo then SetNAtt( M^.NA , NAG_WeaponModifier , NAS_AmmoSpent , 0 );

	{ Check SubComs and InvComs. }
	Part := M^.SubCom;
	while Part <> Nil do begin
		DoReloadMaster( Part , ReloadGeneralInv );
		Part := Part^.Next;
	end;
	if ReloadGeneralInv or not IsMasterGear( M ) then begin
		Part := M^.InvCom;
		while Part <> Nil do begin
			DoReloadMaster( Part , ReloadGeneralInv );
			Part := Part^.Next;
		end;
	end;
end;

Function ReloadCharsCost( GB: GameBoardPtr; PC,NPC: GearPtr; ReloadGeneralInv: Boolean ): LongInt;
	{ Calculate the cost of reloading every PC's ammunition. }
var
	it: LongInt;
	Part: GearPtr;
begin
	it := 0;
	Part := GB^.Meks;
	while Part <> Nil do begin
		if ( ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) ) and ( Part^.G = GG_Character ) then begin
			it := it + ReloadMasterCost( Part , ReloadGeneralInv );
		end;
		Part := Part^.Next;
	end;

	{ SCale the price for the PC's shopping skill. }
	if it > 0 then it := ScalePrice( PC , NPC , it );

	ReloadCharsCost := it;
end;

Procedure DoReloadChars( GB: GameBoardPtr; PC,NPC: GearPtr; ReloadGeneralInv: Boolean );
	{ Calculate the cost of reloading every PC's ammunition. }
var
	COst: LongInt;
	Part: GearPtr;
begin
	Cost := ReloadCharsCost( GB , PC , NPC , ReloadGeneralInv );
	if Cost <= NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) then begin
		Part := GB^.Meks;
		while Part <> Nil do begin
			if ( ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) ) and ( Part^.G = GG_Character ) then begin
				DoReloadMaster( Part , ReloadGeneralInv );
			end;
			Part := Part^.Next;
		end;

		AddNAtt( PC^.NA, NAG_Experience , NAS_Credits , -Cost );

		{ Print the message. }
		CHAT_Message := MsgString( 'SERVICES_ReloadChars' );

	end else begin
		{ Player can't afford the reload. }

		CHAT_Message := MsgString( 'SERVICES_RALousyBum' );

	end;
end;

Function ReloadMechaCost( GB: GameBoardPtr; PC,NPC: GearPtr; ReloadGeneralInv: Boolean ): LongInt;
	{ Calculate the cost of reloading every mek's ammunition. }
var
	it: LongInt;
	Part: GearPtr;
begin
	it := 0;
	Part := GB^.Meks;
	while Part <> Nil do begin
		if ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ( Part^.G = GG_Mecha ) then begin
			it := it + ReloadMasterCost( Part , ReloadGeneralInv );
		end;
		Part := Part^.Next;
	end;

	{ SCale the price for the PC's shopping skill. }
	if it > 0 then it := ScalePrice( PC , NPC , it );

	ReloadMechaCost := it;
end;

Procedure DoReloadMecha( GB: GameBoardPtr; PC,NPC: GearPtr; ReloadGeneralInv: Boolean );
	{ Calculate the cost of reloading every PC's ammunition. }
var
	COst: LongInt;
	Part: GearPtr;
begin
	Cost := ReloadMechaCost( GB , PC , NPC , ReloadGeneralInv );
	if Cost <= NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) then begin
		Part := GB^.Meks;
		while Part <> Nil do begin
			if ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ( Part^.G = GG_Mecha ) then begin
				DoReloadMaster( Part , ReloadGeneralInv );
			end;
			Part := Part^.Next;
		end;

		AddNAtt( PC^.NA, NAG_Experience , NAS_Credits , -Cost );

		{ Print the message. }
		CHAT_Message := MsgString( 'SERVICES_ReloadMeks' );

	end else begin
		{ Player can't afford the reload. }

		CHAT_Message := MsgString( 'SERVICES_RALousyBum' );

	end;
end;


Function RechargeCost( GB: GameBoardPtr; PC,NPC: GearPtr ): LongInt;
	{ Calculate the cost of reloading every PC's ammunition. }
	Function RechargeTrackCost( Part: GearPtr ): LongInt;
		{ Return the number of spent power points along this track and counting all children. }
	var
		it: LongInt;
	begin
		it := 0;
		while Part <> Nil do begin
			it := it + NAttValue( Part^.NA , NAG_Condition , NAS_PowerSpent ) + RechargeTrackCost( Part^.SubCom ) + RechargeTrackCost( Part^.InvCom );
			Part := Part^.Next;
		end;
		RechargeTrackCost := it;
	end;
var
	it: LongInt;
	Part: GearPtr;
begin
	it := 0;
	Part := GB^.Meks;
	while Part <> Nil do begin
		if ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then begin
			it := it + NAttValue( Part^.NA , NAG_Condition , NAS_PowerSpent ) + RechargeTrackCost( Part^.SubCom ) + RechargeTrackCost( Part^.InvCom );
		end;
		Part := Part^.Next;
	end;

	if it > 0 then begin
		{ Every 100 points of power costs 1 credit. }
		it := it div 100;
		if it < 1 then it := 1;

		{ SCale the price for the PC's shopping skill. }
		it := ScalePrice( PC , NPC , it );
	end;

	RechargeCost := it;
end;

Procedure DoRecharge( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ Recharge the PC's power sources. }
	Procedure DoRechargeTrack( Part: GearPtr );
		{ Recharge everything along this track. }
	begin
		while Part <> Nil do begin
			SetNAtt( Part^.NA , NAG_Condition , NAS_PowerSpent , 0 );
			DoRechargeTrack( Part^.SubCom );
			DoRechargeTrack( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;
var
	COst: LongInt;
	Part: GearPtr;
begin
	Cost := RechargeCost( GB , PC , NPC );
	if Cost <= NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) then begin
		Part := GB^.Meks;
		while Part <> Nil do begin
			if ( NATtVAlue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then begin
				SetNAtt( Part^.NA , NAG_Condition , NAS_PowerSpent , 0 );
				DoRechargeTrack( Part^.SubCom );
				DoRechargeTrack( Part^.InvCom );
			end;
			Part := Part^.Next;
		end;

		AddNAtt( PC^.NA, NAG_Experience , NAS_Credits , -Cost );

		{ Print the message. }
		CHAT_Message := MsgString( 'SERVICES_DoRecharge' );

	end else begin
		{ Player can't afford the recharge. }
		CHAT_Message := MsgString( 'SERVICES_RALousyBum' );
	end;
end;

Function ItemShopWeight( I: GearPtr ): Integer;
	{ This is the log base two of the gear's unscaled cost. }
var
	Cost: LongInt;
	N: Integer;
begin
	{ First, determine what the unscaled price is. }
	Cost := GearCost( I );

	{ If I is a set, cost will be the average of all items in the set. }
	if I^.G = GG_Set then begin
		N := NumSiblingGears( I^.SubCom ) + NumSiblingGears( I^.InvCom );
		if N > 0 then Cost := Cost div N;
	end;

	N := I^.Scale;
	{ SF:1 items are 10x more expensive than SF:0 items. After that }
	{ it costs x5 per scale factor. }
	if N > 0 then Cost := Cost div 2;
	while N > 0 do begin
		Dec( N );
		Cost := Cost div 5;
	end;

	{ Sets have a weight equal to the average of the parts in them. }
	N := NumSiblingGears( I^.SubCom ) + NumSiblingGears( I^.InvCom );
	if N > 0 then Cost := Cost div N;

	{ Determine the Log base 2 of the item... this will be }
	{ the target number to decide whether or not the shopkeep }
	{ might have this item. }
	{ Because mecha are so expensive, take the log base two of their }
	{ cost divided by ten. }
	if I^.G = GG_Mecha then Cost := Cost div 10;

	{ Calculate the log here. }
	N := 0;
	while Cost > 2 do begin
		Inc( N );
		Cost := Cost div 2;
	end;
	ItemShopWeight := N;
end;

Function NotGoodWares( GB: GameBoardPtr; I , NPC: GearPtr; Stuff: String; Tolerance: LongInt ): Boolean;
	{ Return TRUE if this item is inappropriate for NPC's shop, }
	{ FALSE if it is. An item is appropriate if: }
	{ - one of its CATEGORY tags may be found in STUFF. }
	{ - its unscaled value doesn't exceed the shopkeep's rating. }
	{ - its faction is either the storekeeper or the town's faction. }
	{ - its modified legality level is greater or equal to the town's level. }
const
	LowLegalityLevel = 0;
var
	NGW: Boolean;
	Tag,Category,Desc: String;
	N: LongInt;
	Scene,Fac: GearPtr;
begin
	{ Begin by assuming TRUE. }
	NGW := True;

	{ Search through STUFF to see if Item's type matches the CATEGORY. }
	Category := SAttValue( I^.SA , 'CATEGORY' );
	NGW := not PartAtLeastOneMatch ( Stuff , Category );

	Scene := FindRootScene( GB , GB^.Scene );

	{ Make sure this item is cleared for the shopkeeper's faction, and the faction }
	{ of the city. Items marked with the GENERAL tag are clear for all factions. }
	if not NGW then begin
		N := 0;
		desc := 'GENERAL';
		Fac := SeekFaction( GB^.Scene , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
		if Fac <> Nil then desc := SAttValue( Fac^.SA , 'DESIG' ) + ' ' + desc;

		{ Scene here points to the root scene. }
		if ( Scene <> Nil ) and ( Fac = Nil ) then begin
			Fac := SeekFaction( GB^.Scene , NAttValue( Scene^.NA , NAG_Personal , NAS_FactionID ) );
			if Fac <> Nil then desc := SAttValue( Fac^.SA , 'DESIG' ) + ' ' + desc;
		end;
		Category := SAttValue( I^.SA , 'FACTIONS' );
		while Category <> '' do begin
			Tag := ExtractWord( Category );
			if AStringHasBString( desc , Tag ) then Inc( N );
		end;
		{ If there wasn't at least one faction match, this item is no good. }
		NGW := N < 1;
	end;

	{ Make sure this item is legal. }
	{ Mecha don't have to be checked for legality. }
	if ( Scene <> Nil ) and ( I^.G <> GG_Mecha ) and not NGW then begin
		{ Scene should point to the root scene here, since we found it above. }
		{ If the current scene is marked for a modified legality level, }
		{ use the local tolerance value instead. }

		NGW := NAttValue( I^.NA , NAG_GearOps , NAS_Legality ) > Tolerance;
	end;

	if not NGW then begin
		{ Determine the unscaled cost of this item. }
		N := ItemShopWeight( I );
		if RollStep( SkillValue( NPC , 21 ) ) < N then NGW := True;

	end;

	NotGoodWares := NGW;
end;

Procedure AddSomeMeks( GB: GameBoardPtr; NPC: GearPtr; var Wares: GearPtr );
	{ WARES is the inventory list of a shop. Let's add ~10 mecha files }
	{ to the list. }
var
	Fac,Mek: GearPtr;
	ShopList,MekFile: SAttPtr;
	N: Integer;
	mecha_colors: String;
begin
	{ To start with, determine this merchant's lot color. This is the color all }
	{ the mecha in the sales lot are painted. If the NPC has a faction this will }
	{ be the faction color. Otherwise, check to see if he has a color stored. }
	{ Otherwise pick a color scheme at random and save it. }
	mecha_colors := SAttValue( NPC^.SA , 'mecha_colors' );
	if mecha_colors = '' then begin
		Fac := SeekFaction( GB^.Scene , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
		if Fac <> Nil then mecha_colors := SAttValue( Fac^.SA , 'mecha_colors' );
		if mecha_colors = '' then begin
			mecha_colors := standard_lot_colors[ random( num_standard_schemes ) ];
		end;
		SetSAtt( NPC^.SA , 'mecha_colors <' + mecha_colors + '>' );
	end;

	ShopList := CreateFileList( Design_Directory + Default_Search_Pattern );

	{ From the list of filenames, pick a number of them at random. }
	N := 20;
	while ( N > 0 ) and ( ShopList <> Nil ) do begin
		MekFile := SelectRandomSAtt( ShopList );

		{ Load this file }
		Mek := LoadSingleMecha( MekFile^.Info , Design_Directory );

		{ Remove this SAtt from the list, so we don't load it twice. }
		RemoveSAtt( ShopList , MekFile );

		{ Attach the loaded mek to the end of WARES. }
		if ( Mek <> Nil ) and ( Mek^.G = GG_Mecha ) then begin
			AppendGear( Wares , Mek );

			{ NEW v0.310- If the storekeeper knows MECHA ENGINEERING, maybe }
			{ modify this mecha! }
			if ( Random( 2 ) = 1 ) and ( NAttValue( NPC^.NA , NAG_Skill , NAS_MechaEngineering ) > 0 ) then begin
				ShopkeeperModifyMek( NPC , Mek );
			end;

			SetSAtt( Mek^.SA , 'sdl_colors <' + mecha_colors + '>' );
			SetSAtt( Mek^.SA , 'CATEGORY <MECHA>' );
		end else begin
			DisposeGear( Mek );
		end;
	end;

	{ Get rid of the shopping list. }
	DisposeSAtt( ShopList );
end;

Function CreateWaresList( GB: GameBoardPtr; NPC: GearPtr; Stuff: String ): GearPtr;
	{ Fabricate the list of items this NPC has for sale. }
var
	Scene,Wares,I,I2: GearPtr;	{ List of items for sale. }
	NPCSeed,NPCRestock,Tolerance: LongInt;
	TotalSP,MaxSP: Integer;
begin
	{ Set the random seed to something less than random... }
	NPCSeed := NAttValue( NPC^.NA , NAG_PErsonal , NAS_RandSeed );
	NPCRestock := NAttValue( NPC^.NA , NAG_PErsonal , NAS_RestockTime );
	if NPCSeed = 0 then begin
		NPCSeed := Random( 2000000000 ) + 1;
		NPCRestock := Random( 86400 ) + 1;
		SetNAtt( NPC^.NA , NAG_PErsonal , NAS_RandSeed , NPCSeed );
		SetNAtt( NPC^.NA , NAG_PErsonal , NAS_RestockTime , NPCRestock );
	end;
	RandSeed := ( ( GB^.ComTime + NPCRestock ) div 86400 ) + NPCSeed;

	{ Read the basic items list, then filter it for appropriate }
	{ wares afterwards. }
	Wares := AggregatePattern( PC_Equipment_Pattern , Design_Directory );

	{ If this is a mecha shop, also load some mecha files. }
	if AStringHasBString( Stuff , 'MECHA' ) then begin
		AddSomeMeks( GB , NPC , Wares );
	end;

	{ Calculate the shopkeeper's tolerance. }
	Tolerance := ShopTolerance( GB , NPC );

	{ Do filtering here. }
	I := Wares;
	while I <> Nil do begin
		I2 := I^.Next;

		{ If this isn't a good item for this shop, remove it. }
		{ Otherwise increment the item counter. }
		if NotGoodWares( GB , I , NPC , Stuff , Tolerance ) then RemoveGear( Wares , I );

		I := I2;
	end;

	{ If N is too large for this shopkeeper, remove a number of items }
	{ from the inventory. }
	{ GH2: Inventory size is determined by the NPC's shopping skill. }
	I := Wares;
	TotalSp := 0;
	MaxSp := SkillValue( NPC , 21 ) * 10 + 5;
	while I <> Nil do begin
		TotalSP := TotalSP + ItemShopWeight( I );
		I := I^.Next;
	end;
	while TotalSP > MaxSP do begin
		I := SelectRandomGear( Wares );
		TotalSP := TotalSP - ItemShopWeight( I );
		RemoveGear( Wares , I );
	end;

	{ Re-randomize the random seed. }
	Randomize;

	{ Return the list we've created. }
	CreateWaresList := Wares;
end;

Procedure BrowseWares( GB: GameBoardPtr; PC,NPC: GearPtr; Wares: GearPtr );
	{ Take a look through the items this NPC has for sale. }
	{ First, construct the shop list. Then, browse each item, }
	{ potentially buying whichever one strikes your fancy. }
var
	RPM: RPGMenuPtr;	{ Buying menu. }
	I: GearPtr;
	N: Integer;
	msg: String;
begin

	{ Create the browsing menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
	I := Wares;

	SERV_Menu := RPM;
	SERV_Info := Wares;

	N := 1;
	while I <> Nil do begin
		msg := FullGearName( I );

		{ Add extra information, depending upon item type. }
		if I^.G = GG_Weapon then begin
			msg := msg + '  (DC:' + BStr( ScaleDC( I^.V , I^.Scale ) ) + ')';
		end else if ( I^.G = GG_ExArmor ) or ( I^.G = GG_Shield ) then begin
			msg := msg + '  [AC:' + BStr( GearMaxArmor( I ) ) + ']';
		end else if I^.G = GG_Consumable then begin
			msg := msg + '  (' + BStr( I^.Stat[ STAT_FoodQuantity ] ) + ')';
		end else if I^.G = GG_Ammo then begin
			msg := msg + '  (' + BStr( I^.Stat[ STAT_AmmoPresent ] ) + ')';
		end else if I^.G = GG_Software then begin
			msg := 'SW: ' + msg;
		end;

		{ Add extra information, depending upon item scale. }
		if ( I^.G <> GG_Mecha ) and ( I^.Scale > 0 ) then begin
			msg := msg + '(SF' + BStr( I^.Scale ) + ')';
		end;

		{ Pad the message. }
{$IFDEF ASCII}
		while Length( msg + ' $' + BStr( PurchasePrice( PC , NPC , I ) ) ) < ( ZONE_ShopMenu.W - 5 ) do msg := msg + ' ';
{$ELSE}
		while TextLength( GAME_FONT , ( msg + ' $' + BStr( PurchasePrice( PC , NPC , I ) ) ) ) < ( ZONE_ShopMenu.W - 50 ) do msg := msg + ' ';
{$ENDIF}

		{ Add it to the menu. }
		AddRPGMenuItem( RPM , msg + ' $' + BStr( PurchasePrice( PC , NPC , I ) ) , N );
		Inc( N );
		I := I^.Next;
	end;
	RPMSortAlpha( RPM );

	{ Error check - if for some reason we are left with a blank }
	{ menu, better leave this procedure. }
	if RPM^.NumItem < 1 then begin
		DisposeRPGMenu( RPM );
		Exit;
	end;

	RPM^.Mode := RPMNoCleanup;

	Repeat
		{ Display the trading stats. }
		N := SelectMenu( RPM , @ServiceRedraw );

		if N > 0 then begin
			PurchaseGearMenu( GB , PC , NPC , RetrieveGearSib( Wares , N ) );
		end;

	until N = -1;


	SERV_Menu := Nil;
	SERV_Info := Nil;

	DisposeRPGMenu( RPM );
end;

Procedure SellStuff( GB: GameBoardPtr; PCInv,PCChar,NPC: GearPtr; const Categories: String );
	{ The player wants to sell some items to this NPC. }
	{ PCInv points to the team-1 gear whose inventory is to be sold. }
	{ PCChar points to the actual player character. }
var
	RPM: RPGMenuPtr;
	MI,N: Integer;
	Part : GearPtr;
begin
	MI := 1;
	repeat
		{ Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
		RPM^.Mode := RPMNoCleanup;
		BuildInventoryMenu( RPM , PCInv );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Exit' ) , -1 );

		SetItemByPosition( RPM , MI );

		{ Get a choice from the menu, then record the current item }
		{ number. }

		SERV_Menu := RPM;
		SERV_Info := PCInv;

		N := SelectMenu( RPM , @SellStuffRedraw );

		MI := RPM^.SelectItem;

		{ Dispose of the menu. }
		DisposeRPGMenu( RPM );

		{ If N is positive, prompt to sell that item. }
		if N > -1 then begin
			Part := LocateGearByNumber( PCInv , N );
			SellGear( Part^.Parent^.InvCom , Part , PCChar , NPC , Categories );
		end;

	until N = -1;
	SERV_Menu := Nil;
	SERV_Info := Nil;
end;


Procedure ThisMechaWasSelected( GB: GameBoardPtr; MekNum: Integer; PC,NPC: GearPtr );
	{ Do all the standard shopping options with this mecha. }
	{ IMPORTANT: A mecha can only be sold if it's not currently on the map! }
	{ Otherwise, the PC could potentially sell himself if in the cockpit... }
var
	RPM: RPGMenuPtr;
	Mek: GearPtr;
	N: Integer;
begin
	{ Find the mecha. }
	Mek := RetrieveGearSib( GB^.Meks , MekNum );

	repeat
		{ Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );

		{ Add options, depending on the mek. }
		if not OnTheMap( GB , Mek ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_Sell' ) + GearName( Mek ) , 1 );
		if TotalRepairableDamage( Mek , 15 ) > 0 then AddRPGMenuItem( RPM , MsgString( 'SERVICES_OSRSP15' ) + ' [$' + BStr( RepairMasterCost( Mek , 15 ) ) + ']' , 2 );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_SellMekInv' ) , 4 );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_BrowseParts' ) , 3 );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Exit' ) , -1 );

		SERV_Menu := Nil;
		SERV_Info := Mek;
		N := SelectMenu( RPM , @ServiceRedraw );

		DisposeRPGMenu( RPM );

		if N = 1 then begin
			{ Sell the mecha. }
			if SellGear( GB^.Meks , Mek , PC , NPC , '' ) then N := -1;

		end else if N = 2 then begin
			{ Repair the mecha. }
			RepairOneFrontEnd( GB , Mek , PC , NPC , 15 );

		end else if N = 3 then begin
			{ Use the parts browser. }

			MechaPartBrowser( Mek , @ServiceRedraw );


		end else if N = 4 then begin
			{ Sell items. }
			SellStuff( GB , Mek , PC , NPC , '' );

		end;

	until N = -1;
	SERV_Info := Nil;
end;

Function CreateMechaMenu( GB: GameBoardPtr ): RPGMenuPtr;
	{ Create a menu listing all the Team1 meks on the board. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	Mek: GearPtr;
	msg: String;
begin
	{ Allocate a menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );

	{ Add each mek to the board. }
	N := 1;
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		{ If this gear is a mecha, and it belongs to the PC, }
		{ add it to the menu. }
		if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and not GearActive( Mek ) then begin
			msg := FullGearName( Mek );
			AddRPGMenuItem( RPM , msg , N );
		end;

		Inc( N );
		Mek := Mek^.Next;
	end;

	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MsgString( 'SERVICES_Exit' ) , -1 );

	CreateMechaMenu := RPM;
end;

Procedure BrowseMecha( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ The Player is going to take a look through his mecha list, maybe }
	{ sell some of them, maybe repair some of them... }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	repeat
		{ Create the browsing menu. }
		RPM := CreateMechaMenu( GB );

		{ Select an item from the menu, then get rid of the menu. }

		SERV_Info := GB^.Meks;
		SERV_Menu := RPM;
		N := SelectMenu( RPM , @ServiceRedraw );

		DisposeRPGMenu( RPM );

		{ If a mecha was selected, take a look at it. }
		if N > 0 then begin
			ThisMechaWasSelected( GB , N , PC , NPC );
		end;
	until N = -1;
	SERV_Info := Nil;
	SERV_Menu := Nil;
end;

Procedure InstallCyberware( GB: GameBoardPtr; PC , NPC: GearPtr );
	{ The NPC will attempt to install cyberware into the PC. }
	{ - The PC will select which item to install. }
	{ - If appropriate, the PC will select where to install. }
	{ - NPC will make rolls to reduce trauma rating of part. }
	{ - Time will be advanced by 6 hours. }
	{ - Part will be transferred and installed. }
	const
		RT_Average = 2;
		RT_Good = 3;
		RT_Bad = 1;

	Procedure ClearCyberSlot( Slot,Item: GearPtr );
		{ Clear any items currently using ITEM's CyberSlot }
		{ from Slot's list of subcomponents. }
	var
		SC,SC2: GearPtr;
		CyberSlot: String;
	begin
		CyberSlot := UpCase( SAttValue( Item^.SA , SAtt_CyberSlot ) );
		if CyberSlot <> '' then begin
			SC := Slot^.SubCom;
			while SC <> Nil do begin
				SC2 := SC^.Next;

				if UpCase( SAttValue( SC^.SA , SAtt_CyberSlot ) ) = CyberSlot then begin
					RemoveGear( Slot^.SubCom , SC );
				end;

				SC := SC2;
			end;
		end;
	end;

	Function ReduceTrauma( Item: GearPtr ): Integer;
		{ As part of the deal, the cyberdoc will attempt to }
		{ lower the trauma cost of this item. }
	var
		T,SkRoll,V0: Integer;
	begin
		{ Only modifier gears have trauma values, and not even }
		{ all of those... better make sure. }
		if ( Item^.G = GG_Modifier ) and ( Item^.V > 0 ) then begin
			{ Initial trauma will be affected by the PC's }
			{ psychological predisposition. }
			T := NAttValue( PC^.NA , NAG_CharDescription , NAS_Pragmatic );
			if T > 0 then begin
				Item^.V := Item^.V * ( 400 - T ) div 400;
			end else if T < 0 then begin
				{ Spiritual characters are more heavily }
				{ traumatized by cyberware. }
				Item^.V := Item^.V + ( Abs( T ) div 2 );
			end;

			{ The NPC gets three rolls to reduce the trauma. }
			V0 := Item^.V;
			SkRoll := 0;
			for t := 1 to 3 do begin
				SkRoll := SkRoll + RollStep( SkillValue( NPC , 24 ) );
			end;
			if SkRoll > Item^.V then begin
				Item^.V := Item^.V - ( SkRoll - Item^.V );
				if Item^.V < 1 then Item^.V := 1;
			end;

			if Item^.V = 1 then begin
				ReduceTrauma := RT_Good;
			end else if Item^.V < ( V0 div 2 ) then begin
				ReduceTrauma := RT_Average;
			end else begin
				ReduceTrauma := RT_Bad;
			end;

		end else begin
			ReduceTrauma := RT_Average;
		end;
	end;

var
	RPM: RPGMenuPtr;
	N: Integer;
	Item,Slot: GearPtr;

	Procedure CreateCyberMenu;
		{ Check through PC's inventory, adding items which bear }
		{ the "CYBER" tag to the menu. }
	var
		Part: GearPtr;
	begin
		Part := LocatePilot( PC )^.InvCom;
		while Part <> Nil do begin
			if AStringHasBString( SAttValue( Part^.SA , 'TYPE' ) , 'CYBER' ) then begin
				AddRPGMenuItem( RPM , GearName( Part ) , FindGearIndex( PC , Part ) );
			end;
			Part := Part^.Next;
		end;
	end;

	Function WillingToPay: Boolean;
		{ The name is a bit misleading. This function checks to }
		{ see if the PC can pay, then if the PC agrees to the }
		{ price will then take his money. }
	var
		Cost: LongInt;
	begin
		Cost := SkillAdvCost( Nil , NAttValue( NPC^.NA , NAG_Skill , 24 ) ) * 2;
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Cyber_Pay_Yes' ) , 1 );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Cyber_Pay_No' ) , -1 );

		CHAT_Message := ReplaceHash( MsgString( 'SERVICES_Cyber_Pay' ) , BStr( Cost ) );
		N := SelectMenu( RPM , @ServiceRedraw );

		DisposeRPGMenu( RPM );

		if N = 1 then begin
			if NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
				AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -Cost );
				WillingToPay := True;
			end else begin
				WillingToPay := False;
			end;
		end else begin
			WillingToPay := False;
		end;
	end;

	Procedure PerformInstallation;
		{ Actually stick the part into the PC. }
	var
		Result: Integer;
	begin
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Cyber_WaitPrompt' ) , -1 );
		ClearCyberSlot( Slot , Item );
		DelinkGear( Item^.Parent^.InvCom , Item );
		Result := ReduceTrauma( Item );
		InsertSubCom( Slot , Item );
		if GB <> Nil then QuickTime( GB , 3600 * 2 );
		AddStaminaDown( PC , Random( 8 ) + Random( 8 ) + Random( 8 ) + 3 );
		AddMentalDown( PC , Random( 8 ) + Random( 8 ) + Random( 8 ) + 3 );
		AddReputation( PC , 7 , 3 );
		ApplyCyberware( LocatePilot( PC ) , Item );

		CHAT_Message := MsgString( 'SERVICES_Cyber_Wait' );
		N := SelectMenu( RPM , @ServiceRedraw );
		DisposeRPGMenu( RPM );
		CHAT_Message := MsgString( 'SERVICES_Cyber_Done' + BStr( Result ) );

		DialogMsg( ReplaceHash( MsgString( 'SERVICES_Cyber_Confirmation' ) , GearName( Item ) ) );
	end;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
	CreateCyberMenu;

	if RPM^.NumItem > 0 then begin
		CHAT_Message := MsgString( 'SERVICES_Cyber_SelectPart' );
		N := SelectMenu( RPM , @ServiceRedraw );

		DisposeRPGMenu( RPM );

		if N > 0 then begin
			Item := LocateGearByNumber( PC , N );
			if Item <> Nil then begin
				RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
				BuildSubMenu( RPM , PC , Item , False );
				if RPM^.NumItem = 1 then begin
					Slot := LocateGearByNumber( PC , RPM^.FirstItem^.Value );
				end else if RPM^.NumItem > 1 then begin
					CHAT_Message := MsgString( 'SERVICES_Cyber_SelectSlot' );
					N := SelectMenu( RPM , @ServiceRedraw );

					if N > 0 then begin
						Slot := LocateGearByNumber( PC , N );
					end else begin
						Slot := Nil;
					end;
				end else begin
					Slot := Nil;
				end;
				DisposeRPGMenu( RPM );

				if Slot <> Nil then begin
					if WillingToPay then begin
						PerformInstallation;
					end else begin
						CHAT_Message := MsgString( 'SERVICES_Cyber_Cancel' );

					end;
				end else begin
					CHAT_Message := MsgString( 'SERVICES_Cyber_Cancel' );

				end;

			end;
		end else begin
			CHAT_Message := MsgString( 'SERVICES_Cyber_Cancel' );

		end;

	end else begin
		CHAT_Message := MsgString( 'SERVICES_Cyber_NoPart' );
		DisposeRPGMenu( RPM );
	end;
end;


Procedure OpenShop( GB: GameBoardPtr; PC,NPC: GearPtr; Stuff: String );
	{ Let the shopping commence! This procedure is called when }
	{ a conversation leads to a transaction... This is the top }
	{ level of the shopping menu, and should offer the following }
	{ choices: }
	{  - Browse Wares }
	{  - Repair All / Treat Injuries (depening on NPC skills) }
	{  - Reload All (if this is a weapon shop) }
	{  - Take a look at this... (to sell/repair/reload items in Inv) }
var
	RPM: RPGMenuPtr;
	Wares: GearPtr;
	N: Integer;
	Cost,C1,C2: LongInt;
begin
	SERV_GB := GB;
	SERV_NPC := NPC;
	SERV_PC := PC;

	{ Gather up all the PC's mechas and salvage. }
	GatherFieldHQ( GB );

	{ Generate the list of stuff in the store. }
	Wares := CreateWaresList( GB , NPC , Stuff );

	repeat
		{ Start by allocating the menu. }
		{ This menu will use the same dimensions as the interaction }
		{ menu, since it branches from there. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );

		{ Add the basic options. }
		if Wares <> Nil then AddRPGMenuItem( RPM , 'Browse Wares' , 0 );

		{ Add options for each of the repair skills. }
		for N := 1 to NumSkill do begin
			{ A shopkeeper can only repair items for which he has the }
			{ required skills. }
			if NAttValue( NPC^.NA , NAG_Skill , N ) > 0 then begin
				Cost := RepairAllCost( GB , N );
				if Cost > 0 then begin
					AddRPGMenuItem( RPM , MsgString( 'SERVICES_OSRSP' + BStr( N ) ) + ' [$' + BStr( ScalePrice( PC , NPC , Cost ) ) + ']' , N );
				end;
			end;
		end;

		{ If the shopkeeper knows Basic Repair, allow Reload Chars. }
		{ If the shopkeeper knows Mecha Repair, allow reload mecha. }
		if NAttValue( NPC^.NA , NAG_Skill , 23 ) > 0 then begin
			C1 := ReloadCharsCost( GB , PC , NPC , False );
			C2 := ReloadCharsCost( GB , PC , NPC , True );
			if ( C1 > 0 ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_ReloadCharsPrompt' ) + ' [$' + BStr( C1 ) + ']' , -4 );
			if C2 > C1 then AddRPGMenuItem( RPM , MsgString( 'SERVICES_ReloadChars+Prompt' ) + ' [$' + BStr( C2 ) + ']' , -11 );
		end;
		if NAttValue( NPC^.NA , NAG_Skill , 15 ) > 0 then begin
			C1 := ReloadMechaCost( GB , PC , NPC , False );
			C2 := ReloadMechaCost( GB , PC , NPC , True );
			if ( C1 > 0 ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_ReloadMeksPrompt' ) + ' [$' + BStr( C1 ) + ']' , -3 );
			if C2 > C1 then AddRPGMenuItem( RPM , MsgString( 'SERVICES_ReloadMeks+Prompt' ) + ' [$' + BStr( C2 ) + ']' , -10 );
		end;

		{ Also if the shopkeeper knows Basic Repair, allow recharging of batteries. }
		if ( RechargeCost( GB , PC , NPC ) > 0 ) and ( NAttValue( NPC^.NA , NAG_Skill , 23 ) > 0 ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_RechargePrompt' ) + ' [$' + BStr( RechargeCost( GB , PC , NPC ) ) + ']' , -9 );

		if AStringHasBString( Stuff, 'DELIVERY' ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_ExpressDelivery' ) , -8 );

		{ If the shopkeeper knows Cybertech, allow the implantation }
		{ of modules. }
		if ( NAttValue( NPC^.NA , NAG_Skill , 24 ) > 0 ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_CybInstall' ) , -7 );

		AddRPGMenuItem( RPM , MsgString( 'SERVICES_SellStuff' ) , -5 );

		if AStringHasBString( Stuff, 'MECHA' ) then AddRPGMenuItem( RPM , MsgString( 'SERVICES_MechaService' ) , -2 );

		AddRPGMenuItem( RPM , MsgString( 'SERVICES_Inventory' ) , -6 );

		AddRPGMenuItem( RPM , 'Exit Shop' , -1 );

		{ Display the trading stats. }
		N := SelectMenu( RPM , @ServiceRedraw );

		DisposeRPGMenu( RPM );

		if N > 0 then begin
			RepairAllFrontEnd( GB , PC , NPC , N );
		end else if N = 0 then begin
			BrowseWares( GB, PC , NPC , Wares );
		end else if N = -2 then begin
			BrowseMecha( GB , PC , NPC );
		end else if N = -3 then begin
			DoReloadMecha( GB , PC , NPC , False );
		end else if N = -4 then begin
			DoReloadChars( GB , PC , NPC , False );
		end else if N = -5 then begin
			SellStuff( GB , PC , PC , NPC , Stuff );
		end else if N = -6 then begin
			BackpackMenu( GB , PC , True , @ServicesBackpackRedraw );

		end else if N = -7 then begin
			InstallCyberware( GB , PC , NPC );
		end else if N = -8 then begin
			ExpressDelivery( GB , PC , NPC );
		end else if N = -9 then begin
			DoRecharge( GB , PC , NPC );

		end else if N = -10 then begin
			DoReloadMecha( GB , PC , NPC , True );
		end else if N = -11 then begin
			DoReloadChars( GB , PC , NPC , True );
		end;

	until N = -1;

	DisposeGear( Wares );
end;

Procedure OpenSchool( GB: GameBoardPtr; PC,NPC: GearPtr; Stuff: String );
	{ Let the teaching commence! I was thinking, at first, of }
	{ including skill training as a sub-bit of the shopping procedure, }
	{ but abandoned this since I'd like a bit more control over }
	{ the process. }
	{ The going rate for training is $100 = 1XP. }
	{ This rate is not affected by Shopping skill, though a good }
	{ reaction score with the teacher can increase the number of XP }
	{ gained. }
const
	XPStep: Array [1..40] of Integer = (
		1,2,3,4,5, 6,7,8,9,10,
		12,15,20,25,50, 75,100,150,200,250,
		500,750,1000,1500,2000, 2500,3000,3500,4000,4500,
		5000,6000,7000,8000,9000, 10000,12500,15000,20000,25000
	);
	Knowledge_First_Bonus = 14;
	Knowledge_First_Penalty = 8;
	CostFactor = 250;
var
	SkillMenu,CostMenu: RPGMenuPtr;
	Skill,N: Integer;
	Cash: LongInt;
	DSLTemp: Boolean;
begin
	SERV_GB := GB;
	SERV_NPC := NPC;
	SERV_PC := PC;

	{ When using a school, can always learn directly. }
	DSLTemp := Direct_Skill_Learning;
	Direct_Skill_Learning := True;

	{ Step One: Create the skills menu. }
	SkillMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
	AttachMenuDesc( SkillMenu , ZONE_ItemsInfo );

	while Stuff <> '' do begin
		N := ExtractValue( Stuff );
		if ( N >= 1 ) and ( N <= NumSkill ) then begin
			AddRPGMenuItem( SkillMenu , MsgString( 'SKILLNAME_' + BStr( N ) ) , N , SkillDescription( N ) );
		end;
	end;
	RPMSortAlpha( SkillMenu );
	AddRPGMenuItem( SkillMenu , MsgString( 'SCHOOL_Exit' ) , -1 );

	repeat
		{ Get a selection from the menu. }
		Skill := SelectMenu( SkillMenu , @ServiceRedraw );

		{ If a skill was chosen, do the training. }
		if ( Skill >= 1 ) and ( Skill <= NumSkill ) then begin
			{ Create the CostMenu, and see how much the }
			{ player wants to spend. }
			CostMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
			Cash := NAttValue( PC^.NA , NAG_Experience , NAS_Credits );

			{ Add menu entries for each of the cost values }
			{ that the PC can afford. }
			for N := 1 to 40 do begin
				if XPStep[ N ] * CostFactor <= Cash then begin
					AddRPGMenuItem( CostMenu , '$' + BStr( XPStep[ N ] * CostFactor ) , N );
				end;
			end;

			{ Add the exit option, so that we'll never have }
			{ an empty menu. }
			AddRPGMenuItem( CostMenu , MsgString( 'SCHOOL_ExitCostSelector' ) , -1 );

			Chat_Message := MsgString( 'SCHOOL_HowMuch' );
			N := SelectMenu( CostMenu , @ServiceRedraw );
			DisposeRPGMenu( CostMenu );

			{ If CANCEL wasn't selected, take away the cash }
			{ and give the PC some experience. }
			if N <> -1 then begin
				CHAT_Message := MsgString( 'SCHOOL_TeachingInProgress' );
				AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -( XPStep[ N ] * CostFactor ) );

				{ Calculate the number of XPs earned. }
				if NPC <> Nil then begin
					Cash := ( XPStep[ N ] * ( 400 + ReactionScore( GB^.Scene , PC , NPC ) ) ) div 400;
				end else begin
					Cash := XPStep[ N ];
				end;

				{ Add bonus for high Knowledge stat, }
				{ or penalty for low Knowledge stat. }
				if CStat( PC , STAT_Knowledge ) >= Knowledge_First_Bonus then begin
					Cash := ( Cash * ( 100 + ( CStat( PC , STAT_Knowledge ) - Knowledge_First_Bonus + 1 ) * 5 ) ) div 100;
				end else if CStat( PC , STAT_Knowledge ) <= Knowledge_First_Penalty then begin
					Cash := ( Cash * ( 100 - ( Knowledge_First_Penalty - CStat( PC , STAT_Knowledge ) + 1 ) * 10 ) ) div 100;
					if Cash < 1 then Cash := 1;
				end;

				if DoleSkillExperience( PC , Skill , Cash ) then begin
					DialogMsg( MsgString( 'SCHOOL_Learn' + BStr( Random( 5 ) + 1 ) ) );
				end;

				{ Training takes time. }
				while ( N > 0 ) and ( GB <> Nil ) do begin
					QuickTime( GB , 100 + Random( 100 ) );
					Dec( N );
				end;
			end;
		end;
	until Skill = -1;

	{ Restore the Direct_Skill_Learning setting. }
	Direct_Skill_Learning := DSLTemp;

	DisposeRPGMenu( SkillMenu );
end;

Procedure FillExpressMenu( GB: GameBoardPtr; RPM: RPGMenuPtr );
	{ Search through the world for gears belonging to the PC. }
var
	N: Integer;
	CurrentCity,World: GearPtr;
{ PROCEDURES BLOCK }
	Function FXMRootScene( Part: GearPtr ): GearPtr;
		{ Find the root scene of this part, assuming it's in a regular scene and not }
		{ on the gameboard or anywhere strange. }
	begin
		while ( Part <> Nil ) and not ( ( Part^.Parent <> Nil ) and ( Part^.Parent^.G <> GG_Scene ) ) do begin
			Part := Part^.Parent;
		end;
		FXMRootScene := Part;
	end;
	Procedure CheckAlongPath( Part: GearPtr; AddToMenu: Boolean );
		{ CHeck along the path specified. }
	begin
		while Part <> Nil do begin
			Inc(N);
			if ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and AddToMenu then AddRPGMenuItem( RPM , FullGearName( Part ) + ' (' + GearName( FXMRootScene( Part ) ) + ')' , N );
			if Part = CurrentCity then begin
				{ Don't add parts from the current location. }
				CheckAlongPath( Part^.InvCom , False );
				CheckAlongPath( Part^.SubCom , False );
			end else begin
				CheckAlongPath( Part^.InvCom , AddToMenu );
				CheckAlongPath( Part^.SubCom , AddToMenu );
			end;
			Part := Part^.Next;
		end;
	end;
begin
	N := 0;
	CurrentCity := FindRootScene( GB , GB^.Scene );
	World := FindWorld( GB , GB^.Scene );

	CheckAlongPath( World^.InvCom , True );
	CheckAlongPath( World^.SubCom , True );
end; { FillExpressMenu }

Function DeliveryCost( Mek: GearPtr ): LongInt;
	{ Return the cost to deliver this mecha from one location }
	{ to the next. Cost is determined by mass. }
var
	C,T: LongInt;
begin
	{ Base value is the mass of the mek. }
	C := GearMass( Mek );

	{ This gets multiplied upwards as the mass of the mecha increases. }
	for t := 1 to Mek^.Scale do C := C * 5;

	{ Return the finished cost. }
	DeliveryCost := C;
end;

Procedure ExpressDelivery( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ The PC needs some mecha delivered from out of town. }
	{ Better search the entire adventure and find every mecha }
	{ belonging to the PC. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	Mek: GearPtr;
	Cost: LongInt;
begin
	SERV_GB := GB;
	SERV_NPC := NPC;
	SERV_PC := PC;

	repeat
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
		FillExpressMenu( GB , RPM );
		RPMSortAlpha( RPM );
		AlphaKeyMenu( RPM );
		AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );
		N := SelectMenu( RPM , @ServiceRedraw );
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			Mek := LocateGearByNumber( FindWorld( GB , GB^.Scene ) , N );
			if Mek <> Nil then begin
				Cost := ScalePrice( PC , NPC , DeliveryCost( Mek ) );
				RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
				AddRPGMenuItem( RPM , ReplaceHash( MsgString( 'SERVICES_MoveYes' ) , GearName( Mek ) ) , 1 );
				AddRPGMenuItem( RPM , MsgString( 'SERVICES_MoveNo' ) ,  -1 );

				Chat_Message := ReplaceHash( MsgString( 'SERVICES_MovePrompt' + BStr( Random( 3 ) + 1 ) ) , BStr( Cost ) );
				N := SelectMenu( RPM , @ServiceRedraw );

				DisposeRPGMenu( RPM );
				if N = 1 then begin
					{ The PC wants to move this mecha. }
					if NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
						AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -Cost );
						if IsInvCom( Mek ) then begin
							DelinkGear( Mek^.Parent^.InvCom , Mek );
						end else if IsSubCom( Mek ) then begin
							DelinkGear( Mek^.Parent^.SubCom , Mek );
						end;
						DeployGear( GB , Mek , False );
						Chat_Message := MsgString( 'SERVICES_MoveDone' + BStr( Random( 3 ) + 1 ) );

					end else begin
						Chat_Message := MsgString( 'SERVICES_MoveNoCash' );
					end;
				end;
				N := 0;
			end;
		end;

	until N = -1;
end;

Procedure ShuttleService( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ The PC will be able to travel to a number of different cities. }
	function FindLocalGate( World: GearPtr; SceneID: Integer ): GearPtr;
		{ This is a nice simple non-recursive list search, }
		{ since the gate should be at root level. }
	var
		Part,TheGate: GearPtr;
	begin
		Part := World^.InvCom;
		TheGate := Nil;
		while ( Part <> Nil ) and ( TheGate = Nil ) do begin
			if ( Part^.G = GG_MetaTerrain ) and ( Part^.Stat[ STAT_Destination ] = SceneID ) then begin
				TheGate := Part;
			end;
			Part := Part^.Next;
		end;
		FindLocalGate := TheGate;
	end;
	Function WorldMapRange( World: GearPtr; X0,Y0,X1,Y1: Integer ): Integer;
	begin
		if WorldWrapsX( World ) and ( Abs( X0 - X1 ) > ( World^.Stat[ STAT_MapWidth ] div 2 ) ) then begin
			if X1 > X0 then begin
				X1 := X1 - World^.Stat[ STAT_MapWidth ];
			end else begin
				X0 := X0 - World^.Stat[ STAT_MapWidth ];
			end;
		end;
		if WorldWrapsY( World ) and ( Abs( Y1 - Y0 ) > ( World^.Stat[ STAT_MapHeight ] div 2 ) ) then begin
			if Y1 > Y0 then begin
				Y1 := Y1 - World^.Stat[ STAT_MapHeight ];
			end else begin
				Y0 := Y0 - World^.Stat[ STAT_MapHeight ];
			end;
		end;
		WorldMapRange := Range( X0 , Y0 , X1 , Y1 );
	end;
	Function TravelCost( World,Entrance: GearPtr; X0 , Y0: Integer ): LongInt;
		{ Calculate the travel cost from the original location to the }
		{ destination city. }
	var
		X1,Y1: Integer;
	begin
		if Entrance = Nil then begin
			TravelCost := 50000;
		end else begin
			{ Determine the X,Y coords of the destination on the world map. }
			{ If the map is a wrapping-type map, maybe modify for the shortest }
			{ possible distance. }
			X1 := NAttValue( Entrance^.NA , NAG_Location , NAS_X );
			Y1 := NAttValue( Entrance^.NA , NAG_Location , NAS_Y );
			TravelCost := WorldMapRange( World , X1 , Y1 , X0 , Y0 ) * 200 + 250;
		end;
	end;
const
	MaxShuttleRange = 150;
var
	World,City,Fac,Entrance: GearPtr;
	X0,Y0,N,Cost: LongInt;
	RPM: RPGMenuPtr;
begin
	SERV_GB := GB;
	SERV_NPC := NPC;
	SERV_PC := PC;

	{ Create a shopping list of the available scenes. These must not be }
	{ enemies of the current scene, must be located on the same world, }
	{ must be within a certain range, and must have "DESTINATION" in their }
	{ TYPE string attribute. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ShopMenu );
	AttachMenuDesc( RPM , ZONE_ItemsInfo );
	World := FindWorld( GB , GB^.Scene );
	City := World^.SubCom;
	Entrance := FindLocalGate( World , FindRootScene( GB , GB^.Scene )^.S );
	if Entrance <> Nil then begin
		X0 := NAttValue( Entrance^.NA , NAG_Location , NAS_X );
		Y0 := NAttValue( Entrance^.NA , NAG_Location , NAS_Y );
	end else begin
		X0 := 1;
		Y0 := 1;
	end;
	Fac := SeekFaction( GB^.Scene , GetFactionID( FindRootScene( GB , GB^.Scene ) ) );

	while City <> Nil do begin
		{ Do the faction check. }
		if ( City <> FindRootScene( GB , GB^.Scene ) ) and ( ( Fac = Nil ) or ( NAttValue( Fac^.NA , NAG_FactionScore , GetFactionID( City ) ) >= 0 ) ) then begin
			{ Do the range check. }
			Entrance := FindLocalGate( World , City^.S );
			if AStringHasBString( SAttValue( City^.SA , 'TYPE' ) , 'DESTINATION' ) then begin
				AddRPGMenuItem( RPM , GearName( City ) + ' ($' + BStr( TravelCost( World, Entrance , X0 , Y0 ) ) + ')' , City^.S , SAttValue( City^.SA , 'DESC' ) );
			end;
		end;

		City := City^.Next;
	end;

	{ Sort the menu. }
	RPMSortAlpha( RPM );
	AlphaKeyMenu( RPM );

	{ Add the cancel option. }
	AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

	repeat
		{ Perform the menu selection. }
		N := SelectMenu( RPM , @ServiceRedraw );

		{ If a destination was selected, see if it's possible to go there, deduct the PC's }
		{ money, etc. }
		if N > -1 then begin
			Entrance := FindLocalGate( World , N );
			Cost := TravelCost( World , Entrance , X0 , Y0 );
			if NAttValue( PC^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
				GB^.QuitTheGame := True;
				GB^.ReturnCode := N;
				AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , -Cost );
				SetNAtt( PC^.NA , NAG_Condition , NAS_Hunger , 0 );
				QuickTime( GB , Cost * 10 );
				SetNAtt( PC^.NA , NAG_Condition , NAS_Hunger , 0 );
			end else begin
				{ Not enough cash to buy... }
				CHAT_Message := MsgString( 'BUYNOCASH' + BStr( Random( 4 ) + 1 ) );
			end;

		end;
	until GB^.QuitTheGame or ( N = -1 );

	DisposeRPGMenu( RPM );

end;

initialization
	SERV_GB := Nil;
	SERV_NPC := Nil;

end.
