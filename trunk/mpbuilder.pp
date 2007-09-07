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
{$LONGSTRINGS ON}

interface

uses gears,locale;

Function ComponentMenu( CList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;
Function InitMegaPlot( GB: GameBoardPtr; Slot,Plot: GearPtr; Threat: Integer ): GearPtr;


implementation

{$IFDEF ASCII}
uses narration,playwright,texutil,gearutil,gearparser,ghchars,randmaps,vidgfx,
	ui4gh,vidmenus;
{$ELSE}
uses narration,playwright,texutil,gearutil,gearparser,ghchars,randmaps,glgfx,
	ui4gh,glmenus;
{$ENDIF}

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

Procedure ComponentMenuRedraw;
	{ The redraw for the component selector below. }
begin
	ClrScreen;
	InfoBox( ZONE_Menu );
	InfoBox( ZONE_Info );
	InfoBox( ZONE_Caption );
	GameMsg( 'Select the next component in the core story.', ZONE_Caption , StdWhite );
	RedrawConsole;
end;

Function ComponentMenu( CList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;
	{ Select one of the components from a menu. }
var
	RPM: RPGMenuPtr;
	C: GearPtr;
	N: Integer;
	SL: NAttPtr;
begin
	RPM := CreateRPGMenu( MenuItem, MenuSelect , ZONE_Menu );
	AttachMenuDesc( RPM , ZONE_Info );
	SL := ShoppingList;
	while SL <> Nil do begin
		C := RetrieveGearSib( CList , SL^.S );
		AddRPGMenuItem( RPM , '[' + BStr( SL^.V ) + ']' + GearName( C ) , SL^.S , SAttValue( C^.SA , 'DESC' ) );
		SL := SL^.Next;
	end;

	N := SelectMenu( RPM , @ComponentMenuRedraw );
	SetNAtt( ShoppingList , 0 , N , 0 );
	DisposeRPGMenu( RPM );
	ComponentMenu := RetrieveGearSib( CList , N );
end;

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

Procedure DeletePlotPlaceholders( Slot: GearPtr; PlotID: LongInt );
	{ Delete all the plot placeholders. They should be invcoms of SLOT, }
	{ and be marked with the listed PlotID. }
var
	PP,PP2: GearPtr;
begin
	PP := Slot^.InvCom;
	while PP <> Nil do begin
		PP2 := PP^.Next;
		if NAttValue( PP^.NA , NAG_Narrative , NAS_PlotID ) = PlotID then RemoveGear( Slot^.InvCom , PP );
		PP := PP2;
	end;
end;

Function AddSubPlot( GB: GameBoardPtr; Slot,Plot0: GearPtr; SPReq: String; EsSoFar, PlotID, LayerID: LongInt ): GearPtr; forward;

Function InitShard( GB: GameBoardPtr; Slot,Shard: GearPtr; EsSoFar,PlotID,LayerID,Threat: LongInt; const ParamIn: ElementTable ): GearPtr;
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
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_PlotLayer , LayerID );
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_PlotDifficulcy , Threat );

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
		end;
		I := I^.Next;
	end;

	{ Initialize the subplot list to prevent trouble later on. }
	SPList := Nil;

	{ Attempt the basic content insertion routine. }
	InitOK := InsertSubPlot( Slot, Shard , GB );

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

		if NumElem <= Num_Plot_Elements then begin
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
			if XXRan_Debug then begin
				DialogMsg( 'ERROR: ' + GearName( Shard ) + ' has too many elements: ' + BStr( NumElem ) + ' / ' + BStr( EsSoFar ) );
				for t := 1 to Num_Plot_Elements do begin
					DialogMsg( ' ' + BStr( T ) + ' ' + SAttValue( Shard^.SA , 'NAME_' + BStr( T ) ) + ' ' + BStr( ElementID( Shard , T ) ) );
				end;
			end;
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
			ParamList[t].EValue := ElementID( Plot0 , E );
			EDesc := SAttValue( Plot0^.SA , 'ELEMENT' + BStr( E ) );
			if EDesc <> '' then ParamList[t].EType := EDesc[1];
			AddElementContext( GB , Plot0 , Context , BStr( T )[1] , E );
			Inc( T );
		end;
	end;

	{ We have the context. Create the shopping list. }
	ShoppingList := CreateComponentList( Sub_Plot_List , Context );

	{ Based on this shopping list, search for applocable subplots and attempt to }
	{ fit them into the adventure. }
	NotFoundMatch := True;
	Shard := Nil;
	while ( ShoppingList <> Nil ) and NotFoundMatch do begin
		if XXRan_Wizard and ( ShoppingList <> Nil ) and ( Slot^.G = GG_Story ) then begin
			DialogMsg( Context );
			Shard := CloneGear( ComponentMenu( Sub_Plot_List , ShoppingList ) );
		end else begin
			Shard := CloneGear( SelectComponentFromList( Sub_Plot_List , ShoppingList ) );
		end;
		if Shard <> Nil then begin
			{ See if we can add this one to the list. If not, it will be }
			{ deleted by InitShard. }
			Shard := InitShard( GB , Slot , Shard , EsSoFar , PlotID , LayerID , NAttValue( Plot0^.NA , NAG_Narrative , NAS_PlotDifficulcy ) , ParamList );
			if Shard <> Nil then NotFoundMatch := False;
		end;
	end;

	{ Get rid of the shopping list. }
	DisposeNAtt( ShoppingList );

	{ Return our selected subplot. }
	AddSubPlot := Shard;
end;

Procedure ReplaceStrings( Part: GearPtr; Dictionary: SAttPtr );
	{ We have a dictionary of substitute strings, and a part to do the replacements on. }
var
	S: SAttPtr;
	P,P2: Integer;
	SPat,SRep: String;
begin
	S := Part^.SA;
	while S <> Nil do begin
		P := 1;
		while P < Length( S^.Info ) do begin
			if ( S^.Info[P] = '%' ) and ( P < ( Length( S^.Info ) - 1 ) ) then begin
				{ We've found a hash. This could be a replacement string. See what string it is. }
				SPat := '%';
				P2 := P;
				repeat
					Inc( P2 );
					SPat := SPat + S^.Info[P2];
				until ( P2 >= Length( S^.Info ) ) or ( S^.Info[P2] = '%' );

				{ We now have a string that may very well be something we want to replace. Check it. }
				SRep := SAttValue( Dictionary , SPat );
				if SRep <> '' then begin
					{ The pattern was found in the dictionary. Replace all instances of it. }
					ReplacePat( S^.Info , SPat , SRep );
					P := P + Length( SRep ) - 1;
				end;
			end;

			Inc( P );
		end;

		S := S^.Next;
	end;
end;

Procedure InitListStrings( LList: GearPtr; Dictionary: SAttPtr );
	{ Run LList, all of its siblings and children, through the ReplaceStrings }
	{ procedure. }
begin
	while LList <> Nil do begin
		ReplaceStrings( LList , Dictionary );
		InitListStrings( LList^.SubCom , Dictionary );
		InitListStrings( LList^.InvCom , Dictionary );
		LList := LList^.Next;
	end;
end;

Procedure MergeElementLists( MasterPlot , SubPlot: GearPtr );
	{ The element list of SUBPLOT should be merged into MASTERPLOT. }
	{ If a SUBPLOT element is found in MASTERPLOT already, no need }
	{ to merge. Store the master plot element indicies in SubPlot. }
	{ Also copy the PLACE strings here. }
var
	FirstFreeSlot,T,PlotIndex: Integer;
	EID: LongInt;
	EDesc: String;
	Dictionary: SAttPtr;
begin
	{ Locate the first free slot in MasterPlot. }
	FirstFreeSlot := 1;
	While ( FirstFreeSlot <= Num_Plot_Elements ) and ( ElementID( MasterPlot , FirstFreeSlot ) <> 0 ) do Inc( FirstFreeSlot );
	Dictionary := Nil;

	{ Go through the elements of SubPlot. Check to see if they are found in }
	{ MasterPlot. If so, do nothing. If not, add them. }
	for T := 1 to Num_Plot_Elements do begin
		EID := ElementID( SubPlot , T );
		if EID <> 0 then begin
			EDesc := SAttValue( SubPlot^.SA , 'ELEMENT' + BStr( T ) );
			PlotIndex := PlotElementID( MasterPlot , EDesc[1] , EID );
			if PlotIndex = 0 then begin
				{ This element apparently doesn't currently have a }
				{ place in this plot. Add it. }
				PlotIndex := FirstFreeSlot;
				Inc( FirstFreeSlot );
				SetNAtt( MasterPlot^.NA , NAG_ElementID , PlotIndex , EID );
				SetSAtt( MasterPlot^.SA , 'ELEMENT' + BStr( PlotIndex ) + ' <' + EDesc + '>' );
			end;

			{ We should now have a working PlotIndex. Save it in SubPlot, }
			{ and copy over the PLACE to MasterPlot. }
			SetNAtt( SubPlot^.NA , NAG_MasterPlotElementIndex , T , PlotIndex );
			SetSAtt( Dictionary , '%e' + BStr( T ) + '% <' + BStr( PlotIndex ) + '>' );
		end;
	end;

	InitListStrings( SubPlot , Dictionary );
	DisposeSAtt( Dictionary );

	{ After initializing the strings, do one more loop to copy over the PLACE info. }
	for T := 1 to Num_Plot_Elements do begin
		EID := ElementID( SubPlot , T );
		if EID <> 0 then begin
			PlotIndex := NAttValue( SubPlot^.NA , NAG_MasterPlotElementIndex , T );
			EDesc := SAttValue( SubPlot^.SA , 'PLACE' + BStr( T ) );
			if EDesc <> '' then SetSAtt( MasterPlot^.SA , 'PLACE' + BStr( PlotIndex ) + ' <' + EDesc + '>' );
		end;
	end;
end;

Procedure MergePersona( MainPlot , SubPlot , Persona: GearPtr );
	{ We have a persona that needs to be merged into the main plot. }
	{ If the main plot already has a persona for this character, merge }
	{ this new persona in as a megalist. If no persona currently exists, }
	{ delink this persona from MainPlot and stick in SubPlot. }
var
	MPIndex: Integer;
	MainPersona: GearPtr;
begin
	{ Determine the index of this element in the main plot. }
	MPIndex := NAttValue( SubPlot^.NA , NAG_MasterPlotElementIndex , Persona^.S );

	{ Attempt to locate the main persona. }
	MainPersona := SeekCurrentLevelGear( MainPlot^.SubCom , GG_Persona , MPIndex );
	if MainPersona = Nil then begin
		{ No main persona- create one. }
		MainPersona := LoadNewSTC( 'PERSONA_BLANK' );
		InsertSubCom( MainPlot , MainPersona );
		SetSAtt( MainPersona^.SA , 'SPECIAL <' + SAttValue( Persona^.SA , 'SPECIAL' ) + '>' );
		MainPersona^.S := MPIndex;
	end;

	{ Combine the two plots together. }
	BuildMegalist( MainPersona , Persona^.SA );
end;

Procedure MergeMetascene( MainPlot , SubPlot , MS: GearPtr );
	{ Combine the sub-metascene with the main metascene. }
	{ If no main metascene exists, simply move and relabel the }
	{ one provided here. }
var
	MPIndex: Integer;
	MainScene,Thing: GearPtr;
begin
	{ Determine the index of this element in the main plot. }
	MPIndex := NAttValue( SubPlot^.NA , NAG_MasterPlotElementIndex , MS^.S );

	{ Attempt to locate the main metascene. }
	MainScene := SeekCurrentLevelGear( MainPlot^.SubCom , GG_MetaScene , MPIndex );
	if MainScene = Nil then begin
		{ No main scene- delink, move, and relabel this one. }
		DelinkGear( SubPlot^.SubCom , MS );
		InsertSubCom( MainPlot , MS );
		MS^.S := MPIndex;
	end else begin
		{ Combine the two scenes together. }
		BuildMegalist( MainScene , MS^.SA );

		{ Copy over all InvComs and SubComs. }
		while ( MS^.InvCom <> Nil ) do begin
			Thing := MS^.InvCom;
			DelinkGear( MS^.InvCom , Thing );
			InsertInvCom( MainScene , Thing );
		end;
		while ( MS^.SubCom <> Nil ) do begin
			Thing := MS^.SubCom;
			DelinkGear( MS^.SubCom , Thing );
			InsertSubCom( MainScene , Thing );
		end;
	end;
end;

Procedure CombinePlots( MasterPlot, SubPlot: GearPtr );
	{ Combine SubPlot into MasterPlot, including all elements, scripts, }
	{ personas, metascenes, and so on. }
	{ - Merge element lists }
	{ - Copy PLACE strings from SUBPLOT to MASTERPLOT. }
	{   A place defined in a subplot take precedence over anything }
	{   defined earlier. }
	{ - Megalist scripts }
	{ - Megalist personas }
	{ - Combine MetaScenes }
	{ - Move InvComs }
	{ - Add victory points }
var
	Thing,T2: GearPtr;
begin
	MergeElementLists( MasterPlot , SubPlot );
	BuildMegalist( MasterPlot , SubPlot^.SA );

	{ Combine the plot points. }
	MasterPlot^.V := MasterPlot^.V + SubPlot^.V;

	{ Take a look at the things in this subplot. }
	{ Deal with them separately, as appropriate. }
	Thing := SubPlot^.SubCom;
	while Thing <> Nil do begin
		T2 := Thing^.Next;

		if Thing^.G = GG_Persona then begin
			MergePersona( MasterPlot , SubPlot , Thing );
		end else if Thing^.G = GG_MetaScene then begin
			MergeMetascene( MasterPlot , SubPlot , Thing );
		end;

		Thing := T2;
	end;

	{ Move over the InvComs. }
	while SubPlot^.InvCom <> Nil do begin
		Thing := SubPlot^.InvCom;
		DelinkGear( SubPlot^.InvCom , Thing );
		InsertInvCom( MasterPlot , Thing );
	end;
end;


Function AssembleMegaPlot( Slot , SPList: GearPtr; PlotID: LongInt ): GearPtr;
	{ SPList is a list of subplots. Assemble them into a single coherent megaplot. }
	{ The first item in the list is the base plot- all other plots get added to it. }
	{ - Delete all placeholder stubs from SLOT }
	{ - Process each fragment in turn. }
	{   - Delink from list }
	{   - Do string substitutions }
	{   - Combine plots }
	{ - Insert the finished plot into slot }
	Procedure DoStringSubstitutions( SubPlot: GearPtr );
		{ Do the string substitutions for this subplot. Basically, }
		{ create the dictionary and pass it on to the substituter. }
	var
		Dictionary: SAttPtr;
		T: Integer;
	begin
		{ Begin creating. }
		Dictionary := Nil;
		SetSAtt( Dictionary , '%plotid% <' + BStr( PlotID ) + '>' );
		SetSAtt( Dictionary , '%id% <' + BStr( NAttValue( SubPlot^.NA , NAG_Narrative , NAS_PlotLayer ) ) + '>' );
		SetSAtt( Dictionary , '%threat% <' + BStr( NAttValue( SubPlot^.NA , NAG_Narrative , NAS_PlotDifficulcy ) ) + '>' );
		for t := 1 to Num_Sub_Plots do begin
			SetSAtt( Dictionary , '%id' + BStr( T ) + '% <' + Bstr( NAttValue( SubPlot^.NA , NAG_SubPlotLayerID , T ) ) + '>' );
		end;
		for t := 1 to Num_Plot_Elements do begin
			{ If dealing with the main plot, do substitutions for the Element Indicies now. }
			if SubPlot = SPList then SetSAtt( Dictionary , '%E' + BStr( T ) + '% <' + BStr( T ) + '>' );
			SetSAtt( Dictionary , '%' + BStr( T ) + '% <' + BStr( ElementID( SubPlot , T ) ) + '>' );
			SetSAtt( Dictionary , '%name' + BStr( T ) + '% <' + SAttValue( SubPlot^.SA , 'name_' + BStr( T ) ) + '>' );
		end;

		{ Run the provided subplot through the convertor. }
		InitListStrings( SubPlot , Dictionary );
		DisposeSAtt( Dictionary );
	end;
var
	MasterPlot,SubPlot: GearPtr;
begin
	{ Delete the placeholders. }
	DeletePlotPlaceholders( Slot , PlotID );

	{ Extract the master plot. It should be the first one in the list. }
	MasterPlot := SPList;
	DelinkGear( SPList , MasterPlot );
	DoStringSubstitutions( MasterPlot );
	InsertInvCom( Slot , MasterPlot );

	{ Keep processing until we run out of subplots. }
	while SPList <> Nil do begin
		SubPlot := SPList;
		DelinkGear( SPList , SubPlot );
		DoStringSubstitutions( SubPlot );
		CombinePlots( MasterPlot, SubPlot );
		DisposeGear( SubPlot );
	end;

	{ Return the finished plot. }
	AssembleMegaPlot := MasterPlot;
end;

Procedure MoveElements( GB: GameBoardPtr; Plot: GearPtr );
	{ There are a bunch of elements in this plot. Some of them need to be moved. }
	{ Make it so. }
var
	T,PlaceIndex: Integer;
	PlaceCmd,EDesc,TeamName,DebugRec: String;
	Element,Dest,MF,Team: GearPtr;
	InSceneNotElement: Boolean;
	EID: LongInt;
begin
	for t := 1 to Num_Plot_ELements do begin
		PlaceCmd := SAttValue( Plot^.SA , 'PLACE' + BStr( T ) );
		if PlaceCmd <> '' then begin
			DebugRec := PlaceCmd;
			EDesc := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if ( EDesc <> '' ) and ( UpCase( EDesc[1] ) = 'S' ) then begin
				{ I can't believe you just asked me to move a scene... }
				{ What you really must want is for me to move an encounter }
				{ attached to a metascene. Yeah, that must be it. }
				EID := ElementID( Plot , T );
				if EID < 0 then begin
					Element := FindSceneEntrance( FindRoot( GB^.Scene ) , GB , EID );
				end else begin
					Element := Nil;
				end;
			end else begin
				{ Just find the regular element. }
				Element := SeekPlotElement( FindRoot( GB^.Scene ) , Plot , T , GB );
			end;

			if Element = Nil then begin
				DialogMsg( 'ERROR- Element ' + BStr( T ) + ' of ' + GearName( Plot ) + ' not found for movement.' );
				Exit;
			end;

			{ Next, delink the gear for movement... but there's a catch. }
			{ We don't want the delinker to give our element an OriginalHome }
			{ if it's a prefab element, because we want to do that ourselves }
			{ now in a bit. }
			if ( Element^.Parent <> Nil ) and ( Element^.Parent^.G = GG_Plot ) and IsInvCom( Element ) then begin
				DelinkGear( Element^.Parent^.InvCom , Element );
			end else begin
				DelinkGearForMovement( GB , Element );
			end;

			InSceneNotElement := ( PlaceCmd[1] = '~' );
			if InSceneNotElement then DeleteFirstChar( PlaceCmd );

			PlaceIndex := ExtractValue( PlaceCmd );
			Dest := SeekPlotElement( FindRoot( GB^.Scene ) , Plot , PlaceIndex , GB );

			TeamName := RetrieveBracketString( PlaceCmd );

			if InSceneNotElement and (( Dest = Nil ) or ( Dest^.G <> GG_Scene )) then begin
				{ If the destination is a metascene, locate its entrance. }
				if ( Dest = Nil ) or ( Dest^.G = GG_MetaScene ) then begin
					Dest := FindSceneEntrance( FindRoot( GB^.Scene ) , GB , ElementID( Plot , PlaceIndex ) );
				end;

				{ Try to find the associated scene now. }
				if Dest <> Nil then begin
					Dest := FindActualScene( GB , FindGearScene( Dest , GB ) );
				end;
			end;

			if ( Dest <> Nil ) then begin
				if ( Dest^.G <> GG_Scene ) and ( Dest^.G <> GG_MetaScene ) and IsLegalInvCom( Dest , Element ) then begin
					{ If E can be an InvCom of Dest, stick it there. }
					InsertInvCom( Dest , Element );
				end else begin
					{ If Dest isn't a scene, find the scene DEST is in itself }
					{ and stick E in there. }
					while ( Dest <> Nil ) and ( not IsAScene( Dest ) ) do Dest := Dest^.Parent;

					if IsMasterGear( Element ) then begin
						if TeamName <> '' then begin
							Team := SeekChildByName( Dest , TeamName );
							if ( Team <> Nil ) and ( Team^.G = GG_Team ) then begin
								SetNAtt( Element^.NA , NAG_Location , NAS_Team , Team^.S );
							end else begin
								ChooseTeam( Element , Dest );
							end;
						end else begin
							ChooseTeam( Element , Dest );
						end;
					end;

					{ If a Metascene map feature has been defined as this element's home, }
					{ stick it there instead of in the scene proper. Such an element will }
					{ always be MiniMap component #1, so set that value here too. }
					if ( Dest^.G = GG_MetaScene ) then begin
						MF := SeekGearByDesig( Dest^.SubCom , 'HOME ' + BStr( T ) );
						if MF <> Nil then begin
							Dest := MF;
							SetNAtt( Element^.NA , NAG_ComponentDesc , NAS_ELementID , 1 );
						end;
					end;

					{ If this is a prefab element and we're deploying }
					{ to a metascene, assign an OriginalHome value of -1 }
					{ to make sure it doesn't get deleted when the plot }
					{ ends. }
					if NAttValue( Element^.NA , NAG_ParaLocation , NAS_OriginalHome ) = 0 then begin
						if Dest^.G = GG_MetaScene then SetNAtt( Element^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );
					end;

					if Dest = GB^.Scene then begin
						DeployMek( GB , Element , True );
					end else begin
						InsertInvCom( Dest , Element );
					end;
				end;
			end else begin
				DialogMsg( 'ERROR: Destination not found for ' + GearName( Element ) + '/' + GearName( Plot )  + ' PI:' + BStr( PlaceIndex ) );
				DialogMsg( DebugRec );
				InsertInvCom( Plot , Element );
			end;
		end;
	end;
end;

Procedure DeployPlot( GB: GameBoardPtr; Slot,Plot: GearPtr );
	{ Actually add the plot to the adventure. Set it in place, move any elements as }
	{ requested. }
	{ - Insert persona fragments as needed }
	{ - Deploy elements as indicated by PLACE strings }
begin
	PrepAllPersonas( FindRoot( GB^.Scene ) , Plot , GB , NAttValue( Slot^.NA , NAG_Narrative , NAS_MaxPlotLayer ) + 1 );

	MoveElements( GB , Plot );

	PrepMetascenes( FindRoot( GB^.Scene ) , Plot , GB );
end;

Function InitMegaPlot( GB: GameBoardPtr; Slot,Plot: GearPtr; Threat: Integer ): GearPtr;
	{ We've just been handed a prospective megaplot. }
	{ Create all subplots, and initialize everything. }
	{ 1 - Create list of components }
	{ 2 - Merge all components into single plot }
	{ 3 - Insert persona fragments }
	{ 4 - Deploy elements as indicated by PLACE strings }
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
	SPList := InitShard( GB , Slot , Plot , 0 , PlotID , LayerID , Threat , FakeParams );

	{ Now that we have the list, assemble it. }
	if SPList <> Nil then begin
		Plot := AssembleMegaPlot( Slot , SPList , PlotID );
		DeployPlot( GB , Slot , Plot );
	end;

	InitMegaPlot := SPList;
end;

Procedure InitPlaceStrings();
	{ Initialize all the place strings of the standard subplots. }
	{ To be comprehended, place strings need to point to the master plot }
	{ element slot, but for human readability it's better to point them }
	{ at the subplot element slot. This procedure converts any subplot }
	{ element slots to master plot slot references. }
var
	P: GearPtr;
	T: Integer;
	PlaceCmd,DestSlot: String;
	HasTilde: Boolean;
begin
	P :=  Sub_Plot_List;
	while P <> Nil do begin
		for t := 1 to Num_Plot_Elements do begin
			PlaceCmd := SAttValue( P^.SA , 'PLACE' + BStr( T ) );
			DeleteWhiteSpace( PlaceCmd );
			if PlaceCmd <> '' then begin
				if PlaceCmd[1] = '~' then begin
					HasTilde := True;
					DeleteFirstChar( PlaceCmd );
				end else HasTilde := False;

				if PlaceCmd[1] <> '%' then begin
					DestSlot := ExtractWord( PlaceCmd );
					PlaceCmd := '%e' + DestSlot + '% ' +PlaceCmd;
				end;
				if HasTilde then PlaceCmd := '~' + PlaceCmd;
				SetSAtt( P^.SA , 'PLACE' + BStr( T ) + ' <' + PlaceCmd + '>' );
			end;
		end;
		P := P^.Next;
	end;
end;

initialization
	{ Load the list of subplots from disk. }
	Sub_Plot_List := LoadRandomSceneContent( 'MEGA_*.txt' , series_directory );
	InitPlaceStrings();

finalization
	{ Dispose of the list of subplots. }
	DisposeGear( Sub_Plot_List );

end.
