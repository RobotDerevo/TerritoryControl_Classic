
#include "Hitters.as";
#include "ShieldCommon.as";
#include "FireParticle.as"
#include "ArcherCommon.as";
#include "BombCommon.as";
#include "SplashWater.as";
#include "TeamStructureNear.as";
#include "Knocked.as"

void onInit(CBlob@ this)
{
	CShape@ shape = this.getShape();
	ShapeConsts@ consts = shape.getConsts();
	consts.bullet = false;
	consts.net_threshold_multiplier = 4.0f;
	this.Tag("projectile");
	
	this.server_SetTimeToDie(3);
	this.getShape().SetGravityScale(0);
	this.set_u8("type", 0);
	
	this.getCurrentScript().tickFrequency = 2;
	
	if (this.getSprite() !is null) this.getSprite().PlaySound("woosh.ogg", 1, 1);
}

void onTick(CBlob@ this)
{
	CShape@ shape = this.getShape();
	this.getSprite().RotateBy(20, Vec2f());
		
	switch (this.get_u8("type"))
	{
		case 0:
			makeSmokeParticle(this.getPosition());
			break;
			
		case 1:
			sparks(this.getPosition(), 90, 5, SColor(255, 255, 255, 0));
			break;
			
		case 2:
			makeGibParticle("GenericGibs.png", this.getPosition()+Vec2f(XORRandom(8)-4,2+XORRandom(4)), Vec2f(XORRandom(4)-2,-XORRandom(2)), 7, 1+XORRandom(4), Vec2f(8, 8), 2.0f, 20, "Gurgle2", this.getTeamNum());
			break;
			
		case 3:
			sparks(this.getPosition(), 0, 0, SColor(255, 44, 175, 222));
			break;
			
		case 4:
			makeFireParticle(this.getPosition());
			break;
			
		case 6:
			makeSteamParticle(this,this.getVelocity()*0.05);
			break;
	}
}

void makeSteamParticle(CBlob@ this, const Vec2f vel, const string filename = "SmallSteam")
{
	if (!isClient()) return;

	const f32 rad = this.getRadius();
	Vec2f random = Vec2f(XORRandom(128) - 64, XORRandom(128) - 64) * 0.015625f * rad;
	ParticleAnimated(CFileMatcher(filename).getFirst(), this.getPosition() + random, vel, float(XORRandom(360)), 1.0f, 2 + XORRandom(3), -0.1f, false);
}

void makeSteamPuff(CBlob@ this, const f32 velocity = 1.0f, const int smallparticles = 10, const bool sound = true)
{
	if (sound)
	{
		this.getSprite().PlaySound("Steam.ogg");
	}

	makeSteamParticle(this, Vec2f(), "MediumSteam");
	for (int i = 0; i < smallparticles; i++)
	{
		f32 randomness = (XORRandom(32) + 32) * 0.015625f * 0.5f + 0.75f;
		Vec2f vel = getRandomVelocity(-90, velocity * randomness, 360.0f);
		makeSteamParticle(this, vel);
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (this.getTickSinceCreated() < 2) return;

	if (!this.hasTag("collided") && blob !is null && solid)
	{	
		this.Tag("collided");

		switch (this.get_u8("type"))
		{
			case 0:
				if (isServer()) this.server_Hit(blob, blob.getPosition(), Vec2f(0,0), 2.5f, Hitters::arrow);
				break;
				
			case 1:
				if (isServer()) blob.server_Heal(20);
				break;
				
			case 2:
				if (isServer()) blob.server_Heal(2);
				break;
				
			case 3:
				Splash(this, 3, 3, 0.0f, true);
				this.getSprite().PlaySound("GlassBreak");
				break;
				
			case 4:
				if (isServer()) this.server_Hit(blob, blob.getPosition(), Vec2f(0,0), 1.0f, Hitters::fire);
				break;
				
			case 5:
				if (blob.hasTag("vehicle"))
				{
					ParticlesFromSprite(this.getSprite());
					if (isServer()) blob.server_Heal(20);
				}
				break;
				
			case 6:
				if (isServer()) for (int i = 0; i < 4; i++) this.server_Hit(blob, blob.getPosition(), this.getVelocity()*20, 0.25, Hitters::nothing);
				makeSteamPuff(this);
				break;
		}
	}
	
	if (solid || this.hasTag("collided")) if (isServer()) this.server_Die();
}

void onDie(CBlob@ this)
{
	if (isServer())
	{
		if (this.get_u8("type") == 7)
		{
			CMap@ map = getMap();
			const int radius = 10;
			Vec2f pos = this.getPosition();
			f32 radsq = radius * 8 * radius * 8;

			for (int x_step = -radius; x_step < radius; ++x_step)
			{
				for (int y_step = -radius; y_step < radius; ++y_step)
				{
					Vec2f off(x_step * map.tilesize, y_step * map.tilesize);

					if (off.LengthSquared() > radsq) continue;

					Vec2f tpos = pos + off;

					TileType t = map.getTile(tpos).type;
					if (map.isTileGround(t))
					{
						int typ = CMap::tile_stone;
						if (XORRandom(2) == 0)
						{
							typ = 100 + XORRandom(5);
						}
						else
						{
							typ = 215 + XORRandom(4);
						}
						
						map.server_SetTile(tpos, typ);
					}
				}
			}
		}
		
		if (this.get_u8("type") == 2)
		{
			CMap@ map = getMap();
			const int radius = 10;
			Vec2f pos = this.getPosition();
			f32 radsq = radius * 8 * radius * 8;

			for (int x_step = -radius; x_step < radius; ++x_step)
			{
				for (int y_step = -radius; y_step < radius; ++y_step)
				{
					Vec2f off(x_step * map.tilesize, y_step * map.tilesize);

					if (off.LengthSquared() > radsq) continue;

					Vec2f tpos = pos + off;

					TileType t = map.getTile(tpos).type;
					if (t == CMap::tile_empty && map.isTileGround(map.getTile(tpos + Vec2f(0,8)).type))
					{
						map.server_SetTile(tpos, CMap::tile_grass);
					}
					
					if (!map.isTileSolid(t) && map.isTileGround(map.getTile(tpos + Vec2f(0,8)).type))
					{
						if (XORRandom(2) == 0)server_CreateBlob("bush", -1, tpos);
						else
						{
							CBlob@ flow = server_CreateBlob("flowers", -1, tpos);
							flow.Tag("instant_grow");
						}
						if (XORRandom(4) == 0)
						{
							CBlob@ grain = server_CreateBlobNoInit("grain_plant");
							if (grain !is null)
							{
								grain.Tag("instant_grow");
								grain.setPosition(tpos);
								grain.Init();
							}
						}
					}
				}
			}
		}
	}
	
	if (this.getSprite() !is null)
	{
		this.getSprite().PlaySound("card_sparkle.ogg", 1, 1);
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	if (blob is null) return false;
	
	if (blob.hasTag("projectile"))
		return false;
	
	if (this.get_u8("type") == 5 && blob.hasTag("vehicle") && this.getTeamNum() == blob.getTeamNum())
		return true;
	
	if (this.getDamageOwnerPlayer() !is null && blob is this.getDamageOwnerPlayer().getBlob())
		return false;

	bool check = this.getTeamNum() != blob.getTeamNum();
	if (!check)
	{
		CShape@ shape = blob.getShape();
		check = (shape.isStatic() && !shape.getConsts().platform);
	}

	if (check)
	{
		return !blob.hasTag("dead");
	}

	return false;
}

void onThisAddToInventory(CBlob@ this, CBlob@ inventoryBlob)
{
	if (isServer())
		this.server_Die();
}
