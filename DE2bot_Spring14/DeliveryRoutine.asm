; DeliveryRoutine.asm
; Created by Idan Mintz

	ORG     &H000		;Begin program at x000
Init:
	LOAD    Zero
	OUT     LVELCMD     ; Stop motors
	OUT     RVELCMD
	
	CALL    SetupI2C    ; Configure the I2C
	CALL    BattCheck   ; Get battery voltage (and end if too low).
	OUT     SSEG2       ; Display batt voltage on SS

	LOAD    Zero
	ADDI    &H17        ; arbitrary reminder to toggle SW17
	OUT     SSEG1
WaitForUser:
	IN      XIO         ; contains KEYs and SAFETY
	AND     StartMask   ; mask with 0x10100 : KEY3 and SAFETY
	XOR     Mask4       ; KEY3 is active low; invert SAFETY to match
	JPOS    WaitForUser ; one of those is not ready, so try again

Main: ; "Real" program starts here.
	OUT     RESETODO    ; reset odometry in case wheels moved after programming
Go2ft:
	;LOAD    FSlow       ; Very slow forward movement
	;OUT     LVELCMD     ; commmand motors
	;OUT     RVELCMD
	; display velocity just as FYI
	;IN      LVEL        ; read left velocity
	;STORE   Temp        ; save it
	;IN      RVEL        ; read right velocity
	;ADD     Temp        ; add to left velocity
	;SHIFT   -1          ; divide by 2 (average)
	;OUT     SSEG1       ; display it
	
	;IN      XPOS        ; get current X position
	;SUB     TwoFeet     ; check the distance
	;JNEG    Go2ft       ; not there yet; keep checking
	; at this point, we're past the desired distance
	;LOAD    Zero
	;OUT     LVELCMD     ; stop
	;OUT     RVELCMD
	;JUMP    WaitForUser ; repeat
	
test:	LOAD	Seven
		OUT		UART
		CALL	Wait1
		IN		UART_CHK
		JZERO	Fail
		OUT		BEEP
		CALL	WAIT1
		OUT 	BEEP
		CALL	WAIT1
		OUT		BEEP
		CALL	WAIT1
		JUMP	end
		
fail:	OUT		BEEP
		CALL	WAIT1
		OUT		BEEP
				
end:	JUMP	end	

	
;***** SUBROUTINES

; Subroutine to wait (block) for 1 second
Wait1:
	OUT     TIMER
Wloop:
	IN      TIMER
	OUT     LEDS
	ADDI    -10
	JNEG    Wloop
	RETURN

Getjobs:
	LOAD	JobCount
	;Put all the job requests into the UART FIFO
	JobAskLoop:
		OUT		UART
		ADDI	1
		STORE	JobCount
		ADDI	-40
		JNEG	JobAskLoop
	
	LOAD	Zero
	STORE	Iterator
	ADDI	Job0
	STORE	JobCount
	JobRetreiveLoop:
		CALL	WaitForUART
		IN		UART
		ISTORE	JobCount
		ADDI	2
		STORE	JobCount
		LOAD	Iterator
		ADDI	1
		STORE	Iterator
		ADDI	-8
		JNEG	JobRetreiveLoop
		
	RETURN
		

PickJob:
	LOAD	Zero
	STORE	Iterator	; reset iterator
	
	
; Loops until the UART output FIFO is not empty
WaitForUART:
	IN UART_CHK
	JZERO	Fail
	RETURN
	

; This subroutine will get the battery voltage,
; and stop program execution if it is too low.
; SetupI2C must be executed prior to this.
BattCheck:
	CALL    GetBattLvl 
	SUB     MinBatt
	JNEG    DeadBatt
	ADD     MinBatt     ; get original value back
	RETURN
; If the battery is too low, we want to make
; sure that the user realizes it...
DeadBatt:
	LOAD    Four
	OUT     BEEP        ; start beep sound
	CALL    GetBattLvl  ; get the battery level
	OUT     SSEG1       ; display it everywhere
	OUT     SSEG2
	OUT     LCD
	LOAD    Zero
	ADDI    -1          ; 0xFFFF
	OUT     LEDS        ; all LEDs on
	OUT     GLEDS
	CALL    Wait1       ; 1 second
	Load    Zero
	OUT     BEEP        ; stop beeping
	LOAD    Zero
	OUT     LEDS        ; LEDs off
	OUT     GLEDS
	CALL    Wait1       ; 1 second
	JUMP    DeadBatt    ; repeat forever
	
; Subroutine to configure the I2C for reading batt voltage
; Only needs to be done once after each reset.
SetupI2C:
	LOAD    I2CWCmd     ; 0x1190 (write 1B, read 1B, addr 0x90)
	OUT     I2C_CMD     ; to I2C_CMD register
	LOAD    Zero        ; 0x0000 (A/D port 0, no increment)
	OUT     I2C_DATA    ; to I2C_DATA register
	OUT     I2C_RDY     ; start the communication
	CALL    BlockI2C    ; wait for it to finish
	RETURN
	
; Subroutine to read the A/D (battery voltage)
; Assumes that SetupI2C has been run
GetBattLvl:
	LOAD    I2CRCmd     ; 0x0190 (write 0B, read 1B, addr 0x90)
	OUT     I2C_CMD     ; to I2C_CMD
	OUT     I2C_RDY     ; start the communication
	CALL    BlockI2C    ; wait for it to finish
	IN      I2C_DATA    ; get the returned data
	RETURN

; Subroutine to block until I2C device is idle
BlockI2C:
	IN      I2C_RDY;   ; Read busy signal
	JPOS    BlockI2C    ; If not 0, try again
	RETURN              ; Else return

	
; Variables
Temp:     DW 0 ; "Temp" is not a great name, but can be helpful
JobsCompleted: DW	0 ; Number of jobs that have  been completed
JobCount: DW &H21 ; Variable used for getting jobs
NextX_R:  DW &H0000 ; Target X Position in grid space
NextX_A:  DW &H0000 ; Target X position in absolute location (measured/odometry)
NextY_R:  DW &H0000 ; Target Y Position in grid space
NextY_A:  DW &H0000 ; Target Y position in absolute location (measured/odometry)
Iterator: DW &H0000 ; Used for loops as counter

; Constants
Zero:     DW 0
One:      DW 1
Two:      DW 2
Three:    DW 3
Four:     DW 4
Five:     DW 5
Six:      DW 6
Seven:    DW 7
Eight:    DW 8
Nine:     DW 9
Ten:      DW 10
FSlow:    DW 100       ; 100 is about the lowest value that will move at all
RSlow:    DW -100
FFast:    DW 500       ; 500 is a fair clip (511 is max)
RFast:    DW -500
; Masks of multiple bits can be constructed by, for example,
; LOAD Mask0; OR Mask2; OR Mask4, etc.
Mask0:    DW &B00000001
Mask1:    DW &B00000010
Mask2:    DW &B00000100
Mask3:    DW &B00001000
Mask4:    DW &B00010000
Mask5:    DW &B00100000
Mask6:    DW &B01000000
Mask7:    DW &B10000000
StartMask: DW &B10100
AllSonar: DW &B11111111
OneMeter: DW 476        ; one meter in 2.1mm units
HalfMeter: DW 238       ; half meter in 2.1mm units
TwoFeet:  DW 290        ; ~2ft in 2.1mm units
MinBatt:  DW 110        ; 11V - minimum safe battery voltage
I2CWCmd:  DW &H1190     ; write one byte, read one byte, addr 0x90
I2CRCmd:  DW &H0190     ; write nothing, read one byte, addr 0x90

Job0:	  DW &H0000
Job1:	  DW &H0000
Job2:	  DW &H0000
Job3:	  DW &H0000
Job4:	  DW &H0000
Job5:	  DW &H0000
Job6:	  DW &H0000
Job7:	  DW &H0000


; IO address space map
SWITCHES: EQU &H00  ; slide switches
LEDS:     EQU &H01  ; red LEDs
TIMER:    EQU &H02  ; timer, usually running at 10 Hz
XIO:      EQU &H03  ; pushbuttons and some misc. inputs
SSEG1:    EQU &H04  ; seven-segment display (4-digits only)
SSEG2:    EQU &H05  ; seven-segment display (4-digits only)
LCD:      EQU &H06  ; primitive 4-digit LCD display
GLEDS:    EQU &H07  ; Green LEDs (and Red LED16+17)
BEEP:     EQU &H0A  ; Control the beep
LPOS:     EQU &H80  ; left wheel encoder position (read only)
LVEL:     EQU &H82  ; current left wheel velocity (read only)
LVELCMD:  EQU &H83  ; left wheel velocity command (write only)
RPOS:     EQU &H88  ; same values for right wheel...
RVEL:     EQU &H8A  ; ...
RVELCMD:  EQU &H8B  ; ...
I2C_CMD:  EQU &H90  ; I2C module's CMD register,
I2C_DATA: EQU &H91  ; ... DATA register,
I2C_RDY:  EQU &H92  ; ... and BUSY register
UART:     EQU &H98  ; The basic UART interface provided
UART_CHK: EQU &H99
; 0x98-0x9F are reserved for any additional UART functions you create
SONAR:    EQU &HA0  ; base address for more than 16 registers....
DIST0:    EQU &HA8  ; the eight sonar distance readings
DIST1:    EQU &HA9  ; ...
DIST2:    EQU &HAA  ; ...
DIST3:    EQU &HAB  ; ...
DIST4:    EQU &HAC  ; ...
DIST5:    EQU &HAD  ; ...
DIST6:    EQU &HAE  ; ...
DIST7:    EQU &HAF  ; ...
SONAREN:  EQU &HB2  ; register to control which sonars are enabled
XPOS:     EQU &HC0  ; Current X-position (read only)
YPOS:     EQU &HC1  ; Y-position
THETA:    EQU &HC2  ; Current rotational position of robot (0-701)
RESETODO: EQU &HC3  ; reset odometry to 0
