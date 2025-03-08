class DecorativeFlame extends Actor;

var ParticleSystemComponent fireParticle;

simulated event PostBeginPlay ()
{
	Super.PostBeginPlay();
	
	AttachComponent(fireParticle);
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false
	bIgnoreBaseRotation=true
	
	Begin Object Class=ParticleSystemComponent Name=ParticleSystemComponent0
        Template=ParticleSystem'Goat_Effects.Effects.Effects_Fire_01'
		bAutoActivate=true
		bResetOnDetach=true
		Scale=0.3f
		Translation=(X=0, Y=0, Z=-10)
	End Object
	fireParticle=ParticleSystemComponent0
}