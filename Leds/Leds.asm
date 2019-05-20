;*********************************************************************************************
;* Leds and Displays Library                                                                 *
;*-------------------------------------------------------------------------------------------*
;* Leds.asm                                                                                  *
;* Author: eliaschr                                                                          *
;* Copyright (c) 2019, Elias Chrysocheris                                                    *
;*                                                                                           *
;* This program is free software: you can redistribute it and/or modify                      *
;* it under the terms of the GNU General Public License as published by                      *
;* the Free Software Foundation, either version 3 of the License, or                         *
;* (at your option) any later version.                                                       *
;*                                                                                           *
;* This program is distributed in the hope that it will be useful,                           *
;* but WITHOUT ANY WARRANTY; without even the implied warranty of                            *
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                             *
;* GNU General Public License for more details.                                              *
;*                                                                                           *
;* You should have received a copy of the GNU General Public License                         *
;* along with this program.  If not, see <https://www.gnu.org/licenses/>.                    *
;*-------------------------------------------------------------------------------------------*
;* Library of procedures for connecting up to 8 leds and 2 7-segment displays to the MSP430. *
;* The total array of 3x8 Leds is scanned using a timer. Leds and Displays are connected in  *
;* a Common Cathode scheme.                                                                  *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"Leds and Displays Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "Leds.h43"				;Local definitions
			.include "LedsAutoDefs.h43"		;Auto definitions according to settings in
											; Leds.h43


;----------------------------------------
; Definitions
;========================================
;The code in this library expexts the following definitions
;ACLKFreq is the ACLK Frequency (normally 32768)

LEDBUFSIZE:	.equ	3						;Number of Led groups the system handles
LEDFreq:	.equ	60						;The scanning frequency of the led groups in Hz
LEDBLNKON:	.equ	30						;The number of scan counts a blinking led stays on
LEDBLNKITVL:.equ	60						;The number of scan counts a blinking led repeats
											; blinking (Interval)
LEDCYCLE:	.equ	(ACLKFreq / (LEDFreq * LEDBUFSIZE))
											;The CCR0 setting to achieve the scanning timing
											
;Lets define the offsets needed to access the data tableS (LedBuffer and LedGrpArr)
LEDOFFS:	.equ	0
DISP0OFFS:	.equ	(LEDOFFS +1)
DISP1OFFS:	.equ	(DISP0OFFS +1)


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	LedPointer, 2			;Pointer to the current group byte in buffer
			.bss	LedBlnkCnt,	2			;Led blinker counter
			.bss	LedBuffer, LEDBUFSIZE	;Buffer that holds the led status of all groups
			.bss	LedBlinkMask, LEDBUFSIZE;Mask of the leds to be blinking for each group


;----------------------------------------
; Constants
;========================================
			.const
			;Lets define an array of the successive commons to be enabled during scanning
LedGrpArr:	.byte	LEDCOM, DISP0COM, DISP1COM
			;Construct the values to be used for each digit on the displays
LedDigits:	.byte	DISP_A | DISP_B | DISP_C | DISP_D | DISP_E | DISP_F				;0
			.byte	DISB_B | DISP_C													;1
			.byte	DISP_A | DISP_B | DISP_G | DISP_D | DISP_E						;2
			.byte	DISP_A | DISP_B | DISP_C | DISP_D | DISP_G						;3
			.byte	DISP_B | DISP_C | DISP_F | DISP_G								;4
			.byte	DISP_A | DISP_F | DISP_G | DISP_C | DISP_D						;5
			.byte	DISP_F | DISP_G | DISP_E | DISP_C | DISP_D						;6
			.byte	DISP_A | DISP_B | DISP_C										;7
			.byte	DISP_A | DISP_B | DISP_C | DISP_D | DISP_E | DISP_F | DISP_G	;8
			.byte	DISP_A | DISP_B | DISP_C | DISP_D | DISP_F | DISP_G				;9
			.byte	00h																;Empty


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global
			.global	LedScan


;----------------------------------------
; LedsPInit
; Initializes the port pins the Leds and Displays are connected to.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None (Normally R4, R5)
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LEDC_DIR, LEDC_MASK, LEDC_DOUT, LEDP_DIR, LEDP_MASK, LEDP_DOUT
; OTHER FUNCS   : None
LedsPInit:
			BIC.B	#LEDP_MASK,&LEDP_DOUT	;All leds in a group should stay off
			BIS.B	#LEDP_MASK,&LEDP_DIR	;All pins are outputs
			BIS.B	#LEDC_MASK,&LEDC_DOUT	;No group is selected
			BIS.B	#LEDC_MASK,&LEDC_DIR	;All group pins are outputs

			;Normally, the following lines should be used to initialize the local variables.
			; But the main function already has reset the RAM space, so it is not needed.
			; These lines are included here only for completeness
;			MOV		#00000h,R4
;			MOV		R4,&LedBlnkCnt			;Reset blinking time counter
;			MOV		R4,R5
;			MOV		R4,&LedPointer			;Reset pointer of group data in buffer
;LPIn_Loop:	MOV.B	R4,LedBuffer(R5)		;Reset one element in buffer of Led Group data
;			MOV		R4,LedBlinkMask(R5)		;Mask of leds that are blinking
;			INC		R5						;Next element to be used
;			CMP.B	#LEDBUFSIZE,R5			;Passed the limit of buffer
;			JLO		LPIn_Loop				;No => Repeat for the rest of the elements
			RET
			
			
;----------------------------------------
; LedsEnable
; Initializes the associated timer module and starts it counting.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LedBuffer, LEDC_DOUT, LEDP_DOUT, LEDCOM, LEDCYCLE, LedPointer, LEDTCCR0,
;                 LEDTCCTL0, LEDTCTL
; OTHER FUNCS   : None
LedsEnable:
			MOV		#TASSEL_1 | TACLR,&LEDTCTL	;Reset Led Timer and source it from AClk (32K)
			MOV		#LEDCYCLE,&LEDTCCR0			;Period of the timing. Defines the scanning
												; rate
			BIC.B	#LEDCOM,&LEDC_DOUT			;Enable the leds group
			MOV.B	&LedBuffer,&LEDP_DOUT		;Output the state of the leds of this group
			INC		&LedPointer					;Next time we will output the next group
			BIC		#CCIFG,&LEDTCCTL0			;Clear any spurious interrupt
			BIS		#CCIE,&LEDTCCTL0			;Enable CCR0 interrupt
			BIS		#MC0,&LEDTCTL				;Run!
			RET


;----------------------------------------
; LedsDisable
; Initializes the associated timer module and starts it counting.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LEDC_DOUT, LEDC_MASK, LEDP_DOUT, LEDP_MASK, LedPointer, LEDTCCTL0, LEDTCTL
; OTHER FUNCS   : None
LedsDisable:
			BIC		#MC0|MC1,&LEDTCTL			;Stop timer
			BIC		#CCIE|CCIFG,&LEDTCCTL0		;Clear interrupts and disable them from CCR0
			BIS.B	#LEDC_MASK,&LEDC_DOUT		;Disable all groups
			BIC.B	#LEDP_MASK,&LEDP_DOUT		;Also light off all leds of the groups
			MOV		#00000h,&LedPointer			;Reset group pointer
			RET


;----------------------------------------
; LedsOn
; Lights up the selected leds
; INPUT         : R4 contains the led mask to be used
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LedBuffer, LEDOFFS
; OTHER FUNCS   : None
LedsOn:
			BIS.B	R4,&(LedBuffer + LEDOFFS)	;Set the leds to be light up
			RET


;----------------------------------------
; LedsOff
; Lights off the selected leds
; INPUT         : R4 contains the led mask to be used
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LedBuffer, LEDOFFS
; OTHER FUNCS   : None
LedsOff:
			BIC.B	R4,&(LedBuffer + LEDOFFS)	;Clear the leds to be light off
			RET


;----------------------------------------
; LedsVal
; Sets the leds status as described at the input parameter
; INPUT         : R4 contains the led status to be used
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LedBuffer, LEDOFFS
; OTHER FUNCS   : None
LedsVal:
			MOV.B	R4,&(LedBuffer + LEDOFFS)	;Set the leds status according to input param.
			RET
			
			
;----------------------------------------
; LedsBlinkAdd
; Sets the leds blink status as described at the input parameter
; INPUT         : R4 contains the led blink mask to be added
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LedBlinkMask, LEDOFFS
; OTHER FUNCS   : None
LedsBlinkAdd:
			BIS.B	R4,&(LedBlinkMask +LEDOFFS)	;Set the blinking mask
			RET


;----------------------------------------
; LedsBlinkOff
; Sets the leds blink status as described at the input parameter
; INPUT         : R4 contains the led blink mask to be added
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LedBlinkMask, LEDOFFS
; OTHER FUNCS   : None
LedsBlinkOff:
			BIC.B	R4,&(LedBlinkMask +LEDOFFS)	;Set the blinking mask
			RET


;----------------------------------------
; LedsBlinkSet
; Sets the leds blink status as described at the input parameter
; INPUT         : R4 contains the led blink mask to be used
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LedBlinkMask, LEDOFFS
; OTHER FUNCS   : None
LedsBlinkSet:
			MOV.B	R4,&(LedBlinkMask +LEDOFFS)	;Set the blinking mask
			RET


;----------------------------------------
; Disp0BlinkOn
; Sets the leds blink status as described at the input parameter
; INPUT         : R4 contains the led blink mask to be used
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DISP0OFFS, LedBlinkMask
; OTHER FUNCS   : None
Disp0BlinkOn:
			MOV.B	#0FFh,&(LedBlinkMask +DISP0OFFS);Set the blinking mask of the first
												; 7-segment display
			RET


;----------------------------------------
; Disp0BlinkOff
; Sets the leds blink status as described at the input parameter
; INPUT         : R4 contains the led blink mask to be used
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DISP0OFFS, LedBlinkMask
; OTHER FUNCS   : None
Disp0BlinkOff:
			MOV.B	#000h,&(LedBlinkMask +DISP0OFFS);Reset the blinking mask of the first
												; 7-segment display
			RET


;----------------------------------------
; Disp1BlinkOn
; Sets the leds blink status as described at the input parameter
; INPUT         : R4 contains the led blink mask to be used
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DISP1OFFS, LedBlinkMask
; OTHER FUNCS   : None
Disp1BlinkOn:
			MOV.B	#0FFh,&(LedBlinkMask +DISP1OFFS);Set the blinking mask of the second
												; 7-segment display
			RET


;----------------------------------------
; Disp1BlinkOff
; Sets the leds blink status as described at the input parameter
; INPUT         : R4 contains the led blink mask to be used
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DISP1OFFS, LedBlinkMask
; OTHER FUNCS   : None
Disp1BlinkOff:
			MOV.B	#000h,&(LedBlinkMask +DISP1OFFS);Reset the blinking mask of the second
												; 7-segment display
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================

;----------------------------------------
; LedScan
; Interrupt Service Routine for Led Scanning, triggered by CCR0 of the Led Timer
; INPUT         : None
; OUTPUT        : None
; REGS USED     : R4, R5, R6
; REGS AFFECTED : None
; STACK USAGE   : 6 = 3x Push
; VARS USED     : LEDBUFSIZE, LEDC_DOUT, LEDC_MASK, LEDP_DOUT, LedBlinkMask, LedBlnkCnt,
;                 LEDBLNKITVL, LEDBLNKON, LedBuffer, LedGrpArr, LedPointer
; OTHER FUNCS   : None
LedScan:
			BIC.B	#LEDC_MASK,&LEDC_DOUT		;Disable all led groups
			PUSH	R4							;Need to keep registers unaffected (ISR)
			PUSH	R5
			PUSH	R6
			MOV		&LedPointer,R4				;Get the current pointer
			MOV.B	LedBlinkMask(R4),R5			;Get the mask of the blnking status
			MOV.B	LedBuffer(R4),R6			;Get the status of the leds for the current
												; group
			CMP		#LEDBLNKON,&LedBlnkCnt		;Are we at the Off time of blinking leds?
			JLO		LSISR_SkipOff				;No => Skip lighting off the blinking leds
			BIC.B	R5,R6						;else force the masked leds off
LSISR_SkipOff:
			MOV.B	R6,&LEDP_DOUT				;Setup the leds of the group to be used
			BIC.B	LedGrpArr(R4),&LEDC_DOUT	;Enable the group in question
			INC		R4							;Next time will use the nect group
			CMP		#LEDBUFSIZE,R4				;Reached the end of the buffer
			JLO		LSISR_NoReset				;No => OK. Keep on
			MOV		#00000h,R4					;else, restart
LSISR_NoReset:
			MOV		R4,&LedPointer				;Store the next group to be used
			MOV		&LedBlnkCnt,R5				;Get the value of blinking counter
			INC		R5							;Increment it
			CMP		#LEDBLNKITVL,R5				;Passed the value of the interval?
			JLO		LSISR_SkipCnt				;No => Skip reseting it
			MOV		#00000h,R5					;else, reset the blinking coutner
LSISR_SkipCnt:
			MOV		R5,&LedBlnkCnt				;Store the new value
			POP		R6							;Restore used registers
			POP		R5
			POP		R4
			RETI								;Return to interrupted process


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	LEDTVECTOR0				;Led Timer Interrupt Vector to scan the led groups
			.short	LedScan

