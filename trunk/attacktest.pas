program attacktest;

uses	gears,gearutil,locale,gearparser,effects,randmaps,ghchars,ghweapon,texutil;

const
	Tar_X = 9;
	Tar_Y = 8;

	Num_Trials = 20000;

var
	results: SAttPtr;

Function AmountOfDamage( Part: GearPtr ): LongInt;

var
	it: LongInt;
	SP: GearPtr;
begin
	it := 0;
	if Part <> Nil then begin
		it := it + NAttValue( Part^.NA , NAG_Damage , NAS_StrucDamage );
		SP := Part^.SubCom;
		while SP <> Nil do begin
			it := it + AmountOfDamage( SP );
			SP := SP^.Next;
		end;
		SP := Part^.InvCom;
		while SP <> Nil do begin
			it := it + AmountOfDamage( SP );
			SP := SP^.Next;
		end;
	end;
	AmountOfDamage := it;
end;

Function TestAttack( GB: GameBoardPtr; AMaster,Attacker,Target: GearPtr; SkLvl: Integer; UseSpotWeakness: Boolean ): LongInt;
	{ Run this attack a lot of times, and return the average damage done. }
var
	T,TT: LongInt;
	Dmg,Total: LongInt;
begin
	Total := 0;
	StripNAtt( FindRoot( Attacker ) , NAG_Damage );
	StripNAtt( FindRoot( Target ) , NAG_Damage );
	for T := 1 to Num_Trials do begin
		for tt := 1 to NumSkill do begin
			SetNAtt( AMaster^.NA , NAG_Skill , TT , SkLvl );
			SetNAtt( Target^.NA , NAG_Skill , TT , 7 );
		end;
		if not UseSpotWeakness then SetNAtt( AMaster^.NA , NAG_Skill , 18 , 0 );

		DoAttack( GB , Attacker , Target , Tar_X , Tar_Y , 0 , 0 );

		{ Measure the damage done. }
		Dmg := AmountOfDamage( Target );
		Total := Total + Dmg;

		{ Delete the damage from both attacker and target. }
		StripNAtt( FindRoot( Attacker ) , NAG_Condition );
		StripNAtt( FindRoot( Target ) , NAG_Condition );
		StripNAtt( FindRoot( Attacker ) , NAG_Damage );
		StripNAtt( FindRoot( Target ) , NAG_Damage );
		StripNAtt( FindRoot( Attacker ) , NAG_WeaponModifier );
		StripNAtt( FindRoot( Target ) , NAG_WeaponModifier );
	end;
	TestAttack := Total div Num_Trials;
end;

Procedure TestThings( GB: GameBoardPtr; AMaster , Target: GearPtr; SkLvl: LongInt; UseSpotWeakness: Boolean );
	{ Test Armed Combat vs Martial Arts at the requested skill level. }
var
	Attacker: GearPtr;
	Dmg: LongInt;
begin
	Attacker := SeekGearByName( AMaster^.SubCom , 'Night Scythe' );
	if Attacker = Nil then StoreSAtt( results, 'Night Scythe not found!' );
	Dmg := TestAttack( GB , AMaster , Attacker , Target , SkLvl , UseSpotWeakness );
	StoreSAtt( Results, 'Night Scythe at ' + BStr( SkLvl ) + ': ' + BStr( Dmg ) );

	Attacker := SeekGearByName( AMaster^.SubCom , 'arm' );
	if Attacker = Nil then StoreSAtt( results, 'Arm not found!' );
	Dmg := TestAttack( GB , AMaster , Attacker , Target , SkLvl , UseSpotWeakness );
	StoreSAtt( Results, 'Martial Arts at ' + BStr( SkLvl ) + ': ' + BStr( Dmg ) );
end;


var
	GB: GameBoardPtr;
	Scene,AMaster,Target: GearPtr;


begin
	AMaster := LoadNewMonster( 'Assassin Lord' );
	SetSAtt( AMaster^.SA , 'JOB <Assassin>' );
	Target := LoadNewMonster( 'Hunter-Destroyer' );
	Scene := LoadNewSTC( 'SCENE_EmptyBuilding' );
	GB := RandomMap( Scene );
	AppendGear( GB^.Meks , AMaster );
	AppendGear( GB^.Meks , Target );
	SetNAtt( AMaster^.NA , NAG_Location , NAS_X , Tar_X - 1 );
	SetNAtt( AMaster^.NA , NAG_Location , NAS_Y , Tar_Y );
	SetNAtt( Target^.NA , NAG_Location , NAS_X , Tar_X );
	SetNAtt( Target^.NA , NAG_Location , NAS_Y , Tar_Y );

	results := Nil;

	SetNAtt( AMaster^.NA , NAG_Talent , NAS_KungFu , 1 );
	SetNAtt( AMaster^.NA , NAG_Talent , 23 , 0 );

	TestThings( GB , AMaster , Target , 5 , True );
	TestThings( GB , AMaster , Target , 10 , True );
	TestThings( GB , AMaster , Target , 15 , True );
	TestThings( GB , AMaster , Target , 20 , True );

	SaveStringList( 'out.txt' , results );

	DisposeSAtt( results );
	DisposeMap( GB );
end.
