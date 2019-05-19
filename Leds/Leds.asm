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

LEDBUFSIZE:	.equ	3						;Number of Led groups the system handles


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	LedBuffer, LEDBUFSIZE	;Cyclic buffer that holds the keystrokes
			.bss	LedPointer, 2			;Pointer to the current group byte in buffer


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
; VARS USED     : LEDP_DIR, LEDP_MASK, LEDP_DOUT
; OTHER FUNCS   : None
LedsPInit:
			BIC.B	#LEDP_MASK,&LEDP_DOUT	;All leds in a group should stay off
			BIS.B	#LEDP_MASK,&LEDP_DIR	;All pins are outputs
			BIS.B	#LEDC_MASK,&LEDC_OUT	;No group is selected
			BIS.B	#LEDC_MASK,&LEDC_DIR	;All group pins are outputs

			;Normally, the following lines should be used to initialize the local variables.
			; But the main function already has reset the RAM space, so it is not needed.
			; These lines are included here only for completeness
;			MOV		#00000h,R4
;			MOV		R4,R5
;			MOV		R4,&LedPointer			;Reset pointer of group data in buffer
;LPIn_Loop:	MOV.B	R4,LedBuffer(R5)		;Reset one element in buffer of Led Group data
;			INC		R5						;Next element to be used
;			CMP.B	#LEDBUFSIZE,R5			;Passed the limit of buffer
;			JL		LPIn_Loop				;No => Repeat for the rest of the elements
			RET


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	LEDTVECTOR0				;Led Timer Interrupt Vector to scan the led groups
			.short	LedScan

