class NightmareGoat extends GGMutator;

var array<NightmareGoatComponent> mComponents;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local NightmareGoatComponent nightComp;

	super.ModifyPlayer( other );

	goat = GGGoat( other );
	if( goat != none )
	{
		nightComp=NightmareGoatComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'NightmareGoatComponent', goat.mCachedSlotNr));
		if(nightComp != none && mComponents.Find(nightComp) == INDEX_NONE)
		{
			mComponents.AddItem(nightComp);
		}
	}
}

simulated event Tick( float delta )
{
	local int i;

	for( i = 0; i < mComponents.Length; i++ )
	{
		mComponents[ i ].Tick( delta );
	}
	super.Tick( delta );
}

DefaultProperties
{
	mMutatorComponentClass=class'NightmareGoatComponent'
}