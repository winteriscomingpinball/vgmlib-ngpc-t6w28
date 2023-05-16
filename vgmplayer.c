//VGMlib for NGPC
//NGPC C library for z80 driver that supports 
//playback of VGM files for background music and sound effects
//coded by winteriscoming
//special thanks to sodthor, mic_, and Ivan Mackintosh

#include "ngpc.h"
#include "library.h"
#include "vgmdriver.c"

#define VGM_PULSE                     (*(u8*)0x00BC)
#define VGM_DATA_BUFFER               (u8*)0x74D0
#define VGM_DATA_BUFFER_1ST_BYTE      (*(u8*)0x74D0)
#define VGM_DATA_BUFFER_SFX           (u8*)0x7550
#define VGM_DATA_BUFFER_SFX_1ST_BYTE  (*(u8*)0x7550)

//#define WAV_DATA_LEN                  (*(u16*)0x7FF0)
//#define WAV_DATA_BUFFER               (u8*)0x7450





const unsigned char SOUND_OFF[] =
{
	0x50,0x9F,0x50,0xBF,0x50,0xDF,0x50,0xFF,0x50,0x9F,
	0x30,0x9F,0x30,0xBF,0x30,0xDF,0x30,0xFF,0x30,0x9F,
	0x61,0x9D,0x08,0x66,
};


volatile u8 controls[]={
	0x91,
	0x81,
	0x6e
};



const unsigned char zeros[17] =
{
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
};


volatile u32 bgm_loop_offset=0;
volatile u32 vgm_readpos_start=0;
volatile u32 vgm_readpos_end=0;
volatile u16 vgm_bgm_pause_timer=0;
volatile u16 vgm_readpos_start_sfx=0;
volatile u16 vgm_readpos_end_sfx=0;
volatile u16 vgm_sfx_pause_timer=0;
volatile u8 * currentSong;
volatile u8 * currentSFX;
volatile u8 play_sfx=0;
volatile u8 play_bgm=0;
volatile u8 bgm_header_offset=0;
volatile u8 sfx_header_offset=0;
volatile bgm_play_count=0;
volatile bgm_limited_play=0;
volatile bgm_play_counter=0;



volatile driver_start_pos=0;
volatile driver_transfer_count=0;

volatile driver_restored=0;

volatile u8 priority_sfx_is_playing;

// volatile u8 * currentWav;
// volatile u8 play_wav=0;
// volatile u8 wav_phase=0;
// volatile u8 wav_readpos;
// volatile u8 wav_len=0;


// SysPlayWave
// u8 wave[];
// void SysPlayWave(u8 *wave)
// {
 // __asm(" extern large WAVE_OUT");
 // __asm(" ld xwa,(XSP+0x4)");
 // __asm(" ld xhl3,xwa");
 // //__asm(" ldl xhl3,_wave");
 // __asm(" ldb ra3,1");
 // __asm(" calr WAVE_OUT");
// }



// void LoadWav(u8*Wav_Data){
	// //BlockCopy(WAV_DATA_BUFFER, Wav_Data, Len);
	// //WAV_DATA_LEN=Len;
	// currentWav=Wav_Data;
	// //wav_len=Len;
    // play_wav=1;
	// //wav_readpos=0;
	// // restart z80
    // //SOUNDCPU_CTRL = 0x5555;
// }

void waitTime(u16 inputTimer){
	u16 timer=inputTimer;
	
	while(timer){
		timer--;
	}
	
}
//Call this every vblank to both pulse the Z80
//and stream each frame of BGM and SFX data to
//the buffers used by the Z80
void VGM_SendData(){
	u8 dataByte=0;
	u8 checkingData=1;
	u8 bgm_end_reached=0;
	
	if(!VGM_PULSE){  //Enable this to enforce no updates unless Z80 is ready - this does not seem necessary
		// if(play_wav){
			// SysPlayWave(currentWav);
			// play_wav=0;
			// waitTime(10000);
		// }
		if(play_bgm){
			if (vgm_bgm_pause_timer){
				vgm_bgm_pause_timer--;
				
			}
			else{
					
					
					while(checkingData){
						dataByte=currentSong[vgm_readpos_end];
						switch(dataByte){
							case(0x50)://0x50 vgm psg write command has 1 data byte
							case(0x30)://0x30 vgm psg write command for NGPC has 1 data byte
								vgm_readpos_end+=2;
								break;
							case(0x61)://vgm wait command has 2 data bytes
								vgm_readpos_end+=2;
								checkingData=0;
								vgm_bgm_pause_timer=((currentSong[vgm_readpos_end] *0x100) + currentSong[vgm_readpos_end-1]);
								vgm_bgm_pause_timer=vgm_bgm_pause_timer/735;
								if (vgm_bgm_pause_timer) vgm_bgm_pause_timer--;
								break;
							case(0x62)://wait ntsc
								checkingData=0;
								vgm_bgm_pause_timer=0;
								break;
							case(0x66)://end of vgm data has 0 data bytes
								bgm_end_reached=1;
								checkingData=0;
								
								bgm_play_counter++;
								break;
							case(0x63)://wait pal
								checkingData=0;
								vgm_bgm_pause_timer=0;
								break;
							default:
								vgm_readpos_end++;
						}
					}
					
					BlockCopy(VGM_DATA_BUFFER, currentSong+vgm_readpos_start, vgm_readpos_end-vgm_readpos_start+1);
					if(bgm_end_reached){
						
						vgm_readpos_start=bgm_loop_offset;
						
						vgm_readpos_end=vgm_readpos_start;
						bgm_end_reached=0;
						
						if (bgm_limited_play){
							if(bgm_play_count)  bgm_play_count--;
							if (!bgm_play_count) play_bgm=0;
						}
						
						
					}else{
						vgm_readpos_start=vgm_readpos_end+1;
						vgm_readpos_end=vgm_readpos_start;
					}
				
			}
		}

		
		if(play_sfx){
			if (vgm_sfx_pause_timer){
				vgm_sfx_pause_timer--;
				
			}
			else{
				checkingData=1;
					
					vgm_readpos_end_sfx=vgm_readpos_start_sfx;
					
					while(checkingData){
						dataByte=currentSFX[vgm_readpos_end_sfx];
						switch(dataByte){
							case(80)://0x50 vgm psg write command has 1 data byte
								vgm_readpos_end_sfx+=2;
								break;
							case(0x61)://vgm wait command has 2 data bytes
								vgm_readpos_end_sfx+=2;
								checkingData=0;
								vgm_sfx_pause_timer=(((currentSFX[vgm_readpos_end_sfx] *0x100) + currentSFX[vgm_readpos_end_sfx-1])/735);
								if (vgm_sfx_pause_timer>2) vgm_sfx_pause_timer--;
								break;
							case(0x62)://wait ntsc
								checkingData=0;
								vgm_sfx_pause_timer=0;
								break;
							case(0x66)://end of vgm data has 0 data bytes
								vgm_readpos_end_sfx=sfx_header_offset;
								vgm_readpos_start_sfx=sfx_header_offset;
								checkingData=0;
								play_sfx=0;
								VGM_DATA_BUFFER_SFX_1ST_BYTE=0;
								
								break;
							case(0x63)://wait pal
								checkingData=0;
								vgm_sfx_pause_timer=0;
								break;
							default:
								vgm_readpos_end_sfx++;
						}
					}
					
					
					if(play_sfx)BlockCopy(VGM_DATA_BUFFER_SFX, currentSFX+vgm_readpos_start_sfx, vgm_readpos_end_sfx-vgm_readpos_start_sfx+1);
					vgm_readpos_start_sfx=vgm_readpos_end_sfx+1;
					
				
			}
		}
		
		VGM_PULSE++;
	}
	
}

void VGM_PlaySFX(u8*SFX_Data, u8 givePriority){
	//if(play_sfx==1){
	//	nextSFX=SFX_Data;
	//	play_next_sfx=1;
	//}
	//else{
		
		
		if(!priority_sfx_is_playing || givePriority){
			currentSFX=SFX_Data;
			play_sfx=1;
			priority_sfx_is_playing=givePriority;
		   //variables for start and end position
		   //these are set according to offsets for vgm header data
		   if(SFX_Data[0]==0x56){
			   //data has header, so set offset to 0x40
			   sfx_header_offset=0x40;
		   }else{
			   //data has no header, so set offset to zero
			   sfx_header_offset=0x00;
		   }
	   
		   vgm_readpos_start_sfx=sfx_header_offset;
		   vgm_readpos_end_sfx=sfx_header_offset;
	   
		   vgm_sfx_pause_timer=0;
		}
	//}
   
}

//Called by other functions once a BGM is already established.
//This should not be called directly
void VGM_PlayBGM(){
   //check if data has VGM header -is first byte V (0x56)?
   if(currentSong[0]==0x56){
	   //data has header, so set offset to 0x40
	   bgm_header_offset=0x40;
   }else{
	   //data has no header, so set offset to zero
	   bgm_header_offset=0x00;
   }
   
   vgm_readpos_start=bgm_header_offset;
   vgm_readpos_end=bgm_header_offset;
   
   vgm_bgm_pause_timer=0;
   
   play_bgm=1;
   
}


//Call this to play BGM a set number of times
//BGM_Data is the array of VGM data for the BGM to be played
//loop_point is the offset for the loop point in the track
//num is the number of times to play the BGM
void VGM_PlayBGM_X_Times(u8*BGM_Data, u32 loop_point, u8 num){
	bgm_play_counter=0;
	currentSong=BGM_Data;
	bgm_limited_play=1;
	bgm_play_count=num;
	VGM_PlayBGM();
	
}


//Call this to loop BGM infinitely
//BGM_Data is the array of VGM data for the BGM to be played
//loop_point is the offset for the loop point in the track
void VGM_PlayBGM_Loop(u8*BGM_Data, u32 loop_point){
	bgm_play_counter=0;
	bgm_loop_offset=loop_point;
	bgm_limited_play=0;
	currentSong=BGM_Data;
	VGM_PlayBGM();
}


//Call this to stop/pause BGM
void VGM_StopBGM(){
	play_bgm=0; 
	BlockCopy(VGM_DATA_BUFFER, SOUND_OFF, sizeof(SOUND_OFF));
}


//Call this to resume bgm that has been stopped/paused
void VGM_ResumeBGM(){
	play_bgm=1;
}


//Call this first to install the sound driver
void VGM_InstallSoundDriver(void){
   //stop the z80
   SOUNDCPU_CTRL = 0xAAAA;
   // copy driver
   BlockCopy(Z80_RAM, vgmdriver, sizeof(vgmdriver));
   //initialize variables
   vgm_bgm_pause_timer=0;
   vgm_readpos_start_sfx=0x40;
   vgm_readpos_end_sfx=0x3f;
   vgm_sfx_pause_timer=0;
   vgm_readpos_start=0x40;
   vgm_readpos_end=0x3f;
   play_bgm=0;
   play_sfx=0;
   driver_start_pos=0;
   driver_transfer_count=0;
   driver_restored=0;
   priority_sfx_is_playing=0;
   //play_wav=0;
   //wav_phase=0;
   //wav_readpos=0;
   
   // restart z80
   SOUNDCPU_CTRL = 0x5555;
}


void VGM_RestoreSoundDriver(void){
   //stop the z80
   //SOUNDCPU_CTRL = 0xAAAA;
   // copy driver
   if(!driver_transfer_count){
	   driver_restored=0;
	   driver_start_pos=0;
	   SOUNDCPU_CTRL = 0x5555;
	   
	   
   }
   if (!driver_restored){
	   //driver_start_pos +=0x7F*driver_transfer_count;
	   driver_transfer_count++;
	   
	   //BlockCopy(VGM_DATA_BUFFER, SOUND_OFF, sizeof(SOUND_OFF));
	   //BlockCopy(VGM_DATA_BUFFER_SFX, zeros, sizeof(zeros));
	   
	   //BlockCopy(Z80_RAM+0x310, zeros, sizeof(zeros));
       //BlockCopy(Z80_RAM+driver_start_pos, vgmdriver+driver_start_pos, 0x7F);
	   if (driver_transfer_count>=1){
		   driver_restored=1; 
		   //driver_start_pos=0;
		   driver_transfer_count=0;
		   // restart z80
           
           //SOUNDCPU_CTRL = 0x5555;
		   //SOUNDCPU_CTRL = 0x5555;
	   }
   
   }
   
}