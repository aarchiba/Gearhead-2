unit ghprop;
	{ What do props do? Well, not much by themselves... But they }
	{ can be used to make buildings, safes, machinery, or whatever }
	{ else you can think to do with them. }

	{ Metaterrain acts basically like terrain- it can hinder movement or block line }
	{ of sight. As a gear, it can have scripts associated with it. }
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

uses texutil,gears,uiconfig;

	{ PROP DEFINITION }
	{ G => GG_Prop }
	{ S => Prop Behavior }
	{ V => Prop Size; translates to mass and damage. }

	{ METATERRAIN DEFINITION }
	{ G => GG_MetaTerrain }
	{ S => Specific Type, 0 = Generic }
	{ V => Terrain Size; translates to armor and damage. }
	{         if MetaTerrain V = 0, cannot be destroyed. }


const
	{ Please note that a metaterrain gear does not need to have }
	{ its "S" value within the 1..NumBasicMetaTerrain range, }
	{ but those which do lie within this range will be initialized }
	{ with the default scripts. }

	{ *** MAP FEATURE DEFINITION *** }
	{ G = GG_MapFeature              }
	{ S = Feature Type               }
	{ V = Feature Value              }

	MapFeatureMaxWidth = 25;
	MapFeatureMaxHeight = 15;
	MapFeatureMinDimension = 5;


Procedure CheckPropRange( Part: GearPtr );

Procedure InitMetaTerrain( Part: GearPtr );
Procedure InitMapFeature( Part: GearPtr );

Function RandomBuildingName( B: GearPtr ): String;

implementation



Procedure CheckPropRange( Part: GearPtr );
	{ Examine the various bits of this gear to make sure everything }
	{ is all nice and legal. }
begin
	{ Check V - Size Category }
	if Part^.V < 1 then Part^.V := 1
	else if Part^.V > 100 then Part^.V := 100;


end;

Procedure InitMetaTerrain( Part: GearPtr );
	{ Initialize this metaterrain gear for a nice default example of }
	{ the terrain type it's supposed to represent. }
var
	MT_RogueChar: Array [1..NumBasicMetaTerrain] of char = (
		'+', '*', '/', '\', '!',
		'_', '%', '?', '%', '&',
		'*'
	);
begin
	{ If this is a part for which we have a standard script, }
	{ install that script now. }
	if ( Part^.S >= 1 ) and ( Part^.S <= NumBasicMetaTerrain ) then begin
		SetSAtt( Part^.SA , 'ROGUECHAR <' + MT_RogueChar[ Part^.S ] + '>' );
		SetSAtt( Part^.SA , 'NAME <' + MsgString( 'METATERRAINNAME_' + BStr( Part^.S ) ) + '>' );
	end;

	{ Do part-specific initializations here. }
	if Part^.S = GS_MetaDoor then begin
		{ Begin with the stats for a closed door. }
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 6;
	end else if Part^.S = GS_MetaStairsUp then begin
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 1;
		Part^.Stat[ STAT_Obscurement ] := 1;
	end else if Part^.S = GS_MetaElevator then begin
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 6;
	end else if Part^.S = GS_MetaBuilding then begin
		Part^.Stat[ STAT_Pass ] := -100;
	end else if ( Part^.S = GS_MetaRubble ) or ( Part^.S = GS_MetaSign ) then begin
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 1;
		Part^.Stat[ STAT_Obscurement ] := 1;
	end;
end;

Procedure InitMapFeature( Part: GearPtr );
	{ This procedure does only one thing- if the part has a minimap defined, }
	{ make sure it's at least a 5x5 area. }
begin
	if ( part <> Nil ) and ( SAttValue( Part^.SA , 'MINIMAP' ) <> '' ) then begin
		if Part^.Stat[ STAT_MFWidth ] < 5 then Part^.Stat[ STAT_MFWidth ] := 5;
		if Part^.Stat[ STAT_MFHeight ] < 5 then Part^.Stat[ STAT_MFHeight ] := 5;
	end;
end;

Function RandomBuildingName( B: GearPtr ): String;
	{ Create a random name for the provided building. }
	{ Replace %b with the basic building name. }
	{ Replace %a with an adjective. }
	{ Replace %n with an ordinal number. }
const
	NumNameForms = 3;
	NumAdjectives = 5;
	NumOridinals = 5;
var
	it: String;
begin
	it := MSgString( 'GHPROP_RBN_FORM_' + BStr( Random( NumNameForms ) + 1 ) );
	if B = Nil then begin
		ReplacePat( it , '%b' , 'NoBuildingError' );
	end else begin
		ReplacePat( it , '%b' , SAttValue( B^.SA , 'NAME' ) );
	end;
	ReplacePat( it , '%a' , MSgString( 'GHPROP_RBN_Adjective_' + BStr( Random( NumAdjectives ) + 1 ) ) );
	ReplacePat( it , '%n' , MSgString( 'GHPROP_RBN_Ordinal_' + BStr( Random( NumOridinals ) + 1 ) ) );
	RandomBuildingName := it;
end;


end.
