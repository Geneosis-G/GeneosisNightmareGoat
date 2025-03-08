class TrailFlame extends Actor;

var NightmareGoatComponent nightmareComp;
var ParticleSystemComponent fireParticle;
var float fadeTime;
var float flameRadius;

simulated event PostBeginPlay ()
{
	Super.PostBeginPlay();

	AttachComponent(fireParticle);
	SetTimer( fadeTime, false, NameOf( StopFire ) );
}

function SetNGC(NightmareGoatComponent ngc)
{
	nightmareComp=ngc;
}

function StopFire()
{
	if( IsTimerActive( NameOf( StopFire ) ) )
	{
		ClearTimer( NameOf( StopFire ) );
	}

	if( fireParticle != none )
	{
		fireParticle.DeactivateSystem();
		fireParticle.KillParticlesForced();
	}

	Destroy();
}

function BurnActor(Actor act)
{
	if(nightmareComp == none || act == nightmareComp.gMe || GGPawn(act) == none)
		return;

	nightmareComp.BurnPawn(GGPawn(act));
}

event Touch( Actor other, PrimitiveComponent otherComp, vector hitLoc, vector hitNormal )
{
	//WorldInfo.Game.Broadcast(self, self $ " Touch");
	BurnActor(other);
}

DefaultProperties
{
	flameRadius=30.f
	fadeTime=3.f

	bNoDelete=false
	bStatic=false
	bIgnoreBaseRotation=true

	bBlockActors=false
	bCollideActors=true
	mBlockCamera=false
	Physics=PHYS_None
	CollisionType=COLLIDE_TouchAll

	Begin Object Class=CylinderComponent Name=CollisionCylinder
		CollideActors=true
		CollisionRadius=30
		CollisionHeight=30
		Translation=(X=0,Y=0,Z=30)
		bAlwaysRenderIfSelected=true
	End Object
	CollisionComponent=CollisionCylinder
	Components.Add(CollisionCylinder)

	Begin Object Class=ParticleSystemComponent Name=ParticleSystemComponent0
        Template=ParticleSystem'Goat_Effects.Effects.Effects_Fire_01'
		bAutoActivate=true
		bResetOnDetach=true
	End Object
	fireParticle=ParticleSystemComponent0
}