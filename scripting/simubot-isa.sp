#if defined _SIMUBOT_ISA_included
 #endinput
#endif
#define _SIMUBOT_ISA_included

#include <smlib/clients>
#include <smlib/entities>
#include <botcontroller>

#include "simubot.sp"

// Integer registers
#define R_EAX			0x0
#define R_ECX			0x1
#define R_EDX			0x2
#define R_EBX			0x3
#define R_ESP			0x4
#define R_EBP			0x5
#define R_ESI			0x6
#define R_EDI			0x7
#define R_NONE			0xF

// Float registers
#define R_ST0			0x0
#define R_ST1			0x1
#define R_ST2			0x2
#define R_ST3			0x3
#define R_ST4			0x4
#define R_ST5			0x5
#define R_ST6			0x6
#define R_ST7			0x7


// Condition Flags
#define FL_ZERO			0x0
#define FL_SIGN			0x1
#define FL_OVERFLOW		0x2

// Y86
#define INST_HALT		0x0
#define INST_NOP		0x1
#define INST_CMOV		0x2
#define INST_IRMOV		0x3
#define INST_RMMOV		0x4
#define INST_MRMOV		0x5
#define INST_OP			0x6
#define INST_JXX		0x7
#define INST_CALL		0x8
#define INST_RET		0x9
#define INST_PUSH		0xA
#define INST_POP		0xB

// Custom floating point instructions
#define INST_FLSTC		0xC // Float stack control instructions
#define INST_FLOP		0xD // Floating point operations

// Custom game engine instruction
#define INST_SLEEP		0xF

// INST_SLEEP
#define FN_REG			0x0
#define FN_DWORD		0x1

// INST_OP
#define FN_ADD			0x0
#define FN_SUB			0x1
#define FN_MUL			0x2
#define FN_DIV			0x3
#define FN_MOD			0x4
#define FN_AND			0x5
#define FN_OR			0x6
#define FN_XOR			0x7
#define FN_NOT			0x8
#define FN_SHL			0x9
#define FN_SHR			0xA
#define FN_CMP			0xB
#define FN_TEST			0xC
#define FN_INC			0xD
#define FN_DEC			0xE
#define FN_CHS			0xF

// INST_FLST
#define FN_FLD			0x0
#define FN_FST			0x1
#define FN_FSTP			0x2
#define FN_FINCSTP		0x7
#define FN_FDECSTP		0x8

// INST_FLST subtype
#define S_ST			0x0
#define S_MEM			0x1


// INST_FLOP
#define FN_FADD			0x0
#define FN_FSUB			0x1
#define FN_FMUL			0x2
#define FN_FDIV			0x3

#define FN_FSIN			0x8
#define FN_FCOS			0x9

#define FN_FCOMP		0xB
#define FN_FTST			0xC
#define FN_FSQRT		0xD
#define FN_FABS			0xE
#define FN_FCHS			0xF

// INST_JXX
#define FN_NC			0x0
#define FN_LE			0x1
#define FN_L			0x2
#define FN_E			0x3
#define FN_NE			0x4
#define FN_GE			0x5
#define FN_G			0x6

// INST_CALL
#define FN_CALL			0x0
#define FN_CALLFWD		0x1

// ISA Command Forwards
enum Forwards {
	FW_GETPOS,
	FW_SETPOS,
	
	FW_GETANG,
	FW_SETANG,
	
	FW_GETVEL,
	FW_SETVEL,

	FW_GETLVEL,
	FW_SETLVEL,
	
	FW_GETBUTN,
	FW_SETBUTN,
	
	FW_SPWNBOT,
	FW_KICKBOT,
	
	FW_GETTEAM,
	FW_SETTEAM,
	
	FW_GETCLASS,
	FW_SETCLASS,
	
	FW_RESPAWN,
	FW_SAY,
	FW_CHAT,
	FW_COUT
}

StringMap g_hInstMap;

static any readValue(int iAddress) {
	return g_sProgram[iAddress] | g_sProgram[iAddress + 1] << 8 | g_sProgram[iAddress + 2] << 16 | g_sProgram[iAddress + 3] << 24;
}

static any getArg(int i) {
	return readValue(g_iReg[R_EBP] + 8 + 4*i);
}

static void writeValue(int iAddress, any aValue) {
	g_sProgram[iAddress] = aValue & 0xFF;
	g_sProgram[iAddress+1] = (aValue>>>8) & 0xFF;
	g_sProgram[iAddress+2] = (aValue>>>16) & 0xFF;
	g_sProgram[iAddress+3] = (aValue>>>24) & 0xFF;
}

static void setArg(int i, any aValue) {
	writeValue(g_iReg[R_EBP] + 8 + 4*i, aValue);
}

public int isaForward(int iFwdID) {
	// PrintToServer("[SB] Call forward: 0x%X", iFwdID);
	switch (iFwdID) {
		case FW_GETPOS: {
			float fPos[3];
			Entity_GetAbsOrigin(getArg(0), fPos);
			
			setArg(1, fPos[0]);
			setArg(2, fPos[1]);
			setArg(3, fPos[2]);
		}

		case FW_SETPOS: {
			float fPos[3];
			fPos[0] = getArg(1);
			fPos[1] = getArg(2);
			fPos[2] = getArg(3);
			Entity_SetAbsOrigin(getArg(0), fPos);
		}
		
		case FW_SETANG: {
			int iClient = getArg(0);
			float fAng[3];
			fAng[0] = getArg(1);
			fAng[1] = getArg(2);
			fAng[2] = getArg(3);
			
			g_iClientData[iClient][0] = fAng[0];
			g_iClientData[iClient][1] = fAng[1];
			g_iClientData[iClient][2] = fAng[2];
			
			// PrintToServer("[SB] Setting angles [%.1f, %.1f, %.1f]: %L", fAng[0], fAng[1], fAng[2], iClient);
			//Entity_SetAbsAngles(iClient, fAng);
			//TeleportEntity(iClient, NULL_VECTOR, fAng, NULL_VECTOR);
		}
		

		case FW_GETVEL: {
			float fPos[3];
			Entity_GetAbsVelocity(getArg(0), fPos);
			
			setArg(1, fPos[0]);
			setArg(2, fPos[1]);
			setArg(3, fPos[2]);
		}
		
		case FW_SETVEL: {
			float fVel[3];
			fVel[0] = getArg(1);
			fVel[1] = getArg(2);
			fVel[2] = getArg(3);
			
			Entity_SetAbsVelocity(getArg(0), fVel);
		}
		
		case FW_SETLVEL: {
			int iClient = getArg(0);
			g_iClientData[iClient][3] = getArg(1);
			g_iClientData[iClient][4] = getArg(2);
			g_iClientData[iClient][5] = getArg(3);
			
			// PrintToServer("[SB] Setting localvel [%.1f, %.1f, %.1f]: %L", g_iClientData[iClient][3], g_iClientData[iClient][4], g_iClientData[iClient][5], iClient);
		}
		
		case FW_SETBUTN: {
			int iClient = getArg(0);
			int iButn = getArg(1);
			
			// PrintToServer("[SB] Setting buttons to 0x%X: %L", iButn, iClient);
			
			Client_SetButtons(iClient, iButn);
			g_iClientData[iClient][6] = view_as<any>(iButn);
		}
		
		case FW_SPWNBOT: {
			int iBot = BotController_CreateBot("SimuBOT");
			PrintToServer("[SB] Spawned bot: %L", iBot);
			if (iBot != -1) {
				g_bBots[iBot] = true;
			}
			return iBot;
		}
		
		case FW_KICKBOT: {
			int iClient = getArg(0);
			PrintToServer("Trying to kick client %d", iClient);
			if (g_bBots[iClient]) {
				PrintToServer("[SB] Kicking: %L", iClient);
				KickClient(iClient, "Kicked by simulator");
				g_bBots[iClient] = false;
				
				g_iClientData[iClient][0] = 0.0;
				g_iClientData[iClient][1] = 0.0;
				g_iClientData[iClient][2] = 0.0;
				g_iClientData[iClient][3] = 0.0;
				g_iClientData[iClient][4] = 0.0;
				g_iClientData[iClient][5] = 0.0;
				g_iClientData[iClient][6] = view_as<any>(0);
			} else {
				PrintToServer("[SB] Cannot kick non-bot: %L", iClient);
			}
		}
		
		case FW_SETTEAM: {
			int iClient = getArg(0);
			int iTeam = getArg(1);
			TF2_ChangeClientTeam(iClient, view_as<TFTeam>(iTeam));
			// PrintToServer("[SB] Changed team to %d: %L", iTeam, iClient);
		}
		
		case FW_SETCLASS: {
			int iClient = getArg(0);
			int iClass = getArg(1);
			TF2_SetPlayerClass(iClient, view_as<TFClassType>(iClass));
			// PrintToServer("[SB] Changed class to %d: %L", iClass, iClient);
		}
		
		case FW_RESPAWN: {
			int iClient = getArg(0);
			TF2_RespawnPlayer(iClient);
			// PrintToServer("[SB] Respawning: %L", iClient);
		}
		
		case FW_SAY: {
			int iClient = getArg(0);
			char sBuffer[128];
			doFormat(2, sBuffer, g_sProgram[getArg(1)]);
			FakeClientCommand(iClient, "say %s", sBuffer);
			
			PrintToServer("[SB] Force saying \"%s\": %L", sBuffer, iClient);
		}
		
		case FW_CHAT: {
			char sBuffer[128];
			doFormat(1, sBuffer, g_sProgram[getArg(0)]);
			PrintToChatAll(sBuffer);
		}
		
		case FW_COUT: {
			char sBuffer[128];
			doFormat(1, sBuffer, g_sProgram[getArg(0)]);
			PrintToServer(sBuffer);
		}
		
		default: {
			SetFailState("[SB] Unknown call forward: 0x%X", iFwdID);
		}			
	}
	
	return 0;
}

static void doFormat(int iParamOffset, char sBuffer[128], char[] sFormat) {
	int iParams = getArg(iParamOffset);
	switch (iParams) {
		case 0: {
			strcopy(sBuffer, sizeof(sBuffer), sFormat);
		}
		case 1: {
			Format(sBuffer, sizeof(sBuffer), sFormat, getArg(iParamOffset+1));
		}
		case 2: {
			Format(sBuffer, sizeof(sBuffer), sFormat,
				getArg(iParamOffset+1), getArg(iParamOffset+2));
		}
		case 3: {
			Format(sBuffer, sizeof(sBuffer), sFormat,
				getArg(iParamOffset+1), getArg(iParamOffset+2), getArg(iParamOffset+3));
		}
		case 4: {
			Format(sBuffer, sizeof(sBuffer), sFormat,
				getArg(iParamOffset+1), getArg(iParamOffset+2), getArg(iParamOffset+3), getArg(iParamOffset+4));
		}
		default: {
			SetFailState("[SB] Too many format parameters (max 4): %d", iParams);
		}
	}
}

public void loadKeywords() {
	// Registers
	addMap("eax", R_EAX);
	addMap("ecx", R_ECX);
	addMap("edx", R_EDX);
	addMap("ebx", R_EBX);
	addMap("esp", R_ESP);
	addMap("ebp", R_EBP);
	addMap("esi", R_ESI);
	addMap("edi", R_EDI);

	addMap("st(0)", R_ST0);
	addMap("st(1)", R_ST1);
	addMap("st(2)", R_ST2);
	addMap("st(3)", R_ST3);
	addMap("st(4)", R_ST4);
	addMap("st(5)", R_ST5);
	addMap("st(6)", R_ST6);
	addMap("st(7)", R_ST7);
	
	// Instructions
	addMap("halt", 		INST_HALT	<< 4);
	addMap("nop", 		INST_NOP	<< 4);
	
	addMap("rrmovl",	INST_CMOV	<< 4	| FN_NC);
	addMap("cmovl", 	INST_CMOV	<< 4 	| FN_L);
	addMap("cmovle",	INST_CMOV	<< 4 	| FN_LE);
	addMap("cmove",		INST_CMOV	<< 4	| FN_E);
	addMap("cmovne",	INST_CMOV	<< 4 	| FN_NE);
	addMap("cmovg",		INST_CMOV	<< 4	| FN_GE);
	addMap("cmovge",	INST_CMOV	<< 4	| FN_G);
	
	addMap("irmovl", 	INST_IRMOV	<< 4);
	addMap("rmmovl", 	INST_RMMOV	<< 4);
	addMap("mrmovl", 	INST_MRMOV	<< 4);
	
	addMap("addl",		INST_OP		<< 4	| FN_ADD);
	addMap("subl",		INST_OP		<< 4	| FN_SUB);
	addMap("mull",		INST_OP		<< 4	| FN_MUL);
	addMap("divl",		INST_OP		<< 4	| FN_DIV);
	addMap("modl",		INST_OP		<< 4	| FN_MOD);
	addMap("andl",		INST_OP		<< 4	| FN_AND);
	addMap("orl",		INST_OP		<< 4	| FN_OR);
	addMap("xorl",		INST_OP		<< 4	| FN_XOR);
	addMap("notl",		INST_OP		<< 4	| FN_NOT);
	addMap("shl",		INST_OP		<< 4	| FN_SHL);
	addMap("shr",		INST_OP		<< 4	| FN_SHR);
	addMap("cmpl",		INST_OP		<< 4	| FN_CMP);
	addMap("testl",		INST_OP		<< 4	| FN_TEST);
	addMap("incl",		INST_OP		<< 4	| FN_INC);
	addMap("decl",		INST_OP		<< 4	| FN_DEC);
	addMap("chsl",		INST_OP		<< 4	| FN_CHS);
	
	addMap("jmp",		INST_JXX	<< 4	| FN_NC);
	addMap("jle",		INST_JXX	<< 4	| FN_LE);
	addMap("jl",		INST_JXX	<< 4	| FN_L);
	addMap("je",		INST_JXX	<< 4	| FN_E);
	addMap("jne",		INST_JXX	<< 4	| FN_NE);
	addMap("jge",		INST_JXX	<< 4	| FN_GE);
	addMap("jg",		INST_JXX	<< 4	| FN_G);
	
	addMap("call",		INST_CALL	<< 4);
	addMap("ret",		INST_RET	<< 4);
	addMap("pushl",		INST_PUSH	<< 4);
	addMap("popl",		INST_POP	<< 4);
	
	addMap("fld",		INST_FLSTC	<< 4	| FN_FLD);
//	addMap("fldr",		INST_FLSTC	<< 4	| FN_FLDR);
//	addMap("fild",		INST_FLSTC	<< 4	| FN_FILD);
	addMap("fst",		INST_FLSTC	<< 4	| FN_FST);
//	addMap("fstr",		INST_FLSTC	<< 4	| FN_FSTR);
	addMap("fstp",		INST_FLSTC	<< 4	| FN_FSTP);
//	addMap("fstrp",		INST_FLSTC	<< 4	| FN_FSTRP);
	addMap("fincstp",	INST_FLSTC	<< 4	| FN_FINCSTP);
	addMap("fdecstp",	INST_FLSTC	<< 4	| FN_FDECSTP);
	
	addMap("fadd",		INST_FLOP	<< 4	| FN_FADD);
	addMap("fsub",		INST_FLOP	<< 4	| FN_FSUB);
	addMap("fmul",		INST_FLOP	<< 4	| FN_FMUL);
	addMap("fdiv",		INST_FLOP	<< 4	| FN_FDIV);
	addMap("fsin",		INST_FLOP	<< 4	| FN_FSIN);
	addMap("fcos",		INST_FLOP	<< 4	| FN_FCOS);
	addMap("fcomp",		INST_FLOP	<< 4	| FN_FCOMP);
	addMap("ftst",		INST_FLOP	<< 4	| FN_FTST);
	addMap("fsqrt",		INST_FLOP	<< 4	| FN_FSQRT);
	addMap("fabs",		INST_FLOP	<< 4	| FN_FABS);
	addMap("fchs",		INST_FLOP	<< 4	| FN_FCHS);
	
	addMap("sleep",		INST_SLEEP	<< 4);
}

static void addMap(char[] sInst, int iInst) {
	g_hInstMap.SetValue(sInst, iInst);
}

public void addExternLabels(StringMap hLabelMap) {
	// External function labels
	hLabelMap.SetValue("_getpos",		FW_GETPOS);
	hLabelMap.SetValue("_setpos",		FW_SETPOS);
	hLabelMap.SetValue("_setang",		FW_SETANG);
	hLabelMap.SetValue("_getvel",		FW_GETVEL);
	hLabelMap.SetValue("_setvel",		FW_SETVEL);
	hLabelMap.SetValue("_setbuttons",	FW_SETBUTN);
	hLabelMap.SetValue("_setlvel",		FW_SETLVEL);
	hLabelMap.SetValue("_spawnbot",		FW_SPWNBOT);
	hLabelMap.SetValue("_kickbot",		FW_KICKBOT);
	hLabelMap.SetValue("_setteam",		FW_SETTEAM);
	hLabelMap.SetValue("_setclass",		FW_SETCLASS);
	hLabelMap.SetValue("_respawn",		FW_RESPAWN);
	hLabelMap.SetValue("_say",			FW_SAY);
	hLabelMap.SetValue("_chat",			FW_CHAT);
	hLabelMap.SetValue("_cout",			FW_COUT);
}
