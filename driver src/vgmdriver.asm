; VGM driver for NGPC with BGM and SFX support
; Written by winteriscoming
; Thanks to mic_ for sharing his VGM driver source code.
; Thanks to Ivan Mackintosh for writing the NGPC sound driver tutorial.
; This driver would not be possible without their contributions.

;new version May 4th, 2023 - uses NGPC-specific VGM instead of SMS

.MEMORYMAP
	DEFAULTSLOT 0
	SLOTSIZE $1000
	SLOT 0 $0000
.ENDME

.ROMBANKSIZE $1000
.ROMBANKS 1
.BANK 0 SLOT 0
.ORGA $00


; Sound registers
.define REG_CH4 $4000
.define REG_CH123 $4001

;Pulse variable
;this is the byte in ram where the vblank interrupt in 
;the t900 code sets the pulse for the z80 at 0x00BC
.define VBPULSE $8000


;.define BGM_WAITING $8000 ;not used

;z80 interrupt register
.define Z80_INT $C000

;VGM commands
.define VGM_WRITE_CMD_LEFT $50
.define VGM_WRITE_CMD_RIGHT $30
;.define VGM_WAIT_CMD $61  ;not checked - code skips to wait and t900 manages wait period
;.define VGM_WAIT_NTSC $62 ;not checked - code skips to wait and t900 manages wait period
;.define VGM_WAIT_PAL $63  ;not checked - code skips to wait and t900 manages wait period

;mask bits to check for noise command vs tone command
.define NOISE_CHECK $60

;mask bits to check for volume cmd
.define VOL_CHECK $90

;mask bits to check for channel in cmd
.define CHANNEL_MASK $60

;value of the different channels in cmd
.define CMD_CH1 $00
.define CMD_CH2 $20
.define CMD_CH3 $40
.define CMD_CH4 $60

di
im 	1
jp main_loop

main_loop: ;check VBPULSE and wait for it to be incremented by T900
	
	ld  a,(VBPULSE)
	cp  0
	jp	z,main_loop
	
	
	jp sfx_loop


bgm_start: ;initializes BGM buffer for this frame
    
    ;load BGM buffer address into bc
	ld	bc,BGM_BUFFER
	
process_BGM: ;processes the frame of BGM data from the buffer
    
	ld	a,(bc)		; Read one byte from the VGM data buffer
	inc	c		; Increment read position in buffer
	ld (CURRENTCMD),a 
	and VGM_WRITE_CMD_LEFT
	cp VGM_WRITE_CMD_LEFT
	jp z, vgm_write  ;check if it is a 0x50 command and process it
	ld a,(CURRENTCMD) 
	and VGM_WRITE_CMD_RIGHT
	cp VGM_WRITE_CMD_RIGHT
	jp z, vgm_write  ;check if it is a 0x30 command and process it
	jp reset_pulse   ;otherwise end the frame and wait for next


reset_pulse: ;reset the pulse variable in shared RAM that gets set by T900
	ld  a,0
	ld  (VBPULSE),a
	
	jp main_loop


vgm_write: ;process 0x50 or 0x30 command
    ld  a,(bc) ;load the data byte from the buffer (the one after the 0x50 cmd)
	and VOL_CHECK  ;check if it is a volume command - otherwise it is a noise or tone command
	cp VOL_CHECK
	jp z, write_volume ;process volume command
	ld	a,(bc)		;load the same data byte from the buffer again since a was changed
	and NOISE_CHECK ;check if it is a noise cmd - otherwise it is a tone cmd
	cp NOISE_CHECK
	jp z, write_noise ;process noise cmd
	jp check_channel_bgm ;process tone cmd by first checking which channel it is for

write_noise:
	ld a,(CURRENTCMD) 
	and VGM_WRITE_CMD_RIGHT
	cp VGM_WRITE_CMD_RIGHT
	jp z, write_noise_right
	jp write_noise_left
	
	
write_noise_left: ;process noise cmd
	;check if channel 4 is being used by sfx and skip if so
	ld a,4
	ld (CURRENT_CHANNEL), a
	ld  a,(bc)  ;load the cmd from the buffer
	ld  (CURRENT_BGM_CH4_CMD1),a
	
	ld a, (SFXCH4USED)
	or a
	jp nz, skip_noise_or_vol_bgm
	ld  a,(bc)  ;load the cmd from the buffer
	inc c       ;Increment read position in buffer for the next time the buffer is read
	ld  (REG_CH123),a
	;ld  (REG_CH4),a ;write psg data to noise register
    jp process_BGM ;go back and process the rest of the frame

write_noise_right: ;process noise cmd
	;check if channel 4 is being used by sfx and skip if so
	ld a,4
	ld (CURRENT_CHANNEL), a
	ld  a,(bc)  ;load the cmd from the buffer
	ld  (CURRENT_BGM_CH4_CMD1),a
	
	ld a, (SFXCH4USED)
	or a
	jp nz, skip_noise_or_vol_bgm
	ld  a,(bc)  ;load the cmd from the buffer
	inc c       ;Increment read position in buffer for the next time the buffer is read
	;ld  (REG_CH123),a
	ld  (REG_CH4),a ;write psg data to noise register
    jp process_BGM ;go back and process the rest of the frame
	
skip_noise_or_vol_bgm: ;increment read position in buffer but do not write anything to registers
    inc c      ;Increment read position in buffer for the next time the buffer is read
    jp process_BGM ;go back and process the rest of the frame


write_tone_left: ;process tone cmd for channels 1 or 2 (write only to one register)
	ld a,(CURRENT_CHANNEL)
	cp 1    ;is it channel 1?
	jp nz,+ ;otherwise skip
	ld a, (CURRENT_BGM_CH1_CMD1)
	ld  (REG_CH123),a ;write first byte to tone register
	ld a, (CURRENT_BGM_CH1_CMD2)
	ld  (REG_CH123),a ;write 2nd byte to tone register
	jp process_BGM ;go back and process the rest of the frame
+:
	ld a,(CURRENT_CHANNEL)
	cp 2    ;is it channel 2?
	jp nz,+ ;otherwise skip
	ld a, (CURRENT_BGM_CH2_CMD1)
	ld  (REG_CH123),a ;write first byte to tone register
	ld a, (CURRENT_BGM_CH2_CMD2)
	ld  (REG_CH123),a ;write 2nd byte to tone register
	jp process_BGM ;go back and process the rest of the frame
+:
	ld a,(CURRENT_CHANNEL)
	cp 3    ;is it channel 3?
	jp nz,+ ;otherwise skip
	ld a, (CURRENT_BGM_CH3_CMD1)
	ld  (REG_CH123),a ;write first byte to tone register
	ld a, (CURRENT_BGM_CH3_CMD2)
	ld  (REG_CH123),a ;write 2nd byte to tone register
	jp process_BGM ;go back and process the rest of the frame
+:
    ;if it gets here, it's channel 4
	ld a, (CURRENT_BGM_CH4_CMD1)
	ld  (REG_CH123),a ;write first byte to tone register
	ld a, (CURRENT_BGM_CH4_CMD2)
	ld  (REG_CH123),a ;write 2nd byte to tone register
	jp process_BGM ;go back and process the rest of the frame
	

write_tone_right: ;process tone cmd for channels 1 or 2 (write only to one register)
	ld a,(CURRENT_CHANNEL)
	cp 1    ;is it channel 1?
	jp nz,+ ;otherwise skip
	ld a, (CURRENT_BGM_CH1_CMD1)
	ld  (REG_CH4),a ;write first byte to tone register
	ld a, (CURRENT_BGM_CH1_CMD2)
	ld  (REG_CH4),a ;write 2nd byte to tone register
	jp process_BGM ;go back and process the rest of the frame
+:
	ld a,(CURRENT_CHANNEL)
	cp 2    ;is it channel 2?
	jp nz,+ ;otherwise skip
	ld a, (CURRENT_BGM_CH2_CMD1)
	ld  (REG_CH4),a ;write first byte to tone register
	ld a, (CURRENT_BGM_CH2_CMD2)
	ld  (REG_CH4),a ;write 2nd byte to tone register
	jp process_BGM ;go back and process the rest of the frame
+:
	ld a,(CURRENT_CHANNEL)
	cp 3    ;is it channel 3?
	jp nz,+ ;otherwise skip
	ld a, (CURRENT_BGM_CH3_CMD1)
	ld  (REG_CH4),a ;write first byte to tone register
	ld a, (CURRENT_BGM_CH3_CMD2)
	ld  (REG_CH4),a ;write 2nd byte to tone register
	jp process_BGM ;go back and process the rest of the frame
+:
    ;if it gets here, it's channel 4
	ld a, (CURRENT_BGM_CH4_CMD1)
	ld  (REG_CH4),a ;write first byte to tone register
	ld a, (CURRENT_BGM_CH4_CMD2)
	ld  (REG_CH4),a ;write 2nd byte to tone register
	jp process_BGM ;go back and process the rest of the frame
	
	

	



check_channel_bgm: ;check which channel is in cmd
    ld a, (bc) ;get the current PSG cmd (after 0x50 cmd)
	and CHANNEL_MASK
	cp CMD_CH1 ;see if it is channel 1
	jp z, check_ch1
	ld a, (bc) ;get the current PSG cmd (after 0x50 cmd)
	and CHANNEL_MASK
	cp CMD_CH2 ;see if it is channel 2
	jp z, check_ch2
	ld a, (bc) ;get the current PSG cmd (after 0x50 cmd)
	and CHANNEL_MASK
	cp CMD_CH3 ;see if it is channel 2
	jp z, check_ch3
	jp check_ch4

	
	

check_ch1: ;check if channel 1 is in use by sfx and skip if so
	ld a, 1
	ld (CURRENT_CHANNEL), a
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH1_CMD1),a
	inc c
	inc c
	ld a, (bc) ;get the next CMD
	inc c
	ld (CURRENT_BGM_CH1_CMD2),a
	
	ld a, (SFXCH1USED)
	cp 0
	jp nz, process_BGM  ;go back and process the rest of the frame
	ld a,(CURRENTCMD) 
	and VGM_WRITE_CMD_RIGHT
	cp VGM_WRITE_CMD_RIGHT
	jp z, write_tone_right
	jp write_tone_left


check_ch2: ;check if channel 2 is in use by sfx and skip if so
	ld a, 2
	ld (CURRENT_CHANNEL), a
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH2_CMD1),a
	inc c
	inc c
	ld a, (bc) ;get the next CMD
	inc c
	ld (CURRENT_BGM_CH2_CMD2),a
	ld a, (SFXCH2USED)
	cp 0
	jp nz, process_BGM  ;go back and process the rest of the frame
	ld a,(CURRENTCMD) 
	and VGM_WRITE_CMD_RIGHT
	cp VGM_WRITE_CMD_RIGHT
	jp z, write_tone_right
	jp write_tone_left

check_ch3: ;check if channel 3 is in use by sfx and skip if so
	ld a, 3
	ld (CURRENT_CHANNEL), a
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH3_CMD1),a
	inc c
	inc c
	ld a, (bc) ;get the next CMD
	inc c
	ld (CURRENT_BGM_CH3_CMD2),a
	
	ld a, (SFXCH3USED)
	cp 0
	jp nz, process_BGM  ;go back and process the rest of the frame
	ld a,(CURRENTCMD) 
	and VGM_WRITE_CMD_RIGHT
	cp VGM_WRITE_CMD_RIGHT
	jp z, write_tone_right
	jp write_tone_left

check_ch4: ;check if channel 3 is in use by sfx and skip if so
	ld a, 4
	ld (CURRENT_CHANNEL), a
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH4_CMD1),a
	inc c
	inc c
	ld a, (bc) ;get the next CMD
	inc c
	ld (CURRENT_BGM_CH4_CMD2),a
	
	ld a, (SFXCH4USED)
	cp 0
	jp nz, process_BGM  ;go back and process the rest of the frame
	ld a,(CURRENTCMD) 
	and VGM_WRITE_CMD_RIGHT
	cp VGM_WRITE_CMD_RIGHT
	jp z, write_tone_right
	jp write_tone_left

write_volume:  ;write volume to both registers for stereo bgm
	;is it channel 1?
	ld a, (bc) ;get the current CMD
	and CHANNEL_MASK
	cp CMD_CH1
	jr nz,+  ;if not, move to next
	ld a, (SFXCH1USED) ;if so, check if channel is in use by SFX
	cp 0
	jp nz, skip_noise_or_vol_bgm  ;skip if channel is in use by SFX
	
	ld a,(CURRENTCMD)
	and VGM_WRITE_CMD_LEFT
	cp VGM_WRITE_CMD_LEFT
	jp z, store_ch1_vol_left  ;check if it is a 0x50 command and send cmd to left
	jp store_ch1_vol_right ;otherwise go right
+:  
    ;is it channel 2?
	ld a, (bc) ;get the current CMD
	and CHANNEL_MASK
	cp CMD_CH2
	jr nz,+  ;if not, move to next
	ld a, (SFXCH2USED) ;if so, check if channel is in use by SFX
	cp 0
	jp nz, skip_noise_or_vol_bgm  ;skip if channel is in use by SFX
	
	ld a,(CURRENTCMD)
	and VGM_WRITE_CMD_LEFT
	cp VGM_WRITE_CMD_LEFT
	jp z, store_ch2_vol_left  ;check if it is a 0x50 command and send cmd to left
	jp store_ch2_vol_right ;otherwise go right
+:  
    ;is it channel 3?
	ld a, (bc) ;get the current CMD
	and CHANNEL_MASK
	cp CMD_CH3
	jr nz,+  ;if not, move to next
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH3_VOL),a
	ld a, (SFXCH3USED) ;if so, check if channel is in use by SFX
	cp 0
	jp nz, skip_noise_or_vol_bgm  ;skip if channel is in use by SFX	
	
	ld a,(CURRENTCMD)
	and VGM_WRITE_CMD_LEFT
	cp VGM_WRITE_CMD_LEFT
	jp z, store_ch3_vol_left  ;check if it is a 0x50 command and send cmd to left
	jp store_ch3_vol_right ;otherwise go right
+:  
    ;is it channel 4? It is if it got this far
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH4_VOL),a
	ld a, (SFXCH4USED) ;if so, check if channel is in use by SFX
	or a
	jp nz, skip_noise_or_vol_bgm  ;skip if channel is in use by SFX
	
	ld a,(CURRENTCMD)
	and VGM_WRITE_CMD_LEFT
	cp VGM_WRITE_CMD_LEFT
	jp z, store_ch4_vol_left  ;check if it is a 0x50 command and send cmd to left
	jp store_ch4_vol_right ;otherwise go right

	
store_ch1_vol_right:
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH1_VOL_RIGHT),a
	jp write_volume_p2_right

store_ch1_vol_left:
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH1_VOL),a
	jp write_volume_p2_left
	
store_ch2_vol_right:
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH2_VOL_RIGHT),a
	jp write_volume_p2_right

store_ch2_vol_left:
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH2_VOL),a
	jp write_volume_p2_left
	
store_ch3_vol_right:
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH3_VOL_RIGHT),a
	jp write_volume_p2_right

store_ch3_vol_left:
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH3_VOL),a
	jp write_volume_p2_left
	
store_ch4_vol_right:
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH4_VOL_RIGHT),a
	jp write_volume_p2_right

store_ch4_vol_left:
	ld a, (bc) ;get the current CMD
	ld (CURRENT_BGM_CH4_VOL),a
	jp write_volume_p2_left
	
write_volume_p2_left: ;part 2 of volume write process - write the volume cmd to left register
    ld a, (bc)      ;get the current CMD	
	inc c           ;Increment read position in buffer
	ld  (REG_CH123),a
	jp process_BGM
	
write_volume_p2_right: ;part 2 of volume write process - write the volume cmd to right register
    ld a, (bc)      ;get the current CMD	
	inc c           ;Increment read position in buffer
	ld  (REG_CH4),a
	jp process_BGM
	

sfx_loop: ;initialize SFX buffer read position for this frame
    ld	bc,SFX_BUFFER
	jp  play_sfx
	
	
play_sfx:  ;loop that processes the sfx data for this frame
	ld	a,(bc)		; Read one byte from the SFX data buffer
	ld (CURRENTCMD),a 
	cp 0 ;check if current cmd is 0 and restore last BGM commands
	jp z, restore_BGM
	inc	c		; Increment read position in buffer
	ld a,(CURRENTCMD) ;load the cmd back into a
	and VGM_WRITE_CMD_LEFT ;check if it is a 0x50 cmd and process it
	cp VGM_WRITE_CMD_LEFT
	jp z, vgm_write_sfx
	ld a,(CURRENTCMD) ;load the cmd back into a
	and VGM_WRITE_CMD_RIGHT ;check if it is a 0x30 cmd and process it
	cp VGM_WRITE_CMD_RIGHT
	jp z, vgm_write_sfx
	jp bgm_start ;No more SFX data for this frame, now process BGM

	
vgm_write_sfx: ;Process 0x50 or 0x30 cmd from SFX buffer
    ld  a,(bc)     ;load the data byte from buffer after cmd
	and VOL_CHECK  ;check if it is a volume command
	cp VOL_CHECK
	jp z, write_volume_sfx_p1
	ld	a,(bc)		;load the data byte from buffer after cmd
	and NOISE_CHECK  ;check if it is a noise cmd
	cp NOISE_CHECK
	jp z, write_noise_sfx ;it is a noise cmd
	jp write_tone_sfx ;otherwise it is a tone cmd
	
	
write_volume_sfx_p1:  ;write figure out which side to write volume to
	ld a,(CURRENTCMD) ;load the cmd back into a
	and VGM_WRITE_CMD_LEFT ;check if it is left
	cp VGM_WRITE_CMD_LEFT
	jp z, write_volume_sfx_p2_left
	jp write_volume_sfx_p2_right ;it is right if it gets here
	
write_volume_sfx_p2_left:  ;write volume to both registers for stereo bgm
	ld  a,(bc)      ;load the data byte from buffer after cmd
	inc c           ;Increment read position in buffer
	ld  (REG_CH123),a
	jp play_sfx  ;continue processing this frame
	
write_volume_sfx_p2_right:  ;write volume to both registers for stereo bgm
	ld  a,(bc)      ;load the data byte from buffer after cmd
	inc c           ;Increment read position in buffer
	ld  (REG_CH4),a
	jp play_sfx  ;continue processing this frame
	
write_noise_sfx:
	ld a,(CURRENTCMD) ;load the cmd back into a
	and VGM_WRITE_CMD_LEFT ;check if it is left
	cp VGM_WRITE_CMD_LEFT
	jp z, write_noise_sfx_left
	jp write_noise_sfx_right
	
write_noise_sfx_right: ;write noise cmd to register and mark channel 4 as in use by SFX
    ld  a,1
	ld (SFXCH4USED),a ;set the ch4 in use flag to 1
    ld  a,(bc)      ;load the data byte from buffer after cmd
	inc c           ;Increment read position in buffer
	ld  (REG_CH4),a ;Write cmd to the noise register
    jp play_sfx ;continue processing this frame
	
write_noise_sfx_left: ;write noise cmd to register and mark channel 4 as in use by SFX
    ld  a,1
	ld (SFXCH4USED),a ;set the ch4 in use flag to 1
    ld  a,(bc)      ;load the data byte from buffer after cmd
	inc c           ;Increment read position in buffer
	ld  (REG_CH123),a ;Write cmd to the noise register
    jp play_sfx ;continue processing this frame
	
write_tone_sfx:  ;process tone cmd
    ;check if channel3
	ld  a,(bc)  ;load the data byte from buffer after cmd
	and CHANNEL_MASK
	cp CMD_CH3
	jp z, mark_ch3_used  ;if it is, process channel 3, otherwise it is channel 1 or 2
	ld  a,(bc)  ;load the data byte from buffer after cmd
	and CHANNEL_MASK
	cp CMD_CH1  ;is it channel 1?
	jp z,  mark_ch1_used  ;if so, mark channel 1 as used and process the cmd
	ld  a,(bc)  ;load the data byte from buffer after cmd
	and CHANNEL_MASK
	cp CMD_CH2  ;is it channel 2?
	jp z,  mark_ch2_used  ;if so, mark channel 1 as used and process the cmd
	jp mark_ch4_used  ;otherwise mark channel 2 as used and procss the cmd
	
write_tone_sfx2
	ld a,(CURRENTCMD) ;load the cmd back into a
	and VGM_WRITE_CMD_LEFT ;check if it is left
	cp VGM_WRITE_CMD_LEFT
	jp z, write_tone_sfx2_left
	jp write_tone_sfx2_right

write_tone_sfx2_left  ;part 2 of sfx tone procesing for channel 1 or 2 - data from both write cmds written to register
	ld  a,(bc)      ;load the data byte from buffer after cmd
	inc c           ;Increment read position to the next 0x50 cmd in buffer
	inc c           ;Increment read position to the next data byte cmd in buffer
	ld  (REG_CH123),a  ;write data byte 1
	ld  a,(bc)
	inc c           ;Increment read position in buffer
	ld  (REG_CH123),a  ;write data byte 2
    jp play_sfx ;continue processing this frame

write_tone_sfx2_right  ;part 2 of sfx tone procesing for channel 1 or 2 - data from both write cmds written to register
	ld  a,(bc)      ;load the data byte from buffer after cmd
	inc c           ;Increment read position to the next 0x50 cmd in buffer
	inc c           ;Increment read position to the next data byte cmd in buffer
	ld  (REG_CH4),a  ;write data byte 1
	ld  a,(bc)
	inc c           ;Increment read position in buffer
	ld  (REG_CH4),a  ;write data byte 2
    jp play_sfx ;continue processing this frame



mark_ch1_used:  ;mark channel 1 as in use and process the cmd
	ld  a,1
	ld (SFXCH1USED),a
	jp write_tone_sfx2


mark_ch2_used:  ;mark channel 2 as in use and process the cmd
    ld  a,1
	ld (SFXCH2USED),a
	jp write_tone_sfx2
	
mark_ch3_used:  ;mark channel 2 as in use and process the cmd
    ld  a,1
	ld (SFXCH3USED),a
	jp write_tone_sfx2

mark_ch4_used:  ;mark channel 2 as in use and process the cmd
    ld  a,1
	ld (SFXCH4USED),a
	jp write_tone_sfx2

restore_BGM: ;restore BGM commands that were overwritten or skipped during SFX
	;restore channel1?
	ld a, (SFXCH1USED)
	cp 0
	jp z, +
	ld a, (CURRENT_BGM_CH1_CMD1)
	cp 0   ;is there a command stored?
	jp z,+  ;skip if not
	;otherwise write the cmds to the register
	ld (REG_CH123),a
	ld a,(CURRENT_BGM_CH1_CMD2)
	ld (REG_CH123), a
	ld a,(CURRENT_BGM_CH1_VOL)
	ld (REG_CH123), a
	ld a,(CURRENT_BGM_CH1_VOL_RIGHT)
	ld (REG_CH4),a
+:
    ;restore channel2?
	ld a, (SFXCH2USED)
	cp 0
	jp z, +
	ld a, (CURRENT_BGM_CH2_CMD1)
	cp 0   ;is there a command stored?
	jp z,+  ;skip if not
	;otherwise write the cmds to the register
	ld (REG_CH123),a
	ld a,(CURRENT_BGM_CH2_CMD2)
	ld (REG_CH123), a
	ld a,(CURRENT_BGM_CH2_VOL)
	ld (REG_CH123), a
	ld a,(CURRENT_BGM_CH2_VOL_RIGHT)
	ld (REG_CH4),a
+:
    ;restore channel3?
	ld a, (SFXCH3USED)
	cp 0
	jp z, +
	ld a, (CURRENT_BGM_CH3_CMD1)
	cp 0   ;is there a command stored?
	jp z,+  ;skip if not
	;otherwise write the cmds to the registers
	ld (REG_CH123),a
	ld (REG_CH4),a
	ld a,(CURRENT_BGM_CH3_CMD2)
	ld (REG_CH123), a
	ld (REG_CH4),a
	ld a,(CURRENT_BGM_CH3_VOL)
	ld (REG_CH123), a
	ld a,(CURRENT_BGM_CH3_VOL_RIGHT)
	ld (REG_CH4),a
+:
    ;restore channel4?
	ld a, (SFXCH4USED)
	cp 0
	jp z, clear_sfx_flags
	ld a, (CURRENT_BGM_CH4_CMD1)
	cp 0   ;is there a command stored?
	jp z, clear_sfx_flags  ;skip if not
	;otherwise write the cmds to the registers
	ld (REG_CH4),a
	ld a,(CURRENT_BGM_CH4_VOL)
	ld (REG_CH123), a
	ld a,(CURRENT_BGM_CH4_VOL_RIGHT)
	ld (REG_CH4),a
	
clear_sfx_flags: ;clear all SFX in-use flags
	ld  a,0
	ld  c,a
	ld (SFXCH1USED),a
	ld (SFXCH2USED),a
	ld (SFXCH3USED),a
	ld (SFXCH4USED),a
	jp bgm_start


.ORGA $450  ;these variables are aligned to byte 0x310 - visible in shared RAM by T900 at 0x7390
CURRENT_CHANNEL: .db 0

CURRENTCMD: .db $FF
SFXCH1USED: .db 0
SFXCH2USED: .db 0
SFXCH3USED: .db 0
SFXCH4USED: .db 0

CURRENT_BGM_CH1_CMD1: .db 0
CURRENT_BGM_CH1_CMD2: .db 0
CURRENT_BGM_CH1_VOL:  .db 0
CURRENT_BGM_CH1_VOL_RIGHT:  .db 0

CURRENT_BGM_CH2_CMD1: .db 0
CURRENT_BGM_CH2_CMD2: .db 0
CURRENT_BGM_CH2_VOL:  .db 0
CURRENT_BGM_CH2_VOL_RIGHT:  .db 0

CURRENT_BGM_CH3_CMD1: .db 0
CURRENT_BGM_CH3_CMD2: .db 0
CURRENT_BGM_CH3_VOL:  .db 0
CURRENT_BGM_CH3_VOL_RIGHT:  .db 0

CURRENT_BGM_CH4_CMD1: .db 0
CURRENT_BGM_CH4_CMD2: .db 0
CURRENT_BGM_CH4_VOL:  .db 0
CURRENT_BGM_CH4_VOL_RIGHT:  .db 0

.ORGA $4D0 ;BGM buffer is aligned to byte 0x350 - visible in shared RAM by T900 at 0x73D0
BGM_BUFFER:


.ORGA $550 ;SFX buffer is aligned to byte 0x3D0 - visible in shared RAM by T900 at 0x7450
SFX_BUFFER


.ORGA $5D0 ;marking byte after SFX buffer so that entirety of SFX buffer is reserved in RAM
RESERVED: .db 1