unit mpbuilder;
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

uses narration,playwright,texutil,gearutil,gearparser,ghchars;

Type
	ElementDesc = Record
		EType: Char;
		EValue: LongInt;
	end;
	{ I feel just like Dmitri Mendelev writing this... }
	ElementTable = Array [1..Num_Plot_Elements] of ElementDesc;

Const
	Num_Sub_Plots = 8;

Function NewLayerID( Slot: GearPtr ): LongInt;
	{ Calculate a new unique Layer ID. }
begin

end;

Function AddSubPlot( GB: GameBoardPtr; Adv,Story,Plot0: GearPtr; SPReq: String; EsSoFar, PlotID, LayerID: LongInt ): GearPtr; forward;

Function InitShard( GB: GameBoardPtr; Adv,Story,Shard: GearPtr; EsSoFar,PlotID,LayerID: LongInt; const ParamIn: ElementTable ): GearPtr;
	{ SHARD is a plot fragment candidate. Attempt to add it to the story. }
	{ Attempt to add its subplots as well. }
	{ SHARD can only be added if its number of new elements plus the current }
	{ element total is less than the number of total possible elements. }
	{ EsSoFar is the number of elements allocated so far. }
	{ Before initializing a shard, the following will be done: }
	{ - Parameter elements copied over }
	{ - Any character gears present will be randomized }
	{ Upon successfully initializing a shard, this procedure will then do the following: }
	{ - Delink the shard from the story, and attach all subplots. }
	{ - Create a plot stub and mark it with the PlotID; copy over all elements used by }
	{   this shard and place it as Story's invcom. This stub is to prevent other shards }
	{   from selecting characters or items used here. }
	{ - Return the shard list }
	{ If installation fails, SHARD will be deleted and NIL will be returned. }
var
	InitOK: Boolean;
	T,NumParam,NumElem: Integer;
	I,SubPlot,SPList: GearPtr;
	cash: LongInt;
	SPReq: String;
begin
	{ Start by copying over all provided parameters. }
	{ Also count the number of parameters passed; it could be useful. }
	NumParam := 0;
	for t := 1 to Num_Plot_Elements do begin
		if ParamIn[ t ].EValue <> 0 then begin
			SetNAtt( Shard^.NA , NAG_ElementID , T , ParamIn[ t ].EValue );
			SetSAtt( Shard^.SA , 'ELEMENT' + BStr( T ) + ' <' + ParamIn[ t ].EType + '>' );
			Inc( NumParam );
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

	{ Initialize the subplot list to prevent trouble later on. }
	SPList := Nil;

	{ Attempt the basic content insertion routine. }
	InitOK := InsertStory( Story, Shard , GB );

	{ If the installation has gone well so far, time to move on. }
	if InitOK then begin
		{ Count the number of unique elements. If more elements have been }
		{ defined than will fit in a single plot, then loading of this subplot }
		{ will fail. }
		NumElem := 0;
		for t := 1 to Num_Plot_Elements do begin
			if NAttValue( Shard^.NA , NAG_ElementID , T  ) <> 0 then begin
				Inc( NumElem );
			end;
		end;
		NumElem := NumElem - NumParam + EsSoFar;

		if ( NumElem + EsSoFar ) <= Num_Plot_Elements then begin
			{ We have room for the elements. Good. Now move on by installing the subplots. }

			{ If any of the needed subplots fail, installation of this shard fails }
			{ as well. }
			for t := 1 to Num_Sub_Plots do begin
				SPReq := SAttValue( Shard^.SA , 'SUBPLOT' + BStr( T ) );
				if SPReq <> '' then begin
					SubPlot := AddSubPlot( GB , Adv , Story , Shard , SPReq , NumElem , PlotID , NewLayerID( Story ) );
					if SubPlot <> Nil then begin
						{ A subplot was correctly installed. Add it to the list. }
						AppendGear( SPList , SubPlot );
						NumElem := NumElem + NAttValue( SubPlot^.NA , NAG_Narrative , NAS_NumSPElementsUsed );
					end else begin
						{ The subplot request failed, meaning that this shard fails }
						{ as well. }
						InitOK := False;
					end;
				end;
			end;
		end else begin
			{ We have too many elements to merge back into the main plot. }
			InitOk := False;
			RemoveGear( Story^.InvCom , Shard );
		end;
	end;

	{ Return our result. }
	if InitOk then begin
		SetNAtt( Shard^.NA , NAG_Narrative , NAS_NumSPElementsUsed , NumElem );
		InitShard := Shard;
	end else begin
		DisposeGear( SPList );
		InitShard := Nil;
	end;
end;

Function AddSubPlot( GB: GameBoardPtr; Adv,Story,Plot0: GearPtr; SPReq: String; EsSoFar, PlotID, LayerID: LongInt ): GearPtr;

begin

end;

Procedure InitMegaPlot( Story,Plot: GearPtr );
	{ We've just been handed a prospective megaplot. }
	{ Create all subplots, and initialize everything. }
	{ 1 - Create list of components }
	{ 2 - Merge all components into single plot }
begin

end;

end.
