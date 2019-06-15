#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <socket>
#include <colorvariables>
#include <ripext>

#define PLUGIN_NAME           "ChatToSocket"
#define PLUGIN_VERSION        "1.0"

#pragma semicolon 1
#pragma newdecls required

Handle masterSocket;

ArrayList socketList;

char sHostName[128];
int iMaxSlot = -2;

ConVar cv_bDebug;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Hexah",
	description = "Sends all text messages to a socket",
	version = PLUGIN_VERSION,
	url = "github.com/Hexer10"
};

//TODO Add queue
public void OnPluginStart()
{
	socketList = new ArrayList();
	
	iMaxSlot = GetCommandLineParamInt("-maxplayers_override", -1);
	
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	
	masterSocket = SocketCreate(_, Socket_OnMasterError);
	SocketBind(masterSocket, "0.0.0.0", 50001);
	SocketListen(masterSocket, Socket_OnIncome);
	SocketSetOption(masterSocket, SocketReuseAddr, 1);
	SocketSetOption(masterSocket, DebugMode, 1);
	
	RegServerCmd("sm_sendinfo", Cmd_SendInfo);
	RegServerCmd("sm_getsockets", Cmd_GetSockets);
	cv_bDebug = CreateConVar("sm_cts_debug", "0", _, _, true, _, true, 1.0);
}

public void OnConfigsExecuted()
{
	FindConVar("hostname").GetString(sHostName, sizeof sHostName);
}

public Action Cmd_GetSockets(int args)
{
	for (int i = 0; i < socketList.Length; i++)
	{
		PrintToServer("%i. Socket: %i", i, socketList.Get(i));
	}
	return Plugin_Handled;
}
public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	JSONObject json = new JSONObject();
	
	json.SetInt("type", 6);
	json.SetInt("userid", event.GetInt("userid"));
	json.SetInt("team", event.GetInt("team"));
	
	SendToAll(json); 
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	JSONObject json = new JSONObject();
	
	json.SetInt("type", 7);
	json.SetInt("userid", event.GetInt("userid"));
	json.SetBool("alive", true);
	
	SendToAll(json); 
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	JSONObject json = new JSONObject();
	
	json.SetInt("type", 7);
	json.SetInt("userid", event.GetInt("userid"));
	json.SetBool("alive", false);
	
	SendToAll(json); 
}


public Action Cmd_SendInfo(int args)
{
	JSONObject json = new JSONObject();
	
	json.SetInt("type", 3);
	json.SetBool("connect", true);
	
	SendToAll(json);
}

public void OnClientPutInServer(int client)
{
	if (!IsClientConnected(client) || IsClientSourceTV(client) || IsFakeClient(client))
		return;
		
	JSONObject json = new JSONObject();
	
	json.SetInt("type", 3);
	json.SetBool("connect", true);
	
	SendToAll(json);
	json = new JSONObject();
	
	char sName[64];
	char sSteamID[64];
	GetClientName(client, sName, sizeof sName);
	bool iAlive = IsPlayerAlive(client);
	int iTeam = GetClientTeam(client);
	if (!GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof sSteamID))
		return;
	
	json.SetInt("type", 5);

	json.SetInt("userid", GetClientUserId(client));
	json.SetString("name", sName);
	json.SetBool("alive", iAlive);
	json.SetInt("team", iTeam);
	json.SetString("steamid", sSteamID);
	
	
	SendToAll(json);
}

public void OnClientDisconnect(int client)
{
	if (!IsClientConnected(client) || IsClientSourceTV(client) || IsFakeClient(client))
		return;
		
	JSONObject json = new JSONObject();
	
	json.SetInt("type", 3);
	json.SetBool("connect", false);
	json.SetInt("userid", GetClientUserId(client));
	
	SendToAll(json);
}

public void Socket_OnMasterError(Handle socket, const int errorType, const int errorNum, any arg)
{
	SetFailState("Failed to create a socket (%i) (%i)", errorType, errorNum);
}

public void Socket_OnError(Handle socket, const int errorType, const int errorNum, any arg)
{
	LogError("Socket error: Handle: %i Error: %i %i", socket, errorType, errorNum);
}

public void Socket_OnIncome(Handle socket, Handle newSocket, const char[] remoteIP, int remotePort, any arg)
{
	LogMessage("New Socket(%i): %s:%i", newSocket, remoteIP, remotePort);

	SocketSetReceiveCallback(newSocket, Socket_OnRecieve);
	SocketSetDisconnectCallback(newSocket, Socket_OnDisconnect);
	SocketSetErrorCallback(newSocket, Socket_OnError);
	socketList.Push(newSocket);
	
	RequestFrame(Frame_SendInfo, newSocket);
}

public void Frame_SendInfo(Handle socket)
{
	if (socketList.FindValue(socket) == -1)
		return;
	
	int iPlayerCount = 0;
	for (int i = 1; i <= MaxClients; i++)if (IsClientInGame(i) && IsClientConnected(i) && !IsClientSourceTV(i) && !IsFakeClient(i))
	{
		iPlayerCount++;
	}
	
	JSONObject json = new JSONObject();
	
	json.SetInt("type", 1);
	
	char sMap[64];
	GetCurrentMap(sMap, sizeof sMap);
	
	json.SetString("map", sMap);
	json.SetString("hostname", sHostName);

	json.SetInt("maxslot", iMaxSlot);
	json.SetInt("currentSlot", iPlayerCount);
	
	Send(json, socket);
}

public void OnMapStart()
{
	JSONObject json = new JSONObject();
	
	json.SetInt("type", 2);
	
	char sMap[64];
	GetCurrentMap(sMap, sizeof sMap);
	
	json.SetString("map", sMap);
	
	SendToAll(json);
}

public void Socket_OnRecieve(Handle socket, const char[] recieveData, const int dataSize, any arg)
{
	JSONObject json = JSONObject.FromString(recieveData);
	
	if (json == null)
		return;

	int type = json.GetInt("type");

	//Recived messages
	if (type == 0)
	{
		char sName[128];
		char sMessage[256];

		json.GetString("name", sName, sizeof sName);
		json.GetString("message", sMessage, sizeof sMessage);

		PrintToChatAll("[MOBILE-APP] %s: %s", sName, sMessage);
		SendToAll(json, socket);
	}
	else if (type == 4)//Ask for player list
	{
		delete json;
		json = new JSONObject();
		json.SetInt("type", 4);
		
		JSONArray jsonArray = new JSONArray();
		for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i) && IsClientConnected(i) && !IsClientSourceTV(i) && !IsFakeClient(i))
		{
			JSONObject jsonPlayerArray = new JSONObject();
			
			char sName[64];
			char sSteamID[64];
			GetClientName(i, sName, sizeof sName);
			bool iAlive = IsPlayerAlive(i);
			int iTeam = GetClientTeam(i);
			if (!GetClientAuthId(i, AuthId_SteamID64, sSteamID, sizeof sSteamID))
				return;
			
			jsonPlayerArray.SetInt("userid", GetClientUserId(i));
			jsonPlayerArray.SetString("name", sName);
			jsonPlayerArray.SetBool("alive", iAlive);
			jsonPlayerArray.SetInt("team", iTeam);
			jsonPlayerArray.SetString("steamid", sSteamID);
			
			jsonArray.Push(jsonPlayerArray);
			delete jsonPlayerArray;
		}
		json.Set("players", jsonArray);
		Send(json, socket);
	}
	
}

public void Socket_OnDisconnect(Handle socket, any arg)
{
	socketList.Erase(socketList.FindValue(socket));
	LogMessage("Disconnect Socket(%i)", socket);
	delete socket;
}

public void OnPluginEnd()
{
	delete masterSocket;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	char name[128];
	GetClientName(client, name, sizeof name);

	char sSteamID[64];
	if (!GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof sSteamID))
	return;

	JSONObject json = new JSONObject();
	json.SetString("name", name);
	json.SetString("message", sArgs);
	json.SetString("steamid", sSteamID);
	json.SetInt("userid", GetClientUserId(client));
	json.SetInt("type", 0);
	
	SendToAll(json);
}

void SendToAll(JSONObject json, Handle exclude = null)
{
	static char sJSON[1024];
	json.ToString(sJSON, sizeof sJSON);
	delete json;

	
	for (int i = 0; i < socketList.Length; i++)
	{
		Handle socket = socketList.Get(i);
		if (socket == exclude)
			continue;
			
		if (cv_bDebug.BoolValue)
		{
			LogMessage("Sent %s, to all sockets(%i)", sJSON, socket);
		}
		SocketSend(socket, sJSON);
	}
}

void Send(JSONObject json, Handle socket)
{
	static char sJSON[5120];
	json.ToString(sJSON, sizeof sJSON);
	delete json;
	if (cv_bDebug.BoolValue)
	{
		LogMessage("Sent %s, to %i", sJSON, socket);
	}
	SocketSend(socket, sJSON);
}