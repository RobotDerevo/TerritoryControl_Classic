﻿// A script by TFlippy & Pirate-Rob

#include "TileMaterials.as";
#include "Hitters.as";
#include "CustomTiles.as";
#include "TC_Translation.as";

const string[] resources = 
{
	"mat_iron", 
	"mat_copper",
	"mat_stone",
	"mat_gold"
};

const u8[] resourceYields = 
{
	2,
	2,
	4,
	2
};

const u8[] resourceWeights = 
{
	10,
	4,
	10,
	8
};

void onInit(CBlob@ this)
{
	this.Tag("builder always hit");
	
	this.getCurrentScript().tickFrequency = 15;
	
	this.setInventoryName(name(Translate::DrillRig));
	
	this.set_bool("isActive", false);
	this.addCommandID("sv_toggle");
	this.addCommandID("cl_toggle");
}

void onInit(CSprite@ this)
{
	this.SetEmitSound("Drill.ogg");
	this.SetEmitSoundVolume(0.3f);
	this.SetEmitSoundSpeed(0.7f);
	this.SetEmitSoundPaused(!this.getBlob().get_bool("isActive"));
}

void onTick(CBlob@ this)
{
	if (isServer() && this.get_bool("isActive"))
	{
		CMap@ map = getMap();
		const f32 depth = XORRandom(96);
		Vec2f pos = Vec2f(this.getPosition().x + (XORRandom(64) - 32) * (1 - depth / 96), Maths::Min(this.getPosition().y + 16 + depth, (map.tilemapheight * map.tilesize) - 8));

		Tile tile = map.getTile(pos);
		
		if (tile.type == CMap::tile_bedrock)
		{
			const u8 index = GetRandomResourceIndex();
			Material::createFor(this, resources[index], XORRandom(resourceYields[index]));

			//this.server_Hit(this, this.getPosition(), Vec2f(0, 0), 0.02f, Hitters::drill, true); //slightly damage our drill
		}
		else if (!isTileIron(tile.type) && !isTilePlasteel(tile.type))
		{
			map.server_DestroyTile(pos, 1.0f, this);
			MaterialsFromTile(this, tile.type, 1.0f, pos);
		}
	}
}

u8 GetRandomResourceIndex()
{
    f32 totalWeight = 0.0f;
    for (uint i = 0; i < resourceWeights.length; i++) totalWeight += resourceWeights[i];

    const f32 randomValue = XORRandom(10000) / 10000.0f * totalWeight;
    f32 cumulativeWeight = 0.0f;

    for (uint i = 0; i < resourceWeights.length; i++)
    {
        cumulativeWeight += resourceWeights[i];
        if (randomValue <= cumulativeWeight) return i;
    }

    return 2;
}

void onDie(CBlob@ this)
{
	if (isServer())
	{
		server_CreateBlob("drill", this.getTeamNum(), this.getPosition());
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("sv_toggle") && isServer())
	{
		this.set_bool("isActive", !this.get_bool("isActive"));
		
		CBitStream stream;
		stream.write_bool(this.get_bool("isActive"));
		this.SendCommand(this.getCommandID("cl_toggle"), stream);
	}
	else if (cmd == this.getCommandID("cl_toggle") && isClient())
	{		
		const bool active = params.read_bool();
	
		this.set_bool("isActive", active);
	
		CSprite@ sprite = this.getSprite();
		sprite.PlaySound("LeverToggle.ogg");
		sprite.SetEmitSoundPaused(!active);
		sprite.SetAnimation(active ? "active" : "inactive");
	}
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!this.isOverlapping(caller)) return;
	
	caller.CreateGenericButton(11, Vec2f(0, -8), this, this.getCommandID("sv_toggle"), (this.get_bool("isActive") ? Translate::TurnOff : Translate::TurnOn));
}
