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

Var
	Sub_Plot_List: GearPtr;

Function NewPlotID( Adv: GearPtr ): LongInt;
	{ Calculate a new unique Plot ID. }
begin
	{ Increase the previous ID by one, and return that. }
	AddNAtt( Adv^.NA , NAG_Narrative , NAS_MaxPlotID , 1 );
	NewPlotID := NAttValue( Adv^.NA , NAG_Narrative , NAS_MaxPlotID );
end;

Function NewLayerID( Slot: GearPtr ): LongInt;
	{ Calculate a new unique Layer ID. }
begin
	{ Increase the previous ID by one, and return that. }
	AddNAtt( Slot^.NA , NAG_Narrative , NAS_MaxPlotLayer , 1 );
	NewLayerID := NAttValue( Slot^.NA , NAG_Narrative , NAS_MaxPlotLayer );
end;

Procedure ClearElementTable( var ET: ElementTable );
	{ Clear this table's stored elements by setting all IDs }
	{ to zero. }
var
	t: Integer;
begin
	for t := 1 to Num_Plot_Elements do begin
		ET[t].EValue := 0;
	end;
end;

Procedure CreatePlotPlaceholder( Slot , Shard: GearPtr );
	{ Create a new plot gear to hold all of SHARD's elements, and store it }
	{ in SLOT. IT will be marked with SHARD's PlotID, and this marking will be }
	{ used to dispose of all the placeholders after assembly. }
var
	it: GearPtr;
	T: Integer;
	EID: LongInt;
begin
	it := NewGear( Slot );
	InsertInvCom( Slot , It );
	it^.G := GG_Plot;
	SetNAtt( it^.NA , NAG_Narrative , NAS_PlotID , NAttValue( Shard^.NA , NAG_Narrative , NAS_PlotID ) );
	for t := 1 to Num_Plot_Elements do begin
		EID := ElementID( Shard , T );
		if EID <> 0 then begin
			SetNAtt( It^.NA , NAG_ElementID , T , EID );
			SetSAtt( It^.SA , 'ELEMENT' + BStr( T ) + ' <' + SAttValue( Shard^.SA , 'ELEMENT' + BStr( T ) ) + '>' );
		end;
	end;
end;

Function AddSubPlot( GB: GameBoardPtr; Slot,Plot0: GearPtr; SPReq: String; EsSoFar, PlotID, LayerID: LongInt ): GearPtr; forward;

Function InitShard( GB: GameBoardPtr; Slot,Shard: GearPtr; EsSoFar,PlotID,LayerID: LongInt; const ParamIn: ElementTable ): GearPtr;
	{ SHARD is a plot fragment candidate. Attempt to add it to the Slot. }
	{ Attempt to add its subplots as well. }
	{ SHARD can only be added if its number of new elements plus the current }
	{ element total is less than the number of total possible elements. }
	{ EsSoFar is the number of elements allocated so far. }
	{ Before initializing a shard, the following will be done: }
	{ - Parameter elements copied over }
	{ - Any character gears present will be randomized }
	{ Upon successfully initializing a shard, this procedure will then do the following: }
	{ - Delink the shard from the Slot, and attach all subplots. }
	{ - Create a plot stub and mark it with the PlotID; copy over all elements used by }
	{   this shard and place it as Slot's invcom. This stub is to prevent other shards }
	{   from selecting characters or items used here. }
	{ - Return the shard list }
	{ If installation fails, SHARD will be deleted and NIL will be returned. }
var
	InitOK: Boolean;
	T,NumParam,NumElem: Integer;
	I,SubPlot,SPList: GearPtr;
	cash,SPID: LongInt;
	SPReq: String;
begin
	{ Assign the values to this shard. }
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_PlotID , PlotID );
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_LayerID , LayerID );

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
	InitOK := InsertStory( Slot, Shard , GB );

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
					SPID := NewLayerID( Slot );
					SetNAtt( Shard^.NA , NAG_SubPlotLayerID , T , SPID );
					SubPlot := AddSubPlot( GB , Slot , Shard , SPReq , NumElem , PlotID , SPID );
					if SubPlot <> Nil then begin
						{ A subplot was correctly installed. Add it to the list. }
						AppendGear( SPList , SubPlot );
						NumElem := NumElem + NAttValue( SubPlot^.NA , NAG_Narrative , NAS_NumSPElementsUsed );
					end else begin
						{ The subplot request failed, meaning that this shard fails }
						{ as well. }
						InitOK := False;
						RemoveGear( Slot^.InvCom , Shard );
						Break;
					end;
				end;
			end;

		end else begin
			{ We have too many elements to merge back into the main plot. }
			InitOk := False;
			RemoveGear( Slot^.InvCom , Shard );
		end;
	end;

	{ Return our result. }
	if InitOk then begin
		{ Delink the shard. }
		DelinkGear( Slot^.InvCom , Shard );

		{ Create the plot placeholder stub, to prevent characters from being }
		{ selected by different parts of the same superplot. }
		CreatePlotPlaceholder( Slot , Shard );

		{ Append the SPList to the shard. }
		AppendGear( Shard , SPList );

		SetNAtt( Shard^.NA , NAG_Narrative , NAS_NumSPElementsUsed , NumElem - EsSoFar );
		InitShard := Shard;
	end else begin
		DisposeGear( SPList );
		InitShard := Nil;
	end;
end;

Function AddSubPlot( GB: GameBoardPtr; Slot,Plot0: GearPtr; SPReq: String; EsSoFar, PlotID, LayerID: LongInt ): GearPtr;
	{ A request has been issued for a subplot. Search through the plot }
	{ component list and see if there's anything that matches our criteria. }
	{ Plot0 must not be Nil. }
var
	ShoppingList: NAttPtr;
	Context,EDesc: String;
	ParamList: ElementTable;
	T,E: Integer;
	Shard: GearPtr;
	NotFoundMatch: Boolean;
begin
	{ Start by determining the context. }
	Context := ExtractWord( SPReq );
	if Slot^.G = GG_Story then Context := Context + ' ' + StoryContext( GB , Slot );

	{ Determine the parameters to be sent, and add context info for them. }
	ClearElementTable( ParamList );
	T := 1;
	while ( SPReq <> '' ) and ( T <= Num_Plot_Elements ) do begin
		E := ExtractValue( SPReq );
		if ( E >= 1 ) and ( E <= Num_Plot_Elements ) then begin
			{ This element is being shared with the subplot. }
			ParamList[t].EValue := ElementID( Plot0 , T );
			EDesc := SAttValue( Plot0^.SA , 'ELEMENT' + BStr( T ) );
			if EDesc <> '' then ParamList[t].EType := EDesc[1];
			AddElementContext( GB , Plot0 , Context , BStr( T )[1] , T );
			Inc( T );
		end;
	end;

	{ We have the context. Create the shopping list. }
	ShoppingList := CreateComponentList( Sub_Plot_List , Context );

	{ Based on this shopping list, search for applocable subplots and attempt to }
	{ fit them into the adventure. }
	NotFoundMatch := True;
	Shard := Nil;
	while ( ShoppingList = Nil ) and NotFoundMatch do begin
		Shard := CloneGear( SelectComponentFromList( Sub_Plot_List , ShoppingList ) );
		if Shard <> Nil then begin
			{ See if we can add this one to the list. If not, it will be }
			{ deleted by InitShard. }
			Shard := InitShard( GB , Slot , Shard , EsSoFar , PlotID , LayerID , ParamList );
			if Shard <> Nil then NotFoundMatch := False;
		end;
	end;

	{ Get rid of the shopping list. }
	DisposeNAtt( ShoppingList );

	{ Return our selected subplot. }
	AddSubPlot := Shard;
end;

Procedure AssembleMegaPlot( Slot , SPList: GearPtr );
	{ SPList is a list of subplots. Assemble them into a single coherent megaplot. }
	{ The first item in the list is the base plot- all other plots get added to it. }
	{ - Delete all placeholder stubs from SLOT }
	{ - Process each fragment in turn. }
	{   - Delink from list }
	{   - Do string substitutions }
	{   - Combine plot scripts, personas, and metascenes via megalist }
	{   - Combine metascene contents }
	{   - Set element PLACE attributes }
	{ - Insert the finished plot into slot }
begin

end;

Procedure DeployPlot();
	{ Actually add the plot to the adventure. Set it in place, move any elements as }
	{ requested. }
begin

end;

Function InitMegaPlot( GB: GameBoardPtr; Slot,Plot: GearPtr ): GearPtr;
	{ We've just been handed a prospective megaplot. }
	{ Create all subplots, and initialize everything. }
	{ 1 - Create list of components }
	{ 2 - Merge all components into single plot }
var
	SPList: GearPtr;
	PlotID,LayerID: LongInt;
	FakeParams: ElementTable;
begin
	{ The plot we've been handed will serve as the base component. The first thing }
	{ to do, then, is to initialize it via the InitShard procedure. This will also }
	{ give us a list of subplots. If InitShard fails, PLOT will be deleted. }
	{ First, we need to clear SLOT's current Plot Layer ID to start fresh, then }
	{ request a new later ID from Slot and a Plot ID from the adventure. }
	PlotID := NewPlotID( FindRoot( Slot ) );
	SetNAtt( Slot^.NA , NAG_Narrative , NAS_MaxPlotLayer , 0 );
	LayerID := NewLayerID( Slot );

	ClearElementTable( FakeParams );
	SPList := InitShard( GB , Slot , Plot , 0 , PlotID , LayerID , FakeParams );

	{ Now that we have the list, assemble it. }
	if SPList <> Nil then begin
		AssembleMegaPlot( Slot , SPList );
	end;

	InitMegaPlot := SPList;
end;

initialization
	{ Load the list of subplots from disk. }
	Sub_Plot_List := LoadRandomSceneContent( 'MEGA_*.txt' , series_directory );


finalization
	{ Dispose of the list of subplots. }
	DisposeGear( Sub_Plot_List );

end.
