unit ghchars;
	{This unit handles the constants, functions, and}
	{attributes associated with Character gears.}
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
	{ ******************************** }
	{ ***  CHARACTER  DEFINITIONS  *** }
	{ ******************************** }
	{ G = GG_Character }
	{ S = Undefined    }
	{ V = Unefinded; previously Monster Threat Value.  }

uses texutil,gears,uiconfig;

Type
	SkillDesc = Record
		Hidden: Boolean;	{ Is this one of the hidden skills all characters start with? }
		MekSys: Byte;		{ Is this skill affected by a mecha stat modifier? }
		ToolNeeded: Byte;	{ Does this skill require a tool? }
		Usage: Byte;		{ How is this skill used? }
	end;

Const
	{  NAG_StatImprovementLevel counts how many times a stat has been }
				{ improved through experience. }

	{ This is the normal maximum stat value in character creation. }
	NormalMaxStatValue = 14;

	{ Here are the Mecha System definitions for skills. }
	MS_Maneuver = 1;
	MS_Targeting = 2;
	MS_Sensor = 3;

	{ SKILL FORMAT }
	{ G = NAG_Skill }
	{ S = Skill Name }
	{ V = Skill Rank }


				{ Combatant characters can take part in mecha combat. }
	NAS_IsMentor = 4;	{ If nonzero, this character is a mentor. }
				{ Mentors may never be taken as lancemates. }
	NAS_NonMissionGiver = 5;	{ If nonzero, this character may not give missions. }
					{ Random NPCs don't usually get this authority. }
	{ How many times has the character's Heroism }
					{ been increased- there's a limit. }

	NAS_Skill_XP_Base = 100;	{ For skill-specific XP awards. }
					{ S = 100 + Skill Index }

 	{ Conversion between credits and experience, used for }
				{ skill training and also for skill-boosting foods. }


	MORALE_HPRegen = 5;
	MORALE_RepSmall = 10;
	MORALE_RepBig = 30;

	FOOD_MORALE_FACTOR = 15;

	{ Hunger penalty is calibrated to start roughly twelve hours }
	{ after your last meal. }
	Hunger_Penalty_Starts = 70;


	{  ******************  }
	{  ***   SKILLS   ***  }
	{  ******************  }

	{For now, all skills will be hardcoded into the game binary.}
	{At some point in time I may have them defined in an}
	{external text file, but since the application of these}
	{skills have to be hard coded I don't see why the data}
	{for them shouldn't be as well.}

	USAGE_Repair = 1;
	USAGE_Clue = 2;
	USAGE_Performance = 3;	{ Gets its own type, since it's unique. }
	USAGE_Robotics = 4;	{ Ditto. }
	USAGE_DominateAnimal = 5;	{ Yet another unique skill. }
	USAGE_PickPockets = 6;		{ The same. }

	TOOL_None = 0;
	TOOL_Performance = 1;
	TOOL_CodeBreaking = 2;

	SkillMan: Array [1..NumSkill] of SkillDesc = (
		{ Skills 1 - 5 }
		(	{Mecha Gunnery}
			hidden: False;
			meksys: MS_Targeting;
			ToolNeeded: TOOL_None;
			Usage: 0			),
		(	{Mecha Fighting}
			hidden: False;
			meksys: MS_Maneuver;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Mecha Piloting}
			hidden: False;
			meksys: MS_Maneuver;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Ranged Combat}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Close Combat}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),

		{ Skills 6 - 10 }
		(	{Dodge}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Vitality}
			hidden: True;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Athletics}
			hidden: True;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Concentration}
			hidden: True;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Awareness}
			hidden: False;
			meksys: MS_Sensor;
			ToolNeeded: TOOL_None;
			Usage: 0;			),

		{ Skills 11 - 15 }
		(	{Initiative}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Survival}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: USAGE_Clue;		),
		(	{Repair}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: USAGE_Repair;		),
		(	{Medicine}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: USAGE_Repair;		),
		(	{Electronic Warfare}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),

		{ Skills 16 - 20 }
		(	{Spot Weakness}
			hidden: False;
			meksys: MS_Sensor;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Conversation}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Shopping}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Stealth}
			hidden: False;
			meksys: MS_Maneuver;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Intimidation}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),

		{ Skills 21 - 25 }
		(	{Science}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: USAGE_Clue;		),
		(	{Mecha Engineering}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Code Breaking}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_CodeBreaking;
			Usage: USAGE_Clue;		),
		(	{Mysticism}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: USAGE_Clue;		),
		(	{Performance}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_Performance;
			Usage: USAGE_Performance;	),

		{ Skills 26 - 30 }
		(	{Toughness}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			),
		(	{Insight}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: USAGE_Clue;		),
		(	{Taunt}
			hidden: False;
			meksys: 0;
			ToolNeeded: TOOL_None;
			Usage: 0;			)
	);


	Num_Basic_Combat_Skills = 6;



	{  *******************  }
	{  ***   TALENTS   ***  }
	{  *******************  }



	{ Talent pre-requisites are described as follows: The first }
	{ coordinate lists the skill (if positive) or stat (if negative) }
	{ needed to gain the talent. The second coordinate lists the }
	{ minimum value required. If either coordinate is zero, this }
	{ talent has no pre-requisites. }
	{ NEW: Personality traits may be specified as -8 + Trait Number }
	TALENT_PreReq: Array [1..NumTalent,1..2] of Integer = (
	( NAS_CloseCombat , 5 ), ( NAS_CloseCombat , 5 ) , ( NAS_Medicine , 5 ) , ( NAS_Toughness , 5 ) , ( -STAT_Speed , 15 ) ,
	( 0 , 0 ), ( -STAT_Charm , 15 ) , ( NAS_MechaPiloting , 5 ) , ( NAS_MechaPiloting , 5 ) , ( NAS_MechaPiloting , 5 ),
	( NAS_Repair , 5 ), ( 0 , 0 ), ( NAS_Shopping , 5 ), (-STAT_Craft,15), ( 0 , 0 ),
	( NAS_Stealth , 5 ), ( NAS_ElectronicWarfare , 5 ), ( 0 , 0 ), ( NAS_SpotWeakness , 5 ), ( NAS_MechaEngineering , 10 ),
	( NAS_Conversation , 5 ), ( -8 + NAS_Renowned , 80 ), ( NAS_Science , 5 ), ( NAS_Dodge , 5 ), ( NAS_Survival , 5 ),
	( NAS_Stealth , 5 ), ( NAS_Science , 5 )
	);

	TALENT_Usage: Array [1..NumTalent] of Integer = (
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, 0, 0, 0,
		0, 0, USAGE_Robotics, 0, USAGE_DominateAnimal,
		USAGE_PickPockets, 0
	);

	{  *************************  }
	{  ***   MERIT  BADGES   ***  }
	{  *************************  }

	{ Merit badges are attributes which must be earned by the PC. Some }
	{ of them confer special abilities or bonuses, while others don't. }
	{ Note that while defined here, merit badges should be stored in the }
	{ adventure gear rather than the PC itself. }

	{ PERSONAL attributes hold information about the character's place }
	{ in the campaign world. }

	{ FACREWARD attributes tell what perks the PC has been given by a faction. }
	{  These are stored in the faction gear rather than the PC. }



Procedure InitChar(Part: GearPtr);
Function CharBaseDamage( PC: GearPtr; CBod,CVit: Integer ): Integer;

Function RandomName: String;
procedure RollStats( PC: GearPtr; Pts: Integer);
function RandomPilot( StatPoints , SkillRank: Integer ): GearPtr;

Function NumberOfSpecialties( PC: GearPtr ): Integer;

function IsLegalCharSub( Part: GearPtr ): Boolean;

Function CanLearnTalent( PC: GearPtr; T: Integer ): Boolean;
Function NumFreeTalents( PC: GearPtr ): Integer;
Procedure ApplyTalent( PC: GearPtr; T: Integer );

Function CharStamina( PC: GearPtr ): Integer;
Function CharMental( PC: GearPtr ): Integer;

Function IsACombatant( NPC: GearPtr ): Boolean;

implementation

uses ghmodule,lua,lauxlib;

Procedure InitChar(Part: GearPtr);
	{PART is a newly created Character record.}
	{Initialize its stuff.}
begin
	{Default scale for a PC is 0.}
	Part^.Scale := 0;

	{ Default material for a PC is "meat". }
	SetNAtt( Part^.NA , NAG_GearOps , NAS_Material , NAV_Meat );
end;

Function CharBaseDamage( PC: GearPtr; CBod,CVit: Integer ): Integer;
	{Calculate the number of general HPs that a character}
	{can take.}
var
	HP: Integer;
begin
	{Error check- make sure we have a character here.}
	if PC^.G <> GG_Character then Exit(0);

	{ If CBod is less than the BODY stat, use the BODY stat. }
	if CBod < PC^.STAT[ STAT_Body ] then CBod := PC^.STAT[ STAT_Body ];

	HP := ( CBod + 5 ) div 2;

	{ Add the Vitality skill. }
	HP := HP + CVit + ( NAttValue( PC^.NA , NAG_Skill , NAS_Toughness ) div 2 );

	CharBaseDamage := HP;
end;

Function RandomName: String;
	{Generate a random name for a character.}
Const
	NumSyllables = 126;
	SyllableList: Array [1..NumSyllables] of String [5] = (
		'Jo','Sep','Hew','It','Seo','Eun','Suk','Ki','Kang','Cho',
		'Ai','Bo','Ca','Des','El','Fas','Gun','Ho','Ia','Jes',
		'Kep','Lor','Mo','Nor','Ox','Pir','Qu','Ra','Sun','Ter',
		'Ub','Ba','Tyb','War','Bac','Yan','Zee','Es','Vis','Jang',
		'Vic','Tor','Et','Te','Ni','Mo','Bil','Con','Ly','Dam',
		'Cha','Ro','The','Bes','Ne','Ko','Kun','Ran','Ma','No',
		'Ten','Do','To','Me','Ja','Son','Love','Joy','Ken','Iki',
		'Han','Lu','Ke','Sky','Wal','Jen','Fer','Le','Ia','Chu',
		'Tek','Ubu','Roi','Har','Old','Pin','Ter','Red','Ex','Al',
		'Alt','Rod','Mia','How','Phi','Aft','Aus','Tin','Her','Ge',
		'Hawk','Eye','Ger','Ru','Od','Jin','Un','Hyo','Leo','Star',
		'Buck','Ers','Rog','Eva','Ova','Oni','Ami','Ga','Cyn','Mai',
		'Na','Mel','Gha','Mek','Kat','Ser'
	);

	NumVowels = 11;
	VowelList: Array [1..NumVowels] of Char = (
		'A','E','I','O','U','Y','A','E','I','O',
		'U'
	);

	NumConsonants = 33;
	ConsonantList: Array [1..NumConsonants] of Char = (
		'B','C','D','F','G','H','J','K','L','M','N',
		'P','Q','R','S','T','V','W','X','Y','Z','T',
		'N','S','H','R','D','L','C','M','P','B','G'
	);

	Function Syl( IsFirst: Boolean ): String;
	begin
		if Random(20) = 1 then
			Syl := VowelList[Random(NumVowels)+1]
		else if Random( 4 ) <> 1 then begin
			{ Create a three-letter syllable. }
			if IsFirst then begin
				if Random( 2 ) = 1 then begin
					{ Begin with a vowel- use VCC, as reccomended by Joshua Smyth }
					Syl := VowelList[Random(NumVowels)+1] + LowerCase( ConsonantList[Random(NumConsonants)+1] ) + LowerCase( ConsonantList[Random(NumConsonants)+1] );
				end else if Random( 10 ) = 1 then begin
					Syl := ConsonantList[Random(NumConsonants)+1] + LowerCase( VowelList[Random(NumVowels)+1] ) + LowerCase( VowelList[Random(NumVowels)+1] ) + LowerCase( ConsonantList[Random(NumConsonants)+1] );
				end else begin
					{ Begin with a consonant- use CVC, again reccomended by Joshua Smyth }
					Syl := ConsonantList[Random(NumConsonants)+1] + LowerCase( VowelList[Random(NumVowels)+1] ) + LowerCase( ConsonantList[Random(NumConsonants)+1] );
				end;
			end else begin
				if Random( 5 ) = 1 then begin
					{ Begin with a consonant- use CVC, again reccomended by Joshua Smyth }
					Syl := ConsonantList[Random(NumConsonants)+1] + LowerCase( VowelList[Random(NumVowels)+1] ) + LowerCase( ConsonantList[Random(NumConsonants)+1] );
				end else if Random( 4 ) = 1 then begin
					Syl := VowelList[Random(NumVowels)+1] + LowerCase( ConsonantList[Random(NumConsonants)+1] ) + LowerCase( VowelList[Random(NumVowels)+1] );
				end else if Random( 3 ) = 1 then begin
					Syl := ConsonantList[Random(NumConsonants)+1] + LowerCase( VowelList[Random(NumVowels)+1] );
				end else if Random( 2 ) = 1 then begin
					Syl := VowelList[Random(NumVowels)+1] + LowerCase( ConsonantList[Random(NumConsonants)+1] );
				end else begin
					Syl := VowelList[Random(NumVowels)+1] + LowerCase( ConsonantList[Random(NumConsonants)+1] ) + LowerCase( ConsonantList[Random(NumConsonants)+1] );
				end;
			end;
		end else if Random( 7 ) = 2 then begin
			if Random(3) = 1 then
				Syl := ConsonantList[Random(NumConsonants)+1] + LowerCase( VowelList[Random(NumVowels)+1] )
			else if Random(2) = 1 then
				Syl := VowelList[Random(NumVowels)+1] + LowerCase( ConsonantList[Random(NumConsonants)+1] )
			else if Random(2) = 1 then
				Syl := ConsonantList[Random(NumConsonants)+1] + LowerCase( VowelList[Random(NumVowels)+1] ) + LowerCase( ConsonantList[Random(NumConsonants)+1] )
			else
				Syl := VowelList[Random(NumVowels)+1] + LowerCase( ConsonantList[Random(NumConsonants)+1] ) + LowerCase( VowelList[Random(NumVowels)+1] );
		end else
			Syl := SyllableList[Random(NumSyllables)+1];
	end;
var
	it, E: String;
begin
	lua_getglobal( MyLua , 'gh_RandomName' );

	it := '';
	if lua_pcall( MyLua , 0 , 1 , 0 ) = 0 then begin
		it := lual_checkstring( MyLua , 1 );
	end else begin
		{ Report an error }
		E := 'RandomName ERROR: ' + lua_tostring( MyLua , -1 );
		RecordError( E );
	end;
	lua_settop( MyLua , 0 );

	if it = '' then begin
		{A basic name is two syllables stuck together.}
		if Random(100) <> 5 then
			it := Syl( True ) + LowerCase(Syl( False ) )
		else
			it := Syl( True );

		{Uncommon names may have 3 syllables.}
		if ( Random(8) > Length(it) ) then
			it := it + LowerCase(Syl( False ) )
		else if Random(30) = 1 then
			it := it + LowerCase(Syl( False ) );

		{Short names may have a second part. This isn't common.}
		if ( Length( it ) < 3 ) and ( Random( 30 ) <> 1 ) then begin
			it := it + ' ' + Syl( True ) + LowerCase(Syl( False ) )
		end else if ( Length( it ) < 5 ) and ( Random( 3 ) <> 1 ) then begin
			it := it + ' ' + Syl( True );
			if Random(4) <> 1 then it := it + LowerCase(Syl( False ) );
		end else if (Length(it) < ( 7 + Random( 5 ) ) ) and (Random(3) = 1) then begin
			it := it + ' ' + Syl( True );
			if Random(3) <> 1 then it := it + LowerCase(Syl( False ) );
		end;

		{ Random chance of random anime designation. }
		if Random(1000) = 123 then it := it + ' - ' + ConsonantList[Random(21)+1];
	end;

	RandomName := it;
end;

procedure RollStats( PC: GearPtr; Pts: Integer);
	{ Randomly allocate PTS points to all of the character's }
	{ stats.  Advancing stats past maximum }
	{ rank takes two stat points per rank instead of one. }
	{ Hopefully, this will be clear once you read the implementation... }
var
	T: Integer;	{ A loop counter. }
	STemp: Array [1..NumGearStats] of Integer;
	{ I always name my loop counters T, in honor of the C64. }
begin
	{ Error Check - Is this a character!? }
	if ( PC = Nil ) or ( PC^.G <> GG_Character ) then Exit;

	{ Set all stat values to minimum. }
	if Pts >= NumGearStats then begin
		for t := 1 to NumGearStats do begin
			STemp[T] := 1;
		end;
		Pts := Pts - NumGearStats;
	end else begin
		for t := 1 to NumGearStats do begin
			STemp[T] := 0;
		end;
	end;

	{ Keep processing until we run out of stat points to allocate. }
	while Pts > 0 do begin
		{ T will now point to the stat slot to improve. }
		T := Random( NumGearStats ) + 1;

		{ If the stat selected is under the max value, }
		{ improve it. If it is at or above the max value, }
		{ there's a one in three chance of improving it. }
		if ( STemp[T] + PC^.Stat[ T ] ) < NormalMaxStatValue then begin
			Inc( STemp[T] );
			Dec( Pts );

		end else if Random(2) = 1 then begin
			Inc( STemp[T] );
			Pts := Pts - 2;

		end;
	end;

	{ Add the STemp values to the stat baseline. }
	for t := 1 to NumGearStats do PC^.Stat[t] := PC^.Stat[t] + STemp[t];
end;

function RandomPilot( StatPoints , SkillRank: Integer ): GearPtr;
	{ Create a totally random mecha pilot, presumably so that }
	{ the PC pilots will have someone to thwack. }
const
	NumNPCPilotSpecialties = 6;
	PS: Array [1..NumNPCPilotSpecialties] of Byte = (
		NAS_SpotWeakness, NAS_Initiative, NAS_ElectronicWarfare, NAS_Awareness, NAS_Stealth,
		NAS_Vitality
	);
var
	NPC: GearPtr;
	T: Integer;
begin
	{ Generate record. }
	NPC := NewGear;
	if NPC = Nil then Exit( Nil );
	InitChar( NPC );
	NPC^.G := GG_Character;

	{ Roll some stats for this character. }	
	RollStats( NPC , StatPoints );

	{ Set all combat skills to equal SkillRank. }
	for t := 1 to Num_Basic_Combat_Skills do begin
		SetNAtt( NPC^.NA , NAG_Skill , T , SkillRank );
	end;
	{ Add a specialty. }
	SetNAtt( NPC^.NA , NAG_Skill , PS[ Random( NumNPCPilotSpecialties ) + 1 ] , SkillRank );

	{ Generate a random name for the character. }
	SetSAtt( NPC^.SA , 'Name <'+RandomName+'>');

	{ Return a pointer to the character record. }
	RandomPilot := NPC;
end;

Function NumberOfSpecialties( PC: GearPtr ): Integer;
	{ Return the number of skills this PC knows. Don't return the hidden skills; }
	{ those don't count. }
var
	T,N: Integer;
begin
	N := 0;
	for t := 1 to NumSkill do begin
		if ( not SkillMan[ t ].Hidden ) and ( NAttValue( PC^.NA , NAG_Skill , T ) > 0 ) then Inc( N );
	end;
	NumberOfSpecialties := N;
end;

function IsLegalCharSub( Part: GearPtr ): Boolean;
	{ Return TRUE if the specified part can be a subcomponent of }
	{ SPC, false if it can't be. }
begin
	if ( Part^.G = GG_Module ) then IsLegalCharSub := True
	else if ( Part^.G = GG_Modifier ) then IsLegalCharSub := Part^.V = GV_CharaModifier
	else IsLegalCharSub := False;
end;

Function CanLearnTalent( PC: GearPtr; T: Integer ): Boolean;
	{ Return TRUE if the PC can learn this talent, or FALSE otherwise. }
begin
	{ The talent must be within the legal range in order to be }
	{ learned. }
	if ( T < 1 ) or ( T > NumTalent ) then begin
		CanLearnTalent := False;

	{ The PC can't learn the same talent twice. }
	end else if NAttValue( PC^.NA , NAG_Talent , T ) <> 0 then begin
		CanLearnTalent := False;

	end else if ( Talent_PreReq[ T , 1 ] = 0 ) or ( Talent_PreReq[ T , 2 ] = 0 ) then begin
		CanLearnTalent := True;

	end else if ( Talent_PreReq[ T , 1 ] > 0 ) then begin
		CanLearnTalent := NAttValue( PC^.NA , NAG_Skill , Talent_PreReq[ T , 1 ] ) >= Talent_PreReq[ T , 2 ];

	end else if ( Talent_PreReq[ T , 1 ] < -8 ) then begin
		if Talent_PreReq[ T , 2 ] < 0 then begin
			CanLearnTalent := NAttValue( PC^.NA , NAG_CharDescription , Talent_PreReq[ T , 1 ] + 8 ) <= Talent_PreReq[ T , 2 ];
		end else begin
			CanLearnTalent := NAttValue( PC^.NA , NAG_CharDescription , Talent_PreReq[ T , 1 ] + 8 ) >= Talent_PreReq[ T , 2 ];
		end;

	end else begin
		CanLearnTalent := PC^.Stat[ Abs( Talent_PreReq[ T , 1 ] ) ] >= Talent_PreReq[ T , 2 ];

	end;
end;

Function NumFreeTalents( PC: GearPtr ): Integer;
	{ Return the number of talents the PC can learn. }
var
	TP: NAttPtr;
	N: Integer;
	XP: LongInt;
begin
	{ Start by counting the number of talents the PC currently has. }
	TP := PC^.NA;
	N := 0;
	while TP <> Nil do begin
		if TP^.G = NAG_Talent then Inc( N );
		TP := TP^.Next;
	end;

	{ Subtract this from the total number of talents the PC can get, }
	{ based on Experience. }
	XP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP );
	if XP > 100000 then N := 5 - N
	else if XP > 60000 then N := 4 - N
	else if XP > 30000 then N := 3 - N
	else if XP > 10000 then N := 2 - N
	else N := 1 - N;

	NumFreeTalents := N;
end;

Procedure ApplyIdealism( PC: GearPtr );
	{ Apply a +1 modifier to three random stats. }
var
	T,T2,S: Integer;
	StatDeck: Array [1..NumGearStats] of Integer;
begin
	{ Start by shuffling the statdeck. }
	for t := 1 to NumGearStats do StatDeck[ t ] := T;
	for t := 1 to NumGearStats do begin
		S := Random( NumGearStats ) + 1;
		T2 := StatDeck[ t ];
		StatDeck[ t ] := StatDeck[ S ];
		StatDeck[ S ] := T2;
	end;

	{ Select the first three stats off the top of the deck. }
	for t := 1 to 3 do Inc( PC^.Stat[ StatDeck[ T ] ] );
end;

Procedure ApplyTalent( PC: GearPtr; T: Integer );
	{ Apply the listed talent to the PC, invoking any special effects }
	{ if needed. }
begin
	{ Start with an error check. }
	if ( T < 1 ) or ( T > NumTalent ) then Exit;

	{ Record the talent. }
	SetNAtt( PC^.NA , NAG_Talent , T , 1 );

	{ Depending on the talent, do various effects. }
	Case T of
		NAS_Idealist:
			ApplyIdealism( PC );
	end;
end;

Function CharStamina( PC: GearPtr ): Integer;
	{Calculate the number of stamina points that a character has.}
var
	SP: Integer;
begin
	{Error check- make sure we have a character here.}
	if PC^.G <> GG_Character then Exit(0);

	{ basic stamina rating is equal to the average between BODY and EGO. }
	SP := ( PC^.Stat[ STAT_Body ] + PC^.Stat[ STAT_Ego ] + 5 ) div 2;

	{ Add the Athletics skill. }
	SP := SP + NAttValue( PC^.NA , NAG_Skill , NAS_Athletics ) * 3;

	CharStamina := SP;
end;



Function CharMental( PC: GearPtr ): Integer;
	{Calculate the number of mental points that a character has.}
var
	MP: Integer;
begin
	{Error check- make sure we have a character here.}
	if PC^.G <> GG_Character then Exit(0);

	{ basic mental rating is equal to the average between }
	{ KNOWLEDGE and EGO. }
	MP := ( PC^.Stat[ STAT_Knowledge ] + PC^.Stat[ STAT_Ego ] + 5 ) div 2;

	{ Add the Concentration skill. }
	MP := MP + NAttValue( PC^.NA , NAG_Skill , NAS_Concentration ) * 3;

	CharMental := MP;
end;

Function IsACombatant( NPC: GearPtr ): Boolean;
	{ Return TRUE if this NPC should be given a mecha to take part in combat. }
begin
	IsACombatant := ( NPC <> Nil ) and ( NAttValue( NPC^.NA , NAG_CharDescription , NAS_IsCombatant ) <> 0 );
end;

end.
