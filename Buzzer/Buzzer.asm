;*********************************************************************************************
;* Buzzer Library                                                                            *
;*-------------------------------------------------------------------------------------------*
;* Buzzer.asm                                                                                *
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
;* Library of procedures for connecting a buzzer on the system to provide audio feedback.    *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"Buzzer Library"
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
			.include "Buzzer.h43"			;Local definitions
			.include "BuzzAutoDefs.h43"		;Auto definitions according to settings in
											; Buzzer.h43


;----------------------------------------
; Definitions
;========================================
BUZZERONT:	.equ	30						;The time the buzzer stays on for a single beep,
											; in number of timer ticks.
BUZZERITVL:	.equ	08000h					;Time interval for repetitive beeps in number of
											; timer ticks


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	BeepCnt, 2				;The number of times the buzzer will sound
			.bss	BeepRptT, 2				;The repetiotion interval to be used


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global
			.global	BuzzBeepISR


;----------------------------------------
; BuzzPInit
; Initializes the port pin that triggers the Buzzer.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : BUZZP_DIR, BUZZP_DOUT, BUZZPIN
; OTHER FUNCS   : None
BuzzPInit:
			BIC.B	#BUZZPIN,&BUZZP_DOUT	;Buzzer should not sound
			BIS.B	#BUZZPIN,&BUZZP_DIR		;Buzzer pin is output
			RET
			

;----------------------------------------
; BeepOnce
; Starts the buzzer to beep once
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : BeepCnt, BeepRptT, BUZZCCR1, BUZZERITVL, BUZZERONT, BUZZP_DOUT, BUZZPIN,
;                 BUZZTCCR1, BUZZTCCTL1, BUZZTCTL, BUZZTR
; OTHER FUNCS   : None
BeepOnce:
			MOV		#BUZZERITVL - BUZZERONT,&BeepRptT;Set the repetition interval
			MOV		#00001h,&BeepCnt		;Beep only once
			MOV		#BUZZERONT,&BUZZTCCR1	;Set the On time
			ADD		&BUZZTR,&BUZZCCR1		;The "On Time" counts from now
			BIS.B	#BUZZPIN,&BUZZP_DOUT	;Beep!
			BIC		#CCIFG,&BUZZTCCTL1		;Clear spurious interrupts
			BIS		#CCIE,&BUZZTCCTL1		;Enable interrupts from this timer CCR1
			BIS		#MC1,&BUZZTCTL			;Start timer running in continuous mode
			RETI


;----------------------------------------
; BeepMany
; Initializes the port pin that triggers the Buzzer.
; INPUT         : R4 conains the number of beeps
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : BeepCnt, BeepRptT, BUZZCCR1, BUZZERITVL, BUZZERONT, BUZZP_DOUT, BUZZPIN,
;                 BUZZTCCR1, BUZZTCCTL1, BUZZTCTL, BUZZTR
; OTHER FUNCS   : None
BeepMany:
			MOV		#BUZZERITVL - BUZZERONT,&BeepRptT;Set the repetition interval
			MOV		#R4,&BuzzCnt			;Beep only once
			MOV		#BUZZERONT,&BUZZTCCR1	;Set the On time
			ADD		&BUZZTR,&BUZZCCR1		;The "On Time" counts from now
			BIS.B	#BUZZPIN,&BUZZP_DOUT	;Beep!
			BIC		#CCIFG,&BUZZTCCTL1		;Clear spurious interrupts
			BIS		#CCIE,&BUZZTCCTL1		;Enable interrupts from this timer CCR1
			BIS		#MC1,&BUZZTCTL			;Start timer running in continuous mode
			RETI


;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; BuzzBeepISR
; Dispatcher for the interrupts triggered by the Buzzer TimerA
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : BUZZTIV
; OTHER FUNCS   : BuzzOnInt
BuzzBeepISR:
			ADD		&BUZZTIV,PC				;Jump to the correct element of the ISR table
			RETI							;Vector 0: No Interrupt
			JMP		BuzzOnInt				;Vector 2: Timer CCR1 CCIFG
			RETI							;Vector 4: Timer CCR2 CCIFG
			RETI							;Vector 6: Reserved
			RETI							;Vector 8: Reserved
			RETI							;Vector A: TAIFG


;----------------------------------------
; BuzzOnInt
; Interrupt to produce timings for the buzzer to produce one or many beeps
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : 
; OTHER FUNCS   : BuzzOnInt
BuzzOnInt:
			BIT.B	#BUZZPIN,&BUZZ_DIN		;Do we sound?
			JZ		BOI_Repeat				;No => Try to repeat beep
			;Going to stop the buzzer beep
			BIC.B	#BUZZPIN,&BUZZ_DOUT		;Stop beeping
			DEC		&BeepCnt				;One beep leSS
			JNZ		BOI_NoStop				;Not finished => Do not stop the timer
			;Finished -> Stop
			BIC		#MC0|MC1,&BUZZTCTL		;Stop timer from running
			BIC		#CCIE|CCIFG,&BUZZTCCTL1	;Clear any pending interrupts
			RETI
			
			;Need to beep more times
BOI_NoStop:	ADD		&BeepRptT,&BUZZTCCR1	;Prepare for next interrupt
			BIC		#CCIFG,&BUZZTCTL		;Clear the interrupt flag
			RETI
			
BOI_Repeat:	BIS.B	#BUZZPIN,&BUZZ_DOUT		;Start beeping
			ADD		#BEEPONT,&BUZZTCCR1		;Set the interval of sounding for On Time
			BIC		#CCIFG,&BUZZTCTL		;Clear the interrupt flag
			RETI


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	BUZZTVECTOR1			;Buzzer Beeping Interrupt Vector
			.short	BuzzBeepISR
