;*********************************************************************************************
;* Buzzer Library                                                                            *
;*-------------------------------------------------------------------------------------------*
;* Buzzer.asm                                                                                  *
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


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------


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
; VARS USED     : 
; OTHER FUNCS   : None
LedsPInit:
			BIC.B	#BUZZPIN,&BUZZP_DOUT	;Buzzer should not sound
			BIS.B	#BUZZPIN,&BUZZP_DIR		;Buzzer pin is output
			RET
			
			


;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; BuzzBeepISR
; 
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : 
; OTHER FUNCS   : None
BuzzBeepISR:
			RETI


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	BUZZTVECTOR1			;Buzzer Beeping Interrupt Vector
			.short	BuzzBeepISR
