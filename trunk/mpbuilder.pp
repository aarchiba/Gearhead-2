unit questbuilder;
	{ This unit contains the functions and procedures for creating }
	{ big amalgamations of components. }
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

interface

uses gears,locale;

implementation

uses narration,playwright,texutil;

Type
	ElementDesc = Record
		EType: Char;
		EValue: LongInt;
	end;
	{ I feel just like Dmitri Mendelev writing this... }
	ElementTable = Array [1..Num_Plot_Elements] of ElementDesc;

Function InitShard( GB: GameBoardPtr; Adv,Story,Shard: GearPtr; PlotID,LayerID: LongInt; const ParamIn: ElementTable ): GearPtr;
	{ SHARD is a plot fragment candidate. Attempt to add it to the story. }
	{ Attempt to add its subplots as well. }
	{ SHARD can only be added if its number of new elements plus the current }
	{ element total is less than the number of total possible elements. }
	{ Before initializing a shard, the following will be done: }
	{ - Parameter elements copied over }
	{ - Any character gears present will be randomized }
	{ Upon successfully initializing a shard, this procedure will then do the following: }
	{ - Delink the shard from the story, and attach all subplots. }
	{ - Create a plot stub and mark it with the PlotID; copy over all elements used by }
	{   this shard and place it as Story's invcom. This stub is to prevent other shards }
	{   from selecting characters or items used here. }
	{ - Return the shard list }
var
	InitOK: Boolean;
	T: Integer;
	I: GearPtr;
begin
	{ Start by copying over all provided parameters. }
	for t := 1 to Num_Plot_Elements do begin
		if ParamIn[ t ].EValue <> 0 then begin
			SetNAtt( Shard^.NA , NAG_ElementID , T , ParamIn[ t ].EValue );
			SetSAtt( Shard^.SA , 'ELEMENT' + BStr( T ) + ' <' + ParamIn[ t ].EType + '>' );
		end;
	end;

	{ Next, randomize the NPCs. }
	I := Shard^.InvCom;
	while I <> Nil do begin
		{ Character gears have to be individualized. }
		if ( I^.G = GG_Character ) and NotAnAnimal( I ) then begin
			IndividualizeNPC( I );
			cash := NAttValue( I^.NA , NAG_Experience , NAS_Credits );
			if cash > 0 then begin
				SetNAtt( I^.NA , NAG_Experience , NAS_Credits , 0 );
				SelectCombatEquipment( I , Standard_Equipment_List , cash );
			end;
		end;
		I := I^.Next;
	end;

	{ Attempt the basic content insertion routine. }
	InitOK := InsertStory( Story, Shard , GB );

	{ If the installation has gone well so far, we need to check for subplots. }
	if InitOK then begin
		{ If any of the needed subplots fail, installation of this shard fails }
		{ as well. }

	end;

	{ Return our result. }
	InitShard := InitOK;
end;

Procedure InitMegaPlot( Story,Plot: GearPtr );
	{ We've just been handed a prospective megaplot. }
	{ Create all subplots, and initialize everything. }
	{ 1 - Create list of components }
	{ 2 - Merge all components into single plot }
begin

end;

end.
