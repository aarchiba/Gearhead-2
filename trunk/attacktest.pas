program attacktest;

uses	gears,gearutil,locale,gearparser,effects,randmaps,ghchars,ghweapon,texutil,ghintrinsic,ability,movement,action;

const
	Tar_X = 9;
	Tar_Y = 8;

	Num_Trials = 2000;

var
	results: SAttPtr;


Function TestAttack( GB: GameBoardPtr; AMaster,Attacker,Target: GearPtr; AtOp: Integer ): LongInt;
	{ Run this attack a lot of times, and see how long it takes to destroy }
	{ the target. }
var
	T,TT,N: LongInt;
	Dmg,Total: LongInt;
begin
	Total := 0;
	StripNAtt( FindRoot( Attacker ) , NAG_Damage );
	StripNAtt( FindRoot( Target ) , NAG_Damage );
	for T := 1 to Num_Trials do begin
		{ See how many attacks it takes before the target is destroyed. }
		N := 0;

		{ Prep the target. }
		SetNAtt( Target^.NA , NAG_Action , NAS_MoveMode , MM_Skim );
		PrepAction( GB , Target , NAV_NormSpeed );

		repeat
			DoAttack( GB , Attacker , Target , Tar_X , Tar_Y , 0 , AtOp );

			StripNAtt( AMaster , NAG_Condition );
			StripNAtt( AMaster , NAG_Damage );
			StripNAtt( AMaster , NAG_WeaponModifier );
			Inc( N );
		until ( N > 50 ) or not GearActive( Target );

		Total := Total + N;

		{ Delete the damage from the target for the next runthrough. }
		StripNAtt( FindRoot( Target ) , NAG_Condition );
		StripNAtt( FindRoot( Target ) , NAG_Damage );
		StripNAtt( FindRoot( Target ) , NAG_WeaponModifier );
	end;
	TestAttack := Total div Num_Trials;
end;

Procedure TestThings( GB: GameBoardPtr; AMaster , Hand , Target: GearPtr; TestWeapon: String );
	{ Test the requested weapon. }
var
	Attacker: GearPtr;
	TTK: LongInt;	{ Times To Kill }
begin
	Attacker := LoadNewSTC( TestWeapon );
	if Attacker = Nil then begin
		StoreSAtt( results, TestWeapon + ' not found!' );
	end else begin
		InsertInvCom( Hand , Attacker );
		TTK := TestAttack( GB , AMaster , Attacker , Target , Attacker^.Stat[ STAT_BurstValue ] );
		StoreSAtt( Results, TestWeapon + ': ' + BStr( TTK ) + '  ($' + BStr( GearValue( Attacker ) ) + ')' );
		RemoveGear( Hand^.InvCom , Attacker );
		writeln( TestWeapon + ' done.' );
	end;
end;


var
	GB: GameBoardPtr;
	Scene,Hand,AMaster,Target,Pilot,CP: GearPtr;


begin
	{ For the attacker and defender, load some nice SAN-D1 Daums. }
	{ Install a generic pilot in each. }
	AMaster := LoadNewItem( 'SAN-D1 Daum' );
	CP := SeekGear( AMaster , GG_CockPit , 0 );
	if CP <> Nil then begin
		Pilot := LoadNewNPC( 'Mecha Pilot' , FALSE );
		SetSkillsAtLevel( Pilot , 50 );
		SetNAtt( Pilot^.NA , NAG_Intrinsic , NAS_Integral , 1 );
		InsertSubCom( CP , Pilot );
	end;
	Target := SeekGearByName( AMaster , 'Bolt Cannon' )^.Parent;
	if Target <> Nil then begin
		Hand := Target^.Parent;
		while Hand^.InvCom <> Nil do begin
			Target := Hand^.InvCom;
			RemoveGear( Hand^.InvCom , Target );
		end;
	end else begin
		writeln( 'ERROR: No Bolt Cannon found.' );
	end;

	Target := LoadNewItem( 'SAN-D1 Daum' );
	CP := SeekGear( Target , GG_CockPit , 0 );
	if CP <> Nil then begin
		Pilot := LoadNewNPC( 'Mecha Pilot' , FALSE );
		SetSkillsAtLevel( Pilot , 50 );
		SetNAtt( Pilot^.NA , NAG_Intrinsic , NAS_Integral , 1 );
		InsertSubCom( CP , Pilot );
	end;

	Scene := LoadNewSTC( 'SCENE_EmptyBuilding' );
	GB := RandomMap( Scene );
	AppendGear( GB^.Meks , AMaster );
	AppendGear( GB^.Meks , Target );

	SetNAtt( AMaster^.NA , NAG_Location , NAS_X , Tar_X - 5 );
	SetNAtt( AMaster^.NA , NAG_Location , NAS_Y , Tar_Y );
	SetNAtt( Target^.NA , NAG_Location , NAS_X , Tar_X );
	SetNAtt( Target^.NA , NAG_Location , NAS_Y , Tar_Y );

	results := Nil;

	TestThings( GB , AMaster , Hand , Target , 'GR-12' );
	TestThings( GB , AMaster , Hand , Target , 'GR-24' );
	TestThings( GB , AMaster , Hand , Target , 'MAC-4' );
	TestThings( GB , AMaster , Hand , Target , 'RG-8' );
	TestThings( GB , AMaster , Hand , Target , 'RG-16' );
	TestThings( GB , AMaster , Hand , Target , 'MAC-2' );
	TestThings( GB , AMaster , Hand , Target , 'VC-5' );
	TestThings( GB , AMaster , Hand , Target , 'SC-9' );
	TestThings( GB , AMaster , Hand , Target , 'MB-7' );
	TestThings( GB , AMaster , Hand , Target , 'MBAZ-17' );
	TestThings( GB , AMaster , Hand , Target , 'MRIF-5' );
	TestThings( GB , AMaster , Hand , Target , 'PAR-2' );
	TestThings( GB , AMaster , Hand , Target , 'PAR-6' );
	TestThings( GB , AMaster , Hand , Target , 'PAR-13' );
	TestThings( GB , AMaster , Hand , Target , 'PHS-8' );
	TestThings( GB , AMaster , Hand , Target , 'PHS-25' );


	SaveStringList( 'atest_out.txt' , results );

	DisposeSAtt( results );
	DisposeMap( GB );
end.
