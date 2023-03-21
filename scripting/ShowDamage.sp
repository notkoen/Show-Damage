#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>

// Uncomment to use Vauff's DynamicChannels plugin (https://github.com/Vauff/DynamicChannels)
// #define DYNAMIC_CHANNELS
#if defined DYNAMIC_CHANNELS
#include <DynamicChannels>
#endif

ConVar g_cvChannel;
ConVar g_cvEnable;

Cookie g_cShowDamage;
Cookie g_cHitmarker;

bool g_bShowDamage[MAXPLAYERS+1] = {true, ...};
bool g_bHitmarker[MAXPLAYERS+1] = {true, ...};

public Plugin myinfo =
{
	name = "Show Damage",
	author = "koen",
	description = "Shows damage done to players",
	version = "1.0",
	url = "https://github.com/notkoen"
};

public void OnPluginStart()
{
	HookEvent("player_hurt", HookPlayerHurt, EventHookMode_Post);

	g_cvChannel = CreateConVar("sm_showdamage_channel", "5", "game_text channel to display hitmarkers on", _, true, 0.0, true, 5.0);
	g_cvEnable = CreateConVar("sm_showdamage_enable", "1", "Toggle show damage functionality", _, true, 0.0, true, 1.0);
	AutoExecConfig();

	RegConsoleCmd("sm_showdamage", Command_ShowDamage, "Open up show damage settings menu");
	RegConsoleCmd("sm_sd", Command_ShowDamage, "Open up show damage settings menu");

	SetCookieMenuItem(CookieHandler, INVALID_HANDLE, "Show Damage Settings");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}
}

//--------------------------------------------------
// Purpose: cookies
//--------------------------------------------------
public void OnClientDisconnect(int client)
{
	g_bHitmarker[client] = true;
	g_bShowDamage[client] = true;
}

public void OnClientCookiesCached(int client)
{
	char buffer[4];

	GetClientCookie(client, g_cShowDamage, buffer, sizeof(buffer));
	if (buffer[0] != '\0')
		g_bShowDamage[client] = StrEqual(buffer, "1");
	else
	{
		g_bShowDamage[client] = true;
		SetClientCookie(client, g_cShowDamage, "1");
	}

	GetClientCookie(client, g_cHitmarker, buffer, sizeof(buffer));
	if (buffer[0] != '\0')
		g_bHitmarker[client] = StrEqual(buffer, "1");
	else
	{
		g_bHitmarker[client] = true;
		SetClientCookie(client, g_cHitmarker, "1");
	}
}

//--------------------------------------------------
// Purpose: show damage command callback
//--------------------------------------------------
public Action Command_ShowDamage(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	if (client == 0)
		return Plugin_Handled;

	PrepareMenu(client);
	return Plugin_Handled;
}

//--------------------------------------------------
// Purpose: cookie menu handler
//--------------------------------------------------
public void CookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
			PrepareMenu(client);
	}
}

//--------------------------------------------------
// Purpose: menu
//--------------------------------------------------
void PrepareMenu(int client)
{
	Menu menu = CreateMenu(ShowDamageMenuHandler);
	menu.ExitBackButton = true;
	menu.ExitButton = true;

	menu.SetTitle("Show Damage Settings");

	char buffer[256];
	Format(buffer, sizeof(buffer), "Show Damage: %s", g_bShowDamage[client] ? "On" : "Off");
	menu.AddItem("showdamage", buffer);

	Format(buffer, sizeof(buffer), "Show Hitmarkers: %s", g_bHitmarker[client] ? "On" : "Off");
	menu.AddItem("hitmarker", buffer);

	menu.Display(client, MENU_TIME_FOREVER);
}

int ShowDamageMenuHandler(Handle menu, MenuAction action, int client, int selection)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (selection)
			{
				case 0:
				{
					g_bShowDamage[client] = !g_bShowDamage[client];
					SetClientCookie(client, g_cShowDamage, g_bShowDamage[client] ? "1" : "0");
					PrintToChat(client, " \x04[Show Damage] \x01Damage hud is now %s", g_bShowDamage[client] ? "\x04enabled" : "\x02disabled");
				}
				case 1:
				{
					g_bHitmarker[client] = !g_bHitmarker[client];
					SetClientCookie(client, g_cHitmarker, g_bHitmarker[client] ? "1" : "0");
					PrintToChat(client, " \x04[Show Damage] \x01Hitmarkers have now been %s", g_bHitmarker[client] ? "\x04enabled" : "\x02disabled");
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (selection == MenuCancel_ExitBack)
				ShowCookieMenu(client);
		}
		case MenuAction_End:
			CloseHandle(menu);
	}
	return 0;
}

//--------------------------------------------------
// Purpose: player_hurt event hook
//--------------------------------------------------
public Action HookPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnable.BoolValue)
		return Plugin_Continue;

	int victim, attacker, damage, healthRemaining;

	victim = GetClientOfUserId(GetEventInt(event, "userid"));
	attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	damage = GetEventInt(event, "dmg_health");
	healthRemaining = GetEventInt(event, "health");

	if (g_bShowDamage[attacker])
	{
		if (!IsClientInGame(attacker))
			return Plugin_Continue;

		if (GetClientTeam(attacker) == 3)
			ShowDamageDealt(attacker, victim, damage, healthRemaining);
	}

	if (g_bHitmarker[attacker])
		ShowHitmarker(attacker);

	return Plugin_Continue;
}

//--------------------------------------------------
// Purpose: show damage dealt function
//--------------------------------------------------
public void ShowDamageDealt(int client, int victim, int damage, int hpLeft)
{
	PrintCenterText(client, "You did <font color='#FF0000'>%d</font> damage to <font color='#0064FF'>%N</font>\nHealth Remaining: <font color='#00CE00'>%d</font>", damage, victim, hpLeft);
}

//--------------------------------------------------
// Purpose: show hitmarker function
//--------------------------------------------------
public void ShowHitmarker(int client)
{
	SetHudTextParams(-1.0, -1.0, 0.3, 255, 0, 0, 255, 0, 0.1, 0.1, 0.1);

	#if defined DYNAMIC_CHANNELS
	ShowHudText(client, GetDynamicChannel(g_cvChannel.IntValue), "∷");
	#else
	ShowHudText(client, g_cvChannel.IntValue, "∷");
	#endif
}