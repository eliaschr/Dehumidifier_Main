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
LEDTESTTIME:.equ	20						;Number of scan itterations a led will be lit
											; during test
LEDCYCLE:	.equ	(ACLKFreq / (LEDFreq * LEDBUFSIZE))
											;The CCR0 setting to achieve the scanning timing
											
;Lets define the offsets needed to access the data tableS (LedBuffer and LedGrpArr)
LEDOFFS:	.equ	0
DISP0OFFS:	.equ	(LEDOFFS +1)
DISP1OFFS:	.equ	(DISP0OFFS +1)
LEDGROUPS:	.equ	(DISP1OFFS +1)			;Number of groups supported

;Following is the mask of the leds used at no scanning port
LEDNS_MASK:	.equ	(Board_LedNSTank | Board_LedNSAnion)


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	LedPointer, 2			;Pointer to the current group byte in buffer
			.bss	LedBlnkCnt,	2			;Led blinker counter
			.bss	LedTestCntr, 2			;Led Test Scanning Counter
			.bss	LedTestPtr, 2			;Pointer to data during led test
			.bss	LedBuffer, LEDBUFSIZE	;Buffer that holds the led status of all groups
			.bss	LedBlinkMask, LEDBUFSIZE;Mask of the leds to be blinking for each group


;----------------------------------------
; Constants
;========================================
			.sect ".const"
			;Lets define an array of the successive commons to be enabled during scanning
LedGrpArr:	.byte	LEDCOM, DISP0COM, DISP1COM

			;Construct the values to be used for each digit on the displays
LedDigits:	.byte	DISP_A | DISP_B | DISP_C | DISP_D | DISP_E | DISP_F				;0
			.byte	DISP_B | DISP_C													;1
			.byte	DISP_A | DISP_B | DISP_G | DISP_D | DISP_E						;2
			.byte	DISP_A | DISP_B | DISP_C | DISP_D | DISP_G						;3
			.byte	DISP_B | DISP_C | DISP_F | DISP_G								;4
			.byte	DISP_A | DISP_F | DISP_G | DISP_C | DISP_D						;5
			.byte	DISP_F | DISP_G | DISP_E | DISP_C | DISP_D						;6
			.byte	DISP_A | DISP_B | DISP_C										;7
			.byte	DISP_A | DISP_B | DISP_C | DISP_D | DISP_E | DISP_F | DISP_G	;8
			.byte	DISP_A | DISP_B | DISP_C | DISP_D | DISP_F | DISP_G				;9
			.byte	00h																;Empty

;Helper definitions to add a group and flashing value in the test array
LEDGRP:		.equ	(LEDOFFS << 8)
DISP0GRP:	.equ	(DISP0OFFS << 8)
DISP1GRP:	.equ	(DISP1OFFS << 8)
FLASHTEST:	.equ	BITF
LedTestArr:	;Test leds, one by one and then all together
			.byte	LEDGRP|LEDHUMID, LEDGRP|LEDPOWER, LEDGRP|LEDTANK, LEDGRP|LEDTIMER
			.byte	LEDGRP|LEDLOW, LEDGRP|LEDHIGH, LEDGRP|LEDANION
			.byte	LEDGRP|LEDHUMID|LEDPOWER|LEDTANK|LEDTIMER|LEDLOW|LEDHIGH|LEDANION
			.byte	LEDGRP					;All leds off
			;Test display 0 leds one by one and then all
			.byte	DISP0GRP|DISP_A, DISP0GRP|DISP_B, DISP0GRP|DISP_C, DISP0GRP|DISP_D
			.byte	DISP0GRP|DISP_E, DISP0GRP|DISP_F, DISP0GRP|DISP_G, DISP0GRP|DISP_DP
			.byte	DISP0GRP				;Display 0 off
			;Test display 1 leds one by one and then all
			.byte	DISP1GRP|DISP_A, DISP1GRP|DISP_B, DISP1GRP|DISP_C, DISP1GRP|DISP_D
			.byte	DISP1GRP|DISP_E, DISP1GRP|DISP_F, DISP1GRP|DISP_G, DISP1GRP|DISP_DP
			.byte	DISP1GRP				;Display 1 off
LedTestEnd:	.byte	000h					;Marks the end of the testing array
LedTestFunc:.word	LedsVal, Disp0SetLeds, Disp1SetLeds


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
; VARS USED     : LEDC_DIR, LEDC_MASK, LEDC_DOUT, LEDNS_DIR, LEDNS_DOUT, LEDNS_MASK, LEDP_DIR,
;                 LEDP_MASK, LEDP_DOUT
; OTHER FUNCS   : None
LedsPInit:
			BIC.B	#LEDP_MASK,&LEDP_DOUT	;All leds in a group should stay off
			BIS.B	#LEDP_MASK,&LEDP_DIR	;All pins are outputs
			BIS.B	#LEDC_MASK,&LEDC_DOUT	;No group is selected
			BIS.B	#LEDC_MASK,&LEDC_DIR	;All group pins are outputs
			BIS.B	#LEDNS_MASK,&LEDNS_DOUT	;Both No-Scanning leds must be off (inverse logic)
			BIS.B	#LEDNS_MASK,&LEDNS_DIR	;Both led pins are outputs

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
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LedBuffer, LEDANION, LEDC_DOUT, LEDCOM, LEDCYCLE, LEDNS_DOUT, LEDNS_MASK,
;                 LEDNSANION, LEDNSTANK, LEDP_DOUT, LedPointer, LEDTANK, LEDTCCR0, LEDTCCTL0,
;                 LEDTCTL
; OTHER FUNCS   : None
LedsEnable:
			MOV		#TASSEL_1 | TACLR,&LEDTCTL	;Reset Led Timer and source it from AClk (32K)
			MOV		#LEDCYCLE,&LEDTCCR0			;Period of the timing. Defines the scanning
												; rate
			BIC.B	#LEDCOM,&LEDC_DOUT			;Enable the leds group
			MOV.B	&LedBuffer,R4				;Get the value. Need it later
			MOV.B	R4,&LEDP_DOUT				;Output the state of the leds of this group
			BIS.B	#LEDNS_MASK,&LEDNS_DOUT		;Non scanning leds are off
			BIT.B	#LEDTANK,R4					;Is the Tank Full led on?
			JZ		LEn_SkipTank				;No => keep the respective Non-scan led off
			BIC.B	#LEDNSTANK,&LEDNS_DOUT		;else, light it up
LEn_SkipTank:
			BIT.B	#LEDANION,R4				;Is the Anion led on?
			JZ		LEn_SkipAnion				;No => keep the respective Non-scan led off
			BIC.B	#LEDNSANION,&LEDNS_DOUT		;else, Light it up
LEn_SkipAnion:
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
; VARS USED     : LEDC_DOUT, LEDC_MASK, LEDNS_DOUT, LEDNS_MASK, LEDP_DOUT, LEDP_MASK,
;                 LedPointer, LEDTCCTL0, LEDTCTL
; OTHER FUNCS   : None
LedsDisable:
			BIC		#MC0|MC1,&LEDTCTL			;Stop timer
			BIC		#CCIE|CCIFG,&LEDTCCTL0		;Clear interrupts and disable them from CCR0
			BIS.B	#LEDC_MASK,&LEDC_DOUT		;Disable all groups
			BIC.B	#LEDP_MASK,&LEDP_DOUT		;Also light off all leds of the groups
			BIS.B	#LEDNS_MASK,&LEDNS_DOUT		;Light off the no scanning leds
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
			BIC.B	R4,&(LedBuffer + LEDOFFS)	;Clear the leds to be off
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
; Starts blinking the leds defined at the input parameter
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
; Stops led blinking of the defined leds
; INPUT         : R4 contains the led blink mask to be removed
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
; Starts blinking of Display 0
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
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
; Stops Display 0 blinking
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
; Starts blinking Display 1
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
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
; Stops Display 1 blinking
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DISP1OFFS, LedBlinkMask
; OTHER FUNCS   : None
Disp1BlinkOff:
			MOV.B	#000h,&(LedBlinkMask +DISP1OFFS);Reset the blinking mask of the second
												; 7-segment display
			RET


;----------------------------------------
; Disp0SetDigit
; Sets the digit to be displayed by Display 0
; INPUT         : R4 contains the digit to be desplayed on display 0
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DISP0OFFS, LedBuffer, LedDigits
; OTHER FUNCS   : None
Disp0SetDigit:
			MOV.B	LedDigits(R4),&(LedBuffer +DISP0OFFS);Get the digit value and store it at
												; Disp0 data buffer
			RET


;----------------------------------------
; Disp1SetLeds
; Sets the digit to be displayed by Display  1
; INPUT         : R4 contains the digit to be desplayed on display 1
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DISP1OFFS, LedBuffer, LedDigits
; OTHER FUNCS   : None
Disp1SetDigit:
			MOV.B	LedDigits(R4),&(LedBuffer +DISP0OFFS);Get the digit value and store it at
												; Disp1 data buffer
			RET


;----------------------------------------
; Disp0SetLeds
; Sets the leds of Display 0 according to the input parameter
; INPUT         : R4 contains the leds status of display 0
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DISP0OFFS, LedBuffer
; OTHER FUNCS   : None
Disp0SetLeds:
			MOV.B	R4,&(LedBuffer +DISP0OFFS)	;Set the Display 0 led mask
			RET


;----------------------------------------
; Disp1SetLeds
; Sets the leds of Display 0 according to the input parameter
; INPUT         : R4 contains the leds status of display 1
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : DISP1OFFS, LedBuffer
; OTHER FUNCS   : None
Disp1SetLeds:
			MOV.B	R4,&(LedBuffer +DISP0OFFS)	;Set the Display 1 led mask
			RET


;----------------------------------------
; LedsTest
; Starts a led test.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : LEDCYCLE, LEDTCCR1, LEDTCCTL1, LedTestCntr, LedTestGrp, LedTestPtr
; OTHER FUNCS   : None
LedsTest:
			MOV		#00000h,&LedTestCntr		;Reset the counter of itterations
			MOV		#00000h,&LedTestPtr			;Reset the pointer to start indications from
												; the beggining
			MOV		#LEDCYCLE/2,&LEDTCCR1		;Triggering of Testing interrupt will be at
												; half of the scanning cycle
			MOV.B	&LedTestArr,&LedBuffer		;Initialize the first state
			BIC		#CCIFG,&LEDTCCTL1			;Clear any spurious interrutps
			BIS		#CCIE,&LEDTCCTL1			;Enable Tesing interrupt
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
; VARS USED     : LEDANION, LedBlinkMask,  LedBlnkCnt, LEDBLNKITVL, LEDBLNKON, LedBuffer,
;                 LEDBUFSIZE, LEDC_DOUT, LEDC_MASK, LedGrpArr, LEDNS_DOUT, LEDNS_MASK,
;                 LEDNSANION, LEDNSTANK, LEDOFFS, LEDP_DOUT, LedPointer
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
			;Now have to decide for the non scanning leds also (Inverse logic on them)
			CMP.B	#LEDOFFS,R4					;Do we have data for the Leds?
			JNZ		LSISR_NoNS					;No => Then we do not care about No Scan leds
			BIS.B	#LEDNS_MASK,&LEDNS_DOUT		;Light off both leds temporarily
			BIT.B	#LEDTANK,R6					;Is the Tank led on?
			JZ		LSISR_NoTank				;No => keep it off
			BIC.B	#LEDNSTANK,&LEDNS_DOUT		;else Light it up
LSISR_NoTank:
			BIT.B	#LEDANION,R6				;Is the Anion led on?
			JZ		LSISR_NoNS					;No => keep it off, too
			BIC.B	#LEDNSANION,&LEDNS_DOUT		;else, light it up
LSISR_NoNS:	INC		R4							;Next time will use the next group
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
; LedTester
; Interrupt Service Routine for Led testing, triggered by CCR1 of the Led Timer
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : 
; OTHER FUNCS   : None
LedTester:
			INC		&LedTestCntr				;Increment the number of itterations
			CMP		#LEDTESTTIME,&LedTestCntr
												;Is it time to change the led values?
			JLO		LTISR_Skip					;No => then just exit
			MOV		#00000h,&LedTestCntr		;Clear again the number of itteration
			
			PUSH	R4
			PUSH	R5
			PUSH	R15
			MOV		&LedTestPtr,R5				;Get current pointer
			INC		R5							;Next test
			MOV		R5,&LedTestPtr				;Store it
			ADD		#LedTestArr,R5				;Add the starting of the table
			MOV		@R5,R4						;Get the value to be set
			SWPB	R4							;Group to low byte
			AND.B	#00Fh,R4					;Filter out the flashing flags
			
			
			MOV		#LedsVal,R15				;Pointer to Led Group setting function
			CMP.B	#LEDGRP,R4					;Do we have to set the led group?
			JEQ		LTI_SetIt					;Yes => then proceed to setting leds
			MOV		#Disp0SetLeds,R15			;Pointer to Display 0 led setting
			CMP.B	#DISP0GRP,R4				;Do we have to set Display 0?
			JEQ		LTI_SetIt					;Yes => then set it
			MOV		#Disp1SetLeds,R15			;else, we must set the leds of Display 1
LTI_SetIt:	MOV		@R5,R4						;Refresh the value to be used
			CALL	R15							;Call function pointed by R15
			
				
LTISR_Skip:	RETI								;Return to caller

;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	LEDTVECTOR0				;Led Timer Interrupt Vector to scan the led groups
			.short	LedScan

			.sect	LEDTVECTOR1				;Led testing interrupt vector
			.short	LedTester
