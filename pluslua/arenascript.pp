unit arenascript;
	{ This unit holds the scripting language for GearHead. }
	{ It's pretty similar to the scripts developed for DeadCold. }
	{ Basically, certain game events will add a trigger to the }
	{ list. In the main combat procedure, if there are any pending }
	{ triggers, they will be checked against the events list to }
	{ see if anything happens. }

	{ Both the triggers and the event scripts will be stored as }
	{ normal string attributes. }

	{ This unit also handles conversations with NPCs, since those }
	{ are written using the scripting language and may use any }
	{ commands available there + a few special commands. }
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

uses gears,locale,
{$IFDEF ASCII}
	vidmenus,vidgfx;
{$ELSE}
	sdlmenus,sdl;
{$ENDIF}

const
	NAG_ScriptVar = 0;
	NAG_SkillCounter = -16;	{ Counter for skill tests. }
	Max_Plots_Per_Story = 5;


	{ When playing in arena mode, the following string attributes will be added to the scene }
	{ following battle. }
	ARENAREPORT_CharDied = 'AR_PCDIED';
	ARENAREPORT_CharRecovered = 'AR_PCRECOVERED';
	ARENAREPORT_MechaDestroyed = 'AR_MECHADIED';
	ARENAREPORT_MechaRecovered = 'AR_MECHARECOVERED';
	ARENAREPORT_MechaObtained = 'AR_MECHAOBTAINED';
	ARENAREPORT_Personal = 'AR_PERSONAL';

var
	{ This gear pointer will be created if a dynamic scene is requested. }
	SCRIPT_DynamicEncounter: GearPtr;

	{ **************************************** }
	{ ***  INTERACTION  GLOBAL  VARIABLES  *** }
	{ **************************************** }
	{ These variables hold information that may be needed anywhere }
	{ while interaction is taking place, but are undefined if }
	{ interaction is not taking place. }
	{ IntMenu should let procedures know whether or not interaction }
	{ is currently happening or not- if IntMenu <> Nil, we're in the }
	{ middle of a conversation and all other interaction variables }
	{ should have good values. }
	IntMenu: RPGMenuPtr;	{ Interaction Menu }
	I_PC,I_NPC: GearPtr;	{ Pointers to the PC & NPC Chara gears }
	I_Rumors: SAttPtr;	{ List of rumors. }
	I_Persona: GearPtr;	{ The conversation currently being used. }
	I_HaveNotShopped: Boolean;

	lancemate_tactics_persona: GearPtr;	{ Persona for setting lancemate tactics. }
	rumor_leads: GearPtr;			{ Mini-conversations for finding rumors. }


Procedure SetLancemateOrders( GB: GameBoardPtr );
Function NumLancemateSlots( Adv,PC: GearPtr ): Integer;

Procedure BrowseMemoType( GB: GameBoardPtr; Tag: String );

Function BasicSkillTarget( Renown: Integer ): Integer;
Function HardSkillTarget( Renown: Integer ): Integer;
Function Calculate_Reward_Value( GB: GameBoardPtr; Renown,Percent: LongInt ): LongInt;

Procedure AddLancemate( GB: GameBoardPtr; NPC: GearPtr );
Function AddLancemateFrontEnd( GB: GameBoardPtr; PC,NPC: GearPtr; CanCancel: Boolean ): Boolean;
Procedure RemoveLancemate( GB: GameBoardPtr; Mek: GearPtr; DoMessage: Boolean );

Procedure HandleInteract( GB: GameBoardPtr; PC,NPC,Persona: GearPtr );
Procedure DoTalkingWIthNPC( GB: GameBoardPtr; PC,Mek: GearPtr; ByTelephone: Boolean );

Function TriggerGearScript( GB: GameBoardPtr; MyGear: GearPtr; const Trigger: String ): Boolean;
Function CheckTriggerAlongPath( const T: String; GB: GameBoardPtr; Plot: GearPtr; CheckAll: Boolean ): Boolean;
Procedure HandleTriggers( GB: GameBoardPtr );


Function StartRescueScenario( GB: GameBoardPtr; PC: GearPtr; Context: String ): Boolean;


implementation

uses action,arenacfe,ability,gamebook,ghchars,gearparser,ghmodule,backpack,
     ghprop,ghweapon,interact,menugear,plotbuild,plotsearch,rpgdice,lua,lauxlib,
     services,texutil,uiconfig,wmonster,narration,description,skilluse,
	ghintrinsic,movement,minigame,customization,aibrain,
{$IFDEF ASCII}
	vidmap,vidinfo;
{$ELSE}
	sdlgfx,sdlmap,sdlinfo;
{$ENDIF}

const
	CMD_Chat = -2;
	CMD_Join = -3;
	CMD_Quit = -4;
	CMD_WhereAreYou = -5;
	CMD_AskAboutRumors = -6;
	Debug_On: Boolean = False;

var
	AS_GB: GameBoardPtr;	{ The current gameboard, set for Lua functions. }
	ASRD_MemoMessage: String;

	AS_Menu: RPGMenuPtr;

{  ******************************  }
{  ***   REDRAW  PROCEDURES   ***  }
{  ******************************  }

Procedure InteractRedraw;
	{ Redraw the screen for whatever interaction is going to go on. }
begin
	CombatDisplay( AS_GB );
	SetupInteractDisplay( PlayerBlue );
	if I_NPC <> Nil then begin
		DisplayInteractStatus( AS_GB , I_NPC , CHAT_React , I_Endurance );

	end;
	GameMsg( CHAT_Message , ZONE_InteractMsg , InfoHiLight );
end;

Procedure ArenaScriptReDraw;
	{ Redraw the combat screen for some menu usage. }
begin
	if AS_GB <> Nil then CombatDisplay( AS_GB );
end;

Procedure MemoPageReDraw;
	{ Redraw the combat screen for some menu usage. }
begin
	if AS_GB <> Nil then CombatDisplay( AS_GB );
	SetupMemoDisplay;
	GameMsg( ASRD_MemoMessage , ZONE_MemoText , StdWhite );
end;

Procedure ChoiceReDraw;
	{ Redraw the combat screen for some menu usage. }
begin
	if AS_GB <> Nil then CombatDisplay( AS_GB );
	SetupMemoDisplay;
	GameMsg( ASRD_MemoMessage , ZONE_MemoMenu , StdWhite );
end;



{  ****************************  }
{  ***   EVERYTHING  ELSE   ***  }
{  ****************************  }

Function GG_LocateAdventure( GB: GameBoardPtr; Source: GearPtr ): GearPtr;
	{ Find the adventure. }
begin
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		GG_LocateAdventure := FindRoot( GB^.Scene );
	end else begin
		GG_LocateAdventure := FindRoot( Source );
	end;
end;


Function BasicSkillTarget( Renown: Integer ): Integer;
	{ Return an appropriate target for skill rolls for someone of the listed renown. }
var
	it: Integer;
begin
	it := Renown div 8 + 3;
	if it < 5 then it := 5;
	BasicSkillTarget := it;
end;

Function HardSkillTarget( Renown: Integer ): Integer;
	{ Return a difficult target for skill rolls for someone of the listed renown. }
var
	it: Integer;
begin
	it := Renown div 7 + 10;
	if it < 9 then it := 9;
	HardSkillTarget := it;
end;

Function SocSkillTarget( GB: GameBoardPtr; Renown: Integer ): Integer;
	{ Return a social difficult target for skill rolls based on Renown and modified }
	{ by the relationship between I_PC and I_NPC. }
var
	it,react: Integer;
begin
	it := Renown div 7 + 7;
	if it < 10 then it := 10;

	{ If the PC and NPC exist, apply the special modifier. }
	if ( I_PC <> Nil ) and ( I_NPC <> Nil ) then begin
		react := ReactionScore( GB^.Scene , I_PC , I_NPC );
		it := it - ( react div 10 );
	end;

	SocSkillTarget := it;
end;



Function RevealRumors( GB: GameBoardPtr; NPC: GearPtr; SkRoll: Integer; var Rumor_Error: Boolean ): SAttPtr;
	{ Reveal some rumors! Call the CreateRumorList procedure with a standard reveal. }
begin
{	RevealRumors := CreateRumorList( GB, NPC, SkRoll, TRUE, Rumor_Error, ReplaceHash( MsgString( '#SaidThat' ) , PilotName( NPC ) ), 'RUMOR' );}
end;

Function ReviewRumorMemos( GB: GameBoardPtr ): SAttPtr;
	{ Create the list of rumor memos. }
var
	Rumor_Error: Boolean;	{ A dummy variable. }
begin
{	ReviewRumorMemos := CreateRumorList( GB, Nil, 0, FALSE, Rumor_Error, '', 'RUMEMO' );}
end;

Procedure BrowseMemoType( GB: GameBoardPtr; Tag: String );
	{ Create a list, then browse the memos based upon this }
	{ TAG type. Possible options are MEMO, NEWS, and EMAIL. }
var
	MemoList,M: SAttPtr;
	Adv: GearPtr;

	Procedure HarvestPlotMemos( LList: SAttPtr );
		{ This list may contain plot memos. How to tell? The first four }
		{ characters will be "MEMO". It's just like harvesting the history. }
	begin
		while LList <> Nil do begin
			if UpCase( Copy( LList^.Info , 1 , 4 ) ) = 'MEMO' then begin
				StoreSAtt( MemoList , RetrieveAString( LList^.Info ) );
			end;
			LList := LList^.Next;
		end;
	end;
	Procedure CreateMemoList( Part: GearPtr; Tag: String );
		{ Look through all gears in the structure recursively, }
		{ looking for MEMO string attributes to store in our list. }
	var
		msg: String;
		QID: LongInt;
	begin
		while Part <> Nil do begin
			if ( tag = 'MEMO' ) and ( Part^.G = GG_Plot ) then begin
				{ This is a plot. It may have subplot memos. These are }
				{ memos that have the PLOTID attached to their butts. Why? }
				{ Because I realized, somewhat late, that a plot which can }
				{ contain multiple narrative threads really needs multiple }
				{ memos as well. }
				HarvestPlotMemos( Part^.SA );
			end else begin
				{ Not a plot. Just do the regular harvesting work, then. }
				msg := SAttValue( Part^.SA , Tag );
				if msg <> '' then StoreSAtt( MemoList , msg );

				{ This part may also have a quest-related message attached }
				{ to it. See if that's so. }
				QID := NAttValue( Part^.NA , NAG_Narrative , NAS_PlotID );
				if ( QID <> 0 ) then begin
					msg := SAttValue( Part^.SA , Tag + '_' + BStr( NAttValue( Adv^.NA , NAG_PlotStatus , Qid ) ) );
					if msg <> '' then StoreSAtt( MemoList , msg );
				end;
			end;

			CreateMemoList( Part^.SubCom , Tag );
			CreateMemoList( Part^.InvCom , Tag );
			Part := Part^.Next;
		end;
	end;
	Procedure AddQuestMemos;
		{ Quest memos work a bit differently than other memos. First, }
		{ they only appear so long as the quest they're assigned to is }
		{ active (i.e. it has a nonnegative QID). }
	var
		SA,SA2: SAttPtr;
		msg_head: String;
		qid: LongInt;
	begin
		SA := Adv^.SA;
		while SA <> Nil do begin
			SA2 := SA^.next;

			{ If this string attribute is potentially a quest memo, }
			{ try to extract its QuestID. If this memo is no longer }
			{ valid then delete it. }
			if HeadMatchesString( 'MEMO_' , SA^.Info ) then begin
				msg_head := RetrieveAPreamble( SA^.Info );
				msg_head := Copy( msg_head , 6 , Length( msg_head ) );
				qid := ExtractValue( msg_head );
				if ( qid <> 0 ) and ( NAttValue( Adv^.NA , NAG_PlotStatus , Qid ) > -1 ) then begin
					{ Add it to the list. }
					StoreSAtt( MemoList , RetrieveAString( SA^.Info ) );
				end else begin
					{ Invalid quest memo. Get rid of it. }
					RemoveSAtt( Adv^.SA , SA );
				end;
			end;

			SA := SA2;
		end;
	end;
	Function PlaceMemoPhoneCall( PC: GearPtr; MMsg: String ): Boolean;
		{ We want to make a phone call to someone mentioned in this memo. }
		{ Search through all the NPCs on the game board and within the current city. }
		{ Add them to a menu. Then, query the menu, and do talking with the selected NPC. }
		{ Return TRUE if a conversation was had, or FALSE otherwise. }
		Procedure CheckAlongList( RPM: RPGMenuPtr; LList: GearPtr );
			{ Check along this list for NPCs mentioned in the memo, recursively }
			{ searching through children as well. }
			{ Add any good NPCs found to the menu, using their CID as the key. }
		var
			Name: String;
			CID: LongInt;
		begin
			while LList <> Nil do begin
				if LList^.G = GG_Character then begin
					{ This is a character. Is it somebody we're looking for? }
					Name := GearName( LList );
					CID := NAttValue( LList^.NA , NAG_Narrative , NAS_NID );
					if ( CID <> 0 ) and ( Pos( Name , MMsg ) > 0 ) and CanContactByPhone( GB , LList ) then begin
						AddRPGMenuItem( RPM , GearName( LList ) , CID );
					end;
				end else begin
					{ Not a character. Recurse like mad! }
					CheckAlongList( RPM , LList^.SubCom );
					CheckAlongList( RPM , LList^.InvCom );
				end;

				LList := LList^.Next;
			end;
		end;
	var
		RPM: RPGMenuPtr;
		city,NPC: GearPtr;
		CID: LongInt;
	begin
		{ Step One- Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );
		CheckAlongList( RPM , GB^.Meks );
		City := FindRootScene( GB^.Scene );
		if City <> Nil then begin
			CheckAlongList( RPM , City^.SubCom );
			CheckAlongList( RPM , City^.InvCom );
		end;
		RPMSortAlpha( RPM );
		AlphaKeyMenu( RPM );
		if RPM^.NumItem > 0 then begin
			AddRPGMenuItem( RPM , MsgString( 'Cancel' ) , -1 );
		end else begin
			AddRPGMenuItem( RPM , MsgString( 'MEMO_CALL_NoPeople' ) , -1 );
		end;

		{ Step Two- Query the menu and locate the NPC. }
		CID := SelectMenu( RPM , @MemoPageRedraw );
		DisposeRPGMenu( RPM );

		{ Step Three- Pass the request along to HandleInteract. }
		if CID > -1 then begin
			NPC := SeekGearByNID( GB , GB^.Scene , CID );
			if NPC <> Nil then begin
				DoTalkingWithNPC( GB , PC , NPC , True );
			end;
		end else NPC := Nil;

		PlaceMemoPhoneCall := NPC <> Nil;
	end;
	Procedure BrowseList;
		{ Actually browse the created list. }
	var
		RPM: RPGMenuPtr;
		N,D: Integer;
		PC: GearPtr;
	begin
		{ Locate the PC. We need it for the PComm capability. }
		PC := LocatePC( GB );
		if MemoList <> Nil then begin
			RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );
			AddRPGMenuItem( RPM , MsgString( 'MEMO_Next' ) , 1 );
			AddRPGMenuItem( RPM , MsgString( 'MEMO_Prev' ) , 2 );
			if ( PC <> Nil ) and HasPCommCapability( PC , PCC_Phone ) then AddRPGMenuItem( RPM , MsgString( 'MEMO_Call' ) , 3 );
			AddRPGMenuKey( RPM , KeyMap[ KMC_East ].KCode , 1 );
			AddRPGMenuKey( RPM , KeyMap[ KMC_West ].KCode , 2 );
			AlphaKeyMenu( RPM );
			RPM^.Mode := RPMNoCleanup;
			N := 1;

			repeat
				M := RetrieveSAtt( MemoList , N );
				AS_GB := GB;
				ASRD_MemoMessage := M^.Info;
				D := SelectMenu( RPM , @MemoPageRedraw );


				if D = 1 then begin
					N := N + 1;
					if N > NumSAtts( MemoList ) then N := 1;
				end else if D = 2 then begin
					N := N - 1;
					if N < 1 then N := NumSAtts( MemoList );
				end else if D = 3 then begin
					{ We want to place a phone call to someone mentioned }
					{ in this memo. Make it so. }
					PlaceMemoPhoneCall( PC , M^.Info );
					D := -1;
				end;
			until ( D = -1 ) or not KeepPlayingSC( GB );

			DisposeSAtt( MemoList );
			DisposeRPGMenu( RPM );
		end;

	end;
	Function NoMemoError: String;
		{ Return a string which will explain to the user that there are }
		{ no memos of the selected type. }
	var
		msg: String;
	begin
		msg := MsgString( 'MEMO_No_' + Tag );
		if msg = '' then msg := ReplaceHash( MsgString( 'MEMO_None' ) , LowerCase( Tag ) );
		NoMemoError := msg;
	end;
begin
	{ Error check first - we need the GB and the scene for this. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;
	tag := UpCase( Tag );
	MemoList := Nil;
	Adv := FindRoot( GB^.Scene );
	if ( Tag = 'RUMEMO' ) then begin
		MemoList := ReviewRumorMemos( GB );
	end else begin
		CreateMemoList( Adv , Tag );
	end;
	if Tag = 'MEMO' then AddQuestMemos;

	{ Sort the memo list. }
	if MemoList <> Nil then SortStringList( MemoList )
	else StoreSAtt( MemoList , NoMemoError );

	BrowseList;
end;

Procedure SetLancemateOrders( GB: GameBoardPtr );
	{ Go through the lancemates, and assign any orders they might need. }
var
	PCUID,DefOrder: LongInt;
	mek: gearPtr;
begin
	{ Step one- find the PC's UID. }
	mek := GB^.meks;
	while mek <> Nil do begin
		if ( NAttValue( mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and IsMasterGear( mek ) then begin
			{ This must be the PC. }
			PCUID := NAttValue( mek^.NA , NAG_EpisodeData , NAS_UID );
		end;
		mek := mek^.Next;
	end;

	{ Step two- look for the lancemates and set their orders. }
	mek := GB^.meks;
	while mek <> Nil do begin
		if ( NAttValue( mek^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and IsMasterGear( mek ) then begin
			DefOrder := NAttValue( mek^.NA , NAG_Personal , NAS_LMOrders_AIType );
			if DefOrder = NAV_Passive then begin
				SetNAtt( mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_Passive );
			end else if DefOrder = NAV_Follow then begin
				SetNAtt( mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_Follow );
				SetNAtt( mek^.NA , NAG_EpisodeData , NAS_ATarget , PCUID );
			end else begin
				SetNAtt( mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_SeekAndDestroy );
			end;
		end;
		mek := mek^.Next;
	end;
end;

Function NumLancemateSlots( Adv,PC: GearPtr ): Integer;
	{ Return the number of freely-selected lancemates this PC can have. }
var
	N: Integer;
begin
	{ You get one lancemate for free. }
	N := 1;

	{ You can earn extra lancemates via merit badges. }
	if HasMeritBadge( Adv , NAS_MB_Lancemate2 ) then begin
		Inc( N );
		if HasMeritBadge( Adv, NAS_MB_Lancemate3 ) then Inc( N );
	end;

	{ Or, you can take a talent for one extra. }
	if HasTalent( PC , NAS_Entourage ) then begin
		Inc( N );
	end;

	NumLancemateSlots := N;
end;

Function CanJoinLance( GB: GameBoardPtr; PC,NPC: GearPtr ): Boolean;
	{ Return TRUE if NPC can join the lance right now, or FALSE otherwise. }
var
	ERen: Integer;	{ Lancemate Points needed, Effective Renown }
	CanJoin: Boolean;
begin
	ERen := NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned );
	if ERen < 15 then ERen := 15;
	ERen := ERen + CStat( PC , STAT_Charm );
	CanJoin := True;
	if ( NPC = Nil ) or ( NPC^.G <> GG_Character ) then begin
		CanJoin := False;
	end else if NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) > ERen then begin
		CanJoin := False;
	end else if ( GB <> Nil ) and ( ReactionScore( GB^.Scene , PC , NPC ) < 10 ) then begin
		CanJoin := False;
	end else if ( GB <> Nil ) and not ( OnTheMap( GB , FindRoot( NPC ) ) and IsFoundAlongTrack( GB^.Meks , FindRoot( NPC ) ) ) then begin
		{ Can only join if in the same scene as the PC. }
		CanJoin := False;
	end;
	CanJoinLance := CanJoin;
end;

Function FindRandomMekID( GB: GameBoardPtr; Team: Integer ): LongInt;
	{ Locate a random mek belonging to TEAM. }
var
	NumMeks,N,T,MID: Integer;
	Mek: GearPtr;
begin
	{ Start out by finding out how many meks belong to this team }
	{ anyways. }
	NumMeks := NumOperationalMasters( GB , Team );
	MID := 0;

	{ If there are actually members on this team, select one randomly. }
	if NumMeks > 0 then begin
		{ Decide what mek to take, and initialize the }
		{ search variables. }
		N := Random( NumMeks ) + 1;
		T := 0;
		Mek := GB^.Meks;

		while Mek <> Nil do begin
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team ) and GearOperational( Mek ) then begin
				Inc( T );
				if T = N then MID := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_UID );
			end;
			Mek := Mek^.Next;
		end;
	end;

	FindRandomMekID := MID;
end;

Function FindRandomPilotID( GB: GameBoardPtr; Team: Integer ): LongInt;
	{ Locate a random pilot belonging to TEAM. }
var
	NumMeks,N,T,MID: Integer;
	Mek,P: GearPtr;
begin
	{ Start out by finding out how many meks belong to this team }
	{ anyways. }
	NumMeks := NumOperationalMasters( GB , Team );
	MID := 0;

	{ If there are actually members on this team, select one randomly. }
	if NumMeks > 0 then begin
		{ Decide what mek to take, and initialize the }
		{ search variables. }
		N := Random( NumMeks ) + 1;
		T := 0;
		Mek := GB^.Meks;

		while Mek <> Nil do begin
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team ) and GearOperational( Mek ) then begin
				Inc( T );
				if T = N then begin
					P := LocatePilot( Mek );
					if P <> Nil then MID := NAttValue( P^.NA , NAG_EpisodeData , NAS_UID );
				end;
			end;
			Mek := Mek^.Next;
		end;
	end;

	FindRandomPilotID := MID;
end;

Function FindRootUID( GB: GameBoardPtr; ID: LongInt ): LongInt;
	{ Find the ID of the root of the specified gear. }
var
	Part: GearPtr;
begin
	{ First, find the part being pointed to. }
	Part := LocateMekByUID( GB , ID );

	{ Locate its root. }
	if Part <> Nil then begin
		Part := FindRoot( Part );

		{ Return the root's UID. }
		FindRootUID := NAttValue( Part^.NA , NAG_EpisodeData , NAS_UID );

	{ If there was an error locating the part, return 0. }
	end else FindRootUID := 0;
end;


Function NumPCMeks( GB: GameBoardPtr ): Integer;
	{ Return the number of mecha belonging to team 1. }
	{ It doesn't matter if they're on the board or not, nor whether or }
	{ not they are destroyed. }
var
	M: GearPtr;
	N: Integer;
begin
	N := 0;
	if GB <> Nil then begin
		M := GB^.Meks;
		while M <> Nil do begin
			{ If this is a mecha, and it belongs to team 1, }
			{ increment the counter. }
			if ( M^.G = GG_Mecha ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then Inc( N );
			M := M^.Next;
		end;
	end;
	NumPCMeks := N;
end;

Function FindPCScale( GB: GameBoardPtr ): Integer;
	{ Return the scale of the PC. Generally this will be 0 if the }
	{ PC is on foot, 1 or 2 if the PC is in a mecha, unless the PC }
	{ is a storm giant or a zentradi in which case anything goes. }
var
	PC: GearPtr;
begin
	PC := LocatePC( GB );
	if PC <> Nil then begin
		FindPCScale := FindRoot( PC )^.Scale;
	end else begin
		FindPCScale := 0;
	end;
end;

Function Calculate_Reward_Value( GB: GameBoardPtr; Renown,Percent: LongInt ): LongInt;
	{ Return an appropriate reward value, based on the listed }
	{ threat level and percent scale. }
const
	Min_Reward_Value = 3000;
var
	RV: LongInt;
begin
	{ Calculate the base reward value. }
	RV := Calculate_Threat_Points( Renown + 10 , 100 ) div 64 * Percent div 100;
	if RV < Min_Reward_Value then RV := Min_Reward_Value;

	{ Modify this for the PC's talents. }
	if GB <> Nil then begin
		if TeamHasTalent( GB , NAV_DefPlayerTeam , NAS_BusinessSense ) then RV := ( RV * 5 ) div 4;
	end;

	Calculate_Reward_Value := RV;
end;

Function Calculate_Asking_Price( GB: GameBoardPtr; Renown,Percent: LongInt ): LongInt;
	{ Return an appropriate asking price, based on the listed }
	{ threat level, percent scale, and reaction score with I_NPC. }
const
	Min_Asking_Price = 3000;
var
	RV,React: LongInt;
begin
	{ Calculate the base reward value. }
	RV := Calculate_Threat_Points( Renown , 25 ) * Percent div 100;
	if RV < Min_Asking_Price then RV := Min_Asking_Price;

	{ Modify this for the reaction score. }
	if ( I_NPC <> Nil ) and ( I_PC <> Nil ) and ( GB <> Nil ) then begin
		React := ReactionScore( GB^.Scene , I_PC , I_NPC );
		if React < 0 then RV := RV * ( 100 - 2 * React ) div 100
		else if React > 20 then RV := RV * ( 220 - React ) div 200;
	end;

	Calculate_Asking_Price := RV;
end;

Function Count_Faction_Buddies( GB: GameBoardPtr; FacID: Integer ): Integer;
	{ Return the number of positive relationships the PC has with this }
	{ particular faction. }
	function CountBuddies( LList: GearPtr ): LongInt;
		{ Count the number of buddies along this path. }
	var
		N: LongInt;
	begin
		N := 0;
		while LList <> Nil do begin
			if ( LList^.G = GG_Character ) and ( NAttValue( LList^.NA , NAG_Relationship , 0 ) > 0 ) and ( GetFactionID( LList ) = FacID ) and NotDestroyed( LList ) then Inc( N );
			N := N + CountBuddies( LList^.SubCom );
			N := N + CountBuddies( LList^.InvCom );
			LList := LList^.Next;
		end;
		CountBuddies := N;
	end;
var
	Adv: GearPtr;
begin
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit( 0 );
	Adv := FindRoot( GB^.Scene );
	Count_Faction_Buddies := CountBuddies( GB^.Meks ) + CountBuddies( Adv^.SubCom ) + CountBuddies( Adv^.InvCom );
end;



Function YesNoMenu( GB: GameBoardPtr; Prompt,YesMsg,NoMsg: String ): Boolean;
	{ This will open up a small window in the middle of the map }
	{ display, then prompt the user for a choice. }
	{ Return TRUE if the "yes" option was selected, or FALSE if }
	{ the "no" option was selected. }
	{ This function performs no screen cleanup. }
var
	rpm: RPGMenuPtr;
	N: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );
	AddRPGMenuItem( RPM , YesMsg , 1 );
	AddRPGMenuItem( RPM , NoMsg , -1 );
	RPM^.Mode := RPMNoCancel;

	AS_GB := GB;
	ASRD_MemoMessage := Prompt;
	N := SelectMenu( RPM , @MemoPageRedraw );

	DisposeRPGMenu( RPM );

	{ Do cleanup before branching. }
	CombatDisplay( GB );

	YesNoMenu := N <> -1;
end;

Function SV_Range( GB: GameBoardPtr; UID1,UID2: LongInt ): Integer;
	{ Locate the two gears pointed to by the UIDs, then calculate }
	{ the range between them. If one or both are NIL, or if one or }
	{ both are off the map, return 0. }
var
	M1,M2: GearPtr;
begin
	{ Error check. }
	if GB = Nil then Exit( 0 );

	M1 := LocateMekByUID( GB , UID1 );
	M2 := LocateMekByUID( GB , UID2 );

	if ( M1 <> Nil ) and OnTheMap( GB , M1 ) and ( M2 <> Nil ) and OnTheMap( GB , M2 ) then begin
		SV_Range := Range( GB , M1 , M2 );
	end else begin
		SV_Range := 0;
	end;
end;

Function SV_PCSkillVal( GB: GameBoardPtr; Skill,Stat: Integer ): Integer;
	{ Return the PC's base skill value. This used to be easy until those }
	{ stupid lancemates came along... Check all PCs and lancemates, and }
	{ return the highest value. }
var
	M: GearPtr;
	HiSkill,T: Integer;
begin
	{ Error check. }
	if GB = Nil then Exit( 0 );

	M := GB^.Meks;
	HiSkill := 0;
	while M <> Nil do begin
		T := NAttValue( M^.NA , NAG_Location , NAS_Team );
		if GearActive( M ) and ( ( T = NAV_DefPlayerTeam ) or ( T = NAV_LancemateTeam ) ) then begin
			T := SkillValue( M , Skill , Stat );
			if T > HiSkill then HiSkill := T;
		end;

		M := M^.Next;
	end;

	SV_PCSkillVal := HiSkill;
end;

Function SV_WorldID( GB: GameBoardPtr ): Integer;
	{ Return the ID number of the current world. }
var
	Scene: GearPtr;
begin
	Scene := FindWorld( GB , GB^.Scene );
	if Scene <> Nil then SV_WorldID := Scene^.S
	else SV_WorldID := 0;
end;

Function AV_ProcessConcert( GB: GameBoardPtr; AudienceSize,SkillTarget: Integer ): Integer;
	{ A concert is beginning! Yay! }
var
	PC: GearPtr;
begin
	PC := LocatePC( GB );
	AV_ProcessConcert := DoConcert( GB , PC , AudienceSize , SkillTarget );
end;

Function EncounterMapType( GB: GameBoardPtr; X,Y: Integer ): Integer;
	{ The PC has met an encounter at point X,Y on the current map. Return the }
	{ map generator which this encounter should use. }
begin
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and AStringHasBString( SAttValue( GB^.Scene^.SA , 'SPECIAL' ) , 'UNIFORM' ) then begin
		EncounterMapType := GB^.Scene^.Stat[ STAT_MapGenerator ];
	end else if GB <> Nil then begin
		EncounterMapType := TileTerrain( GB , X , Y )
	end else begin
		EncounterMapType := 1;
	end;
end;

Procedure AS_SetExit( GB: GameBoardPtr; RC: Integer );
	{ Several things need to be done when exiting the map. }
	{ This procedure should centralize most of them. }
var
	Dest,Src,SrcHome: GearPtr;
	T: Integer;
begin
	{ Only process this request if we haven't already set an exit. }
	if ( GB <> Nil ) and ( not GB^.QuitTheGame ) then begin
		GB^.QuitTheGame := True;
		GB^.ReturnCode := RC;
		if GB^.Scene <> Nil then begin
			if IsInvCom( GB^.SCene ) then begin
				SCRIPT_Gate_To_Seek := NAttValue( GB^.Scene^.NA , NAG_Narrative , NAS_EntranceScene );
			end else begin
				SCRIPT_Gate_To_Seek := RealSceneID( GB^.Scene );
			end;

			Dest := FindActualScene( GB , RC );

			{ Set the return value for metascenes. }
			if ( Dest = Nil ) and ( SCRIPT_DynamicEncounter = Nil ) then begin
				{ If we've been asked to exit to a nonexistant scene, }
				{ try to re-enter the current scene again. }
				GB^.ReturnCode := FindGearScene( GB^.Scene , GB );

			end else if ( RC < 0 ) and ( Dest <> Nil ) then begin
				{ This is a metascene. Set the entrance value and the map generator }
				{ if appropriate. }
				if ( NAttValue( Dest^.NA , NAG_Narrative , NAS_EntranceScene ) = 0 ) and ( GB^.Scene^.G = GG_Scene ) then begin
					SetNAtt( Dest^.NA , NAG_Narrative , NAS_EntranceScene , NAttValue( GB^.Scene^.NA , NAG_Narrative , NAS_NID ) );
				end;

				{ If the metascene has no map generator set, better set the map }
				{ generator from the tile the entrance is sitting upon. }
				if Dest^.Stat[ STAT_MapGenerator ] = 0 then begin
					Src := FindSceneEntrance( FindRoot( GB^.Scene ) , GB , RC );
					if ( Src <> Nil ) and OnTheMap( GB , Src ) and IsFoundAlongTrack( GB^.Meks , Src ) then begin
						Dest^.Stat[ STAT_MapGenerator ] := EncounterMapType( GB , NAttValue( Src^.NA , NAG_Location , NAS_X ) , NAttValue( Src^.NA , NAG_Location , NAS_Y ) );
						{ If this will make the encounter a space map, set the map-scroll tag. }
						if Dest^.Stat[ STAT_MapGenerator ] = TERRAIN_Space then Dest^.Stat[ STAT_SpaceMap ] := 1;
						SrcHome := GB^.Scene;
					end else begin
						{ Copy the entrance's map generator and hope for the best. }
						SrcHome := FindActualScene( GB , FindGearScene( Src , GB ) );
						if SrcHome = Nil then SrcHome := GB^.Scene;
						Dest^.Stat[ STAT_MapGenerator ] := SrcHome^.Stat[ STAT_MapGenerator ];
						{ If this will make the encounter a space map, set the map-scroll tag. }
						if Dest^.Stat[ STAT_MapGenerator ] = TERRAIN_Space then Dest^.Stat[ STAT_SpaceMap ] := 1;
					end;

					{ Also copy over the tileset + backdrop. }
					SetNAtt( Dest^.NA , NAG_SceneData , NAS_TileSet , NAttValue( SrcHome^.NA , NAG_SceneData , NAS_TileSet ) );
					SetNAtt( Dest^.NA , NAG_SceneData , NAS_Backdrop , NAttValue( SrcHome^.NA , NAG_SceneData , NAS_Backdrop ) );

					{ Copy the environmental effects from the parent scene. }
					for t := 1 to Num_Environment_Variables do begin
						SetNAtt( Dest^.NA , NAG_EnvironmentData , T , NAttValue( SrcHome^.NA , NAG_EnvironmentData , T ) );
					end;
				end;

			end else if ( Dest <> Nil ) and ( Dest^.G = GG_World ) then begin
				{ If we're exiting to the world, the gate to seek }
				{ should be the root scene. }
				Src := FindRootScene( GB^.Scene );
				if Src <> Nil then SCRIPT_Gate_To_Seek := NAttValue( Src^.NA , NAG_Narrative , NAS_NID );
			end;
		end;
	end;
end;

Function FormatMemoString( GB: GameBoardPtr; const Msg: String ): String;
	{ Add the name of the city to the memo. }
var
	RootScene: GearPtr;
begin
	RootScene := FindRootScene( GB^.Scene );
	if ( RootScene <> Nil ) and ( msg <> '' ) then begin
		FormatMemoString := GearName( RootScene ) + ': ' + msg;
	end else begin
		FormatMemoString := msg;
	end;
end;

Function PlotHintString( GB: GameBoardPtr; Source: GearPtr; N: LongInt; AddMemo: Boolean ): String;
	{ Determine hint string N for this plot. }
	{ Also store a rumor memo. }
	Function GenericHintString: String;
		{ We can't find a valid hint string for this plot. Just return }
		{ some generic advice. }
	begin
		GenericHintString := MsgString( 'GENERIC_HINT_STRING_' + BStr( Random( 6 ) + 1 ) );
	end;
var
	Plot: GearPtr;
	IsFound: Boolean;
	msg,memo_msg: String;
begin
	{ Start looking for the correct message. }
	repeat
		Plot := SeekGearByNID( Nil, FindRoot( GB^.Scene ) , N );

		if Plot <> Nil then begin
			msg := SAttValue( Plot^.SA , 'HINT' );
			DeleteWhiteSpace( msg );
			IsFound := True;
			if ( Length( msg ) > 1 ) and ( msg[1] = ':' ) then begin
				{ This is a redirect. }
				DeleteFirstChar( msg );
				N := ExtractValue( msg );
				IsFound := False;
			end;
		end else begin
			msg := GenericHintString();
			IsFound := True;
		end;
	until IsFound;

	if msg = '' then PlotHintString := GenericHintString
end;

Function CurrentPCRenown( GB: GameBoardPtr ): Integer;
	{ Return the current renown score of the PC. }
var
	PC: GearPtr;
begin
	PC := LocatePilot( LocatePC( GB ) );
	if PC <> Nil then begin
		CurrentPCRenown := NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned );
	end else begin
		CurrentPCRenown := 0;
	end;
end;




Procedure HandleWhereAreYou( GB: GameBoardPtr );
	{ The PC has asked the NPC where he is. The NPC will tell the PC }
	{ his or her current location. }
var
	SID: Integer;
begin
	SID := FindSceneID( I_NPC , GB );
	if SID <> 0 then begin
		CHAT_Message := ReplaceHash( MsgString( 'WHEREAREYOU_IAMHERE' ) , SceneName( GB , SID , True ) );
	end else begin
		CHAT_Message := MsgString( 'WHEREAREYOU_Dunno' );
	end;
end;


Procedure HandleAskAboutRumors( GB: GameBoardPtr; Source: GearPtr );
	{ The PC wants to find some rumors. Make it so. }
var
	RL,RL_Skill: GearPtr;
	SkVal,BestScore,SkRoll: Integer;
	NPCDesc,RL_Script: String;
	Rumor_List,R: SAttPtr;
	Rumor_Error: Boolean;
	RPM: RPGMenuPtr;
begin

end;


Procedure AddLancemate( GB: GameBoardPtr; NPC: GearPtr );
	{ Add the listed NPC to the PC's lance. }
var
	Mecha,Pilot: GearPtr;
	Timer: LongInt;
begin
	{ This NPC will have to quit their current team to do this... }
	{ so, better set a trigger. }
	SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) ) );

	{ If this is the first time the lancemate has joined, add the NPC's mecha. }
	if IsACombatant( NPC ) and ( NAttValue( NPC^.NA , NAG_Narrative , NAS_GaveLMMecha ) = 0 ) then begin
		Mecha := SelectNPCMecha( GB , GB^.Scene , NPC );
		if Mecha <> Nil then begin
			SetNAtt( Mecha^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
			DeployGear( GB , Mecha , False );
			AssociatePilotMek( GB^.Meks , NPC , Mecha );
			SetNAtt( NPC^.NA , NAG_Narrative , NAS_GaveLMMecha , 1 );
		end;
	end;

	{ Set the plot recharge timer to at least 12 hours from now. }
	Timer := NAttValue( NPC^.NA , NAG_Personal , NAS_PlotRecharge );
	if Timer < ( GB^.ComTime + 43200 ) then SetNAtt( NPC^.NA , NAG_Personal , NAS_PlotRecharge , GB^.ComTime + 43200 );

	Pilot := LocatePilot( NPC );
	if Pilot <> NPC then SetNAtt( Pilot^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );

	SetNAtt( NPC^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );
	SetLancemateOrders( GB );
end;

Function AddLancemateFrontEnd( GB: GameBoardPtr; PC,NPC: GearPtr; CanCancel: Boolean ): Boolean;
	{ NPC wants to join the lance. If NPC isn't a temp lancemate, and the lance is already }
	{ full, prompt to remove a member before NPC can join. }
	{ Return TRUE if the lancemate was added, or FALSE otherwise. }
var
	NoCancel: Boolean;
	RPM: RPGMenuPtr;
	LM: GearPtr;
	N: Integer;
begin
	NoCancel := True;

	{ Step One- Check NPC's temp status, then count up the number of lancemates }
	{ to see if there's gonna be a problem. }
	if NAttValue( NPC^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_TempLancemate then begin
		{ Initialize some values. }
		AS_GB := GB;
		ASRD_MemoMessage := ReplaceHash( MsgString( 'JOINFE_Need_Space' ) , GearName( NPC ) );

		{ Count up the number of lancemates. }
		while ( LancematesPresent( GB ) >= NumLancemateSlots( GB^.Scene , PC ) ) and NoCancel do begin
			{ Remove lancemates to make room for NPC. }
			{ Create the menu. }
			RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );

			{ Create the list. }
			LM := GB^.Meks;
			N := 1;
			while LM <> Nil do begin
				if ( NAttValue( LM^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and GearActive( LM ) and IsRegularLancemate( LM ) then begin
					AddRPGMenuItem( RPM , PilotName( LM ) , N );
				end;

				Inc( N );
				LM := LM^.Next;
			end;

			RPMSortAlpha( RPM );
			AlphaKeyMenu( RPM );
			if CanCancel then AddRPGMenuItem( RPM , MsgString( 'Cancel' ) , -1 )
			else RPM^.Mode := RPMNoCancel;

			N := SelectMenu( RPM , @MemoPageReDraw );
			DisposeRPGMenu( RPM );
			if N = -1 then NoCancel := False
			else begin
				LM := RetrieveGearSib( GB^.Meks , N );
				RemoveLancemate( GB , LM , True );
			end;
		end;
	end;

	{ Step Two- we apparently have room now. Add the lancemate to the party. }
	if NoCancel then AddLancemate( GB , NPC );

	AddLancemateFrontEnd := NoCancel;
end;

Procedure AttemptJoin( GB: GameBoardPtr );
	{ I_NPC will attempt to join the party. Yay! }
var
	LMP: Integer;	{ Lancemates Present }
begin
	{ Make sure we've got an NPC to deal with. }
	if I_NPC = Nil then Exit;
	{ Also make sure the NPC isn't currently a member of the team. }
	if NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam then Exit;

	{ Need two more available lancemate points than are currently in use. }
	if CanJoinLance( GB , I_PC , I_NPC ) then begin
		if AddLancemateFrontEnd( GB , I_PC , I_NPC , True ) then CHAT_Message := MsgString( 'JOIN_JOIN' )
		else CHAT_Message := MsgString( 'JOIN_Cancel' );
	end else begin
		LMP := LancematesPresent( GB );
		if ReactionScore( GB^.Scene , I_PC , I_NPC ) < 25 then begin
			CHAT_Message := MsgString( 'JOIN_REFUSE' );
		end else if LMP >= NumLancemateSlots( GB^.Scene , I_PC ) then begin
			CHAT_Message := MsgString( 'JOIN_NOPOINT' );
		end else begin
			CHAT_Message := MsgString( 'JOIN_BUSY' );
		end;
	end;
end;

Procedure RemoveLancemate( GB: GameBoardPtr; Mek: GearPtr; DoMessage: Boolean );
	{ Remove NPC from the party. }
	{ If this location isn't a good one for the LM, move the LM to a better place. }
var
	NPC,DestScene: GearPtr;
	msg: String;
begin
	if Mek^.G = GG_Mecha then begin
		NPC := ExtractPilot( Mek );
		if NPC = Nil then Exit;
		DeployGear( GB , NPC , False );
	end else begin
		NPC := Mek;
	end;

	if IsInvCom( GB^.Scene ) or ( not IsSafeArea( GB ) ) then begin
		{ This isn't a good place for the NPC to stay. Better move it }
		{ to somewhere else. }

		{ Step One- Locate the destination scene. }
		DestScene := ElementSearch( FindRootScene( GB^.Scene ) , Nil , GG_Scene , '(:BUILD|:MEETI) :PUBLI -:ENEMY' , GB );

		if DestScene <> Nil then begin
			{ Step Two- Announce the lancemate's destination. }
			msg := ReplaceHash( MsgString( 'QUIT_LANCE_GO' ) , GearName( DestScene ) );

			{ Step Three- Delink the lancemate and send it there. }
			{  Note that NPC might actually be the NPC's mecha. Deal with it. }
			DelinkGearForMovement( GB , NPC );
			InsertInvCom( DestScene , NPC );
			SetSAtt( NPC^.SA , 'TEAMDATA <Ally>' );
			ChooseTeam( NPC , DestScene );

		end else begin
			{ Fail. Just stick the NPC here, for now. }
			msg := MsgString( 'QUIT_LANCE' );

			SetSAtt( NPC^.SA , 'TEAMDATA <Ally>' );
			ChooseTeam( NPC , GB^.Scene );
		end;
	end else begin
		{ The LM can just hang around here until the PC gets back. }
		msg := MsgString( 'QUIT_LANCE' );
		SetSAtt( NPC^.SA , 'TEAMDATA <Ally>' );
		ChooseTeam( NPC , GB^.Scene );
	end;

	{ Set the rumor recharge to six hours from now. After all, the LM }
	{ was hanging around with the PC... they need some time to hear things. }
	SetNAtt( NPC^.NA , NAG_Personal , NAS_RumorRecharge , GB^.ComTime + 21600 );

	if DoMessage then begin
		if NPC = I_NPC then begin
			CHAT_Message := msg;
		end else begin
			Monologue( GB , NPC , msg );
		end;
	end;
end;

Procedure HandleQuitLance( GB: GameBoardPtr );
	{ I_NPC will quit the party. }
begin
	if I_NPC = Nil then Exit;
	RemoveLancemate( GB , I_NPC , True );
end;



Procedure HandleInteract( GB: GameBoardPtr; PC,NPC,Persona: GearPtr );
	{ The player has just entered a conversation. }
	{ HOW THIS WORKS: The interaction menu is built by an ASL script. }
	{ the player selects one of the provided responses, which will }
	{ either trigger another script ( V >= 0 ) or call one of the }
	{ standard interaction routines ( V < 0 ) }
	Procedure InvokePNode( trigger: String );
		{ Invoke the requested node of the requested persona. }
	begin
		{ Call the Conversation function in Lua. }
		lua_getglobal( MyLua , 'gh_conversation' );
		lua_pushlightuserdata( MyLua , Pointer( I_Persona ) );
		lua_pushlstring( MyLua , @Trigger[1] , Length( Trigger ) );
		lua_pushlightuserdata( MyLua , Pointer( I_NPC ) );
		if lua_pcall( MyLua , 3 , 0 , 0 ) <> 0 then begin
			Trigger := 'InvokePNode ERROR: ' + lua_tostring( MyLua , -1 );
			DialogMsg( Trigger );
			RecordError( Trigger );
		end;

		{ Get rid of the boolean or error message now on the stack. }
		lua_settop( MyLua , 0 );
	end;
	Function PNodeTrigger( PNode: LongInt ): String;
		{ Return the trigger label for this numbered PNode. }
	begin
		PNodeTrigger := 'node_' + BStr( PNode );
	end;
var
	IntScr: String;		{ Interaction Script }
	N,FreeRumors: Integer;
	RTT: LongInt;		{ ReTalk Time }
	T: String;
	PNode: LongInt;

	MI: RPGMenuItemPtr;	{ For removing options once they've been used. }
begin
	{ Start by allocating the menu. }
	IntMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
	IntMenu^.Mode := RPMEscCancel;

	{ Initialize interaction variables. }
	I_PC := PC;
	I_NPC := NPC;
	AS_GB := GB;

	{ Since the conversation can be switched by REVERTPERSONA and maybe some other }
	{ effects, from this point onwards use I_PERSONA rather than PERSONA. }
	I_Persona := Persona;

	{ Add a divider to the skill roll history. }
	SkillCommentDivider;

	{ We start from the greeting node. }
	PNode := PNode_Greeting;
	I_HaveNotShopped := true;
	InvokePNode( PNodeTrigger( PNode ) );

	repeat
		{ Print the NPC description. }
		{ This could change depending upon what the PC does. }
		if IntMenu^.NumItem > 0 then begin
			AS_GB := GB;
			CHAT_React := ReactionScore( GB^.Scene , PC , NPC );
			N := SelectMenu( IntMenu , @InteractRedraw );

		end else begin
			{ If the menu is empty, we must leave this procedure. }
			{ More importantly, we better not do anything in }
			{ the conditional below... Set N to equal a "goodbye" result. }
			N := -1;
		end;

		if N >= PNode_Greeting then begin
			{ One of the placed options have been triggered. }
			{ Attempt to find the appropriate script to }
			{ invoke. }
			I_HaveNotShopped := true;
			InvokePNode( PNodeTrigger( N ) );

		end else if N = CMD_Join then begin
			AttemptJoin( GB );
			{ After attempting to join, remove the JOIN option. }
			MI := SetItemByValue( IntMenu , CMD_Join );
			if MI <> Nil then RemoveRPGMenuItem( IntMenu , MI );
			SetItemByPosition( IntMenu , 1 );

		end else if N = CMD_Quit then begin
			HandleQuitLance( GB );
			ClearMenu( IntMenu );

		end else if N = CMD_WhereAreYou then begin
			HandleWhereAreYou( GB );

		end else if N = CMD_AskAboutRumors then begin
			HandleAskAboutRumors( GB , Persona );
			MI := SetItemByValue( IntMenu , CMD_AskAboutRumors );
			if MI <> Nil then RemoveRPGMenuItem( IntMenu , MI );
			SetItemByPosition( IntMenu , 1 );

		end;

	until ( N = -1 ) or ( IntMenu^.NumItem < 1 ) or ( I_NPC = Nil );

	{ If the menu is empty, pause for a minute. Or at least a keypress. }
	if ( IntMenu^.NumItem < 1 ) and I_HaveNotShopped then begin
		InteractRedraw;
		DoFlip;
		MoreKey;
	end;

	{ Update the NumberOfConversations counter. }
	if I_NPC <> Nil then AddNAtt( NPC^.NA , NAG_Personal , NAS_NumConversation , 1 );

	{ Get rid of the menu. }
	DisposeRPGMenu( IntMenu );
end;

Procedure PCDoVerbalAttack( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ The PC wants to verbally abuse this NPC. If it's possible do so. If it }
	{ isn't possible, then explain why. }
begin
	NPC := LocatePilot( NPC );
	if CurrentMental( PC ) < 1 then begin
		DialogMsg( MsgSTring( 'VERBALATTACK_NoMP' ) );
	end else if ( NPC <> Nil ) and CanSpeakWithTarget( GB , PC , NPC ) then begin
		if AreEnemies( GB , PC , NPC ) then begin
			DoVerbalAttack( GB , PC , FindRoot( NPC ) );
			{ When the PC taunts an enemy, it takes an action. }
			SetNAtt( PC^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ReactionTime( PC ) );
		end else begin
			DialogMsg( ReplaceHash( MsgSTring( 'TAUNT_OnlyEnemies' ) , GearName( NPC ) ) );
		end;
	end else begin
		DialogMsg( ReplaceHash( MsgSTring( 'TALKING_TooFar' ) , GearName( NPC ) ) );
	end;
end;

Procedure DoTalkingWIthNPC( GB: GameBoardPtr; PC,Mek: GearPtr; ByTelephone: Boolean );
	{ Actually handle the talking with an NPC already selected. }
var
	Persona,NPC: GearPtr;
	CID: Integer;
	React: Integer;
	ReTalk: LongInt;
begin
	NPC := LocatePilot( Mek );
	if ( NPC <> Nil ) and GearOperational( NPC ) and AreEnemies( GB , Mek , PC ) and NotAnAnimal( NPC ) and IsFoundAlongTrack( GB^.Meks , FindRoot( NPC ) ) and ( NATtValue( NPC^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) <> NAV_NowSurrendered ) then begin
		PCDoVerbalAttack( GB , PC , NPC );

	end else if ( NPC <> Nil ) and GearOperational( NPC ) then begin
		if ByTelephone or CanSpeakWithTarget( GB , PC , NPC ) then begin
			CID := NAttValue( NPC^.NA , NAG_Narrative , NAS_NID );
			if CID <> 0 then begin
				{ Everything should be okay to talk... Now see if the NPC wants to. }
				{ Determine the NPC's RETALK and REACT values. }
				React := ReactionScore( GB^.Scene , PC , NPC );

				Persona := SeekPersona( GB , CID );

				{ Surrendered NPCs never refuse to talk. }
				if NATtValue( NPC^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) = NAV_NowSurrendered then begin
					DialogMsg( ReplaceHash( MsgSTring( 'TALKING_Start' ) , GearName( NPC ) ) );

					HandleInteract( GB , PC , NPC , Persona );
					CombatDisplay( gb );

				{ If the NPC really doesn't like the PC, }
				{ they'll refuse to talk on principle. }
				end else if ( ( React + RollStep( SkillValue ( PC , NAS_Conversation , STAT_Ego ) ) ) < -Random( 120 ) ) or ( AreEnemies( GB , NPC , PC ) and IsFoundAlongTrack( GB^.Meks , NPC ) ) then begin
					DialogMsg( ReplaceHash( MsgSTring( 'TALKING_RefuseHard' ) , GearName( NPC ) ) );

				{ If the NPC is ready to talk, is friendly with the PC, or has a PERSONA gear defined, }
				{ they'll be willing to talk. }
				end else if ( ReTalk < GB^.ComTime ) or ( Random( 50 ) < ( React + 20 ) ) or ( Persona <> Nil ) then begin
					DialogMsg( ReplaceHash( MsgSTring( 'TALKING_Start' ) , GearName( NPC ) ) );

					HandleInteract( GB , PC , NPC , Persona );
					CombatDisplay( gb );

				end else begin
					DialogMsg( ReplaceHash( MsgSTring( 'TALKING_RefuseSoft' ) , GearName( NPC ) ) );

				end;

				WaitAMinute( GB , PC , ReactionTime( PC ) );
			end else begin
				DialogMsg( MsgSTring( 'TALKING_NoReply' ) );
			end;
		end else begin
			DialogMsg( ReplaceHash( MsgSTring( 'TALKING_TooFar' ) , GearName( NPC ) ) );
		end;
	end else begin
		DialogMsg( 'Not found!' );
	end;
end;

Procedure ForceInteract( GB: GameBoardPtr; CID: LongInt );
	{ Attempt to force the PC to converse with the provided NPC. }
var
	PC,NPC,Interact: GearPtr;
begin
	{ Locate all the required elements. }
	PC := LocatePilot( LocatePC( GB ) );
	NPC := SeekGearByNID( GB , GB^.Scene , CID );
	Interact := SeekPersona( GB , CID );

	if ( PC <> Nil ) and ( NPC <> Nil ) and NotDestroyed( PC ) then begin
		{ Before initiating the conversation, get rid of the }
		{ recharge timer, since the NPC initiated this chat }
		{ and won't get pissed off. }

		{ Print an appropriate message. }
		if NPC^.Parent = Nil then begin
			{ The NPC has no parent, so it must be on the gameboard }
			{ and not in a mecha. Use the conversation message. }
			DialogMsg( ReplaceHash( MsgString( 'FORCECHAT_SPEAK' ) , GearName( NPC ) ) );
		end else begin
			{ Use the contact message. }
			DialogMsg( ReplaceHash( MsgString( 'FORCECHAT_CONTACT' ) , GearName( NPC ) ) );
		end;

		{ Hand everything to the interaction procedure. }
		HandleInteract( GB , PC , NPC , Interact );
	end;
end;

Function TriggerGearScript( GB: GameBoardPtr; MyGear: GearPtr; const Trigger: String ): Boolean;
	{ Attempt to trigger the requested script in this gear. If the }
	{ script cannot be found, then do nothing. }
	{ IMPORTANT: The Trigger should be upper case. }
var
	E: String;
	it: Boolean;
begin
	{ Initialize needed variables. }
	AS_GB := GB;

	{ Next, call the HandleTrigger function in Lua. }
	lua_getglobal( MyLua , 'gh_trigger' );
	lua_pushlightuserdata( MyLua , Pointer( MyGear ) );
	lua_pushlstring( MyLua , @Trigger[1] , Length( Trigger ) );
	if lua_pcall( MyLua , 2 , 1 , 0 ) <> 0 then begin
		E := 'HandleTrigger ERROR: ' + lua_tostring( MyLua , -1 );
		DialogMsg( E );
		RecordError( E );
		it := True;
	end else begin
		it := lua_toboolean( MyLua , -1 );
	end;

	{ Get rid of the boolean or error message now on the stack. }
	lua_settop( MyLua , 0 );

	TriggerGearScript := it;
end;

Function CheckTriggerAlongPath( const T: String; GB: GameBoardPtr; Plot: GearPtr; CheckAll: Boolean ): Boolean;
	{ Check all the active narrative gears in this list (plots, stories, and factions) }
	{ looking for events which match the provided trigger. }
	{ Return TRUE if an event was invoked, or FALSE if no event was encountered. }
var
	P2: GearPtr;
	it,I2: Boolean;
	LT,TempList: SAttPtr;	{ Local Trigger counter }
	LT_tmp: STring;	{ The content of the local trigger currently being processed. }
begin
	it := False;
	while Plot <> Nil do begin
		P2 := Plot^.Next;
		if CheckAll or ( Plot^.G = GG_Plot ) or ( Plot^.G = GG_Faction ) or ( Plot^.G = GG_Story ) or ( Plot^.G = GG_Adventure ) or ( Plot^.G = GG_CityMood ) then begin
			{ FACTIONs and STORYs can hold active plots in their InvCom. }
			if ( Plot^.G = GG_Faction ) or ( Plot^.G = GG_Story ) or ( Plot^.G = GG_Adventure ) then CheckTriggerAlongPath( T , GB , Plot^.InvCom , CheckAll);

			{ Check the trigger against this gear's scripts. }
			I2 := TriggerGearScript( GB , Plot , T );
			it := it or I2;

			{ The trigger above might have changed the }
			{ structure, so reset P2. }
			P2 := Plot^.Next;

			{ Remove the plot, if it's been advanced. }
			if Plot^.G = GG_AbsolutelyNothing then begin
				if IsInvCom( Plot ) then RemoveGear( Plot^.Parent^.InvCom , Plot )
				else if IsSubCom( Plot ) then RemoveGear( Plot^.Parent^.SubCom , Plot );
			end;
		end;
		Plot := P2;
	end;
	CheckTriggerAlongPath := it;
end;

Procedure CheckRandMapScripts( const T: String; GB: GameBoardPtr );
	{ Check all the local scripts attached to this gameboard. }
	{ They'll be the GG_RandMapScripts attached to GB^.Scene^.SubCom. }
var
	Plot,P2: GearPtr;
	LT,TempList: SAttPtr;	{ Local Trigger counter }
	LT_tmp: STring;	{ The content of the local trigger currently being processed. }
begin
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;
	Plot := GB^.Scene^.SubCom;
	while Plot <> Nil do begin
		P2 := Plot^.Next;
		if Plot^.G = GG_RandMapScript then begin
			{ Check the trigger against this gear's scripts. }
			TriggerGearScript( GB , Plot , T );

			{ The trigger above might have changed the }
			{ structure, so reset P2. }
			P2 := Plot^.Next;

			{ Remove the plot, if it's been advanced. }
			if Plot^.G = GG_AbsolutelyNothing then begin
				RemoveGear( Plot^.Parent^.SubCom , Plot );
			end;
		end;
		Plot := P2;
	end;
end;

Procedure HandleTriggers( GB: GameBoardPtr );
	{ Go through the list of triggers, enacting events if any are }
	{ found. Deallocate the triggers as they are processed. }
var
	TList,TP: SAttPtr;	{ Trigger List , Trigger Pointer }
	E,msg: String;
	City: GearPtr;
begin
	IntMenu := Nil;

	{ Only try to implement triggers if this gameboard has a scenario }
	{ defined. }
	if GB^.Scene <> Nil then begin

		{ Some of the events we process might add their own }
		{ triggers to the list. So, we check all the triggers }
		{ currently set, then look at the GB^.Trig list again }
		{ to see if any more got put there. }
		while GB^.Trig <> Nil do begin
			{ Copy the list pointer to TList, clear the }
			{ list pointer from GB, and set the pointer }
			{ to the first trigger. }
			TList := GB^.Trig;
			GB^.Trig := Nil;
			TP := TList;

			while TP <> Nil do begin
				{ Commands can be embedded in the triggers list. }
				{ The actual point of this is to allow scripts }
				{ to automatically activate interactions & props. }
				if ( Length( TP^.Info ) > 0 ) and ( TP^.Info[1] = '!' ) then begin
					{ Copy the command. }
					E := UpCase( ExtractWord( TP^.Info ) );
					DeleteFirstChar( E );

					if E = 'TALK' then begin
						ForceInteract( GB , ExtractValue( TP^.Info ) );
					end else if E = 'ANNOUNCE' then begin
						msg := msgString( TP^.Info );
						if msg <> '' then YesNoMenu( GB , msg , '' , '' );
					end;

					{ Clear this trigger. }
					TP^.Info := '';

				end else if TP^.Info <> '' then begin
					{ Check the PLOTS, FACTIONS and STORIES in }
					{ Adventure/InvCom first. }
					TP^.Info := UpCase( TP^.Info );

					if GB^.Scene^.Parent <> Nil then begin
						CheckTriggerAlongPath( TP^.Info , GB , FindRoot( GB^.Scene ) , False );
					end;

					{ Check for quests and moods in the current city next. }
					City := FindRootScene( GB^.Scene );
					if ( City <> Nil ) then begin
						CheckTriggerAlongPath( TP^.Info , GB , City^.InvCom , False );
					end;

					CheckRandMapScripts( TP^.Info , GB );

					{ Check the current scene last. }
					TriggerGearScript( GB , GB^.Scene , TP^.Info );
					CheckTriggerAlongPath( TP^.Info , GB , GB^.meks , True );
				end;

				TP := TP^.Next;
			end;

			{ Get rid of the trigger list. }
			DisposeSAtt( TList );

		end;
	end;
end;

Function StartRescueScenario( GB: GameBoardPtr; PC: GearPtr; Context: String ): Boolean;
	{ Attempt to load a rescue scenario for the PC. }
	Function RescueContext: String;
		{ Generate a string telling everything that needs to be told about }
		{ the PC's current location. }
	var
		RC: String;
		C: GearPtr;
	begin
		RC := Context;
		AddTraits( RC , SAttValue( GB^.Scene^.SA , 'CONTEXT' ) );
		AddTraits( RC , SATtValue( GB^.Scene^.SA , 'DESIG' ) );
		AddTraits( RC , SAttValue( GB^.Scene^.SA , 'TYPE' ) );
		AddTraits( RC , SAttValue( GB^.Scene^.SA , 'TERRAIN' ) );

		{ Next add the data for the city we're located in, its faction, and the }
		{ world that it's located in. }
		C := FindRootScene( GB^.Scene );
		if C <> Nil then begin
			AddTraits( RC , SAttValue( C^.SA , 'DESIG' ) );
			C := SeekFaction( FindRoot( GB^.Scene ) , NAttValue( C^.NA , NAG_Personal , NAS_FactionID ) );
			if C <> Nil then AddTraits( RC , SAttValue( C^.SA , 'DESIG' ) );
		end;
		RescueContext := RC;
	end;	{ RescueContext }
var
	Rescue_list,R: GearPtr;
	ItWorked: Boolean;
begin
	{ If no scene, can't be rescued. Sorry. }
	if GB^.Scene = Nil then Exit( False );

	{ Assume the rescue failed unless shown otherwise. }
	ItWorked := False;

	{ Load the rescue files. }
	Rescue_List := AggregatePattern( 'RESCUE_*.txt' , Series_Directory );

	{ Generate the complete context for the rescue. }
	Context := RescueContext;

	while Rescue_List <> Nil do begin
		R := FindNextComponent( Rescue_List , Context );

		if R <> Nil then begin
			DelinkGear( Rescue_List , R );
			SetNAtt( R^.NA , NAG_ElementID , 1 , GB^.Scene^.S );
{			if InsertPlot( FindRootScene( GB^.Scene ) , FindRoot( GB^.Scene ) , R , GB , CurrentPCRenown( GB ) ) then begin
				{ Start by printing a message, since the time taken by the }
				{ rescue scenario is likely to cause a noticeable delay. }
				DialogMsg( MsgString( 'JustAMinute' ) );
				CombatDisplay( GB );
				DoFLip;

				DoCompleteRepair( PC );
				DisposeGear( Rescue_List );
				SetTrigger( GB , 'UPDATE' );
				HandleTriggers( GB );
				ItWorked := True;
			end;
}
		end else begin
			DisposeGear( Rescue_List );
		end;
	end;

	StartRescueScenario := ItWorked;
end;

	{  **************************  }
	{  ***   LUA  FUNCTIONS   ***  }
	{  **************************  }

	Function GetLuaGear( GB: GameBoardPtr; ThisLua: PLua_State; idx: Integer ): GearPtr;
		{ Lua wants us to use a gear. If we're passed a UserData, }
		{ assume that this is a pointer to a gear. If we're passed }
		{ a number, assume that it's a NarrativeID. If we get }
		{ anything the heck else assume that someone screwed up. }
	var
		NID: LongInt;
		tmp: GearPtr;
	begin
		if lua_isuserdata( ThisLua , idx ) then begin
			{ This is apparently a pointer to a gear. WARNING: It may }
			{ not be a valid pointer!!! Risky operation!!! }
			{ FIXME: can we require that this be in the gh table, as a check? }
			GetLuaGear := GearPtr( lua_touserdata( ThisLua , idx ) );
		end else if lua_isnumber( ThisLua , idx ) then begin
			{ This must be a NarrativeID. Search for the gear being sought. }
			NID := lua_tointeger( ThisLua , idx );
			GetLuaGear := SeekGearByNID( GB , GB^.Scene , NID );

		end else if lua_istable( ThisLua , idx ) then begin
			{ This is a gear's lua table. }
			lua_pushstring( ThisLua , 'ptr' );
			lua_gettable( ThisLua , idx );
			if lua_isuserdata( ThisLua , lua_gettop( ThisLua ) ) then begin
				tmp := GearPtr( lua_touserdata( ThisLua , lua_gettop( ThisLua ) ) );
				lua_pop( ThisLua , 1 );
				GetLuaGear := tmp;
			end else begin
				RecordError( 'ERROR: GetLuaGear passed a table with malformed "ptr" field' );
				lua_pop( ThisLua , 1 );
				GetLuaGear := Nil;
			end;

		end else begin
			{ What the hell did you just try to pass me? Get rid of it }
			{ before someone gets hurt. }
			RecordError( 'ERROR: GetLuaGear passed a ' + lua_typename( ThisLua , idx ) );
			GetLuaGear := Nil;
		end;
	end;

	Function Lua_GetGearG( MyLua: PLua_State ): LongInt; cdecl;
		{ Take a gear and return its G descriptor. }
		{ Record an error if the gear is not found. }
	var
		MyGear: GearPtr;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );

		if MyGear <> Nil then begin
			lua_pushinteger( MyLua , MyGear^.G );
		end else begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: GetGearG passed nonexistant gear!' );
		end;

		Lua_GetGearG := 1;
	end;

	Function Lua_GetGearS( MyLua: PLua_State ): LongInt; cdecl;
		{ Take a gear and return its S descriptor. }
		{ Record an error if the gear is not found. }
	var
		MyGear: GearPtr;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );

		if MyGear <> Nil then begin
			lua_pushinteger( MyLua , MyGear^.S );
		end else begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: GetGearS passed nonexistant gear!' );
		end;

		Lua_GetGearS := 1;
	end;

	Function Lua_GetGearV( MyLua: PLua_State ): LongInt; cdecl;
		{ Take a gear and return its V descriptor. }
		{ Record an error if the gear is not found. }
	var
		MyGear: GearPtr;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );

		if MyGear <> Nil then begin
			lua_pushinteger( MyLua , MyGear^.V );
		end else begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: GetGearV passed nonexistant gear!' );
		end;

		Lua_GetGearV := 1;
	end;

	Function Lua_RawFollowLink( MyLua: PLua_State ): LongInt; cdecl;
		{ Take a gear and return its first subcomponent. }
		{ Record an error if the gear is not found or nil if it has none. }
	var
		MyGear: GearPtr;
		target: GearPtr;
		S: Integer;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );
		S := luaL_checkint( MyLua , 2 );

		if ( MyGear <> Nil ) then begin
			case S of
				LINK_PARENT: target := MyGear^.Parent;
				LINK_NEXT: target := MyGear^.Next;
				LINK_SUBCOM: target := MyGear^.SubCom;
				LINK_INVCOM: target := MyGear^.InvCom;
				else begin
					target := Nil;
					RecordError( 'ERROR: GetGearStat passed invalid kind of link!' );
				end
			end;

			if target <> Nil then begin
				lua_pushlightuserdata( MyLua , Pointer ( target ) );
			end else begin
				lua_pushnil( MyLua );
			end
		end else if MyGear = Nil then begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: RawFollowLink passed nonexistant gear!' );
		end;

		Lua_RawFollowLink := 1;
	end;

	Function Lua_GetGearStat( MyLua: PLua_State ): LongInt; cdecl;
		{ Take a gear and return one of its stat values. }
		{ Record an error if the gear is not found. }
	var
		MyGear: GearPtr;
		S: LongInt;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );
		S := luaL_checkint( MyLua , 2 );

		if ( MyGear <> Nil ) and ( S >= 1 ) and ( S <= NumGearStats ) then begin
			lua_pushinteger( MyLua , MyGear^.Stat[ S ] );
		end else if MyGear = Nil then begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: GetGearStat passed nonexistant gear!' );
		end else begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: GetGearStat asked to get stat ' + BStr( S ) + ' from ' + GearName( MyGear ) );
		end;

		Lua_GetGearStat := 1;
	end;

	Function Lua_GetNAtt( MyLua: PLua_State ): LongInt; cdecl;
		{ Take a gear and return one of its numeric attributes. }
		{ Record an error if the gear is not found. }
	var
		MyGear: GearPtr;
		G,S: LongInt;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );
		G := luaL_checkint( MyLua , 2 );
		S := luaL_checkint( MyLua , 3 );

		if ( MyGear <> Nil ) then begin
			lua_pushinteger( MyLua , NAttValue( MyGear^.NA , G , S ) );
		end else begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: GetNAtt passed nonexistant gear!' );
		end;

		Lua_GetNAtt := 1;
	end;

	Function Lua_SetNAtt( MyLua: PLua_State ): LongInt; cdecl;
		{ Take a gear and set one of its numeric attributes. }
		{ Record an error if the gear is not found. }
	var
		MyGear: GearPtr;
		G,S,V: LongInt;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );
		G := luaL_checkint( MyLua , 2 );
		S := luaL_checkint( MyLua , 3 );
		V := luaL_checkint( MyLua , 4 );

		if ( MyGear <> Nil ) then begin
			SetNAtt( MyGear^.NA , G , S , V );
		end else begin
			RecordError( 'ERROR: SetNAtt passed nonexistant gear!' );
		end;

		Lua_SetNAtt := 0;
	end;

	Function Lua_AddNAtt( MyLua: PLua_State ): LongInt; cdecl;
		{ Take a gear and add to one of its numeric attributes. }
		{ Record an error if the gear is not found. }
	var
		MyGear: GearPtr;
		G,S,V: LongInt;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );
		G := luaL_checkint( MyLua , 2 );
		S := luaL_checkint( MyLua , 3 );
		V := luaL_checkint( MyLua , 4 );

		if ( MyGear <> Nil ) then begin
			AddNAtt( MyGear^.NA , G , S , V );
		end else begin
			RecordError( 'ERROR: SetNAtt passed nonexistant gear!' );
		end;

		Lua_AddNAtt := 0;
	end;


	Function Lua_SetGearStat( MyLua: PLua_State ): LongInt; cdecl;
		{ Take a gear and change one of its stat values. }
		{ Record an error if the gear is not found. }
	var
		MyGear: GearPtr;
		S,V: LongInt;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );
		S := luaL_checkint( MyLua , 2 );
		V := luaL_checkint( MyLua , 3 );

		if ( MyGear <> Nil ) and ( S >= 1 ) and ( S <= NumGearStats ) then begin
			MyGear^.Stat[ S ] := V;
		end else if MyGear = Nil then begin
			RecordError( 'ERROR: SetGearStat passed nonexistant gear!' );
		end else begin
			RecordError( 'ERROR: SetGearStat asked to set stat ' + BStr( S ) + ' of ' + GearName( MyGear ) );
		end;

		Lua_SetGearStat := 0;
	end;

	Function Lua_NumUnits( MyLua: PLua_State ): LongInt; cdecl;
		{ Return the number of active masters this team has on the gameboard. }
	var
		Team: LongInt;
	begin
		Team := luaL_checkint( MyLua , 1 );

		if ( AS_GB <> Nil ) then begin
			lua_pushinteger( MyLua , NumActiveMasters( AS_GB , Team ) );
		end else begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: GameBoard not found for NumUnits!' );
		end;

		Lua_NumUnits := 1;
	end;

	Function Lua_GHPrint( MyLua: PLua_State ): LongInt; cdecl;
		{ Print a string. }
	var
		msg: String;
	begin
		msg := luaL_checkstring( MyLua , 1 );
		DialogMsg( msg );
		Lua_GHPrint := 0;
	end;

	Function Lua_GHAlert( MyLua: PLua_State ): LongInt; cdecl;
		{ Print a string. }
	var
		msg: String;
	begin
		msg := luaL_checkstring( MyLua , 1 );
		if msg <> '' then begin
			YesNoMenu( AS_GB , msg , '' , '' );
			DialogMsg( msg );
		end;
		Lua_GHAlert := 0;
	end;

	Function Lua_USkillTest( MyLua: PLua_State ): LongInt; cdecl;
		{ Return TRUE if the PC makes the requested skill roll, or FALSE otherwise. }
		{ Param 1 = Skill, Param 2 = Stat }
		{ Param 3 = Target to beat }
	var
		Skill,SkStat,SkTar,SkRoll: Integer;
	begin
		Skill := luaL_checkint( MyLua , 1 );
		SkStat := luaL_checkint( MyLua , 2 );
		SkTar := luaL_checkint( MyLua , 3 );
		if AS_GB <> Nil then begin
			SkRoll := SkillRoll( AS_GB , LocatePC( AS_GB ) , Skill , SkStat , SkTar , 0 , IsSafeArea( AS_GB ) , True );
			if SkRoll >= SkTar then begin
				lua_pushboolean( MyLua , True );
			end else begin
				lua_pushboolean( MyLua , False );
			end;
		end else begin
			lua_pushboolean( MyLua , False );
		end;
		Lua_USkillTest := 1;
	end;

	Function Lua_DrawTerr( MyLua: PLua_State ): LongInt; cdecl;
		{ Alter a single gameboard tile. }
	var
		X,Y,T: LongInt;
	begin
		{ Find out where and what to adjust. }
		X := luaL_checkint( MyLua , 1 );
		Y := luaL_checkint( MyLua , 2 );
		T := luaL_checkint( MyLua , 3 );

		if ( AS_GB <> NIl ) and OnTheMap( AS_GB , X , Y ) and ( T >= 1 ) and ( T <= NumTerr ) then begin
			SetTerrain( AS_GB , X , Y , T );
		end;

		Lua_DrawTerr := 0;
	end;

	Function Lua_Return( MyLua: PLua_State ): LongInt; cdecl;
		{ An exit command has been received. }
		Procedure ReturnToScene( DefaultSID: Integer );
			{ Return from the current scene to some place appropriate. If a }
			{ "ReturnTo" value has been stored, go there. Otherwise, return to }
			{ the default scene given as a parameter. }
		var
			RtS: Integer;	{ Return To Scene }
		begin
			if ( AS_GB <> Nil ) and ( AS_GB^.Scene <> Nil ) then begin
				RtS := NAttValue( AS_GB^.Scene^.NA , NAG_Narrative , NAS_ReturnToScene );
			end else RtS := 0;
			if RtS <> 0 then begin
				SetNAtt( AS_GB^.Scene^.NA , NAG_Narrative , NAS_ReturnToScene , 0 );
				AS_SetExit( AS_GB , RtS );
			end else begin
				AS_SetExit( AS_GB , DefaultSID );
			end;
		end;
	begin
		if ( AS_GB <> Nil ) and ( AS_GB^.Scene <> Nil ) and ( FindROot( AS_GB^.Scene )^.G = GG_Adventure ) and ( FindROot( AS_GB^.Scene )^.S = GS_ArenaCampaign ) then begin
			{ In an arena campaign, return always returns with an exit value of 1. }
			AS_GB^.QuitTheGame := True;
			AS_GB^.ReturnCode := 1;
		end else if ( AS_GB <> Nil ) and ( AS_GB^.Scene <> Nil ) and ( AS_GB^.Scene^.G = GG_MetaScene ) then begin
			ReturnToScene( NAttValue( AS_GB^.Scene^.NA , NAG_Narrative , NAS_EntranceScene ) );

		end else if ( AS_GB <> Nil ) and ( AS_GB^.Scene <> Nil ) and IsInvCom( AS_GB^.Scene ) then begin
			if NAttValue( AS_GB^.Scene^.NA  , NAG_Narrative , NAS_EntranceScene ) <> 0 then begin
				AS_SetExit( AS_GB , NAttValue( AS_GB^.Scene^.NA  , NAG_Narrative , NAS_EntranceScene ) );
				SetNAtt( AS_GB^.Scene^.NA  , NAG_Narrative , NAS_EntranceScene , 0 );
			end;
		end else if ( AS_GB <> Nil ) and ( AS_GB^.Scene <> Nil ) and ( AS_GB^.Scene^.Parent <> Nil ) and ( AS_GB^.Scene^.Parent^.G = GG_Scene ) then begin
			ReturnToScene( NAttValue( AS_GB^.Scene^.Parent^.NA , NAG_Narrative , NAS_NID ) );
		end else begin
			ReturnToScene( 0 );
		end;
		Lua_Return := 0;
	end;

	Function Lua_Exit( MyLua: PLua_State ): LongInt; cdecl;
		{ An exit command has been received. }
		{ One parameter should have been passed- the NID of the destination. }
	var
		MyGear: GearPtr;
		SID: LongInt;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );
		if MyGear <> Nil then begin
			SID := NAttValue( MyGear^.NA , NAG_Narrative , NAS_NID );
			if ( AS_GB = Nil ) or ( ( SID < 0 ) and ( FindActualScene( AS_GB , SID ) = Nil ) ) then begin
				DialogMsg( MsgString( 'AS_EXIT_NOMETASCENE' ) );
			end else begin
				AS_SetExit( AS_GB , SID );
			end;
		end;
		Lua_Exit := 0;
	end;

	Function Lua_InitChatMenu( MyLua: PLua_State ): LongInt; cdecl;
		{ Clear the chat menu, maybe add some standard options. }
		{ Param1: Add Standard Options (Boolean) }
	var
		AddStdOps: Boolean;
	begin
		{ Error check - make sure the interaction menu is active. }
		if IntMenu = Nil then begin
			Exit;

		{ If there are any menu items currently in the list, get rid }
		{ of them. }
		end else if IntMenu^.FirstItem <> Nil then begin
			ClearMenu( IntMenu );
		end;

		AddStdOps := lua_toboolean( MyLua , 1 );
		if AddStdOps then begin
			AddRPGMenuItem( IntMenu , MsgString( 'NEWCHAT_Goodbye' ) , -1 );
			if ( AS_GB <> Nil ) and OnTheMap( AS_GB , FindRoot( I_NPC ) ) and IsFoundAlongTrack( AS_GB^.Meks , FindRoot( I_NPC ) ) then begin
				{ Only add the JOIN command if this NPC is in the same scene as the PC. }
				if ( I_PC <> Nil ) and HasTalent( I_PC , NAS_Camaraderie ) then begin
					if ( I_NPC <> Nil ) and ( NAttValue( I_NPC^.NA , NAG_Relationship , 0 ) >= NAV_Friend ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then AddRPGMenuItem( IntMenu , MsgString( 'NEWCHAT_Join' ) , CMD_Join );
				end else begin
					if ( I_NPC <> Nil ) and ( NAttValue( I_NPC^.NA , NAG_Relationship , 0 ) >= NAV_ArchAlly ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then AddRPGMenuItem( IntMenu , MsgString( 'NEWCHAT_Join' ) , CMD_Join );
				end;
			end;
			if ( I_NPC <> Nil ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ( NAttValue( I_NPC^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_TempLancemate ) and IsSafeArea( AS_GB ) and IsSubCom( AS_GB^.Scene ) then AddRPGMenuItem( IntMenu , MsgSTring( 'NEWCHAT_QuitLance' ) , CMD_Quit );
			if not ( OnTheMap( AS_GB , FindRoot( I_NPC ) ) and IsFoundAlongTrack( AS_GB^.Meks , FindRoot( I_NPC ) ) ) then AddRPGMenuItem( IntMenu , MsgString( 'NewChat_WhereAreYou' ) , CMD_WhereAreYou );
			if ( NAttValue( I_NPC^.NA , NAG_Personal , NAS_RumorRecharge ) < AS_GB^.ComTime ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then AddRPGMenuItem( IntMenu , MsgString( 'NEWCHAT_AskAboutRumors' ) , CMD_AskAboutRumors );
			RPMSortAlpha( IntMenu );
		end;

		Lua_InitChatMenu := 0;
	end;

	Function Lua_AddChatMenuItem( MyLua: PLua_State ): LongInt; cdecl;
		{ Add a new item to the IntMenu. }
		{ P1 = The menu item value }
		{ P2 = The menu item text }
	var
		N: Integer;
		Msg: String;
	begin
		{ Error check - this command can only work if the IntMenu is }
		{ already allocated. }
		if ( IntMenu <> Nil ) then begin
			{ First, determine the prompt number. }
			N := luaL_checkint( MyLua , 1 );
			msg := luaL_checkstring( MyLua , 2 );

			if Msg <> '' then begin
				AddRPGMenuItem( IntMenu , Msg , N );
				RPMSortAlpha( IntMenu );
			end;
		end;

		Lua_AddChatMenuItem := 0;
	end;

	Function Lua_SetChatMsg( MyLua: PLua_State ): LongInt; cdecl;
		{ Something is being said. The param is the message. }
	var
		msg: String;
	begin
		msg := luaL_checkstring( MyLua , 1 );

		if msg <> '' then begin
			{ Error check- if not in a conversation, call the PRINT }
			{ routine instead. }
			if IntMenu = Nil then begin
				DialogMsg( msg );
			end else begin
				CHAT_Message := msg;
			end;
		end;
		Lua_SetChatMsg := 0;
	end;

	Function Lua_GetContext( MyLua: PLua_State ): LongInt; cdecl;
		{ There's a gear that we want to know the context of. }
		{ First argument is the gear, second argument is the label to apply. }
	var
		MyGear: GearPtr;
		c_label,context: String;
	begin
		MyGear := GetLuaGear( AS_GB ,MyLua , 1 );
		c_label := luaL_checkstring( MyLua , 2 );
		if c_label = '' then c_label := '@';

		context := '';
		if ( MyGear <> nil ) then begin
			AddGearXRContext( AS_GB , FindRoot( AS_GB^.Scene ) , MyGear , context , c_label[1] );
		end;
		Lua_PushString( MyLua , context );
		Lua_GetContext := 1;
	end;

	Function Lua_GetReaction( MyLua: PLua_State ): LongInt; cdecl;
		{ There's a gear that we want to know the context of. }
		{ First argument is the gear, second argument is the label to apply. }
	var
		MyNPC: GearPtr;
	begin
		MyNPC := GetLuaGear( AS_GB ,MyLua , 1 );

		if ( MyNPC <> nil ) then begin
			lua_pushinteger( MyLua , ReactionScore( AS_GB^.Scene , LocatePC( AS_GB ) , MyNPC ) );
		end else begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: GetReaction passed nonexistant gear!' );
		end;
		Lua_GetReaction := 1;
	end;

	Function Lua_GetTime( MyLua: PLua_State ): LongInt; cdecl;
		{ Return the current ComTime. }
	begin
		if ( AS_GB <> nil ) then begin
			lua_pushinteger( MyLua , AS_GB^.ComTime );
		end else begin
			lua_pushnil( MyLua );
			RecordError( 'ERROR: GetTime called with nonexistant gameboard!' );
		end;
		Lua_GetTime := 1;
	end;

	Function Lua_ForceChat( MyLua: PLua_State ): LongInt; cdecl;
		{ Force the player to talk with the specified NPC. }
	var
		NPC: GearPtr;
	begin
		if AS_GB <> Nil then begin
			{ Find out which NPC to speak with. }
			NPC := GetLuaGear( AS_GB , MyLua , 1 );

			if NPC <> Nil then begin
				StoreSAtt( AS_GB^.Trig , '!TALK ' + BStr( NAttValue( NPC^.NA , NAG_Narrative , NAS_NID ) ) );
			end;
		end;

		Lua_ForceChat := 0;
	end;

	Function Lua_MoveAndPacify( MyLua: PLua_State ): LongInt; cdecl;
		{ Move the specified gear to the specified scene, }
		{ setting its team to a nonagressive one. }
		{ Only physical gears can be moved in this way. }
		{ If the specified scene is 0, the gear will be "frozen" isntead. }
	var
		GearToMove,Scene: GearPtr;
	begin
		GearToMove := GetLuaGear( AS_GB , MyLua , 1 );
		Scene := GetLuaGear( AS_GB , MyLua , 1 );

		{ Check to make sure we have a valid gear to move. }
		if ( GearToMove <> Nil ) and ( GearToMove^.G >= 0 ) and ( Scene <> Nil ) then begin
			DelinkGearForMovement( AS_GB , GearToMove );
			InsertInvCom( Scene , GearToMove );

			{ Set the TEAMDATA here. }
			if IsACombatant( GearToMove ) then begin
				SetSAtt( GearToMove^.SA , 'TEAMDATA <SD ALLY>' );
			end else begin
				SetSAtt( GearToMove^.SA , 'TEAMDATA <PASS ALLY>' );
			end;

			{ If inserting a character, better choose a team. }
			if IsAScene( Scene ) and IsMasterGear( GearToMove ) then begin
				ChooseTeam( GearToMove , Scene );
			end;
		end;
		Lua_MoveAndPacify := 0;
	end;

	Function Lua_GetPC( MyLua: PLua_State ): LongInt; cdecl;
		{ Find the PC. Return it to Lua. }
	var
		PC: GearPtr;
		Renown: Integer;
	begin
		PC := LocatePilot( LocatePC( AS_GB ) );
		if PC <> Nil then begin
			lua_pushlightuserdata( MyLua , Pointer( PC ) );
		end else begin
			lua_pushnil( MyLua );
		end;


		Lua_GetPC := 1;
	end;

	Function Lua_GiveXP( MyLua: PLua_State ): LongInt; cdecl;
		{ Give some experience points to all PCs and lancemates. }
	const
		LM_Renown_Lag = 20;	{ Lancemates will lag one renown band behind PC. }
		Procedure DoRapidLeveling( NPC,PC: GearPtr; Renown: Integer );
			{ Search through this NPC's skills. If you find one that is lower }
			{ than acceptable for the provided Renown, increase it. }
		var
			OptRank,SpecSkill,Skill,N,SkRank: Integer;
			CanGetBonus: Array [1..NumSkill] of Boolean;
		begin
			if NPC = Nil then Exit;

			{ Clamp the renown score. }
			if Renown < 1 then Renown := 1;


			{ Advance the NPC's renown. }
			if NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) < Renown then AddNAtt( NPC^.NA , NAG_CharDescription , NAS_Renowned , 1 );

			{ Maybe advance the NPC's reaction score. }
			{ This will depend on the current score bonus and the renown level. }
			N := Random( Renown + 5 ) div 2;
			if N > NAttValue( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_Narrative , NAS_NID ) ) then AddReact( AS_GB , PC , NPC , 1 );

			{ Determine the skill level to use. }
			OptRank := SkillRankForRenown( Renown );

			{ Determine the specialist skill of this model. }
			SpecSkill := NAttValue( NPC^.NA , NAG_Personal , NAS_SpecialistSkill );

			{ Count how many skills could use a level-up. }
			N := 0;
			for Skill := 1 to NumSkill do begin
				{ If this is the specialist skill, it can go one higher. }
				SkRank := SkillRank( NPC , Skill );
				if ( Skill = SpecSkill ) and ( SkRank > 1 ) then Dec( SkRank );
				if ( SkRank > 0 ) and ( SkRank < OptRank ) then begin
					Inc( N );
					CanGetBonus[ Skill ] := True;
				end else CanGetBonus[ Skill ] := False;
			end;

			{ If any skills need boosting, select one at random and do that now. }
			if N > 0 then begin
				{ Select one skill at random }
				N := Random( N );

				{ Find it, and give a +1 bonus. }
				for Skill := 1 to NumSkill do begin
					if CanGetBonus[ Skill ] then begin
						Dec( N );
						if N = -1 then begin
							AddNAtt( NPC^.NA , NAG_Skill , Skill , 1 );
							Break;
						end;
					end;
				end;
			end;
		end;
	var
		XP,T,Renown,LMs: LongInt;
		M,PC,NPC: GearPtr;
	begin
		{ Find out how much to give. }
		XP := luaL_checkint( MyLua , 1 );

		{ Count the lancemates, reduce XP if too many. }
		LMs := LancematesPresent( AS_GB );
		if LMs > 4 then LMs := 4;
		if LMs > 1 then XP := ( XP * ( 6 - LMs ) ) div 5;

		{ Locate the PC, and find its Renown score. }
		PC := LocatePilot( LocatePC( AS_GB ) );
		if PC <> Nil then begin
			Renown := NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned );
		end else begin
			Renown := 1;
		end;

		{ We'll rapidly level one of the lancemates at random. }
		{ Select a model. }
		LMs := Random( LancematesPresent( AS_GB ) ) + 1;

		{ Search for models to give XP to. }
		if AS_GB <> Nil then begin
			M := AS_GB^.Meks;
			while M <> Nil do begin
				T := NAttValue( M^.NA , NAG_Location , NAS_Team );
				if ( T = NAV_DefPlayerTeam ) then begin
					DoleExperience( M , XP );
				end else if ( T = NAV_LancemateTeam ) and OnTheMap( AS_GB , M ) then begin
					DoleExperience( M , XP );

					{ Locate the pilot. }
					NPC := LocatePilot( M );
					{ Only regular lancemates get rapid leveling- Pets and temps don't. }
					if IsRegularLancemate( M ) then begin
						Dec( LMs );
						if ( LMs = 0 ) and ( NPC <> Nil ) then DoRapidLeveling( NPC , PC , Renown - LM_Renown_Lag );

						{ Lancemates are also eligible for training events. }
						if NAttValue( NPC^.NA , NAG_Narrative , NAS_LancemateTraining_Total ) < Renown then begin
							AddNAtt( NPC^.NA , NAG_Narrative , NAS_LancemateTraining_Total , 1 );
						end;
					end;
				end;
				M := M^.Next;
			end;
		end;

		DialogMsg( ReplaceHash( MSgString( 'AS_XPV' ) , Bstr( XP ) ) );

		Lua_GiveXP := 0;
	end;

	Function Lua_GetCurrentScene( MyLua: PLua_State ): LongInt; cdecl;
		{ Find the current scene. Return it to Lua. }
	begin
		if ( AS_GB <> Nil ) and ( AS_GB^.Scene <> Nil ) then begin
			lua_pushlightuserdata( MyLua , Pointer( AS_GB^.Scene ) );
		end else begin
			lua_pushnil( MyLua );
		end;
		Lua_GetCurrentScene := 1;
	end;

	Function Lua_DeployRandomMecha( MyLua: PLua_State ): LongInt; cdecl;
		{ Fill current scene with enemies. }
	var
		TID,Renown,Strength,LMs: LongInt;
	begin
		{ Find out the team, and how many enemies to add. }
		TID := luaL_checkint( MyLua , 1 );
	 	Renown := luaL_checkint( MyLua , 2 );
		Strength := luaL_checkint( MyLua , 3 );

		{ If this team is an enemy of the player team, add extra STRENGTH based on the number of }
		{ lancemates. This extra STRENGTH will not entirely cancel out the usefulness of lancemates, }
		{ but will reduce it slightly, thereby allowing solo PCs to exist. }
		if AreEnemies( AS_GB , TID , NAV_DefPlayerTeam ) then begin
			LMs := LancematesPresent( AS_GB );
			if LMs > 0 then Strength := Strength + ( 25 * LMs );
		end;

		AddTeamForces( AS_GB , TID , Renown , Strength );

		Lua_DeployRandomMecha := 0;
	end; { ProcessWMecha }

	Procedure CantOpenBusiness( GB: GameBoardPtr );
		{ The business can't be opened. Print an error message. }
	var
		Scene: Integer;
		msg: String;
	begin
		Scene := FindSceneID( I_NPC , GB );
		if Scene <> 0 then begin
			msg := ReplaceHash( msgString( 'CantOpenShop_WithScene' ) , SceneName( GB , Scene , True ) );
		end else begin
			msg := msgString( 'CantOpenShop' );
		end;
		CHAT_Message := msg;
	end;

	Function Lua_OpenShop( MyLua: PLua_State ): LongInt; cdecl;
		{ Retrieve the WARES line, then pass it all on to the OpenShop }
		{ procedure. }
	var
		Wares: String;
	begin
		{ Retrieve the WARES string. }
		Wares := luaL_checkstring( MyLua , 1 );

		{ Only open the shop if the NPC is on the current map. }
		if IsFoundAlongTrack( AS_GB^.Meks , FindRoot( I_NPC ) ) then begin
			{ Pass all info on to the OPENSHOP procedure. }
			OpenShop( AS_GB , I_PC , I_NPC , Wares );
			I_HaveNotShopped := false;
		end else begin
			{ Call the error handler. }
			CantOpenBusiness( AS_GB );
		end;

		Lua_OpenShop := 0;
	end;

	Function Lua_IsInPlay( MyLua: PLua_State ): LongInt; cdecl;
		{ Return TRUE if the provided gear is in play, or FALSE otherwise. }
	var
		GearToCheck: GearPtr;
	begin
		GearToCheck := GetLuaGear( AS_GB , MyLua , 1 );
		lua_pushboolean( MyLua , ( GearToCheck <> nil ) and IsFoundAlongTrack( AS_GB^.Meks , FindRoot( GearToCheck ) ) );
		Lua_IsInPlay := 1;
	end;

	Function Lua_SpendTime( MyLua: PLua_State ): LongInt; cdecl;
		{ Advance the game clock by a specified amount. }
		{ FOr long periods of time, we don't want the PC to get hungry, as this will }
		{ result in an obscene number of "You are hungry" messages. So, break the time }
		{ into hour periods and give the PC some food between each. }
	var
		N,OriginalHunger: LongInt;
		PC: GearPtr;
	begin
		{ Find out how much to adjust the value by. }
		N := luaL_checkint( MyLua , 1 );

		PC := LocatePilot( LocatePC( AS_GB ) );
		if PC <> Nil then begin
			OriginalHunger := NAttValue( PC^.NA , NAG_Condition , NAS_Hunger );
			if OriginalHunger > ( Hunger_Penalty_Starts - 15 ) then OriginalHunger := Hunger_Penalty_Starts - 16;
		end;

		while N > 0 do begin
			if N > 3600 then begin
				if PC <> Nil then SetNAtt( PC^.NA , NAG_Condition , NAS_Hunger , OriginalHunger );
				QuickTime( AS_GB , 3600 );
				N := N - 3600;
			end else begin
				QuickTime( AS_GB , N );
				N := 0;
			end;
		end;

		Lua_SpendTime := 0;
	end;

	Function Lua_BrowseMessages( MyLua: PLua_State ): LongInt; cdecl;
		{ Browse messages of a given type. }
	var
		memo_tag: String;
	begin
		memo_tag := luaL_checkstring( MyLua , 1 );
		if memo_tag = '' then memo_tag := 'MEMO';
		BrowseMemoType( AS_GB , memo_tag );
		Lua_BrowseMessages := 0;
	end;

	Function Lua_InitMenu( MyLua: PLua_State ): LongInt; cdecl;
		{ Clear the script menu. }
	begin
		{ If there are any menu items currently in the list, get rid }
		{ of them. }
		if AS_Menu^.FirstItem <> Nil then begin
			ClearMenu( AS_Menu );
		end;
		Lua_InitMenu := 0;
	end;

	Function Lua_AddMenuItem( MyLua: PLua_State ): LongInt; cdecl;
		{ Add a new item to the AS_Menu. }
		{ P1 = The menu item text }
		{ P2 = The menu item value }
	var
		N: Integer;
		Msg: String;
	begin
		msg := luaL_checkstring( MyLua , 1 );
		N := luaL_checkint( MyLua , 2 );

		if Msg <> '' then begin
			AddRPGMenuItem( AS_Menu , Msg , N );
		end;

		Lua_AddMenuItem := 0;
	end;

	Function Lua_QueryMenu( MyLua: PLua_State ): LongInt; cdecl;
		{ Query the menu, return the result. }
		{ Param1: The text to display above the menu. }
	var
		msg: String;
		N: LongInt;
	begin
		msg := luaL_checkstring( MyLua , 1 );

		if AS_Menu^.FirstItem <> Nil then begin
			ASRD_MemoMessage := msg;
			AlphaKeyMenu( AS_Menu );
			N := SelectMenu( AS_Menu , @MemoPageRedraw );

			{ Do cleanup before branching. }
			CombatDisplay( AS_GB );

			lua_pushinteger( MyLua , n );

		end else begin
			{ Empty menu - return 0. }
			lua_pushinteger( MyLua , 0 );
		end;
		Lua_QueryMenu := 1;
	end;

	Function Lua_CreatePart( MyLua: PLua_State ): LongInt; cdecl;
		{ Stick an item from the standard items list on the gameboard. }
		{ This function will return a pointer to the new gear. }
	var
		IName: String;
		NewPart: GearPtr;
	begin
		IName := luaL_checkstring( MyLua , 1 );
		NewPart := Nil;

		{ As long as we have a GB, try to stick the item there. }
		if AS_GB <> Nil then begin
			NewPart := LoadNewSTC( IName );
			if NewPart = Nil then NewPart := LoadNewItem( IName );
			if NewPart = Nil then NewPart := LoadNewMonster( IName );
{			if NewPart = Nil then NewPart := LoadNewNPC( IName , True );}

			{ If we found something, stick it on the map. }
			if NewPart <> Nil then begin
				{ Register it with Lua. }
				ActivateGearTree( NewPart );

				{ Deploy the item. }
				EquipThenDeploy( AS_GB , NewPart , False );
			end;

			{ Any further processing must be done by other commands. }
		end;

		if NewPart <> Nil then begin
			lua_pushlightuserdata( MyLua , Pointer( NewPart ) );
		end else begin
			lua_pushnil( MyLua );
		end;
		Lua_CreatePart := 1;
	end;

	Function Lua_GiveGear( MyLua: PLua_State ): LongInt; cdecl;
		{ Attempt to give the requested gear to the PC. }
		{ Only physical gears can be moved in this way. }
	var
		GearToGive: GearPtr;
		DelinkOK: Boolean;
		PC: GearPtr;
	begin
		GearToGive := GetLuaGear( AS_GB , MyLua , 1 );
		PC := LocatePC( AS_GB );

		if ( GearToGive <> Nil ) and ( GearToGive^.G >= 0 ) and (( PC = Nil ) or ( FindGearIndex( GearToGive , PC ) < 0 )) then begin

			{ Delink the gear, if it can be found. }
			if IsSubCom( GearToGive ) then begin
				DelinkGear( GearToGive^.Parent^.SubCom , GearToGive );
				DelinkOK := True;
			end else if IsInvCom( GearToGive ) then begin
				DelinkGear( GearToGive^.Parent^.InvCom , GearToGive );
				DelinkOK := True;
			end else if ( AS_GB <> Nil ) and IsFoundAlongTrack( AS_GB^.Meks , GearToGive ) then begin
				DelinkGear( AS_GB^.Meks , GearToGive );
				DelinkOK := True;
			end else begin
				DelinkOK := False;
			end;

			if DelinkOK then begin
				GivePartToPC( AS_GB , GearToGive , PC );
				if ( PC <> nil ) and ( GearToGive^.G = GG_Mecha ) then begin
					if FindPilotsMecha( AS_GB^.Meks , PC ) = Nil then AssociatePilotMek( AS_GB^.Meks , PC , GearToGive );
				end;
			end;
		end;

		Lua_GiveGear := 0;
	end;

	Function Lua_SeekGate( MyLua: PLua_State ): LongInt; cdecl;
		{ We're going somewhere, but not through the regular door. }
		{ P1 = Scene entrance to emerge from. }
	var
		SceneToSeek: GearPtr;
	begin
		SceneToSeek := GetLuaGear( AS_GB , MyLua , 1 );
		if SceneToSeek <> Nil then begin
			SCRIPT_Gate_To_Seek := NAttValue( SceneToSeek^.NA , NAG_Narrative , NAS_NID );
		end;
		Lua_SeekGate := 0;
	end;

	Function Lua_PCMekCanEnterScene( MyLua: PLua_State ): LongInt; cdecl;
		{ Return TRUE if the PC makes the requested skill roll, or FALSE otherwise. }
		{ Param 1 = Skill, Param 2 = Stat }
		{ Param 3 = Target to beat }
	var
		Scene,PC,Mek: GearPtr;

	begin
		{ Find the scene we're referring to. }
		Scene := GetLuaGear( AS_GB , MyLua , 1 );

		{ Locate the PC, the PC's mecha, and the target scene. }
		PC := FindRoot( LocatePC( AS_GB ) );
		if ( PC <> Nil ) then begin
			if PC^.G = GG_Mecha then Mek := PC
			else Mek := FindPilotsMecha( AS_GB^.Meks , PC );
		end;

		if ( PC <> Nil ) and ( Mek <> Nil ) and ( Scene <> Nil ) and NotDestroyed( Mek ) and MekCanEnterScene( Mek , Scene ) then begin
			lua_pushboolean( MyLua , True );
		end else begin
			lua_pushboolean( MyLua , False );
		end;

		Lua_PCMekCanEnterScene := 1;
	end;

	Function Lua_CalculateReward( MyLua: PLua_State ): LongInt; cdecl;
		{ Calculate a reward value, based on a renown value + percent. }
	var
		Renown,Percent: LongInt;
	begin
		{ Find out the team, and how many enemies to add. }
		Renown := luaL_checkint( MyLua , 1 );
	 	Percent := luaL_checkint( MyLua , 2 );

		lua_pushinteger( MyLua , Calculate_Reward_Value( AS_GB, Renown, Percent ) );

		Lua_CalculateReward := 1;
	end;





initialization
	lua_register( MyLua , 'gh_GetGearG' , @Lua_GetGearG );
	lua_register( MyLua , 'gh_GetGearS' , @Lua_GetGearS );
	lua_register( MyLua , 'gh_GetGearV' , @Lua_GetGearV );
	lua_register( MyLua , 'gh_RawFollowLink' , @Lua_RawFollowLink );
	lua_register( MyLua , 'gh_GetStat' , @Lua_GetGearStat );
	lua_register( MyLua , 'gh_SetStat' , @Lua_SetGearStat );
	lua_register( MyLua , 'gh_GetNAtt' , @Lua_GetNAtt );
	lua_register( MyLua , 'gh_SetNAtt' , @Lua_SetNAtt );
	lua_register( MyLua , 'gh_AddNAtt' , @Lua_AddNAtt );
	lua_register( MyLua , 'gh_RawPrint' , @Lua_GHPrint );
	lua_register( MyLua , 'gh_RawAlert' , @Lua_GHAlert );
	lua_register( MyLua , 'gh_TrySkillTest' , @Lua_USkillTest );
	lua_register( MyLua , 'gh_DrawTerrain' , @Lua_DrawTerr );
	lua_register( MyLua , 'gh_CountActiveModels' , @Lua_NumUnits );
	lua_register( MyLua , 'gh_Return' , @Lua_Return );
	lua_register( MyLua , 'gh_GotoScene' , @Lua_Exit );
	lua_register( MyLua , 'gh_InitChatMenu' , @Lua_InitChatMenu );
	lua_register( MyLua , 'gh_AddChatMenuItem' , @Lua_AddChatMenuItem );
	lua_register( MyLua , 'gh_SetChatMessage' , @Lua_SetChatMsg );
	lua_register( MyLua , 'gh_GetContext' , @Lua_GetContext );
	lua_register( MyLua , 'gh_GetReaction' , @Lua_GetContext );
	lua_register( MyLua , 'gh_GetTime' , @Lua_GetTime );
	lua_register( MyLua , 'gh_StartChat' , @Lua_ForceChat );
	lua_register( MyLua , 'gh_MoveAndPacify' , @Lua_MoveAndPacify );
	lua_register( MyLua , 'gh_GetPCPtr' , @Lua_GetPC );
	lua_register( MyLua , 'gh_GiveXP' , @Lua_GiveXP );
	lua_register( MyLua , 'gh_GetCurrentScenePtr' , @Lua_GetCurrentScene );
	lua_register( MyLua , 'gh_DeployRandomMecha' , @Lua_DeployRandomMecha );
	lua_register( MyLua , 'gh_OpenShop' , @Lua_OpenShop );
	lua_register( MyLua , 'gh_IsInPlay' , @Lua_IsInPlay );
	lua_register( MyLua , 'gh_SpendTime' , @Lua_SpendTime );
	lua_register( MyLua , 'gh_BrowseMessages' , @Lua_BrowseMessages );
	lua_register( MyLua , 'gh_InitMenu' , @Lua_InitMenu );
	lua_register( MyLua , 'gh_AddMenuItem' , @Lua_AddMenuItem );
	lua_register( MyLua , 'gh_QueryMenu' , @Lua_QueryMenu );
	lua_register( MyLua , 'gh_RawCreatePart' , @Lua_CreatePart );
	lua_register( MyLua , 'gh_GiveGear' , @Lua_GiveGear );
	lua_register( MyLua , 'gh_SeekGate' , @Lua_SeekGate );
	lua_register( MyLua , 'gh_PCMekCanEnterScene' , @Lua_PCMekCanEnterScene );
	lua_register( MyLua , 'gh_CalculateReward' , @Lua_CalculateReward );
	
	if lua_dofile( MyLua , 'gamedata/gh_messagemutator.lua' ) <> 0 then RecordError( 'GH_MESSAGEMUTATOR ERROR: ' + lua_tostring( MyLua , -1 ) );
	if lua_dofile( MyLua , 'gamedata/gh_functions.lua' ) <> 0 then RecordError( 'GH_FUNCTIONS ERROR: ' + lua_tostring( MyLua , -1 ) );
	if lua_dofile( MyLua , 'gamedata/gh_init.lua' ) <> 0 then RecordError( 'GH_INIT ERROR: ' + lua_tostring( MyLua , -1 ) )
	else Lua_Is_Go := True;

	SCRIPT_DynamicEncounter := Nil;

	lancemate_tactics_persona := LoadFile( 'lmtactics.txt' , Data_Directory );
	rumor_leads := LoadFile( 'rumor_leads.txt' , Data_Directory );

	I_NPC := Nil;
	IntMenu := Nil;

	AS_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );
	AS_Menu^.Mode := RPMNoCancel;

	AS_GB := Nil;

finalization
	if SCRIPT_DynamicEncounter <> Nil then begin
		DisposeGear( SCRIPT_DynamicEncounter );
	end;

	DisposeGear( lancemate_tactics_persona );
	DisposeGear( rumor_leads );
	DisposeRPGMenu( AS_Menu );
end.
