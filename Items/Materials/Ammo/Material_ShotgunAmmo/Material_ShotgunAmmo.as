
void onInit(CBlob@ this)
{
	this.maxQuantity = 12;
	this.getCurrentScript().runFlags |= Script::remove_after_this;
}
