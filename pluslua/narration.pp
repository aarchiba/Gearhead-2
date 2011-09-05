unit narration;
	{ This unit holds utilities for dealing with RPG campaigns and random plots. }
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

	{ PLOT DEFINITION }
	{   G = GG_Plot                  }
	{   S = Active/Inactive/Dormant  }
	{   V = Dramatic Choice ID       }

	{ MEME DEFINITION      }
	{   G = GG_Meme        }
	{   S = ID Number      }
	{   V = Undefined      }
	{ A Meme is only active when it's a subcom of a root scene. There is an ASL command }
	{ for activating a meme. }

	{ CITYMOOD DEFINITION }
	{  G = GG_CityMood     }
	{  S = Major/Minor     }
	{  V = Number of attached plots }
	{ A mood may also have TYPE and a PLOT_TYPE string attributes. The first modifies the }
	{ type of the city to which the mood is attached. The second determines what sort of plot }
	{ will be loaded by this mood; the default value is *GENERAL. }
	{ The ControllerID for a mood is assigned automatically. }


Const

	Num_Plot_Elements = 50;	{ Maximum number of plot elements }


{	NAG_MemeData = -17;		 Used to record certain things about memes. 
		NAS_MemeTimeLimit = 1;	 Holds the time at which this meme should be deleted. 
					 If zero, this meme has no time limit. 
		NAS_NumViews = 0;	 How many times the PC has seen this meme. 
		NAS_MaxMemeViews = 2;	 How many times should this meme be viewed? Due to the peculiarities of 
					 the system, the default score (0) is equivalent to 1. }

{	NAG_MoodData = -23;	 Used to record certain things about moods. 
		NAS_MoodTimeLimit = 1;	 The time at which this mood will be deleted. }


	{ PLOT ELEMENTS }
	{ A plot or a story can have up to 50 elements associated with it. As of }
	{ this revision, all elements are referred to by their Narrative ID. }

	{ Some additional types are defined for the purposes of element search. }
	{ "M" = Metascene, ID number is metascene ID }
	{       Once an entry point is selected the "M" tag is changed to "S". }
	{ "P" = Prefab; element is defined within the plot/story. }
	{       Once the plot is initialized an appropriate descriptive tag is added. }
	{ "G" = Grab; element ID is taken from source story. }
	{       The grabbed element gains the same descriptive tag as the original. }


	{ These constants describe the standard palette entries for xxran stories. }
	XRP_EnemyChar = 1;		{ E: }
	XRP_EnemyFac = 2;		{ F: }
	XRP_AllyFac = 3;		{ P: }
	XRP_EpisodeScene = 7;		{ L: }
	XRP_TargetItem = 8;		{ I: }

	TRIGGER_StartGame = 'Start';
	TRIGGER_EndGame = 'END';

	{ ArenaHQ Data. Not really narrative, but this is a good place }
	{ to stick it. }
	NAG_AHQData = 27;
		NAS_RewardMissionTimer = 1;	{ Used for spacing out reward missions. }
		NAS_CoreMissionTimer = 2;	{ Used for spacing out core missions. }
		NAS_CoreMissionStep = 3;	{ Records the number of core missions completed. }
		NAS_CoreMissionEnemy = 4;	{ Enemy for the core story. }

	{ The Attitude and Motivation constants, made public so the BeanCounter }
	{ can examine them. }
	Num_XXR_Motivations = 8;
	Num_XXR_Attitudes = 14;
	XXR_Motivation: Array [0..Num_XXR_Motivations] of String[3] = (
		'---',
		'mer', 'pro', 'ggd', 'see', 'rev', 'cha', 'com', 'nih'
	);
	XXR_Attitude: Array [0..Num_XXR_Attitudes] of String[3] = (
		'---',
		'jr_', 'sr_', 'sec', 'equ', 'env',   'pch', 'hat', 'mut', 'obs', 'tha',
		'nme', 'ant', 'adm', 'dis'
	);

	Num_XXR_Plans = 9;
	XXR_Plan: Array [0..Num_XXR_Plans] of String[3] = (
		'---',
		'sub','cat','pil','pat','art',	'gat','wep','war','ina'
	);

Procedure AddFactionPlanContext( Fac: GearPtr; var Context: String; palette_entry_code: Char );

Function LancemateCanDevelop( NPC: GearPtr ): Boolean;
Procedure AddXXCharContext( NPC: GearPtr; var Context: String; palette_entry_code: Char );
Procedure AddGearXRContext( GB: GameBoardPtr; Adv,Part: GearPtr; var Context: String; palette_entry_code: Char );

Procedure AddElementContext( GB: GameBoardPtr; Story: GearPtr; var Context: String; palette_entry_code: Char; Element_Num: Integer );
Function DifficulcyContext( Threat: Integer ): String;
Function StoryPlotRequest( Story: GearPtr ): String;
Function StoryContext( GB: GameBoardPtr; Story: GearPtr ): String;


Function FindSceneID( Part: GearPtr; GB: GameBoardPtr ): Integer;

Function SeekFaction( Scene: GearPtr; ID: Integer ): GearPtr;
Function GetFactionID( Part: GearPtr ): Integer;
Function FactionIsInactive( Fac: GearPtr ): Boolean;

Function ElementID( Plot: GearPtr; N: Integer ): LongInt;
Function PlotElementID( Plot: GearPtr; ID: LongInt ): Integer;
Function FindMetaPersona( Source: GearPtr; N: Integer ): GearPtr;

Function ElementInUse( Scope: GearPtr; ID: LongInt ): Boolean;

Function FindPersonaPlot( Adventure: GearPtr; CID: Integer ): GearPtr;

Function PersonaInUse( Adventure: GearPtr;  ID: LongInt ): Boolean;

Function SeekGearByNID( GB: GameBoardPtr; Adventure: GearPtr; NID: LongInt ): GearPtr;

Function SeekPlotElement( Adventure , Plot: GearPtr; N: Integer; GB: GameBoardPtr ): GearPtr;

Function SeekPersona( Scene: GearPtr; CID: LongInt ): GearPtr;
Function SeekPersona( GB: GameBoardPtr; CID: LongInt ): GearPtr;

Function FindMetascenePlot( Adventure: GearPtr; MSID: LongInt ): GearPtr;
Function MetaSceneNotInUse( Adventure: GearPtr; MSID: LongInt ): Boolean;
Function FindSceneEntrance( Adventure: GearPtr; GB: GameBoardPtr; MSID: LongInt ): GearPtr;

Function NewNID( Adventure: GearPtr ): LongInt;
Function NewMetaSceneID( Adventure: GearPtr ): LongInt;

Function ElementLocation( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
Function ElementFaction( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
Function ElementName( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): String;

Procedure WriteCampaign( Camp: CampaignPtr; var F: Text );
Function ReadCampaign( var F: Text ): CampaignPtr;

Function TeamDescription( Scene,Team: GearPtr ): String;
Function CreateTeam( Scene: GearPtr; TDesc: String ): GearPtr;
Procedure ChooseTeam( NPC , Scene: GearPtr );
Procedure PutAwayGlobal( GB: GameBoardPtr; var Item: GearPtr );

Function RealSceneID( Scene: GearPtr ): Integer;
Function FindActualScene( Scene: GearPtr; SID: Integer ): GearPtr;
Function FindActualScene( GB: GameBoardPtr; SID: Integer ): GearPtr;
Function IsAScene( S: GearPtr ): Boolean;
Function SceneIsTemp( S: GearPtr ): Boolean;
Function FindRootScene( S: GearPtr ): GearPtr;
Function FindWorld( GB: GameBoardPtr; S: GearPtr ): GearPtr;

Procedure DelinkGearForMovement( GB: GameBoardPtr; GearToBeMoved: GearPtr );

Function KeepPlayingSC( GB: GameBoardPtr ): Boolean;

Procedure RecordFatality( Camp: CampaignPtr; NPC: GearPtr );

Function HasMeritBadge( Adv: GearPtr; Badge: Integer ): Boolean;

Function LocatePC( GB: GameBoardPtr ): GearPtr;
Function SceneName( GB: GameBoardPtr; ID: Integer; Exact: Boolean ): String;
Function FactionRankName( GB: GameBoardPtr; Source: GearPtr; FID,FRank: Integer ): String;
Function PCRankName( GB: GameBoardPtr; Source: GearPtr ): String;


implementation

uses 	texutil,rpgdice,ghchars,gamebook,ability,menugear,ghprop,ghweapon,
	interact,uiconfig,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}

const
	FROZEN_MAP_CONTINUE = 1;
	FROZEN_MAP_SENTINEL = -1;

Procedure AddFactionPlanContext( Fac: GearPtr; var Context: String; palette_entry_code: Char );
	{ Add context descriptor for the master plan of this faction. }
var
	T: Integer;
begin
	T := NAttValue( Fac^.NA , NAG_XXRan , NAS_XXFac_Plan );
	if ( T > 0 ) and ( T <= Num_XXR_Plans ) then Context := Context + ' ' + palette_entry_code + ':P.' + XXR_Plan[ t ]
	else Context := Context + ' ' + palette_entry_code + ':P.---';
end;


Function LancemateCanDevelop( NPC: GearPtr ): Boolean;
	{ If this lancemate can learn new skills via the TrainNPC function, }
	{ return TRUE. This is determined by the NAS_LancemateTraining_Total and }
	{ NAS_LancemateTraining_Spent attributes. }
const
	Points_Per_TrainNPC = 11;
begin
	NPC := LocatePilot( NPC );
	if NPC = Nil then Exit( False );
	LancemateCanDevelop := ( ( NAttValue( NPC^.NA , NAG_Narrative , NAS_LancemateTraining_Spent ) + 1 ) * Points_Per_TrainNPC ) < NAttValue( NPC^.NA , NAG_Narrative , NAS_LancemateTraining_Total );
end;

Procedure AddXXCharContext( NPC: GearPtr; var Context: String; palette_entry_code: Char );
	{ Add context descriptors for the attitude and motivation of this NPC. }
var
	T: Integer;
begin
	T := NAttValue( NPC^.NA , NAG_XXRan , NAS_XXChar_Motivation );
	if ( T > 0 ) and ( T <= Num_XXR_Motivations ) then Context := Context + ' ' + palette_entry_code + ':M_' + XXR_Motivation[ t ]
	else Context := Context + ' ' + palette_entry_code + ':M_---';

	T := NAttValue( NPC^.NA , NAG_XXRan , NAS_XXChar_Attitude );
	if ( T > 0 ) and ( T <= Num_XXR_Attitudes ) then Context := Context + ' ' + palette_entry_code + ':A_' + XXR_Attitude[ t ]
	else Context := Context + ' ' + palette_entry_code + ':A_---';

	{ Lancemates may also get a TRAIN tag, if appropriate. }
	if ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and LancemateCanDevelop( NPC ) then begin
		Context := Context + ' ' + palette_entry_code + ':TRAIN';
	end;
end;

Procedure AddGearXRContext( GB: GameBoardPtr; Adv,Part: GearPtr; var Context: String; palette_entry_code: Char );
	{ Add the context information for PART to CONTEXT. }
var
	F: GearPtr;
	msg,m2: String;
	T: Integer;
	NID: LongInt;
	Persona: GearPtr;
begin
	if Part <> Nil then begin
		Context := Context + ' ' + palette_entry_code + ':++';

		{ Add additional information about PART. }
		msg := SAttValue( Part^.SA , 'DESIG' );
		if msg <> '' then Context := Context + ' ' + palette_entry_code + ':' + msg;
		msg := SAttValue( Part^.SA , 'CONTEXT' );
		while msg <> '' do begin
			m2 := ExtractWord( msg );
			if m2 <> '' then Context := Context + ' ' + palette_entry_code + ':' + m2;
		end;

		{ If Part isn't a faction itself, add the designation of its faction. }
		if Part^.G <> GG_Faction then begin
			F := SeekFaction( Adv , NAttValue( Part^.NA , NAG_Personal , NAS_FactionID ) );
			if F <> Nil then begin
				msg := SAttValue( F^.SA , 'DESIG' );
				if msg <> '' then Context := Context + ' ' + palette_entry_code + ':' + msg;
			end;
		end else begin
			F := Part;
		end;
		if F <> Nil then begin
			{ If this faction is also the PC's faction, add a PCFAC tag. }
			if F^.S = NAttValue( FindRoot( Adv )^.NA , NAG_Personal , NAS_FactionID ) then Context := Context + ' ' + palette_entry_code + ':PCFAC';

			{ If we haven't already done so, add the faction's context notes. }
			if F <> Part then begin
				msg := SAttValue( F^.SA , 'CONTEXT' );
				while msg <> '' do begin
					m2 := ExtractWord( msg );
					if m2 <> '' then Context := Context + ' ' + palette_entry_code + ':' + m2;
				end;
			end;
		end else begin
			{ No faction was found. }
			Context := Context + ' ' + palette_entry_code + ':NOFAC';
		end;

		{ If Part is a character, add relationship info. }
		if Part^.G = GG_Character then begin
			Case NAttValue( Part^.NA , NAG_Relationship , 0 ) of
				NAV_ArchEnemy: Context := Context + ' ' + palette_entry_code + ':NEMES';
				NAV_ArchAlly: Context := Context + ' ' + palette_entry_code + ':MATE_';
				NAV_Family: Context := Context + ' ' + palette_entry_code + ':FAMILY';
				NAV_Lover: Context := Context + ' ' + palette_entry_code + ':LOVER';
				NAV_Friend: Context := Context + ' ' + palette_entry_code + ':FRIEND';
			end;
			m2 := SAttValue( Part^.SA , 'JOB_DESIG' );
			if m2 <> '' then Context := Context + ' ' + palette_entry_code + ':' + m2;

			{ If the part is a lancemate, add that info. }
			if NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam then begin
				Context := Context + ' ' + palette_entry_code + ':LANCE';
			end;

			{ Add the heroic/villainous component. }
			T := NAttValue( Part^.NA , NAG_CharDescription , NAS_Heroic );
			if T > 0 then Context := Context + ' ' + palette_entry_code + ':GOOD_'
			else if T < 0 then Context := Context + ' ' + palette_entry_code + ':EVIL_';

			{ Add the character arc and attitude values. }
			AddXXCharContext( Part , Context , palette_entry_code );

			{ Note whether the NPC is free or in use. }
			NID := NAttValue( Part^.NA , NAG_Narrative , NAS_NID );
			Persona := SeekPersona( Adv , NID );
			if ( Persona <> Nil ) and AStringHasBString( SAttValue( Persona^.SA , 'SPECIAL' ) , 'NOPLOTS' ) then Context := Context + ' ' + palette_entry_code + ':INUSE'
			else if PersonaInUse( Adv , NID ) then Context := Context + ' ' + palette_entry_code + ':INUSE'
			else Context := Context + ' ' + palette_entry_code + ':F4USE';

			{ If this NPC is a mission-giver, note that here. }
			if NAttValue( Part^.NA , NAG_CharDescription , NAS_NonMissionGiver ) = 0 then Context := Context + ' ' + palette_entry_code + ':MAJOR';

			{ See if the NPC is ready for action. }
			if GB <> Nil then begin
				if GB^.ComTime >= NAttValue( Part^.NA , NAG_Personal , NAS_PlotRecharge ) then begin
					Context := Context + ' ' + palette_entry_code + ':READY';
				end;
			end;

			if NotAnAnimal( Part ) then Context := Context + ' ' + palette_entry_code + ':CHARA'
			else Context := Context + ' ' + palette_entry_code + ':BEAST';


		end else if Part^.G = GG_Faction then begin
			{ Add the plot arc value. }
			AddFactionPlanContext( Part , Context , palette_entry_code );

		end else if Part^.G = GG_Scene then begin
			m2 := SAttValue( Part^.SA , 'TERRAIN' );
			if m2 <> '' then Context := Context + ' ' + palette_entry_code + ':' + m2;
		end;

		if IsArchEnemy( Adv , Part ) then Context := Context + ' ' + palette_entry_code + ':ENEMY';
		if IsArchAlly( Adv , Part ) then Context := Context + ' ' + palette_entry_code + ':ALLY_';

	end else begin
		Context := Context + ' ' + palette_entry_code + ':--';

	end;
end;

Procedure AddElementContext( GB: GameBoardPtr; Story: GearPtr; var Context: String; palette_entry_code: Char; Element_Num: Integer );
	{ Add the context details for element T of STORY. }
var
	IsMetaScene: Boolean;
	Adv,E: GearPtr;
	msg: String;
begin
	IsMetaScene := False;
	Adv := FindRoot( Story );

	{ If this element is a scene, tell whether it's a regular scene }
	{ or a metascene. }
	msg := SAttValue( Story^.SA , 'ELEMENT' + BStr( Element_Num ) );
	if ( msg <> '' ) and ( UpCase( msg[1] ) = 'S' ) then begin
		if ElementID( Story , Element_Num ) >= 0 then begin
			Context := Context + ' ' + palette_entry_code + ':perm';
		end else begin
			Context := Context + ' ' + palette_entry_code + ':meta';
			IsMetaScene := True;
		end;
	end;

	E := SeekPlotElement( Adv , Story , Element_Num , GB );
	if ( E = Nil ) and IsMetaScene and ( FindSceneEntrance( Adv , GB , ElementID( Story , Element_Num ) ) <> Nil ) then begin
		Context := Context + ' ' + palette_entry_code + ':++';
	end else begin
		AddGearXRContext( GB , Adv , E , Context , palette_entry_code );
	end;
end;

Function DifficulcyContext( Threat: Integer ): String;
	{ Return a string describing this difficulcy level. }
begin
	if Threat > 80 then begin
		DifficulcyContext := '!Ex';
	end else if Threat > 60 then begin
		DifficulcyContext := '!Hi';
	end else if Threat > 40 then begin
		DifficulcyContext := '!Md';
	end else if Threat > 20 then begin
		DifficulcyContext := '!Lo';
	end else begin
		DifficulcyContext := '!Ne';
	end;
end;

Function StoryPlotRequest( Story: GearPtr ): String;
	{ Return the plotrequest to be used by this story. The plot request }
	{ depends on the provided XXRAN_PATTERN attribute and the dramatic }
	{ choice made by the player. }
var
	it: String;
	C: GearPtr;
begin
	{ Start with the plot request. }
	it := SAttValue( Story^.SA , 'XXRAN_PATTERN' );

	{ Attach the current choice to the plot_request. }
{	C := SeekDramaticChoice( NAttValue( Story^.NA , NAG_XXRan , NAS_DramaticChoice ) );
	if C <> Nil then begin
		it := it + SAttValue( C^.SA , 'DESIG' );
	end else begin
		it := it + 'INTRO';
	end;
}
	StoryPlotRequest := it;
end;

Function StoryContext( GB: GameBoardPtr; Story: GearPtr ): String;
	{ Describe the context of this story in a concise string. }
const
	Merit_Badge_Tag: Array [1..NumMeritBadge] of String = (
		'STAR_', 'CHAMP', '', ''
	);
var
	it,msg: String;
	T: Integer;
	LList: GearPtr;
begin
	{ Start with the basic context. }
	it := StoryPlotRequest( Story ) + ' ' + SAttValue( Story^.SA , 'CONTEXT' );

	{ Add tags for the choices made so far. }
{	LList := Dramatic_Choices;
	while LList <> Nil do begin
		if NAttValue( Story^.NA , NAG_Completed_DC , LList^.V ) > 0 then it := it + ' :' + SAttValue( LList^.SA , 'DESIG' );
		LList := LList^.Next;
	end;
}
	{ Add tags for the merit badges earned by the PC. }
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		{ Use LList to hold the adventure, for now. }
		LList := FindRoot( GB^.Scene );
		for t := 1 to NumMeritBadge do begin
			if ( Merit_Badge_Tag[ t ] <> '' ) and HasMeritBadge( LList , T ) then begin
				it := it + ' C:' + Merit_Badge_Tag[ t ];
			end;
		end;
	end;

	{ Add a description for the difficulcy rating. }
	it := it + ' ' + DifficulcyContext( NAttValue( Story^.NA , NAG_Narrative , NAS_DifficultyLevel ) );

	{ Add the extra random palette entries. }
	if ( Story^.G = GG_Story ) and ( Story^.S = GS_XRANStory ) then begin
		for t := 1 to Num_Plot_Elements do begin
			{ If this element represents to a palette entry, add its info }
			{ to the context. }
			msg := SAttValue( Story^.SA , 'palette_entry_code' + BStr( T ) );
			if msg <> '' then AddElementContext( GB , Story , it , msg[1] , T );
		end;
	end;
	StoryContext := it;
end;



Function FindSceneID( Part: GearPtr; GB: GameBoardPtr ): Integer;
	{ Find the scene number of this gear. Return 0 if no scene }
	{ can be found which contains it. Return the metascene ID }
	{ if the scene is a metascene. }
var
	it: Integer;
	Scene: GearPtr;
begin
	it := 0;

	if Part <> Nil then begin
		{ Move upwards through the tree until either we }
		{ find a scene gear or root level. }
		Scene := Part;
		while ( Scene <> Nil ) and not IsAScene( Scene ) do begin
			Scene := Scene^.Parent;
		end;

		{ If we didn't find the scene, maybe this gear is on the gameboard. }
		if Scene = Nil then begin
			if IsFoundAlongTrack( GB^.Meks , FindRoot( Part ) ) then Scene := GB^.Scene;
		end;

		if Scene <> Nil then begin
			it := RealSceneID( Scene );
		end;
	end;

	FindSceneID := it;
end;

Function SeekFaction( Scene: GearPtr; ID: Integer ): GearPtr;
	{ Look for a faction corresponding to the provided ID number. }
	{ Return NIL if no such faction is found. }
var
	F: GearPtr;
begin
	{ Error check. }
	if ( Scene = Nil ) or ( ID = 0 ) then Exit( Nil );

	{ Find the root of SCENE, which should be the ADVENTURE. }
	{ The faction should be located along the invcoms. }
	F := FindRoot( Scene )^.InvCom;
	while ( F <> Nil ) and (( F^.G <> GG_Faction ) or ( F^.S <> ID )) do F := F^.Next;

	{ If the faction was not in the normal place, call the }
	{ heavy-duty and cycle-wasteful search routine. }
	if F = Nil then F := SeekGear( FindRoot( Scene ) , GG_Faction , ID );
	SeekFaction := F;
end;

Function GetFactionID( Part: GearPtr ): Integer;
	{ This function will return the Faction ID associated with }
	{ any given part, if appropriate. }
	{ FOr a faction this will be it's "S" descriptor. }
	{ For anything else, faction affiliation is stored as a NAtt. }
begin
	if Part = Nil then begin
		GetFactionID := 0;
	end else if Part^.G = GG_Faction then begin
		GetFactionID := Part^.S;
	end else begin
		GetFactionID := NAttValue( Part^.NA , NAG_Personal , NAS_FactionID );
	end;
end;

Function FactionIsInactive( Fac: GearPtr ): Boolean;
	{ Return TRUE if this faction has an INACTIVE tag in its }
	{ TYPE string attribute, or FALSE otherwise. }
begin
	FactionIsInactive := AStringHasBString( SATtValue( Fac^.SA , 'TYPE' ) , 'INACTIVE' );
end;

Function ElementID( Plot: GearPtr; N: Integer ): LongInt;
	{ Return the stored ID number for the requested plot element. }
begin
	ElementID := NAttValue( Plot^.NA , NAG_ElementID , N );
end;

Function PlotElementID( Plot: GearPtr; ID: LongInt ): Integer;
	{ Determine which plot element is referred to by the supplied data. }
	{ ID is the NarrativeID of the element. }
	{ If the supplied ID number cannot be found within this plot, }
	{ return 0. }
var
	t,N: Integer;
begin
	N := 0;

	for t := 1 to Num_Plot_Elements do begin
		if ElementID( Plot , T ) = ID then begin
			N := T;
			break;
		end;
	end;

	PlotElementID := N;
end;

Function FindMetaPersona( Source: GearPtr; N: Integer ): GearPtr;
	{ Locate the replacement persona from this PLOT or STORY. }
begin
	FindMetaPersona := SeekCurrentLevelGear( Source^.SubCom , GG_Persona , N );
end;

Function PlotIsActive( Plot: GearPtr ): Boolean;
	{ Return TRUE if this part is active, or FALSE otherwise. }
begin
	PlotIsActive := ( Plot <> Nil ) and ( Plot^.S = GS_PlotActive );
end;

Function SeekPlotAlongPath( Part: GearPtr; ID: LongInt; NeedsPersona: Boolean ): GearPtr;
	{ Seek a gear which uses the specified element along the given }
	{ path. If no such plot is found return Nil. Recursively search }
	{ all active subcomponents. }
var
	it: GearPtr;
begin
	it := Nil;
	while ( Part <> Nil ) and ( it = Nil ) do begin
		if ( Part^.G = GG_Story ) or ( Part^.G = GG_Faction ) then begin
			it := SeekPlotALongPath( Part^.InvCom , ID , NeedsPersona );

		end else if ( Part^.G = GG_Plot ) and PlotIsActive( Part ) then begin
			it := SeekPlotAlongPath( Part^.InvCom , ID , NeedsPersona );

			if ( it = Nil ) and ( PlotElementID( Part , ID ) <> 0 ) then begin
				if NeedsPersona then begin
					if FindMetaPersona( Part , PlotElementID( Part , ID ) ) <> Nil then begin
						it := Part;
					end;
				end else begin
					it := Part;
				end;
			end;
		end;

		Part := Part^.Next;
	end;
	SeekPlotAlongPath := it;
end;

Function FindPersonaPlot( Adventure: GearPtr; CID: Integer ): GearPtr;
	{ Search all through ADVENTURE looking for a plot which }
	{ involves PERSONA. If no such plot is found, return NIL. }
begin
	{ Plots should be located along Adventure/InvCom. Plots which }
	{ are not located there are probably sub-plots, so they probably }
	{ don't yet have actors assigned. }
	Adventure := FindRoot( Adventure );
	if ( Adventure = Nil ) or ( Adventure^.G <> GG_Adventure ) then begin
		FindPersonaPlot := Nil;
	end else begin
		FindPersonaPlot := SeekPlotAlongPath( Adventure^.InvCom , CID , False );
	end;
end;

Function ElementInUse( Scope: GearPtr; ID: LongInt ): Boolean;
	{ See if the listed NID is currently being used by a plot or story, }
	{ including those which are currently dormant. }
var
	PlotFound: Boolean;
begin
	PlotFound := False;
	while ( Scope <> Nil ) and not PlotFound do begin
		if ( Scope^.G = GG_Plot ) or ( Scope^.G = GG_Story ) then begin
			PlotFound := PlotElementID( Scope , ID ) <> 0;
		end;
		if not PlotFound then PlotFound := ElementInUse( Scope^.InvCom , ID );
		if not PlotFound then PlotFound := ElementInUse( Scope^.SubCom , ID );
		Scope := Scope^.Next;
	end;
	ElementInUse := PlotFound;
end;

Function PersonaInUse( Adventure: GearPtr;  ID: LongInt ): Boolean;
	{ Seek a plot, story, or remnant which uses this Character ID. }
	{ Quests aren't checked, making the title of this particular function misleading. }
	{ I should change that sometime. }
begin
	PersonaInUse := ElementInUse( Adventure , ID );
end;


Function FindMetascenePlot( Adventure: GearPtr; MSID: LongInt ): GearPtr;
	{ Locate the plot that uses this metascene. }
begin
	FindMetascenePlot := SeekPlotAlongPath( Adventure^.InvCom , MSID , False );
end;

Function MetaSceneNotInUse( Adventure: GearPtr; MSID: LongInt ): Boolean;
	{ Return TRUE if this metascene is not in use, or FALSE otherwise. }
begin
	MetaSceneNotInUse := not ElementInUse( Adventure , MSID );
end;

Function FindQuestscene( LList: GearPtr; QSID: LongInt ): GearPtr;
	{ Attempt to locate the questscene referenced by MSID. Check LList and }
	{ all of its subcoms. }
var
	MS,T: GearPtr;
	N: Integer;
begin
	MS := Nil;

	while ( LList <> Nil ) and ( MS = Nil ) do begin
		if LList^.G = GG_Plot then begin
			N := PlotElementID( LList , QSID );
			if N > 0 then begin
				T := LList^.SubCom;
				while T <> Nil do begin
					if ( T^.G = GG_MetaScene ) and ( T^.S = N ) then MS := T;	
					T := T^.Next;
				end;
			end;
		end;

		if MS = Nil then MS := FindQuestScene( LList^.SubCom , QSID );
		if MS = Nil then MS := FindQuestScene( LList^.InvCom , QSID );

		LList := LList^.Next;
	end;

	FindQuestscene := MS;
end;

Function FindSceneEntrance( Adventure: GearPtr; GB: GameBoardPtr; MSID: LongInt ): GearPtr;
	{ Attempt to find an entrance for this metascene. }
	Function CheckAlongPath( P: GearPtr ): GearPtr;
	var
		it: GearPtr;
	begin
		it := Nil;
		while ( P <> Nil ) and ( it = Nil ) do begin
			if ( P^.G = GG_MetaTerrain ) and ( P^.Stat[ STAT_Destination ] = MSID ) then begin
				it := P;
			end;
			if it = Nil then it := CheckAlongPath( P^.SubCom );
			if it = Nil then it := CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
		CheckAlongPath := it;
	end;
var
	it: GearPtr;
begin
	it := CheckAlongPath( Adventure );
	if it = Nil then it := CheckAlongPath( GB^.Meks );
	FindSceneEntrance := it;
end;

Function SeekGearByNID( GB: GameBoardPtr; Adventure: GearPtr; NID: LongInt ): GearPtr;
	{ ATtempt to find a gear in either the mecha list or in the }
	{ adventure. Return NIL if no such gear can be found. }
var
	Item: GearPtr;
begin
	{ Error check - no undefined searches!!! }
	if NID = 0 then Exit( Nil );

	if GB <> Nil then begin
		Item := SeekGearByIDTag( GB^.Meks , NAG_Narrative , NAS_NID , NID );
		if Item = Nil then Item := SeekGearByIDTag( FindRoot( GB^.Scene ) , NAG_Narrative , NAS_NID , NID );
	end else begin
		Item := SeekGearByIDTag( FindRoot( Adventure ) , NAG_Narrative , NAS_NID , NID );
	end;
	SeekGearByNID := Item;
end;

Function SeekPlotElement( Adventure , Plot: GearPtr; N: Integer; GB: GameBoardPtr ): GearPtr;
	{ Find the gear referred to in the N'th element of PLOT. }
	{ If no such element may be found return Nil. }
begin
	{ Return the part that was found. }
	SeekPlotElement := SeekGearByNID( GB , Adventure , ElementID( Plot , N ) );
end;

Function SeekPersona( Scene: GearPtr; CID: LongInt ): GearPtr;
	{ Seek the closest persona gear with the provided Character ID. }
	{ If this NPC is involved in a plot, use the persona gear from }
	{ the plot if one is provided. Otherwise, seek the PERSONA }
	{ in the GB/Scene gear. }
var
	Plot,Persona: GearPtr;
	N: Integer;
begin
	Persona := Nil;

	{ Use the persona located in the character's PLOT, if appropriate. }
	Plot := FindPersonaPlot( FindRoot( Scene ) , CID );
	if Plot <> Nil then begin
		{ This character is featured in a plot. The plot may }
		{ well contain a persona for this character to use }
		{ while the plot is in effect. }
		N := PlotElementID( Plot , CID );
		Persona := FindMetaPersona( Plot , N );
	end;

	{ Next two places to look - The current scene, and the }
	{ adventure itself. }
	if Persona = Nil then Persona := SeekGear( Scene , GG_Persona , CID );
	if ( Persona = Nil ) and ( CID > Num_Plot_Elements ) then begin
		Scene := FindRootScene( Scene );
		if Scene <> Nil then Persona := SeekGear( Scene , GG_Persona , CID , False );
	end;


	SeekPersona := Persona;
end;

Function SeekPersona( GB: GameBoardPtr; CID: LongInt ): GearPtr;
	{ Call the above procedure with the scene. }
begin
	SeekPersona := SeekPersona( GB^.Scene , CID );
end;

Function NewNID( Adventure: GearPtr ): LongInt;
	{ Determine a new, unique NID for an item being added to the }
	{ campaign. Again, all IDs come from this procedure, so don't }
	{ worry about pre-existing values. }
var
	it: LongInt;
begin
	Adventure := FindRoot( Adventure );

	it := NAttValue( Adventure^.NA , NAG_Narrative , NAS_MaxNID );

	{ Return the highest value found, +1. }
	SetNAtt( Adventure^.NA , NAG_Narrative , NAS_MaxNID , it + 1 );
	NewNID := it + 1;
end;

Function NewMetaSceneID( Adventure: GearPtr ): LongInt;
	{ Determine a new, unique ID for a metascene entrance point. }
var
	it: LongInt;
begin
	Adventure := FindRoot( Adventure );
	it := NAttValue( Adventure^.NA , NAG_Narrative , NAS_MinMSID ) - 1;
	if it > -100 then it := -100;
	SetNAtt( Adventure^.NA , NAG_Narrative , NAS_MinMSID , it );
	NewMetaSceneID := it;
end;



Function ElementLocation( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
	{ Find the scene number where this element resides. If no such }
	{ scene can be found, return 0. }
var
	E: GearPtr;
begin
	E := SeekPlotElement( Adv, Plot, N , GB );
	ElementLocation := FindSceneID( E , GB );
end;

Function ElementFaction( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
	{ Find the scene number where this element resides. If no such }
	{ scene can be found, return 0. }
var
	E: GearPtr;
begin
	E := SeekPlotElement( Adv, Plot, N , GB );

	ElementFaction := GetFactionID( E );
end;

Function ElementName( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): String;
	{ Find the name of element N. Return an empty string if no such }
	{ element can be found. }
var
	Desc: String;
	Part: GearPtr;
begin
	Desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );

	if Desc <> '' then begin
		if ( UpCase( Desc[1] ) = 'S' ) and ( ElementID( Plot , N ) < 0 ) then begin
			Part := FindSceneEntrance( Adventure , GB , ElementID( Plot , N ) );
		end else begin
			Part := SeekPlotElement( Adventure, Plot, N , GB );
		end;

		if Part <> Nil then begin
			{ If this is a metascene, we don't really want the name of the scene }
			{ itself since that's meaningless. Instead, what we really want is the }
			{ name of the entrance to the scene. }
			ElementName := GearName( Part );
		end else begin
			ElementName := '***ERROR***';
		end;
	end else begin
		ElementName := '***NOT DEFINED***';
	end;
end;

Procedure WriteCampaign( Camp: CampaignPtr; var F: Text );
	{ Output the supplied campaign and all appropriate data to disk. }
var
	Frz: FrozenLocationPtr;
begin
	{ Output GameBoard. }
	if Camp^.GB <> Nil then begin
		writeln( F , Camp^.GB^.MAP_Width );
		writeln( F , Camp^.GB^.MAP_Height );
		writeln( F , Camp^.GB^.ComTime );
		writeln( F , Camp^.GB^.Scale );
		WriteMap( Camp^.GB^.Map , F );

		{ Can't output the scene gear directly, since it'll be outputted }
		{ with the rest of SOURCE later on. Output its reference number. }
		writeln( F , FindGearIndex( Camp^.Source , Camp^.GB^.Scene ) );

		{ Output map contents. }
		WriteCGears( F , Camp^.GB^.Meks );
	end else begin
		{ To indicate that there's no gameboard, i.e. that this is }
		{ an arena campaign saved at the HQ, output a 0. Since there's }
		{ no such thing as a map with 0 width, this value will let the }
		{ loader know that there's no gameboard. Also, by working things }
		{ this way, I ensure that save files from previous versions of GH2 }
		{ are still compatable. Am I brilliant or what? }
		writeln( F , '0' );
	end;

	{ Output frozen maps. }
	Frz := Camp^.Maps;
	while Frz <> Nil do begin
		writeln( F , FROZEN_MAP_CONTINUE );
		writeln( F , Frz^.Name );
		writeln( F , Frz^.MAP_Width );
		writeln( F , Frz^.MAP_Height );
		WriteMap( Frz^.Map , F );
		Frz := Frz^.Next;
	end;

	{ Output frozen map sentinel marker. }
	writeln( F , FROZEN_MAP_SENTINEL );

	{ Output SOURCE. }
	WriteCGears( F , Camp^.Source );
end;

Function ReadCampaign( var F: Text ): CampaignPtr;
	{ Input the campaign and all appropriate data from disk. }
var

	Camp: CampaignPtr;
	SceneIndex: LongInt;
	N: Integer;
	Frz: FrozenLocationPtr;
	W,H: Integer;
begin
	{ Allocate the campaign and the gameboard. }
	Camp := NewCampaign;
	readln( F , W );
	if W > 0 then begin
		readln( F , H );
		Camp^.GB := NewMap( W , H );

		Camp^.GB^.MAP_Width := W;
		Camp^.GB^.MAP_Height := H;

		readln( F , Camp^.GB^.ComTime );
		Camp^.ComTime := Camp^.GB^.ComTime;
		readln( F , Camp^.GB^.Scale );
		Camp^.GB^.Map := ReadMap( F , Camp^.GB^.MAP_Width , Camp^.GB^.MAP_Height );

		{ Read the index of this game board's SCENE gear, and }
		{ remember to set it in the GB structure after SOURCE is loaded. }
		readln( F , SceneIndex );

		{ Read the list of map contents. }
		Camp^.GB^.Meks := ReadCGears( F );

	end else begin
		{ If W=0, this implies that we don't actually have a gameboard. }
		{ Load the rest of the file anyways. }
		Camp^.GB := Nil;
		Camp^.ComTime := 0;
	end;

	{ Read the frozen maps. }
	repeat
		ReadLn( F , N );

		if N = FROZEN_MAP_CONTINUE then begin
			Frz := CreateFrozenLocation( Camp^.Maps );
			ReadLn( F , Frz^.Name );
			ReadLn( F , Frz^.MAP_Width );
			ReadLn( F , Frz^.MAP_Height );
			Frz^.Map := ReadMap( F , Frz^.MAP_Width , Frz^.MAP_Height );
		end;
	until N = FROZEN_MAP_SENTINEL;

	{ Read the source, and set the gameboard's scene. }
	Camp^.Source := ReadCGears( F );
	{ Only set the scene if we have a gameboard. It's possible that we don't. }
	if Camp^.GB <> Nil then Camp^.GB^.Scene := LocateGearByIndex( Camp^.Source , SceneIndex );

	{ Return the restored campaign structure. }
	ReadCampaign := Camp;
end;

Function TeamDescription( Scene,Team: GearPtr ): String;
	{ Create a description for this team. This is to be used }
	{ by the team location routines. }
var
	it: String;
begin
	{ Start with an empty string. }
	it := '';

	if Team <> Nil then begin
		if AreEnemies( Scene, Team^.S , NAV_DefPlayerTeam ) then begin
			it := it + ' enemy';
		end else if AreAllies( Scene , Team^.S , NAV_DefPlayerTeam ) then begin
			it := it + ' ally';
		end;

		it := it + ' ' + AI_Type_Label[ Team^.Stat[ STAT_TeamOrders ] ];

		if Team^.Stat[ STAT_WanderMon ] > 0 then it := it + ' wmon';
	end;

	TeamDescription := it;
end;

Function CreateTeam( Scene: GearPtr; TDesc: String ): GearPtr;
	{ Make a new team corresponding to the description provided. }
var
	Team: GearPtr;
	CMD: String;
	T: Integer;
begin
	Team := NewGear;
	Team^.G := GG_Team;
	Team^.S := NewTeamID( Scene );
	InsertSubCom( Scene , Team );

	{ Set the new team's attributes based upon the remainder of }
	{ the PLACE string. }
	TDesc := UpCase( TDesc );
	while TDesc <> '' do begin
		cmd := ExtractWord( TDesc );

		if cmd = 'ENEMY' then begin
			SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefPlayerTeam , NAV_AreEnemies );
		end else if cmd = 'ALLY' then begin
			SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefPlayerTeam , NAV_AreAllies );

		end else begin
			{ This command may be an AIType. }
			for t := 0 to NumAITypes do begin
				if cmd = AI_Type_Label[ t ] then Team^.Stat[ STAT_TeamOrders ] := t;
			end;
		end;
	end;

	CreateTeam := Team;
end;

Function FindMatchingTeam( Scene: GearPtr; TDesc: String ): GearPtr;
	{ Locate a team which matches the provided description. }
	{ If no such team can be found, return Nil. If more than }
	{ one team is found, return one of them, although there's }
	{ no guarantee which one. }
var
	T,it: GearPtr;
begin
	{ Teams are located as root subcomponents of the scene, }
	{ so look there. }
	T := Scene^.SubCom;

	{ Initialize our search bit to NIL. }
	it := Nil;

	while ( T <> Nil ) and ( it = Nil ) do begin
		if ( T^.G = GG_Team ) and ( T^.S <> NAV_DefPlayerTeam ) and PartMatchesCriteria( TeamDescription( Scene , T ) , TDesc ) then begin
			it := T;
		end;

		T := T^.Next;
	end;

	FindMatchingTeam := it;
end;

Procedure ChooseTeam( NPC , Scene: GearPtr );
	{ Find a team which matches the NPC's needs. }
var
	TeamData: String;
	Team: GearPtr;
begin
	TeamData := SAttValue( NPC^.SA , 'TEAMDATA' );

	{ If we have no teamdata, and the NPC is a prop, just set it to }
	{ team zero. }
	if ( TeamData = '' ) and ( NPC^.G = GG_Prop ) then begin
		SetNAtt( NPC^.NA , NAG_Location , NAS_Team , 0 );

	end else begin
		Team := FindMatchingTeam( Scene , TeamData );

		{ If no matching team was found, create a new team. }
		if Team = Nil then begin
			Team := CreateTeam( Scene , TeamData );
		end;

		{ Store the correct team number in the NPC. }
		SetNAtt( NPC^.NA , NAG_Location , NAS_Team , Team^.S );
	end;
end;


Procedure PutAwayGlobal( GB: GameBoardPtr; var Item: GearPtr );
	{ ITEM is a global gear. It belongs somewhere other than it is. }
	{ IMPORTANT: GB, GB^.SCene, and Item are all defined. }
var
	SID: Integer;
	Scene: GearPtr;
begin
	{ Find this gear's original home scene. }
	SID := NAttValue( Item^.NA , NAG_ParaLocation , NAS_OriginalHome );

	{ Erase the original home data, since we're sending it home now. }
	{ If the gear gets moved again its original home data should be }
	{ reset. }
	SetNAtt( Item^.NA , NAG_ParaLocation , NAS_OriginalHome , 0 );

	{ Put it away there. }
	if SID > 0 then begin
		Scene := FindActualScene( GB , SID );
	end else begin
		Scene := Nil;
	end;

	if Scene <> Nil then begin
		InsertInvCom( Scene , Item );

		{ If inserting a character, better choose a team. }
		if IsMasterGear( Item ) then begin
			ChooseTeam( Item , Scene );
		end;

	end else if GB^.SCene <> Nil then begin
		InsertInvCom( FindRoot( GB^.Scene ) , Item );

	end else begin
		DisposeGear( Item );

	end;
end;

Function RealSceneID( Scene: GearPtr ): Integer;
	{ Given SCENE, return its actual ID value. If this is a MetaScene, }
	{ we have to check its plot. }
	{ Temporary scenes always have an ID of 0. }
var
	it: Integer;
begin
	if ( Scene^.G = GG_MetaScene ) and ( Scene^.Parent <> Nil ) and ( Scene^.Parent^.G = GG_Plot ) and IsSubCom( Scene ) and ( Scene^.S >= 1 ) and ( Scene^.S <= Num_Plot_Elements ) then begin
		it := ElementID( Scene^.Parent , Scene^.S );
	end else if ( Scene^.G = GG_MetaScene ) or IsSubCom( Scene ) then begin
		it := NAttValue( Scene^.NA , NAG_Narrative , NAS_NID );
	end else begin
		it := 0;
	end;
	RealSceneID := it;
end;

Function FindActualScene( Scene: GearPtr; SID: Integer ): GearPtr;
	{ Find the scene with the specified ID. }
	function LookForScene( S: GearPtr ): GearPtr;
		{ Look for the requested scene along this path, }
		{ checking subcoms as well. }
	var
		it: GearPtr;
	begin
		it := Nil;
		while ( S <> Nil ) and ( it = Nil ) do begin
			if ( ( S^.G = GG_Scene ) or ( S^.G = GG_World ) ) and ( NAttValue( S^.NA , NAG_Narrative , NAS_NID ) = SID ) then it := S;
			if it = Nil then it := LookForScene( S^.SubCom );
			S := S^.Next;
		end;
		LookForScene := it;
	end;
var
	Part: GearPtr;
begin
	if Scene = Nil then Exit( Nil );
	Scene := FindRoot( Scene );
	Part := Nil;
	if SID > 0 then begin
		Part := LookForScene( Scene );
	end else if SID < 0 then begin
		Part := SeekGearByNID( Nil , Scene , SID );
	end;
	FindActualScene := Part;
end;

Function FindActualScene( GB: GameBoardPtr; SID: Integer ): GearPtr;
	{ Find the ACTUAL scene with the specified ID, as opposed to any }
	{ temporary scenes which may have the same value. }
begin
	FindActualScene := FindActualScene( GB^.Scene , SID );
end;

Function IsAScene( S: GearPtr ): Boolean;
	{ Return TRUE if S is a scene or metascene, or FALSE otherwise. }
begin
	IsAScene := ( S <> Nil ) and ( ( S^.G = GG_Scene ) or ( S^.G = GG_MetaScene ) );
end;

Function SceneIsTemp( S: GearPtr ): Boolean;
	{ Return TRUE if S is a temporary scene. These include: }
	{ - Metascenes }
	{ - Dynamic Scenes }
begin
	SceneIsTemp := ( S = Nil ) or ( S^.G = GG_MetaScene ) or IsInvCom( S );
end;

Function FindRootScene( S: GearPtr ): GearPtr;
	{ Return the root scene of S. If no root is found, return Nil. }
	{ S should be a scene or metascene connected to the adventure; otherwise, }
	{ expect an error. }
begin
	if S = Nil then Exit( Nil );
	if ( S^.G = GG_MetaScene ) and ( NAttValue( S^.NA , NAG_Narrative , NAS_EntranceScene ) <> 0 ) then S := FindActualScene( FindRoot( S ) , NAttValue( S^.NA , NAG_Narrative , NAS_EntranceScene ) )
	else if IsInvCom( S ) then S := FindActualScene( FindRoot( S ) , NAttValue( S^.NA , NAG_Narrative , NAS_EntranceScene ) );
	while ( S <> Nil ) and not ( ( S^.Parent <> Nil ) and ( S^.Parent^.G <> GG_Scene ) ) do begin
		S := S^.Parent;
	end;
	FindRootScene := S;
end;

Function FindWorld( GB: GameBoardPtr; S: GearPtr ): GearPtr;
	{ Find the world this scene belongs to. }
	{ If no world can be found, return Nil. }
begin
	{ First, find the city this scene belongs to. That should make things easier. }
	S := FindRootScene( S );
	while ( S <> Nil ) and ( S^.G <> GG_World ) do begin
		S := S^.Parent;
	end;
	FindWorld := S;
end;

Procedure DelinkGearForMovement( GB: GameBoardPtr; GearToBeMoved: GearPtr );
	{ Delink the provided gear in preparation for movement to somewhere else. }
var
	Scene,Master: GearPtr;
	SceneID,TID: Integer;
begin
	if NAttValue( GearToBeMoved^.NA , NAG_ParaLocation , NAS_OriginalHome ) = 0 then begin
		SceneID := FindSceneID( GearToBeMoved , GB );
		Scene := FindActualScene( GB , SceneID );
		TID := NAttValue( GearToBeMoved^.NA , NAG_Location , NAS_Team );

		if ( SceneID > 0 ) and ( SCene <> Nil ) then begin
			{ Record team description. }
			SetSATt( GearToBeMoved^.SA , 'TEAMDATA <' + TeamDescription( Scene, LocateTeam( Scene , TID ) ) + '>' );

			{ Record the item's orginal home, if not already done. }
			SetNAtt( GearToBeMoved^.NA , NAG_ParaLocation , NAS_OriginalHome , SceneID );
		end else begin
			SetNAtt( GearToBeMoved^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );
		end;
	end;

	{ Locate the root, if possible. }
	Master := FindRoot( GearToBeMoved );

	{ Delink the gear, if it can be found. }
	if IsSubCom( GearToBeMoved ) then begin
		DelinkGear( GearToBeMoved^.Parent^.SubCom , GearToBeMoved );
	end else if IsInvCom( GearToBeMoved ) then begin
		DelinkGear( GearToBeMoved^.Parent^.InvCom , GearToBeMoved );
	end else if IsFoundAlongTrack( GB^.Meks , GearToBeMoved) then begin
		DelinkGear( GB^.Meks , GearToBeMoved );
	end;

	{ If the root of the gear is on the map, is a mecha, and is temporary, }
	{ get rid of that now. }
	if ( Master <> GearToBeMoved ) and ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , Master ) and ( NAttValue( Master^.NA , NAG_EpisodeData , NAS_Temporary ) <> 0 ) then begin
		RemoveGear( GB^.Meks , Master );
	end;

	{ Remove attributes of the current area. }
	StripNAtt( GearToBeMoved , NAG_Location );
	StripNAtt( GearToBeMoved , NAG_Damage );
	StripNAtt( GearToBeMoved , NAG_WeaponModifier );
	StripNAtt( GearToBeMoved , NAG_Condition );
	StripNAtt( GearToBeMoved , NAG_StatusEffect );
end;

Function KeepPlayingSC( GB: GameBoardPtr ): Boolean;
	{ Check out this scenario and decide whether or not to keep }
	{ playing. Right now, combat will continue as long as there }
	{ is at least one active mek on each team. }
var
	PTeam,ETeam: Integer;		{ Player Team , Enemy Team }
begin
	{ If this scenario is being controlled by a SCENE gear, }
	{ control of when to quit will be handled by the event strings. }
	{ Also, if we have received a QUIT order, stop playing. }

	if gb^.Scene <> Nil then KeepPlayingSC := Not gb^.QuitTheGame
	else if gb^.QuitTheGame then KeepPlayingSC := False
	else begin

		{ Determine the number of player mecha and enemy mecha. }
		PTeam := NumActiveMasters( GB , NAV_DefPlayerTeam );
		ETeam := NumActiveMasters( GB , NAV_DefEnemyTeam );

		KeepPlayingSC := ( PTeam > 0 ) and ( ETeam > 0 );
	end;
end;

Procedure RecordFatality( Camp: CampaignPtr; NPC: GearPtr );
	{ This character has died, and is about to be removed from the campaign. }
	{ Record the death, and also record any special things about this NPC. }
var
	Relationship: Integer;
begin
	AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_TotalFatalities , 1 );
	Relationship := NAttValue( NPC^.NA , NAG_Relationship , 0 );
	case Relationship of
		NAV_Family: 	AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_FamilyFatalities , 1 );
		NAV_Lover: 	AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_LoverFatalities , 1 );
		NAV_Friend:	AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_FriendFatalities , 1 );
	end;
	Relationship := NAttValue( NPC^.NA , NAG_Location , NAS_Team );
	if ( Relationship = NAV_DefPlayerTeam ) or ( Relationship = NAV_LancemateTeam ) then begin
		AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_LancemateFatalities , 1 );
	end;
end;

Function HasMeritBadge( Adv: GearPtr; Badge: Integer ): Boolean;
	{ Return TRUE if the current PC has the requested merit badge or its }
	{ equivalent ability, FALSE if not. }
begin
	Adv := FindRoot( Adv );
	HasMeritBadge := NAttValue( Adv^.NA , NAG_MeritBadge , Badge ) <> 0;
end;

Function LocatePC( GB: GameBoardPtr ): GearPtr;
	{ Attempt to find the player character. If there's more than one }
	{ master on Team 1, return one of them. }
var
	Bits,PC,Pilot: GearPtr;
	XPScore,HiXP: LongInt;
begin
	{ Begin the search... }
	PC := Nil;

	if GB <> Nil then begin
		Bits := GB^.Meks;
		while ( Bits <> Nil ) do begin
			if ( NAttValue( Bits^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and IsMasterGear( Bits ) and OnTheMap( GB , Bits ) and GearOperational( Bits ) then begin
				Pilot := LocatePilot( Bits );
				if ( PC = Nil ) and ( Pilot <> Nil ) then begin
					PC := Bits;
					HiXP := NattValue( Pilot^.NA , NAG_Experience , NAS_TotalXP );
				end else if Pilot <> Nil then begin
					XPScore := NattValue( Pilot^.NA , NAG_Experience , NAS_TotalXP );
					if XPScore > HiXP then begin
						PC := Bits;
						HiXP := XPScore;
					end;
				end;
			end;
			Bits := Bits^.Next;
		end;
	end;

	{ If the PC can't be found on the map, search again... }
	{ This time take any Team1 master that has a pilot. }
	if PC = Nil then begin
		Bits := GB^.Meks;
		while ( Bits <> Nil ) and ( PC = Nil ) do begin
			if ( NAttValue( Bits^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and IsMasterGear( Bits ) and ( LocatePilot( Bits ) <> Nil ) then begin
				PC := Bits;
			end;
			Bits := Bits^.Next;
		end;
	end;

	LocatePC := PC;
end;

Function SceneName( GB: GameBoardPtr; ID: Integer; Exact: Boolean ): String;
	{ Find the name of the scene with the given ID. If no such }
	{ scene can be found, return a value that should let the player }
	{ know an error has been commited. }
	{ If EXACT=TRUE, use the EXACT_NAME attribute instead of the }
	{ regular name. The reason for this is that sometimes there's }
	{ some ambiguity with the common name of a scene: if I say "Cayley }
	{ Rock", do I mean the city in general or the main station }
	{ specifically? }
var
	msg: String;
	Part: GearPtr;
begin
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then begin
		SceneName := 'XXX';
	end else begin
		{ Look for the scene along the subcomponents of the }
		{ adventure. This is to make sure we don't accidentally }
		{ pick a dynamic scene with the right ID. }
		{ Also, if we have a metascene instead of a regular scene, then }
		{ we want the name of the entrance instead of the name of the }
		{ scene itself. }
		if ID > 0 then begin
			Part := FindActualScene( GB , ID );
		end else begin
			Part := FindSceneEntrance( FindRoot( GB^.Scene ) , GB , ID );
		end;
		if Exact then begin
			msg := SAttValue( Part^.SA , 'EXACT_NAME' );
			if msg = '' then msg := GearName( Part );
			SceneName := msg;
		end else begin
			SceneName := GearName( Part );
		end;
	end;
end;

Function FactionRankName( GB: GameBoardPtr; Source: GearPtr; FID,FRank: Integer ): String;
	{ Return the generic name of rank FRank from faction FID. }
var
	F: GearPtr;
	it: String;
begin
	{ First find the faction. }
	F := SeekFaction( GB^.Scene , FID );

	{ Do range checking on the FRank score obtained. }
	if FRank < 0 then FRank := 0
	else if FRank > 8 then FRank := 8;

	{ If no faction was found, return the default rank title. }
	if F = Nil then begin
		it := MSgString( 'FacRank_' + BStr( FRank ) );
	end else begin
		{ First check the faction for a name there. }
		{ If the faction has no name set, use the default. }
		it := SAttValue( F^.SA , 'FacRank_' + BStr( FRank ) );
		if it = '' then it := MSgString( 'FacRank_' + BStr( FRank ) );
	end;

	FactionRankName := it;
end;

Function PCRankName( GB: GameBoardPtr; Source: GearPtr ): String;
	{ Return the name of the PC's rank with the PC's faction. }
	{ if the PC has no rank, return the basic string. }
var
	FID: Integer;
	A,F: GearPtr;
begin
	{ The PC's faction ID is located in the adventure gear, so }
	{ locate that first. }
	A := FindRoot( GB^.Scene );
	if A <> Nil then begin
		{ The faction rank score is located in the faction itself. }
		{ So now, let's locate that. }
		FID := NAttValue( A^.NA , NAG_Personal , NAS_FactionID );
		F := SeekFaction( A , FID );
		if F <> Nil then begin
			{ Call the general Faction Rank function. }
			PCRankName := FactionRankName( GB , Source , FID , NAttValue( A^.NA , NAG_Experience , NAS_FacLevel ) );
		end else begin
			{ No faction found. Return the default value. }
			PCRankName := MsgSTring( 'FACRANK_0' );
		end;
	end else begin
		{ Adventure not found. Return default "peon". }
		PCRankName := MsgSTring( 'FACRANK_0' );
	end;
end;


end.
