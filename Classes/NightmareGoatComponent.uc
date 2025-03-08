class NightmareGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var SkeletalMesh 	mJoustingSkelMesh;
var PhysicsAsset	mJoustingPhysAsset;
var AnimSet			mJoustingAnimSet;
var AnimTree		mJoustingAnimTree;

var Material mNightmareMaterial;
var float mNewCollisionRadius;
var float mNewCollisionHeight;
var vector mCameraLookAtOffset;
var GGRB_Handle mGrabber;
var Actor mLastGrabbedItem;

var float burnRadius;

var bool isSprintPressed;
var float explosiveJumpRadius;
var float explosiveJumpHeight;

var float lastVerticalSpeed;
var float explosiveMomentum;
var float explosiveLandingRadius;

var bool mUseFlameTrail;
var TrailFlame lastFlame;
var ParticleSystem explosionParticleTemplate;
var ParticleSystem explosionHugeParticleTemplate;
var ParticleSystem explosionSmallParticleTemplate;
var SoundCue explosionSound;
var SoundCue explosionHugeSound;
var SoundCue explosionSmallSound;
var array<DecorativeFlame> mFootFlames;

var UDKParticleSystemComponent mFireParticleComponent;
var ParticleSystem mFireParticleTemplate;
var name mFlameThrowerBone;
var float mFireDamage;
var float mFireForce;
var float mFireCollisionRange;
var float mFireCollisionInterval;
var float mLastCollisionTimestamp;
var bool mIsFlamethrowerEnabled;
var AudioComponent mFiremanGoatFlamethrowerAC;
var SoundCue mFiremanGoatFlamethrowerSound;

var array<name> footBones;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	local int i;
	local DecorativeFlame decoFlame;
	local name boneName;

	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		gMe.mRagdollLandSpeed=1000000;

		gMe.mesh.SetSkeletalMesh( mJoustingSkelMesh );
		gMe.mesh.SetPhysicsAsset( mJoustingPhysAsset );
		gMe.mesh.AnimSets[ 0 ] = mJoustingAnimSet;
		gMe.mesh.SetAnimTreeTemplate( mJoustingAnimTree );

		gMe.mesh.SetMaterial( 0, mNightmareMaterial );

		gMe.SetLocation( gMe.Location + vect( 0.0f, 0.0f, 1.0f ) * ( mNewCollisionHeight - gMe.GetCollisionHeight() ) );
		gMe.SetCollisionSize( mNewCollisionRadius, mNewCollisionHeight );

		gMe.mCameraLookAtOffset = mCameraLookAtOffset;

		mFootFlames.Length=0;
		for( i = 0; i < footBones.Length; ++i )
		{
			boneName=footBones[i];
			//gMe.WorldInfo.Game.Broadcast(gMe, "boneName=" $ boneName);
			decoFlame=gMe.Spawn(class'DecorativeFlame', gMe,, gMe.Mesh.GetBoneLocation(boneName),,, true);
			decoFlame.SetBase(gMe,, gMe.mesh, boneName);
			mFootFlames.AddItem(decoFlame);
		}

		mFireParticleComponent = new(gMe) class'UDKParticleSystemComponent';
		mFireParticleComponent.bAutoActivate = false;
		mFireParticleComponent.SetTemplate(mFireParticleTemplate);
		mFireParticleComponent.SetKillOnDeactivate(0,false);
		mFireParticleComponent.SetKillOnCompleted(0,false);
		gMe.mesh.AttachComponent( mFireParticleComponent, mFlameThrowerBone, vect(33.f, 0.f, -27.f), rot(-18000, 0, 0));

		mFiremanGoatFlamethrowerAC = gMe.CreateAudioComponent( mFiremanGoatFlamethrowerSound, false );

		gMe.mAbilities[EAT_Bite].mAnimNeckBlendListIndex=INDEX_NONE;
		gMe.mAbilities[EAT_Bite].mRange=150.f;
		mGrabber=gMe.mGrabber;
		gMe.mGrabber=none;
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ) )
		{
			BurnThemAll();
		}

		if( localInput.IsKeyIsPressed( "GBA_Jump", string( newKey ) ) )
		{
			if(isSprintPressed && !gMe.mIsRagdoll && gMe.Velocity.Z <= 0.1f)
			{
				ExplosiveJump();
			}
		}

		if( localInput.IsKeyIsPressed( "GBA_Sprint", string( newKey ) ) || newKey == 'XboxTypeS_LeftTrigger')
		{
			isSprintPressed=true;
		}

		if(localInput.IsKeyIsPressed("LeftMouseButton", string( newKey )) || newKey == 'XboxTypeS_RightTrigger')
		{
			SetFlameThrowerEnabled(true);
		}

		if( localInput.IsKeyIsPressed( "GBA_ToggleRagdoll", string( newKey ) ) )
		{
			gMe.SetTimer(1.5f, false, NameOf( ToggleFlameTrail ), self);
		}

		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			ForceLick();
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_Sprint", string( newKey ) ) || newKey == 'XboxTypeS_LeftTrigger')
		{
			isSprintPressed=false;
		}

		if(localInput.IsKeyIsPressed("LeftMouseButton", string( newKey )) || newKey == 'XboxTypeS_RightTrigger')
		{
			SetFlameThrowerEnabled(false);
		}

		if( localInput.IsKeyIsPressed( "GBA_ToggleRagdoll", string( newKey ) ) )
		{
			if(gMe.IsTimerActive(NameOf( ToggleFlameTrail ), self))
			{
				gMe.ClearTimer(NameOf( ToggleFlameTrail ), self);
			}
		}
	}
}

function ToggleFlameTrail()
{
	local DecorativeFlame decoFlame;

	mUseFlameTrail=!mUseFlameTrail;
	foreach mFootFlames(decoFlame)
	{
		decoFlame.SetHidden(!mUseFlameTrail);
	}
}

function BurnThemAll()
{
	local GGPawn hitGpawn;
	local vector pos;

	pos=gMe.Mesh.GetPosition();
	gMe.WorldInfo.MyEmitterPool.SpawnEmitter(explosionParticleTemplate, pos);
	gMe.PlaySound(explosionSound,,,, pos);

	foreach gMe.CollidingActors( class'GGPawn', hitGpawn, burnRadius, pos)
	{
		if(hitGpawn != gMe)
		{
			BurnPawn(hitGpawn);
		}
	}
}

function BurnPawn(GGPawn gpawn, optional bool ignoreIfBurning)
{
	if(gpawn.IsTimerActive('SetOnFire', gpawn))
	{
		if(ignoreIfBurning)
		{
			return;
		}
		gpawn.ClearTimer('SetOnFire', gpawn);
	}
	gpawn.SetOnFire( true );
	gpawn.SetTimer( FRand() * 2.0f + 8.0f, false, 'SetOnFire', gpawn);
}

function ExplosiveJump()
{
	ExplodeRadius(explosiveJumpRadius, explosionSmallParticleTemplate, explosionSmallSound);

	gMe.SetPhysics(PHYS_Falling);
	gMe.Velocity.Z = explosiveJumpHeight;
}

function ExplosiveLanding(float radius)
{
	ExplodeRadius(radius, explosionHugeParticleTemplate, explosionHugeSound);
}

function ExplodeRadius(float radius, ParticleSystem expTemplate, SoundCue expSound)
{
	local Actor hitActor;
    local TraceHitInfo HitInfo;
	local vector pos;

	pos=gMe.Mesh.GetPosition();
	gMe.WorldInfo.MyEmitterPool.SpawnEmitter(expTemplate, pos);
	gMe.PlaySound(expSound,,,, pos);

    foreach gMe.VisibleCollidingActors( class'Actor', hitActor, radius, pos,,,,, HitInfo )
    {
        if(hitActor != gMe &&  !hitActor.bWorldGeometry && (hitActor.bCanBeDamaged || hitActor.bProjTarget) )
        {
            if(GGPawn(hitActor) != none)
			{
				GGPawn(hitActor).SetRagdoll( true );
			}
            hitActor.TakeRadiusDamage(gMe.Controller, radius, radius, class'GGDamageTypeExplosiveActor', explosiveMomentum, pos, true, gMe);
        }
    }
}

function Tick(float deltaTime)
{
	local vector pos;
	local Actor hitAct;

	// Leave a flame trail
	if(mUseFlameTrail)
	{
		pos=gMe.mesh.GetPosition();
		pos.Z-=gMe.GetCollisionHeight();
		if(lastFlame == none || VSize(lastFlame.Location - pos) > lastFlame.flameRadius)
		{
			lastFlame=gMe.Spawn(class'TrailFlame', gMe,, pos,,, true);
			lastFlame.SetNGC(self);
		}
	}
	// Can't be set on fire
	if(gMe.mIsBurning)
	{
		gMe.SetOnFire(false);
	}
	// Breathe fire
	if(mIsFlamethrowerEnabled && mFireParticleComponent != None && mFireParticleComponent.CollisionEvents.Length > 0)
	{
		if(myMut.WorldInfo.TimeSeconds - mLastCollisionTimestamp >= mFireCollisionInterval)
		{
			if(mFireParticleComponent.CollisionEvents.Length>0)
			{
				foreach gMe.OverlappingActors( class'Actor', hitAct, mFireCollisionRange, mFireParticleComponent.CollisionEvents[mFireParticleComponent.CollisionEvents.Length-1].Location)
			    {
					HitActor(hitAct);
				}

				mLastCollisionTimestamp = myMut.WorldInfo.TimeSeconds;
			}
		}
	}
	// Lick stuff
	if( mGrabber != none )
	{
		UpdateGrabber( deltaTime );
	}
	if(mLastGrabbedItem != none && gMe.mGrabbedItem == none)
	{
		mGrabber.ReleaseComponent();
	}

	mLastGrabbedItem=gMe.mGrabbedItem;
	lastVerticalSpeed=gMe.Velocity.Z;
}

function SetFlameThrowerEnabled( bool enable )
{
	if( enable != mIsFlamethrowerEnabled )
	{
		mIsFlamethrowerEnabled = enable;

		if( enable )
		{
			mFireParticleComponent.ActivateSystem();

			if( mFiremanGoatFlamethrowerAC != none )
			{
				mFiremanGoatFlamethrowerAC.FadeIn( 1, 1 );
			}
		}
		else
		{
			mFireParticleComponent.DeactivateSystem();

			if( mFiremanGoatFlamethrowerAC != none )
			{
				mFiremanGoatFlamethrowerAC.FadeOut( 1, 0 );
			}
		}
	}
}

function bool ShouldIgnoreActor(Actor act)
{
	//WorldInfo.Game.Broadcast(self, "shouldIgnoreActor=" $ act);
	return (
	act == none
	|| Volume(act) != none
	|| act == gMe
	|| act == gMe.Owner);
}

function HitActor(Actor target)
{
	local GGPawn gpawn;
	local GGNPCMMOEnemy mmoEnemy;
	local GGNpcZombieGameModeAbstract zombieEnemy;
	local GGKactor kActor;
	local GGSVehicle vehicle;
	local float mass;
	local vector direction, newVelocity;
	local int damage;

	if(ShouldIgnoreActor(target))
		return;

	gpawn = GGPawn(target);
	mmoEnemy = GGNPCMMOEnemy(target);
	zombieEnemy = GGNpcZombieGameModeAbstract(target);
	kActor = GGKActor(target);
	vehicle = GGSVehicle(target);

	direction = Normal2D(target.Location - gMe.mesh.GetPosition());
	if(gpawn != none)
	{
		direction = Normal(gpawn.mesh.GetPosition() - gMe.mesh.GetPosition());
		mass=50.f;
		if(!gpawn.mIsRagdoll)
		{
			gpawn.SetRagdoll(true);
		}
		//gpawn.mesh.AddImpulse(direction * mass * wrenchForce,,, false);
		newVelocity = gpawn.mesh.GetRBLinearVelocity() + (direction * mFireForce);
		gpawn.Mesh.SetRBLinearVelocity(newVelocity);
		//Damage MMO enemies
		if(mmoEnemy != none)
		{
			damage = mFireDamage;
			mmoEnemy.TakeDamageFrom(damage, gMe, class'GGDamageTypeExplosiveActor');
		}
		else
		{
			gpawn.TakeDamage( 0.f, gMe.Controller, gpawn.Location, vect(0, 0, 0), class'GGDamageType',, gMe);
		}
		//Damage zombies
		if(zombieEnemy != none)
		{
			damage = mFireDamage * 2.f;
			zombieEnemy.TakeDamage(damage, gMe.Controller, zombieEnemy.Location, vect(0, 0, 0), class'GGDamageTypeZombieSurvivalMode' );
		}
		BurnPawn(gpawn, true);
	}
	else if(kActor != none)
	{
		mass=kActor.StaticMeshComponent.BodyInstance.GetBodyMass();
		//WorldInfo.Game.Broadcast(self, "Mass : " $ mass);
		kActor.ApplyImpulse(direction,  mass * mFireForce,  -direction);
		kActor.TakeDamage(1000000, gMe.Controller, kActor.Location, vect(0, 0, 0), class'GGDamageTypeAbility',, gMe);
	}
	else if(vehicle != none)
	{
		mass=vehicle.Mass;
		vehicle.AddForce(direction * mass * mFireForce);
	}
	else if(GGApexDestructibleActor(target) != none)
	{
		target.TakeDamage(1000000, gMe.Controller, target.Location, direction * mass * mFireForce, class'GGDamageTypeAbility',, gMe);
	}
}

function OnCollision( Actor actor0, Actor actor1 )
{
	if(actor0 == gMe && gMe.mIsRagdoll && lastVerticalSpeed < -1000.f)
	{
		ExplosiveLanding(-lastVerticalSpeed);
		lastVerticalSpeed=0.f;
	}
}

function ModifyCameraZoom( GGGoat goat )
{
	local GGCameraModeOrbital orbitalCamera;

	orbitalCamera = GGCameraModeOrbital( GGCamera( PlayerController( goat.Controller ).PlayerCamera ).mCameraModes[ CM_ORBIT ] );

	orbitalCamera.mMaxZoomDistance = 1300;
	orbitalCamera.mMinZoomDistance = 250;
	orbitalCamera.mDesiredZoomDistance = 800;
	orbitalCamera.mCurrentZoomDistance = 800;
}

//////////////////////////////////
// Force lick stuff
//////////////////////////////////


function ForceLick()
{
	local GGAbility ability;
	local vector biteLocation;
	local Actor grabVictim;
	local GGCollidableActorInterface collidable;
	local bool grabbedSuccessfully;

	if( gMe.Physics == PHYS_RigidBody || gMe.mTerminatingRagdoll || gMe.mBaaing || gMe.mGrabbedItem != none)
	{
		if( gMe.mGrabbedItem != none )
		{
			gMe.DropGrabbedItem();
			return;
		}
		return;
	}

	gMe.mGrabbedLocalLocation = vect( 0.0f, 0.0f, 0.0f );
	ability = gMe.mAbilities[ EAT_Bite ];
	gMe.PlaySound( SoundCue'Goat_Sounds.Cue.Effect_Goat_lick_cue', true, false, true );

	biteLocation=gMe.mesh.GetBoneLocation('Jaw');
	grabVictim = FindGrabbableItem( biteLocation, ability.mRange );

	if( grabVictim != none )
	{
		grabbedSuccessfully = GrabItem( grabVictim, biteLocation );
		if( grabbedSuccessfully )
		{
			GrabbedItem( ability, grabVictim );
		}

		collidable = GGCollidableActorInterface( grabVictim );
		if( collidable != none )
		{
			collidable.SetCollisionChainGoatNr( gMe );
		}
	}
}

function GrabbedItem( GGAbility ability, Actor grabVictim )
{
	GGHUD( PlayerCOntroller( gMe.Controller ).myHUD ).mHUDMovie.ActorGrabbed( grabVictim );

	GGGameInfo( gMe.WorldInfo.Game ).OnUseAbility( gMe, ability, grabVictim );

	if( GGScoreActorInterface( grabVictim ) != none )
	{
		if( string( GGScoreActorInterface( grabVictim ).GetPhysMat() ) == "PhysMat_HangGlider" )
		{
			GGPlayerControllerGame( gMe.Controller ).mAchievementHandler.UnlockAchievement( ACH_MILE_HIGH_CLUB );
		}
		else if( string( GGScoreActorInterface( grabVictim ).GetPhysMat() ) == "PhysMat_Axe" )
		{
			GGPlayerControllerGame( gMe.Controller ).mAchievementHandler.UnlockAchievement( ACH_JOHNNY );
		}
	}

	gMe.TriggerGlobalEventClass( class'GGSeqEvent_GrabbedObject', gMe.Controller );
}

function Actor FindGrabbableItem( vector grabLocation, float grabRange )
{
	local Actor foundActor, hitActor;
	local TraceHitInfo hitInfo;
	local name boneName;
	local GGGrabbableActorInterface grabbableInterface;

	foundActor = none;

	foreach gMe.VisibleCollidingActors( class'Actor', hitActor, grabRange, grabLocation,,,,, hitInfo )
	{
		grabbableInterface = GGGrabbableActorInterface( hitActor );

		if( grabbableInterface == none || hitActor == gMe )
		{
			continue;
		}

		if( foundActor != none && VSizeSq( hitActor.Location - grabLocation ) > VSizeSq( foundActor.Location - grabLocation ) )
		{
			continue;
		}

		boneName = grabbableInterface.GetGrabInfo( grabLocation );

		if( grabbableInterface.CanBeGrabbed( gMe, boneName ) )
		{
			foundActor = hitActor;
		}
	}

	return foundActor;
}

function bool GrabItem( Actor item, vector grabLocation )
{
	local name boneName;
	local PrimitiveComponent grabComponent;
	local vector dummyExtent, dummyOutPoint, closestPoint;
	local GJKResult closestPointResult;
	local GGPhysicalMaterialProperty physProp;
	local GGGrabbableActorInterface grabbableInterface;

	grabbableInterface = GGGrabbableActorInterface( item );

	if( grabbableInterface == none )
	{
		return false;
	}

	boneName = grabbableInterface.GetGrabInfo( grabLocation );

	if( grabbableInterface.CanBeGrabbed( gMe, boneName ) )
	{
		grabComponent = grabbableInterface.GetGrabbableComponent();
		physProp = grabbableInterface.GetPhysProp();

		grabbableInterface.OnGrabbed( gMe );
	}
	else
	{
		return false;
	}

	// Grab the item.
	mGrabber.GrabComponent( grabComponent, boneName, grabLocation, false );
	gMe.mActorsToIgnoreBlockingBy.AddItem( item );
	gMe.mGrabbedItem = item;

	// Cache location for the tongue. Have to check for grabbed component if the goat has grabbed a consumeable
	if( mGrabber.GrabbedBoneName == 'None' && mGrabber.GrabbedComponent != none )
	{
		closestPointResult = mGrabber.GrabbedComponent.ClosestPointOnComponentToPoint( grabLocation, dummyExtent, dummyOutPoint, closestPoint );
		if( closestPointResult == GJK_NoIntersection )
		{
			gMe.mGrabbedLocalLocation = InverseTransformVector( mGrabber.GrabbedComponent.LocalToWorld, closestPoint );
		}
		else
		{
			gMe.mGrabbedLocalLocation = InverseTransformVector( mGrabber.GrabbedComponent.LocalToWorld, gMe.mGrabbedItem.Location );
		}
	}

	if( physProp != none && physProp.ShouldAlertNPCs() )
	{
		gMe.NotifyAIControlllersGrabbedItem();
	}

	return true;
}

function UpdateGrabber( float deltaTime )
{
	local vector grabLocation;

	if( gMe.mGrabbedItem == none
		|| mGrabber.GrabbedComponent == none
		|| gMe.mGrabbedItem.bPendingDelete
		|| gMe.mGrabbedItem.Physics == PHYS_None )
	{
		gMe.DropGrabbedItem();
	}
	else
	{
		// Uqly hax to initialize the tongue the first time.
		if( gMe.mTongueControl.StrengthTarget == 0.0f )
		{
			gMe.SetTongueActive( true );
		}

		grabLocation=gMe.mesh.GetBoneLocation('Jaw');
		mGrabber.SetLocation( grabLocation );

		// If we should reduce the mass of the KActor we picked up
		if( GGKActor( gMe.mGrabbedItem ) != None && gMe.mScaleMassOnPickup )
		{
			GGKActor( gMe.mGrabbedItem ).SetMassScale( gMe.mScaleMassRate );
		}

		if( mGrabber.GrabbedBoneName != 'None' )
		{
			gMe.mTongueControl.BoneTranslation = SkeletalMeshComponent( mGrabber.GrabbedComponent ).GetBoneLocation( mGrabber.GrabbedBoneName );
		}
		else
		{
			gMe.mTongueControl.BoneTranslation = TransformVector( mGrabber.GrabbedComponent.LocalToWorld, gMe.mGrabbedLocalLocation );
		}

		if( GGInterpActor( gMe.mGrabbedItem ) != none )
		{
			gMe.UpdateGrabbedInterpActor( deltaTime );
		}
	}
}

defaultproperties
{
	burnRadius=1000.f
	mUseFlameTrail=true

	explosiveJumpRadius=500.f
	explosiveJumpHeight=2000.f

	explosiveMomentum=50000.f
	explosiveLandingRadius=1000.f

	//mJoustingSkelMesh=SkeletalMesh'MMO_JoustingGoat.mesh.JoustingGoat_01'
	mJoustingSkelMesh=SkeletalMesh'MMO_JoustingGoat.Mesh.Horse_01'
	mJoustingPhysAsset=PhysicsAsset'MMO_JoustingGoat.mesh.JoustingGoat_Physics_01'
	mJoustingAnimSet=AnimSet'MMO_JoustingGoat.Anim.JoustingGoat_Anim_01'
	mJoustingAnimTree=AnimTree'MMO_JoustingGoat.Anim.JoustingGoat_Animtree'

	mNewCollisionRadius=40.0f
	mNewCollisionHeight=98.0f

	mCameraLookAtOffset=(X=0.0f,Y=0.0f,Z=120.0f)

	mNightmareMaterial=Material'MMO_JoustingGoat.Materials.Horse_Mat_02'

	explosionParticleTemplate=ParticleSystem'Goat_Effects.Effects.Effects_Explosion_Car_01'
	explosionHugeParticleTemplate=ParticleSystem'Goat_Effects.Effects.Effects_Explosion_Huge_01'
	explosionSmallParticleTemplate=ParticleSystem'Goat_Effects.Effects.Projectile_Explosion_01'
	explosionSound=SoundCue'MMO_SFX_SOUND.Cue.SFX_Demon_Spawn_Explosion_Cue'
	explosionHugeSound=SoundCue'Goat_Sounds.Cue.Explosion_Car_Cue'
	explosionSmallSound=SoundCue'Goat_Sounds.Cue.Explosion_Tube_Cue'

	footBones(0)=Front_Toe_L
	footBones(1)=Front_Toe_R
	footBones(2)=Back_Toe_L
	footBones(3)=Back_Toe_R

	mFlameThrowerBone="Jaw"
	mFireParticleTemplate=ParticleSystem'Zombie_Particles.Particles.Flamethrower_ParticleSystem'
	mFireDamage=5.0f
	mFireForce=100.f

	mFireCollisionRange=30.0f//500.f
	mFireCollisionInterval=0.1f

	mFiremanGoatFlamethrowerSound=SoundCue'Zombie_NPC_Sound.ZombieElephant.ZombieElephant_Flamethrower_Loop_Cue'
}