#if defined _SIMUBOT_included
 #endinput
#endif
#define _SIMUBOT_included
#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR 	"AI"
#define PLUGIN_VERSION 	"0.1.0"
#define SIM_PATH	"data/simubot"

#include <sourcemod>
#include <regex>
#include <sdktools>
#include <smlib/strings>
#include <tf2>
#include <tf2_stocks>
#include <botcontroller>
//#include <sdkhooks>

ArrayList g_hBots;
char g_sProgram[16384];
int g_iProgramSize;
int g_iReg[8];
float g_fReg[8];
int g_iFTOS; // Float-point registers' top of stack index
bool g_bFlags[3];

bool g_bRunning;
int g_iPC;
int g_iPCLast;
int g_iFrameSkip;

bool g_bBots[MAXPLAYERS+1];
float g_iClientData[MAXPLAYERS + 1][7];

#include "simubot-isa.sp"

public Plugin myinfo = 
{
	name = "Simulation Bot",
	author = PLUGIN_AUTHOR,
	description = "Research test and simulation bot",
	version = PLUGIN_VERSION,
	url = "https://jump.tf"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_sim", cmdSim, ADMFLAG_ROOT, "Run simulation");
	RegAdminCmd("sm_comp", cmdCompile, ADMFLAG_ROOT, "Compile and load simulation ASM");
	RegAdminCmd("sm_mem", cmdMem, ADMFLAG_ROOT, "Dump memory contents");
	RegAdminCmd("sm_halt", cmdHalt, ADMFLAG_ROOT, "Force simulation terminaton");
	g_hBots = new ArrayList();
	g_hInstMap = new StringMap();
	
	loadKeywords();
}

public void OnPluginEnd() {
	for (int i = 0; i < g_hBots.Length; i++) {
		KickClient(g_hBots.Get(i), "Simulator shutdown");
	}
}

public void OnMapStart() {
	g_bRunning = false;
}

public void OnMapEnd() {
	g_hBots.Clear();
	g_bRunning = false;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &weapon) {
	if (g_bBots[iClient]) {
		fAng[0] = g_iClientData[iClient][0];
		fAng[1] = g_iClientData[iClient][1];
		fAng[2] = g_iClientData[iClient][2];
		
		fVel[0] = g_iClientData[iClient][3];
		fVel[1] = g_iClientData[iClient][4];
		fVel[2] = g_iClientData[iClient][5];
			
		iButtons = view_as<int>(g_iClientData[iClient][6]);
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public void OnGameFrame() {
	while (g_bRunning && g_iPC < sizeof(g_sProgram)) {
		if (g_iFrameSkip != 0) {
			g_iFrameSkip--;
			//PrintToServer("[SB] Skipping frame");
			return;
		}
		
		if (g_iPC == g_iPCLast) {
			SetFailState("Simulator Error (PC: 0x%X) - Program counter not progressing", g_iPC);
		}
		g_iPCLast = g_iPC;
		
		int iInst = view_as<int>(g_sProgram[g_iPC]);
		int iCode = (iInst >>> 4) & 0xF;
		int iFun = iInst & 0xF;
		
		//PrintToServer("  0x%04X: INST (0x%X)", g_iPC, iInst);
		
		switch (iCode) {
			case INST_HALT: {
				PrintToServer("[SB] (PC: 0x%X) Termination", g_iPC);
				g_bRunning = false;
				g_iPC++;
			}
			
			case INST_NOP: {
				g_iPC++;
			}
			
			case INST_CMOV: {
				int iRegs = view_as<int>(g_sProgram[g_iPC + 1]);
				int iRA = (iRegs >>> 4) & 0xF;
				int iRB = iRegs & 0xF;
				
				if (checkCond(iFun)) {
					g_iReg[iRB] = g_iReg[iRA];
				}
				
				g_iPC+=2;
			}
			
			case INST_IRMOV: {
				int iRegID = g_sProgram[g_iPC+1] & 0xF;
				g_iReg[iRegID] = g_sProgram[g_iPC+2] | g_sProgram[g_iPC+3] << 8 | g_sProgram[g_iPC+4] << 16 | g_sProgram[g_iPC+5] << 24;
				g_iPC += 6;
			}
			
			case INST_RMMOV: {
				int iRegs = view_as<int>(g_sProgram[g_iPC + 1]);
				int iRA = (iRegs >>> 4) & 0xF;
				int iRB = iRegs & 0xF;
				int iD = g_sProgram[g_iPC+2] | g_sProgram[g_iPC+3] << 8 | g_sProgram[g_iPC+4] << 16 | g_sProgram[g_iPC+5] << 24;
				
				g_sProgram[g_iReg[iRB] + iD] = g_iReg[iRA] & 0xFF;
				g_sProgram[g_iReg[iRB] + iD+1] = (g_iReg[iRA]>>>8) & 0xFF;
				g_sProgram[g_iReg[iRB] + iD+2] = (g_iReg[iRA]>>>16) & 0xFF;
				g_sProgram[g_iReg[iRB] + iD+3] = (g_iReg[iRA]>>>24) & 0xFF;
				g_iPC += 6;
			}
			
			case INST_MRMOV: {
				int iRegs = view_as<int>(g_sProgram[g_iPC + 1]);
				int iRA = (iRegs >>> 4) & 0xF;
				int iRB = iRegs & 0xF;
				int iD = g_sProgram[g_iPC+2] | g_sProgram[g_iPC+3] << 8 | g_sProgram[g_iPC+4] << 16 | g_sProgram[g_iPC+5] << 24;
				
				g_iReg[iRA] = g_sProgram[g_iReg[iRB] + iD] | g_sProgram[g_iReg[iRB] + iD+1] << 8 | g_sProgram[g_iReg[iRB] + iD+2] << 16 | g_sProgram[g_iReg[iRB] + iD+3] << 24;
				g_iPC += 6;
			}
			
			case INST_OP: {
				int iRegs = view_as<int>(g_sProgram[g_iPC + 1]);
				int iRA = (iRegs >>> 4) & 0xF;
				int iRB = iRegs & 0xF;
				
				int iResult;
				switch (iFun) {
					case FN_ADD: {
						iResult = g_iReg[iRB] + g_iReg[iRA];
						g_bFlags[FL_OVERFLOW] = ((g_iReg[iRB] < 0) == (g_iReg[iRA] < 0)) && ((g_iReg[iRB] < 0) != (iResult < 0));
					}
					case FN_SUB, FN_CMP: {
						iResult = g_iReg[iRB] - g_iReg[iRA];
						g_bFlags[FL_OVERFLOW] = ((g_iReg[iRB] < 0) != (g_iReg[iRA] < 0)) && ((g_iReg[iRB] < 0) != (iResult < 0));
					}
					case FN_MUL: {
						iResult = g_iReg[iRB] * g_iReg[iRA];
						g_bFlags[FL_OVERFLOW] = (g_iReg[iRA] != 0) && (iResult / g_iReg[iRA] != g_iReg[iRB]);
					}
					case FN_DIV: {
						iResult = g_iReg[iRB] / g_iReg[iRA];
						g_bFlags[FL_OVERFLOW] = false;
					}
					case FN_MOD: {
						iResult = g_iReg[iRB] % g_iReg[iRA];
						g_bFlags[FL_OVERFLOW] = false;
					}
					case FN_AND, FN_TEST: {
						iResult = g_iReg[iRB] & g_iReg[iRA];
						g_bFlags[FL_OVERFLOW] = false;
					}
					case FN_OR: {
						iResult = g_iReg[iRB] | g_iReg[iRA];
						g_bFlags[FL_OVERFLOW] = false;
					}
					case FN_XOR: {
						iResult = g_iReg[iRB] ^ g_iReg[iRA];
						g_bFlags[FL_OVERFLOW] = false;
					}
					case FN_NOT: {
						iResult = !g_iReg[iRB];
						g_bFlags[FL_OVERFLOW] = false;
					}
					case FN_SHL: {
						iResult = g_iReg[iRB] << g_iReg[iRA];
						g_bFlags[FL_OVERFLOW] = false;
					}
					case FN_SHR: {
						iResult = g_iReg[iRA] >>> g_iReg[iRB];
						g_bFlags[FL_OVERFLOW] = false;
					}
					case FN_INC: {
						iResult = g_iReg[iRB]+1;
						g_bFlags[FL_OVERFLOW] = (g_iReg[iRB] >= 0) && ((g_iReg[iRB] < 0) != (iResult < 0));
					}
					case FN_DEC: {
						iResult = g_iReg[iRB]-1;
						g_bFlags[FL_OVERFLOW] = (g_iReg[iRB] < 0) && ((g_iReg[iRB] < 0) != (iResult < 0));
					}
					case FN_CHS: {
						iResult = -g_iReg[iRB];
						g_bFlags[FL_OVERFLOW] = false;
					}
				}
				
				g_bFlags[FL_ZERO] = (iResult == 0);
				g_bFlags[FL_SIGN] = (iResult < 0);
				
				if (iFun != FN_CMP && iFun != FN_TEST) {
					g_iReg[iRB] = iResult;
				}
				/*
				else {
					PrintToServer("[SB] Check flags: zf=%d, sf=%d, of=%d", g_bFlags[FL_ZERO], g_bFlags[FL_SIGN], g_bFlags[FL_OVERFLOW]);
				}
				*/
				g_iPC+=2;
			}
			
			case INST_JXX: {
				if (checkCond(iFun)) {
					g_iPC = g_sProgram[g_iPC+1] | g_sProgram[g_iPC+2] << 8 | g_sProgram[g_iPC+3] << 16 | g_sProgram[g_iPC+4] << 24;
				} else {
					g_iPC += 5;
				}
			}
			
			case INST_CALL: {
				switch (iFun) {
					case FN_CALL: {
						int iPCNext = g_iPC+5;
						g_iReg[R_ESP] -= 4;
						g_sProgram[g_iReg[R_ESP]] = iPCNext & 0xFF;
						g_sProgram[g_iReg[R_ESP]+1] = (iPCNext >>> 8) & 0xFF;
						g_sProgram[g_iReg[R_ESP]+2] = (iPCNext >>> 16) & 0xFF;
						g_sProgram[g_iReg[R_ESP]+3] = (iPCNext >>> 24) & 0xFF;
						
						g_iPC = g_sProgram[g_iPC+1] | g_sProgram[g_iPC+2] << 8 | g_sProgram[g_iPC+3] << 16 | g_sProgram[g_iPC+4] << 24;
					}
					case FN_CALLFWD: {
						int iBackupEBP = g_iReg[R_EBP];
						g_iReg[R_EBP] = g_iReg[R_ESP] - 8;
						g_iReg[R_EAX] = isaForward(g_sProgram[g_iPC+1] | g_sProgram[g_iPC+2] << 8 | g_sProgram[g_iPC+3] << 16 | g_sProgram[g_iPC+4] << 24);
						g_iReg[R_ESP] = iBackupEBP;
						g_iReg[R_EBP] = iBackupEBP;
						g_iPC+=5;
					}
					default: {
						SetFailState("Program Error (PC: %d) - Unknown call type: 0x%X", g_iPC, iFun);
					}
				}
			}
			
			case INST_RET: {
				g_iPC = g_sProgram[g_iReg[R_ESP]] | g_sProgram[g_iReg[R_ESP]+1] << 8 | g_sProgram[g_iReg[R_ESP]+2] << 16 | g_sProgram[g_iReg[R_ESP]+3] << 24;
				g_iReg[R_ESP] += 4;
			}
				
			case INST_PUSH: {
				int iRegs = view_as<int>(g_sProgram[g_iPC + 1]);
				int iRA = (iRegs >>> 4) & 0xF;
				
				g_iReg[R_ESP] -= 4;
				
				g_sProgram[g_iReg[R_ESP]] = g_iReg[iRA] & 0xFF;
				g_sProgram[g_iReg[R_ESP]+1] = (g_iReg[iRA] >>> 8) & 0xFF;
				g_sProgram[g_iReg[R_ESP]+2] = (g_iReg[iRA] >>> 16) & 0xFF;
				g_sProgram[g_iReg[R_ESP]+3] = (g_iReg[iRA] >>> 24) & 0xFF;

				g_iPC += 2;
			}
			
			case INST_POP: {
				int iRegs = view_as<int>(g_sProgram[g_iPC + 1]);
				int iRA = (iRegs >>> 4) & 0xF;
				
				g_iReg[iRA] = g_sProgram[g_iReg[R_ESP]] | g_sProgram[g_iReg[R_ESP]+1] << 8 | g_sProgram[g_iReg[R_ESP]+2] << 16 | g_sProgram[g_iReg[R_ESP]+3] << 24;
				g_iReg[R_ESP] += 4;
				
				g_iPC += 2;
			}
			
			case INST_FLSTC: {
				switch (iFun) {
					case FN_FLD: {
						if (g_iFTOS <= 0) {
							SetFailState("Program Error (PC: %d) - FPU stack overflow: fld", g_iPC);
						}
								
						int iRegs = view_as<int>(g_sProgram[g_iPC + 1]);
						int iRB = iRegs & 0xF;
						
						switch (iRegs >>> 4) {
							case S_ST: {
								g_fReg[--g_iFTOS] = g_fReg[iRB];
								g_iPC += 2;
							}
							case S_MEM: {
								int iD = g_sProgram[g_iPC+2] | g_sProgram[g_iPC+3] << 8 | g_sProgram[g_iPC+4] << 16 | g_sProgram[g_iPC+5] << 24;

								float fValue = view_as<float>(g_sProgram[g_iReg[iRB] + iD] | g_sProgram[g_iReg[iRB] + iD+1] << 8 | g_sProgram[g_iReg[iRB] + iD+2] << 16 | g_sProgram[g_iReg[iRB] + iD+3] << 24);
								g_fReg[--g_iFTOS] = fValue;
								
								// PrintToServer("fld: g_iFTOS=%d, iRB=%d, iD=%d, fValue=%f", g_iFTOS, iRB, iD, fValue);
								
								g_iPC += 6;
							}
							default: {
								SetFailState("Program Error (PC: %d) - Invalid FLST subtype: %d", g_iPC, iRegs >>> 4);
							}
						}
					}
					
					case FN_FST, FN_FSTP: {
						if (g_iFTOS >= sizeof(g_fReg)) {
							SetFailState("Program Error (PC: %d) - FPU stack underflow: fst/fstp", g_iPC);
						}
							
						int iRegs = view_as<int>(g_sProgram[g_iPC + 1]);
						int iRB = iRegs & 0xF;
						
						switch (iRegs >>> 4) {
							case S_ST: {
								g_fReg[g_iFTOS-iRB] = g_fReg[g_iFTOS];
								g_iPC += 2;
							}
							case S_MEM: {
								int iD = g_sProgram[g_iPC+2] | g_sProgram[g_iPC+3] << 8 | g_sProgram[g_iPC+4] << 16 | g_sProgram[g_iPC+5] << 24;
								
								int iVal = view_as<int>(g_fReg[g_iFTOS]);
								g_sProgram[g_iReg[iRB] + iD] = iVal & 0xFF;
								g_sProgram[g_iReg[iRB] + iD + 1] = (iVal >>> 8) & 0xFF;
								g_sProgram[g_iReg[iRB] + iD + 2] = (iVal >>> 16) & 0xFF;
								g_sProgram[g_iReg[iRB] + iD + 3] = (iVal >>> 24) & 0xFF;

								
								// PrintToServer("fst/fstp: g_iFTOS=%d, iRB=%d, iD=%d, fValue=%f", g_iFTOS, iRB, iD, g_fReg[g_iFTOS]);
								
								g_iPC += 6;
							}
							default: {
								SetFailState("Program Error (PC: %d) - Invalid FLST subtype: %d", g_iPC, iRegs >>> 4);
							}
						}
						
						if (iFun == FN_FSTP) {
							g_iFTOS++;
						}
					}
				}
			}
			
			case INST_FLOP: {
				g_bFlags[FL_OVERFLOW] = false; // IEEE-754 compliant clamps -inf, +inf
				
				float fResult;
				switch (iFun) {
					case FN_ADD: {
						fResult = g_fReg[g_iFTOS] + g_fReg[g_iFTOS+1];
						g_fReg[++g_iFTOS] = fResult;
					}
					case FN_FSUB: {
						fResult = g_fReg[g_iFTOS] - g_fReg[g_iFTOS+1];
						g_fReg[++g_iFTOS] = fResult;
					}
					case FN_FMUL: {
						fResult = g_fReg[g_iFTOS] * g_fReg[g_iFTOS+1];
						g_fReg[++g_iFTOS] = fResult;
					}
					case FN_FDIV: {
						fResult = g_fReg[g_iFTOS] / g_fReg[g_iFTOS+1];
						g_fReg[++g_iFTOS] = fResult;
					}
					case FN_FSIN: {
						fResult = Sine(g_fReg[g_iFTOS]);
						g_fReg[g_iFTOS] = fResult;
					}
					case FN_FCOS: {
						fResult = Cosine(g_fReg[g_iFTOS]);
						g_fReg[g_iFTOS] = fResult;
					}
					case FN_FCOMP: {
						fResult = g_fReg[g_iFTOS] - g_fReg[g_iFTOS+1];
					}
					case FN_FTST: {
						fResult = g_fReg[g_iFTOS];
					}
					case FN_FSQRT: {
						fResult = SquareRoot(g_fReg[R_ST0]);
					}
					case FN_FABS: {
						fResult = FloatAbs(g_fReg[R_ST0]);
					}
					case FN_FCHS: {
						fResult = -g_fReg[g_fReg[R_ST0]];
					}
				}
				
				g_bFlags[FL_ZERO] = (fResult == 0);
				g_bFlags[FL_SIGN] = (fResult < 0);

				// PrintToServer("flop: g_iFTOS=%d, fValue=%f", g_iFTOS, fResult);
				
				g_iPC++;
			}
			
			case INST_SLEEP: {
				switch (iFun) {
					case FN_REG: {
						int iReg = g_sProgram[g_iPC + 1] & 0xF;
						g_iFrameSkip = g_iReg[iReg];
						g_iPC += 2;
					}
					default: {
						g_iFrameSkip = g_sProgram[g_iPC+1] | g_sProgram[g_iPC+2] << 8 | g_sProgram[g_iPC+3] << 16 | g_sProgram[g_iPC+4] << 24;
						
						// PrintToServer("[SB] (PC: 0x%X) Frame skip %d", g_iPC, g_iFrameSkip);
						
						g_iPC+=5;
					}
				}
				
				if (g_iFrameSkip < 0) {
					g_iFrameSkip = 0;
				}
			}
			default: {
				SetFailState("Program Error (PC: %d) - Unknown instruction: %d", g_iPC, iCode);
			}
		}
		
	}
	
	if (g_iPC == sizeof(g_sProgram)) {
		PrintToServer("[SB] Reached end of program space (PC: %d)", g_iPC);
		g_iPC++;
	}
}

static bool checkCond(int iFun) {
	switch (iFun) {
		case FN_NC: {
			return true;
		}
		case FN_LE: {
			return (g_bFlags[FL_SIGN] ^ g_bFlags[FL_OVERFLOW]) | g_bFlags[FL_ZERO];
		}
		case FN_L: {
			return (g_bFlags[FL_SIGN] ^ g_bFlags[FL_OVERFLOW]);
		}
		case FN_E: {
			return g_bFlags[FL_ZERO];
		}
		case FN_NE: {
			return !g_bFlags[FL_ZERO];
		}
		case FN_GE: {
			return !(g_bFlags[FL_SIGN] ^ g_bFlags[FL_OVERFLOW]);
		}
		case FN_G: {
			return !(g_bFlags[FL_SIGN] ^ g_bFlags[FL_OVERFLOW]) & !g_bFlags[FL_ZERO];
		}
		default: {
			SetFailState("Program Error (PC: %d) - Unknown conditional subtype: %d", g_iPC, iFun);
		}
	}
	
	// Unreachable
	return false;
}

public bool loadASM(char sFilePath[PLATFORM_MAX_PATH]) {
	PrintToServer("[SB] Compiling ASM: %s", sFilePath);
	File hFile = OpenFile(sFilePath, "r");
	
	int iLineNumber = 1;
	char sLine[64];
	int iPC = 0;
	StringMap hLabelMap = new StringMap();
	StringMap hLabelFillMap = new StringMap();
	addExternLabels(hLabelMap);
	
	char sError[64];
	char sMatch[64];
	RegexError e;
	
	while (hFile.ReadLine(sLine, sizeof(sLine))) {
		TrimString(sLine);
		if (!sLine[0] || sLine[0] == ';') {
			iLineNumber++;
			continue;
		}
		
		if (iPC >= 0.9*sizeof(g_sProgram)) {
			PrintToServer("[SB] ASM Error (Line %d): Memory limit reached (%d/%d bytes): Unable to reserve 10%% stack space", iLineNumber, iPC, sizeof(g_sProgram));
			return false;
		}
		
		// Reset for regex
		sMatch[0] = 0;
		
		int iLabelIdx = FindCharInString (sLine, ':');
		if (iLabelIdx != -1) {
			// https://regex101.com/r/xX1mE4/2
			Regex r = new Regex("^([a-z_]\\w*)\\s*:", PCRE_CASELESS, sError, sizeof(sError), e);
			if (r.Match(sLine, e) < 1) {
				PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sLine);
				delete r;
				return false;
			}
			
			r.GetSubString(1, sMatch, sizeof(sMatch)); // Label
			
			int iTemp;
			if (hLabelMap.GetValue(sMatch, iTemp)) {
				PrintToServer("[SB] ASM Error (Line %d): Duplicate label: %s", iLineNumber, sMatch);
				delete r;
				return false;
			}
			
			hLabelMap.SetValue(sMatch, iPC);
			
			PrintToServer("  %3d: 0x%04X  LABEL      | %s", iLineNumber, iPC, sMatch);
			strcopy(sLine, sizeof(sLine), sLine[iLabelIdx + 1]);
			TrimString(sLine);
		
			if (!sLine[0]) {
				iLineNumber++;
				delete r;
				continue;
			}
			
			delete r;
		}
		
		int iCommentIdx = FindCharInString (sLine, ';');
		if (iCommentIdx != -1) {
			sLine[iCommentIdx] = 0;
			TrimString(sLine);
			
			if (!sLine[0]) {
				iLineNumber++;
				continue;
			}
		}
		
		// Handle directives
		if (sLine[0] == '.') {
			PrintToServer("  %3d: 0x%04X  DIR        | %s", iLineNumber, iPC, sLine);
			
			if (StrContains (sLine, ".align", false) == 0) {
				// https://regex101.com/r/rL5iK8/1
				Regex r = new Regex("^\\.align\\s+(0[xX][\\da-fA-F]+|\\d+)$", 0, sError, sizeof(sError), e);
				if (r.Match(sLine, e) < 1) {
					PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sLine);
					delete r;
					return false;
				}
				
				r.GetSubString(1, sMatch, sizeof(sMatch));
				
				// If found 0x, hex base
				int iVal;
				if (StrContains(sMatch, "0x", false) == 0) {
					iVal = StringToInt(sMatch[2], 16);
				} else {
					iVal = StringToInt(sMatch);
				}
				
				while (iPC & iVal != iVal) {
					iPC++;
				}
				
				delete r;
			} else if (StrContains (sLine, ".ascii", false) == 0) {
				// https://regex101.com/r/sP1jK6/2
				Regex r = new Regex("^\\.ascii\\s+\"(.*)\"$", 0, sError, sizeof(sError), e);
				if (r.Match(sLine, e) < 1) {
					PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sLine);
					delete r;
					return false;
				}
				
				r.GetSubString(1, sMatch, sizeof(sMatch));
				int i = 0;
				while (sMatch[i]) {
					g_sProgram[iPC++] = sMatch[i++];
				}
				g_sProgram[iPC++] = 0; // NULL string termination character
				
				delete r;
			} 
			else if (StrContains(sLine, ".long", false) == 0) {
				Regex r = new Regex("^\\.long\\s+(0[xX][\\da-fA-F]+|\\d+)$", 0, sError, sizeof(sError), e);
				if (r.Match(sLine, e) < 1) {
					PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sLine);
					delete r;
					return false;
				}
				
				r.GetSubString(1, sMatch, sizeof(sMatch));
				
				// If found 0x, hex base
				int iVal;
				if (StrContains(sMatch, "0x", false) == 0) {
					iVal = StringToInt(sMatch[2], 16);
				} else {
					iVal = StringToInt(sMatch);
				}
				delete r;
				
				g_sProgram[iPC] = iVal & 0xFF;
				g_sProgram[iPC+1] = (iVal>>>8) & 0xFF;
				g_sProgram[iPC+2] = (iVal>>>16) & 0xFF;
				g_sProgram[iPC+3] = (iVal>>>24) & 0xFF;
				
				iPC += 4;
			} else if (StrContains (sLine, ".pos", false) == 0) {
				// https://regex101.com/r/rL5iK8/1
				Regex r = new Regex("^\\.pos\\s+(0[xX][\\da-fA-F]+|\\d+)$", 0, sError, sizeof(sError), e);
				if (r.Match(sLine, e) < 1) {
					PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sLine);
					delete r;
					return false;
				}
				
				r.GetSubString(1, sMatch, sizeof(sMatch));
				
				// If found 0x, hex base
				int iVal;
				if (StrContains(sMatch, "0x", false) == 0) {
					iVal = StringToInt(sMatch[2], 16);
				} else {
					iVal = StringToInt(sMatch);
				}

				delete r;
				iPC = iVal;
			} else {
				PrintToServer("[SB] ASM Error (Line %d): Unknown directive (%s)", iLineNumber, sLine[1]);
				return false;
			}
			
			iLineNumber++;
			continue;
		}
		
		int iInstSplit = FindCharInString(sLine, ' ');
		if (iInstSplit == -1) { 
			iInstSplit = FindCharInString(sLine, '\t');
		}
		if (iInstSplit == -1) {
			int iCode;
			if (g_hInstMap.GetValue(sLine, iCode)) {
				PrintToServer("  %3d: 0x%04X  INST (0x%X) | %s", iLineNumber, iPC, iCode>>4, sLine);
				g_sProgram[iPC++] = iCode;
				iLineNumber++;
				continue;
			} else {
				PrintToServer("[SB] ASM Error (Line %d): Unknown instruction (%s)", iLineNumber, sLine);
				return false;
			}
		}
		
		char sInst[8];
		strcopy(sInst, iInstSplit+1, sLine);

		int iCode;
		if (g_hInstMap.GetValue(sInst, iCode)) {
			PrintToServer("  %3d: 0x%04X  INST (0x%X) | %s", iLineNumber, iPC, iCode>>4, sLine);
		} else {
			PrintToServer("[SB] ASM Error (Line %d): Unknown instruction (%s)", iLineNumber, sInst);
			return false;
		}
		
		int iFun = iCode & 0xF;
		g_sProgram[iPC] = iCode;
		
		char sParts[64];
		strcopy(sParts, sizeof(sParts), sLine[iInstSplit+1]);
		TrimString(sParts);
		
		switch (iCode >>> 4) {
			case INST_IRMOV: {
				// https://regex101.com/r/kE9yG4/3
				Regex r = new Regex("^(\\$(0[xX][\\da-fA-F]+|-?\\d+)|[a-z]\\w*),\\s*%([a-z]{3})", 0, sError, sizeof(sError), e);
				if (r.Match(sParts, e) < 2) {
					PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sParts);
					delete r;
					return false;
				}
				
				int iRegB;
				r.GetSubString(3, sMatch, sizeof(sMatch));
				if (!g_hInstMap.GetValue(sMatch, iRegB)) {
					PrintToServer("[SB] ASM Error (Line %d): Invalid register: %s", iLineNumber, sMatch);
					delete r;
					return false;
				}
				
				g_sProgram[iPC+1] = iRegB;
				
				// If no value, i.e. label
				r.GetSubString(2, sMatch, sizeof(sMatch));
				
				if (sMatch[0]) {
					// If found 0x, hex base
					int iVal;
					if (StrContains(sMatch, "0x", false) == 0) {
						iVal = StringToInt(sMatch[2], 16);
					} else {
						iVal = StringToInt(sMatch);
					}
	
					g_sProgram[iPC+2] = iVal & 0xFF;
					g_sProgram[iPC+3] = (iVal>>>8) & 0xFF;
					g_sProgram[iPC+4] = (iVal>>>16) & 0xFF;
					g_sProgram[iPC+5] = (iVal>>>24) & 0xFF;
				} else {
					r.GetSubString(1, sMatch, sizeof(sMatch)); // Label
					int iLabelInfo[2];
					iLabelInfo[0] = iPC + 2;
					iLabelInfo[1] = iLineNumber;
					
					ArrayList hList;
					if (!hLabelFillMap.GetValue(sMatch, hList)) {
						hList = new ArrayList(2);
						hLabelFillMap.SetValue(sMatch, hList);
					}
					hList.PushArray(iLabelInfo, 2);
				}
				
				delete r;
				
				iPC += 6;
			}
			
			case INST_CALL, INST_JXX, INST_SLEEP: {
				int iReg;
				if (iCode>>>4 == INST_SLEEP && sParts[0] == '%' && g_hInstMap.GetValue(sParts[1], iReg)) {
					g_sProgram[iPC] |= FN_REG & 0xF;
					g_sProgram[iPC+1] = iReg;
					iPC += 2;
				} else {
					// https://regex101.com/r/pM3uE7/2
					Regex r = new Regex("^(\\$(0[xX][\\da-fA-F]+|\\d+)|(_)?[a-z_]\\w*)$",  0, sError, sizeof(sError), e);
					if (r.Match(sParts, e) < 1) {
						PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sParts);
						delete r;
						return false;
					}
					
					// If no value, i.e. label
					r.GetSubString(2, sMatch, sizeof(sMatch));
					if (sMatch[0]) {
						// If found 0x, hex base
						int iVal;
						if (StrContains(sMatch, "0x", false) == 0) {
							iVal = StringToInt(sMatch[2], 16);
						} else {
							iVal = StringToInt(sMatch);
						}
						
						g_sProgram[iPC+1] = iVal & 0xFF;
						g_sProgram[iPC+2] = (iVal>>>8) & 0xFF;
						g_sProgram[iPC+3] = (iVal>>>16) & 0xFF;
						g_sProgram[iPC+4] = (iVal>>>24) & 0xFF;
					} else {
						r.GetSubString(3, sMatch, sizeof(sMatch));
						if (sMatch[0] == '_') {
							if (iCode>>>4 == INST_CALL) {
								g_sProgram[iPC] |= FN_CALLFWD;
							} else {
								PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sParts);
								delete r;
								return false;
							}
						}
						
						r.GetSubString(1, sMatch, sizeof(sMatch)); // Label
						int iLabelInfo[2];
						iLabelInfo[0] = iPC + 1;
						iLabelInfo[1] = iLineNumber;
						
						ArrayList hList;
						if (!hLabelFillMap.GetValue(sMatch, hList)) {
							hList = new ArrayList(2);
							hLabelFillMap.SetValue(sMatch, hList);
						}
						hList.PushArray(iLabelInfo, 2);
					}
					
					delete r;
					
					if (iCode>>>4 == INST_SLEEP) {
						g_sProgram[iPC] |= FN_DWORD & 0xF;
					}
					
					iPC += 5;
				}
			}
			case INST_OP, INST_CMOV: {
				if (iFun == FN_INC || iFun == FN_DEC) {
					int iReg;
					if (sParts[0] != '%' || !g_hInstMap.GetValue(sParts[1], iReg)) {
						PrintToServer("[SB] ASM Error (Line %d): Invalid register (%s)", iLineNumber, sParts);
						return false;
					}
					
					g_sProgram[iPC+1] = iReg; // rB
				} else {
					// https://regex101.com/r/hT3mA0/2
					Regex r = new Regex("^%([a-z]{3}),\\s*%([a-z]{3})", 0, sError, sizeof(sError), e);
					if (r.Match(sParts, e) < 2) {
						PrintToServer("[SB] ASM Error (Line %d): Incorrect syntax: %s", iLineNumber, sParts);
						delete r;
						return false;
					}
					
					int iRegA;
					r.GetSubString(1, sMatch, sizeof(sMatch));
					if (!g_hInstMap.GetValue(sMatch, iRegA)) {
						PrintToServer("[SB] ASM Error (Line %d): Invalid register (%s)", iLineNumber, sMatch);
						delete r;
						return false;
					}
					
					int iRegB;
					r.GetSubString(2, sMatch, sizeof(sMatch));
					if (!g_hInstMap.GetValue(sMatch, iRegB)) {
						PrintToServer("[SB] ASM Error (Line %d): Invalid register (%s)", iLineNumber, sMatch);
						return false;
					}
					
					delete r;
					
					g_sProgram[iPC + 1] = (iRegA << 4) | iRegB;
				}
				
				iPC += 2;
			}
			case INST_RMMOV: {
				// https://regex101.com/r/vM3cW6/2
				Regex r = new Regex("^%([a-z]{3}),\\s*((0[xX][\\da-fA-F]+|-?\\d+)|[a-z]\\w*)\\(%([a-z]{3})\\)", 0, sError, sizeof(sError), e);
				if (r.Match(sParts, e) < 3) {
					PrintToServer("[SB] ASM Error (Line %d): Incorrect syntax: %s", iLineNumber, sParts);
					delete r;
					return false;
				}
				
				int iRegA;
				r.GetSubString(1, sMatch, sizeof(sMatch));
				if (!g_hInstMap.GetValue(sMatch, iRegA)) {
					PrintToServer("[SB] ASM Error (Line %d): Invalid register: %s", iLineNumber, sMatch);
					delete r;
					return false;
				}
				
				int iRegB;
				r.GetSubString(4, sMatch, sizeof(sMatch));
				if (!g_hInstMap.GetValue(sMatch, iRegB)) {
					PrintToServer("[SB] ASM Error (Line %d): Invalid register: %s", iLineNumber, sMatch);
					delete r;
					return false;
				}
				
				g_sProgram[iPC+1] = (iRegA << 4) | iRegB;
				
				// If no value, i.e. label
				r.GetSubString(3, sMatch, sizeof(sMatch));
				if (sMatch[0]) {				
					// If found 0x, hex base
					int iOffset;
					if (StrContains(sMatch, "0x", false) == 0) {
						iOffset = StringToInt(sMatch[2], 16);
					} else {
						iOffset = StringToInt(sMatch);
					}
					
					g_sProgram[iPC+2] = iOffset & 0xFF;
					g_sProgram[iPC+3] = (iOffset>>>8) & 0xFF;
					g_sProgram[iPC+4] = (iOffset>>>16) & 0xFF;
					g_sProgram[iPC+5] = (iOffset>>>24) & 0xFF;
				} else {
					r.GetSubString(2, sMatch, sizeof(sMatch)); // Label
					int iLabelInfo[2];
					iLabelInfo[0] = iPC + 2;
					iLabelInfo[1] = iLineNumber;
					
					ArrayList hList;
					if (!hLabelFillMap.GetValue(sMatch, hList)) {
						hList = new ArrayList(2);
						hLabelFillMap.SetValue(sMatch, hList);
					}
					hList.PushArray(iLabelInfo, 2);
				}
				
				delete r;

				iPC += 6;
			}
			case INST_MRMOV: {
				// https://regex101.com/r/uX8eQ2/2
				Regex r = new Regex("^((0[xX][\\da-fA-F]+|-?\\d+)|[a-z]\\w*)\\(%([a-z]{3})\\),\\s*%([a-z]{3})", 0, sError, sizeof(sError), e);
				if (r.Match(sParts, e) < 3) {
					PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sParts);
					delete r;
					return false;
				}
				
				int iRegB;
				r.GetSubString(3, sMatch, sizeof(sMatch));
				if (!g_hInstMap.GetValue(sMatch, iRegB)) {
					PrintToServer("[SB] ASM Error (Line %d): Invalid register: %s", iLineNumber, sMatch);
					delete r;
					return false;
				}
				
				int iRegA;
				r.GetSubString(4, sMatch, sizeof(sMatch));
				if (!g_hInstMap.GetValue(sMatch, iRegA)) {
					PrintToServer("[SB] ASM Error (Line %d): Invalid register: %s", iLineNumber, sMatch);
					delete r;
					return false;
				}
				
				g_sProgram[iPC+1] = (iRegA << 4) | iRegB;
				
				// If no value, i.e. label
				r.GetSubString(2, sMatch, sizeof(sMatch));
				if (sMatch[0]) {
					// If found 0x, hex base
					int iOffset;
					if (StrContains(sMatch, "0x", false) == 0) {
						iOffset = StringToInt(sMatch[2], 16);
					} else {
						iOffset = StringToInt(sMatch);
					}
					
					g_sProgram[iPC+2] = iOffset & 0xFF;
					g_sProgram[iPC+3] = (iOffset>>>8) & 0xFF;
					g_sProgram[iPC+4] = (iOffset>>>16) & 0xFF;
					g_sProgram[iPC+5] = (iOffset>>>24) & 0xFF;
				} else {
					r.GetSubString(1, sMatch, sizeof(sMatch)); // Label
					int iLabelInfo[2];
					iLabelInfo[0] = iPC + 2;
					iLabelInfo[1] = iLineNumber;
					
					ArrayList hList;
					if (!hLabelFillMap.GetValue(sMatch, hList)) {
						hList = new ArrayList(2);
						hLabelFillMap.SetValue(sMatch, hList);
					}
					hList.PushArray(iLabelInfo, 2);
				}
				
				delete r;

				iPC += 6;
			}
			case INST_PUSH, INST_POP: {
				int iReg;
				if (sParts[0] != '%' || !g_hInstMap.GetValue(sParts[1], iReg)) {
					PrintToServer("[SB] ASM Error (Line %d): Invalid register (%s)", iLineNumber, sParts);
					return false;
				}
				
				g_sProgram[iPC+1] = iReg << 4; // rA
				iPC += 2;
			}
			case INST_FLSTC: {
				switch (iFun) {
					case FN_FLD, FN_FST, FN_FSTP: {
						int iST;
						if (g_hInstMap.GetValue(sParts, iST)) {
							g_sProgram[iPC+1] = (S_ST << 4) | iST;
							iPC += 2;
						} else {
							// https://regex101.com/r/rM8sL5/3
							Regex r = new Regex("^((0[xX][\\da-fA-F]+|\\d+)|[a-z]\\w*)\\(%([a-z]{3})\\)$", 0, sError, sizeof(sError), e);
							if (r.Match(sParts, e) < 3) {
								PrintToServer("[SB] ASM Error (Line %d): Bad syntax: %s", iLineNumber, sParts);
								delete r;
								return false;
							}
							
							int iRegB;
							r.GetSubString(3, sMatch, sizeof(sMatch));
							if (!g_hInstMap.GetValue(sMatch, iRegB)) {
								PrintToServer("[SB] ASM Error (Line %d): Invalid register: %s", iLineNumber, sMatch);
								delete r;
								return false;
							}
							
							g_sProgram[iPC+1] = (S_MEM << 4) | iRegB;
					
							// If no value, i.e. label
							r.GetSubString(2, sMatch, sizeof(sMatch));
							if (sMatch[0]) {
								// If found 0x, hex base
								int iOffset;
								if (StrContains(sMatch, "0x", false) == 0) {
									iOffset = StringToInt(sMatch[2], 16);
								} else {
									iOffset = StringToInt(sMatch);
								}
								
								g_sProgram[iPC+2] = iOffset & 0xFF;
								g_sProgram[iPC+3] = (iOffset>>>8) & 0xFF;
								g_sProgram[iPC+4] = (iOffset>>>16) & 0xFF;
								g_sProgram[iPC+5] = (iOffset>>>24) & 0xFF;
							} else {
								r.GetSubString(1, sMatch, sizeof(sMatch)); // Label
								int iLabelInfo[2];
								iLabelInfo[0] = iPC + 2;
								iLabelInfo[1] = iLineNumber;
								
								ArrayList hList;
								if (!hLabelFillMap.GetValue(sMatch, hList)) {
									hList = new ArrayList(2);
									hLabelFillMap.SetValue(sMatch, hList);
								}
								hList.PushArray(iLabelInfo, 2);
							}
							
							delete r;
			
							iPC += 6;
						}
					}
					default: {
						PrintToServer("[SB] ASM Error (Line %d): Unhandled float stack instruction (%s)", iLineNumber, sInst);
						return false;
					}
				}
			}
			case INST_FLOP: {
				switch (iFun) {
					default: {
						PrintToServer("[SB] ASM Error (Line %d): Unhandled floating point operation (%s)", iLineNumber, sInst);
						return false;
					}
				}
			}
			default: {
				PrintToServer("[SB] ASM Error (Line %d): Unhandled instruction (%s)", iLineNumber, sInst);
				return false;
			}
		}
		
		iLineNumber++;
	}
	
	if (hLabelFillMap.Size > 0) {
		StringMapSnapshot hLabelFillMapSnapshot = hLabelFillMap.Snapshot();
		char sLabel[64];
		int iLabelInfo[2];
		
		for (int i = 0; i < hLabelFillMapSnapshot.Length; i++) {
			hLabelFillMapSnapshot.GetKey(i, sLabel, sizeof(sLabel));
			
			ArrayList hList;
			hLabelFillMap.GetValue(sLabel, hList);
			
			int iVal;
			if (!hLabelMap.GetValue(sLabel, iVal)) {
				PrintToServer("[SB] ASM Error (Line %d): Label not found (%s)", iLabelInfo[1], sLabel);
				delete hLabelFillMapSnapshot;
				return false;
			}
			
			for (int j = 0; j < hList.Length; j++) {
				hList.GetArray(j, iLabelInfo, 2);
				
				PrintToServer("Subbing label: %s (0x%X) into program address (0x%X)", sLabel, iVal, iLabelInfo[0]);
				
				g_sProgram[iLabelInfo[0]] = iVal & 0xFF;
				g_sProgram[iLabelInfo[0]+1] = (iVal >>> 8) & 0xFF;
				g_sProgram[iLabelInfo[0]+2] = (iVal >>> 16) & 0xFF;
				g_sProgram[iLabelInfo[0]+3] = (iVal >>> 24) & 0xFF;
			}
			
			delete hList;
		}
		
		delete hLabelFillMapSnapshot;
	}
	
	delete hLabelFillMap;
	delete hLabelMap;
	delete hFile;
	
	g_iProgramSize = iPC;
	
	PrintToServer("Generated binary (%d bytes):", g_iProgramSize);
	printProgram(g_iProgramSize);
	
	return true;
}

public void printProgram(int iBytes) {
	for (int i = 0; i < iBytes && (i+15<sizeof(g_sProgram)); i+=16) {
		PrintToServer("  0x%04X:   %02X %02X %02X %02X    %02X %02X %02X %02X    %02X %02X %02X %02X    %02X %02X %02X %02X", i,
			view_as<int>(g_sProgram[i] & 0xFF), view_as<int>(g_sProgram[i+1] & 0xFF), view_as<int>(g_sProgram[i+2] & 0xFF), view_as<int>(g_sProgram[i+3] & 0xFF),
			view_as<int>(g_sProgram[i+4] & 0xFF), view_as<int>(g_sProgram[i+5] & 0xFF), view_as<int>(g_sProgram[i+6] & 0xFF), view_as<int>(g_sProgram[i+7] & 0xFF),
			view_as<int>(g_sProgram[i+8] & 0xFF), view_as<int>(g_sProgram[i+9] & 0xFF), view_as<int>(g_sProgram[i+10] & 0xFF), view_as<int>(g_sProgram[i+11] & 0xFF),
			view_as<int>(g_sProgram[i+12] & 0xFF), view_as<int>(g_sProgram[i+13] & 0xFF), view_as<int>(g_sProgram[i+14] & 0xFF), view_as<int>(g_sProgram[i+15] & 0xFF));
	}
}

// Commands
public Action cmdMem(int iClient, int iArgs) {
	PrintToServer("CPU Reg:");
	for (int i = 0; i < 8; i++) {
		PrintToServer("  r%d: 0x%X", i, g_iReg[i]);
	}
	PrintToServer("FPU Reg:");
	for (int i = 0; i < 8; i++) {
		PrintToServer("  st[%d]: %f", i, g_fReg[i]);
	}
	PrintToServer("Prgm Mem:");
	printProgram(g_iProgramSize);
	
	return Plugin_Handled;
}

public Action cmdHalt(int iClient, int iArgs) {
	g_bRunning = false;
	PrintToServer("[SB] (PC: 0x%X) Forced termination", g_iPC);
	return Plugin_Handled;
}

public Action cmdSim(int iClient, int iArgs) {
	if (g_bRunning) {
		PrintToServer("[SB] Simulaton already running");
	} else {
		PrintToServer("[SB] Beginning simulation");
		g_iFrameSkip = 0;
		g_iPC = 0;
		g_iFTOS = sizeof(g_fReg);
		g_bRunning = true;
		for (int i = 1; i <= MaxClients; i++) {
			g_iClientData[iClient][0] = 0.0;
			g_iClientData[iClient][1] = 0.0;
			g_iClientData[iClient][2] = 0.0;
			g_iClientData[iClient][3] = 0.0;
			g_iClientData[iClient][4] = 0.0;
			g_iClientData[iClient][5] = 0.0;
			g_iClientData[iClient][6] = view_as<any>(0);
		}
	}
	
	return Plugin_Handled;
}

public Action cmdCompile(int iClient, int iArgs) {
	if (iArgs != 1) {
		ReplyToCommand(iClient, "[SB] Usage: sm_sim <asm file>");
		return Plugin_Handled;
	}
	
	char sASMFile[PLATFORM_MAX_PATH];
	GetCmdArg(1, sASMFile, sizeof(sASMFile));
	
	char sASMFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sASMFilePath, sizeof(sASMFilePath), "%s/%s", SIM_PATH, sASMFile);
	if (!FileExists(sASMFilePath)) {
		ReplyToCommand(iClient, "[SB] Cannot find simbot ASM:  %s", sASMFilePath);
		return Plugin_Handled;
	}
	
	g_iFrameSkip = 0;
	g_iPC = 0;
	g_iPCLast = -1;
	g_iFTOS = sizeof(g_fReg);
	
	if (!loadASM(sASMFilePath)) {
		PrintToServer("[SB] Compilation failed");
		g_sProgram[0] = INST_HALT << 4;  // Prevent accidental execution of incomplete program
	}

	return Plugin_Handled;
}
