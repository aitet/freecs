/*
 * Copyright (c) 2016-2021 Marco Cawthorne <marco@icculus.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF MIND, USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*QUAKED weapon_glock18 (0 0 1) (-16 -16 0) (16 16 32)
"model" "models/w_glock18.mdl"

COUNTER-STRIKE (1999) ENTITY

Glock 18 Select Fire Weapon

Default arsenal for Terrorists

- Buy Menu -
Price: $400

*/

enum
{
	GLOCK_IDLE1,
	GLOCK_IDLE2,
	GLOCK_IDLE3,
	GLOCK_SHOOT_BURST1,
	GLOCK_SHOOT_BURST2,
	GLOCK_SHOOT,
	GLOCK_SHOOT_EMPTY,
	GLOCK_RELOAD1,
	GLOCK_DRAW1,
	GLOCK_UNUSED1,
	GLOCK_UNUSED2,
	GLOCK_DRAW2,
	GLOCK_RELOAD2
};

void
w_glock18_precache(void)
{
#ifdef SERVER
	Sound_Precache("weapon_glock18.fire");
	Sound_Precache("weapon_glock18.burstfire");
	precache_model("models/w_glock18.mdl");
#else
	precache_model("models/v_glock18.mdl");
	precache_model("models/p_glock18.mdl");
#endif
}

void
w_glock18_updateammo(player pl)
{
	Weapons_UpdateAmmo(pl, pl.glock18_mag, pl.ammo_9mm, -1);
}

string
w_glock18_wmodel(void)
{
	return "models/w_glock18.mdl";
}

string
w_glock18_pmodel(player pl)
{
	return "models/p_glock18.mdl";
}

string
w_glock18_deathmsg(void)
{
	return "";
}

int
w_glock18_pickup(player pl, int new, int startammo)
{
#ifdef SERVER

	if (new) {
		if (startammo == -1)
			pl.glock18_mag = 20;
		else
			pl.glock18_mag = startammo;
	} else {
		if (pl.ammo_9mm < AMMO_MAX_9MM) {
			pl.ammo_9mm = bound(0, pl.ammo_9mm + 20, AMMO_MAX_9MM);
		} else {
			return (0);
		}
	}
#endif
	return (1);
}

void
w_glock18_draw(player pl)
{
	Weapons_SetModel("models/v_glock18.mdl");

	int r = (float)input_sequence % 2;
	switch (r) {
	case 0:
		Weapons_ViewAnimation(pl, GLOCK_DRAW1);
		break;
	default:
		Weapons_ViewAnimation(pl, GLOCK_DRAW2);
		break;
	}

#ifdef CLIENT
	pl.cs_cross_mindist = 8;
	pl.cs_cross_deltadist = 3;
#endif
}

void
w_glock18_primary(player pl)
{

	if (pl.w_attack_next > 0.0)
		return;
	if (pl.gflags & GF_SEMI_TOGGLED)
		return;
	if (!pl.glock18_mag)
		return;

	int shotcount = (pl.mode_glock18) ? 3 : 1;

	/* fix shotcount if we're < 3 in burst mode */
	if (pl.glock18_mag < 3 && pl.mode_glock18)
		shotcount = pl.glock18_mag;

	for (int i = 0; i < shotcount; i ++) {
		Cstrike_ShotMultiplierAdd(pl, 1);
		float accuracy = Cstrike_CalculateAccuracy(pl, (pl.mode_glock18) ? 175 : 200);
		pl.glock18_mag--;
#ifdef SERVER
		TraceAttack_SetRangeModifier(1.25); /* penetrates 9 units, but not 10 */
		TraceAttack_SetPenetrationPower(1);
		TraceAttack_FireBullets(1, pl.origin + pl.view_ofs, 25, [accuracy,accuracy], WEAPON_GLOCK18);
#endif
	}

	if (pl.mode_glock18) {
		int r = (float)input_sequence % 2;
		switch (r) {
		case 0:
			Weapons_ViewAnimation(pl, GLOCK_SHOOT_BURST1);
			break;
		default:
			Weapons_ViewAnimation(pl, GLOCK_SHOOT_BURST2);
			break;
		}
		pl.w_attack_next = 0.5f;
	} else {
		if (pl.glock18_mag <= 0) {
			Weapons_ViewAnimation(pl, GLOCK_SHOOT_EMPTY);
		} else {
			Weapons_ViewAnimation(pl, GLOCK_SHOOT);
		}
		pl.w_attack_next = 0.15f;
	}

	if (pl.flags & FL_CROUCHING)
		Animation_PlayerTop(pl, ANIM_SHOOT_ONEHAND, 0.45f);
	else
		Animation_PlayerTop(pl, ANIM_CROUCH_SHOOT_ONEHAND, 0.45f);

#ifdef CLIENT
	View_SetMuzzleflash(MUZZLE_RIFLE);
	View_AddEvent(w_pistol_ejectshell, 0.0f);
#else
	if (pl.mode_glock18) {
		Sound_Play(pl, CHAN_WEAPON, "weapon_glock18.burstfire");
	} else {
		Sound_Play(pl, CHAN_WEAPON, "weapon_glock18.fire");
	}
#endif

	pl.gflags |= GF_SEMI_TOGGLED;
	pl.w_idle_next = pl.w_attack_next + 1.0f;
}

void
w_glock18_secondary(player pl)
{

	if (pl.w_attack_next > 0) {
		return;
	}

	/* toggle burst-fire */
	pl.mode_glock18 = 1 - pl.mode_glock18;

#ifdef CLIENT
	if (pl.mode_glock18) {
		CSQC_Parse_CenterPrint("Switched to Burst-Fire mode");
	} else {
		CSQC_Parse_CenterPrint("Switched to Semi-Automatic mode");
	}
#endif

	pl.w_attack_next = 0.5f;
	pl.w_idle_next = pl.w_attack_next + 1.0f;
}

void
w_glock18_reload(player pl)
{

	if (pl.w_attack_next > 0.0)
		return;
	if (pl.glock18_mag >= 20)
		return;
	if (!pl.ammo_9mm)
		return;

	int r = (float)input_sequence % 2;
	switch (r) {
	case 0:
		Weapons_ViewAnimation(pl, GLOCK_RELOAD1);
		break;
	default:
		Weapons_ViewAnimation(pl, GLOCK_RELOAD2);
		break;
	}

	pl.w_attack_next = 2.1f;
	pl.w_idle_next = pl.w_attack_next + 1.0f;

#ifdef SERVER
	static void w_weapon_reload_done(void) {
		player pl = (player)self;
		Weapons_ReloadWeapon(pl, player::glock18_mag, player::ammo_9mm, 20);
	}

	pl.think = w_weapon_reload_done;
	pl.nextthink = time + pl.w_attack_next - 0.1f;
#endif
}

void
w_glock18_release(player pl)
{
	w_cstrike_weaponrelease();

	/* auto-reload if need be */
	if (pl.w_attack_next <= 0.0)
	if (pl.glock18_mag == 0 && pl.ammo_9mm > 0) {
		Weapons_Reload(pl);
		return;
	}

	if (pl.w_idle_next)
		return;

	int r = floor(pseudorandom() * 3);

	switch (r) {
	case 0:
		Weapons_ViewAnimation(pl, GLOCK_IDLE1);
		pl.w_idle_next = 2.8125f;
		break;
	case 1:
		Weapons_ViewAnimation(pl, GLOCK_IDLE2);
		pl.w_idle_next = 2.25f;
		break;
	case 2:
		Weapons_ViewAnimation(pl, GLOCK_IDLE3);
		pl.w_idle_next = 2.5f;
		break;
	}
}

float
w_glock18_aimanim(player pl)
{
	return w_deagle_aimanim(pl);
}

void
w_glock18_hud(player pl)
{
#ifdef CLIENT
	Cstrike_DrawCrosshair();
	HUD_DrawAmmo1();
	HUD_DrawAmmo2();
	vector aicon_pos = g_hudmins + [g_hudres[0] - 48, g_hudres[1] - 42];
	drawsubpic(aicon_pos, [24,24], g_hud7_spr, [48/256,72/256], [24/256, 24/256], g_hud_color, pSeatLocal->m_flAmmo2Alpha, DRAWFLAG_ADDITIVE);
#endif
}

int
w_glock18_isempty(player pl)
{

	if (pl.glock18_mag <= 0 && pl.ammo_9mm <= 0)
		return 1;

	return 0;
}

void
w_glock18_hudpic(player pl, int selected, vector pos, float a)
{
#ifdef CLIENT
	vector hud_col;

	if (w_glock18_isempty(pl))
		hud_col = [1,0,0];
	else
		hud_col = g_hud_color;

	HUD_DrawAmmoBar(pos, pl.ammo_9mm, AMMO_MAX_9MM, a);

	if (selected) {
		drawsubpic(
			pos,
			[170,45],
			g_hud4_spr,
			[0,45/256],
			[170/256,45/256],
			hud_col,
			a,
			DRAWFLAG_ADDITIVE
		);
	} else {
		drawsubpic(
			pos,
			[170,45],
			g_hud1_spr,
			[0,45/256],
			[170/256,45/256],
			hud_col,
			a,
			DRAWFLAG_ADDITIVE
		);
	}
#endif
}

weapon_t w_glock18 =
{
	.name		= "glock18",
	.id		= ITEM_GLOCK18,
	.slot		= 1,
	.slot_pos	= 1,
	.weight		= 5,
	.allow_drop	= TRUE,
	.draw		= w_glock18_draw,
	.holster	= __NULL__,
	.primary	= w_glock18_primary,
	.secondary	= w_glock18_secondary,
	.reload		= w_glock18_reload,
	.release	= w_glock18_release,
	.postdraw	= w_glock18_hud,
	.precache	= w_glock18_precache,
	.pickup		= w_glock18_pickup,
	.updateammo	= w_glock18_updateammo,
	.wmodel		= w_glock18_wmodel,
	.pmodel		= w_glock18_pmodel,
	.deathmsg	= w_glock18_deathmsg,
	.aimanim	= w_glock18_aimanim,
	.hudpic		= w_glock18_hudpic,
	.type		= csweapon_ranged_type,
	.isempty	= w_glock18_isempty
};

#ifdef SERVER
void
weapon_glock18(void)
{
	Weapons_InitItem(WEAPON_GLOCK18);
}
#endif
