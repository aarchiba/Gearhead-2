program mekcheck;

uses wmonster,gears,gearparser,gearutil,texutil;

var
	Class_Size_Limit: Array [1..10] of LongInt;


Procedure Filter_Mecha_List( var LList: GearPtr );
	{ Check this list. Remove anything that isn't a mecha. }
var
	I, I2: GearPtr;
begin
	I := LList;
	while I <> Nil do begin
		I2 := I^.Next;
		if I^.G <> GG_Mecha then RemoveGear( LList , I );
		I := I2;
	end;
end;

Procedure Examine_Mecha_List( mecha_list: GearPtr; Facs: String );
	{ Examine the mecha list. See how complete its mecha spectrum is. }
var
	Mecha_Graph: Array [1..10,1..3] of Integer;
	mek: GearPtr;
	t,tt,total: Integer;
	mekval: LongInt;
begin
	{ Start by clearing the graph. }
	for t := 1 to 10 do begin
		for tt := 1 to 3 do begin
			Mecha_Graph[ t , tt ] := 0;
		end;
	end;

	{ Next, fill the graph. }
	mek := mecha_list;
	total := 0;
	while mek <> Nil do begin
		if PartAtLeastOneMatch( SAttValue( Mek^.SA , 'FACTIONS' ) , Facs ) then begin
			{ This mecha can be used by this faction. Let's see where it fits. }
			mekval := GearValue( mek );

			t := 1;
			tt := 0;
			while ( tt = 0 ) and ( t < 11 ) do begin
				if mekval <= Class_Size_Limit[ t ] then tt := t;
				Inc( T );
			end;

			if tt <> 0 then begin
				Inc( Mecha_Graph[ tt , 1 ] );
				Inc( Total );
			end;
		end;

		mek := mek^.next;
	end;

	{ Output the graph }
	for t := 1 to 10 do begin
		write( '  ' + WideStr( T , 2 ) + ': ' );
		for tt := 1 to Mecha_Graph[ t , 1 ] do write( '*' );
		writeln();
	end;
	writeln( ' Total: ' , total );
end;

Procedure CalcBARat( llist: GearPtr );
	{ Go through every mecha in LList. Calculate the percentage of mecha cost }
	{ not related to weapons. }
	Function WeaponsOnlyValue( plist: GearPtr ): LongInt;
		{ Return the value of this list's weapons. }
	var
		it: LongInt;
	begin
		it := 0;
		while plist <> Nil do begin
			if plist^.G = GG_Weapon then begin
				it := it + GearCost( plist );
			end else begin
				it := it + WeaponsOnlyValue( plist^.subcom );
				it := it + WeaponsOnlyValue( plist^.invcom );
			end;
			plist := plist^.next;
		end;
		WeaponsOnlyValue := it;
	end;
var
	msg: String;
	tval,wval: LongInt;
	mlist,m: SAttPtr;
begin
	mlist := Nil;
	while llist <> Nil do begin
		tval := GearCost( llist );
		wval := WeaponsOnlyValue( llist^.subcom );
		if wval > tval then wval := tval;

		msg := WideStr( tval - wval , 9 ) + '   ' + FullGearName( llist ) + ': ';
		while Length( msg ) < 45 do msg := msg + ' ';

		msg :=  msg + '%' + BStr( ( ( tval - wval ) * 100 ) div tval );

		StoreSAtt( mlist , msg );
		llist := llist^.next;
	end;

	SortStringList( mlist );
	m := mlist;
	while m <> Nil do begin
		writeln( m^.info );
		m := m^.Next;
	end;
	DisposeSAtt( mlist );
end;


var
	t: Integer;
	mecha_list,F: GearPtr;

begin
	writeln( 'Mecha Class Value Maximums' );
	for t := 1 to 10 do begin
		Class_Size_Limit[ t ] := OptimalMechaValue( t * 10 + 5 ) * 2;
		writeln( '  ' + WideSTr( t , 2 ) , ': ' , OptimalMechaValue( t * 10 - 5 ) , '-' , Class_Size_Limit[ t ] );
	end;

	mecha_list := AggregatePattern( '*.txt' , Design_Directory );
	Filter_Mecha_List( mecha_list );

	writeln();
	writeln( 'General Mecha' );
	Examine_Mecha_List( mecha_list , 'GENERAL' );

	F := Factions_LIst;
	while F <> Nil do begin
		writeln();
		writeln( GearName( F ) + ' Mecha' );
		Examine_Mecha_List( mecha_list , 'GENERAL ' + SAttValue( F^.SA , 'DESIG' ) );

		F := F^.Next;
	end;

	writeln();
	writeln( 'MECHA BODY/ARMAMENT RATING' );
	CalcBARat( mecha_list );

	DisposeGear( mecha_list );
end.
