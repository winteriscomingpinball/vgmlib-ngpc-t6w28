//NGPC VGM demo of z80 driver that supports playback of VGM files for
//background music and sound effects
//demo coded by winteriscoming
//special thanks to sodthor, mic_, and Ivan Mackintosh

#include "ngpc.h"
#include "carthdr.h"
#include "library.h"

#include "vgmplayer.c"
#include "bgm1.c"
#include "bgm2.c"
#include "explode.c"
#include "shoot.c"


void __interrupt myVBL()
{
    WATCHDOG = WATCHDOG_CLEAR;
    if (USR_SHUTDOWN) { SysShutdown(); while (1); }
    VGM_SendData();
}


void main()
{  
   u8 pausephase=0;
   u8 bgmphase=0;
   u8 sfxphase=0;
   u8 prevJOYPAD;
   
   InitNGPC();
   SysSetSystemFont();
   
   VGM_InstallSoundDriver();
   //LoadWav((u8*)sndsample);
   
   //VGM_PlayBGM_Loop((u8*)test3_tuned, test3_tuned_loop_point);
   
   __asm("di");
		VBL_INT = myVBL;
   __asm("ei");
   
   ClearScreen(SCR_1_PLANE);
   ClearScreen(SCR_2_PLANE);
   SetBackgroundColour(RGB(255, 255, 255));
   
   //showImage(123,(SOD_IMG*)&images[0],CENTER,CENTER);
   SysSetSystemFont();
   
   //SetPalette(SCR_1_PLANE, 0, 0, 0, 0, RGB(15,15,15));
   PrintString(SCR_1_PLANE, 0, 6, 1, "VGM DEMO");
   
   PrintString(SCR_1_PLANE, 0, 3, 4, "A - CHANGE BGM");
   PrintString(SCR_1_PLANE, 0, 2, 6, "OPT - PAUSE BGM");
   PrintString(SCR_1_PLANE, 0, 3, 8, "B - PLAY SFX");
   
   PrintString(SCR_1_PLANE, 0, 7, 13, "SFX: ");
   PrintString(SCR_1_PLANE, 0, 7, 11, "BGM: ");
   
   
   while(1){
	  
	  
	  PrintDecimal(SCR_1_PLANE, 0, 13, 11, bgmphase, 2);
	  
	  
	  PrintDecimal(SCR_1_PLANE, 0, 13, 13, !sfxphase, 2);
	  
	   
	   if (JOYPAD & J_OPTION  && !(prevJOYPAD & J_OPTION)){
		   
		   pausephase=!pausephase;
		   
		   if (pausephase)VGM_StopBGM();
		   else VGM_ResumeBGM();
		  
	   }
	   
	   if (JOYPAD & J_B && !(prevJOYPAD & J_B)){
		   
		   sfxphase=!sfxphase;
		   if (sfxphase)VGM_PlaySFX((u8*)explode,1);
		   else VGM_PlaySFX((u8*)shoot,1);
		   

	   }
	   
	   if (JOYPAD & J_A && !(prevJOYPAD & J_A)){
		   //stop the z80
   //SOUNDCPU_CTRL = 0xAAAA;
   //VGM_InstallSoundDriver();
   //LoadWav((u8*)sndsample);
		   // restart z80
    //SOUNDCPU_CTRL = 0x5555;
		   if(bgmphase<1){
			    bgmphase++;
		   }else{
			   bgmphase=0;
		   }
		   
		   switch(bgmphase){
				case 0:
					VGM_PlayBGM_Loop((u8*)bgm1, bgm1_loop_point);
					break;
				case 1:
					VGM_PlayBGM_Loop((u8*)bgm2, bgm2_loop_point);
					break;
				default:
					break;
		   }
	   }
	   prevJOYPAD=JOYPAD;
	   

   }	   // never fall out of main!!!
}
