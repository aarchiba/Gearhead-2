unit gamebook;
	{ This unit holds all the essential information needed to play the game: }
	{ the maps, the gear definitions, so on and so forth. }

{	Dungeon Monkey Unlimited, a tactics combat CRPG
	Copyright (C) 2010 Joseph Hewitt

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

	uses texutil,gears;

const
	MaxMapWidth = 200;

	POVSize = 30;	{ This should be big enough. }

	GG_Component = 0;
		STAT_Challenge = 1;

	{ *** MODEL DEFINITION *** }
	{ G = GG_Model }
	GG_Model = 1;
		{ S = Team }
		GS_Scenery = 0;
		GS_PCTeam = 1;
		GS_EnemyTeam = 2;
		GS_AllyTeam = 3;

		{ V = Activity }
		GV_Active = 1;
		GV_Inactive = 0;

		Num_Model_Stats = 6;
		STAT_Strength = 1;
		STAT_Toughness = 2;
		STAT_Reflexes = 3;
		STAT_Intelligence = 4;
		STAT_Piety = 5;
		STAT_Luck = 6;

	GG_Item = 2;
		{GS is the item type. }
		Num_Item_Types = 23;
		GS_Sword = 1;
		GS_Axe = 2;
		GS_Mace = 3;
		GS_Dagger = 4;
		GS_Staff = 5;
		GS_Bow = 6;
		GS_Polearm = 7;
		GS_Arrow = 8;
		GS_Shield = 9;
		GS_Sling = 10;
		GS_Bullet = 11;
		GS_Clothes = 12;
		GS_LightArmor = 13;
		GS_HeavyArmor = 14;
		GS_Hat = 15;
		GS_Helm = 16;
		GS_Glove = 17;
		GS_Gauntlet = 18;
		GS_Sandals = 19;
		GS_Shoes = 20;
		GS_Boots = 21;
		GS_Cloak = 22;
		GS_MonsterAttack = 23;

		GV_Identified = 0;
		GV_Unidentified = 1;

		{ N and D give damage as nDd, which will make perfect sense }
		{ if you've played a lot of DnD. }
		STAT_WeaponN = 1;
		STAT_WeaponD = 2;
		STAT_WeaponHands = 3;	{ If nonzero, this is a two-handed weapon. }
		STAT_WeaponRange = 4;	{ Can attack monsters Rng+1 away. Rng0 = melee only. }
		STAT_Quantity = 5;	{ Number of items/charges for stacks/etc. }
		STAT_WeaponElement = 6;	{ Generally Slicing, Piercing, or Bludgeoning. }

	GG_Effect = 3;	{ Effects describe spells, attacks, and whatnot. }
		{ GS defines the effect type. This will also determine the }
		{ meaning of the effect's stats. }
		{ The string attribute CAPTION is used to give the effect a }
		{ caption. For certain effects, the caption will be generated }
		{ automatically. }
		GS_DoNothing = 0;
			{ Remember Adventure Construction Set? ACS rocked. }
			{ This effect does nothing but add an animation/caption. }
		GS_AttackRoll = 1;
			{ An attack roll will be made, and success or failure }
			{ will follow. }
			STAT_AttackRoll_AtSkill = 1;	{ The attack skill to use. }
			STAT_AttackRoll_AtStat = 2;	{ The attack stat to use. }
			STAT_AttackRoll_AtBonus = 3;	{ Bonus to the attack roll. }
			STAT_AttackRoll_DefSkill = 4;	{ The defensive skill to use. }
			STAT_AttackRoll_DefStat = 5;	{ The defensive stat to use. }
		GS_HPDamage = 2;
			{ The target will lose HP, possibly dying. }
			STAT_HPDamage_DieN = 1;		{ The two dice stats use the same slots as weapons, }
			STAT_HPDamage_DieD = 2;		{ so they can both use the gearparser DAMAGE command. }
			STAT_HPDamage_DmgStat = 3;
			STAT_HPDamage_DmgBonus = 4;	{ A constant damage bonus. }
			STAT_HPDamage_Element = 6;
		GS_Healing = 3;
			GV_HealthRestore = 1;
			GV_MagicRestore = 2;
			GV_LuckRestore = 3;
			STAT_Healing_DieN = 1;		{ The two dice stats use the same slots as weapons, }
			STAT_Healing_DieD = 2;		{ so they can both use the gearparser DAMAGE command. }
			STAT_Healing_BonusStat = 3;
		GS_Summon = 4;
			SATT_Summon_Option = 'OPTION_';	{ Up to six options should be provided. }
		GS_Enchant = 5;
		GS_IfTarget = 6;		{ Checks the target's nature, returns TRUE if appropriate. }
			GV_IfTarget_IsAlly = 0;
			GV_IfTarget_IsEnemy = 1;
			GV_IfTarget_NAttGreater = 2;	{ True if target's NAtt greater than listed value. }
			GV_IfTarget_NAttNotEqual = 3;	{ True if target's NAtt not equal to listed value. }
			GV_IfTarget_IsAnimal = 4;
			GV_IfTarget_IsLiving = 5;
			GV_IfTarget_IsUnholy = 6;
			STAT_IfTarget_NAtt_G = 1;
			STAT_IfTarget_NAtt_S = 2;
			STAT_IfTarget_NAtt_V = 3;
		GS_LoseATurn = 7;	{ Target will be held for several turns. }
			STAT_LoseATurn_Duration = 1;	{ Max number of turns to lose. }
		GS_ChangeNAtt = 8;	{ Modify value of target's numeric attributes. }
			GV_SetNAtt = 1;
			GV_AddNAtt = 2;
			STAT_ChangeNAtt_G = 1;
			STAT_ChangeNAtt_S = 2;
			STAT_ChangeNAtt_V = 3;
		GS_Confusion = 9;	{ Target will be confused for several turns. }
			STAT_Confusion_Duration = 1;	{ Max number of turns to lose. }
		GS_Kill = 10;		{ Target dies. The end. }
		GS_PercentRoll = 11;
			{ Roll d100- if the comscore is equal or higher, it succeeds. }
			{ There's a penalty to the roll if the target is a higher }
			{ level than the caster. }
			STAT_PercentRoll_Skill = 1;	{ The attack skill to use. }
			STAT_PercentRoll_Stat = 2;	{ The attack stat to use. }
			STAT_PercentRoll_Bonus = 3;	{ Bonus to the attack roll. }


	GG_Scene = 4;	{ Scenes are descriptions of gameboards. }
		{ GS defines the scene ID number. }
		{ GV defines the map type. }
		GV_Maze = 0;
		GV_Cave = 1;
		GV_Wilderness = 2;
		{ Map features stored as subcoms. }
		STAT_MapWidth = 1;
		STAT_MapHeight = 2;
		STAT_FloorType = 3;

	GG_MapFeature = 5;	{ A Map Feature is a sub-feature of a scene. }
		{ I'm using the GearHead nomenclature to avoid confusing myself. }
		STAT_MF_XPos = 1;
		STAT_MF_YPos = 2;
		STAT_MF_Width = 3;
		STAT_MF_Height = 4;
		STAT_MF_Anchor = 5;	{ An anchored MF must be placed on an edge. }
			MFAnchor_North = 1;
			MFAnchor_East = 2;
			MFAnchor_South = 3;
			MFAnchor_West = 4;

	GG_CheckPoint = 6;	{ Used to indicate a tile, or special features thereof. }
		GS_EntryGrid = 1;	{ Party enters scene from GV here. }
		GS_WallPoint = 2;	{ Attaches to the wall. }

		{ A checkpoint can modify the terrain of the tile where it's placed. }
		STAT_CP_Floor = 1;
		STAT_CP_Wall = 2;
		STAT_CP_Decor = 3;

		{ For setting the destination of an exit or entrance. In the }
		{ design file, this will be set to an element number. It will }
		{ be converted to a real scene number by the adventure builder. }
		STAT_Destination = 8;

	GG_StoryContent = 7;	{ Used to construct a random adventure. }
		{ May be referred to in the comments as a "plot" or a "shard", }
		{ since I didn't revise them when copying from the other programs }
		{ from which the code was scavenged. }

	GG_Prop = 8;	{ A non-combatant, non-item visible thing on the map. }

		{ Stat 8 is STAT_Destination, same as for checkpoints. }

	GG_MetaScript = 9;	{ Part of the world-building toolkit. This gear }
		{ contains scripts which will be merged into the element indicated }
		{ by GS. }

	GG_Invocation = 10;	{ A special power that you can activate... }
		GS_Spell = 1;	{ ...for instance, a magic spell. }
			{ GV gives the level, from one to nine, of the incantation. }
			{ This is used for restricting spells and for calculating MP }
			{ costs. }

		STAT_Invocation_Range = 1;
			IRng_Unusable = -1;	{ Spell may not be used- generally for NonComRange. }
			IRng_Personal = 0;	{ Affects the invoker, or is centered upon invoker }
			IRng_Touch = 1;		{ Affects one character in melee range }
			IRng_Missile = 2;	{ Affects a tile within 10 squares }
			IRng_OnePC = 3;		{ May affect a single PC. }
			IRng_Identify = 4;	{ Unique spell range- targets an unidentified inventory item. }
		STAT_Invocation_Radius = 2;	{ Positive for blast radius, negative for donut. }
		STAT_Invocation_CostMod = 3;	{ Added to the regularly calculated MP cost. }
		STAT_Invocation_NonCombatRange = 4;	{ Range outside of combat may be different. }

	GG_Enchantment = 11;	{ A sticky effect which attaches to a model. }
		{ The effect condition: Enchantments may take an effect as a subcom. }
		{  This effect gets triggered under the condition specified here. }
		GS_ENCHANT_EveryRound = 0;	{ Effect happens once per round. }
		GS_ENCHANT_AttackMod = 1;	{ Effect gets added to enchantee's basic attack. }
		{ The duration: Combat, Daily, or Permanent }
		STAT_Enchantment_Duration = 1;
			EDUR_Inherent = -1;	{ May not be removed; a monster's natural abilities. }
			EDUR_CombatOnly = 0;
			EDUR_OneDay = 1;


	{  ********************  }
	{  ***   ELEMENTS   ***  }
	{  ********************  }
	Num_Elements = 13;
	ELEMENT_Slashing = 0;
	ELEMENT_Piercing = 1;
	ELEMENT_Crushing = 2;
	ELEMENT_Fire = 3;
	ELEMENT_Lightning = 4;
	ELEMENT_Frost = 5;
	ELEMENT_Lunar = 6;
	ELEMENT_Solar = 7;
	ELEMENT_Acid = 8;
	ELEMENT_Wind = 9;
	ELEMENT_Water = 10;
	ELEMENT_Atomic = 11;
	ELEMENT_Poison = 12;


	{  **************************  }
	{  ***   COMBAT  SCORES   ***  }
	{  **************************  }
	{ The equivalent of skills + whatnot from other games. These are calculated }
	{ dynamically because we live in the 21st century not in the 18th. }
	Num_Com_Score = 24;
	CS_PhysicalAttack = 1;
	CS_PhysicalDefense = 2;
	CS_MagicalAttack = 3;
	CS_MagicalDefense = 4;
	CS_DisarmTraps = 5;
	CS_Stealth = 6;
	CS_Resist_Slashing = 7;
	CS_Resist_Piercing = 8;
	CS_Resist_Crushing = 9;
	CS_Resist_Fire = 10;
	CS_Resist_Lightning = 11;
	CS_Resist_Frost = 12;
	CS_Resist_Lunar = 13;
	CS_Resist_Solar = 14;
	CS_Resist_Acid = 15;
	CS_Resist_Wind = 16;
	CS_Resist_Water = 17;
	CS_Resist_Atomic = 18;
	CS_Resist_Poison = 19;
	CS_TurnUndead = 20;
	CS_KungFu = 21;
	CS_NaturalArmor = 22;
	CS_CriticalHit = 23;
	CS_Awareness = 24;

	{ This array cross-references the element types with the relevant comscore. }
	Resist_X_ComScore: Array [ 0..Num_Elements-1 ] of Byte = (
		CS_Resist_Slashing,
		CS_Resist_Piercing, CS_Resist_Crushing, CS_Resist_Fire, CS_Resist_Lightning, CS_Resist_Frost,
		CS_Resist_Lunar, CS_Resist_Solar, CS_Resist_Acid, CS_Resist_Wind, CS_Resist_Water,
		CS_Resist_Atomic, CS_Resist_Poison
	);


	{  *************************  }
	{  ***   SPELL  COLORS   ***  }
	{  *************************  }
	Num_Spell_Colors = 6;
	SPELLC_Solar = 1;	{ Yellow }
	SPELLC_Earth = 2;	{ Orange }
	SPELLC_Water = 3;	{ Green }
	SPELLC_Fire = 4;	{ Red }
	SPELLC_Air = 5;		{ Blue }
	SPELLC_Lunar = 6;	{ Violet }


	{  ******************************  }
	{  ***   CHARACTER  CLASSES   ***  }
	{  ******************************  }
	Num_Classes = 16;
	CLASS_Warrior = 1;
	CLASS_Thief = 2;
	CLASS_Bard = 3;
	CLASS_Priest = 4;
	CLASS_Mage = 5;
	CLASS_Druid = 6;
	CLASS_M_Beast = 7;
	CLASS_M_Humanoid = 8;
	CLASS_M_Dragon = 9;
	CLASS_M_Defender = 10;
	CLASS_Knight = 11;
	CLASS_Ranger = 12;
	CLASS_Necromancer = 13;
	CLASS_Samurai = 14;
	CLASS_Monk = 15;
	CLASS_Ninja = 16;

	CLASS_HP_DIE: Array [1..Num_Classes] of integer = (
		12, 8, 6, 8, 4,
		6, 10, 8, 10, 12,
		10, 8, 4, 10, 8,
		10
	);
	CLASS_MP_DIE: Array [1..Num_Classes] of integer = (
		4, 6, 6, 8, 10,
		8, 6, 8, 10, 6,
		4, 6, 10, 6, 6,
		4
	);
	CLASS_SPELL_COLORS: Array [1..Num_Classes,1..Num_Spell_Colors] of Boolean = (
		( False, False, False, False, False, False ),	{ Warrior }
		( False, False, False, False, False, False ),	{ Thief }
		( False, False, False, False, True, False ),	{ Bard }
		( True, False, True, False, True, False ),	{ Priest }
		( False, False, False, True, True, True ),	{ Mage }
		( True, True, False, True, False, False ),	{ Druid }
		( False, False, False, False, False, False ),	{ Animal }
		( False, False, False, False, False, False ),	{ Humanoid }
		( False, False, False, False, False, False ),	{ Dragon }
		( False, False, False, False, False, False ),	{ Defender }
		( True, False, False, False, False, False ),	{ Knight }
		( False, True, False, False, False, False ),	{ Ranger }
		( False, True, True, False, False, True ),	{ Necromancer }
		( False, False, False, False, False, True ),	{ Samurai }
		( False, False, False, False, False, False ), 	{ Monk }
		( False, False, False, False, False, False )	{ Ninja }
	);


	{  ******************************  }
	{  ***   CHARACTER  SPECIES   ***  }
	{  ******************************  }
	Num_Species = 9;
	SPECIES_Human = 1;
	SPECIES_Dwarf = 2;
	SPECIES_Elf = 3;
	SPECIES_Gnome = 4;
	SPECIES_Orc = 5;
	SPECIES_Hurthling = 6;
	SPECIES_Fuzzy = 7;
	SPECIES_Reptal = 8;
	SPECIES_Centaur = 9;


	{  ********************  }
	{  ***   FACTIONS   ***  }
	{  ********************  }
	Num_Factions = 5;
	FAC_Dragon = 1;
	FAC_Nature = 2;
	FAC_Goblins = 3;
	FAC_Giants = 4;
	FAC_Chaos = 5;


	{  *******************************  }
	{  ***   NUMERIC  ATTRIBUTES   ***  }
	{  *******************************  }

	{ Characters need lots of data. Here it is. }
	NAG_CharacterData = 1;
		NAS_BaseHP = 1;
		NAS_BaseMP = 2;
		NAS_CurrentClass = 3;
		NAS_Gender = 4;
			NAV_Neuter = 0;	{ Monsters + Items get this. }
			NAV_Female = 1;
			NAV_Male = 2;
		NAS_Species = 5;
		NAS_Experience = 6;

	{ How many levels the character has gained in each class. }
	{ The S descriptor is the class ID, from above. }
	NAG_ClassLevels = 2;

	{ Fighting stats only apply while in combat mode, and are reset afterwards. }
	NAG_FightingStat = 3;
		NAS_ActionPointsSpent = 1;
		NAS_AttackPointsSpent = 2;
		NAS_LoseATurn = 3;
		NAS_Temporary = 4;	{ If nonzero, get deleted at end of combat. }
		NAS_Hidden = 5;		{ If nonzero, model is hidden. }
		NAS_Probed = 6;
		NAS_Silenced = 7;
		NAS_ShouldMitose = 8;	{ If nonzero, split this monster in two. }
		NAS_Confused = 9;

	NAG_Location = 4;
		NAS_X = 1;
		NAS_Y = 2;

	NAG_Damage = 5;
		NAS_HPDmg = 1;
		NAS_MPDmg = 2;
		NAS_LuckDmg = 3;

	NAG_Appearance = 6;
		NAS_Frame = 0;
		NAS_Avatar_Skin = 1;
		{ Base is determined by species + gender + this var. }
		NAS_Avatar_Hair = 2;
		NAS_Avatar_Beard = 3;
		{ Hair and beard are the frame plus one; a value of zero }
		{ indicates that this layer is inactive. }

	{ For models, tells how many spells they have access to. For spells, }
	{ tells how many slots they take up. }
	NAG_SpellGems = 7;
		{ The S descriptor is the spell color, as above. }

	NAG_ScriptVar = 8;

	NAG_ItemData = 9;
		{ Items need some data which can't be stored in the stats. }
		NAS_EquipSlot = 1;	{ V = Slot into which item is equipped. }
			Num_Equipment_Slots = 7;
			NAV_Hand1 = 1;
			NAV_Hand2 = 2;
			NAV_Body = 3;
			NAV_Head = 4;
			NAV_Arm = 5;
			NAV_Feet = 6;
			NAV_Back = 7;
		NAS_GPFudge = 2;	{ Modifier to GP value. }
		NAS_AvatarFrame = 3;	{ Frame to be used when this item equipped. }
		NAS_AvatarPants = 4;
		NAS_MaleBody = 5;	{ Alternate frames for Body layer of }
		NAS_MalePants = 6;	{ male characters. If nonzero, use alternate. }
		NAS_Mass = 7;		{ Mass, measured in half pounds. }

	NAG_EffectData = 10;
		NAS_AnimSequence = 1;
			Num_AnimSeq = 26;
			NAV_Anim_PhysicalHit = 1;
			NAV_Anim_PhysicalMiss = 2;
			NAV_Anim_BlueHit = 3;
			NAV_Anim_GreenHit = 4;
			NAV_Anim_BloodSpray = 5;
			NAV_Anim_LightningHit = 6;
			NAV_Anim_BlastHit = 7;
			NAV_Anim_GreenSplash = 8;
			NAV_Anim_SonicHit = 9;
			NAV_Anim_PinkHit = 10;
			NAV_Anim_YellowSparkle = 11;
			NAV_Anim_GreenSparkle = 12;
			NAV_Anim_BlueSparkle = 13;
			NAV_Anim_Healing = 14;
			NAV_Anim_Web = 15;
			NAV_Anim_YellowBang = 16;
			NAV_Anim_BlueBang = 17;
			NAV_Anim_GreenBang = 18;
			NAV_Anim_PurpleBang = 19;
			NAV_Anim_Shield = 20;
			NAV_Anim_OrangeSparkle = 21;
			NAV_Anim_PurpleSparkle = 22;
			NAV_Anim_RedSparkle = 23;
			NAV_Anim_Paralysis = 24;
			NAV_Anim_Confusion = 25;
			NAV_Anim_Critical = 26;
		NAS_ShotSequence = 2;
			Num_ShotSeq = 19;
			NAV_Shot_Arrow = 1;
			NAV_Shot_Bolt = 2;
			NAV_Shot_Stone = 13;
			NAV_Shot_Bullet = 14;
			NAV_Shot_Shuriken = 15;
			NAV_Shot_Cannonball = 18;
		NAS_AttackModSlot = 3;
			NAV_AMS_OnAttack = -1;
			NAV_AMS_OnHit = 0;
			NAV_AMS_OnMiss = 1;
			NAV_AMS_OnDamage = 2;
			NAV_AMS_OnKill = 3;

	NAG_ComScoreMod = 11;
		{ Anything which modifies a model's combat scores gets one of }
		{ these tags. The S descriptor is the ComScore value from above. }

	NAG_MonsterData = 12;	{ Monsters need some extra data which PCs don't. }
		NAS_MonsterActionPoints = 1;
		NAS_MonsterGP = 2;
		NAS_CanMitose = 3;	{ If struck by a bladed weapon, may split in two. }

	NAG_StoryData = 13;	{ Info about the story state/generation. }
		NAS_PlotXP = -1;	{ Total XP for all mobs, bosses created. }
		NAS_UniqueID = 0;
		NAS_DifficultyLevel = 1;
		NAS_Climate = 2;
			Num_Climate = 7;
			NAV_Forest = 1;
			NAV_Arctic = 2;
			NAV_Desert = 3;
			NAV_Jungle = 4;
			NAV_Grassland = 5;
			NAV_Wasteland = 6;
			NAV_Swamp = 7;
		NAS_ProppState = 3;
			NAV_P_AlteredWeather = 1;
		NAS_EnemyFaction = 4;
			{ See above for the faction constants. }
		NAS_ToBePlacedHere = 5;
			{ New items need to be placed somewhere. }
		NAS_SingleUse = 6;
			{ Marker for story components that can only be used once. }
		NAS_MobID = 7;
			{ Team identifier for monsters. }
		NAS_InventoryGenerator = 8;
			{ Automatically generate an inventory for this prefab thing. }
			NAV_GeneralStore = 1;
			NAV_SmallTreasure = 2;
			NAV_MediumTreasure = 3;
			NAV_LargeTreasure = 4;
		NAS_Setting = 9;

	NAG_ElementID = 14;	{ Element IDs for StoryContent gears. }
		Num_Plot_Elements = 8;	{ The max number of elements for one StoryContent shard. }

	NAG_SubPlotID = 15;	{ For storing the subplots generated by a plot. }

	NAG_SaveFileData = 16;	{ Needed for saving and loading the game. }
		NAS_PartySlot = 1;	{ Used for saving/restoring the game. }
		NAS_CurrentGB = 2;	{ The ID of the current gameboard. }

	NAG_CampaignData = 17;
		NAS_Gold = 1;
		NAS_FieldCampBonus = 2;	{ They gotta run out of monsters eventually... }

	NAG_DailyData = 18;	{ Cleared every night. }
		NAS_TurnAttempts = 1;

	NAG_Template = 19;	{ Modifications attached to a monster. }
		Num_Templates = 12;
		NAS_Undead = 1;
		NAS_Construct = 2;
		NAS_Plant = 3;
		NAS_Elemental = 4;
		NAS_Demon = 5;
		NAS_Bug = 6;
		NAS_Reptile = 7;
		NAS_Fire = 8;
		NAS_Water = 9;
		NAS_Earth = 10;
		NAS_Air = 11;
		NAS_Ice = 12;

	NAG_OkFor = 20;		{ Used for setting boolean values in a gear. }
		{ For instance, magical enhancements will use this value to store }
		{ which item types they can be applied to. }

	NAG_StatDrain = 21;	{ A special type of damage- lowers your stats semi-permanently. }


	{  ********************************  }
	{  ***   TERRAIN  DEFINITIONS   ***  }
	{  ********************************  }

	Num_Floor = 13;
		FLOOR_Grass = 1;
		FLOOR_Tile = 2;
		FLOOR_Water = 3;
		FLOOR_Stone = 4;
		FLOOR_Gravel = 5;
		FLOOR_Ice = 6;
		FLOOR_Snow = 7;
		FLOOR_Sand = 8;
		FLOOR_Cave = 9;
		FLOOR_Jungle = 10;
		FLOOR_Swamp = 11;
		FLOOR_Sewer = 12;
		FLOOR_Dungeon = 13;

		Floor_Blocks_Movement: Array [1..Num_Floor] of Boolean = (
			False, False, True, False, False,
			False, False, False, False, False,
			False, False, False
		);

	Num_Wall = 29;
		WALL_BasicWall = 1;
		WALL_ClosedDoor = 2;
		WALL_OpenDoor = 3;
		WALL_StairsUp = 4;
		WALL_StairsDown = 5;
		WALL_SpruceTree = 6;
		WALL_MapleTree = 7;
		WALL_DeadTree = 8;
		WALL_FallenTree = 9;
		WALL_PalmTree = 10;
		WALL_SandDune = 11;
		WALL_SnowDrift = 12;
		WALL_IcyPine = 13;
		WALL_IcyMaple = 14;
		WALL_Cactus = 15;
		WALL_TallTree = 16;
		WALL_Bush = 17;
		WALL_Hill = 18;
		WALL_SadTree = 19;
		WALL_Willow = 20;
		WALL_RockySpikes = 21;
		WALL_SandySpikes = 22;
		WALL_Boulder = 23;
		WALL_IcySpikes = 24;
		WALL_Mushrooms = 25;
		WALL_Cave = 26;
		WALL_Campfire = 27;
		WALL_BerryBush = 28;
		WALL_AppleTree = 29;

		Wall_Blocks_Movement: Array [0..Num_Wall] of Boolean = (
			False,
			True, True, False, True, True,
			True, True, True, True, True,
			True, True, True, True, True,
			True, True, True, True, True,
			True, True, True, True, True,
			True, True, True, True
		);
		Wall_Blocks_Vision: Array [0..Num_Wall] of Boolean = (
			False,
			True, True, False, True, True,
			False, False, False, False, False,
			False, False, False, False, False,
			False, False, False, False, False,
			False, False, False, False, False,
			True, False, False, False
		);

	Num_Decor = 12;
		DECOR_Skull = 1;
		DECOR_Bone = 2;
		DECOR_Skeleton = 3;
		DECOR_IcePuddle = 4;
		DECOR_MudPuddle = 5;
		DECOR_Portrait = 6;
		DECOR_SunSign = 7;
		DECOR_MoonSign = 8;
		DECOR_Landscape = 9;
		DECOR_Bookshelf = 10;
		DECOR_Message = 11;
		DECOR_Fireplace = 12;

	{  ********************************  }
	{  ***   ENCUMBERANCE  LEVELS   ***  }
	{  ********************************  }

	EL_None = 0;
	EL_Light = 1;
	EL_Heavy = 2;

	{  ************************************  }
	{  ***   MISCELLANEOUS  CONSTANTS   ***  }
	{  ************************************  }

	Num_Party_Members = 4;

	{This array holds the vector information for movement. The 9 directions}
	{correspond to the keys on the numeric keypad.}
	VecDir: Array [1..9,1..2] of Integer = (
	(-1, 1),( 0, 1),( 1, 1),
	(-1, 0),( 0, 0),( 1, 0),
	(-1,-1),( 0,-1),( 1,-1)
	);

	{ This array holds the eight vectors of GearHead. Useful for checking }
	{ every tile adjacent to a given one. Dir 0 is at three o'clock, for }
	{ no better reason than it's the same convention I've used in }
	{ other games. }
	AngDir: Array [0..7 , 1..2] of SmallInt = (
		(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1)
	);

	{ Command constants for loop/flow control. }
	CMD_Whatever = -1;	{ Used for commands we don't need to care about. }
	CMD_Quit = 1;
	CMD_Move = 2;


	TRIGGER_ModelEliminated = 'FAINT';
	TRIGGER_MobEliminated = 'MFAINT';
	TRIGGER_ModelActivated = 'ACT';
	TRIGGER_MobActivated = 'MACT';
	TRIGGER_Start = 'START';
	TRIGGER_UseProp = 'USE';

	{ Details about the story context descriptors. }
	Num_Context_Descriptors = 4;
	CDIndex: Array [ 1..Num_Context_Descriptors ] of integer = (
		NAS_ProppState, NAS_Climate, NAS_EnemyFaction, NAS_Setting
	);
	Context_Head: Array [ 1..Num_Context_Descriptors ] of Char = (
		'P', 'C', 'E', 'S'
	);

Type
	tile = Record
		floor,wall,decor: Byte;
		visible: Boolean;
	end;

	Location = Array of tile;

	Point = Record
		x,y: Integer;
	end;

	effect_stencil = Array [1..MaxMapWidth,1..MaxMapWidth] of Boolean;

	model_map = Array [1..MaxMapWidth,1..MaxMapWidth] of GearPtr;

	campaignptr = ^campaign;
	gameboardptr = ^gameboard;

	gameboard = Record
		ID: Integer;		{ Scene number. }
		map: Location;
		map_width,map_height: Byte;	{ Width and height of the map. }
		Scene: GearPtr; { A gear describing the scenario. }
		contents: GearPtr; {A list of all associated models.}
		camp: CampaignPtr;
		next: GameBoardPtr;
	end;

	campaign = Record
		source: GearPtr;	{ The adventure + scene gears. }
		boards: GameBoardPtr;	{ The associated gameboards. }
	end;

Var
	G_Triggers: SAttPtr;

	{ The following variables hold the state of the currently loaded }
	{ adventure. Apparently, at the time during which I wrote CombatQuest }
	{ and NovaCity I was going through some kind of infatuation with }
	{ global variables. Much of my work in combining these projects has }
	{ been de-globalizing a lot of stuff... these variables may well be }
	{ de-globalized themselves, in time. }

	G_Party: Array [1..Num_Party_Members] of GearPtr;

	{ To move between scenes, change this variable. }
	G_Destination: LongInt;

	{ The context tags are used for random world generation and picking }
	{ monsters for a scene. }
	Context_Tags: SAttPtr;


Function NewGameboard( Camp: CampaignPtr; ID: Integer; XMax,YMax: Byte ): GameBoardPtr;Function FindGameBoard( Camp: CampaignPtr; ID: Integer ): GameBoardPtr;
Function NewCampaign: CampaignPtr;
Procedure DisposeCampaign( Camp: CampaignPtr );

Function OnTheMap( GB: GameBoardPtr; X,Y: Integer ): Boolean;
Function OnTheMap( GB: GameBoardPtr; M: GearPtr ): Boolean;
Function FindModelXY( GB: GameBoardPtr; X,Y: Integer ): GearPtr;
Function FindCheckpointXY( GB: GameBoardPtr; X,Y: Integer ): GearPtr;

Function ItemMass( Item: GearPtr ): Integer;
Function InventoryMass( PC: GearPtr ): Integer;
Function EncumberanceCeiling( PC: GearPtr; EL: Integer ): Integer;
Function EncumberanceLevel( PC: GearPtr ): Integer;
Function CanTakeMoreItems( PC: GearPtr ): Boolean;

Function TotalLevel( M: GearPtr ): Integer;
Function AveragePCLevel: Integer;
Function CStat( M: GearPtr; Stat: Integer ): Integer;
Function MaxHP( M: GearPtr ): Integer;
Function MaxMP( M: GearPtr ): Integer;
Function CurrentHP( M: GearPtr ): Integer;
Function CurrentMP( M: GearPtr ): Integer;
Function IsAlright( M: GearPtr ): Boolean;
Function IsMasterGear( M: GearPtr ): Boolean;

Function IsFighting( GB: GameBoardPtr; M: GearPtr ): Boolean;
Function AreEnemies( M1,M2: GearPtr ): Boolean;

Function TileFloor( GB: GameBoardPtr; X,Y: Integer ): Integer;
Function TileWall( GB: GameBoardPtr; X,Y: Integer ): Integer;
Function TileDecor( GB: GameBoardPtr; X,Y: Integer ): Integer;
Function TileVisible( GB: GameBoardPtr; X,Y: Integer ): Boolean;
Procedure SetFloor( GB: GameBoardPtr; X,Y,Terr: Integer );
Procedure SetWall( GB: GameBoardPtr; X,Y,Terr: Integer );
Procedure SetDecor( GB: GameBoardPtr; X,Y,Terr: Integer );
Procedure SetVisibility( GB: GameBoardPtr; X,Y: Integer; V: Boolean );

Function ModelVisible( GB: GameBoardPtr; M: GearPtr ): Boolean;


Function TileBlocksMovement( GB: GameBoardPtr; X , Y : Integer ): Boolean;
Function TileBlocksVision( GB: GameBoardPtr; X , Y : Integer ): Boolean;

Function SolveLine(X1,Y1,X2,Y2,N: Integer): Point;
Function Range( X1 , Y1 , X2 , Y2: Integer ): Integer;
Function Range( M1,M2: GearPtr ): Integer;

Procedure Plot_Circular_Area( GB: GameBoardPtr; var Stencil: effect_stencil; X0,Y0,Rng: Integer );
Procedure UpdatePCPosition( GB: GameBoardPtr; PC: GearPtr );
Procedure Clear_Effect_Stencil( GB: GameBoardPtr; var S: effect_Stencil );
Procedure Calc_Invocation_Stencil( GB: GameBoardPtr; var S: effect_Stencil; I: GearPtr; X0,Y0: Integer );

Function IsIdentified( I: GearPtr ): Boolean;
Function GearName( Part: GearPtr ): String;
Function GearDesc( Part: GearPtr ): String;
function SeekGearByName( LList: GearPtr; Name: String ): GearPtr;

Procedure AddTrigger( Base: String; V: Integer );

Procedure FloorFill( GB: GameBoardPtr; X1,Y1,X2,Y2,Terrain: Integer );
Procedure WallFill( GB: GameBoardPtr; X1,Y1,X2,Y2,Terrain: Integer );
Procedure VisibilityFill( GB: GameBoardPtr; X1,Y1,X2,Y2: Integer; Vis: Boolean );

Function FirstAlrightPCIndex( GB: GameBoardPtr ): Integer;
Function NextAlrightPCIndex( GB: GameBoardPtr; PN: Integer; MoveForward: Boolean ): Integer;
Function FirstActivePC( GB: GameBoardPtr ): GearPtr;
Function RandomPC( GB: GameBoardPtr ): GearPtr;
Function Party_Dead: Boolean;
Function Should_Exit_Scene: Boolean;

Function FindPointNearModel( GB: GameBoardPtr; PC: GearPtr ): Point;
Function FindPointNearParty( GB: GameBoardPtr ): Point;

Procedure ActivateModel( GB: GameBoardPtr; M0: GearPtr );

Function CanJoinClass( PC: GearPtr; C: Integer ): Boolean;
Procedure ApplyClassLevel( PC: GearPtr; C: Integer );
Procedure AddClassLevel( PC: GearPtr; C: Integer );
Function XPNeededForNextLevel( PC: GearPtr ): LongInt;

Function FindEquippedItem( PC: GearPtr; Slot: Integer ): GearPtr;
Function BaseComScore( PC: GearPtr; CS: Integer ): Integer;
Function ComScore( PC: GearPtr; CS: Integer ): Integer;
Function StatBonus( PC: GearPtr; Stat: Integer ): Integer;
Function DamageBonus( PC: GearPtr; Stat: Integer ): Integer;
Function ActionPoints( PC: GearPtr ): Integer;
Function BestPhysicalDefense( PC: GearPtr ): Integer;

Procedure WriteCampaign( Camp: CampaignPtr; var F: Text );
Function ReadCampaign( var F: Text ): CampaignPtr;

Function PlotContext( Plot: GearPtr ): String;
Function GearContextTags( Part: GearPtr; const c_head: String ): String;

Function SpellGemsOfColor( PC: GearPtr; Color: Integer ): Integer;
Function SpellGemsRequired( Spell: GearPtr; Color: Integer ): Integer;
Function TotalSpellGems( PC: GearPtr ): Integer;
Function SpellGemsUsed( PC: GearPtr; Color: Integer ): Integer;
Function FreeSpellGems( PC: GearPtr; Color: Integer ): Integer;
Function TotalFreeSpellGems( PC: GearPtr ): Integer;
Function MPRequired( Spell: GearPtr ): Integer;

Function GPValue( I_Master: GearPtr ): LongInt;

Function TurningAttemptsPerDay( PC: GearPtr ): Integer;

Function ModelIsAnimal( M: GearPtr ): Boolean;
Function ModelIsLiving( M: GearPtr ): Boolean;
Function ModelIsUnholy( M: GearPtr ): Boolean;
Function ModelHasBrain( M: GearPtr ): Boolean;


implementation

uses uiconfig;

Function LastGameBoard( LList: GameBoardPtr ): GameBoardPtr;
	{ Find the last GameBoard in this particular list. }
begin
	if LList <> Nil then while LList^.Next <> Nil do LList := LList^.Next;

	LastGameBoard := LList;
end;

Function FindGameBoard( Camp: CampaignPtr; ID: Integer ): GameBoardPtr;
	{ Locate the game board with the requested ID. }
	{ If no such board is found, return Nil. }
var
	LList,it: GameBoardPtr;
begin
	{Initialize it to Nil.}
	it := Nil;

	{Loop through all the boards.}
	LList := Camp^.Boards;
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if ( LList^.ID = ID ) then it := LList;
		LList := LList^.Next;
	end;

	{Return the value.}
	FindGameBoard := it;
end;

Function NewGameboard( Camp: CampaignPtr; ID: Integer; XMax,YMax: Byte ): GameBoardPtr;
	{Allocate and initialize a new GameBoard structure.}
var
	it: GameBoardPtr;
	X: Integer;
begin
	{Allocate the needed memory space.}
	New(it);

	if it <> Nil then begin
		it^.ID := ID;
		it^.Contents := Nil;
		it^.Scene := Nil;
		it^.MAP_Width := XMax;
		it^.MAP_Height := YMax;
		it^.Camp := Camp;
		it^.Next := Nil;

		if Camp^.Boards = Nil then begin
			Camp^.Boards := it;
		end else begin
			LastGameBoard( Camp^.Boards )^.Next := it;
		end;

		SetLength( it^.map , XMax * YMax );
		for X := 0 to ( Length( it^.Map ) - 1 ) do begin
			it^.map[X].floor := 1;
			it^.map[X].wall := 0;
			it^.map[X].decor := 0;
			it^.map[X].visible := False;
		end;
	end;
	NewGameboard := it;
end;

Procedure DisposeGameboards( var LList: GameBoardPtr );
	{ Get rid of all the GameBoards in this list. }
	{ NOTE: Any content still attached will be lost as well!!! }
var
	LTemp: GameBoardPtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;
		DisposeGear( LList^.Contents );
		Dispose(LList);
		LList := LTemp;
	end;
end;

Function NewCampaign: CampaignPtr;
	{ Create and initialize a new campaign record. }
var
	it: CampaignPtr;
begin
	New( it );
	it^.Source := Nil;
	it^.Boards := Nil;
	NewCampaign := it;
end;

Procedure DisposeCampaign( Camp: CampaignPtr );
	{ Dispose of this campaign and all associated content. }
begin
	DisposeGear( Camp^.Source );
	DisposeGameBoards( Camp^.Boards );
	Dispose( Camp );
end;

Function OnTheMap( GB: GameBoardPtr; X,Y: Integer ): Boolean;
	{ Return TRUE if this point is on the map, FALSE otherwise. }
begin
	OnTheMap := ( X >= 1 ) and ( Y >= 1 ) and ( X <= GB^.map_width ) and ( Y <= GB^.map_height );
end;

Function OnTheMap( GB: GameBoardPtr; M: GearPtr ): Boolean;
	{ Return TRUE if this model is on the map, FALSE otherwise. }
begin
	OnTheMap := ( M <> Nil ) and OnTheMap( GB , NAttValue( M^.NA , NAG_Location , NAS_X ) , NAttValue( M^.NA , NAG_Location , NAS_Y ) );
end;

Function FindModelXY( GB: GameBoardPtr; X,Y: Integer ): GearPtr;
	{ Locate a monster in tile X,Y. }
var
	M: GearPtr;
begin
	M := GB^.Contents;
	while ( M <> Nil ) do begin
		if IsMasterGear( M ) and ( NAttValue( M^.NA , NAG_Location , NAS_X ) = X ) and ( NAttValue( M^.NA , NAG_Location , NAS_Y ) = Y ) then begin
			Break;
		end;
		M := M^.Next;
	end;
	FindModelXY := M;
end;

Function FindCheckpointXY( GB: GameBoardPtr; X,Y: Integer ): GearPtr;
	{ Locate a checkpoint in tile X,Y. }
var
	M: GearPtr;
begin
	M := GB^.Contents;
	while ( M <> Nil ) do begin
		if ( M^.G = GG_CheckPoint ) and ( NAttValue( M^.NA , NAG_Location , NAS_X ) = X ) and ( NAttValue( M^.NA , NAG_Location , NAS_Y ) = Y ) then begin
			Break;
		end;
		M := M^.Next;
	end;
	FindCheckpointXY := M;
end;

Function ItemMass( Item: GearPtr ): Integer;
	{ Return the mass of this item. }
var
	mass: Integer;
begin
	mass := NAttValue( Item^.NA , NAG_ItemData , NAS_Mass );
	if mass < 1 then mass := 1;
	ItemMass := Mass;
end;

Function InventoryMass( PC: GearPtr ): Integer;
	{ Return the total mass of all the items the PC is carrying. }
var
	I: GearPtr;
	mass: Integer;
begin
	mass := 0;
	I := PC^.InvCom;
	while I <> Nil do begin
		mass := mass + ItemMass( I );
		I := I^.next;
	end;
	InventoryMass := mass;
end;

Function EncumberanceCeiling( PC: GearPtr; EL: Integer ): Integer;
	{ Return the maximum amount of weight the PC can carry. }
var
	Strength: Integer;
begin
	Strength := CSTat( PC , STAT_Strength );
	case EL of
		EL_None:	Strength := Strength * 6;
		EL_Light:	Strength := Strength * 12;
		EL_Heavy:	Strength := Strength * 20;
	end;
	EncumberanceCeiling := Strength;
end;

Function EncumberanceLevel( PC: GearPtr ): Integer;
	{ Return the PC's encumberance level. }
var
	mass: Integer;
begin
	mass := InventoryMass( PC );
	if mass < EncumberanceCeiling( PC , EL_None ) then EncumberanceLevel := EL_None
	else if mass < EncumberanceCeiling( PC , EL_Light ) then EncumberanceLevel := EL_Light
	else EncumberanceLevel := EL_Heavy;
end;

Function CanTakeMoreItems( PC: GearPtr ): Boolean;
	{ Return TRUE if the PC's carried mass hasn't yet exceeded the HEAVY }
	{ limit. }
begin
	if PC^.G <> GG_Model then Exit( True );
	CanTakeMoreItems := InventoryMass( PC ) < EncumberanceCeiling( PC , EL_Heavy );
end;

Function TotalLevel( M: GearPtr ): Integer;
	{ Add up all of the model's class levels to reveal the total level. }
var
	it,t: Integer;
begin
	it := 0;
	for t := 1 to Num_Classes do begin
		it := it + NAttValue( M^.NA , NAG_ClassLevels , T );
	end;
	TotalLevel := it;
end;

Function AveragePCLevel: Integer;
	{ Return the average level of the party, counting dead and nonexistent }
	{ members as zero. }
var
	Total,T: Integer;
begin
	Total := 0;
	for t := 1 to Num_Party_Members do if ( G_Party[ t ] <> Nil ) and IsAlright( G_Party[ t ] ) then Total := Total + TotalLevel( G_Party[ t ] );
	if Total < Num_Party_Members then Total := Num_Party_Members;
	AveragePCLevel := Total div Num_Party_Members;
end;

Function CStat( M: GearPtr; Stat: Integer ): Integer;
	{ Calculate this model's true stat rating, given both the natural value }
	{ plus any bonuses from powers. }
var
	it: Integer;
begin
	{ Begin with an error check. }
	if ( M = Nil ) or ( Stat < 1 ) or ( Stat > Num_Model_Stats ) then Exit( 0 );

	it := M^.Stat[ Stat ] - NAttValue( M^.NA , NAG_StatDrain , Stat );
	if it < 1 then it := 1;

	CStat := it;
end;

Function MaxHP( M: GearPtr ): Integer;
	{ Return the max HP value of this model. That's health points, for those }
	{ keeping track. }
var
	it,bonus_stat: Integer;
begin
	if M = Nil then Exit( 0 );

	{ Start with the basic recorded value. }
	it := NAttValue( M^.NA , NAG_CharacterData , NAS_BaseHP );

	{ May get a bonus based on a certain stat times the model's level. }
	bonus_stat := CStat( M , STAT_Toughness );
	if bonus_stat > 10 then it := it + ( ( bonus_stat - 10 ) * TotalLevel( M ) ) div 2;
	MaxHP := it;
end;

Function MaxMP( M: GearPtr ): Integer;
	{ Return the max MP value of this model. That's mana points, for those }
	{ keeping track. }
var
	it,bonus_stat: Integer;
begin
	if M = Nil then Exit( 0 );

	{ Start with the basic recorded value. }
	it := NAttValue( M^.NA , NAG_CharacterData , NAS_BaseMP );

	{ May get a bonus based on a certain stat times the model's level. }
	bonus_stat := CStat( M , STAT_Piety );
	if bonus_stat > 10 then it := it + ( ( bonus_stat - 10 ) * TotalLevel( M ) ) div 2;
	MaxMP := it;
end;

Function CurrentHP( M: GearPtr ): Integer;
	{ Return this model's current HP total. }
begin
	CurrentHP := MaxHP( M ) - NAttValue( M^.NA , NAG_Damage , NAS_HPDmg );
end;

Function CurrentMP( M: GearPtr ): Integer;
	{ Return this model's current MP total. }
begin
	CurrentMP := MaxMP( M ) - NAttValue( M^.NA , NAG_Damage , NAS_MPDmg );
end;

Function IsAlright( M: GearPtr ): Boolean;
	{ Return TRUE if M is alright, or FALSE if M is disabled. }
begin
	IsAlright := ( M <> Nil ) and ( MaxHP( M ) > NAttValue( M^.NA , NAG_Damage , NAS_HPDmg ) );
end;

Function IsMasterGear( M: GearPtr ): Boolean;
	{ Return TRUE if M is a gear which occupies a map tile, can be seen, }
	{ and directly interacted with. }
begin
	IsMasterGear := ( M <> Nil ) and ( ( M^.G = GG_Model ) or ( M^.G = GG_Prop ) );
end;

Function IsFighting( GB: GameBoardPtr; M: GearPtr ): Boolean;
	{ Return TRUE if M is actively fighting, or FALSE if M is just standing there. }
begin
	IsFighting := IsAlright( M ) and OnTheMap( GB , M ) and ( M^.G = GG_Model ) and ( M^.S = GS_EnemyTeam ) and ( M^.V = GV_Active );
end;

Function AreEnemies( M1,M2: GearPtr ): Boolean;
	{ Return TRUE if M1 and M2 are enemies, or FALSE otherwise. }
begin
	if ( M1 = Nil ) or ( M2 = Nil ) then begin
		AreEnemies := False;
	end else if ( M1^.S = GS_Scenery ) or ( M2^.S = GS_Scenery ) then begin
		{ Nobody is enemies with scenery. }
		AreEnemies := False;
	end else if M1^.S = GS_EnemyTeam then begin
		AreEnemies := M2^.S <> GS_EnemyTeam;
	end else begin
		AreEnemies := M2^.S = GS_EnemyTeam;
	end;
end;

Function TileIndex( GB: GameBoardPtr; X,Y: Integer ): LongInt;
	{ Given tile X,Y on GB, tell what array index position the tile will be at. }
begin
	TileIndex := X + ( Y - 1 ) * GB^.Map_Width - 1;
end;

Function TileFloor( GB: GameBoardPtr; X,Y: Integer ): Integer;
	{ Return the floor type found at tile X,Y of the provided map. }
	{ The default return value is 1; every tile must have a floor }
	{ type defined. }
var
	T: Integer;
begin
	if OnTheMap( GB , X , Y ) then begin
		T := GB^.Map[ TileIndex( GB , X , Y ) ].floor;
		if ( T < 1 ) or ( T > Num_Floor ) then T := 1;
		TileFloor := T;
	end else begin
		TileFloor := 1;
	end;
end;

Function TileWall( GB: GameBoardPtr; X,Y: Integer ): Integer;
	{ Return the wall type found at tile X,Y of the provided map. }
	{ The default return value is 0, aka no wall present. }
var
	T: Integer;
begin
	if OnTheMap( GB , X , Y ) then begin
		T := GB^.Map[ TileIndex( GB , X , Y ) ].wall;
		if ( T < 0 ) or ( T > Num_Wall ) then T := 0;
		TileWall := T;
	end else begin
		TileWall := 0;
	end;
end;

Function TileDecor( GB: GameBoardPtr; X,Y: Integer ): Integer;
	{ Return the decor type found at tile X,Y of the provided map. }
	{ The default return value is 0, aka no decor present. }
var
	T: Integer;
begin
	if OnTheMap( GB , X , Y ) then begin
		T := GB^.Map[ TileIndex( GB , X , Y ) ].decor;
		if ( T < 0 ) or ( T > Num_Decor ) then T := 0;
		TileDecor := T;
	end else begin
		TileDecor := 0;
	end;
end;

Function TileVisible( GB: GameBoardPtr; X,Y: Integer ): Boolean;
	{ Return the visibility flag of the requested tile. }
begin
	if OnTheMap( GB , X , Y ) then begin
		TileVisible := GB^.Map[ TileIndex( GB , X , Y ) ].visible;
	end else begin
		TileVisible := False;
	end;
end;

Procedure SetFloor( GB: GameBoardPtr; X,Y,Terr: Integer );
	{ Set the terrain for the requested map tile, if it lies within the bounds of the map. }
begin
	if OnTheMap( GB , X , Y ) then begin
		GB^.Map[ TileIndex( GB , X , Y ) ].floor := Terr;
	end;
end;

Procedure SetWall( GB: GameBoardPtr; X,Y,Terr: Integer );
	{ Set the terrain for the requested map tile, if it lies within the bounds of the map. }
begin
	if OnTheMap( GB , X , Y ) then begin
		GB^.Map[ TileIndex( GB , X , Y ) ].wall := Terr;
	end;
end;

Procedure SetDecor( GB: GameBoardPtr; X,Y,Terr: Integer );
	{ Set the terrain for the requested map tile, if it lies within the bounds of the map. }
begin
	if OnTheMap( GB , X , Y ) then begin
		GB^.Map[ TileIndex( GB , X , Y ) ].decor := Terr;
	end;
end;

Procedure SetVisibility( GB: GameBoardPtr; X,Y: Integer; V: Boolean );
	{ Set the visibility for the requested map tile, if it lies within the bounds of the map. }
begin
	if OnTheMap( GB , X , Y ) then begin
		GB^.Map[ TileIndex( GB , X , Y ) ].Visible := V;
	end;
end;

Function ModelVisible( GB: GameBoardPtr; M: GearPtr ): Boolean;
	{ Return TRUE if this model is visible, or FALSE otherwise. }
begin
	ModelVisible := True;
end;

Function TileBlocksMovement( GB: GameBoardPtr; X , Y : Integer ): Boolean;
	{ Return TRUE if X,Y contains blocking terrain. }
	{ Note that this function specifically does not check for blocking }
	{ models. }
begin
	TileBlocksMovement := ( not OnTheMap( GB , X , Y ) ) or Wall_Blocks_Movement[ TileWall( GB , X , Y ) ] or Floor_Blocks_Movement[ TileFloor( GB , X , Y ) ];
end;

Function TileBlocksVision( GB: GameBoardPtr; X , Y : Integer ): Boolean;
	{ Return TRUE if this tile blocks vision, or FALSE if you can see }
	{ through it. }
begin
	TileBlocksVision := ( not OnTheMap( GB , X , Y ) ) or Wall_Blocks_Vision[ TileWall( GB , X , Y ) ];
end;


Function SolveLine(X1,Y1,X2,Y2,N: Integer): Point;
	{Find the N'th point along a line starting at X1,Y1 and ending}
	{at X2,Y2. Return its location.}
var
	tmp: point;
	VX1,VY1,VX,VY: Integer;
	Rise,Run: Integer; {Rise and Run}
begin
	{ERROR CHECK- Solve the trivial case.}
	if (X1=X2) and (Y1=Y2) then begin
		tmp.x := X1;
		tmp.y := Y1;
		Exit(tmp);
	end;

	{For line determinations, we'll use a virtual grid where each game}
	{tile is a square 10 units across. Calculations are done from the}
	{center of each square.}
	VX1 := X1*10 + 5;
	VY1 := Y1*10 + 5;

	{Do the slope calculations.}
	Rise := Y2 - Y1;
	Run := X2 - X1;

	if Abs(X2 - X1)> Abs(Y2 - Y1) then begin
		{The X direction is longer than the Y axis.}
		{Therefore, we can infer X pretty easily, then}
		{solve the equation for Y.}
		{Determine our X value.}
		if Run > 0 then VX := (n*10) + VX1
		else VX := VX1 - n*10;

		VY := n*10*Rise div Abs(Run) + VY1;

		end
	else begin
		{The Y axis is longer.}
		if Rise > 0 then VY := (n*10) + VY1
		else VY := VY1 - n*10;

		VX := (n*10*Run div Abs(Rise)) + VX1;

	end;

	{Error check- DIV doesn't deal with negative numbers as I would}
	{want it to. I'd always like a positive remainder- so, let's modify}
	{the values.}
	if VX<0 then VX := VX - 10;
	if VY<0 then VY := VY - 10;

	tmp.x := VX div 10;
	tmp.y := VY div 10;
	SolveLine := tmp;
end;

Function Range( X1 , Y1 , X2 , Y2: Integer ): Integer;
	{Calculate the range between X1,Y1 and X2,Y2.}
begin
	{Pythagorean theorem.}
	Range := Round(Sqrt(Sqr(X2 - X1) + Sqr(Y2 - Y1)));
end;

Function Range( M1,M2: GearPtr ): Integer;
	{ Calculate the distance between M1 and M2. }
var
	X1,Y1,X2,Y2: Integer;
begin
	X1 := NAttValue( M1^.NA , NAG_Location , NAS_X );
	Y1 := NAttValue( M1^.NA , NAG_Location , NAS_Y );
	X2 := NAttValue( M2^.NA , NAG_Location , NAS_X );
	Y2 := NAttValue( M2^.NA , NAG_Location , NAS_Y );
	Range := Range( X1 , Y1 , X2 , Y2 );
end;

Procedure Switch( var A,B: Integer );
	{ Swap the values of the two vars passed. }
var
	tmp: Integer;
begin
	tmp := A;
	A := B;
	B := tmp;
end;

Procedure FloorFill( GB: GameBoardPtr; X1,Y1,X2,Y2,Terrain: Integer );
	{ Fill the specified area of the map with the specified terrain. }
var
	X,Y: Integer;
begin
	if X1 > X2 then Switch( X1 , X2 );
	if Y1 > Y2 then Switch( Y1 , Y2 );
	for X := X1 to X2 do begin
		for Y := Y1 to Y2 do begin
			SetFloor( GB , X , Y , Terrain );
		end;
	end;
end;

Procedure WallFill( GB: GameBoardPtr; X1,Y1,X2,Y2,Terrain: Integer );
	{ Fill the specified area of the map with the specified terrain. }
var
	X,Y: Integer;
begin
	if X1 > X2 then Switch( X1 , X2 );
	if Y1 > Y2 then Switch( Y1 , Y2 );
	for X := X1 to X2 do begin
		for Y := Y1 to Y2 do begin
			SetWall( GB , X , Y , Terrain );
		end;
	end;
end;

Procedure VisibilityFill( GB: GameBoardPtr; X1,Y1,X2,Y2: Integer; Vis: Boolean );
	{ Fill the specified area of the map with the specified visibility. }
var
	X,Y: Integer;
begin
	for X := X1 to X2 do begin
		for Y := Y1 to Y2 do begin
			SetVisibility( GB , X , Y , Vis );
		end;
	end;
end;


Procedure Plot_Circular_Area( GB: GameBoardPtr; var Stencil: effect_stencil; X0,Y0,Rng: Integer );
	{ Draw a circular area of the requested radius at the requested spot. }
	{ Store the results in the provided stencil. This procedure will be used }
	{ for LOS as well as for blast attacks. }
const
	UPV_True = 1;
	UPV_False = -1;
	UPV_Maybe = 0;
var
	temp: Array [-POVSize..POVSize,-POVSize..POVSize] of integer;
	SceneryPresent: effect_stencil;	{ Scenery present? }
	x,y: Integer;

	Procedure InitSceneryPresent;
		{ Initialize the array which tells whether or not there's any metaterrain }
		{ present on the map. }
	var
		M: GearPtr;
		TX,TY: Integer;
	begin
		{ Initialize all tiles to FALSE. }
		for TX := 1 to GB^.map_width do for TY := 1 to GB^.map_height do SceneryPresent[ TX , TY ] := False;

		{ Add all metaterrain models. }
		M := GB^.Contents;
		while M <> Nil do begin
			if ( M^.G = GG_Model ) and ( M^.S = GS_Scenery ) then begin
				TX := NAttValue( M^.NA , NAG_Location , NAS_X );
				TY := NAttValue( M^.NA , NAG_Location , NAS_Y );
				if OnTheMap( GB , TX , TY ) then SceneryPresent[ TX , TY ] := True;
			end;
			M := M^.Next;
		end;
	end;

	Function TileBlocksLOS( TX,TY: Integer ): Boolean;
		{ Return TRUE if tile TX,TY blocks LOS, or FALSE otherwise. }
	begin
		TileBlocksLOS := TileBlocksVision( GB , TX , TY ) or SceneryPresent[ TX , TY ];
	end;

	Procedure CheckLine(XT,YT: Integer);
	var
		t: Integer;	{A counter, and a terrain type.}
		Wall: Boolean;	{Have we hit a wall yet?}
		p: Point;
	begin
		{Check every point on the line from the origin to XT,YT,}
		{recording the results in the Temp array.}

		{The variable WALL represents a boundary that cannot be seen through.}
		Wall := false;

		for t := 1 to Rng do begin
			{Locate the next point on the line.}
			p := SolveLine(0,0,XT,YT,t);

			{If we have already encountered a wall, mark this square as UPV_False}
			if Wall then temp[p.x,p.y] := UPV_False;

			Case temp[p.x,p.y] of
				UPV_False: Break; {This LoS is blocked. No use searching any further.}
				UPV_Maybe: begin  {We will mark this one as true, but check for a wall later.}
					temp[p.x,p.y] := UPV_True;
					end;
				{If we got a UPV_True, we just skip merrily along without doing anything.}
			end;

			{If this current square is a wall,}
			{set Wall to true.}
			if TileBlocksLOS( X0 + P.X , Y0 + P.Y ) then Wall := True;
		end;
	end;

	Procedure FillOutCardinals( D: Integer );
		{ Travel along direction D. If the tile is set to UPV_True, }
		{ then set the two adjacent tiles to UPV_True as well. }
	var
		t: Integer;
	begin
		for t := 1 to POVSize do begin
			if temp[ 0 + VecDir[D,1]*T , 0 + VecDir[D,2]*t ] = UPV_True then begin
				temp[ 0 + VecDir[D,1]*T + VecDir[D,2] , 0 + VecDir[D,2]*t + VecDir[D,1] ] := UPV_True;
				temp[ 0 + VecDir[D,1]*T - VecDir[D,2] , 0 + VecDir[D,2]*t - VecDir[D,1] ] := UPV_True;
			end;
		end;
	end;

begin
	{Error Check- make sure that the range is a legal value.}
	if Rng > POVsize then Rng := POVsize
	else if Rng < 1 then Rng := 1;

	{ Initialize the MetaTerrain array }
	InitSceneryPresent;

	{Set every square in the temp array to Maybe.}
	for x := -POVSize to POVSize do
		for y := -POVSize to POVSize do
			temp[x,y] := UPV_Maybe;

	{Set the origin to True.}
	temp[0,0] := UPV_True;

	{Check the 4 cardinal directions}
	CheckLine(0,Rng);
	CheckLine(0,-Rng);
	CheckLine(Rng,0);
	CheckLine(-Rng,0);

	{Check the 4 diagonal directions}
	CheckLine(Rng,Rng);
	CheckLine(Rng,-Rng);
	CheckLine(-Rng,Rng);
	CheckLine(-Rng,-Rng);

	For X := -Rng + 1 to -1 do begin
		Checkline(X,-Rng);
		CheckLine(X,Rng);
	end;

	For X := Rng -1 downto 1 do begin
		Checkline(X,-Rng);
		CheckLine(X,Rng);
	end;


	For Y := -Rng + 1 to -1 do begin
		Checkline(Rng,Y);
		CheckLine(-Rng,Y);
	end;

	For Y := Rng - 1 downto 1 do begin
		CheckLine(Rng,Y);
		CheckLine(-Rng,Y);
	end;

	FillOutCardinals( 8 );
	FillOutCardinals( 6 );
	FillOutCardinals( 2 );
	FillOutCardinals( 4 );

	{Copy the results from temp to the actual LOS array.}

	{ Initialize the stencil to all FALSE. }
	for x := 1 to GB^.map_width do for Y := 1 to GB^.map_height do Stencil[ X , Y ] := False;

	{ Next, copy our LOS results. }
	for x := -POVSize to POVSize do
		for y := -POVSize to POVSize do
			if ( temp[x,y] = UPV_True ) and OnTheMap( GB , X0 + X , Y0 + Y ) and ( Range( X0 + X , Y0 + Y , X0 , Y0 ) <= Rng ) then begin
				Stencil[ X0 + X , Y0 + Y ] := True;
			end;
end;

Procedure UpdateVisibleArea( GB: GameBoardPtr; X0,Y0,Rng: Integer );
	{ Given the PC's position X0,Y0 and vision range Range, determine }
	{ what points can and cannot be seen. }
var
	X,Y: Integer;
	stencil: effect_stencil;
begin
	{ First call the circular area procedure to get a stencil. }
	Plot_Circular_Area( GB , Stencil , X0 , Y0 , Rng );
	for X := 1 to GB^.map_width do begin
		for y := 1 to GB^.map_height do begin
			{ Next, copy that stencil to the map. }
			SetVisibility( GB , X , Y , Stencil[ X , Y ] or TileVisible( GB , X , Y ) );
		end;
	end;
end;

Procedure UpdatePCPosition( GB: GameBoardPtr; PC: GearPtr );
	{ Every time a player model moves, several things happen: }
	{ - the visible portions of the map get expanded. }
begin
	{ Begin with an error check. }
	if ( PC = Nil ) or not IsAlright( PC ) then Exit;
	UpdateVisibleArea( GB , NAttValue( PC^.NA , NAG_Location , NAS_X ) , NAttValue( PC^.NA , NAG_Location , NAS_Y ) , 10 );
end;

Procedure Clear_Effect_Stencil( GB: GameBoardPtr; var S: effect_Stencil );
	{ Just set all tiles to FALSE. }
var
	X,Y: Integer;
begin
	{ Clear the stencil. }
	for X := 1 to GB^.Map_Width do for Y := 1 to GB^.Map_Height do S[X,Y] := False;
end;

Procedure Calc_Invocation_Stencil( GB: GameBoardPtr; var S: effect_Stencil; I: GearPtr; X0,Y0: Integer );
	{ fill out the stencil according to the details in the Invocation gear, at the }
	{ given point, with the given power rank and boost level. }
begin
	{ Clear the stencil. }
	Clear_Effect_Stencil( GB , S );

	{ Start by calculating the radius of the effect, or 0 for a non-area effect. }
	if ( I^.Stat[ STAT_Invocation_Radius ] <> 0 ) then begin
		Plot_Circular_Area( GB , S , X0 , Y0 , Abs( I^.Stat[ STAT_Invocation_Radius ] ) );
		if I^.Stat[ STAT_Invocation_Radius ] < 0 then begin
			if OnTheMap(GB , X0 , Y0 ) then S[X0,Y0] := False;
		end;
	end else begin
		if OnTheMap( GB , X0 , Y0 ) then S[X0,Y0] := True;
	end;
end;


Procedure ClearParty;
	{ Clear the party quick reference slots. }
var
	T: Integer;
begin
	for t := 1 to Num_Party_Members do G_Party[ t ] := Nil;
end;

Function IsIdentified( I: GearPtr ): Boolean;
	{ Return TRUE if this item is identified, or FALSE otherwise. }
begin
	IsIdentified := ( I <> Nil ) and ( ( I^.G <> GG_Item ) or ( I^.V = GV_Identified ) );
end;

Function GearName( Part: GearPtr ): String;
	{ Return the name of this gear. }
begin
	if Part = Nil then begin
		GearName := 'NIL';
	end else begin
		if IsIdentified( Part ) then begin
			GearName := SAttValue( Part^.SA , 'NAME' );
		end else begin
			GearName := MsgString( 'UNIDENTIFIED_ITEM_NAME_' + BStr( Part^.S ) );
		end;
	end;
end;

Function GearDesc( Part: GearPtr ): String;
	{ Return the name of this gear. }
begin
	if Part = Nil then begin
		GearDesc := 'NIL';
	end else begin
		if IsIdentified( Part ) then begin
			GearDesc := SAttValue( Part^.SA , 'DESC' );
		end else begin
			GearDesc := MsgString( 'UNIDENTIFIED_ITEM_DESC' );
		end;
	end;
end;

function SeekGearByName( LList: GearPtr; Name: String ): GearPtr;
	{ Seek a gear with the provided name. If no such gear is }
	{ found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	Name := UpCase( Name );
	while LList <> Nil do begin
		if UpCase( GearName( LList ) ) = Name then it := LList;
		if ( it = Nil ) then it := SeekGearByName( LList^.SubCom , Name );
		if ( it = Nil ) then it := SeekGearByName( LList^.InvCom , Name );
		LList := LList^.Next;
	end;
	SeekGearByName := it;
end;

Procedure AddTrigger( Base: String; V: Integer );
	{ Add a trigger to the list. }
begin
	StoreSATt( G_Triggers , Base + BStr( V ) );
end;

Function FirstAlrightPCIndex( GB: GameBoardPtr ): Integer;
	{ Return the index of the first non-nil member of the party who's still }
	{ alive and on the map. }
	{ If no party member meets these criteria, return 0. }
var
	T,N: Integer;
begin
	T := 1;
	N := 0;
	for t := 1 to Num_Party_Members do begin
		if ( G_Party[t] <> Nil ) and OnTheMap( GB , G_Party[t] ) and IsAlright( G_Party[ t ] ) and ( N = 0 ) then N := t;
	end;
	FirstAlrightPCIndex := N;
end;

Function NextAlrightPCIndex( GB: GameBoardPtr; PN: Integer; MoveForward: Boolean ): Integer;
	{ Return the index of the next non-nil member of the party who's still }
	{ alive and on the map. Note that if there's only one person in the party, }
	{ of if there's no-one in the party, this function will return the starting }
	{ PC. MoveForward is TRUE to Inc the index number and FALSE to Dec it. }
	Function IsGoodPC( N: Integer ): Boolean;
		{ Return TRUE if this is a PC we can settle for. }
	begin
		IsGoodPC := ( G_Party[N] <> Nil ) and OnTheMap( GB , G_Party[N] ) and IsAlright( G_Party[ N ] );
	end;
var
	N: Integer;
begin
	if ( PN < 1 ) or ( PN > Num_Party_Members ) then Exit( PN );
	N := PN;
	repeat
		if MoveForward then begin
			Inc( N );
			if N > Num_Party_Members then N := 1;
		end else begin
			Dec( N );
			if N < 1 then N := Num_Party_Members;
		end;
	until IsGoodPC( N ) or ( N = PN );
	NextAlrightPCIndex := N;
end;

Function FirstActivePC( GB: GameBoardPtr ): GearPtr;
	{ Return a pointer to the first non-nil member of the party who's on the map. }
	{ If no party member meets these criteria, return NIL. }
var
	T: Integer;
begin
	T := 1;
	for t := 1 to Num_Party_Members do begin
		if ( G_Party[t] <> Nil ) and OnTheMap( GB , G_Party[t] ) then break;
	end;
	FirstActivePC := G_Party[t];
end;

Function RandomPC( GB: GameBoardPtr ): GearPtr;
	{ Count the number of active PCs, then return one of them. }
var
	T,N: Integer;
	it: GearPtr;
begin
	it := Nil;
	N := 0;
	for t := 1 to Num_Party_Members do begin
		if ( G_Party[t] <> Nil ) and OnTheMap( GB , G_Party[t] ) and IsAlright( G_Party[ t ] ) then Inc( N );
	end;

	if N > 0 then begin
		T := 1;
		N := Random( N ) + 1;
		while ( T <= Num_Party_Members ) and ( it = Nil ) do begin
			if ( G_Party[t] <> Nil ) and OnTheMap( GB , G_Party[t] ) and IsAlright( G_Party[ t ] ) then begin
				Dec( N );
				if N = 0 then it := G_Party[ t ];
			end;
			Inc( T );
		end;
	end;

	RandomPC := it;
end;

Function Party_Dead: Boolean;
	{ Check to see if the entire party has passed away or not. }
var
	T: Integer;
	AnyAlive: Boolean;
begin
	AnyAlive := False;
	for t := 1 to Num_Party_Members do begin
		if IsAlright( G_Party[ T ] ) then AnyAlive := True;
	end;
	Party_Dead := not AnyAlive;
end;

Function Should_Exit_Scene: Boolean;
	{ You should exit the scene if either the party is all dead or }
	{ an EXIT command has been issued. }
begin
	Should_Exit_Scene := Party_Dead or ( G_Destination <> 0 );
end;

Function FindPointNearModel( GB: GameBoardPtr; PC: GearPtr ): Point;
	{ Locate an empty spot near the provided model. }
	{ If no spot can be found easily, return the position of model itself. }
var
	P: Point;
	OX,OY,D: Integer;
begin
	OX := NAttValue( PC^.NA , NAG_Location , NAS_X );
	OY := NAttValue( PC^.NA , NAG_Location , NAS_Y );
	P.X := OX;
	P.Y := OY;
	for D := 0 to 7 do begin
		if ( not TileBlocksMovement( GB , OX + AngDir[ D , 1 ] , OY + AngDir[ D , 2 ] ) ) and ( FindModelXY( GB , OX + AngDir[ D , 1 ] , OY + AngDir[ D , 2 ] ) = Nil ) then begin
			P.X := OX + AngDir[ D , 1 ];
			P.Y := OY + AngDir[ D , 2 ];
			Break;
		end;
	end;
	FindPointNearModel := P;
end;


Function FindPointNearParty( GB: GameBoardPtr ): Point;
	{ Locate an empty spot near the party. }
	{ If no spot can be found easily, return the position of the first }
	{ active PC. }
var
	PC: GearPtr;
begin
	PC := FirstActivePC( GB );
	FindPointNearParty := FindPointNearModel( GB , PC );
end;

Procedure ActivateModel( GB: GameBoardPtr; M0: GearPtr );
	{ Activate M. Also, activate any models within 5 tiles on the same team. }
var
	aa: Effect_Stencil;
	M: GearPtr;
	X,Y,ID,MobID: Integer;
begin
	{ Start by making M0 active. }
	M0^.V := GV_Active;
	X := NAttValue( M0^.NA , NAG_Location , NAS_X );
	Y := NAttValue( M0^.NA , NAG_Location , NAS_Y );
	MobID := NAttValue( M0^.NA , NAG_StoryData , NAS_MobID );
	Plot_Circular_Area( GB , aa , X , Y , 5 );

	ID := NAttValue( M0^.NA , NAG_StoryData , NAS_UniqueID );
	if ID <> 0 then begin
		AddTrigger( TRIGGER_ModelActivated , ID );
	end;
	if MobID <> 0 then begin
		AddTrigger( TRIGGER_MobActivated , MobID );
	end;

	{ Next, check the map for other models to activate. }
	M := GB^.Contents;
	while M <> Nil do begin
		if ( M^.G = GG_Model ) and ( M^.S = M0^.S ) and ( M^.V = GV_Inactive ) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			{ Monsters will be activated if they are within range or if }
			{ they are a member of the same mob as the first monster activated. }
			if OnTheMap( GB , X , Y ) and ( aa[ X , Y ] or ( NAttValue( M^.NA , NAG_StoryData , NAS_MobID ) = MobID ) ) then begin
				M^.V := GV_Active;
				ID := NAttValue( M^.NA , NAG_StoryData , NAS_UniqueID );
				if ID <> 0 then begin
					AddTrigger( TRIGGER_ModelActivated , ID );
				end;
				ID := NAttValue( M^.NA , NAG_StoryData , NAS_MobID );
				if ( ID <> 0 ) and ( ID <> MobID ) then begin
					AddTrigger( TRIGGER_MobActivated , ID );
				end;
			end;
		end;
		M := M^.Next;
	end;
end;

Function CanJoinClass( PC: GearPtr; C: Integer ): Boolean;
	{ Return TRUE if the character can join this class, }
	{ or FALSE otherwise. }
const
	Class_Stat_Req: Array [ 1..Num_Classes , 1..Num_Model_Stats ] of Integer = (
	{ For non-player classes, put -1 in the first column. }
	{       STR TGH REF INT PIE LUC		}
	(	11,  0,  0,  0,  0,  0	),	{ Warrior }
	(	 0,  0, 11,  0,  0,  0	),	{ Thief }
	(	 0,  0, 13, 11,  0, 13	),	{ Bard }
	(	 0,  0,  0,  0, 11,  0	),	{ Priest }
	(	 0,  0,  0, 11,  0,  0	),	{ Mage }
	(	 0,  9,  0,  0, 11,  0	),	{ Druid }
	(	-1, -1, -1, -1, -1, -1	),	{ Animal }
	(	-1, -1, -1, -1, -1, -1	),	{ Humanoid }
	(	-1, -1, -1, -1, -1, -1	),	{ Dragon }
	(	-1, -1, -1, -1, -1, -1	),	{ Defender }
	(	11, 11,  0,  0, 17, 13	),	{ Knight }
	(	11,  0, 13, 11,  0,  0	),	{ Ranger }
	(	 0,  0,  0, 13, 13,  0	),	{ Necromancer }
	(	15,  0, 11,  0, 13, 11	),	{ Samurai }
	(	 0, 15, 13,  0, 13,  0	),	{ Monk }
	(	13, 13, 13, 13, 13, 13	)	{ Ninja }
	);
var
	it: Boolean;
	T: Integer;
begin
	{ Error check- make sure this is a legal class. }
	if ( C < 1 ) or ( C > Num_Classes ) or ( PC = Nil ) or ( Class_Stat_Req[ C , 1 ] < 0 ) then Exit( False );

	{ Assume true, unless shown false. }
	it := true;
	for t := 1 to Num_Model_Stats do begin
		if ( PC^.Stat[ T ] < Class_Stat_Req[ C , T ] ) then it := False;
	end;
	CanJoinClass := it;
end;

Procedure ApplyClassLevel( PC: GearPtr; C: Integer );
	{ This class will apply the class level. Roll new HP, MP, Spell Gems, }
	{ and increment the level counters. }
	Function GetsSpellGem: Boolean;
		{ Return TRUE if the PC should get a new spell gem this level, }
		{ or FALSE otherwise. }
	const
		Levels_Per_Gem: Array [1..Num_Classes] of Byte = (
		0, 0, 2, 1, 1,
		1, 0, 0, 0, 0,
		3, 3, 1, 2, 0,
		0
		);
	begin
		GetsSpellGem := ( Levels_Per_Gem[ C ] > 0 ) and ( ( ( NAttValue( PC^.NA , NAG_ClassLevels , C ) + 1 ) mod Levels_Per_Gem[ C ] ) = 0 );
	end;
	Function RandomSpellGem: Integer;
		{ Return a random spell gem legal for this class. }
		{ Weight the selection to favor colors with low ranks. }
		Function ColorWeight( SC: Integer ): Integer;
			{ The less of this color the PC currently knows, the }
			{ higher the weight will be. }
		var
			it: Integer;
		begin
			it := NAttValue( PC^.NA , NAG_SpellGems , SC );
			if it < 2 then ColorWeight := 20
			else if it < 10 then ColorWeight := 11 - it
			else ColorWeight := 1;
		end;
	var
		t,total,sg: Integer;
	begin
		{ Pass one- count the total weight of legal choices. }
		total := 0;
		for t := 1 to Num_Spell_Colors do begin
			if CLASS_SPELL_COLORS[ C , T ] then total := total + ColorWeight( t );
		end;

		{ Pick one randomly, based on weight. }
		if total > 0 then begin
			total := Random( total );
			t := 1;
			sg := 0;
			while ( t <= Num_Spell_Colors ) and ( sg = 0 ) do begin
				if CLASS_SPELL_COLORS[ C , T ] then begin
					total := total - ColorWeight( t );
					if ( total < 0 ) and ( sg = 0 ) then sg := t;
				end;
				Inc( T )
			end;
			RandomSpellGem := sg;
		end else begin
			{ Hmm... we've been asked for a spell gem for a }
			{ non-magic-using class. Just return something random. }
			RandomSpellGem := Random( Num_Spell_Colors ) + 1;
		end;
	end;
var
	IsFirstTime,NeededGems: Boolean;
	t: Integer;
begin
	{ Error check- make sure we have a valid PC and a valid class. }
	if ( PC = Nil ) or ( C < 1 ) or ( C > Num_Classes ) then Exit;

	SetNAtt( PC^.NA , NAG_CharacterData , NAS_CurrentClass , C );
	IsFirstTime := NAttValue( PC^.NA , NAG_ClassLevels , C ) = 0;
	AddNAtt( PC^.NA , NAG_CharacterData , NAS_BaseHP , Random( Class_HP_Die[ C ] ) + 1 );
	AddNAtt( PC^.NA , NAG_CharacterData , NAS_BaseMP , Random( Class_MP_Die[ C ] ) + 1 );

	if IsFirstTime then begin
		{ The first time you take a level in a spellcasting class, }
		{ you don't get your regularly scheduled gem but you do get }
		{ one point in each color if you don't have any already. }
		NeededGems := False;
		for t := 1 to Num_Spell_Colors do begin
			if CLASS_SPELL_COLORS[ C , T ] and ( NAttValue( PC^.NA , NAG_SpellGems , t ) < 1 ) then begin
				SetNAtt( PC^.NA , NAG_SpellGems , t , 1 );
				NeededGems := True;
			end;
		end;

		{ If we didn't need any gems- for example, if we just changed class }
		{ from a bard to a priest- then give one at random if appropriate. }
		if ( not NeededGems ) and GetsSpellGem then AddNAtt( PC^.NA , NAG_SpellGems , RandomSpellGem , 1 );

	end else if GetsSpellGem then begin
		AddNAtt( PC^.NA , NAG_SpellGems , RandomSpellGem , 1 );
	end;
end;

Procedure AddClassLevel( PC: GearPtr; C: Integer );
	{ This procedure increments the level counter and applies the level bonuses. }
begin
	ApplyClassLevel( PC , C );
	AddNAtt( PC^.NA , NAG_ClassLevels , C , 1 );
end;

Function XPNeededForNextLevel( PC: GearPtr ): LongInt;
	{ Return how many experience points the PC needs for the next level. }
var
	Lvl: LongInt;
begin
	Lvl := TotalLevel( PC );
	XPNeededForNextLevel := Lvl * ( Lvl + 1 ) * 500;
end;

Function FindEquippedItem( PC: GearPtr; Slot: Integer ): GearPtr;
	{ Search through the PC's items for an equipped weapon using the requested slot. }
var
	I,I2: GearPtr;
begin
	if ( PC = Nil ) or ( Slot < 1 ) or ( Slot > Num_Equipment_Slots ) then begin
		{ If an invalid request was made, return NIL. }
		FindEquippedItem := Nil;
	end else begin
		I := PC^.InvCom;
		I2 := Nil;
		while ( I <> Nil ) and ( I2 = Nil ) do begin
			if NAttValue( I^.NA , NAG_ItemData , NAS_EquipSlot ) = Slot then I2 := I;
			I := I^.Next;
		end;
		FindEquippedItem := I2;
	end;
end;

Function BaseComScore( PC: GearPtr; CS: Integer ): Integer;
	{ Return the model's "natural" comscore- i.e. just based on class }
	{ levels, not counting equipment. }
const
	{ This array tells how many points of each combat score the PC will gain }
	{ per class level. }
	{ ATTACK SKILLS: 5 points is best, 4 is okay, 3 is bad. }
	{ DEFENSE SKILLS: As above -1, usually. PhysDef only for monster classes. }
	{	CS_PhysicalAttack = 1;
		CS_PhysicalDefense = 2;
		CS_MagicalAttack = 3;
		CS_MagicalDefense = 4;
		CS_DisarmTraps = 5;
		CS_Stealth = 6;
		CS_Resist_Slashing = 7;
		CS_Resist_Piercing = 8;
		CS_Resist_Crushing = 9;
		CS_Resist_Fire = 10;
		CS_Resist_Lightning = 11;
		CS_Resist_Frost = 12;
		CS_Resist_Lunar = 13;
		CS_Resist_Solar = 14;
		CS_Resist_Acid = 15;
		CS_Resist_Wind = 16;
		CS_Resist_Water = 17;
		CS_Resist_Atomic = 18;
		CS_Resist_Poison = 19
		CS_TurnUndead = 20
		CS_NaturalAttack = 21
		CS_NaturalArmor = 22
		CS_CriticalHit = 23
		CS_Awareness = 24	}
	Class_CS_Bonus: Array [ 1..Num_Classes, 1..Num_Com_Score ] of Integer = (
		( 5, 0, 3, 2, 0, 0,	{ Warrior }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 2 ),
		( 4, 0, 3, 4, 5, 5,	{ Thief }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 4 ),
		( 4, 0, 4, 3, 4, 0,	{ Bard }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 3 ),
		( 4, 0, 4, 3, 0, 0,	{ Priest }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  5, 0, 0, 0, 3 ),
		( 3, 0, 5, 4, 0, 0,	{ Mage }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 3 ),
		( 3, 0, 5, 3, 0, 0,	{ Druid }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 4 ),
		( 4, 3, 3, 2, 0, 0,	{ Animal - MONSTER CLASS }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 4 ),
		( 4, 3, 4, 3, 0, 0,	{ Humanoid - MONSTER CLASS }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 2 ),
		( 4, 4, 4, 4, 0, 0,	{ Dragon - MONSTER CLASS }
		  0, 0, 0, 5, 5, 5, 0, 0, 5, 0, 0, 0, 0,
		  0, 0, 0, 0, 4 ),
		( 4, 4, 3, 4, 0, 0,	{ Defender - MONSTER CLASS }
		  5, 5, 5, 3, 3, 3, 0, 0, 3, 1, 1, 0, 1,
		  0, 0, 0, 0, 3 ),
		( 5, 0, 3, 5, 0, 0,	{ Knight }
		  0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 2 ),
		( 5, 0, 3, 3, 0, 4,	{ Ranger }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 5 ),
		( 3, 0, 5, 4, 0, 0,	{ Necromancer }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 0, 0, 3 ),
		( 5, 0, 4, 2, 0, 0,	{ Samurai }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 2, 0, 0, 3 ),
		( 5, 0, 3, 4, 0, 0,	{ Monk }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 5, 4, 0, 3 ),
		( 4, 0, 3, 4, 4, 5,	{ Ninja }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		  0, 0, 4, 5, 4 )
	);
	Template_CS_Bonus: Array [ 1..Num_Templates, 1..Num_Com_Score ] of Integer = (
		( 5, 0, 5, 0, 0, 0,	{ Undead }
		  0, 0, 0, 0, 0, 50, 50, -100, 0, 0, 0, 0, 155,
		  0, 0, 0, 0, 0 ),
		( 0, 0, 0, 0, 0, 0,	{ Construct }
		  25, 25, 25, 0, 0, 0, 0, 0, 0, 0, -50, -200, 155,
		  0, 0, 0, 0, -10 ),
		( 0, 0, 0, 0, 0, 0,	{ Plant }
		  0, 0, 0, -50, 0, 0, 0, 50, 0, 0, 250, 0, 0,
		  0, 0, 0, 0, -10 ),
		( 0, 5, 0,-5, 0, 0,	{ Elemental }
		  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -100, 155,
		  0, 0, 0, 0, 0 ),
		( 0, 0, 0, 0, 0, 0,	{ Demon }
		  0, 0, 0, 75, 0, 0, 75, -50, 0, 0, 0, 0, 100,
		  0, 0, 0, 0, 0 ),
		( 0, 10, 0, -10, 0, 0,	{ Bug }
		  25, 0, 25, 0, 0, 0, 0, 0, -100, 0, 0, 0, -100,
		  0, 0, 0, 0, 0 ),
		( 0, 0, 0, 0, 0, 0,	{ Reptile }
		  0, 0, 0, 0, 0, -50, 0, 0, 0, 0, 0, 0, 50,
		  0, 0, 0, 0, 0 ),
		( 5,-5, 0, 0, 0, 0,	{ Fire }
		  0, 0, 0, 100, 0, -100, 0, 0, 0, 0, -100, 50, 0,
		  0, 0, 0, 0, 0 ),
		( 0, 0,-5, 5, 0, 0,	{ Water }
		  0, 0, 0, 50, -100, 50, 0, 0, -100, 0, 100, 0, 0,
		  0, 0, 0, 0, 0 ),
		(-5, 5, 0, 0, 0, 0,	{ Earth }
		  0, 0, -50, 0, 100, 0, 0, 0, 50, -100, -100, 0, 0,
		  0, 0, 0, 0, 0 ),
		( 0, 0, 5,-5, 0, 0,	{ Air }
		  -50, 0, 0, -100, 0, 0, 0, 0, 50, 100, 0, 0, 0,
		  0, 0, 0, 0, 0 ),
		( 0, 0, 0, 0, 0, 0,	{ Ice }
		  0, -50, 0, -100, 0, 100, 0, 0, 0, 50, 50, 0, 0,
		  0, 0, 0, 0, 0 )

	);
var
	it,T,Lvl: Integer;
begin
	it := 0;
	if ( CS >= 1 ) and ( CS <= Num_Com_Score ) then begin
		for t := 1 to Num_Classes do begin
			Lvl := NAttValue( PC^.NA , NAG_ClassLevels , T );
			if Lvl > 0 then begin
				it := it + Class_CS_Bonus[ T , CS ] * Lvl;
			end;
		end;
		for t := 1 to Num_Templates do begin
			if NAttValue( PC^.NA , NAG_Template , T ) <> 0 then it := it + Template_CS_Bonus[ T , CS ];
		end;
	end;
	BaseComScore := it;
end;

Function ComScore( PC: GearPtr; CS: Integer ): Integer;
	{ Calculate a combat score for this character. The score will be }
	{ dependant upon a number of factors: }
	{ - The PC's class levels. }
	{ - The items equipped by the PC. }
	{ - Any enchantments currently affecting the PC. }
	{ - Any natural bonuses the PC has. }
var
	it: Integer;
	Item: GearPtr;
begin
	{ The base ComScore is the PC's own ComScore mod. Actual player }
	{ characters probably won't get this modifier at all (unless someone's }
	{ been cheating), but monsters can use it to override the default }
	{ values of their monster class. }
	it := NAttValue( PC^.NA , NAG_ComScoreMod , CS );

	{ Add the class bonuses. }
	it := it + BaseComScore( PC , CS );

	{ Item bonuses. Only equipped items count!!! }
	Item := PC^.InvCom;
	while Item <> Nil do begin
		if ( Item^.G = GG_Item ) and ( NAttValue( Item^.NA , NAG_ItemData , NAS_EquipSlot ) <> 0 ) then begin
			it := it + NAttValue( Item^.NA , NAG_ComScoreMod , CS );
		end;
		Item := Item^.Next;
	end;

	{ Enchantment bonuses. }
	Item := PC^.SubCom;
	while Item <> Nil do begin
		if Item^.G = GG_Enchantment then begin
			it := it + NAttValue( Item^.NA , NAG_ComScoreMod , CS );
		end;
		Item := Item^.Next;
	end;

	{ Return the value we've calculated. }
	ComScore := it;
end;

Function StatBonus( PC: GearPtr; Stat: Integer ): Integer;
	{ Return the stat skill bonus this PC has coming. }
begin
	StatBonus := ( CSTat( PC , Stat ) - 11 ) * 3;
end;

Function DamageBonus( PC: GearPtr; Stat: Integer ): Integer;
	{ Return the damage bonus based on this stat. }
begin
	DamageBonus := ( CSTat( PC , Stat ) div 2 ) - 5;
end;

Function ActionPoints( PC: GearPtr ): Integer;
	{ Return the number of action points this PC gets. }
var
	Species,it: Integer;
	Item: GearPtr;
begin
	Species := NAttValue( PC^.NA , NAG_CharacterData , NAS_Species );
	if ( Species >= 1 ) and ( Species <= Num_Species ) then begin
		Item := FindEquippedItem( PC , NAV_Body );
		if ( Item = Nil ) or ( Item^.S = GS_Clothes ) then begin
			it := 12;
		end else if ( Item^.S = GS_HeavyArmor ) then begin
			it := 8;
		end else begin
			it := 10;
		end;
		if Species = SPECIES_Centaur then it := it + 2;
	end else begin
		it := NAttValue( PC^.NA , NAG_MonsterData , NAS_MonsterActionPoints );
	end;
	ActionPoints := it;
end;

Function BestPhysicalDefense( PC: GearPtr ): Integer;
	{ Return the best score of either Physical Defense or Natural Defense. }
var
	RegDef,NatDef: Integer;
begin
	RegDef := ComScore( PC , CS_PhysicalDefense );
	NatDef := ComScore( PC , CS_NaturalArmor );
	if NatDef > RegDef then RegDef := NatDef;
	BestPhysicalDefense := RegDef;
end;

Procedure WriteCampaign( Camp: CampaignPtr; var F: Text );
	{ Write all the data for this campaign to file F so that it may be }
	{ reloaded at a later time. It'd be pretty stupid to write all the }
	{ data in an unreadable format, right? }
	Procedure WriteMap( GB: GameBoardPtr );
		{ Using run-length encoding, output this map. }
	var
		T,C,X: Longint;
		Vis: Boolean;
	begin
		{First, a descriptive message.}
		writeln(F,'*** Dungeon Monkey Unlimited Map ***');

		{Output the terrain of the map, compressed using}
		{run length encoding.}
		{ We need three passes- one for the floors, one for the walls, }
		{ and a last one for the decor. }
		T := GB^.Map[0].floor;
		C := 0;
		X := 0;
		while X < Length( GB^.Map ) do begin
			if GB^.Map[ X ].floor = t then begin
				Inc(C);
			end else begin
				writeln(F,C);
				writeln(F,T);
				T := GB^.Map[ X ].floor;
				C := 1;
			end;
			Inc( X );
		end;
		{Output the last terrain stretch}
		writeln(F,C);
		writeln(F,T);

		T := GB^.Map[0].wall;
		C := 0;
		X := 0;
		while X < Length( GB^.Map ) do begin
			if GB^.Map[ X ].wall = t then begin
				Inc(C);
			end else begin
				writeln(F,C);
				writeln(F,T);
				T := GB^.Map[ X ].wall;
				C := 1;
			end;
			Inc( X );
		end;
		{Output the last terrain stretch}
		writeln(F,C);
		writeln(F,T);

		T := GB^.Map[0].decor;
		C := 0;
		X := 0;
		while X < Length( GB^.Map ) do begin
			if GB^.Map[ X ].decor = t then begin
				Inc(C);
			end else begin
				writeln(F,C);
				writeln(F,T);
				T := GB^.Map[ X ].decor;
				C := 1;
			end;
			Inc( X );
		end;
		{Output the last terrain stretch}
		writeln(F,C);
		writeln(F,T);

		{Output the Visibility of the map, again using run}
		{length encoding. Since there are only two possible}
		{values, just flop between them.}
		Vis := False;
		C := 0;
		X := 0;
		while X < Length( GB^.Map ) do begin
			if GB^.map[ X ].visible = Vis then begin
				Inc(C);
			end else begin
				writeln(F,C);
				Vis := not Vis;
				C := 1;
			end;
			Inc( X );
		end;
		{Output the last terrain stretch}
		writeln(F,C);
	end;
var
	T: Integer;
	GB: GameBoardPtr;
begin
	{ The campaign needs to be formatted a bit before we can write it. }
	for t := 1 to Num_Party_Members do if G_Party[ t ] <> Nil then SetNAtt( G_Party[t]^.NA , NAG_SaveFileData , NAS_PartySlot , t );

	{ Output the source. This bit is easy. }
	WriteCGears( F , Camp^.Source );

	{ Output the game boards. Crud, DMU uses a different gameboard format }
	{ than any of the games from which it is composed, meaning that I have }
	{ to do some actual work here. }
	GB := Camp^.Boards;
	while GB <> Nil do begin
		writeln( F , GB^.MAP_Width );
		writeln( F , GB^.MAP_Height );
		writeln( F , GB^.ID );
		writemap( GB );
		WriteCGears( F , GB^.Contents );
		GB := GB^.Next;
	end;

	{ Output the gameboard sentinel. }
	writeln( F , 0 );
end;

Function ReadCampaign( var F: Text ): CampaignPtr;
	{ Write all the data for this campaign to file F so that it may be }
	{ reloaded at a later time. It'd be pretty stupid to write all the }
	{ data in an unreadable format, right? }
	Procedure ReadMap( GB: GameBoardPtr );
		{ According to the GearHead2 comments: }
		{ "This procedure is taken more or less verbatim from DeadCold." }
		{ Remember, kids, strive for reusability. You never know how long }
		{ you're going to keep using the same damn code. }
	var
		MapLength,C,T,X,I: Longint;
		A: String;
		Vis: Boolean;
	begin
		{First, get rid of the descriptive message.}
		readln(F,A);

		MapLength := GB^.Map_Width * GB^.Map_Height;

		{ Need to read the three channels separately- floor, }
		{ wall, and decor. }
		I := 0;
		while I < MapLength do begin
			readln(F,C);	{Read Count}
			readln(F,T);	{Read Terrain}

			{Fill the map with this terrain up to Count.}
			for X := I to ( I + C - 1 ) do begin
				GB^.map[ X ].floor := t;
				Inc( I );
			end;
		end;

		I := 0;
		while I < MapLength do begin
			readln(F,C);	{Read Count}
			readln(F,T);	{Read Terrain}

			{Fill the map with this terrain up to Count.}
			for X := I to ( I + C - 1 ) do begin
				GB^.map[ X ].wall := t;
				Inc( I );
			end;
		end;

		I := 0;
		while I < MapLength do begin
			readln(F,C);	{Read Count}
			readln(F,T);	{Read Terrain}

			{Fill the map with this terrain up to Count.}
			for X := I to ( I + C - 1 ) do begin
				GB^.map[ X ].decor := t;
				Inc( I );
			end;
		end;

		{Read the visibility data.}
		Vis := False;
		I := 0;
		while I < MapLength do begin
			readln(F,C);	{Read Count}

			{Fill the map with this terrain up to Count.}
			for X := I to ( C + I - 1 ) do begin
				GB^.Map[ X ].visible := Vis;
				Inc( I );
			end;

			Vis := not Vis;
		end;
	end;
var
	Camp: CampaignPtr;
	GB: GameBoardPtr;
	PC: GearPtr;
	W,H,ID: Integer;
begin
	Camp := NewCampaign;

	{ Input the source. Again, this bit is easy. }
	Camp^.Source := ReadCGears( F );

	{ Input the game boards. }
	repeat
		readln( F , W );
		if W > 0 then begin
			readln( F , H );
			readln( F , ID );

			GB := NewGameboard( Camp , ID , W , H );
			readmap( GB );
			GB^.Contents := ReadCGears( F );
			GB^.Scene := SeekGearByIDTag( Camp^.Source , NAG_StoryData , NAS_UniqueID , ID );
		end;
	until W < 1;

	{ Locate the current gameboard, and restore the G_Party array. }
	GB := FindGameboard( Camp , NAttValue( Camp^.Source^.NA , NAG_SaveFileData , NAS_CurrentGB ) );
	for W := 1 to Num_Party_Members do G_Party[ W ] := Nil;
	if GB <> Nil then begin
		PC := GB^.Contents;
		while PC <> Nil do begin
			ID := NAttValue( PC^.NA , NAG_SaveFileData , NAS_PartySlot );
			if ( ID >= 1 ) and ( ID <= Num_Party_Members ) then G_Party[ ID ] := PC;
			PC := PC^.Next;
		end;
	end;

	ReadCampaign := Camp;
end;

Function PlotContext( Plot: GearPtr ): String;
	{ Return a string describing the context of this plot. }
var
	context,ctag: String;
	T,N: Integer;
begin
	context := '';
	for t := 1 to Num_Context_Descriptors do begin
		N := NAttValue( Plot^.NA , NAG_StoryData , CDIndex[ t ] );
		if N <> 0 then ctag := SAttValue( Context_Tags , Context_Head[ t ] + '_' + BStr( N ) );
		if ( N = 0 ) or ( ctag = '' ) then ctag := '-----';
		context := context + ' ' + Context_Head[ t ] + ':' + ctag;
	end;
	PlotContext := context;
end;

Function GearContextTags( Part: GearPtr; const c_head: String ): String;
	{ Return a list of all the context tags which apply to this part. }
	{ If c_head is not empty, apply that to all tags. }
	Procedure AddCTag( var context: String; const c_tag: String );
		{ Add c_tag to context, maybe along with c_head. }
	begin
		if c_head = '' then context := context + ' ' + c_tag
		else context := context + ' ' + c_head + c_tag;
	end;
var
	context,c_tag,c_data: String;
	t,N: Integer;
begin
	context := '';

	{ First add the standard context descriptors. }
	for t := 1 to Num_Context_Descriptors do begin
		N := NAttValue( Part^.NA , NAG_StoryData , CDIndex[ t ] );
		if N <> 0 then c_tag := SAttValue( Context_Tags , Context_Head[ t ] + '_' + BStr( N ) );
		if ( N <> 0 ) and ( c_tag <> '' ) then AddCTag( context , c_tag );
	end;

	{ Depending on the gear type, there may be custom descriptors to add. }
	if Part^.G = GG_Scene then begin
		AddCTag( context , SAttValue( Context_Tags , 'MAPGEN_' + BStr( Part^.V ) ) );
		if Part^.V <> GV_Wilderness then AddCTag( context , SAttValue( Context_Tags , 'MAPGEN_D' ) );
		N := ( ( NAttValue( Part^.NA , NAG_StoryData , NAS_DifficultyLevel ) - 1 ) div 5 ) + 1;
		if N > 5 then N := 5;
		AddCTag( context , SAttValue( Context_Tags , 'DIFFICULTY_' + BStr( N ) ) );
	end;


	{ Individual parts may also have special context descriptors. }
	c_data := SAttValue( Part^.SA , 'CONTEXT' );
	while c_data <> '' do begin
		c_tag := ExtractWord( c_data );
		if c_tag <> '' then AddCTag( Context , c_tag );
	end;

	GearContextTags := Context;
end;

Function SpellGemsOfColor( PC: GearPtr; Color: Integer ): Integer;
	{ Return how many spell gems the PC has of this particular color. }
begin
	if ( Color < 1 ) or ( Color > Num_Spell_Colors ) then begin
		{ Return the number of colorless gems. }
		SpellGemsOfColor := ( CStat( PC , STAT_Intelligence ) * TotalLevel( PC ) + 19 ) div 30;
	end else begin
		{ Return the number of gems of this color. }
		SpellGemsOfColor := NAttValue( PC^.NA , NAG_SpellGems , Color );
	end;
end;

Function SpellGemsRequired( Spell: GearPtr; Color: Integer ): Integer;
	{ Return how many spell gems this spell requires. }
begin
	if ( Color < 1 ) or ( Color > Num_Spell_Colors ) then begin
		{ Return the total number of gems. }
		SpellGemsRequired := Spell^.V + 1;
	end else begin
		{ Return the number of gems of this color. }
		SpellGemsRequired := NAttValue( Spell^.NA , NAG_SpellGems , Color );
	end;
end;

Function TotalSpellGems( PC: GearPtr ): Integer;
	{ Caclulate the total number of spell gems this PC has, including the }
	{ colorless gems gained from Intelligence bonus. }
var
	T,N: Integer;
begin
	N := 0;
	for t := 0 to num_spell_Colors do begin
		N := N + SpellGemsOfColor( PC , T );
	end;
	TotalSpellGems := N;
end;

Function SpellGemsUsed( PC: GearPtr; Color: Integer ): Integer;
	{ Check through the PC's spells and determine how many gems of }
	{ the requested color are being used. }
var
	Spell: GearPtr;
	N: Integer;
begin
	Spell := PC^.SubCom;
	N := 0;
	while Spell <> Nil do begin
		if ( Spell^.G = GG_Invocation ) and ( Spell^.S = GS_Spell ) then begin
			N := N + SpellGemsRequired( Spell , Color );
		end;

		Spell := Spell^.Next;
	end;
	SpellGemsUsed := N;
end;

Function FreeSpellGems( PC: GearPtr; Color: Integer ): Integer;
	{ Return how many free spell gems the PC has of this particular color. }
begin
	FreeSpellGems := SpellGemsOfColor( PC , Color ) - SpellGemsUsed( PC , Color );
end;

Function TotalFreeSpellGems( PC: GearPtr ): Integer;
	{ Caclulate the total number of spell gems this PC has, including the }
	{ colorless gems gained from Intelligence bonus. }
var
	N: Integer;
	Spell: GearPtr;
begin
	N := TotalSpellGems( PC );
	Spell := PC^.SubCom;
	while Spell <> Nil do begin
		if ( Spell^.G = GG_Invocation ) and ( Spell^.S = GS_Spell ) then begin
			N := N - SpellGemsRequired( Spell , 0 );
		end;
		Spell := Spell^.Next;
	end;
	TotalFreeSpellGems := N;
end;

Function MPRequired( Spell: GearPtr ): Integer;
	{ Return how many spell points this spell requires. This will be }
	{ equal to the level of the spell plus one extra for every spell gem. }
var
	N,T: Integer;
begin
	N := Spell^.V + Spell^.Stat[ STAT_Invocation_CostMod ];
	if Spell^.S = GS_Spell then begin
		for t := 1 to num_spell_Colors do begin
			N := N + SpellGemsRequired( Spell , T ) * 2;
		end;
	end;
	MPRequired := N;
end;

Function GPValue( I_Master: GearPtr ): LongInt;
	{ Calculate a GP cost for this item. }
	Function ItemValue( Item: GearPtr ): LongInt;
		{ Return the value of a GG_Item gear. }
	const
		Com_Score_Cost_Mod: Array [1..Num_Com_Score] of Integer = (
			25, 7, 25, 15, 20, 25,
			10, 10, 10, 5, 5, 5, 20, 20, 5, 15, 15, 30, 15,
			25, 25, 25, 50, 10
		);
	var
		it,n,d: LongInt;
	begin
		{ Start with a default minimum. }
		if ( Item^.S = GS_Arrow ) or ( Item^.S = GS_Bullet ) then it := 1
		else it := 5;

		{ Begin with the weapon damage. If it isn't a weapon, it shouldn't }
		{ have a damage assigned, so screw 'em if they gave it one. }
		if ( Item^.Stat[ STAT_WeaponN ] > 0 ) or ( Item^.Stat[ STAT_WeaponD ] > 0 ) then begin
			N := Item^.Stat[ STAT_WeaponN ];
			D := Item^.Stat[ STAT_WeaponD ];
			if N < 1 then N := 1;
			if D < 2 then D := 2;
			{ The base cost is the maximum possible damage squared plus the }
			{ number of dice rolled squared. }
			D := N * D;
			it := D * D + N * N;

			{ Each point of range increases the base cost by a third. }
			if Item^.Stat[ STAT_WeaponRange ] > 0 then begin
				it := ( it * ( Item^.Stat[ STAT_WeaponRange ] + 4 ) ) div 3;

				{ Being a bow or sling reduces cost by half, due to }
				{ the ammunition requirements. }
				if ( Item^.S = GS_Bow ) or ( Item^.S = GS_Sling ) then it := it div 2;
			end;
		end;

		{ Add cost for the ComScore bonuses. }
		for N := 1 to Num_Com_Score do begin
			D := NAttValue( Item^.NA , NAG_ComScoreMod , N );
			if D > 0 then it := it + D * ( D + 1 ) * Com_Score_Cost_Mod[ N ] div 10;
		end;

		{ Add the GPFudge. }
		it := it + NAttValue( Item^.NA , NAG_ItemData , NAS_GPFudge );

		{ Multiply by quantity. }
		if Item^.Stat[ STAT_Quantity ] > 1 then it := it * Item^.Stat[ STAT_Quantity ];

		if it < 1 then it := 1;

		ItemValue := it;
	end;
begin
	GPValue := ItemValue( I_Master );
end;

Function TurningAttemptsPerDay( PC: GearPtr ): Integer;
	{ Return the number of turning attempts that this PC can make per day. }
var
	it: Integer;
begin
	it := BaseComScore( PC , CS_TurnUndead );
	if it > 0 then begin
		TurningAttemptsPerDay := ( it div 25 ) + 1;
	end else TurningAttemptsPerDay := 0;
end;

Function ModelIsAnimal( M: GearPtr ): Boolean;
	{ Return TRUE if model doesn't have the UNDEAD, DEMON, CONSTRUCT, }
	{ ELEMENTAL, or PLANT tags. }
begin
	ModelIsAnimal := ( M <> Nil ) and ( NAttValue( M^.NA , NAG_Template , NAS_Undead ) = 0 ) and ( NAttValue( M^.NA , NAG_Template , NAS_Demon ) = 0 ) and ( NAttValue( M^.NA , NAG_Template , NAS_Construct ) = 0 ) and ( NAttValue( M^.NA , NAG_Template , NAS_Plant ) = 0 ) and ( NAttValue( M^.NA , NAG_Template , NAS_Elemental ) = 0 );
end;

Function ModelIsLiving( M: GearPtr ): Boolean;
	{ Return TRUE if model doesn't have the UNDEAD, DEMON, CONSTRUCT, }
	{ or ELEMENTAL tags. }
begin
	ModelIsLiving := ( M <> Nil ) and ( NAttValue( M^.NA , NAG_Template , NAS_Undead ) = 0 ) and ( NAttValue( M^.NA , NAG_Template , NAS_Demon ) = 0 ) and ( NAttValue( M^.NA , NAG_Template , NAS_Construct ) = 0 ) and ( NAttValue( M^.NA , NAG_Template , NAS_Elemental ) = 0 );
end;

Function ModelIsUnholy( M: GearPtr ): Boolean;
	{ Return TRUE if model has UNDEAD or DEMON tag. }
begin
	ModelIsUnholy := ( M <> Nil ) and ( ( NAttValue( M^.NA , NAG_Template , NAS_Undead ) <> 0 ) or ( NAttValue( M^.NA , NAG_Template , NAS_Demon ) <> 0 ) );
end;

Function ModelHasBrain( M: GearPtr ): Boolean;
	{ Return TRUE if model is not a construct, plant, or undead. }
begin
	ModelHasBrain := ( M <> Nil ) and ( NAttValue( M^.NA , NAG_Template , NAS_Undead ) = 0 ) and ( NAttValue( M^.NA , NAG_Template , NAS_Construct ) = 0 ) and ( NAttValue( M^.NA , NAG_Template , NAS_Plant ) = 0 );
end;

initialization
	G_Triggers := Nil;
	ClearParty;
	Context_Tags := LoadStringList( Data_Directory + 'context_tags.txt' );

finalization
	if G_Triggers <> Nil then DisposeSAtt( G_Triggers );
	DisposeSAtt( Context_Tags );

end.
