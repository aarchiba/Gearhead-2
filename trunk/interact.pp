unit interact;
	{ This unit contains the rules for using interaction skills, }
	{ such as Conversation, et cetera. }
	{ It also, by reason of necessity, contains some procedures }
	{ related to random plots. The main unit for plots is }
	{ playwright.pp; see that unit for more details. }
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
	{ *** PERSONA GEAR *** }
	{ G = GG_Persona                              }
	{ S = Character ID or Plot Element Number     }
	{ V = na                                      }

	{ *** FACTION GEAR *** }
	{ G = GG_Faction                              }
	{ S = Faction ID                              }
	{ V = Undefined                               }


	{ This attribute records how well two characters like each other or }
	{ hate each other. The "S" identifier is the CID of the character }
	{ to which this reaction score applies. }
	NAG_ReactionScore = 6;

	{ This attribute records the relationship between two factions. }
	NAG_FactionScore = 8;

	{ This attribute records the relationship this NPC has with }
	{ another NPC in the game. }
	NAG_Relationship = 10;
	{ S descriptor is the CID of the other NPC. }
	{ ... or 0 for the PC. }
	NAV_ArchEnemy = -1;
	NAV_Friend = 1;
	NAV_ArchAlly = 2;	{ Is there such a thing as an arch-ally? }
				{ Who really knows. }
		{ If the relationship type is greater than or equal to NAV_ArchAlly, }
		{ the NPC can join the lance. }
	NAV_Family = 3;
	NAV_Lover = 4;

	ArchEnemyReactionPenalty = 25;

	Same_Faction_Bonus = 10;
	MaxFactionScore = 25;
	MinFactionScore = -50;



Function PersonalityCompatability( PC, NPC: GearPtr ): Integer;
Function ReactionScore( Scene, PC, NPC: GearPtr ): Integer;

Function CreateRumorList( GB: gameBoardPtr; PC,NPC: GearPtr ): SAttPtr;
Function IdleChatter: String;
Function IsSexy( PC, NPC: GearPtr ): Boolean;
function DoChatting( GB: GameBoardPtr; var Rumors: SAttPtr; PC,NPC: GearPtr; Var Endurance,FreeRumors: Integer ): String;

Function IsArchEnemy( Adv,NPC: GearPtr ): Boolean;
Function IsArchAlly( Adv,NPC: GearPtr ): Boolean;
Function XNPCDesc( Adv,NPC: GearPtr ): String;

Function GenerateEnemyHook( Scene,PC,NPC: GearPtr; Desc: String ): GearPtr;
Function GenerateAllyHook( Scene,PC,NPC: GearPtr ): GearPtr;

Function LancematesPresent( GB: GameBoardPtr ): Integer;

Function FindLocalNPCByKeyWord( GB: GameBoardPtr; KW: String ): GearPtr;


implementation

uses narration,texutil,rpgdice,ghchars,gearutil,ability,ui4gh,ghprop,action;

const
	Num_Openings = 7;	{ Number of TraitChatter opening phrases. }

	Chat_MOS_Measure = 5;


var
	{ Strings for the random conversation generator. }
	Noun_List,Phrase_List,Adjective_List,RLI_List,Chat_Msg_List,Threat_List: SAttPtr;
	Trait_Chatter: Array [1..Num_Personality_Traits,1..2] of SAttPtr;



Function GeneralCompatability( PC1, PC2: GearPtr ): Integer;
	{ This function will determine the general level of }
	{ compatability between two characters. This is the }
	{ modifier which will be applied to most interaction }
	{ rolls. }
	{ It is determined by several things - }
	{  - Similarity of stats and skills }
var
	T,S1,S2: Integer;
	BCS: Integer;	{ Base compatability score }
begin
	{ Error Check - Make sure both PCs are valid gears. }
	if ( PC1 = Nil ) or ( PC2 = Nil ) then begin
		GeneralCompatability := 0;

	{ Error Check - Make sure both PCs are characters. }
	end else if ( PC1^.G <> GG_Character ) or ( PC2^.G <> GG_Character ) then begin
		GeneralCompatability := 0;

	end else begin
		{ Initialize the compatability score to 0. }
		BCS := 0;

		{ Check the stats. Every stat that is wildly different will }
		{ cause a drop in compatability, while every stat which is }
		{ very similar will cause a rise in compatability. }
		for t := 1 to 8 do begin
			if Abs( PC1^.Stat[t] - PC2^.Stat[t] ) > 8 then begin
				Dec( BCS );
			end else if ( PC1^.Stat[t] - PC2^.Stat[t] ) < 3 then begin
				Inc( BCS );
			end;
		end;

		{ Check the skills. Every skill that both PCs have will }
		{ cause a rise in compatability. }
		for t := 1 to NumSkill do begin
			S1 := NAttValue( PC1^.NA , NAG_Skill , T );
			S2 := NAttValue( PC2^.NA , NAG_Skill , T );

			if ( S1 > 10 ) and ( S2 > 10 ) then begin
				BCS := BCS + 3;
			end else if ( S1 > 5 ) and ( S2 > 5 ) then begin
				BCS := BCS + 2;
			end else if ( S1 > 0 ) and ( S2 > 0 ) then begin
				BCS := BCS + 1;
			end;
		end;

		GeneralCompatability := BCS;
	end;
end;

Function PersonalityCompatability( PC, NPC: GearPtr ): Integer;
	{ Calculate the compatability between PC and NPC based on their }
	{ personality traits. }
var
	T,CS: Integer;
	NPC_Score,PC_Score: Integer;
begin
	{ Initialize the Compatability Score to 0. }
	CS := 0;

	{ Loop through all the personality traits. }
	for t := 1 to Num_Personality_Traits do begin
		{ Determine the scores of both PC and NPC with regard to this }
		{ personality trait. }
		PC_Score := NAttValue( PC^.NA , NAG_CharDescription , -T );
		NPC_Score := NAttValue( NPC^.NA , NAG_CharDescription , -T );

		{ If the personality trait being discussed here is Villainousness, }
		{ this always causes a negative reaction. Otherwise, a reaction }
		{ will only happen if both the PC and the NPC have points in }
		{ this trait. }
		if ( T = Abs( NAS_Heroic ) ) and (PC_Score < -10 ) then begin
			CS := CS - Abs( PC_Score ) div 2;

		end else if ( T = Abs( NAS_Renowned ) ) then begin
			{ Being renowned is always good, while being wangtta is }
			{ always bad. }
			if PC_Score > 0 then begin
				CS := CS + ( PC_Score div 10 );
			end else begin
				CS := CS - ( Abs( PC_Score ) div 10 );
			end;

		end else if ( PC_Score <> 0 ) and ( NPC_Score <> 0 ) then begin
			if Sgn( PC_Score ) = Sgn( NPC_Score ) then begin
				{ The traits are in agreement. Increase CS. }
				CS := CS + Abs( PC_Score ) div 10;

			end else if ( Abs( PC_Score ) > 10 ) and ( Abs( NPC_Score ) > 10 ) then begin
				{ The traits are in opposition. Decrease CS. }
				CS := CS - 5;

			end;
		end;
	end;

	PersonalityCompatability := CS;
end;

Function FactionScore( Scene: GearPtr; F0,F1: Integer ): Integer;
	{ Given two factions, return the amount by which they are }
	{ allied to each other or hate each other. }
var
	Fac_0: GearPtr;
	it: Integer;
begin
	if ( F0 = 0 ) or ( F1 = 0 ) then begin
		it := 0;

	end else if F0 = F1 then begin
		it := Same_Faction_Bonus;

	end else begin
		Fac_0 := SeekFaction( Scene , F0 );
		if Fac_0 <> Nil then begin
			it := NAttValue( Fac_0^.NA , NAG_FactionScore , F1 );
		end else begin
			it := 0;
		end;

	end;
	FactionScore := it;
end;

Function FactionCompatability( Scene, PC, NPC: GearPtr ): Integer;
	{ Determine the faction compatability scores between PC and NPC. }
	{ + the PC's reputation with the NPC's faction. }
	{ - if PC is enemy of allied faction. }
	{ - if PC is ally of enemy faction. }
var
	NPC_FID,PC_FID,it: Integer;
begin
	{ Step one - Locate the FACTION information of the NPC, and }
	{ the PC's FACTION ID.. }
	NPC_FID := NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID );
	PC_FID := NAttValue( PC^.NA , NAG_Personal , NAS_FactionID );

	it := FactionScore( Scene , NPC_FID , PC_FID );

	if it > MaxFactionScore then it := MaxFactionScore
	else if it < MinFactionScore then it := MinFactionScore;

	FactionCompatability := it;
end;

Function ReactionScore( Scene, PC, NPC: GearPtr ): Integer;
	{ Return a score in the range of -100..+100 which tells how much }
	{ the NPC likes the PC. }
var
	it,Persona: Integer;
	Charm: Integer;
begin
	{ The basic Reaction Score is equal to GENERAL COMPATABILITY + the }
	{ existing reaction modifier. }
	Persona := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	PC := LocatePilot( PC );
	it := GeneralCompatability( PC , NPC ) + PersonalityCompatability( PC , NPC ) + NAttValue( PC^.NA , NAG_ReactionScore , Persona );

	{ If the scene is defined, add the faction compatability score. }
	if Scene <> Nil then it := it + FactionCompatability( Scene , PC , NPC );

	{ Add a bonus based on the PC's charm. }
	Charm := CStat( PC , STAT_Charm );
	if Charm > 10 then begin
		it := it + Charm * 2 - 25;
	end else begin
		it := it + Charm * 3 - 35;
	end;

	{ A true archenemy will never have a greater reaction score than 0. }
	if NAttValue( NPC^.NA , NAG_Relationship , NAttValue( PC^.NA , NAG_Personal , NAS_CID ) ) = NAV_ArchEnemy then begin
		it := it - ArchEnemyReactionPenalty;
		if it > 0 then it := 0;
	end else if NAttValue( NPC^.NA , NAG_Relationship , NAttValue( PC^.NA , NAG_Personal , NAS_CID ) ) > 0 then begin
		{ An ally/other relationship will be slightly friendlier to the PC. }
		it := it + 5;
	end;

	{ Make sure IT doesn't go out of bounds. }
	if it > 100 then it := 100
	else if it < -100 then it := -100;

	ReactionScore := it;
end;

Function BlowOff: String;
	{ The NPC will just say something mostly useless to the PC. }
begin
	{ At some point in time I will make a lovely procedure that will }
	{ create all sorts of useless chatter. Right now, I'll just return }
	{ the following constant string. }
	BlowOff := 'I really don''t have much time to chat today, I have a lot of things to do.';
end;

function MadLibString( SList: SAttPtr ): String;
	{ Given a list of string attributes, return one of them at random. }
var
	SA: SAttPtr;
begin
	SA := SelectRandomSAtt( SList );
	if SA <> Nil then MadLibString := SA^.Info
	else MadLibString := '***ERROR***';
end;

Function FormatChatString( Msg1: String ): String;
	{ Do formatting on this string, adding nouns, adjectives, }
	{ and threats as needed. }
var
	msg2,w: String;
begin
	msg2 := '';

	while msg1 <> '' do begin
		w := ExtractWord( msg1 );

		if W[1] = '%' then begin
			DeleteFirstChar( W );
			if UpCase( W[1] ) = 'N' then begin
				DeleteFirstChar( W );
				W := MadLibString( Noun_List ) + W;
			end else if UpCase( W[1] ) = 'T' then begin
				DeleteFirstChar( W );
				W := MadLibString( Threat_List ) + W;
			end else begin
				DeleteFirstChar( W );
				W := MadLibString( Adjective_List ) + W;
			end;
		end;

		msg2 := msg2 + ' ' + w;
	end;

	DeleteWhiteSpace( Msg2 );
	FormatChatString := Msg2;
end;

Function IdleChatter: String;
	{ Create a Mad-Libs style line for the NPC to tell the PC. }
	{ Hopefully, these mad-libs will simulate the cheerfully nonsensical }
	{ things that poorly tanslated anime characters often say to }
	{ each other. }
	{ After testing this procedure, the effect is more akin to the }
	{ konglish slogans which adorn stationary & other character goods... }
	{ Close enough! I've got a winner here... }
var
	msg1: String;
begin
	{ Start with a MadLib form in msg1, and nothing in Msg2. }
	{ Transfer the message from M1 to M2 one word at a time, replacing }
	{ nouns and adjectives along the way. }
	msg1 := MadLibString( Phrase_List );
	msg1 := FormatChatString( Msg1 );
	AtoAn( msg1 );

	IdleChatter := msg1;
end;

Function DoTraitChatter( NPC: GearPtr; Trait: Integer ): String;
	{ The NPC needs to say a line which should give some indication }
	{ as to his/her orientation with respect to the listed }
	{ personality trait. }
const
	Num_Phrase_Bases = 3;
var
	Rk,Pro: Integer;
	msg: String;
begin
	{ To start with, find the trait rank. }
	Rk := NAttValue( NPC^.NA , NAG_CharDescription , -Trait );

	{ Insert a basic starting phrase in the message, or perhaps none }
	{ at all... }
	if Random( 10 ) <> 1 then begin
		msg := SAttValue( Chat_Msg_List , 'TRAITCHAT_Lead' + BStr( Random( Num_Openings ) + 1 ) ) + ' ';
	end else begin
		msg := '';
	end;

	if Abs( Rk ) > 10 then begin
		{ Determine which side of the trait the NPC is in favor of. }
		if Rk > 0 then Pro := 1
		else Pro := 2;

		{ The NPC will either say that they like something from their own side, }
		{ or that they dislike something from the other. }
		if Random( 5 ) <> 1 then begin
			{ Like something. }
			msg := msg + SAttValue( Chat_Msg_List , 'TRAITCHAT_Like' + BStr( Random( Num_Phrase_Bases ) + 1 ) ) + ' ' + MadLibString( Trait_Chatter[ Trait , Pro ] ) + '.';

		end else begin
			{ Dislike something. }
			msg := msg + SAttValue( Chat_Msg_List , 'TRAITCHAT_Hate' + BStr( Random( Num_Phrase_Bases ) + 1 ) ) + ' ' + MadLibString( Trait_Chatter[ Trait , 3 - Pro ] ) + '.';

		end;
	end else begin
		Pro := Random( 2 ) + 1;
		msg := msg + SAttValue( Chat_Msg_List , 'TRAITCHAT_Ehhh' + BStr( Random( Num_Phrase_Bases ) + 1 ) ) + ' ' + MadLibString( Trait_Chatter[ Trait , Pro ] ) + '.';

	end;

	DoTraitChatter := Msg;
end;

Function CreateRumorList( GB: gameBoardPtr; PC,NPC: GearPtr ): SAttPtr;
	{ Scour the GB for information which can be passed to the PC. }
var
	InfoList: SAttPtr;

	Procedure GetRumorFromGear( P: GearPtr );
		{ Retrieve the rumor info from this gear, without caring about }
		{ what kind of gear it is. Well, for the most part, anyhow... }
	var
		Rumor: String;
		Level: LongInt;
		Plot: GearPtr;
	begin
		{ First add the basic rumor.  }
		Rumor := SAttValue( P^.SA , 'RUMOR' );
		if Rumor <> '' then StoreSAtt( InfoList , MadLibString( RLI_List ) + ' ' + Rumor );

		{ Next add the quest rumor. }
		Level := NAttValue( P^.NA , NAG_QuestInfo , NAS_QuestID );
		if Level <> 0 then begin
			Rumor := SAttValue( P^.SA , 'RUMOR' + BStr( NAttValue( FindRoot( GB^.Scene )^.NA , NAG_QuestStatus , Level ) ) );
			if Rumor <> '' then StoreSAtt( InfoList , MadLibString( RLI_List ) + ' ' + Rumor );
		end;

		{ Finally add the plot rumor. }
		if ( P^.G = GG_Plot ) or ( ( P^.Parent <> Nil ) and ( P^.Parent^.G = GG_Plot ) ) then begin
			if P^.G = GG_Plot then Plot := P else Plot := P^.Parent;
			Level := NAttValue( Plot^.NA , NAG_Narrative , NAS_PlotState );
			Rumor := SAttValue( P^.SA , 'RUMOR' + BStr( Level ) );
			if Rumor <> '' then StoreSAtt( InfoList , MadLibString( RLI_List ) + ' ' + Rumor );
		end;
	end;

	Procedure RumorWorkup( P: GearPtr ); Forward;
	Procedure ExtractData( P: GearPtr );
		{ Store all relevant info from PART. }
		{ If P is of certain types, we're gonna have to harvest the data from }
		{ its associated bits. Characters also need the data from their Personas, }
		{ gates to metascenes need to check there, and scenes get faction data. }
	var
		Rumor: String;
		Trait,Level: Integer;
		Persona: GearPtr;
	begin
		if ( P <> NPC ) and ( P^.G <> GG_Persona ) then begin
			if P <> GB^.Scene then GetRumorFromGear( P );
			if P^.G = GG_Character then begin
				{ At most one personality trait per NPC will be added }
				{ to the list. This is to keep them from overwhelming the }
				{ rumors from plots & other stuff... }
				{ GH2: Because there are so many NPCs now, only one in three }
				{  viable personality rumors will ever be added. }
				Trait := Random( Num_Personality_Traits ) + 1;
				Level := NAttValue( P^.NA , NAG_CharDescription , -Trait );
				if ( Level <> 0 ) and ( Random( 7 ) = 1 ) then begin
					if P = PC then begin
						StoreSAtt( InfoList , MadLibString( RLI_List ) + ' ' + ReplaceHash( MsgString( 'RUMOR_PCTRAIT' ) , LowerCase( PersonalityTraitDesc( Trait,Level ) ) ) );
					end else begin
						rumor := MadLibString( RLI_List ) + ' ' + ReplaceHash( MsgString( 'RUMOR_NPCTRAIT' ) , GearName( P ) );
						StoreSAtt( InfoList , ReplaceHash( rumor , LowerCase( PersonalityTraitDesc( Trait,Level ) ) ) );
					end;
				end;

				Persona := SeekPersona( GB , NAttValue( P^.NA , NAG_Personal , NAS_CID ) );
				if Persona <> Nil then begin
					{ Previously we'd just collect the rumor from the persona }
					{ and be done with it, but since Quests have been introduced }
					{ the rumor associated with a given NPC can change depending }
					{ on quest state. }
					GetRumorFromGear( Persona );
				end;

			end else if ( P^.G = GG_Scene ) then begin
				{ Include a rumor based on what faction controls this scene. }
				Persona := SeekFaction( GB^.Scene , NAttValue( P^.NA , NAG_Personal , NAS_FactionID ) );
				if ( Persona <> Nil ) and ( Random( 5 ) = 1 ) then begin
					Rumor := MadLibString( RLI_List ) + ' ' + ReplaceHash( MsgString( 'RUMOR_SCENEFAC' ) , GearName( P ) );
					Rumor := ReplaceHash( Rumor , GearName( Persona ) );
					StoreSAtt( InfoList , Rumor );
				end;

			end else if ( P^.G = GG_MetaTerrain ) and ( P^.Stat[ STAT_Destination ] < 0 ) then begin
				{ Find the metascene, and do a complete rumor work-up of it. }
				Persona := FindActualScene( GB , P^.Stat[ STAT_Destination ] );
				if Persona <> Nil then begin
					RumorWorkup( Persona );
				end;
			end;
		
		end else if P = NPC then begin
			{ Include information about the NPC's faction, }
			{ if appropriate. }
			Persona := SeekFaction( GB^.Scene , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
			if Persona <> Nil then begin
				Rumor := SAttValue( Chat_Msg_List , 'TRAITCHAT_Lead' + BStr( Random( Num_Openings ) + 1 ) ) + ' ';
				Rumor := Rumor + ReplaceHash( MsgString( 'RUMOR_IAmMember' ) , GearName( Persona ) );
				StoreSAtt( InfoList , Rumor );
			end;
		end;
	end;
	Procedure RumorWorkup( P: GearPtr );
		{ Do a complete rumor workup on P, gathering info from it }
		{ and all its child gears. }
	var
		P2: GearPtr;
	begin
		if P = Nil then Exit;
		ExtractData( P );
		P2 := P^.SubCom;
		while P2 <> Nil do begin
			RumorWorkup( P2 );
			P2 := P2^.Next;
		end;
		P2 := P^.InvCom;
		while P2 <> Nil do begin
			RumorWorkup( P2 );
			P2 := P2^.Next;
		end;
	end;
var
	Part: GearPtr;

begin
	InfoList := Nil;

	Part := FindRootScene( GB , GB^.Scene );
	RumorWorkup( Part );

	Part := GB^.Meks;
	while Part <> Nil do begin
		ExtractData( Part );
		Part := Part^.Next;
	end;

	CreateRumorList := InfoList;
end;

function InOpposition( PC , NPC: GearPtr; Trait: Integer ): Boolean;
	{ If the PC and the NPC disagree on this personality TRAIT, }
	{ return TRUE. Otherwise return FALSE. }
var
	T1,T2: Integer;
begin
	T1 := NAttValue( PC^.NA , NAG_CharDescription , -Trait );
	T2 := NAttValue( NPC^.NA , NAG_CharDescription , -Trait );

	if ( Abs( T1 ) > 10 ) and ( Abs( T2 ) > 10 ) then begin
		{ The characters are in opposition if their trait }
		{ values are on opposite sides of 0. }
		InOpposition := Sgn( T1 ) <> Sgn( T2 );
	end else begin
		{ If the traits aren't strongly held by both, then }
		{ no real opposition. }
		InOpposition := False;
	end;
end;

function InHarmony( PC , NPC: GearPtr; Trait: Integer ): Boolean;
	{ If the PC and the NPC agree on this personality TRAIT, }
	{ return TRUE. Otherwise return FALSE. }
var
	T1,T2: Integer;
begin
	T1 := NAttValue( PC^.NA , NAG_CharDescription , -Trait );
	T2 := NAttValue( NPC^.NA , NAG_CharDescription , -Trait );

	if ( Abs( T1 ) > 10 ) and ( Abs( T2 ) > 10 ) then begin
		{ The characters are in opposition if their trait }
		{ values are on opposite sides of 0. }
		InHarmony := Sgn( T1 ) = Sgn( T2 );
	end else begin
		{ If the traits aren't strongly held by both, then }
		{ no real opposition. }
		InHarmony := False;
	end;
end;

Function IsSexy( PC, NPC: GearPtr ): Boolean;
	{ Return TRUE if there are some potential sparks between }
	{ the PC and NPC, or FALSE if there aren't. In this simple }
	{ universe we'll describe that as being if their genders }
	{ aren't equal to each other. }
begin
	IsSexy := ( NAttValue( PC^.NA , NAG_CharDescription , NAS_Gender ) <> NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) ) or HasTalent( PC , NAS_Bishounen );
end;

function DoChatting( GB: GameBoardPtr; var Rumors: SAttPtr; PC,NPC: GearPtr; Var Endurance,FreeRumors: Integer ): String;
	{ This function will do chatting between the specified PC }
	{ and NPC with the specified persona, adjust the Reaction and }
	{ Endurance variables, then return a string that results }
	{ from the chat session. }
var
	SkRoll,SkTarget,MOS: Integer;
	Persona: Integer;
	msg: String;
	RTemp: SAttPtr;
	Trait: Integer;		{ The personality trait invoked by this conversation. }
	RS: Integer;		{ Reaction Score }
	InOp: Boolean;
	Function TraitWeight( N : Integer ): Integer;
		{ Return a value indicating how strongly this NPC }
		{ feels about this particular personality trait. }
	begin
		TraitWeight := Abs( NAttValue( NPC^.NA , NAG_CharDescription , -N ) ) + 5;
	end;
	Function SelectTraitForChatter: Integer;
		{ Decide what the subject of the conversation is going }
		{ to be based on the NPC's traits. }
	var
		total,N,T: Integer;
	begin
		{ The trait to be used will be determined by the }
		{ weight of the NPC's traits. }
		{ Find the total of the NPC's trait points. }
		total := 0;
		for t := 1 to Num_Personality_Traits do total := total + TraitWeight( T );

		{ Next, select a random value and find a trait based on that. }
		N := Random( Total );
		T := 1;
		while N > TraitWeight( T ) do begin
			N := N - TraitWeight( T );
			Inc( T );
		end;
		SelectTraitForChatter := T;
	end;
	Procedure SelectChatter;
		{ Normally idle chatter has been selected; this procedure may }
		{ select a trait-based interaction instead. }
	begin
		if ( Trait <> 0 ) and ( Random( 3 ) <> 1 ) then begin
			{ Trait-Based Chatter. }
			msg := DoTraitChatter( NPC , Trait );
		end else begin
			{ Regular Chatter. }
			msg := IdleChatter;
		end;
	end;
	Function MaxReactBonus: LongInt;
		{ Return the maximum reaction bonus this PC can get from }
		{ this NPC. }
	var
		MRB: LongInt;
	begin
		MRB := ( SkillValue( PC , NAS_Conversation ) + CStat( PC , STAT_Charm ) ) * 2;
		MaxReactBonus := MRB;
	end;
begin
	{ Determine the effect target number. The more extreme the NPC's }
	{ current opinion of the PC is, the more difficult it will be to }
	{ change that opinion.  In addition, if the opinion is a negative }
	{ one, it'll be even harder to change the opinion. }
	RS := ReactionScore( GB^.Scene , PC , NPC );
	Persona := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	SkTarget := 5 + Abs( NAttValue( PC^.NA , NAG_ReactionScore , Persona ) ) div 4;

	{ Start by making a social interaction roll for the PC. }
	SkRoll := SkillRoll( PC , NAS_Conversation , SkTarget , 0 , False );

	{ Apply flirtation bonus to the skill roll, if appropriate. }
	{ The bonus only applies if the PC has ranks in flirtation or is a Jack of all Trades. }
	if IsSexy( PC , NPC ) and HasSkill( PC , NAS_Flirtation ) then begin
		SkRoll := SkRoll + SkillRoll( PC , NAS_Flirtation , SkTarget , 0 , False );
	end;

	{ Initialize TRAIT to random. These things will be needed later. }
	if Random( 3 ) <> 1 then begin
		Trait := SelectTraitForChatter;
	end else begin
		Trait := 0;
	end;

	{ Reduce ENDURANCE. }
	if ( SkRoll > SkTarget ) or ( Random ( 110 ) > RS ) then Dec( Endurance );
	if SkRoll < RollStep( 4 ) then Dec( Endurance );

	{ After all that stuff, we're ready to get to the useful effects. }
	{ First see what useful (or useless) information the NPC will share. }
	if ( RS < Random( 10 ) ) and ( SkRoll < RollStep( 10 ) ) then begin
		{ If the PC is unliked and not very charming, a blowoff will happen. }
		msg := BlowOff;

		{ Since the NPC is trying to get rid of the PC, }
		{ decrement ENDURANCE one more time. }
		Dec( Endurance );

	end else if ( FreeRumors > 0 ) and ( Rumors <> Nil ) then begin
		{ If the PC is entitled to any free rumors, give one out now. }
		RTemp := SelectRandomSAtt( Rumors );
		msg := RTemp^.info;
		RemoveSAtt( Rumors, RTemp );
		Dec( FreeRumors );

	end else if ( Rumors <> Nil ) and ( SkRoll > ( 5 + Random( 10 ) ) ) then begin
		RTemp := SelectRandomSAtt( Rumors );
		msg := RTemp^.info;
		RemoveSAtt( Rumors, RTemp );

	end else begin
		SelectChatter;
	end;

	{ Secondly there's a chance that the chatting will improve relations }
	{ between the PC and NPC. If a TRAIT conversation has taken place, }
	{ this could make things harder. }
	if ( Trait <> 0 ) then begin
		if InOpposition( PC , NPC , Trait ) then begin
			SkRoll := SkRoll div 3;
			{ Characters with the Diplomatic talent don't count as in opposition, }
			{ although they still do suffer the roll penalty. }
			InOp := Not TeamHasTalent( GB , NAV_DefPlayerTeam , NAS_Diplomatic );
		end else begin
			InOp := False;
		end;
	end;


	if ( SkRoll > SkTarget ) and not InOp then begin
		MOS := 1 + ( SkRoll - SkTarget ) div Chat_MOS_Measure;
		if Persona > 0 then begin
			if NAttValue( PC^.NA , NAG_ReactionScore , Persona ) < MaxReactBonus then AddNAtt( PC^.NA , NAG_ReactionScore , Persona , MOS );
		end;

	end else if SkRoll < ( SkTarget div 2 ) then begin
		{ A bad skill roll means that the reaction is going to worsen. }
		{ How much worse depends on whether or not the PC and NPC are in opposition. }
		if InOp then begin
			MOS := 1 + Random( 10 );
		end else begin
			MOS := 1;
		end;

		AddNAtt( PC^.NA , NAG_ReactionScore , Persona , -MOS );
	end;

	DoChatting := msg;
end;

Procedure LoadTraitChatter;
	{ Load the trait chatter elements from disk. }
var
	t: integer;
begin
	for t := 1 to Num_Personality_Traits do begin
		Trait_Chatter[ T , 1 ] := LoadStringList( Trait_Chatter_Base + BStr( T ) + '_1.txt' );
		Trait_Chatter[ T , 2 ] := LoadStringList( Trait_Chatter_Base + BStr( T ) + '_2.txt' );
	end;
end;

Procedure FreeTraitChatter;
	{ Remove the trait chatter elements from memory. }
var
	t: integer;
begin
	for t := 1 to Num_Personality_Traits do begin
		DisposeSAtt( Trait_Chatter[ T , 1 ] );
		DisposeSAtt( Trait_Chatter[ T , 2 ] );
	end;
end;

Function IsArchEnemy( Adv,NPC: GearPtr ): Boolean;
	{ Return TRUE if the NPC is an arch-enemy of the PC, or }
	{ FALSE otherwise. }
	{ The NPC will be an arch-enemy if it has that particular }
	{ relationship set, or if the NPC and the PC belong to }
	{ warring factions, or if the PC is an enemy of the NPC's factions's controller. }
var
	it: Boolean;
	PCF,NPCF: Integer;
	Faction: GearPtr;
begin
	it := NATtValue( NPC^.NA , NAG_Relationship , 0 ) = NAV_ArchEnemy;

	{ If this character is not an intrinsic enemy of the PC, maybe }
	{ it will be an enemy because of faction relations. }
	if ( Adv <> Nil ) and not it then begin
		NPCF := GetFactionID( NPC );
		Faction := SeekFaction( Adv , NPCF );
		PCF := NAttValue( FindRoot( Adv )^.NA , NAG_Personal , NAS_FactionID );
		if Faction <> Nil then begin
			it := ( FactionScore( Adv , NPCF , PCF ) < 0 ) or ( NAttValue( Faction^.NA , NAG_Relationship , 0 ) = NAV_ArchEnemy );

			{ If the PC isn't an enemy of the NPC's faction, see if he's an enemy }
			{ of the controlling faction. }
			if not it then begin
				NPCF := NAttValue( Faction^.NA , NAG_Narrative , NAS_ControllingFaction );
				Faction := SeekFaction( Adv , NPCF );
				if Faction <> Nil then it := ( FactionScore( Adv , NPCF , PCF ) < 0 ) or ( NAttValue( Faction^.NA , NAG_Relationship , 0 ) = NAV_ArchEnemy );
			end;
		end;
	end;

	IsArchEnemy := it;
end;

Function IsArchAlly( Adv,NPC: GearPtr ): Boolean;
	{ Return TRUE if the NPC is an arch-ally of the PC, or }
	{ FALSE otherwise. }
	{ The NPC will be an arch-ally if it has that particular }
	{ relationship set, or if the NPC and the PC belong to }
	{ the same faction. }
var
	it: Boolean;
	PCF,NPCF: Integer;
	Faction: GearPtr;
begin
	it := NATtValue( NPC^.NA , NAG_Relationship , 0 ) >= NAV_ArchAlly;

	{ If this character is not an intrinsic ally of the PC, maybe }
	{ it will be an ally because of faction relations. }
	if ( Adv <> Nil ) and not it then begin
		NPCF := GetFactionID( NPC );
		Faction := SeekFaction( Adv , NPCF );
		PCF := NAttValue( FindRoot( Adv )^.NA , NAG_Personal , NAS_FactionID );

		if Faction <> Nil then begin
			it := ( FactionScore( Adv , NPCF , PCF ) > 0 ) or ( NAttValue( Faction^.NA , NAG_Relationship , 0 ) = NAV_ArchAlly );

			{ If the PC isn't an ally of the NPC's faction, see if he's an ally }
			{ of the controlling faction. }
			if not it then begin
				NPCF := NAttValue( Faction^.NA , NAG_Narrative , NAS_ControllingFaction );
				Faction := SeekFaction( Adv , NPCF );
				if Faction <> Nil then it := ( FactionScore( Adv , NPCF , PCF ) > 0 ) or ( NAttValue( Faction^.NA , NAG_Relationship , 0 ) = NAV_ArchAlly );
			end;
		end;

	end;

	IsArchAlly := it;
end;

Function XNPCDesc( Adv,NPC: GearPtr ): String;
	{ Extended NPC description. }
var
	it: String;
	Fac,Persona: GearPtr;
	CID: LongInt;
begin
	it := NPCTraitDesc( NPC );
	it := it + ' ' + SAttValue( NPC^.SA , 'JOB_DESIG' );

	if IsArchEnemy( Adv, NPC ) then it := it + ' ARCHENEMY';
	Case NAttValue( NPC^.NA , NAG_Relationship , 0 ) of
		NAV_Lover: it := it + ' LOVER';
		NAV_Family: it := it + ' FAMILY';
		NAV_Friend: it := it + ' FRIEND';
	end;
	if IsArchAlly( Adv, NPC ) then it := it + ' ARCHALLY';

	CID := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	Persona := SeekPersona( Adv , CID );
	if ( Persona <> Nil ) and AStringHasBString( SAttValue( Persona^.SA , 'SPECIAL' ) , 'NOPLOTS' ) then it := it + ' INUSE'
	else if ( NAttValue( NPC^.NA , NAG_QuestInfo , NAS_QuestID ) <> 0 ) and ( NAttValue( FindROot( Adv )^.NA , NAG_QuestStatus , NAttValue( NPC^.NA , NAG_QuestInfo , NAS_QuestID ) ) >= 0 ) then it := it + ' INUSE'
	else if PersonaInUse( Adv , CID ) then it := it + ' INUSE'
	else it := it + ' NOTUSED';

	Fac := SeekFaction( Adv , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
	if Fac <> Nil then it := it + ' ' + SATtValue( Fac^.SA , 'DESIG' ) + ' ' + SATtValue( Fac^.SA , 'CONTEXT' );

	it := QuoteString( it );

	XNPCDesc := it;
end;

Function GenerateEnemyHook( Scene,PC,NPC: GearPtr; Desc: String ): GearPtr;
	{ Return a PERSONA gear to be used by the provided NPC }
	{ in the upcoming battle. }
	Function RelativeMessage: String;
		{ Provide a message based upon either the Ally/Enemy }
		{ status of the NPC, or upon the reaction score between }
		{ PC and NPC. }
	var
		R: Integer;
	begin
		if Random( 3 ) <> 1 then begin
			if IsArchAlly( Scene , NPC ) then begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_AreAllies_' + BStr( Random( 3 ) + 1 ) );
			end else if IsArchEnemy( Scene , NPC ) then begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_AreEnemies_' + BStr( Random( 3 ) + 1 ) );
			end else begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_AreNeutral_' + BStr( Random( 3 ) + 1 ) );
			end;
		end else begin
			R := ReactionScore( Scene, PC, NPC );
			if R > ( 35 + Random( 50 ) ) then begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_Like_' + BStr( Random( 3 ) + 1 ) );
			end else if R > ( Random( 30 ) - 10 ) then begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_Ehhh_' + BStr( Random( 3 ) + 1 ) );
			end else begin
				RelativeMessage := SAttValue( Chat_Msg_List , 'EHOOK_Hate_' + BStr( Random( 3 ) + 1 ) );
			end;
		end;
	end;

	Function TraitMessage( T: Integer ): String;
	var
		L: Integer;
	begin
		{ Note that a space is added to the front of the }
		{ trait message for formatting purposes. }
		L := NAttValue( NPC^.NA , NAG_CharDescription , -T );
		if L > 10 then begin
			TraitMessage := ' ' + SAttValue( Chat_Msg_List , 'EHOOK_Trait_' + BStr( T ) + '_1_' + BStr( Random( 3 ) + 1 ) );
		end else if L < -10 then begin
			TraitMessage := ' ' + SAttValue( Chat_Msg_List , 'EHOOK_Trait_' + BStr( T ) + '_2_' + BStr( Random( 3 ) + 1 ) );
		end else begin
			TraitMessage := '';
		end;
	end;

	Function IntimidationTarget: Integer;
		{ Determine how easily this NPC may be scared off. }
	const
		baseTV = 5;
		minimumTV = 10;
	var
		IT,Trait: Integer;
	begin
		{ Difficulcy level is based on the NPC's EGO stat. }
		it := baseTV + CStat( NPC , STAT_Ego );

		{ Certain personality traits can affect the IT. }
		{ LAWFUL characters are less likely to abandon their causes. }
		Trait := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Lawful );
		if Trait > 10 then begin
			it := it + ( Trait div 10 );
		end;

		{ PASSIONATE characters long for battle, }
		{ while EASYGOING characters long for comfort. }
		Trait := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Easygoing );
		if Trait > 25 then begin
			it := it - ( Trait div 25 );
		end else if Trait < -15 then begin
			it := it + ( Abs( Trait ) div 15 );
		end;

		{ RENOWNED characters aren't easily intimidated. }
		Trait := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) - NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned );
		if Trait > 10 then begin
			it := it + ( Trait div 5 );
		end else if Trait < -15 then begin
			it := it - ( Abs( Trait ) div 15 );
		end;

		{ If it's less than the minimum target value, }
		{ set it to at least that much. }
		if it < MinimumTV then it := MinimumTV;

		IntimidationTarget := it;
	end;

var
	Hook: GearPtr;
	greeting,msg1,cmd: String;
	N1,N2: Integer;
begin
	{ Create the gear for the hook. }
	Hook := NewGear( Nil );
	Hook^.G := GG_Persona;
	Hook^.S := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	InitGear( Hook );

	greeting := SAttValue( Chat_Msg_List , 'EHook_Greeting' );

	{ Record the intimidation target and XPV. }
	N1 := IntimidationTarget;
	SetNAtt( Hook^.NA , 0 ,  999 , N1 );
	if N1 > 0 then SetNAtt( Hook^.NA , 0 , 1000 , N1 * 50 );


	{ Create Message 1 - the NPC's speech to the player. }
	{ Start with a trait message. If empty, use a relative message }
	{ instead. }
	N1 := Random( Num_Personality_Traits ) + 1;
	msg1 := TraitMessage( N1 );
	if msg1 = '' then msg1 := RelativeMessage;

	{ Add a second trait message which should not conflict with the }
	{ first one. }
	N2 := Random( Num_Personality_Traits - 1 ) + 1;
	if N2 = N1 then Inc( N2 );
	msg1 := msg1 + TraitMessage( N2 );

	{ Define the options. }
	desc := UpCase( desc );
	while desc <> '' do begin
		cmd := ExtractWord( desc );

		if cmd = '+PCRA' then begin
			{ Player can run away. Enemy will give player }
			{ the option to leave. }
			msg1 := msg1 + ' ' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_PCRA_' + BStr( Random( 5 ) + 1 ) ) );
			greeting := greeting + ' AddChat 2';
			SetSAtt( Hook^.SA , 'prompt2 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_P_2_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
			SetSAtt( Hook^.SA , 'result2 <' + SAttValue( Chat_Msg_List , 'EHOOK_R_2' ) + '>' );
			SetSAtt( Hook^.SA , 'msg3 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_Msg3_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );

		end else if cmd = '+ECRA' then begin
			{ Enemy can run away. Player will have }
			{ the option to threaten the NPC. }
			greeting := greeting + ' AddChat 3';
			SetSAtt( Hook^.SA , 'prompt3 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_P_3_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
			SetSAtt( Hook^.SA , 'result3 <' + SAttValue( Chat_Msg_List , 'EHOOK_R_3' ) + '>' );
			SetSAtt( Hook^.SA , 'msg4 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_Msg4_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
			SetSAtt( Hook^.SA , 'msg5 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_Msg5' ) ) + '>' );

		end;
	end;

	SetSAtt( Hook^.SA , 'greeting <' + greeting + '>' );
	SetSAtt( Hook^.SA , 'msg1 <' + FormatChatString( msg1 ) + '>' );
	SetSAtt( Hook^.SA , 'msg2 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_Msg2_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
	SetSAtt( Hook^.SA , 'prompt1 <' + FormatChatString( SAttValue( Chat_Msg_List , 'EHOOK_P_1_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );
	SetSAtt( Hook^.SA , 'result1 <' + SAttValue( Chat_Msg_List , 'EHook_R_1' ) + '>' );

	GenerateEnemyHook := Hook;
end;

Function GenerateAllyHook( Scene,PC,NPC: GearPtr ): GearPtr;
	{ The only real purpose of this is to let the player know that }
	{ there's another mecha on his side. }
var
	Hook: GearPtr;
begin
	{ Create the gear for the hook. }
	Hook := NewGear( Nil );
	Hook^.G := GG_Persona;
	Hook^.S := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	InitGear( Hook );

	SetSAtt( Hook^.SA , 'greeting <' + SAttValue( chat_msg_list , 'AHOOK_Greeting' ) + '>' );
	SetSAtt( Hook^.SA , 'result1 <' + SAttValue( chat_msg_list , 'AHOOK_R_1' ) + '>' );
	SetSAtt( Hook^.SA , 'Msg1 <' + FormatChatString( SAttValue( chat_msg_list , 'AHOOK_MSG1_' + BStr( Random( 3 ) + 1 ) ) ) + '>' );
	SetSAtt( Hook^.SA , 'Msg2 <' + FormatChatString( SAttValue( chat_msg_list , 'AHOOK_MSG2_' + BStr( Random( 3 ) + 1 ) ) ) + '>' );
	SetSAtt( Hook^.SA , 'Prompt1 <' + FormatChatString( SAttValue( chat_msg_list , 'AHOOK_P_1_' + BStr( Random( 5 ) + 1 ) ) ) + '>' );

	GenerateAllyHook := Hook;
end;

Function LancematesPresent( GB: GameBoardPtr ): Integer;
	{ Return the number of points worth of lancemates present. }
	{ This will determine whether or not the PC can recruit more. }
	{ Check for Team-3 gears; add +2 to the total for each mecha or }
	{ person, +1 to the total for each other master. }
var
	M: GearPtr;
	N: Integer;
begin
	M := GB^.Meks;
	N := 0;
	while M <> Nil do begin
		if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and GearActive( M ) then begin
			if ( M^.G = GG_Mecha ) or ( NAttValue( M^.NA , NAG_Personal , NAS_CID ) <> 0 ) then begin
				N := N + 2;
			end else begin
				N := N + 1;
			end;
		end;
		M := M^.Next;
	end;
	LancematesPresent := N;
end;

Function FindLocalNPCByKeyWord( GB: GameBoardPtr; KW: String ): GearPtr;
	{ Attempt to locate a NPC by keyword. The keyword may be the job of the NPC, or }
	{ it may be a phrase listed in the NPC's Persona's KEYWORDS string attribute. }
	{ The NPC must be local to the PC: That is, it must be either located on the }
	{ game board or within the root scene. }
	Function NPCMatchesKW( NPC: GearPtr ): Boolean;
	var
		desc: String;
		Persona: GearPtr;
	begin
		desc := SAttValue( NPC^.SA , 'JOB' );
		Persona := SeekPersona( GB , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) );
		if Persona <> Nil then desc := desc + SAttValue( Persona^.SA , 'KEYWORDS' );
		NPCMatchesKW := AStringHasBString( desc , KW );
	end;
	Function NumNPCsAlongPath( M: GearPtr ): Integer;
		{ Find out how many NPCs match the given keyword checking along }
		{ this path, including subcoms and invcoms. }
	var
		N: Integer;
	begin
		N := 0;
		while M <> Nil do begin
			if M^.G = GG_Character then begin
				if NPCMatchesKW( M ) then Inc( N );
			end;
			N := N + NumNPCsAlongPath( M^.SubCom );
			N := N + NumNPCsAlongPath( M^.InvCom );
			M := M^.Next;
		end;
		NumNPCsAlongPath := N;
	end;
	Function FindNPCAlongPath( M: GearPtr; var N: Integer ): GearPtr;
		{ Find the Nth NPC searching along this path and through its children. }
	var
		NPC: GearPtr;
	begin
		NPC := Nil;
		while ( M <> Nil ) and ( NPC = Nil ) do begin
			if ( M^.G = GG_Character ) and NPCMatchesKW( M ) then begin
				Dec( N );
				if N = -1 then begin
					NPC := M;
				end;
			end;
			if NPC = Nil then NPC := FindNPCAlongPath( M^.SubCom , N );
			if NPC = Nil then NPC := FindNPCAlongPath( M^.InvCom , N );
			M := M^.Next;
		end;
		FindNPCAlongPath := NPC;
	end;
var
	N: Integer;
	RootScene,M: GearPtr;
begin
	{ Pass one: Locate all NPCs who match the keyword provided. }
	{ Search order: GB, Root Scene SubComs }
	N := NumNPCsAlongPath( GB^.Meks );
	M := Nil;
	RootScene := FindRootScene( GB , GB^.Scene );
	if RootScene <> Nil then begin
		N := N + NumNPCsAlongPath( RootScene^.SubCom );
		N := N + NumNPCsAlongPath( RootScene^.InvCom );
	end;

	{ Pass two: Pick one at random, and select it. }
	if N > 0 then begin
		N := Random( N );
		M := FindNPCAlongPath( GB^.Meks , N );
		if ( M = Nil ) and ( RootScene <> Nil ) then begin
			M := FindNPCAlongPath( RootScene^.SubCom , N );
			if M = Nil then M := FindNPCAlongPath( RootScene^.InvCom , N );
		end;
	end;

	{ Return the NPC found. }
	FindLocalNPCByKeyWord := M;
end;

initialization

	Noun_List := LoadStringList( Standard_Nouns_File );
	Phrase_List := LoadStringList( Standard_Phrases_File );
	Adjective_List := LoadStringList( Standard_Adjectives_File );
	RLI_List := LoadStringList( Standard_Rumors_File );
	Threat_List := LoadStringList( Standard_Threats_File );
	Chat_Msg_List := LoadStringList( Standard_Chatter_File );
	LoadTraitChatter;

finalization
	DisposeSAtt( Noun_List );
	DisposeSAtt( Phrase_List );
	DisposeSAtt( Adjective_List );
	DisposeSAtt( RLI_List );
	DisposeSAtt( Threat_List );
	DisposeSAtt( Chat_Msg_List );
	FreeTraitChatter;
end.
