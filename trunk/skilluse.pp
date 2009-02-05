unit SkillUse;
	{ This unit should cover the usage of skills for the RPG game. }
	{ Actually, it doesn't cover the usage of all skills- most of }
	{ them get implemented in other places (combat skills in the }
	{ attacker unit, conversation skills in the interact unit, etc). }
	{ This unit covers those skills which pretty well need their }
	{ own interface/code... repair skills, picking pockets, etc. }
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
	Repair_Mental_Strain = 1;
	Repair_Max_Tries = 5;

	Performance_Range = 9;
	Performance_Base_Cash = -50;

	TRIGGER_Applause = 'APPLAUSE';


Function TotalRepairableDamage( Target: GearPtr; Skill: Integer ): LongInt;
Procedure ApplyRepairPoints( Target: GearPtr; Skill: Integer; var RP: LongInt );
Procedure ApplyEmergencyRepairPoints( Target: GearPtr; Skill: Integer; var RP: LongInt );
Function UseRepairSkill( GB: GameBoardPtr; PC,Target: GearPtr; Skill: Integer ): LongInt;
Procedure DoCompleteRepair( Target: GearPtr );

Function UsePerformance( GB: GameBoardPtr; PC: GearPtr ): LongInt;


implementation

uses ability,action,gearutil,ghchars,ghholder,ghmodule,ghmovers,ghswag,
     ghweapon,movement,interact,rpgdice,texutil,narration,ghsupport;

Function RepairSkillNeeded( Part: GearPtr ): Integer;
	{ Return the code number of the skill which is needed to fix PART. }
	{ The repair skills are:   }
	{     15. Mecha Tech       }
	{     16. Medicine         }
	{     20. First Aid        }
	{     22. Bio Tech         }
	{     23. General Repair   }
var
	Master: GearPtr;
	Material,Skill: Integer;
begin
	{ Start by finding the master and material for this part. }
	Master := FindMaster( Part );
	Material := NAttValue( Part^.NA , NAG_GearOps , NAS_Material );

	if Material = NAV_BioTech then begin
		Skill := 22;
	end else if ( Master = Nil ) or ( Master^.G = GG_Mecha ) then begin
		{ If it's made of MEAT, use biotech. }
		if Material = NAV_Meat then begin
			Skill := 22;

		{ If it's made of METAL, use Basic Repair for human-scale }
		{ items and Mecha Tech for large scale items. }
		end else begin
			if Part^.Scale = 0 then Skill := 23
			else Skill := 15;
		end;

	end else if Master^.G = GG_Character then begin
		if Material = NAV_Metal then begin
			{ If this is a SubCom and its parent is MEAT, use Cybertech. }
			{ Otherwise use Basic Repair. }
			if IsSubCom( Part ) and ( NAttValue( Part^.Parent^.NA , NAG_GearOps , NAS_Material ) = NAV_Meat ) then Skill := 24
			else begin
				if Part^.Scale = 0 then Skill := 23
				else Skill := 15;
			end;

		end else begin
			{ If this is an inventory part, use BioTech. }
			{ If the part has been destroyed, this requires }
			{ the Medicine skill. Otherwise First Aid will do. }
			if IsInvCom( Part ) then Skill := 22
			else if Destroyed( Part ) then Skill := 16
			else Skill := 20;
		end;

	end else begin
		{ Apparently we don't know what this is, so }
		{ we'll just use MECHA TECH on it. }
		Skill := 15;
	end;

	RepairSkillNeeded := Skill;
end;

Function TotalRepairableDamage( Target: GearPtr; Skill: Integer ): LongInt;
	{ Search through TARGET, and calculate how much damage it has }
	{ that can be repaired using SKILL. }
var
	Part: GearPtr;
	AD,SD,TCom,SCom,it: LongInt;
	T: Integer;
begin
	{ Normally damage must be positive I know, but I just had a bug }
	{ which resulted in negative damage. This prevented the rest of }
	{ the damage to a mek/character from being repaired. So, taking }
	{ absolute value should fix all the mess & prevent it from }
	{ happening again. }
	SD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_StrucDamage ) );
	AD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_ArmorDamage ) );
	it := 0;

	{ If this part is damaged, and if the needed repair skill is }
	{ the skill we're looking for, add the damage to the total. }
	if RepairSkillNeeded( Target ) = Skill then begin
		it := AD + SD;

		{ Modify for complexity. }
		if not IsMasterGear( Target ) then begin
			TCom := ComponentComplexity( Target );
			SCom := SubComComplexity( Target );
			if SCom > TCom then begin
				it := ( it * SCom ) div TCom;
			end;
		end;
	end;

	{ Check for status effects. }
	for t := 1 to Num_Status_FX do begin
		if ( SX_RepSkill[t] = Skill ) and ( NAttValue( Target^.NA , NAG_StatusEffect , T ) <> 0 ) then begin
			it := it + SX_RepCost[ T ];
		end;
	end;

	{ Check the sub-components for damage. }
	Part := Target^.SubCom;
	while Part <> Nil do begin
		it := it + TotalRepairableDamage( Part , Skill );
		Part := Part^.Next;
	end;

	{ Check the inv-components for damage. }
	Part := Target^.InvCom;
	while Part <> Nil do begin
		it := it + TotalRepairableDamage( Part , Skill );
		Part := Part^.Next;
	end;

	TotalRepairableDamage := it;
end;

Procedure ApplyRepairPoints( Target: GearPtr; Skill: Integer; var RP: LongInt );
	{ Search through TARGET, and restore DPs to parts }
	{ that can be repaired using SKILL. }
var
	Part: GearPtr;
	SD,AD,TCom,SCom,ARP,RPNeeded: LongInt;
	T: Integer;
begin
	{ Only examine TARGET for damage if it's of a type that can be }
	{ repaired using SKILL. }
	if RepairSkillNeeded( Target ) = Skill then begin
		{ Calculate structural damage and armor damage. }
		SD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_StrucDamage ) );
		if ( SD > 0 ) and ( RP > 0 ) then begin
			{ Modify for complexity. }
			ARP := RP;
			RPNeeded := SD;

			if not IsMasterGear( Target ) then begin
				TCom := ComponentComplexity( Target );
				SCom := SubComComplexity( Target );
				if SCom > TCom then begin
					RPNeeded := ( RPNeeded * SCom ) div TCom;
					ARP := ( ARP * TCom ) div SCom;
					if ARP < 1 then ARP := 1;
				end;
			end;

			SD := SD - ARP;
			RP := RP - RPNeeded;
			if SD < 0 then SD := 0;
			SetNAtt( Target^.NA , NAG_Damage , NAS_StrucDamage , SD );
		end;

		AD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_ArmorDamage ) );
		if ( AD > 0 ) and ( RP > 0 ) then begin
			{ Modify for complexity. }
			ARP := RP;
			RPNeeded := AD;

			if not IsMasterGear( Target ) then begin
				TCom := ComponentComplexity( Target );
				SCom := SubComComplexity( Target );
				if SCom > TCom then begin
					RPNeeded := ( RPNeeded * SCom ) div TCom;
					ARP := ( ARP * TCom ) div SCom;
					if ARP < 1 then ARP := 1;
				end;
			end;

			AD := AD - ARP;
			RP := RP - RPNeeded;
			if AD < 0 then AD := 0;
			SetNAtt( Target^.NA , NAG_Damage , NAS_ArmorDamage , AD );
		end;
	end;

	{ Check for status effects. }
	for t := 1 to Num_Status_FX do begin
		if ( SX_RepSkill[t] = Skill ) and ( NAttValue( Target^.NA , NAG_StatusEffect , T ) <> 0 ) then begin
			if RP >= SX_RepCost[ t ] then begin
				RP := RP - SX_RepCost[ t ];
				SetNAtt( Target^.NA , NAG_StatusEffect , T , 0 );
			end;
		end;
	end;

	{ Check the sub-components for damage. }
	Part := Target^.SubCom;
	while ( Part <> Nil ) and ( RP > 0 ) do begin
		ApplyRepairPoints( Part , Skill , RP );
		Part := Part^.Next;
	end;

	{ Check the inv-components for damage. }
	Part := Target^.InvCom;
	while ( Part <> Nil ) and ( RP > 0 ) do begin
		ApplyRepairPoints( Part , Skill , RP );
		Part := Part^.Next;
	end;
end;

Procedure ApplyEmergencyRepairPoints( Target: GearPtr; Skill: Integer; var RP: LongInt );
	{ Try to apply the repair points first to those parts of TARGET nessecary }
	{ for it to function. If there are any points left over, apply these to the rest. }
	Procedure ApplyPointsToPart( G,S: Integer );
		{ Locate a part with the Gear G and S descriptors provided, }
		{ and apply repair points to it first. }
	var
		Part: GearPtr;
	begin
		Part := SeekGear( Target , G , S , False );
		if ( Part <> Nil ) and ( RP > 0 ) then begin
			ApplyRepairPoints( Part, Skill, RP );
		end;
	end;
begin
	if Target^.G = GG_Character then begin
		ApplyPointsToPart( GG_Module , GS_Head );
		ApplyPointsToPart( GG_Module , GS_Body );
		if RP > 0 then ApplyRepairPoints( Target, Skill, RP );
	end else if Target^.G = GG_Mecha then begin
		ApplyPointsToPart( GG_Support , GS_Engine );
		ApplyPointsToPart( GG_Module , GS_Body );
		if RP > 0 then ApplyRepairPoints( Target, Skill, RP );
	end else ApplyRepairPoints( Target, Skill, RP );
end;

Function UseRepairSkill( GB: GameBoardPtr; PC,Target: GearPtr; Skill: Integer ): LongInt;
	{ The PC wants to use the requested repair SKILL on TARGET. }
	{ Roll to see how many DPs will be restored, apply these DPs }
	{ to the TARGET, then reduce PC's MPs. }
	Function Repair_Skill_Target: Integer;
		{ Return a good skill target for repair skills. }
		{ This will be decreased as TARGET's scale increases. }
	var
		RST: Integer;
	begin
		if Target^.Scale = 0 then begin
			if Skill = 16 then begin
				{ Medicine is more difficult than most. }
				RST := 10;
			end else begin
				RST := 5;
			end;
		end else if Target^.Scale = 1 then begin
			RST := 3;
		end else begin
			RST := 2;
		end;
		if Destroyed( Target ) then RST := RST + 5;
		Repair_Skill_Target := RST;
	end;
	Function SkillXPFactor: Integer;
		{ Return the factor by which repaired damage is converted }
		{ to experience. }
	begin
		if Skill = 16 then begin
			SkillXPFactor := 1;
		end else if Target^.Scale = 0 then begin
			SkillXPFactor := 3;
		end else begin
			SkillXPFactor := 10;
		end;
	end;
var
	tries,SkTar,RP,MaxRP,Leftover: LongInt;
	DP,DP0,TotalRepaired: LongInt;
begin
	{ Depending upon how much damage the target has, the PC can make }
	{ several repair attempts. }
	PC := LocatePilot( PC );
	if PC = Nil then Exit( 0 );

	if GB <> Nil then begin
		if not MoveLegal( GB^.Scene , FindRoot( PC ) , NAV_Stop , GB^.ComTime ) then Exit( 0 );
	end;

	tries := 0;
	DP := TotalRepairableDamage( Target , Skill );
	DP0 := DP;
	MaxRP := ( SkillRank( PC , Skill ) * ( Target^.Scale + 1 ) ) + 1;

	Leftover := 0;
	while ( tries < Repair_Max_Tries ) and ( DP > 0 ) and ( CurrentMental( PC ) > 0 ) do begin
		SkTar := Repair_Skill_Target;
		RP := SkillROll( GB , PC , Skill , SkTar , 0 , True , True );
		RP := RP - SkTar;
		if RP > MaxRP then begin
			RP := MaxRP;
			DoleSkillExperience( PC , Skill , XPA_SK_UseRepair );
		end;
		if RP > 0 then begin
			RP := RP + Leftover;
			ApplyRepairPoints( Target , Skill , RP );

			Leftover := RP;
		end else begin
			Leftover := 0;
		end;

		DoleSkillExperience( PC , Skill , XPA_SK_UseRepair );
		AddMentalDown( PC , Repair_Mental_Strain );
		Inc( Tries );
	end;

	{ Advance time by the required amount. }
	if HasTalent( PC , NAS_CombatMedic ) and (( Skill = 20 ) or ( Skill = 16 )) and ( not IsSafeArea( GB ) ) then begin
		WaitAMinute( GB , PC , ( ReactionTime( PC ) * Tries div 3 ) + 1 );
		AddStaminaDown( PC , Tries div 2 );
	end else begin
		WaitAMinute( GB , PC , ReactionTime( PC ) * Tries );
	end;

	TotalRepaired := DP0 - TotalRepairableDamage( Target, Skill );
	if TotalRepaired > 0 then DoleExperience( PC , TotalRepaired div SkillXPFactor );

	UseRepairSkill := DP0 - TotalRepairableDamage( Target, Skill );
end;

Procedure DoCompleteRepair( Target: GearPtr );
	{ Repair everything that can be repaired on Target. }
	{ Basically, go through all the repair skills and apply as many points }
	{ as are needed of each. }
var
	T: Integer;
	Pts: LongInt;
begin
	for t := 1 to NumSkill do begin
		if ( SkillMan[ T ].Usage = USAGE_Repair ) and ( TotalRepairableDamage( Target , T ) > 0 ) then begin
			Pts := TotalRepairableDamage( Target , T );
			ApplyRepairPoints( Target , T , Pts );
		end;
	end;
end;

Function UsePerformance( GB: GameBoardPtr; PC: GearPtr ): LongInt;
	{ The PC is about to use a performance skill. }
	{ As a result, the following things may happen: }
	{ - Earn money through tips. }
	{ - Set "APPLAUSE" triggers for positive reactions. }
	{ - Modify Morale up or down. }
	{ - Earn skill experience for performance. }
	{ - Lose Mental and Stamina from the act of playing. }
	{ Return -1 for a bad performance, 0 for a mediocre performance, }
	{ and a positive number if the PC made any tips. }
const
	PerformanceRange = 8;
var
	SkRoll,SkRank,Target,Penalty: Integer;	{ Skill roll target }
	N: Integer;		{ Number of successes }
	Cash: LongInt;
	M: GearPtr;
begin
	{ Reduce stamina and mental now. }
	{ Performing is both mentally and physically exhausting. }
	if Random( 2 ) = 1 then begin
		AddStaminaDown( PC , 1 );
	end else begin
		AddMentalDown( PC , 1 );
	end;

	{ Check through the audience. For the purpose of this game, }
	{ the audience counts as every nonhostile NPC within [UseRange] tiles. }
	N := 0;
	Cash := 0;

	M := GB^.Meks;
	while M <> Nil do begin
		{ If M is a character, not the PC, and is active, }
		{ and is not hostile towards the PC, and is in range, }
		{ check its reaction to the performance. }
		if ( M^.G = GG_Character ) and ( M <> PC ) and ( Range( GB , M , PC ) <= PerformanceRange ) and OnTheMap( GB , M ) and GearActive( M ) and ( not AreEnemies( GB , M , PC ) ) then begin
			{ Calculate the target number. }
			Target := CStat( M , STAT_Ego );
			Penalty := NAttValue( M^.NA , NAG_Personal , NAS_PerformancePenalty );
			if Target < 10 then Target := 10;

			SkRoll := SkillRoll( GB , PC , NAS_Performance , Target + Penalty , 0 , True , True );
			if SkRoll > ( Target + Penalty ) then begin
				Inc( N );
				if SkRoll > ( Target * 2 ) then Inc( N );
				if Random( 2 ) = 1 then AddNAtt( M^.NA , NAG_Personal , NAS_PerformancePenalty , 1 );
				SetTrigger( GB , TRIGGER_Applause );
			end else if ( SkRoll + PersonalityCompatability( PC , M ) ) < ( Target div 3 ) then begin
				Dec( N );
			end;
		end;

		M := M^.Next;
	end;

	{ If the PC earned any money from busking, add that here. }
	if ( N >= 2 ) then begin
		DoleExperience( PC , N div 2 );

		{ Modify N for a low reputation. }
		if NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned ) < 1 then Dec( N );
		Dec( N );
		if ( CurrentMental( PC ) > 0 ) and ( CurrentStamina( PC ) > 0 ) then begin
			SkRank := SkillRank( PC , NAS_Performance ) + 1;
			if N > SkRank then N := SkRank
			else if N < 1 then N := 1;
			Cash := SkillAdvCost( Nil , N ) div 10;
			AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cash );
		end;

	end else if ( N < 0 ) then begin
		{ The PC did pretty badly. }
		AddMoraleDmg( PC , Rollstep( 1 ) );
		Cash := -1;
	end;

	UsePerformance := Cash;
end;



end.
