VGMlib for NGPC
A T6W28 VGM driver and C library for playback of VGM files composed for T6W28 as BGM and SFX
Coded by winteriscoming

Special thanks to sodthor, mic_, and Ivan Mackintosh

The library was designed to work with the established C framework for NGPC development.

Furnace can be used to create VGM tracks in NGP (T6W28) format for both BGM and SFX.

The VGM files need to be converted to C using ngpc_vgm2c.py.

To use once VGM files are converted:
-In your NGPC main file, include vgmplayer.c.
-Include all converted VGM C files.
-Establish a vblank interrupt and call VGM_SendData() within it.
-At some point before playing BGM or SFX, install the driver with
VGM_InstallSoundDriver()

At that point, you can call any of these:
-VGM_PlaySFX(u8*SFX_Data)
-VGM_PlayBGM_X_Times(u8*BGM_Data, u32 loop_point, u8 num)
-VGM_PlayBGM_Loop(u8*BGM_Data, u32 loop_point)

If BGM is playing, you can call this:
-VGM_StopBGM()

If BGM is stopped with VGM_StopBGM(), you can call this:
-VGM_ResumeBGM()

All functions are documented more thoroughly in comments found in vgmplayer.c.